extends Node
## §2.23 — 기지 피격이 **적 피격과 같은 소리**였다 — 삼켜짐과 **귀 구별**을 **둘 다** 고쳤다
## — **✅ 고침 (2026-09-26 §5.2 35 (B) 삼켜짐 · 2026-10-03 §5.2 35 (C)·(D) 귀 구별)**
##
## ## 무엇이 문제였나
##
## `DefenseField._on_enemy_reached_base()` 는 **바로 다음 줄 주석에서** *"기지 피격은 가장 강한
## 타격감이 필요한 순간"* 이라 적고, 그 요구를 **시각만** 받았다(흔들림 7.0 + 붉은 섬광 0.18).
## 소리는 `SoundEngine.play_hit()` — **적이 맞을 때와 같은 이름**이었다.
##
## `SoundEngine` 의 스로틀은 **이름별**이다(`_last_played_msec[stream_name]`, 50 ms).
## 이름이 같다는 것은 두 가지를 뜻했다:
##
## 1. **같은 파형이 나므로 귀로 구별할 수 없다** — "내가 때렸다" 와 "내 기지가 맞았다" 가
##    같은 소리다. 두 사건의 극성이 반대인데도.
## 2. ⚠️ **기지 피격음이 적 피격음에 삼켜진다** — 적 피격이 50 ms 안에 먼저 났다면
##    기지 피격의 `play_hit()` 은 **스로틀에 막혀 나지 않았다.** 즉 **덜 중요한 소리가
##    더 중요한 소리를 지운다**(우선순위 역전).
##
## ## 고침 1 — **스로틀 면제가 아니라 스로틀 키 분리** (2026-09-26, (B))
##
## ```gdscript
## func _play_synth_stream(stream_name, generator_func, category_db = 0.0,
##         throttle_key: String = "") -> void:     # ← 스로틀 키를 파형 키에서 분리
##     var key := throttle_key if throttle_key != "" else stream_name
##
## func play_hit(throttle_key: String = "hit") -> void:
##     _play_synth_stream("hit", func(): ... , sfx_volume_db, throttle_key)
##
## func play_base_hit() -> void:
##     play_hit("hit_base")                        # 파형은 `hit`, 창은 `hit_base`
## ```
##
## ⚠️ **왜 '면제' 가 아닌가.** 감사 §5.2 35 의 (B) 는 *"스로틀 면제"* 라고 적었지만, 면제하면
##    같은 프레임에 3마리가 도착할 때 **3회**가 울린다 → `20*log10(3)` = **+9.5 dB**. 그러면
##    소리의 세기를 *"그 순간 몇 마리가 도착했는가"* 가 정하게 되는데, **그건 스로틀이 애초에
##    막으려던 것**이다. 창을 **나누면** 두 목표가 동시에 선다 — 적 피격에게 안 삼켜지고,
##    자기들끼리는 여전히 1회로 접힌다(실측 `three_arrivals before=10 after=11`).
##
## ## 고침 2 — **기지 피격이 자기 파형을 갖는다** (2026-10-03, (C)·(D))
##
## (B) 는 **창만** 나눴고 파형은 `hit` 하나였다 — 그래서 *"귀로 구별 불가"* 가 남았다.
## (C) 가 그 남은 것을 닫는다: `play_base_hit` 이 **자기 스트림**(`hit_base`)을 쓴다.
##
## ```gdscript
## func play_base_hit() -> void:
##     _play_synth_stream("hit_base", func(): ... , sfx_volume_db, "hit_base")
##     #   ↑ 하강 90 → 28 Hz · 0.30 s · amp 0.55
## ```
##
## ⚠️ **이것이 (B) 가 일부러 피했던 *'새 소리'* 다.** 감독이 2026-10-03 에 그 선택을 뒤집었다
##    (*"남은 문제들을 해결해줘"*). 근거는 *"로직은 있는데 표현이 부족한 사건"* 이다 —
##    소리 채널은 **이미** 있었고(`play_base_hit`), 결함은 *"그 소리가 일상적인 적 피격과
##    똑같이 들린다"* 였다. **없던 효과를 더한 게 아니라 잘못 전달하던 표현을 고친 것**이다.
##    ⚠️ 대가는 **파형 키가 둘이 된 것**(`hit` · `hit_base`) — 새 소리 1개다.
##
## ### (D) 사다리 — 길이 = 강도
##
## `hit` 은 **0.12 s** 로 19개 중 **4번째로 짧다**. 런을 끝낼 수 있는 사건이 가장 약한 칸에
## 있었다는 뜻이다(감사 §2.23-5). `hit_base` 를 **0.30 s** 로 두어 **2.5배**로 벌렸다 —
## `play_reroll`·`play_heal` 과 같은 칸이고, 런 종료음 `play_defeat`(0.80 s) 아래다.
## ⚠️ **되돌리기 쉬운 지점** — `SoundEngine.play_base_hit` 안의 `var duration = 0.30` 한 줄이다.
##
## ## 측정 결과 (두 고침 뒤)
##
## | | 실측 |
## |---|---|
## | 기지 피격이 내는 소리 | `["play_base_hit"]` → 스로틀 키 `["hit_base"]` |
## | 적 피격이 내는 소리 | `["play_hit"]` → 스로틀 키 `["hit"]` — **다른 창** |
## | 파형 캐시 | `["hit_base"]` — **전용 파형을 갖는다**(고침 2) |
## | 두 파형이 같은가 | **다르다**(바이트 비교 · S3) |
## | 길이 | 기지 `0.30 s` > 적 `0.12 s` (**2.5배** · S6) |
## | 같은 프레임에 적 피격 → 기지 피격 | **재생 수가 는다**(삼켜짐 해소 · `9 → 10`) |
## | 같은 프레임 3마리 도착 | 여전히 **1회**(`10 → 11`) — 창을 나눠도 접힌다 |
## | 다른 이름(양성 대조) | 같은 프레임에도 **새로 난다** |
## | `_juice_base_hit()` 안의 `SoundEngine` 호출 | **0건** (시각 전용 — 그대로다) |
## | `_update_low_hp_warning()` 안의 `SoundEngine` 호출 | **0건** (그대로다) |
##
## ## ⚠️ 남은 것 — 이 고침이 **답하지 않은** 질문
##
## ① **사다리 위쪽은 여전히 비어 있다** — `hit_base` 0.30 s 와 런 종료음 `defeat` 0.80 s
##    사이가 **2.7배**다. *"기지가 위험하다"* 는 **중간 단계 소리는 여전히 없다**
##    (`play_wave_start` 0.50 s 가 가장 가깝다). ⚠️ 그건 **새 효과**에 가까우므로
##    *"효과를 많이 넣는 것이 목표가 아니다"* 와 만난다 — **감독 판단**으로 남긴다.
## ② **적 피격 `hit` 의 순위는 그대로 4번째다** — 이건 **의도**다(§5.2 32 (C): 실패한 타격이
##    성공한 타격보다 짧아야 한다). 그래서 S6 은 적 피격에 대해 **절대 순위를 계약으로 삼지
##    않고** *"하위 1/4"* 만 본다. 반면 **기지 피격은 하위 1/4 밖**이어야 한다 — 그게 (D) 다.
##
## ⚠️ **`소음 금지` 원칙과의 관계** — 기지 피격은 **이미** 소리를 내고 있었다. 고침 2 는 그
##    소리를 *다르게* 만들었을 뿐 **재생 횟수를 늘리지 않는다**(재생 수 1 → 2 는 고침 1 의
##    효과이고, 그때 이미 일어났다). ⚠️ 다만 **파형은 하나 늘었다** — 그게 (C) 의 대가다.
##
## 선택지는 감사 §5.2 35.

const PREFIX := "BASE_HIT"
const MainScene = preload("res://scenes/TowerDefenseMain.tscn")
const EnemyUnitScript = preload("res://scripts/tower/EnemyUnit.gd")
const DefenseFieldScript = preload("res://scripts/tower/DefenseField.gd")
const ENGINE_PATH := "res://scripts/core/SoundEngine.gd"
const FIELD_PATH := "res://scripts/tower/DefenseField.gd"
const MAIN_PATH := "res://scripts/ui/TowerDefenseMain.gd"

## 적 피격의 **파형** 이름. ⚠️ 2026-10-03 (C) 부터 기지 피격과 **공유하지 않는다** —
## 이 이름은 이제 *"적 피격의 파형"* 이라는 뜻일 뿐이다(공유하던 시절의 이름이 남았다).
const SHARED_SOUND := "hit"
## 기지 피격의 **전용 파형 + 전용 스로틀 창** 이름 (2026-10-03, (C)).
const BASE_THROTTLE_KEY := "hit_base"
## 적 피격(`hit`)의 길이(초). 19개 중 4번째로 짧다 — 이건 **의도**다(§5.2 32 (C)).
const HIT_DURATION := 0.12
## 기지 피격(`hit_base`)의 길이(초). `hit` 의 **2.5배** — (D) 사다리.
const BASE_HIT_DURATION := 0.30

var failures := 0


func check(cond: bool, msg: String, tag: int) -> void:
	if not cond:
		failures += 1
		print("FAIL_SECTION S%d :: %s" % [tag, msg])
		push_error("S%d %s" % [tag, msg])


func _ready() -> void:
	# ⚠️ 첫 줄 — `muted` 면 `_play_synth_stream()` 이 즉시 return 해 이 절이 공허해진다.
	#    필드 직접 대입이라 `_save_config()` 를 지나지 않는다(설정 파일 안전).
	SoundEngine.muted = false

	# ── S1. 정적 — 두 사건이 **같은 스트림 이름**을 쓴다 ──────────────────────
	var field_src := FileAccess.get_file_as_string(FIELD_PATH)
	var enemy_src := FileAccess.get_file_as_string("res://scripts/tower/EnemyUnit.gd")
	var base_calls := _sound_calls_in(field_src, "_on_enemy_reached_base")
	var hit_calls := _sound_calls_in(enemy_src, "take_damage")
	print("%s base_hit_calls=%s enemy_hit_calls=%s" % [PREFIX, str(base_calls), str(hit_calls)])
	check(base_calls == ["play_base_hit"],
		"기지 피격은 **전용 진입점**을 쓴다 (실측 %s)" % str(base_calls), 1)
	check(hit_calls.has("play_hit"),
		"적 피격은 `play_hit` 을 쓴다 (실측 %s)" % str(hit_calls), 1)
	check(not base_calls.has("play_hit") and not hit_calls.has("play_base_hit"),
		"⚠️ 두 사건이 **서로 다른 진입점**을 쓴다 — 같으면 창도 같아져 삼켜짐이 돌아온다 (기지 %s · 적 %s)"
			% [str(base_calls), str(hit_calls)], 1)

	# ── S2. 정적 — 시각 채널과 소리 채널이 **다른 함수**에 있다 ────────────────
	var juice_calls := _sound_calls_in(field_src, "_juice_base_hit")
	var low_hp_calls := _sound_calls_in(FileAccess.get_file_as_string(MAIN_PATH),
		"_update_low_hp_warning")
	print("%s juice_base_hit_calls=%s low_hp_warning_calls=%s"
		% [PREFIX, str(juice_calls), str(low_hp_calls)])
	check(juice_calls.is_empty(),
		"`_juice_base_hit` 은 **시각 전용**이다 — 소리는 호출자에서 난다", 2)
	check(low_hp_calls.is_empty(),
		"저체력 경고도 **시각 전용**이다 — 위험 구간 경고에 소리가 없다", 2)

	# ── S3~S5. 런타임 — 실제 경로로 재생을 센다 ──────────────────────────────
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._is_loading_state = true
	main.start_new_game()
	await get_tree().process_frame
	await get_tree().process_frame
	var field = main.defense_field
	check(field != null, "필드를 못 얻었다 — 아래 절이 공허해진다", 3)
	if field == null:
		print("%s FAILURES=%d" % [PREFIX, failures])
		get_tree().quit(failures)
		return
	field.base_hp = field.max_base_hp      # 피격이 런을 끝내지 않게

	#   적 하나를 세운다(막대·라벨이 없어도 소리 경로는 돈다).
	var enemy = EnemyUnitScript.new()
	enemy.hp = 500.0
	enemy.max_hp = 500.0
	enemy.shield = 0.0

	# ── S3. 기지 피격 **단독** — 어떤 소리가 나는가 ──────────────────────────
	SoundEngine._last_played_msec.clear()
	SoundEngine._cached_streams.clear()
	field._on_enemy_reached_base(enemy, 1)
	var solo: Array = SoundEngine._last_played_msec.keys()
	solo.sort()
	var cache: Array = SoundEngine._cached_streams.keys()
	cache.sort()
	print("%s base_hit_solo_plays=%s waveform_cache=%s" % [PREFIX, str(solo), str(cache)])
	check(solo == [BASE_THROTTLE_KEY],
		"기지 피격은 **자기 창**(`%s`)으로 낸다 (실측 %s)" % [BASE_THROTTLE_KEY, str(solo)], 3)
	# ⚠️ **2026-10-03 (C) 로 이 자리의 계약이 뒤집혔다.** 전에는 *"파형 캐시가 `hit` 하나뿐"*
	#    을 단언했고 그것이 *'새 소리 0'* 의 구조적 증거였다. 이제는 **자기 파형을 갖는 것이
	#    계약**이다 — (B) 의 그 증거를 (C) 가 일부러 폐기했다.
	check(cache == [BASE_THROTTLE_KEY],
		"파형 캐시는 `%s` — 기지 피격이 **자기 파형**을 쓴다 (실측 %s)"
			% [BASE_THROTTLE_KEY, str(cache)], 3)
	#   ⚠️ **키가 다르다 ≠ 소리가 다르다.** `_play_synth_stream("hit_base", …)` 안에 `hit` 의
	#      생성기를 그대로 복사해 넣으면 **키만 다르고 귀로는 같다** — 그러면 (C) 는 아무것도
	#      안 한 것이다. 그래서 **바이트로** 비교한다(`RerollSoundProbe._same_wave` 와 같은
	#      기법 — 그쪽은 *별칭*을 잡으려고, 이쪽은 *"정말 달라졌나"* 를 잡으려고 쓴다).
	SoundEngine.play_hit()                       # 적 피격 파형도 캐시에 올린다
	var w_base: AudioStreamWAV = SoundEngine._cached_streams.get(BASE_THROTTLE_KEY)
	var w_hit: AudioStreamWAV = SoundEngine._cached_streams.get(SHARED_SOUND)
	var same := _same_wave(w_base, w_hit)
	var len_base := _wav_len(w_base)
	var len_hit := _wav_len(w_hit)
	print("%s waveform_same=%s base_len=%.3f hit_len=%.3f"
		% [PREFIX, str(same), len_base, len_hit])
	check(not same,
		"⚠️ 기지 피격 파형이 적 피격 파형과 **다르다** — 같으면 (C) 는 키만 바꾼 것이다", 3)
	check(is_equal_approx(len_base, BASE_HIT_DURATION),
		"기지 피격 파형 길이가 %.2fs 다 (실측 %.3f)" % [BASE_HIT_DURATION, len_base], 3)
	check(len_base > len_hit,
		"기지 피격이 적 피격보다 **길다** (%.3f > %.3f) — (D) 사다리" % [len_base, len_hit], 3)

	# ── S4. ⚠️ 우선순위 역전 — 적 피격이 50 ms 안에 먼저 나면 기지 피격음이 **삼켜진다**
	#
	#   ⚠️ `_last_played_msec` 은 딕셔너리라 **몇 번 났는지 셀 수 없다**(덮어쓴다).
	#      그래서 **풀에서 실제로 재생 중인 플레이어 수**를 센다.
	#   ⚠️ 그리고 **양성 대조**가 필요하다 — 수가 아예 안 변하는 환경이면
	#      "안 늘었다" 가 공허해진다(다른 이름은 늘어나는지 본다).
	SoundEngine._last_played_msec.clear()
	var before := _playing_count()
	# ⚠️ **풀이 포화되면 이 절이 공허해진다** — 12개가 전부 재생 중이면 `_get_player()` 가
	#    `_players[0]` 을 돌려주고 다시 `play()` 해도 수가 안 늘어난다. 여유를 단언한다.
	check(before <= SoundEngine._players.size() - 3,
		"풀에 여유가 있다(%d/%d 재생 중) — 포화되면 '안 늘었다' 가 공허해진다"
			% [before, SoundEngine._players.size()], 4)
	SoundEngine.play_hit()                       # 적 피격 대역 — 진짜 게임 경로와 같은 이름
	var mid := _playing_count()
	SoundEngine.play_coin()                      # 양성 대조 — **다른 이름**
	var mid2 := _playing_count()
	check(mid2 == mid + 1,
		"양성 대조: 다른 이름은 같은 프레임에 새로 난다 (%d → %d) — 수가 안 변하면 이 절이 공허하다"
			% [mid, mid2], 4)

	SoundEngine._last_played_msec.clear()
	var b2 := _playing_count()
	field._on_enemy_reached_base(enemy, 1)       # 적 피격 없이 → 나야 한다
	var solo2 := _playing_count()
	check(solo2 == b2 + 1,
		"대조군: 적 피격이 없으면 기지 피격음이 **난다** (%d → %d)" % [b2, solo2], 4)

	SoundEngine._last_played_msec.clear()
	var b3 := _playing_count()
	enemy.take_damage(10.0, true, 1.0)           # 적 피격 → `hit` 재생
	var after_enemy := _playing_count()
	field._on_enemy_reached_base(enemy, 1)       # 기지 피격 → **같은 이름**
	var after_base := _playing_count()
	print("%s collision before=%d after_enemy_hit=%d after_base_hit=%d"
		% [PREFIX, b3, after_enemy, after_base])
	check(after_enemy == b3 + 1, "적 피격은 소리를 낸다 (%d → %d)" % [b3, after_enemy], 4)
	check(after_base == after_enemy + 1,
		"⚠️ 기지 피격음이 적 피격음에 **삼켜지지 않는다** (%d → %d 이어야 하는데 %d)"
			% [after_enemy, after_enemy + 1, after_base], 4)

	# ── S5. 같은 프레임에 여러 마리가 도착해도 한 번뿐이다 ────────────────────
	SoundEngine._last_played_msec.clear()
	var b4 := _playing_count()
	field._on_enemy_reached_base(enemy, 1)
	field._on_enemy_reached_base(enemy, 1)
	field._on_enemy_reached_base(enemy, 1)
	var after_three := _playing_count()
	print("%s three_arrivals before=%d after=%d" % [PREFIX, b4, after_three])
	check(after_three == b4 + 1,
		"같은 프레임 3마리 도착 → 소리 1회 (기대 %d, 실측 %d)" % [b4 + 1, after_three], 5)

	enemy.free()

	# ── S6. 길이 순서 — 이 사건이 소리의 **사다리** 어디에 있는가 ──────────────
	var durations := _sound_durations()
	var sorted_d := durations.values()
	sorted_d.sort()
	var rank := sorted_d.find(HIT_DURATION) + 1
	print("%s hit_duration=%.2f rank=%d/%d shortest5=%s"
		% [PREFIX, HIT_DURATION, rank, sorted_d.size(), str(sorted_d.slice(0, 5))])
	# ⚠️ **적 피격에는 절대 순위를 계약으로 삼지 마라.** 2026-10-01 에 `play_shield` 가
	#    0.16 → 0.09 로 짧아지면서(§5.2 32 (C)) `hit` 의 순위가 3 → 4 로 밀렸고, 이 단언이
	#    **거짓 빨강**이 됐다. 순위는 **다른 소리의 길이에 의존**하므로 계약은 *"짧은 편인가"*
	#    이지 *"정확히 3번째인가"* 가 아니다(`OrphanSoundProbe` 의 개수 단언과 **같은 부류**).
	var quarter: int = maxi(1, int(sorted_d.size() / 4.0))
	check(durations.size() == 19, "길이를 19개 읽었다 (실측 %d)" % durations.size(), 6)
	check(rank > 0 and rank <= quarter,
		"적 피격 `hit`(%.2fs)은 %d개 중 최단 %d번째 — 하위 1/4 안이다(의도: 실패한 타격이 짧다)"
			% [HIT_DURATION, sorted_d.size(), rank], 6)
	# ── (C)·(D) 로 **뒤집힌** 계약 (2026-10-03) ────────────────────────────────
	#   전에는 이 자리가 *"`play_base_hit` 은 자기 파형을 갖지 않는다"* 를 단언했다(위임 증거).
	#   이제는 **갖는 것이 계약**이고, 그것도 **적 피격보다 길어야** 한다 — (D) 사다리다.
	var d_base: float = float(durations.get("play_base_hit", -1.0))
	var base_rank := sorted_d.find(d_base) + 1
	print("%s base_hit_duration=%.2f rank=%d/%d" % [PREFIX, d_base, base_rank, sorted_d.size()])
	check(d_base > 0.0,
		"⚠️ `play_base_hit` 이 **자기 `var duration`** 을 갖는다 — 전용 파형의 증거(실측 %.2f)" % d_base, 6)
	check(d_base > HIT_DURATION,
		"⚠️ 기지 피격(%.2fs)이 적 피격(%.2fs)보다 **길다** — 길이=강도 사다리에서 위에 선다"
			% [d_base, HIT_DURATION], 6)
	check(base_rank > quarter,
		"기지 피격(%.2fs)은 최단 %d번째 — **하위 1/4 밖**이다(고침 전에는 4번째로 안이었다)"
			% [d_base, base_rank], 6)
	var d_defeat: float = float(durations.get("play_defeat", -1.0))
	check(d_defeat > d_base,
		"런 종료음(%.2fs)이 기지 피격(%.2fs)보다 길다 — 사다리 순서가 유지된다"
			% [d_defeat, d_base], 6)

	# ── S7. 계약/원칙 — 이 자리에 대해 코드가 무엇을 약속했는가 ────────────────
	#   ⚠️ **주석과 플레이어 문구를 구분해야 한다.** `기지 피격` 은 주석 세 곳에 나오지만
	#      화면에 나가는 문자열에는 **없다** — 처음에 주석까지 세어 실패했다.
	var noise_ban := _scan_all("소음 금지")
	var promise := _scan_player_text("기지 피격")
	print("%s contract noise_ban=%s player_text=%s" % [PREFIX, str(noise_ban), str(promise)])
	check(not noise_ban.is_empty(),
		"**소음 금지** 원칙이 코드에 적혀 있다 — (C)·(D) 가 '새 효과' 였던 이유(고침 1 은 소리를 안 늘렸고, 고침 2 는 늘렸다)", 7)
	check(promise.is_empty(),
		"기지 피격음을 약속하는 **플레이어 문구**는 없다(주석에는 있다) — 깨진 계약이 아니라 **없는 표현**이다", 7)

	print("%s RESOLVED 기지 피격음이 (1) 적 피격에 삼켜지지 않고 (2) 귀로 구별된다 — 전용 파형 `hit_base` · 0.30s (감사 §2.23 · §5.2 35 (B)(C)(D), 2026-09-26 / 2026-10-03)" % PREFIX)

	if failures == 0:
		print("BASE_HIT_PROBE_OK")
	else:
		print("%s FAILURES=%d" % [PREFIX, failures])
	get_tree().quit(failures)


## 재생 중인 플레이어 수. ⚠️ `_last_played_msec` 은 **몇 번 났는지 못 센다**(덮어쓴다).
func _playing_count() -> int:
	var n := 0
	for p in SoundEngine._players:
		if p.is_playing():
			n += 1
	return n


## 두 스트림이 **같은 파형**인가 — `RerollSoundProbe._same_wave` 와 같은 기법이다.
##
## ⚠️ 여기서는 **별칭 검출이 아니라 (C) 의 반증**으로 쓴다. `_cached_streams` 의 키가
##    다르다는 것만으로는 부족하다 — `_play_synth_stream("hit_base", …)` 안에 `hit` 의
##    생성기를 그대로 넣으면 **키만 다르고 귀로는 같다.** 그 경우가 바로 (C) 가
##    아무것도 안 한 상태이므로, **바이트가 같은지**를 직접 본다.
func _same_wave(a: AudioStreamWAV, b: AudioStreamWAV) -> bool:
	if a == null or b == null:
		return false
	if a.data.size() != b.data.size():
		return false
	return a.data == b.data


## 8비트 모노 스트림의 길이(초).
##
## ⚠️ `AudioStreamWAV.get_length()` 에 기대지 않는다 — `_create_wav` 가 형식을
##    `FORMAT_8_BITS`·mono 로 **고정**하므로 `data.size() / mix_rate` 가 곧 길이고,
##    형식이 바뀌면 그쪽은 조용히 다른 값을 준다(여기서는 최소한 가정이 코드에 보인다).
func _wav_len(w: AudioStreamWAV) -> float:
	if w == null or w.mix_rate <= 0:
		return 0.0
	return float(w.data.size()) / float(w.mix_rate)


## `name` 함수 본문에서 `play_*` 이름들을 **주석 줄을 빼고** 모은다.
##
## ⚠️ 함수 본문은 **들여쓰기가 하나라도 있는 줄**로 판정한다 — `func` 다음 줄부터
##    들여쓰기 0 인 줄(다음 `func`·`##`)이 나오면 끝이다. `##` 주석은 본문에 포함되지만
##    `play_` 를 담은 주석은 걸러진다.
func _sound_calls_in(text: String, name: String) -> Array:
	var out: Array = []
	var lines := text.replace("\r\n", "\n").split("\n")
	var re := RegEx.new()
	re.compile("func\\s+%s\\s*\\(" % name)
	var call := RegEx.new()
	call.compile("SoundEngine\\.(play_[a-z_]+)")
	var started := false
	for line in lines:
		var s := str(line)
		if not started:
			if re.search(s) != null:
				started = true
			continue
		var stripped := s.strip_edges()
		if stripped != "" and not s.begins_with("\t") and not s.begins_with(" "):
			break                                    # 들여쓰기 0 = 본문 끝
		if stripped.begins_with("#"):
			continue                                 # 주석은 호출이 아니다
		for m in call.search_all(s):
			out.append(m.get_string(1))
	return out


## `res://scripts` 전체에서 문구를 **주석 포함**으로 찾는다(원칙·문구는 주석에 적힌다).
func _scan_all(needle: String) -> Array:
	var hits: Array = []
	_walk("res://scripts", needle, hits, true)
	return hits


## **플레이어에게 나가는** 문구에서만 찾는다 — 주석 줄은 제외한다.
##
## ⚠️ 이 구분이 없으면 *"기지 피격"* 같은 말이 **주석에 있다는 이유로** '문구가 있다' 고
##    보고된다(첫 판이 그랬다). 계약을 셀 때는 **주석이 아니라 문자열**을 세야 한다.
func _scan_player_text(needle: String) -> Array:
	var hits: Array = []
	_walk("res://scripts", needle, hits, false)
	return hits


## 줄에서 **문자열 밖의** `#` 이후를 잘라낸다.
##
## ⚠️ `s.begins_with("#")` 만으로는 부족하다 — 그건 *줄 전체가 주석인 줄*만 거른다.
##    코드 줄 **끝**에 붙은 주석(`return  # 설명`)은 그대로 남아 '플레이어 문구' 로 세어진다.
##    (2026-09-26, `SwapNoOpProbe` 의 S6 이 실제로 이 구멍에 걸렸다.)
## ⚠️ 문자열 안의 `#`(`"#A6B8F2"`)은 살려야 한다 — 무조건 자르면 진짜 계약을 놓친다.
func _code_part(line: String) -> String:
	var in_str := false
	var quote := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if in_str:
			if c == "\\":
				i += 2
				continue
			if c == quote:
				in_str = false
		else:
			if c == "\"" or c == "'":
				in_str = true
				quote = c
			elif c == "#":
				return line.substr(0, i)
		i += 1
	return line


func _walk(dir_path: String, needle: String, hits: Array, include_comments: bool) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			_walk(full, needle, hits, include_comments)
		elif name.ends_with(".gd"):
			var text := FileAccess.get_file_as_string(full)
			if include_comments:
				if text.contains(needle):
					hits.append(full)
			else:
				for line in text.replace("\r\n", "\n").split("\n"):
					var s := _code_part(str(line)).strip_edges()
					if s == "":
						continue                       # 빈 줄 / 주석만 있는 줄
					if s.contains(needle):
						hits.append(full)
						break
		name = dir.get_next()
	dir.list_dir_end()


## `func play_X` 바로 뒤에 오는 `var duration = N`.
func _sound_durations() -> Dictionary:
	var out := {}
	var path := ENGINE_PATH
	if not FileAccess.file_exists(path):
		return out
	var cur := ""
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var s := str(line).strip_edges()
		if s.begins_with("func play_"):
			var a := s.find("func ") + 5
			var b := s.find("(")
			if b > a:
				cur = s.substr(a, b - a)
		elif cur != "" and s.begins_with("var duration ="):
			var parts := s.split("=")
			if parts.size() >= 2:
				out[cur] = float(parts[1].strip_edges())
			cur = ""
	return out
