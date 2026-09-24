## HitSoundFactory 打击音效合成
##
## 项目里没有任何音效文件 (git 历史中曾有一个, 已被删除), 所以先用代码合成一个
## 短促的打击音作为占位 —— 这样整条链路 (音量设置项 volume_note、播放池、命中触发)
## 都能立刻跑通。之后有正式音效时, 把 Gameplay 里的 make_hit_sound() 换成
## load("res://Asset/Audio/xxx.wav") 即可, 其余接线不用改。


class_name HitSoundFactory


## 采样率
const MIX_RATE: int = 44100

## 打击音时长 (秒) —— 要短, 否则密集谱面会糊成一片
const DURATION: float = 0.06

## 基频 (Hz)
const BASE_FREQ: float = 1180.0

## 指数衰减速度 (越大越"脆")
const DECAY: float = 55.0

## 噪声瞬态占比 (0.0 ~ 1.0), 给打击音一点"击打"的质感
const NOISE_MIX: float = 0.35

## 起始淡入时长 (秒), 避免开头爆音
const ATTACK: float = 0.002

## 尾部淡出起点 (占全长的比例), 避免截断产生咔哒声
const TAIL_START: float = 0.7

## 噪声随机种子 (固定值, 保证每次生成的音色一致)
const NOISE_SEED: int = 20260924


## 合成一个短促的打击音
## @return: 可直接赋给 AudioStreamPlayer.stream 的音频流
static func make_hit_sound() -> AudioStreamWAV:
	var sample_count: int = int(float(MIX_RATE) * DURATION)
	# 16-bit 单声道 → 每个样本 2 字节
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = NOISE_SEED

	for i: int in sample_count:
		var t: float = float(i) / float(MIX_RATE)

		# 指数衰减包络
		var envelope: float = exp(-DECAY * t)

		# 起始淡入
		if t < ATTACK:
			envelope *= t / ATTACK
			pass

		# 尾部淡出
		var tail_start: float = DURATION * TAIL_START
		if t > tail_start:
			envelope *= (DURATION - t) / (DURATION - tail_start)
			pass

		# 基频 + 一个八度泛音, 让音色更亮、更有"击打"感
		var tone: float = sin(TAU * BASE_FREQ * t) + 0.35 * sin(TAU * BASE_FREQ * 2.0 * t)
		var noise: float = rng.randf_range(-1.0, 1.0)
		var sample: float = (tone * (1.0 - NOISE_MIX) + noise * NOISE_MIX) * envelope

		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
		pass

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.set_format(AudioStreamWAV.FORMAT_16_BITS)
	stream.set_mix_rate(MIX_RATE)
	stream.set_stereo(false)
	stream.set_data(data)
	return stream
