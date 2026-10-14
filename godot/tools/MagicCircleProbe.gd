# MagicCircleProbe.gd
# 건설 마법진(`WordTower.gd:914`)이 실제로 어떻게 그려지는지 잰다.
#
# 왜 필요한가:
#   정적 스캔 결과 `_draw` 계열 안에서 `load()` 하는 곳은 프로젝트에 셋뿐이다.
#     · WordTower.gd:938  _draw_trait_badge_on()  → 배지 (사용자가 제보한 흰 사각형)
#     · WordTower.gd:914  _draw()                 → 건설 마법진
#     · tools/BadgeLazyProbe.gd:34                → 내 프로브
#   그리고 `fx_magic_circle_128px.png` 는 **오직 :914 한 곳에서만** 로드된다 —
#   다른 어디서도 미리 로드하지 않으므로 같은 기구가 **반드시** 발현되어야 한다.
#   배지와 다른 점: 마법진은 `Color(카테고리색, 0.85*alpha)` 로 modulate 되므로
#   흰색이 아니라 **카테고리 색 사각형**으로 보일 수 있다.
#
# 재는 것: 타워 중심(= 마법진 중심) 픽셀과 그 주변. 마법진이 정상이면 반투명 원형
#          마법진이 보이고, 깨졌으면 **균일한 단색 사각형**이 보인다.
#
# 보고 전용. 판정하지 않는다.
extends Node2D

const OUT_PATH := "E:/project/word_card/tmp/magiccircle_out.txt"
var _lines: PackedStringArray = []

class _Bg extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.12, 0.12, 0.20, 1.0))

func _emit(s: String) -> void:
	_lines.append(s)
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines) + "\n")
		f.flush()
		f = null

func _watchdog() -> void:
	for i in 600:
		await get_tree().process_frame
	_emit("WATCHDOG")
	get_tree().quit(2)

func _ready() -> void:
	_watchdog()
	var bg := _Bg.new()
	add_child(bg)
	_emit("MAGICCIRCLE_START")

	var scene: PackedScene = load("res://scenes/tower/WordTower.tscn")
	var tw = scene.instantiate()
	add_child(tw)
	tw.position = Vector2(300, 300)
	# 마법진을 켠 채로 세운다. `_draw()` 안에서 처음 load() 되도록 **미리 로드하지 않는다**.
	tw.setup_tower("섬광", WordDatabase.get_word_data("섬광"), null, true)
	_emit("setup_tower(show_magic_circle=true) · magic_circle_time_left=%.2f" % tw.magic_circle_time_left)

	for i in 4:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("E:/project/word_card/tmp/magiccircle.png")
	# 마법진은 타워 중심에 sz=100 으로 그려진다(정상이면 원형, 깨지면 사각형).
	var pts: Array = [
		Vector2i(300, 300), Vector2i(270, 300), Vector2i(330, 300),
		Vector2i(300, 270), Vector2i(300, 330),
		Vector2i(260, 260), Vector2i(340, 260), Vector2i(260, 340), Vector2i(340, 340),
	]
	var parts: PackedStringArray = []
	for p in pts:
		parts.append("%s=%s" % [p, img.get_pixelv(p)])
	_emit("  중심·사방·모서리: %s" % " | ".join(parts))
	# 깨짐 판정 보조: 반지름 50 안쪽이 전부 같은 색이면 사각형(깨짐), 원이면 색이 변한다.
	var same := 0
	var first: Color = img.get_pixelv(Vector2i(300, 300))
	for dx in range(-45, 46, 15):
		for dy in range(-45, 46, 15):
			var c: Color = img.get_pixelv(Vector2i(300 + dx, 300 + dy))
			if abs(c.r - first.r) < 0.01 and abs(c.g - first.g) < 0.01 and abs(c.b - first.b) < 0.01:
				same += 1
	_emit("  반지름45 격자 7x7 중 중심과 같은 색: %d/49  (49 면 균일 = 사각형)" % same)
	_emit("MAGICCIRCLE_DONE")
	get_tree().quit(0)
