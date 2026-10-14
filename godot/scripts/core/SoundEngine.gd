# SoundEngine.gd
# Web Audio API와 동일한 원리로 오디오 데이터를 절차적으로 합성하여 재생하는 엔진
# 개선사항: 볼륨 카테고리 분리(BGM/효과음/UI), 설정 저장/복원, 향상된 웨이브 시작음
extends Node

const CONFIG_PATH := "user://sound_config.json"

var muted: bool = false
var master_volume_db: float = 0.0
var sfx_volume_db: float = 0.0
var ui_volume_db: float = 0.0

var _players: Array[AudioStreamPlayer] = []
var _cached_streams: Dictionary = {}

## 같은 **이름**의 소리가 이 간격 안에 다시 요청되면 무시한다.
## 50ms 는 실측 근거가 있다 — 이 게임에서 가장 빠른 정상 반복은 연사 타워의 공격음이고
## 그 최악 간격이 **≈0.119초**다(`TRAIT_INTERVAL["rapid"]=0.3` × 길이 2 보정 0.70 ×
## 모양 0.9615 × 유물 0.8475 × 0.8333). 즉 50ms 잠금은 정상 반복을 **2.4배 여유**로 비껴간다.
const SFX_MIN_INTERVAL_MSEC := 50

## 이름 → 마지막으로 **재생을 허용한** 시각(`Time.get_ticks_msec()`).
## 소리마다 독립이다 — 서로 다른 소리는 서로를 막지 않는다.
var _last_played_msec: Dictionary = {}

func _ready() -> void:
	_load_config()
	# Create audio player pool
	for i in range(12):
		var p = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func _load_config() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file:
			var json := JSON.new()
			var err := json.parse(file.get_as_text())
			if err == OK:
				var data: Dictionary = json.get_data()
				muted = data.get("muted", false)
				master_volume_db = data.get("master_volume_db", 0.0)
				sfx_volume_db = data.get("sfx_volume_db", 0.0)
				ui_volume_db = data.get("ui_volume_db", 0.0)
			file.close()

func _save_config() -> void:
	var data := {
		"muted": muted,
		"master_volume_db": master_volume_db,
		"sfx_volume_db": sfx_volume_db,
		"ui_volume_db": ui_volume_db,
	}
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func toggle_mute() -> bool:
	muted = !muted
	_save_config()
	return muted

func set_master_volume(db: float) -> void:
	master_volume_db = clampf(db, -80.0, 0.0)
	_save_config()

func set_sfx_volume(db: float) -> void:
	sfx_volume_db = clampf(db, -80.0, 0.0)
	_save_config()

func set_ui_volume(db: float) -> void:
	ui_volume_db = clampf(db, -80.0, 0.0)
	_save_config()

func _get_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]

func _play_synth_stream(stream_name: String, generator_func: Callable, category_db: float = 0.0,
		throttle_key: String = "") -> void:
	if muted:
		return

	# ── 1) 이름별 최소 간격 (겹침 방지) ─────────────────────────────────────
	# 왜 필요한가: `_get_player()` 는 **재생 중이 아닌** 플레이어를 준다. 그래서 같은 소리를
	# 한 프레임에 5번 부르면 **5개 플레이어가 같은 파형을 동시에** 재생한다. 파형이 같으니
	# 위상까지 맞아 **단순 합산**되고 `20*log10(5)` = **+14 dB** 가 된다. 즉 음량이 저작된
	# 값이 아니라 "그 순간 몇 마리를 맞혔는가" 로 정해진다.
	# 실재 경로: `Meteor._impact()` 가 폭발 반경의 **모든 적**을 순회하며
	# `enemy.take_damage(dmg, true, mult)` 를 부른다 — 두 번째 인자가 소리 켬이다.
	#
	# ⚠️ **스로틀 키와 파형 키는 다를 수 있다**(2026-09-26, §2.23-3). 기본은 같은 이름이지만,
	#    두 사건이 **같은 파형을 쓰면서 우선순위는 정반대**일 때 키를 나눈다 — 그래야
	#    덜 중요한 소리가 더 중요한 소리를 지우지 못한다(`play_base_hit`).
	# ⚠️ 키를 나눠도 **창 안의 중복은 여전히 막힌다** — 같은 프레임에 3마리가 도착해도 1회다.
	#    스로틀을 **면제**하면 3회가 울려 `20*log10(3)` = +9.5 dB 가 되고, 그건 소리의 세기를
	#    "그 순간 몇 마리가 도착했는가" 가 정하게 만든다 — 스로틀이 애초에 막으려던 것.
	var key := throttle_key if throttle_key != "" else stream_name
	var now := Time.get_ticks_msec()
	var last: int = _last_played_msec.get(key, -1000000)
	if now - last < SFX_MIN_INTERVAL_MSEC:
		return
	_last_played_msec[key] = now

	if not _cached_streams.has(stream_name):
		_cached_streams[stream_name] = generator_func.call()

	var p = _get_player()
	p.stream = _cached_streams[stream_name]
	p.volume_db = master_volume_db + category_db
	# ── 2) 피치 지터 ────────────────────────────────────────────────────────
	# 같은 파형을 비트 단위로 반복하면 기관총이 된다. ±4% 는 음정으로 인지되지 않으면서
	# 반복을 흩뜨린다. (매 재생마다 새로 뽑으므로 같은 소리도 매번 조금씩 다르다)
	p.pitch_scale = randf_range(0.96, 1.04)
	p.play()

# === SYNTHESIS HELPERS ===
func _create_wav(samples: PackedByteArray, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = samples
	return wav

# === UI 사운드 (ui_volume_db 적용) ===
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
	, ui_volume_db)

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
	, ui_volume_db)

## 리롤(주사위 굴림) **전용**음. 감사 §2.6 문제 3 / §5.2 항목 19.
##
## 왜 전용음이 필요한가 — 이 소리 자리는 2026-09-23 까지 `play_tile_rotate()` 였다.
## 그런데 두 사건의 **빈도가 정반대**다:
##   · 타일 회전 = 웨이브마다 수십 번 나는 미세 조작(`JamoBelt` 의 `RotateButton.pressed` 핸들러)
##   · 리롤     = **런 전체에 3~8번뿐**인 자원 소비 결정
##     (`reroll_dice`: 시작 3 · 막 클리어 +1 · 유물 +2 · 새 런에서 3 으로 리셋)
## 즉 **가장 드문 결정이 가장 흔한 조작과 같은 소리**를 내고 있었다. 그러면 그 결정에는
## 고유한 정체성이 없고, 플레이어는 주사위를 썼다는 사실을 소리로 알 수 없다.
## ⚠️ "다른 사건의 소리를 빌려 쓰지 않는다" 는 이 프로젝트의 규칙이다 — 반복 이벤트의
##    소리를 재사용하면 **침묵보다 나쁜 거짓 신호**가 된다(§5.5).
##
## 소리의 구조 — 주사위가 구르다 멈춘다:
##   0.00~0.185초  4연타 '딸깍'. 타격마다 잡음 + 톱니파를 겹치고 음을 조금씩 낮춘다.
##   0.20~0.30초   멈추는 '탁' — 저역(520→180Hz)으로 떨어지며 사라진다.
## 길이 0.30초. 회전음(0.08초)보다 길고 코인(0.20초)보다 길다 — 자원을 쓴 대가의 크기다.
##
## ⚠️ 잡음은 **고정 시드 지역 RNG** 로 만든다. 전역 `randf()` 를 쓰면 첫 리롤 한 번이
##    전역 난수열을 소비해, 난수 소비량에 민감한 봇 게이트(`DifficultyPlaytest`)의
##    판정을 흔든다(그 도구는 시드를 다시 걸어 결정성을 얻는다 — 전역 소비는 그 노력을 깬다).
func play_reroll() -> void:
	_play_synth_stream("reroll", func():
		var rate = 22050
		var duration = 0.30
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		var rng := RandomNumberGenerator.new()
		rng.seed = 20260923
		var tick_times = [0.00, 0.05, 0.10, 0.15]
		for i in range(count):
			var t = float(i) / rate
			var s = 0.0
			for k in range(tick_times.size()):
				var dt = t - float(tick_times[k])
				if dt >= 0.0 and dt < 0.035:
					var env = 1.0 - dt / 0.035
					env = env * env
					var f = 1400.0 - float(k) * 180.0
					s += (rng.randf() * 2.0 - 1.0) * env * 0.22
					s += (fmod(t * f, 1.0) * 2.0 - 1.0) * env * 0.18
			if t >= 0.20:
				var dt2 = t - 0.20
				var env2 = 1.0 - dt2 / 0.10
				var f2 = lerp(520.0, 180.0, dt2 / 0.10)
				s += (fmod(t * f2, 1.0) * 2.0 - 1.0) * env2 * 0.30
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	, ui_volume_db)

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
	, ui_volume_db)

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
	, ui_volume_db)

# === 전투 효과음 (sfx_volume_db 적용) ===
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
	, sfx_volume_db)

# "방어도가 이 타격을 전부 먹었다" 는 사건의 소리(§2.20).
#
# ⚠️ §5.2 32 (C), 2026-10-01 — 파형을 **짧고 낮게** 다시 썼다. 예전에는 **0.16초 · 180→340Hz
# 상승**음이었다. 이 프로젝트의 불변식은 **"길이 순서 = 강도 순서"** 인데 `play_hit()` 이 0.12초라,
# 막힌 타격이 맞은 타격보다 **길고 밝게** 들렸다 — 아무 일도 안 일어난 타격이 더 세게 들린다는
# 뜻이다. 지금은 **0.09초 · 200→100Hz 하강**음이라 `hit` 보다 짧고 낮다.
#
# ⚠️ **바뀐 것은 길이와 주파수 *방향*이다**(상승 → 하강). **파형 종류는 안 바뀌었다** — 예전 판도
#    `sin()` 이었다(밝기 = 부호 변화 횟수가 **108 → 18** 로 떨어졌다). `hit` 과의 종류 차이
#    (`hit` 은 **톱니파** — `fmod(t*f,1)*2-1`, 이쪽은 **사인**)는 **원래부터** 있었다.
#    ⚠️ 이 문단은 2026-10-01 밤에 정정했다 — 그 전에는 *"파형 종류를 갈랐다"* 고 적혀 있었는데,
#    `main/` 워크트리에 남아 있던 고치기 전 판을 열어 보니 **둘 다 `sin()`** 이었다.
#
# ⚠️ `hit` 과 **구별되어야 한다** — §2.23 이 *"귀로 구별되지 않는다"* 로 이미 한 번 걸렸다.
# 그래서 **길이만 줄이지 않고 주파수 방향까지 뒤집었다**(상승 → 하강). 주파수 대역도 겹치지
# 않는다(`hit` 은 40Hz 까지 내려간다).
func play_shield() -> void:
	_play_synth_stream("shield", func():
		var rate = 22050
		var duration = 0.09
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		for i in range(count):
			var t = float(i) / rate
			var freq = lerp(200.0, 100.0, float(i) / count)
			var env = pow(1.0 - (float(i) / count), 1.4)
			var s = sin(t * freq * TAU) * env * 0.45
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	, sfx_volume_db)

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
	, sfx_volume_db)

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
	, sfx_volume_db)

## `hit` — 적이 맞았을 때. `throttle_key` 를 넘기면 **파형은 그대로 `hit` 이고 스로틀 창만** 바뀐다.
##
## ⚠️ 왜 키를 나눌 수 있어야 하는가 (§2.23-3): 스로틀은 **이름별**이라, 적이 무더기로 맞는
##    프레임에 기지 피격이 겹치면 **기지 피격음이 통째로 삼켜진다**(실측). 두 사건의 극성은
##    정반대인데(적 피격 = 내가 잘 하고 있다 / 기지 피격 = 런이 끝나가고 있다) 소리 이름이
##    같아서 **덜 중요한 소리가 더 중요한 소리를 지운다.**
func play_hit(throttle_key: String = "hit") -> void:
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
	, sfx_volume_db, throttle_key)

## 기지 피격 전용 진입점 (§2.23-3, 2026-09-26) — **2026-10-03 부터 전용 파형이다.**
##
## ⚠️ **예전에는 `play_hit()` 과 같은 파형(`hit`)을 쓰고 스로틀 키만 나눴다.** 그래서
##    삼켜짐은 없앴지만 **귀로는 여전히 구별되지 않았다** — 감사 §5.2 35 의 (C)·(D) 가
##    그대로 남아 있었다. 두 사건의 극성은 정반대다(내가 잘 하고 있다 / 런이 끝나간다).
##
## 이제 파형이 다르다 — 적 피격보다 **낮고 길다**(160→40 Hz · 0.12초 → 90→28 Hz · 0.30초).
## ⚠️ **낮고 긴 쪽이 기지 피격**인 이유: 적 피격은 초당 수십 번 나는 '잔타격' 이라 짧고
##    높아야 하고, 기지 피격은 런당 드문 '큰 사건' 이라 길고 낮아야 한다. 이 프로젝트의
##    **길이=강도** 규칙(`play_final_victory` .95 > `play_defeat` .80 > …)과 같은 방향이다.
## ⚠️ **면제가 아니다** — 스로틀 창은 그대로 나뉘어 있다. 같은 프레임에 3마리가 도착해도
##    **1회**다. 면제하면 3회가 울려 `20*log10(3)` = **+9.5 dB** 가 되고, 그건 소리의 세기를
##    "그 순간 몇 마리가 도착했는가" 가 정하게 만든다 — 스로틀이 애초에 막으려던 것.
func play_base_hit() -> void:
	_play_synth_stream("hit_base", func():
		var rate = 22050
		var duration = 0.30
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		for i in range(count):
			var t = float(i) / rate
			var freq = lerp(90.0, 28.0, float(i) / count)
			var env = 1.0 - (float(i) / count)
			var s = (fmod(t * freq, 1.0) * 2.0 - 1.0) * env * 0.55
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	, sfx_volume_db, "hit_base")

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
	, sfx_volume_db)

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
	, sfx_volume_db)

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
	, sfx_volume_db)

## 유물 구매 전용 (§2.22-6 재배치로 주인이 1곳이 됐다).
##
## ⚠️ **`play_heal()` 이다 — `play_magic()` 이 아니다**(2026-10-01 복원). `play_heal` 의
##    E5→A5→C6→E6 상행 아르페지오는 **이 게임에서 유일하게 '좋은 일' 을 뜻하는 파형**이고,
##    §2.22 의 결정은 그 파형을 *좋은 사건*(유물 구매)에 남기는 것이었다. 그런데 본문이
##    `play_magic()` 으로 바뀌어 있었다 — 그러면 유물 구매가 **밀어내기와 같은 소리**가 되고
##    (둘 다 내려가는 스윕), `play_heal` 은 다시 **진짜 고아**가 되어 §2.22 의 정정이 뒤집힌다.
##    `tools/OrphanSoundProbe.EXPECTED_ALIASES` 와 감사 §2.22-6 이 둘 다 `play_heal` 을 기대한다.
func play_buff() -> void:
	play_heal()

func play_freeze() -> void:
	play_magic()

# 웨이브 시작음 - 전용 사운드 (더 웅장하고 긴장감 있는 소리)
func play_wave_start() -> void:
	_play_synth_stream("wave_start", func():
		var rate = 22050
		var duration = 0.5
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		var freqs = [196.0, 261.63, 329.63, 392.0, 523.25]
		for i in range(count):
			var t = float(i) / rate
			var note_idx = mini(int(t / 0.1), freqs.size() - 1)
			var freq = freqs[note_idx]
			var env = (1.0 - float(i) / count) * (1.0 - float(i) / count)
			var s = sin(t * freq * TAU) * env * 0.5
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	, sfx_volume_db)

# 보스 등장음 — 이 세트에서 **가장 길다**(0.75초. 다음이 웨이브 시작 0.5초, 그다음 승리 0.4초).
#
# 음높이는 낮게 **유지**한다 — 110Hz → 82.41Hz 를 각각 0.35초씩 깐다. `play_hit()` 도 40Hz 까지
# 내려가지만 그건 0.12초 동안 스쳐 지나가는 스윕이라 '낮은 음' 으로 들리지 않는다. 이 소리는
# 낮은 음을 **붙잡고** 있어서 웨이브 시작음(196→523Hz, 밝게 올라감)과 확실히 갈린다.
# 실측: 영교차율 189/s 대 웨이브 시작음 596/s (`tools/BossEntranceProbe.gd`).
#
# 왜 웨이브 시작음을 재사용하지 않는가: `play_wave_start()` 는 **매 웨이브** 울리는 전용음이라
# 보스 등장에 같은 소리를 쓰면 "다음 웨이브 시작" 과 똑같이 들려 **정보가 사라진다** —
# 그 웨이브는 이미 5라운드 전에 시작됐는데 말이다. 그래서 **반대 방향**(내려가는 저음)으로 만든다.
#
# 다른 효과음과 달리 **어택이 느리다**(0.1초). 세트의 나머지는 전부 즉시 어택이라
# 이 소리만 '다가온다' 로 들린다 — 보스가 걸어오는 것과 맞는다.
func play_boss_entrance() -> void:
	_play_synth_stream("boss_entrance", func():
		var rate = 22050
		var duration = 0.75
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		# 낮은 두 음을 내려가며 깐다 (110Hz → 82.41Hz). 세트 최저음이다.
		var freqs = [110.0, 82.41]
		for i in range(count):
			var t = float(i) / rate
			var note_idx = mini(int(t / 0.35), freqs.size() - 1)
			var freq = freqs[note_idx]
			var attack = minf(1.0, t / 0.1)
			var env = attack * (1.0 - float(i) / count)
			var body = fmod(t * freq, 1.0) * 2.0 - 1.0     # 톱니 — 거친 무게
			var sub = sin(t * (freq * 0.5) * TAU)          # 한 옥타브 아래 — 배 밑의 웅웅거림
			var s = (body * 0.6 + sub * 0.4) * env * 0.45
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	, sfx_volume_db)

# 보스 **처치**음 — 등장음의 **거울상** (§5.2 30 (A), 2026-10-01).
#
# 왜 필요한가: 등장은 6종 연출(전용음 · 실루엣 1.9배 · 흔들림 · 섬광 · 배너 · 전용 HP바)을
# 받는데, 처치는 잡몹과 **완전히 같았다** — 잡몹과 같은 `play_coin` 이었다. 보상의 양은
# 계약대로 **8~12배**인데(`+8 G` vs `+1 G`) 표현이 1배였다. 계약 문구는
# `TowerDefenseMain.gd:297` 의 **"5라운드마다 보스 등장 · 처치 시 대보상"** 이다.
# 실측 `tools/BossDeathProbe.gd`: 표현 서명도 소리도 잡몹과 **동일**했다.
#
# ⚠️ **등장음의 거울상으로 만든다** — 두 소리는 한 사건의 앞뒤다.
#   · 등장: **하강** 110 → 82.41Hz · **느린 어택**(0.1초, '다가온다') · 배 밑 **한 옥타브 아래**
#   · 처치: **상행** 82.41 → 110 → 164.81Hz · **즉시 어택**('터진다') · 위쪽 **5도**
#   같은 톱니 계열이라 '같은 보스' 로 들리고, **방향과 어택이 반대**라 한 번에 갈린다.
#   상행 = '좋은 일'(이 세트에서 `victory`·`heal` 이 상행이다) · 낮은 음역 = 무게.
#
# ⚠️ **`play_final_victory()` 를 재사용하지 않는다** — 그건 **런의 마지막 문장**이고
#    런당 1회다. 보스 처치는 런당 **12회**(3막 × 4마리)라, 재사용하면 막마다 그 문장이
#    반복되어 마지막 한 번이 특별하지 않게 된다 — `play_victory` 를 런 승리에 거부한
#    것과 **같은 판단**이다(§2.8).
#
# ⚠️ **길이 0.70초 < 등장 0.75초.** 이 세트의 불변식은 **"길이 순서 = 강도 순서"** 다.
#    등장은 '예고', 처치는 '결과' 라 결과가 예고보다 길 이유가 없다. 동시에
#    `defeat`(0.80초) · `final_victory`(0.95초) 보다 **반드시 짧아야** 한다 — 그 둘은 런의 끝이다.
func play_boss_death() -> void:
	_play_synth_stream("boss_death", func():
		var rate = 22050
		var duration = 0.70
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		# 등장음의 두 음(110 · 82.41)을 **거꾸로** 놓고 한 음 더 올린다 — 내려온 것이 돌아간다.
		var freqs = [82.41, 110.0, 164.81]
		var note: float = duration / float(freqs.size())
		for i in range(count):
			var t = float(i) / rate
			var idx = mini(int(t / note), freqs.size() - 1)
			var freq = freqs[idx]
			var t_in: float = t - float(idx) * note
			# 즉시 어택 — 등장음의 0.1초 어택과 **정반대**다('다가온다' 가 아니라 '터진다').
			var env = minf(1.0, t_in / 0.01) * (1.0 - float(i) / count)
			var body = fmod(t * freq, 1.0) * 2.0 - 1.0      # 톱니 — 등장음과 같은 계열
			var fifth = sin(t * (freq * 1.5) * TAU) * 0.35  # 위쪽 5도 — 등장음의 '아래' 와 반대
			var s = (body * 0.65 + fifth) * env * 0.42
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	, sfx_volume_db)

# ── 런의 마지막 문장 (2026-09-23) ────────────────────────────────────────────
#
# 60라운드를 끝낸 순간과 기지가 함락된 순간에 **오디오가 0건**이었다. 런당 1회뿐인
# 최상위 사건인데 무음이라, 감정적 마침표가 없었다(`GAME_FEEL_AUDIT.md` §2.8).
#
# `play_victory()` 를 재사용하지 않은 이유가 **이 두 함수의 존재 이유**다.
# 그 소리는 이미 `DefenseField._grant_round_reward()` 에서 **라운드가 끝날 때마다**
# (런당 수십 번) 울리고 있다. 승리에 다시 쓰면 "60라운드를 끝냈다" 와 "또 한 라운드
# 끝났다" 가 같은 소리가 된다 — **침묵보다 나쁘다(거짓 신호).**
# 보스 등장음에서 `play_wave_start()` 를 거부한 것과 **같은 판단**이다.
#
# 그래서 둘 다 **여기서만** 쓴다(호출처는 `TowerDefenseMain._on_game_over` 하나).
# 강도는 게임 중요도에 비례해야 한다 — 세트 길이 순서가 그것을 보장한다:
#   런 승리 0.95초 > 함락 0.80초 > 보스 등장 0.75초 > **보스 처치 0.70초** > 웨이브 시작 0.50초
#   > (기존) 승리 0.40초
# ⚠️ `boss_death` 는 2026-10-01 에 이 목록 **가운데**로 들어왔다(§5.2 30). 등장보다 짧고
#    웨이브 시작보다 길다 — '예고' 와 '결과' 가 한 쌍이고, 둘 다 런의 끝(`defeat`·
#    `final_victory`)보다는 아래다. 새 소리를 넣을 때 이 줄을 **갱신하지 않으면** 이 주석이
#    조용히 거짓이 된다(§2.15 가 문구 드리프트로 걸렸던 그 방식).

## 런 승리 — 6음 상행. `play_victory()` 의 4음(C5-E5-G5-C6)을 **이어받아** 두 음 더 올린다.
## 같은 음계라 "더 큰 승리" 로 들리지, 다른 곡으로 들리지 않는다.
func play_final_victory() -> void:
	_play_synth_stream("final_victory", func():
		var rate = 22050
		var duration = 0.95
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		var freqs = [523.25, 659.25, 783.99, 1046.50, 1318.51, 1567.98]
		var note: float = duration / float(freqs.size())
		for i in range(count):
			var t = float(i) / rate
			var idx = mini(int(t / note), freqs.size() - 1)
			var freq = freqs[idx]
			var t_in: float = t - float(idx) * note
			var is_last: bool = idx == freqs.size() - 1
			var env: float
			if is_last:
				# 마지막 음은 **길게 남긴다.** 마침표는 여운이 있어야 마침표다.
				env = minf(1.0, t_in / 0.05) * (1.0 - float(i) / count)
			else:
				# 중간 음들은 짧게 끊어 '올라간다' 를 또렷하게 만든다.
				env = minf(1.0, t_in / 0.012) * (1.0 - t_in / note * 0.35)
			var tone = sin(t * freq * TAU)
			var fifth = sin(t * (freq * 1.5) * TAU) * 0.28     # 5도 — 나팔의 몸통
			var oct = sin(t * (freq * 2.0) * TAU) * 0.18       # 옥타브 — 반짝임
			var s = (tone * 0.6 + fifth + oct) * env * 0.34
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	, sfx_volume_db)

## 기지 함락 — 4음 하행(G4-E4-C4-G3). 승리음과 **정반대 방향**이라 한 번에 구분된다.
## 낮은 음을 깔아 '무게' 를 준다 — 이 게임에서 유일하게 **나쁜** 클라이맥스다.
func play_defeat() -> void:
	_play_synth_stream("defeat", func():
		var rate = 22050
		var duration = 0.8
		var count = int(rate * duration)
		var bytes = PackedByteArray()
		bytes.resize(count)
		var freqs = [392.0, 329.63, 261.63, 196.0]
		var note: float = duration / float(freqs.size())
		for i in range(count):
			var t = float(i) / rate
			var idx = mini(int(t / note), freqs.size() - 1)
			var freq = freqs[idx]
			var t_in: float = t - float(idx) * note
			# 어택이 느리다(0.06초) — '떨어진다' 는 즉각적이지 않다.
			# 보스 등장음과 같은 이유로 느린 어택을 쓴다.
			var env = minf(1.0, t_in / 0.06) * (1.0 - float(i) / count)
			var tone = sin(t * freq * TAU)
			var sub = sin(t * (freq * 0.5) * TAU) * 0.5        # 한 옥타브 아래 — 배 밑의 웅웅거림
			var s = (tone * 0.55 + sub * 0.45) * env * 0.42
			bytes[i] = int(clamp((s + 1.0) * 127.5, 0, 255))
		return _create_wav(bytes, rate)
	, sfx_volume_db)
