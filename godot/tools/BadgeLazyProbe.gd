# BadgeLazyProbe.gd
# **지연 로드 vs 사전 로드** 를 같은 프레임에서 갈라 잰다.
#
# 왜 필요한가:
#   BadgeRealPathProbe 로 원인 주체는 확정됐다 — `trait_id` 를 `balanced` 로 바꿔
#   `_draw_trait_badge_on` 의 배지 분기를 끄면 흰 사각형이 사라진다.
#   남은 질문은 **왜 그 텍스처가 흰색으로 그려지는가** 다.
#   텍스처의 CPU 이미지는 정상이고(24x24 어두운 남색), 고립 렌더도 정상이었다.
#   유일한 차이는 **언제 load() 했는가** 다:
#     · 게임의 `_draw_trait_badge_on` 은 `_draw()` 안에서 `load()` 한다 (지연)
#     · 내 고립 프로브는 `_ready()` 에서 미리 `load()` 해 두었다 (사전)
#   실측 기록: 사전 로드한 실행에서는 전부 정상, 지연 로드한 실행에서는 순백이 나왔다.
#
# 이 프로브가 가르는 것 (한 프레임, 서로 다른 텍스처를 써서 서로를 오염시키지 않는다):
#   L1 badge_control  — 그리기 안에서 load()   (게임과 같은 방식)
#   L2 badge_chain    — 그리기 안에서 load()
#   P1 badge_rapid    — _ready() 에서 미리 load()
#   P2 badge_meteor   — _ready() 에서 미리 load()
#   N  null 텍스처     — draw_texture_rect(null) 이 흰 사각형인지 확인
#
# 보고 전용. 판정하지 않는다.
extends Node2D

const OUT_PATH := "E:/project/word_card/tmp/badgelazy_out.txt"
var _lines: PackedStringArray = []

class _Drawer extends Node2D:
	var path := ""
	var tex: Texture2D = null
	var lazy := false
	var at := Vector2.ZERO
	var size := Vector2(32, 32)
	## 그리기 시점에 `load()` 가 실제로 무엇을 돌려주는지 기록한다.
	var last_class := "(아직 안 그림)"
	var last_size := Vector2.ZERO
	func _draw() -> void:
		var t: Texture2D = load(path) if lazy else tex
		if t != null:
			last_class = t.get_class()
			last_size = t.get_size()
		else:
			last_class = "(null)"
		draw_texture_rect(t, Rect2(at, size), false)

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

func _mk(lazy: bool, file: String, at: Vector2, size := Vector2(32, 32)) -> _Drawer:
	var d := _Drawer.new()
	d.path = "res://assets/fx/%s.png" % file
	d.lazy = lazy
	d.at = at
	d.size = size
	if not lazy:
		d.tex = load(d.path)
	add_child(d)
	return d

func _ready() -> void:
	_watchdog()
	# ⚠️ 순서 주의: 지연(L) 케이스의 텍스처를 사전 로드(P)가 먼저 캐시하면 시험이 무효가 된다.
	#    그래서 L 과 P 는 **서로 다른 텍스처**를 쓴다.
	var l1 := _mk(true, "badge_control", Vector2(100, 100))
	var l2 := _mk(true, "badge_chain", Vector2(250, 100))
	var p1 := _mk(false, "badge_rapid", Vector2(400, 100))
	var p2 := _mk(false, "badge_meteor", Vector2(550, 100))
	var nn := _Drawer.new()
	nn.tex = null
	nn.at = Vector2(100, 250)
	add_child(nn)
	_emit("L1 lazy=%s tex(사전)=%s | L2 lazy=%s | P1 tex=%s | P2 tex=%s | N tex=%s" % [
		l1.lazy, l1.tex, l2.lazy, p1.tex, p2.tex, nn.tex])

	for i in 30:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("E:/project/word_card/tmp/badgelazy.png")
	_emit("── A: 첫 그리기 직후 ──")
	for entry in [["L1 badge_control(지연)", l1], ["L2 badge_chain(지연)", l2],
			["P1 badge_rapid(사전)", p1], ["P2 badge_meteor(사전)", p2], ["N  null", nn]]:
		var d: _Drawer = entry[1]
		var mid := Vector2i(int(d.at.x + d.size.x / 2.0), int(d.at.y + d.size.y / 2.0))
		var c: Color = img.get_pixelv(mid)
		_emit("  %-26s 중앙=%s %s" % [entry[0], c,
			"★순백" if c.r > 0.99 and c.g > 0.99 and c.b > 0.99 else ""])

	# ── B: 다시 그리게 하면 고쳐지는가 ──
	# `_draw()` 는 `queue_redraw()` 때만 다시 돈다. 그 시점엔 텍스처가 이미 캐시되어 있으므로
	# 두 번째 그리기는 정상이어야 한다 — 즉 흰 사각형은 '첫 그리기' 산물이라는 가설의 검증.
	for entry in [l1, l2, p1, p2, nn]:
		(entry as Node2D).queue_redraw()
	for i in 30:
		await get_tree().process_frame
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png("E:/project/word_card/tmp/badgelazy_b.png")
	_emit("── B: queue_redraw() 뒤 ──")
	for entry in [["L1 badge_control(지연)", l1], ["L2 badge_chain(지연)", l2],
			["P1 badge_rapid(사전)", p1], ["P2 badge_meteor(사전)", p2], ["N  null", nn]]:
		var d2: _Drawer = entry[1]
		var mid2 := Vector2i(int(d2.at.x + d2.size.x / 2.0), int(d2.at.y + d2.size.y / 2.0))
		var c2: Color = img2.get_pixelv(mid2)
		_emit("  %-26s 중앙=%s %s" % [entry[0], c2,
			"★순백" if c2.r > 0.99 and c2.g > 0.99 and c2.b > 0.99 else ""])
	_emit("BADGELAZY_DONE")
	get_tree().quit(0)
