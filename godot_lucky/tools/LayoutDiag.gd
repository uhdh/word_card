extends Node
## 레이아웃 진단 — "설계 해상도(720)를 넘겨 잘리는 컨트롤" 을 이름으로 찾아낸다.
##
##   godot --path godot_lucky res://tools/LayoutDiag.tscn
##
## 왜 필요한가: `Control` 트리에서 **한 자식의 최소 폭**이 크면 부모 `VBox/HBox` 가
## 통째로 넓어지고, 루트가 `PRESET_FULL_RECT` 라도 내용은 뷰포트 밖으로 나가 **잘린다**.
## 눈으로는 "왜 잘렸지" 만 보이고 범인은 안 보인다 → 최소 폭을 재서 이름을 찍는다.
##
## ⚠️ `--headless` 로는 폰트 계측이 안 되므로 **창을 띄워서** 돌린다.

const DESIGN := Vector2i(720, 1140)
const PAD := 32.0     ## 좌우 마진 16 + 16

var _vp: SubViewport


func _ready() -> void:
	OS.low_processor_usage_mode = false
	_vp = SubViewport.new()
	_vp.size = DESIGN
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	var main: Control = load("res://scenes/MergeMain.tscn").instantiate()
	_vp.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.call("_fit_board")

	for _i in 5:
		await get_tree().process_frame

	var budget := float(DESIGN.x) - PAD
	print("LAYOUT viewport=%d budget=%.1f" % [DESIGN.x, budget])

	var offenders := 0
	offenders += _walk(main, budget, 0)
	tall_over = 0
	_tall(main, 120.0)

	# 실제로 뷰포트 밖으로 나간 것도 따로 센다
	var clipped := _clipped(main, 0)

	# 화면이 실제로 **무슨 글자를 말하는지** 덤프한다 (문구 계약 확인용).
	print("LAYOUT text:")
	_text(main)

	# 판정은 **세 개뿐**이다: 넘친 폭 · 넘친 높이 · 잘림.
	#   ⚠️ `TALL_LEAD` 는 판정이 아니라 **조사 대상**이다 — 보드를 담은 컨테이너처럼
	#      정당하게 큰 것도 걸린다. 세로 넘침 여부는 `tall_over`(뷰포트 높이 초과)로 본다.
	print("LAYOUT_DONE min_width_offenders=%d tall_over=%d clipped=%d" % [offenders, tall_over, clipped])
	get_tree().quit(0)


func _text(node: Node) -> void:
	if node is Label:
		var t := str((node as Label).text)
		if t != "":
			print("  LABEL " + t)
	elif node is ProgressBar:
		print("  BAR   value=%.1f / %.1f" % [(node as ProgressBar).value, (node as ProgressBar).max_value])
	for child in node.get_children():
		_text(child)


## 최소 '높이' 로 세로 넘침을 판정한다.
##
## ⚠️ **임계 둘을 구분하라.** 처음엔 `m.y > 120` 을 그대로 `tall` 로 세었는데, 보드를 담은
##    `MarginContainer`·`VBoxContainer` 가 정상적으로 380px 짜리라 **늘 3개가 뜨고**, 아무 문제
##    없는데도 "회귀했다" 고 오해하게 만들었다. 그래서
##      - **판정** = `tall_over`: 최소 높이가 **뷰포트 높이(1140)를 넘는** 컨트롤 → 진짜 넘침
##      - **단서** = `TALL_LEAD`: 120px 초과 → 조사해 볼 목록일 뿐, 컨테이너는 클 수 있다
##    로 나눴다. 줄바꿈 Label 이 폭 0 상태에서 부풀면 `tall_over` 쪽에 뜬다.
var tall_over := 0


func _tall(node: Node, lead: float) -> void:
	if node is Control:
		var c := node as Control
		var m := c.get_combined_minimum_size()
		if m.y > float(DESIGN.y):
			tall_over += 1
		if m.y > lead:
			var txt := ""
			if c is Label:
				txt = " text=%s" % str((c as Label).text).substr(0, 30)
			print("  TALL_LEAD min.y=%.1f %s '%s'%s"
				% [m.y, c.get_class(), str(c.name), txt])
	for child in node.get_children():
		_tall(child, lead)


## 최소 폭이 예산을 넘는 컨트롤을 찾는다.
func _walk(node: Node, budget: float, depth: int) -> int:
	var found := 0
	if node is Control:
		var c := node as Control
		var m := c.get_combined_minimum_size()
		if m.x > budget:
			found += 1
			var txt := ""
			if c is Label:
				txt = " text=%s" % str((c as Label).text).substr(0, 40)
			elif c is Button:
				txt = " text=%s" % str((c as Button).text).substr(0, 40)
			print("  OVER min.x=%.1f (%.1f over) %s '%s'%s"
				% [m.x, m.x - budget, c.get_class(), str(c.name), txt])
	for child in node.get_children():
		found += _walk(child, budget, depth + 1)
	return found


## 전역 rect 의 오른쪽/아래가 뷰포트를 넘는 컨트롤.
func _clipped(node: Node, depth: int) -> int:
	var found := 0
	if node is Control:
		var c := node as Control
		if c.visible:
			var r := c.get_global_rect()
			if r.size.x > 1.0 and (r.end.x > float(DESIGN.x) + 1.0 or r.end.y > float(DESIGN.y) + 1.0):
				found += 1
				print("  CLIP right=%.0f bottom=%.0f %s '%s'"
					% [r.end.x, r.end.y, c.get_class(), str(c.name)])
	for child in node.get_children():
		found += _clipped(child, depth + 1)
	return found
