class_name MergeTile
extends RefCounted
## 타일 하나를 그리는 **정적 도구**. 노드가 아니다 — 보드가 `_draw()` 안에서 부른다.
##
## ⚠️ **별(★ U+2605)은 neodgm.ttf 에 없다** — 그래서 별은 글자가 아니라 **도형**으로 그린다.
##    (기존 프로젝트 `언어의 조각` 의 §2.37 "폰트 밖 글리프" 와 같은 함정.)
##    같은 이유로 ☀ · → · ⚙ · ♥ 도 쓰지 않는다. ▶ ● ◆ × · 는 폰트에 있다.

const FONT := preload("res://fonts/neodgm.ttf")


## 타일 한 장. `selected` 면 흰 고리, `dim` 이면 흐리게.
static func draw_tile(ci: CanvasItem, rect: Rect2, jamo: String, tier: int,
		selected := false, dim := false) -> void:
	if rect.size.x < 8.0 or rect.size.y < 8.0:
		return
	var tc := MergePalette.tier_color(tier)
	var radius := minf(rect.size.x, rect.size.y) * 0.15
	var alpha := 0.42 if dim else 1.0

	var bg := StyleBoxFlat.new()
	var base := MergePalette.tier_bg(tier)
	bg.bg_color = Color(base.r, base.g, base.b, alpha)
	bg.set_corner_radius_all(int(radius))
	bg.set_border_width_all(2)
	bg.border_color = Color(tc.r, tc.g, tc.b, alpha)
	ci.draw_style_box(bg, rect)

	var fs := int(rect.size.y * 0.44)
	var tw := FONT.get_string_size(jamo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(FONT,
		rect.position + Vector2((rect.size.x - tw) * 0.5, rect.size.y * 0.545),
		jamo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color(MergePalette.TEXT.r, MergePalette.TEXT.g, MergePalette.TEXT.b, alpha))

	var n := clampi(tier, 1, 7)
	var sr := maxf(3.4, rect.size.y * 0.078)
	var step := sr * 2.35
	var cy := rect.position.y + rect.size.y - sr * 1.8
	var cx := rect.position.x + rect.size.x * 0.5 - step * float(n - 1) * 0.5
	for i in n:
		ci.draw_colored_polygon(star_points(Vector2(cx + step * float(i), cy), sr),
			Color(tc.r, tc.g, tc.b, alpha))

	if selected:
		var ring := StyleBoxFlat.new()
		ring.bg_color = Color(0, 0, 0, 0)
		ring.set_corner_radius_all(int(radius + 2.0))
		ring.set_border_width_all(3)
		ring.border_color = MergePalette.TOWER_RING
		ci.draw_style_box(ring, Rect2(rect.position - Vector2(3, 3), rect.size + Vector2(6, 6)))


## 별 하나의 꼭짓점 10개 (바깥 5 + 안쪽 5).
static func star_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + float(i) * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.44
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts
