# 조준 우선순위가 **플레이어에게 어떻게 보이는지** 를 그대로 뽑는 도구.
#
#   godot --headless --path . res://tools/TargetingProbe.tscn      # 글자 보고
#   godot --path . res://tools/TargetingProbe.tscn                 # + 스크린샷
#
# 테스트는 "그 문구를 포함하는가" 만 검사한다. 이 도구는 **완성된 문자열 전체** 를
# 보여 준다 — 표현이 계약인 프로젝트에서, 계약서에 뭐라고 적혔는지 눈으로 봐야 한다.
# (실제로 이 도구로 `진급 우선 — … 노린다 — 새는 적을 …` 처럼 대시가 두 번 겹치는
#  결함을 잡았다. 테스트는 통과하고 있었다 — contains() 는 겹침을 못 본다.)
#
# 네 모드의 툴팁, 정보창의 조준 행(+아이콘), 그리고 선회 타워에 조준이 **없는지** 까지
# 확인한다. 아이콘은 `TargetingStyle` 이 그리고, 그 표가 네 모드를 다 덮는지도 단언한다.
#
# ⚠️ 스크린샷은 **창 모드에서만** 얻어진다 — headless 의 더미 렌더러는 `get_image()` 가
# null 이라 저장이 안 되고, 그 위에 `texture_2d_get` ERROR 를 찍어 '프로브 실패' 처럼
# 보인다(RelicChipProbe 가 같은 함정을 겪고 남긴 주석이 그대로 여기에도 적용된다).
extends Node2D

const TargetingStyle = preload("res://scripts/tower/TargetingStyle.gd")
const SHOT_DIR := "E:/project/word_card/tmp/"

class StubField extends Node:
	var relic_ids: Array = []
	var enemies: Array = []

	func has_relic(_id: String) -> bool:
		return false

	func get_enemies() -> Array:
		return enemies


## 아이콘 네 개를 **큰 그림과 실제 크기로 나란히** 그린다. 모양이 서로 구별되는지는
## 14px 만으로는 판정할 수 없다 — 큰 그림을 같이 놓아야 '설계한 모양' 과 '작을 때
## 뭉개진 모양' 을 한 장에서 맞댈 수 있다.
class IconSheet extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("#141020"))
		var x := 80.0
		for m in WordTower.TARGETING_MODES:
			var mode := str(m)
			var col: Color = TargetingStyle.color_for(mode)
			# 큰 그림 — 반지름 38px. 모양 판정용.
			TargetingStyle.draw_icon(self, Vector2(x, 80.0), 38.0, mode, col)
			# 실제 크기 — 모달 조준 행과 같은 14px 상자(반지름 6.3).
			TargetingStyle.draw_icon(self, Vector2(x, 190.0), 6.3, mode, col)
			x += 150.0


func _ready() -> void:
	await _run()
	get_tree().quit(0)


func _run() -> void:
	var WordTowerScene = load("res://scenes/tower/WordTower.tscn")
	var ModalScene = load("res://scenes/tower/TowerInfoModal.tscn")

	var field := StubField.new()
	add_child(field)

	var tower = WordTowerScene.instantiate()
	add_child(tower)
	tower.setup_tower("가나", {"category": "weapon", "damage": 4, "is_unknown": true,
		"desc": "기본 활자 탄환."}, field)

	for m in WordTower.TARGETING_MODES:
		tower.set_targeting_mode(str(m))
		tower.btn_select.mouse_entered.emit()
		print("")
		print("=== 툴팁 (조준 = %s) ===" % tower.targeting_label())
		print(tower.btn_select.tooltip_text)

	# 정보창이 실제로 조준 행을 만드는가, 그리고 어디에 놓이는가.
	var modal = ModalScene.instantiate()
	add_child(modal)
	modal.setup(tower.word_data, tower.syllable, tower.attack_range, tower.attack_interval,
		tower.synergy_labels, 10.0, "", 0.0, {}, tower)
	var vbox = modal.get_node("Panel/VBox")
	var order: Array[String] = []
	for c in vbox.get_children():
		order.append(c.name)
	print("")
	print("=== 정보창 VBox 순서 ===")
	print(" / ".join(order))
	var row = vbox.get_node_or_null("TargetingRow")
	if row == null:
		print("!! TargetingRow 가 없다")
	else:
		var text = row.get_node_or_null("TargetingText")
		var icon = row.get_node_or_null("TargetingIcon")
		var btn = null
		for c in row.get_children():
			if c is Button:
				btn = c
		print("=== 정보창 조준 행 ===")
		print("  ", text.text if text != null else "(라벨 없음)")
		print("  버튼: ", btn.text if btn != null else "(버튼 없음)")
		print("  아이콘: ", ("있음 · 그리는 모드 = %s" % icon.mode) if icon != null else "!! 없음")

		# 아이콘이 **글자와 같이** 움직이는가. 아이콘만 안 바뀌면 화면이 거짓말을 한다.
		print("")
		print("=== 정보창 조준 아이콘 (전환 4회) ===")
		if btn == null or icon == null or text == null:
			print("!! 조준 행 구성 요소가 부족해 전환을 시험할 수 없다")
		else:
			var start_mode: String = icon.mode
			var moved := 0
			for i in WordTower.TARGETING_MODES.size():
				btn.pressed.emit()
				# `icon` 은 `get_node_or_null` 결과라 타입이 없다 → `:=` 로 추론할 수 없다.
				var ok: bool = icon.mode == tower.targeting_mode
				if not ok:
					moved += 1
				print("  %s — 아이콘=%s 글자=%s %s" % [
					tower.targeting_label(), icon.mode, text.text.substr(0, 14),
					"OK" if ok else "!! 아이콘과 조준이 갈라졌다"])
			print("  갈라진 횟수: %d (0 이어야 한다) · 시작 모드로 복귀: %s" % [
				moved, str(icon.mode == start_mode)])

	# 선회 타워에는 조준 행이 생기면 안 된다 — 눌러도 아무 일이 없는 버튼은 거짓말이다.
	var orbit_tower = WordTowerScene.instantiate()
	add_child(orbit_tower)
	orbit_tower.setup_tower("가나", {"category": "summon", "damage": 4, "is_unknown": true}, field)
	var modal2 = ModalScene.instantiate()
	add_child(modal2)
	modal2.setup(orbit_tower.word_data, orbit_tower.syllable, orbit_tower.attack_range,
		orbit_tower.attack_interval, orbit_tower.synergy_labels, 10.0, "", 0.0, {}, orbit_tower)
	orbit_tower.btn_select.mouse_entered.emit()
	print("")
	print("=== 선회 타워 ===")
	print("  정보창 TargetingRow 존재: ",
		modal2.get_node("Panel/VBox").get_node_or_null("TargetingRow") != null)
	print("  툴팁에 조준 줄 포함: ", orbit_tower.btn_select.tooltip_text.contains("조준:"))
	print("  툴팁에 선회 방향 줄 포함: ", orbit_tower.btn_select.tooltip_text.contains("선회 방향"))

	# 표 계약 — 모드를 새로 추가하고 `TargetingStyle` 을 안 고치면 그 모드만 아이콘 없이
	# 나온다(조용한 누락). 이름·설명은 WordTower 가, 아이콘·색은 TargetingStyle 이 갖는다.
	print("")
	print("=== 아이콘 표 계약 ===")
	var no_icon: Array[String] = []
	for m in WordTower.TARGETING_MODES:
		if not TargetingStyle.COLORS.has(str(m)):
			no_icon.append(str(m))
	print("  TARGETING_MODES %d개 · 색 없는 모드 %d개%s" % [
		WordTower.TARGETING_MODES.size(), no_icon.size(),
		(" = " + str(no_icon)) if not no_icon.is_empty() else ""])

	# ── 시각 확인 (창 모드 전용) ────────────────────────────────────────────────
	if DisplayServer.get_name() == "headless":
		print("")
		print("=== 스크린샷 생략(headless) ===")
		print("  더미 렌더러는 get_image() 가 null 이라 저장이 안 된다 — 창 모드로 돌려라.")
		return

	# 보고용 모달을 치운다 — 스크린샷에 겹치면 안 된다.
	modal.queue_free()
	modal2.queue_free()
	await get_tree().process_frame

	var sheet := IconSheet.new()
	add_child(sheet)
	await _settle()
	_shoot("targeting_icons.png")
	sheet.queue_free()
	await get_tree().process_frame

	# 실제 정보창 — 아이콘이 **행 안에서** 제자리에 앉는지(크기·정렬)를 **네 모드 모두** 본다.
	# 한 모드만 찍으면 그 모드에서만 맞는지 알 수 없다.
	# ⚠️ 정보창을 **뷰포트 크기의 Control 에 담는다.** Node2D 밑에 그냥 붙이면 부모 rect 가
	# 0x0 이라 가운데 정렬 패널이 [-260,260] 에 놓여 화면 **왼쪽 위로 잘려** 찍혔다(실측).
	var holder := Control.new()
	holder.size = get_viewport_rect().size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	for m in WordTower.TARGETING_MODES:
		tower.set_targeting_mode(str(m))
		var shot_modal = ModalScene.instantiate()
		holder.add_child(shot_modal)
		shot_modal.setup(tower.word_data, tower.syllable, tower.attack_range, tower.attack_interval,
			tower.synergy_labels, 10.0, "", 0.0, {}, tower)
		await _settle()
		_shoot("targeting_row_%s.png" % str(m))
		shot_modal.queue_free()
		await get_tree().process_frame


## 레이아웃이 확정될 때까지 두 프레임 기다린다. 한 프레임이면 컨테이너 정렬이
## 아직 안 끝나 스크린샷에 아이콘이 엉뚱한 자리에 찍힌다.
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _shoot(file_name: String) -> void:
	var vtex: ViewportTexture = get_viewport().get_texture()
	var shot: Image = vtex.get_image() if vtex != null else null
	if shot == null:
		print("!! 스크린샷 이미지가 null — 저장하지 못했다")
		return
	var err: int = shot.save_png(SHOT_DIR + file_name)
	print("스크린샷 %s 저장 err=%d" % [file_name, err])
