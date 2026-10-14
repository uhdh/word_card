# BadgeRealPathProbe.gd
# **실제 게임 경로**에서 타워 특성 배지가 어떻게 그려지는지 잰다.
#
# 왜 필요한가:
#   BadgeDrawProbe 는 WordTower.tscn 을 **단독으로** 띄웠고, 거기서는 11개 배지가 전부 정상이었다.
#   그런데 실제 게임(Shot.tscn, act=2, towers=냉기,빙마,섬광)에서는 타워마다 22x22 순백 사각형이
#   배지 자리에 떴다. 단독 렌더와 실제 렌더의 차이는 **DefenseField 안에 있다**는 뜻이다.
#   → Shot 과 **같은 경로**로 게임을 띄우고, 타워의 배지 관련 상태와 픽셀을 함께 덤프한다.
#
# 재는 것:
#   · field.active_towers 각각의 trait_id / has_icon / badge_path 존재 / 로드된 텍스처 크기
#     / CPU 이미지 중앙 픽셀
#   · 그 타워와 배지 캔버스의 modulate · self_modulate · material · z_index · visible
#   · 타워의 자식 노드 목록 (배지 캔버스가 실제로 붙어 있는가)
#   · 화면에서 배지 중심 픽셀 (순백인가)
#
# 보고 전용. 판정하지 않는다.
## ⚠️ 루트는 반드시 `Node` 여야 한다 — `Node2D` 로 두면 `TowerDefenseMain`(Control) 의
## 앵커 레이아웃이 잡히지 않아 필드가 화면 밖 음수 좌표로 간다(실측: field=(-480,-254)).
## Shot.tscn 도 같은 이유로 `Node` 다.
extends Node

## ⚠️ TraitStyle.gd 는 `class_name` 을 쓰지 않는다(파일 헤더가 그 이유를 적고 있다 —
## 전역 클래스 캐시를 다시 만들어야 인식되고, 빠뜨리면 Parse Error 로 죽는다).
## 프로젝트 관례대로 preload 한다.
const TraitStyle = preload("res://scripts/tower/TraitStyle.gd")

const OUT_PATH := "E:/project/word_card/tmp/badgereal_out.txt"
var _lines: PackedStringArray = []

func _emit(s: String) -> void:
	_lines.append(s)
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines) + "\n")
		f.flush()
		f = null

func _watchdog() -> void:
	for i in 900:
		await get_tree().process_frame
	_emit("WATCHDOG — 900 프레임 안에 끝나지 않았다")
	get_tree().quit(2)

func _ready() -> void:
	_watchdog()
	_emit("BADGEREAL_START")

	var main = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var field = main.find_child("DefenseField", true, false)
	_emit("field=%s" % field)
	if field == null:
		_emit("DefenseField 를 못 찾았다")
		get_tree().quit(3)
		return
	field.set_act(2)
	var parsed: Array = []
	for c in ["냉기", "빙마", "섬광"]:
		parsed.append({"syllable": c, "word_data": WordDatabase.get_word_data(c)})
	field.update_towers_from_parsed_list(parsed)
	for i in 120:
		await get_tree().process_frame

	var towers: Array = field.active_towers
	_emit("active_towers=%d" % towers.size())
	for i in towers.size():
		var t = towers[i]
		if t == null:
			_emit("  [%d] null" % i)
			continue
		var tid: String = str(t.trait_id)
		var has_icon: bool = TraitStyle.has_icon(tid)
		var bp := "res://assets/fx/badge_%s.png" % tid
		var ex: bool = ResourceLoader.exists(bp)
		var tex = load(bp) if ex else null
		var tsz := "null"
		var tpx := "null"
		if tex != null:
			tsz = str(tex.get_size())
			var im: Image = tex.get_image()
			if im != null:
				tpx = "%s" % im.get_pixelv(Vector2i(im.get_width() / 2, im.get_height() / 2))
		_emit("  [%d] syllable=%s trait=%s has_icon=%s path=%s exists=%s tex_size=%s tex_center=%s" % [
			i, str(t.syllable), tid, has_icon, bp, ex, tsz, tpx])
		_emit("      tower: pos=%s modulate=%s self_modulate=%s material=%s z=%d visible=%s" % [
			t.global_position, t.modulate, t.self_modulate, t.material, t.z_index, t.visible])
		var kids: PackedStringArray = []
		for k in t.get_children():
			var extra := ""
			if k is CanvasItem:
				extra = " mod=%s z=%d vis=%s mat=%s" % [(k as CanvasItem).modulate, (k as CanvasItem).z_index, (k as CanvasItem).visible, (k as CanvasItem).material]
			kids.append("%s(%s)%s" % [k.name, k.get_class(), extra])
		_emit("      children: %s" % " | ".join(kids))

	# 픽셀 — 배지 중심. ⚠️ `global_position` 은 필드(Control) 기준이라 음수가 나온다.
	# 캔버스(화면) 좌표는 `get_global_transform_with_canvas().origin` 이다.
	var img := get_viewport().get_texture().get_image()
	img.save_png("E:/project/word_card/tmp/badgereal.png")
	_emit("field: scale=%s pos=%s size=%s modulate=%s self_modulate=%s material=%s texture_filter=%d" % [
		field.scale, field.global_position, field.size, field.modulate, field.self_modulate,
		field.material, field.texture_filter])
	var names := ["냉기", "빙마", "섬광"]
	for i in towers.size():
		var t = towers[i]
		if t == null:
			continue
		var base: Vector2 = t.get_global_transform_with_canvas().origin
		var c: Vector2 = base + Vector2(38.0 * 0.53, -38.0 * 0.53)
		var px: Color = img.get_pixelv(Vector2i(int(c.x), int(c.y)))
		var px2: Color = img.get_pixelv(Vector2i(int(c.x) - 8, int(c.y)))
		_emit("  PIXEL [%d] %s 화면=%s 배지중심=%s = %s  좌8 = %s %s" % [i, names[i], Vector2i(int(base.x), int(base.y)),
			Vector2i(int(c.x), int(c.y)), px, px2,
			"★순백" if px.r > 0.99 and px.g > 0.99 and px.b > 0.99 else ""])

	# ── 인과 시험: 배지 분기를 끈다 ──
	# `_draw_trait_badge_on` 은 `TraitStyle.has_icon(trait_id)` 가 false 면 즉시 return 한다.
	# `balanced` 는 그 조건에 걸린다(COLORS 에 있지만 has_icon 이 배제한다).
	# 흰 사각형이 사라지면 그리는 주체는 **배지 분기가 맞다**.
	for t in towers:
		if t != null:
			t.trait_id = "balanced"
			for k in t.get_children():
				if k is Node2D and k.z_index == 2:
					k.queue_redraw()
			t.queue_redraw()
	for i in 30:
		await get_tree().process_frame
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png("E:/project/word_card/tmp/badgereal_off.png")
	for i in towers.size():
		var t = towers[i]
		if t == null:
			continue
		var base2: Vector2 = t.get_global_transform_with_canvas().origin
		var c2: Vector2 = base2 + Vector2(38.0 * 0.53, -38.0 * 0.53)
		var q: Color = img2.get_pixelv(Vector2i(int(c2.x), int(c2.y)))
		_emit("  OFF   [%d] %s 배지중심=%s = %s %s" % [i, names[i], Vector2i(int(c2.x), int(c2.y)), q,
			"★순백" if q.r > 0.99 and q.g > 0.99 and q.b > 0.99 else ""])

	_emit("BADGEREAL_DONE")
	get_tree().quit(0)
