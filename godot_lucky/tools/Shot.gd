extends Node
## 화면을 PNG 로 찍는 검증 도구.
##
##   목업(빈 보드):
##     godot --path godot_lucky res://tools/Shot.tscn -- out=E:/project/word_card/_mock_shot.png wait=10
##   플레이(타일·타워·적이 올라간 상태):
##     godot --path godot_lucky res://tools/Shot.tscn -- out=... play=1 wait=10
##
## ⚠️ `--headless` 로는 동작하지 않는다 (더미 렌더러라 `get_image()` 가 빈다).
## ⚠️ 창 크기에 기대지 않는다 — **SubViewport 를 720×1140 으로 고정**해 찍으므로
##    창이 화면보다 작아도(프로젝트 override 540×855) 결과는 설계 해상도 그대로다.
## ⚠️ 프로젝트가 `low_processor_mode=true` 다 — 그대로 두면 정지 화면에서는
##    프레임이 더 안 돌아 `frame_post_draw` 가 다시 오지 않고 **캡처가 영영 안 된다.**
##    그래서 켜자마자 끈다.
## ⚠️ `play=1` 은 `MergeMain._process` 를 **끈다**. 안 끄면 캡처를 기다리는 프레임 동안
##    시뮬레이션이 계속 돌아 투사체(SHOT_LIFE 0.13초)가 사라지고 적이 죽어 버린다
##    → "찍으려던 상태" 가 사라진다. 대신 상태를 손으로 만들어 두고 `_refresh()` 를 부른다.

const DESIGN := Vector2i(720, 1140)

var _out := "E:/project/word_card/_mock_shot.png"
var _wait := 10
var _play := false
var _vp: SubViewport


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"out": _out = kv[1]
			"wait": _wait = int(kv[1])
			"play": _play = true

	OS.low_processor_usage_mode = false

	_vp = SubViewport.new()
	_vp.size = DESIGN
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	var main: Control = load("res://scenes/MergeMain.tscn").instantiate()
	_vp.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	for _i in 5:
		await get_tree().process_frame

	if _play:
		main.set_process(false)
		main.call("_fit_board")
		await _seed(main)

	await _capture()


## 플레이 화면을 손으로 만든다 — 실제 조작 대신 `MergeGame` 을 직접 돌린다.
func _seed(main: Control) -> void:
	var g: MergeGame = main.get("_game")
	if g == null:
		print("SHOT_FAILED game is null")
		get_tree().quit(1)
		return
	g.reset()

	# 두 단어를 서로 안 닿게 놓는다 (닿으면 파서가 다른 단어로 굳는다).
	#   가로 '나무' (5행, 1~4열) · 세로 '구름' (2열, 1~4행)
	# ⚠️ 같은 자모가 **같은 등급으로 3장** 모이면 자동 병합이 보드를 바꿔 버린다.
	#    그래서 반복되는 자모(ㄱ·ㄹ·ㅜ)는 등급을 달리해 둔다.
	_put(g, Vector2i(5, 1), "ㄴ")
	_put(g, Vector2i(5, 2), "ㅏ")
	_put(g, Vector2i(5, 3), "ㅁ")
	_put(g, Vector2i(5, 4), "ㅜ")

	_put(g, Vector2i(1, 2), "ㄱ")
	_put(g, Vector2i(2, 2), "ㅜ")
	_put(g, Vector2i(3, 2), "ㄹ")
	_put(g, Vector2i(4, 2), "ㅡ")

	# 단어에 안 들어간 자모 (어둡게 그려진다) + 등급이 다른 것들
	_put(g, Vector2i(1, 1), "ㄱ", 2)
	_put(g, Vector2i(1, 4), "ㅣ")
	_put(g, Vector2i(3, 1), "ㅗ")
	_put(g, Vector2i(3, 3), "ㄹ", 3)

	g._after_change()
	g.selected = Vector2i(5, 2)          # 나무 칸 → 사거리 원이 보인다

	# 적이 살아남도록 조금 뒤 라운드에서 시작한다 (타워가 한 방에 못 잡게).
	g.wave = 6
	g.start_wave()

	# 적이 서너 마리 깔릴 때까지 돌린다.
	var guard := 0
	while g.enemies.size() < 3 and guard < 3000:
		g.tick(0.02)
		guard += 1
	# 투사체가 뜬 순간에서 멈춘다 (SHOT_LIFE 0.13초라 금방 사라진다).
	var guard2 := 0
	while g.shots.size() < 1 and guard2 < 200:
		g.tick(0.02)
		guard2 += 1

	main.call("_refresh")
	var board: Control = main.get("_board")
	if board != null:
		board.queue_redraw()
	print("SHOT_SEED round=%d tiles=%d towers=%d enemies=%d shots=%d"
		% [g.wave, g.tile_count(), g.towers.size(), g.enemies.size(), g.shots.size()])


func _put(g: MergeGame, cell: Vector2i, jamo: String, tier := 1) -> void:
	g.tiles[cell] = {"jamo": jamo, "tier": tier}


func _capture() -> void:
	for _i in maxi(1, _wait):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := _vp.get_texture().get_image()
	var rc := img.save_png(_out)
	if rc != OK:
		print("SHOT_FAILED ", _out, " rc=", rc)
		get_tree().quit(1)
		return
	print("SHOT_SAVED %s %dx%d" % [_out, img.get_width(), img.get_height()])
	get_tree().quit(0)
