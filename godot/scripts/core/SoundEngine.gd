# SoundEngine.gd
# Web Audio API와 동일한 원리로 오디오 데이터를 절차적으로 합성하여 재생하는 엔진
extends Node

var muted: bool = false
var volume_db: float = 0.0

var _players: Array[AudioStreamPlayer] = []
var _cached_streams: Dictionary = {}

func _ready() -> void:
	# Create audio player pool
	for i in range(8):
		var p = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func toggle_mute() -> bool:
	muted = !muted
	return muted

func _get_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]

func _play_synth_stream(stream_name: String, generator_func: Callable) -> void:
	if muted:
		return
	if not _cached_streams.has(stream_name):
		_cached_streams[stream_name] = generator_func.call()
	
	var p = _get_player()
	p.stream = _cached_streams[stream_name]
	p.volume_db = volume_db
	p.play()

# === SYNTHESIS HELPERS ===
func _create_wav(samples: PackedByteArray, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = samples
	return wav

# 1. 타일 클릭음
func play_tile_click() -> void:
	_play_synth_stream("tile_click", func():
		var rate = 22050
		var duration = 0.05
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		for i in range(count):
			var t = float(i) / rate
			var freq = lerp(520.0, 880.0, float(i) / count)
			var env = 1.0 - (float(i) / count)
			var s = sin(t * freq * TAU) * env * 0.4
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	)

# 2. 타일 회전음
func play_tile_rotate() -> void:
	_play_synth_stream("tile_rotate", func():
		var rate = 22050
		var duration = 0.08
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		for i in range(count):
			var t = float(i) / rate
			var freq = lerp(320.0, 640.0, float(i) / count)
			var env = 1.0 - (float(i) / count)
			var s = (fmod(t * freq, 1.0) * 2.0 - 1.0) * env * 0.35
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	)

# 3. 타일 합성음
func play_tile_combine() -> void:
	_play_synth_stream("tile_combine", func():
		var rate = 22050
		var duration = 0.18
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		var freqs = [523.25, 659.25, 783.99]
		for i in range(count):
			var t = float(i) / rate
			var note_idx = mini(int(t / 0.05), freqs.size() - 1)
			var freq = freqs[note_idx]
			var local_t = fmod(t, 0.05) / 0.05
			var env = (1.0 - local_t) * (1.0 - float(i) / count)
			var s = sin(t * freq * TAU) * env * 0.4
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	)

# 4. 단어 완성 팡파레
func play_word_crafted() -> void:
	_play_synth_stream("word_crafted", func():
		var rate = 22050
		var duration = 0.28
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		var freqs = [440.0, 554.37, 659.25, 880.0]
		for i in range(count):
			var t = float(i) / rate
			var note_idx = mini(int(t / 0.06), freqs.size() - 1)
			var freq = freqs[note_idx]
			var env = (1.0 - float(i) / count)
			var s = sin(t * freq * TAU) * env * 0.4
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	)

# 5. 공격 타격음
func play_attack() -> void:
	_play_synth_stream("attack", func():
		var rate = 22050
		var duration = 0.12
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		for i in range(count):
			var env = 1.0 - (float(i) / count)
			var noise = (randf() * 2.0 - 1.0) * env * 0.5
			bytes[i] = int(clamp((noise + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	)

# 6. 방패음
func play_shield() -> void:
	_play_synth_stream("shield", func():
		var rate = 22050
		var duration = 0.16
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		for i in range(count):
			var t = float(i) / rate
			var freq = lerp(180.0, 340.0, float(i) / count)
			var env = 1.0 - (float(i) / count)
			var s = sin(t * freq * TAU) * env * 0.45
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	)

# 7. 마법 효과음
func play_magic() -> void:
	_play_synth_stream("magic", func():
		var rate = 22050
		var duration = 0.22
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		for i in range(count):
			var t = float(i) / rate
			var freq = lerp(700.0, 250.0, float(i) / count)
			var env = 1.0 - (float(i) / count)
			var s = (fmod(t * freq, 1.0) * 2.0 - 1.0) * env * 0.35
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	)

# 8. 소환음
func play_summon() -> void:
	_play_synth_stream("summon", func():
		var rate = 22050
		var duration = 0.25
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		var freqs = [220.0, 330.0, 440.0]
		for i in range(count):
			var t = float(i) / rate
			var note_idx = mini(int(t / 0.08), freqs.size() - 1)
			var freq = freqs[note_idx]
			var env = 1.0 - (float(i) / count)
			var s = (fmod(t * freq, 1.0) * 2.0 - 1.0) * env * 0.35
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	)

# 9. 피격음
func play_hit() -> void:
	_play_synth_stream("hit", func():
		var rate = 22050
		var duration = 0.12
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		for i in range(count):
			var t = float(i) / rate
			var freq = lerp(160.0, 40.0, float(i) / count)
			var env = 1.0 - (float(i) / count)
			var s = (fmod(t * freq, 1.0) * 2.0 - 1.0) * env * 0.5
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	)

# 10. 치유음
func play_heal() -> void:
	_play_synth_stream("heal", func():
		var rate = 22050
		var duration = 0.3
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		var freqs = [329.63, 440.0, 523.25, 659.25]
		for i in range(count):
			var t = float(i) / rate
			var note_idx = mini(int(t / 0.07), freqs.size() - 1)
			var freq = freqs[note_idx]
			var env = 1.0 - (float(i) / count)
			var s = sin(t * freq * TAU) * env * 0.35
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	)

# 11. 승리 팡파레
func play_victory() -> void:
	_play_synth_stream("victory", func():
		var rate = 22050
		var duration = 0.4
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		var freqs = [523.25, 659.25, 783.99, 1046.50]
		for i in range(count):
			var t = float(i) / rate
			var note_idx = mini(int(t / 0.1), freqs.size() - 1)
			var freq = freqs[note_idx]
			var env = 1.0 - (float(i) / count)
			var s = sin(t * freq * TAU) * env * 0.4
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	)

# 12. 골드 획득음
func play_coin() -> void:
	_play_synth_stream("coin", func():
		var rate = 22050
		var duration = 0.2
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		var freqs = [987.77, 1318.51]
		for i in range(count):
			var t = float(i) / rate
			var note_idx = mini(int(t / 0.08), freqs.size() - 1)
			var freq = freqs[note_idx]
			var env = 1.0 - (float(i) / count)
			var s = sin(t * freq * TAU) * env * 0.35
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	)

# 13. 버프음
func play_buff() -> void:
	play_heal()

# 14. 빙결음
func play_freeze() -> void:
	play_magic()


