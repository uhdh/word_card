extends Node
# 보스 등장 연출이 **한 번만** 터지는지, 그리고 **소리가 나는지** 잰다 (§2.4, 2026-09-23).
#
# 왜 필요한가 — 감사 §2.4 가 두 가지를 지적했다.
#
#   1) "소리가 없다" — `_juice_boss_entrance()` 에 `SoundEngine` 호출이 0건이다. 시각 연출은
#      5종(흔들림 2 + 붉은 섬광 + 배너 + 실루엣 1.9배 + 전용 HP바)인데 오디오가 비어 있다.
#   2) "보스가 2마리인 라운드면 연출이 2번 겹친다" — `_spawn_enemy()` 가 boss 마다 부르므로.
#
# ⚠️ 2번은 **추론이었고, 재보니 틀렸다.** `_build_wave_monsters()` 는 보스 라운드에
# `boss_entry()` 를 **한 번만** append 하고(`DefenseField.gd:862-864`), `_start_round()` 의
# 호출자는 둘뿐이며(`_process` 계획 전환 `:759`, `start_next_wave` `:799`)
# `start_next_wave()` 는 `is_wave_running` 으로 자기 중복을 막는다(`:780`).
# 그래서 이 도구는 2번을 **재서 판정한다** — 재보지 않고 "라운드당 1회" 가드를 넣으면
# 도달 불가능한 죽은 코드가 되고, 그건 디렉터 규칙("불필요한 것은 넣지 마라")에 어긋난다.
#
# 재는 것:
#   1) 보스 라운드에 보스가 **정확히 1마리** 스폰된다
#   2) 등장 배너가 **정확히 1개**다 — 2개면 연출이 겹친 것 (감사 주장 2)
#   3) 등장 연출이 **소리를 낸다** (`boss_entrance` 스트림이 실제로 합성된다)
#   4) 그 소리는 웨이브 시작음과 **다른 소리**이고, **더 길고 더 낮다**
#      — 같으면 "보스 등장" 이 "웨이브 시작" 과 구별되지 않아 정보가 사라진다.
#        `play_wave_start()` 는 **매 웨이브** 울리므로 보스 전용 신호가 될 수 없다.
#      ⚠️ 비교 대상은 **그 소리 하나**다. "세트 전체에서 가장 낮다" 는 재지 않는다 —
#         `play_hit()` 은 40Hz 까지 내려가지만 0.12초 스침이라 다른 축의 이야기다.
#
# 실행: godot --headless --path . res://tools/BossEntranceProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")
const BOSS_WAVE := 5          # BOSS_ROUND_INTERVAL = 5 → 5의 배수가 보스 라운드
const BOSS_STREAM := "boss_entrance"
const WAVE_STREAM := "wave_start"

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

## 이름으로 자식 노드를 센다. 배너는 겹치면 **여러 개가 동시에** 존재하므로 이게 증거다.
## (체력바는 못 쓴다 — `_attach_boss_bar()` 가 이전 것을 먼저 free 하므로 언제나 1개다)
func _count_named(node: Node, target: String) -> int:
	var n := 0
	for c in node.get_children():
		if c.name == target:
			n += 1
	return n

func _count_bosses(field) -> int:
	var n := 0
	for e in field.get_enemies():
		if e.enemy_type == "boss":
			n += 1
	return n

## 8비트 데이터의 영교차율(초당). 낮은 소리일수록 작다 — 피치를 재는 싼 대리 지표.
func _zero_cross_rate(stream) -> float:
	if stream == null or stream.data.is_empty():
		return 0.0
	var data: PackedByteArray = stream.data
	var crossings := 0
	var prev := data[0] >= 128
	for i in range(1, data.size()):
		var cur := data[i] >= 128
		if cur != prev:
			crossings += 1
			prev = cur
	return float(crossings) * float(stream.mix_rate) / float(data.size())

func _ready() -> void:
	# ⚠️ 플레이어 설정이 `muted` 일 수 있다 — 그러면 소리는 **합성조차** 되지 않아
	# (`_play_synth_stream()` 첫 줄이 `return`) 3·4번이 아무것도 재지 못한다.
	# `muted` 를 직접 대입하면 `_save_config()` 를 지나지 않으므로 설정 파일은 안전하다.
	SoundEngine.muted = false

	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	main._is_loading_state = true
	main.start_new_game()
	await get_tree().process_frame
	await get_tree().process_frame
	main._is_loading_state = true
	main.defense_field.reset_combat_state()
	await get_tree().process_frame
	# `start_new_game()` 끝의 `call_deferred("_start_wave_automatically")` 가 늦게 도착하면
	# 다시 멈춘다. 안 멈추면 아래 `start_next_wave()` 가 `is_wave_running` 에 막혀 조용히 실패한다.
	if main.defense_field.is_wave_running:
		main.defense_field.reset_combat_state()
		await get_tree().process_frame
	var field = main.defense_field
	check(field.current_act == 1, "기준선이 1막이 아니다 (제 %d막)" % field.current_act)
	check(not field.is_wave_running, "기준선 잡기 실패 — 이미 웨이브가 돌고 있다")

	# ── 0. 기준선 ────────────────────────────────────────────────────────────
	# 웨이브 시작음을 미리 합성해 둔다 — 4번에서 보스 소리와 **비교**해야 하기 때문이다.
	SoundEngine.play_wave_start()
	var base_banners := _count_named(field, "BossBanner")
	var base_bosses := _count_bosses(field)
	var base_has_boss_stream: bool = SoundEngine._cached_streams.has(BOSS_STREAM)
	print("BOSS_PROBE baseline banners=%d bosses=%d boss_stream=%s" % [
		base_banners, base_bosses, str(base_has_boss_stream)])
	check(base_banners == 0, "기준선에 보스 배너가 이미 %d개 있다" % base_banners)
	check(base_bosses == 0, "기준선에 보스가 이미 %d마리 있다" % base_bosses)
	check(not base_has_boss_stream,
		"기준선에 이미 `%s` 스트림이 캐시돼 있다 — 3번은 아무것도 재지 못한다" % BOSS_STREAM)

	# ── 1. 보스 라운드를 실제 경로로 연다 ────────────────────────────────────
	# `_start_round()` 를 직접 부르지 않는다 — `start_next_wave()` 가 웨이브를 여는 문이고,
	# 그 안에서 `_build_wave_monsters()` 가 보스를 큐에 넣는다.
	field.current_wave = BOSS_WAVE - 1
	field.start_next_wave()
	check(field.current_wave == BOSS_WAVE,
		"보스 라운드로 가지 못했다 (wave=%d)" % field.current_wave)
	check(field.spawn_queue.size() > 0, "스폰 큐가 비었다 — 보스가 예약되지 않았다")
	# 보스는 큐의 **첫** 항목이다(`:864` 가 `:866` 루프보다 앞). 그래야 0.8초에 나온다.
	var first: Dictionary = field.spawn_queue[0]
	print("BOSS_PROBE queue first=%s size=%d" % [str(first.get("name", "?")), field.spawn_queue.size()])
	check(str(first.get("type", "")) == "boss",
		"큐의 첫 항목이 보스가 아니다 (%s) — 이 실행은 다른 것을 재고 있다" % str(first.get("type", "?")))

	# ── 2. 보스가 스폰될 때까지 실제로 돌린다 (SPAWN_INTERVAL = 0.8초) ─────────
	var deadline := Time.get_ticks_msec() + 2500
	while _count_bosses(field) == 0 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var banners := _count_named(field, "BossBanner")
	var bosses := _count_bosses(field)
	var has_boss_stream: bool = SoundEngine._cached_streams.has(BOSS_STREAM)
	print("BOSS_PROBE after_spawn bosses=%d banners=%d boss_stream=%s" % [
		bosses, banners, str(has_boss_stream)])

	check(bosses == 1, "보스가 %d마리 스폰됐다 (1마리여야 한다)" % bosses)
	check(banners == 1,
		"보스 등장 배너가 %d개다 — 연출이 겹쳤다 (1개여야 한다)" % banners)

	# ── 3. 등장 연출이 소리를 낸다 ───────────────────────────────────────────
	check(has_boss_stream,
		"보스 등장에 소리가 없다 — `%s` 스트림이 합성되지 않았다 (감사 §2.4)" % BOSS_STREAM)

	# ── 4. 그 소리는 웨이브 시작음과 다르고 더 길다 ──────────────────────────
	var wave_stream = SoundEngine._cached_streams.get(WAVE_STREAM)
	var boss_stream = SoundEngine._cached_streams.get(BOSS_STREAM)
	if boss_stream != null and wave_stream != null:
		var boss_dur := float(boss_stream.data.size()) / float(boss_stream.mix_rate)
		var wave_dur := float(wave_stream.data.size()) / float(wave_stream.mix_rate)
		var boss_zcr := _zero_cross_rate(boss_stream)
		var wave_zcr := _zero_cross_rate(wave_stream)
		print("BOSS_PROBE sound boss=%.2fs zcr=%.0f / wave=%.2fs zcr=%.0f" % [
			boss_dur, boss_zcr, wave_dur, wave_zcr])
		check(boss_stream.data != wave_stream.data,
			"보스 등장음이 웨이브 시작음과 **같은 소리**다 — 매 웨이브 울리는 소리라 보스 신호가 못 된다")
		check(boss_dur > wave_dur,
			"보스 등장음(%.2fs)이 웨이브 시작음(%.2fs)보다 짧다 — 가장 무거운 사건이 가장 짧을 이유가 없다" % [boss_dur, wave_dur])
		# 영교차율은 피치의 싼 대리 지표다. 두 소리 다 결정론적으로 합성되므로(난수 없음)
		# 이 값은 실행마다 같다 — 실측 189/s 대 596/s 로 3배 차이라 흔들릴 여지가 없다.
		check(boss_zcr < wave_zcr,
			"보스 등장음(zcr %.0f/s)이 웨이브 시작음(zcr %.0f/s)보다 낮지 않다 — 구별되지 않는다" % [boss_zcr, wave_zcr])
	else:
		check(false, "비교할 스트림이 없다 (boss=%s wave=%s)" % [
			str(boss_stream != null), str(wave_stream != null)])

	if failures == 0:
		print("BOSS_ENTRANCE_PROBE_OK")
	get_tree().quit(failures)
