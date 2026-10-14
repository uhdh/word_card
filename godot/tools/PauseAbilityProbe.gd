# PauseAbilityProbe.gd — 일시정지와 밀어내기(능력)의 계약을 지킨다.
#
#   godot --headless --path . res://tools/PauseAbilityProbe.tscn
#
# 이 프로브가 지키는 것은 세 가지다.
#   1. 일시정지는 배속과 **같은 기구**(Engine.time_scale)로 멈춘다. 별도 상태 변수를
#      만들지 않는다 — is_paused 는 current_speed_scale 하나로만 판단하며, 재개할 때는
#      1x 가 아니라 **멈추기 직전의 배속**으로 돌아간다(4x 로 보던 플레이어를 위한 설계).
#   2. 밀어내기는 자모 타일 1장을 **영구히** 소모해 경로 위의 모든 적을 뒤로 민다.
#      EnemyUnit 이 PathFollow2D 이므로 progress 를 줄이는 것만으로 충분하며, 0 아래로
#      내려가지 않는다. 웨이브 중에만, 웨이브당 한 번 쓸 수 있다.
#   3. `Engine.time_scale` 을 따르는 것과 따르지 않는 것의 경계 — **트윈은 따르고**
#      (그래서 정지 중 세운 타워가 80% 로 얼어붙는 결함이 있었다), `SceneTreeTimer` 도
#      따른다(그래서 막 클리어 모달의 3초가 배속에 따라 0.75초가 된다). `ignore_time_scale`
#      한 인자로 면제된다는 사실까지 실측해 둔다 — 전제를 재지 않고 적으면 조용히 틀린다.
#
# 주의: 이 스크립트 이름은 SaveManager._is_test_run() 에 있어야 한다.
extends Node2D

var failures := 0


## 실패하면 세고, 이유를 콘솔에 찍는다. (push_error 는 'ERROR:' 로 찍힌다 — 정상이다)
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _ready() -> void:
	print("")
	print("=== 일시정지 · 밀어내기 계약 검증 ===")
	var main = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	add_child(main)

	# ── 일시정지 ────────────────────────────────────────────────────────────
	# 4x 로 보다가 멈추고, 다시 4x 로 돌아와야 한다 — 1x 로 돌아오면 이 설계의 핵심이 깨진다.
	main.set_speed_scale(4.0)
	main.toggle_pause()
	check(Engine.time_scale == 0.0, "일시정지 후 Engine.time_scale 이 0 이 아니다: %s" % Engine.time_scale)
	check(main.is_paused(), "일시정지 후 is_paused() 가 false 다")
	check(main.btn_speed.text == "‖ 정지", "일시정지 버튼 문구가 '‖ 정지' 가 아니다: %s" % main.btn_speed.text)

	main.toggle_pause()
	check(Engine.time_scale == 4.0, "재개 후 Engine.time_scale 이 4x 가 아니다(멈추기 직전 배속으로 돌아와야 한다): %s" % Engine.time_scale)
	check(not main.is_paused(), "재개 후 is_paused() 가 true 다")

	# 일시정지 중에도 배속을 직접 바꾸면 그 값이 그대로 적용된다(별도 bool 이 없으므로).
	main.toggle_pause()
	main.set_speed_scale(2.0)
	check(Engine.time_scale == 2.0, "정지 중 set_speed_scale(2.0) 후 time_scale 이 2 가 아니다: %s" % Engine.time_scale)
	check(not main.is_paused(), "set_speed_scale(2.0) 후에도 is_paused() 가 true 다")
	main.set_speed_scale(1.0)

	# ── 밀어내기 (산술) ─────────────────────────────────────────────────────
	check(main.defense_field.push_back_enemies(0.1) == 0, "적이 없을 때 push_back_enemies 가 0 을 돌려주지 않는다")

	# 적 2마리를 실제 경로에 태운다.
	main.defense_field._spawn_enemy({"name": "probe", "hp": 100.0, "speed": 40.0, "gold": 1, "icon": "monster_slime_1_32px_pastel.png"})
	main.defense_field._spawn_enemy({"name": "probe", "hp": 100.0, "speed": 40.0, "gold": 1, "icon": "monster_slime_1_32px_pastel.png"})
	var path_len: float = main.defense_field.path_2d.curve.get_baked_length()
	var enemies: Array = main.defense_field.get_enemies()
	check(enemies.size() == 2, "적 2마리가 경로에 세워지지 않았다: %d" % enemies.size())
	for enemy in enemies:
		enemy.progress = path_len * 0.5
	var pushed: int = main.defense_field.push_back_enemies(DefenseField.PUSH_BACK_RATIO)
	check(pushed == 2, "밀린 마릿수가 2 가 아니다: %d" % pushed)
	for enemy in enemies:
		var want: float = path_len * 0.5 - path_len * 0.10
		check(absf(enemy.progress - want) < 0.5,
			"밀어낸 후 progress 가 기대값(%.1f)에서 벗어났다: %.1f" % [want, enemy.progress])

	# 경로 시작보다 앞으로 밀리지 않는다 — 0 아래로 내려가면 안 된다.
	enemies[0].progress = 1.0
	main.defense_field.push_back_enemies(DefenseField.PUSH_BACK_RATIO)
	check(enemies[0].progress >= 0.0, "밀어낸 적의 progress 가 0 아래로 내려갔다: %s" % enemies[0].progress)

	# ── 능력 사용 흐름 ──────────────────────────────────────────────────────
	# 웨이브 중에만, 웨이브당 한 번. 두 번째 호출과 웨이브 밖 호출은 거부되어야 한다.
	main.defense_field.is_wave_running = true
	main.ability_uses_left = 1
	main.jamo_belt.jamo_list.assign(["ㄱ", "ㅏ", "ㅁ"])
	main._on_tile_ability_requested(0)
	check(main.jamo_belt.jamo_list.size() == 2, "능력 사용 후 타일이 소모되지 않았다: %d" % main.jamo_belt.jamo_list.size())
	check(main.ability_uses_left == 0, "능력 사용 후 잔여 횟수가 0 이 아니다: %d" % main.ability_uses_left)
	main._on_tile_ability_requested(0)
	check(main.jamo_belt.jamo_list.size() == 2, "잔여 횟수 0 인데 두 번째 능력이 거부되지 않았다: %d" % main.jamo_belt.jamo_list.size())
	main.defense_field.is_wave_running = false
	main.ability_uses_left = 1
	main._on_tile_ability_requested(0)
	check(main.jamo_belt.jamo_list.size() == 2, "웨이브 밖에서 능력이 거부되지 않았다: %d" % main.jamo_belt.jamo_list.size())

	# ── 모드 배타성 ─────────────────────────────────────────────────────────
	# 제거 모드를 켠 뒤 밀어내기 모드를 켜면, 제거 모드는 꺼져야 한다.
	main.jamo_belt._toggle_removal_mode()
	main.jamo_belt._toggle_ability_mode()
	check(not main.jamo_belt.removal_mode, "밀어내기 모드를 켰는데 제거 모드가 꺼지지 않았다")
	check(main.jamo_belt.ability_mode, "밀어내기 모드가 켜지지 않았다")

	# ── 정지 중 벨트 편집 ───────────────────────────────────────────────────
	# 일시정지의 목적은 '시간이 없어서 못 하던 조작' 을 하게 하는 것이다. 그 조작이
	# 타워를 다시 세우면 등장 연출(0.8 → 1.0 스케일 트윈)이 함께 돌아야 한다.
	# 트윈이 Engine.time_scale 을 따르면 정지 중에 세운 타워가 80% 크기로 **영구히**
	# 남는다 — 화면에 그대로 보이는 결함이다. 그래서 여기서 실제로 잰다.
	main.set_speed_scale(1.0)
	main.defense_field.update_towers_from_parsed_list([
		{"syllable": "불", "word_data": {"category": "element", "is_unknown": true}}
	])
	main.toggle_pause()
	check(main.is_paused(), "정지 상태가 아니다")
	# 정지 중에는 _process delta 가 0 이라 create_timer 가 영원히 오지 않는다. 프레임으로 기다린다.
	# (등장 트윈은 0.22초짜리라, 60fps 기준 14프레임 남짓이면 끝난다. 여유를 두고 40프레임까지 본다)
	var popped: float = -1.0
	for i in range(40):
		await get_tree().process_frame
		if main.defense_field.active_towers.is_empty():
			continue
		popped = main.defense_field.active_towers[0].scale.x
		if absf(popped - 1.0) < 0.01:
			break
	check(popped >= 0.0, "정지 중 벨트를 고쳤는데 타워가 세워지지 않았다")
	check(absf(popped - 1.0) < 0.01,
		"정지 중 세운 타워가 80%% 크기로 남았다 — 등장 트윈이 Engine.time_scale 을 따른다 (scale.x=%.3f)" % popped)

	# ── SceneTreeTimer 도 Engine.time_scale 을 따른다 ────────────────────────
	# 막 클리어 모달은 `get_tree().create_timer(3.0)` 으로 **스스로** 닫힌다
	# (`TowerDefenseMain._on_act_cleared`). 그 3초가 배속을 따르면 4x 에서는 0.75초가 되어
	# 런당 2회뿐인 클라이맥스 문구를 읽을 수 없다. 반대로 정지 중에는 영원히 오지 않는다
	# (아래 정지 검사가 그 사실을 못박는다).
	#
	# 여기서 재는 것은 **엔진 사실**이다 — 이걸 재 보지 않고 "아마 따를 것" 이라고 적으면,
	# 이 프로젝트에서 이미 한 번 겪은 것처럼 나중에 조용히 틀린 전제가 된다.
	# 수정 자체는 `ignore_time_scale=true` 한 인자로 끝나므로, 그 인자가 실제로 면제하는지도 함께 잰다.
	main.set_speed_scale(1.0)
	Engine.time_scale = 4.0
	var t0 := Time.get_ticks_msec()
	await get_tree().create_timer(3.0).timeout
	var scaled_ms: int = Time.get_ticks_msec() - t0

	t0 = Time.get_ticks_msec()
	# 인자 순서: (time_sec, process_always, process_in_physics, ignore_time_scale)
	await get_tree().create_timer(3.0, true, false, true).timeout
	var ignored_ms: int = Time.get_ticks_msec() - t0

	print("   [실측] 3.0초 타이머 @4x — 그냥 %d ms · ignore_time_scale %d ms" % [scaled_ms, ignored_ms])
	check(scaled_ms < 2000,
		"create_timer 가 배속을 따르지 않는다 — 이 프로브의 전제가 틀렸다. 막 클리어 모달 3초가 4x 에서도 3초로 유지된다 (%.0f ms)" % scaled_ms)
	check(ignored_ms > 2500,
		"ignore_time_scale=true 인데도 배속이 적용됐다 — 모달 수명 고정에 쓸 수 없다 (%.0f ms)" % ignored_ms)

	# 정지 중에는 아예 오지 않는다. '닫기 버튼 없는 모달' 이 정지와 겹치면 탈출구가 사라진다.
	Engine.time_scale = 0.0
	var fired := false
	var frozen_timer := get_tree().create_timer(0.05)
	frozen_timer.timeout.connect(func(): fired = true)
	for i in range(20):
		await get_tree().process_frame
	check(not fired, "정지 중(0x)에도 create_timer 가 발화했다 — 정지 중 모달 수명 가정을 다시 세워야 한다")
	Engine.time_scale = 1.0

	main.set_speed_scale(1.0)
	Engine.time_scale = 1.0
	print("")
	if failures == 0:
		print("PAUSE_ABILITY_PROBE_OK")
	else:
		print("PAUSE_ABILITY_PROBE_FAIL %d" % failures)
	get_tree().quit(failures)
