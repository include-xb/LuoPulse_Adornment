#!/usr/bin/env python3
"""裁掉 wav 首尾的静音 (含开头那种单帧编码残留尖峰), 保持原格式 (声道/采样率/位深).

为什么需要它:
  Clipchamp / 一些剪辑工具导出的 wav 会在**帧 0** 留一个孤立的单帧尖峰 (幅度很高
  但只有 1 帧), 后面紧跟几十毫秒的数字静音. 危害不只是那一下极轻的"啪":
  任何"找第一个非静音采样"式的裁剪 (包括 Godot 导入设置里的 edit/trim) 都会被它挡住,
  于是一整段纯静音被留在打击音开头, 变成实实在在的延迟.

  本脚本的起音判定要求"连续多个 1ms 窗都超过门限", 单帧尖峰撑不过连续多窗,
  所以它不会被误判成起音 —— 而它本身位于起音点之前, 会被正常裁掉.

用法:
    python trim_wav_silence.py <wav 路径> [更多 wav ...] [选项]

选项:
    --dry-run          只分析并打印, 不写文件
    --no-backup        不生成 .bak (默认生成; 已存在的 .bak 不会被覆盖)
    --keep-ms N        起音前保留多少毫秒"跑道"(默认 3). 不建议设 0 ——
                       直接切在起音点上会让波形从 0 跳到 17%, 反而产生新的咔哒声
    --onset-pct P      起音门限, 占峰值百分比(默认 2.0)
    --onset-ms N       起音需要连续超过门限多少毫秒才算数(默认 3)
    --tail-pct P       尾部静音门限, 占峰值百分比(默认 0.2)

只支持 16bit 未压缩 PCM —— 本项目音效素材都是这个格式, 其它格式直接报错退出.
"""

import argparse
import os
import struct
import sys


class WavError(Exception):
    pass


def read_wav(path):
    """返回 (pcm_bytes, channels, rate, bits). 只接受 16bit PCM."""
    with open(path, "rb") as handle:
        data = handle.read()
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise WavError("不是 RIFF/WAVE 文件")

    offset = 12
    fmt_payload = None
    data_offset = data_size = None
    while offset + 8 <= len(data):
        chunk_id = data[offset:offset + 4]
        chunk_size = struct.unpack_from("<I", data, offset + 4)[0]
        if chunk_id == b"fmt ":
            fmt_payload = data[offset + 8:offset + 8 + chunk_size]
        elif chunk_id == b"data":
            data_offset, data_size = offset + 8, chunk_size
        offset += 8 + chunk_size + (chunk_size & 1)

    if fmt_payload is None or data_offset is None:
        raise WavError("缺少 fmt 或 data 块")
    if len(fmt_payload) < 16:
        raise WavError("fmt 块太短")

    # INFO: fmt 载荷的第 0 个字段是"格式标签"而不是声道数 ——
    #       少算这 2 字节会让后面每个字段都错位(声道/采样率/位深全读到错的值)
    tag, channels, rate, byte_rate, block_align, bits = struct.unpack_from("<HHIIHH", fmt_payload, 0)
    if tag != 1:
        raise WavError("压缩格式 (fmt tag=%d), 只支持未压缩 PCM" % tag)
    if bits != 16:
        raise WavError("位深 %d, 只支持 16bit" % bits)

    return data[data_offset:data_offset + data_size], channels, rate, bits


def to_per_channel(pcm, channels):
    """PCM 字节 → 每声道一个 int 列表."""
    count = len(pcm) // 2
    flat = struct.unpack("<%dh" % count, pcm[:count * 2])
    return [list(flat[c::channels]) for c in range(channels)]


def frame_envelope(per_channel, frames, window):
    """逐窗的 |采样| 最大值, 返回 [(窗起始帧, 峰值), ...]."""
    env = []
    for start in range(0, max(1, frames - window), window):
        stop = min(start + window, frames)
        env.append((start, max(max(abs(ch[i]) for ch in per_channel) for i in range(start, stop))))
    if not env:
        raise WavError("文件太短")
    return env


def find_bounds(per_channel, frames, rate, peak, args):
    """返回 (start, end, onset, pre_onset_hits). 保留区间是半开的 [start, end)."""
    window = max(1, rate // 1000)
    env = frame_envelope(per_channel, frames, window)
    onset_th = peak * args.onset_pct / 100.0
    tail_th = peak * args.tail_pct / 100.0

    # 起音: 第一个"连续 onset_ms 个窗都超过门限"的位置.
    # INFO: 必须要求连续 —— 只看单个窗的话, 开头那种只占 1 帧的编码残留尖峰
    #       会把起音判成第 0 ms, 结果一整个静音段都裁不掉
    sustain = max(1, int(args.onset_ms))
    onset_frame = None
    run = 0
    for start, value in env:
        if value > onset_th:
            run += 1
            if run >= sustain:
                onset_frame = start - (sustain - 1) * window
                break
        else:
            run = 0
    if onset_frame is None:
        raise WavError("找不到起音点: 整段都没有连续 %d ms 超过峰值 %.1f%%" % (sustain, args.onset_pct))

    # 尾部: 最后一个超过门限的窗
    end_frame = frames
    for start, value in reversed(env):
        if value > tail_th:
            end_frame = min(frames, start + window)
            break

    keep = int(rate * args.keep_ms / 1000.0)
    start_frame = max(0, onset_frame - keep)

    # 起音点之前的一切都位于"声音之前", 会被裁掉 —— 开头那种孤帧残留正是这样被清掉的.
    # 这里只做统计与上报, 不单独去改波形 (对噪声型打击音做全局孤点手术会误伤真实瞬态)
    pre_hits = 0
    pre_head = []
    for channel_index, xs in enumerate(per_channel):
        for i in range(onset_frame):
            if abs(xs[i]) > peak * 0.01:
                pre_hits += 1
                if len(pre_head) < 6:
                    pre_head.append("ch%d@帧%d(%.2fms)=%d" % (
                        channel_index, i, i / rate * 1000, xs[i]))
    return start_frame, end_frame, onset_frame, pre_hits, pre_head


def pack_wav(per_channel, start, end, channels, rate, bits):
    """把帧区间 [start, end) 打包成规范的 16bit PCM wav 字节."""
    flat = []
    for i in range(start, end):
        for ch in per_channel:
            flat.append(ch[i])
    pcm = struct.pack("<%dh" % len(flat), *flat)
    block = channels * bits // 8
    fmt = struct.pack("<HHIIHH", 1, channels, rate, rate * block, block, bits)
    body = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt
    body += b"data" + struct.pack("<I", len(pcm)) + pcm
    return b"RIFF" + struct.pack("<I", len(body)) + body


def process(path, args):
    print("=" * 70)
    print(path)
    try:
        pcm, channels, rate, bits = read_wav(path)
        per_channel = to_per_channel(pcm, channels)
        frames = len(per_channel[0])
        peak = max(max(abs(v) for v in xs) for xs in per_channel)
    except WavError as exc:
        print("  跳过: %s" % exc)
        return False

    if peak == 0:
        print("  跳过: 全是静音")
        return False

    print("  原文件: %.3f 秒 (%d 帧, %dch, %dHz, %dbit), 峰值 %d (%.0f%%)" % (
        frames / rate, frames, channels, rate, bits, peak, peak / 32767 * 100))

    try:
        start, end, onset, pre_hits, pre_head = find_bounds(per_channel, frames, rate, peak, args)
    except WavError as exc:
        print("  跳过: %s" % exc)
        return False

    print("  起音点: 帧 %d (%.2f ms)" % (onset, onset / rate * 1000))
    print("  起音前的残留: %d 个采样%s" % (
        pre_hits, ("  " + ", ".join(pre_head)) if pre_head else "  (干净)"))
    print("  裁掉: 开头 %.2f ms, 结尾 %.2f ms" % (
        start / rate * 1000, (frames - end) / rate * 1000))
    print("  新时长: %.3f 秒 (原 %.3f 秒, 省下 %.2f ms)" % (
        (end - start) / rate, frames / rate, (frames - (end - start)) / rate * 1000))

    if args.dry_run:
        print("  [干跑, 未写文件]")
        return True

    if (start, end) == (0, frames):
        print("  无需改动")
        return True

    if not args.no_backup:
        backup = path + ".bak"
        if os.path.exists(backup):
            print("  备份已存在, 保留原样: %s" % backup)
        else:
            with open(path, "rb") as src:
                with open(backup, "wb") as dst:
                    dst.write(src.read())
            print("  备份: %s" % backup)

    with open(path, "wb") as handle:
        handle.write(pack_wav(per_channel, start, end, channels, rate, bits))
    print("  已写入: %d 字节 → %d 字节" % (len(pcm) + 78, os.path.getsize(path)))
    return True


def main():
    parser = argparse.ArgumentParser(description="裁掉 wav 首尾静音 (保持格式)")
    parser.add_argument("paths", nargs="+", help="要处理的 wav 文件")
    parser.add_argument("--dry-run", action="store_true", help="只分析, 不写文件")
    parser.add_argument("--no-backup", action="store_true", help="不生成 .bak")
    parser.add_argument("--keep-ms", type=float, default=3.0, help="起音前保留的跑道(ms)")
    parser.add_argument("--onset-pct", type=float, default=2.0, help="起音门限(峰值百分比)")
    parser.add_argument("--onset-ms", type=float, default=3.0, help="起音需连续超过门限的毫秒数")
    parser.add_argument("--tail-pct", type=float, default=0.2, help="尾部静音门限(峰值百分比)")
    args = parser.parse_args()

    ok = True
    for path in args.paths:
        if not os.path.exists(path):
            print("找不到文件: %s" % path)
            ok = False
            continue
        ok = process(path, args) and ok
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
