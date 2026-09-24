## AudioSumProbe 临时探针: 测量同一帧内 N 个相同打击音播放器叠加后的主总线峰值
## 用来验证 "同帧多个打击音是否同相叠加" 这一假设。
## 不参与游戏逻辑, 测完即删。

extends Node


## 与 Gameplay.play_hit_sound 一致的音量 (volume_note=70 * VOLUME_FACTOR=0.01)
const TEST_VOLUME: float = 0.7

## 播放池
var _players: Array[AudioStreamPlayer] = [ ]

## 主总线抓取
var _capture: AudioEffectCapture = null


func _ready() -> void:
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 2.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), _capture)

	var stream: AudioStreamWAV = HitSoundFactory.make_hit_sound()
	var data: PackedByteArray = stream.get_data()
	var raw_peak: int = 0
	for i: int in data.size() / 2:
		raw_peak = maxi(raw_peak, absi(data.decode_s16(i * 2)))
	print("PROBE stream peak sample = ", float(raw_peak) / 32767.0, "  (duration=", stream.get_length(), "s)")

	for i: int in 4:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = stream
		add_child(player)
		_players.append(player)
		pass

	await get_tree().create_timer(0.3).timeout

	var peak_1: float = await _measure(1)
	var peak_2: float = await _measure(2)
	var peak_4: float = await _measure(4)

	print("PROBE 1 voice peak = ", peak_1)
	print("PROBE 2 voice peak = ", peak_2, "   ratio=", peak_2 / maxf(peak_1, 0.000001))
	print("PROBE 4 voice peak = ", peak_4, "   ratio=", peak_4 / maxf(peak_1, 0.000001))

	get_tree().quit()
	pass


## 同一帧内启动 count 个播放器, 返回主总线抓取到的峰值
func _measure(count: int) -> float:
	_capture.clear_buffer()
	await get_tree().create_timer(0.08).timeout
	_capture.clear_buffer()

	for i: int in count:
		_players[i].volume_linear = TEST_VOLUME
		_players[i].play()
		pass

	await get_tree().create_timer(0.2).timeout
	var frames: PackedVector2Array = _capture.get_buffer(_capture.get_frames_available())
	var peak: float = 0.0
	for f: Vector2 in frames:
		peak = maxf(peak, maxf(absf(f.x), absf(f.y)))
		pass
	_capture.clear_buffer()
	return peak
