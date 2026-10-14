# TraitIcon.gd
# 특성 하나를 나타내는 **그려진 배지** — 타워 위 배지 · 정보창 특성 칩 · 상점 유물 카드가
# 전부 이 하나를 쓴다.
#
# 왜 파일로 뽑았는가 (2026-10-05):
#   정보창(`TowerInfoModal`)은 `TraitIconControl` 을 **자기 안에** 정의해 쓰고 있었다.
#   상점 유물 카드에도 같은 배지가 필요해지자 같은 12줄을 한 번 더 쓰게 생겼는데,
#   `TraitStyle` 은 애초에 "같은 정보가 세 곳에 흩어져 서로 어긋났다" 를 고치려고
#   만들어진 파일이다. 그 아이콘 위젯을 **네 번째 사본**으로 늘리는 건 그 실수를
#   그대로 반복하는 일이라, 여기 하나만 둔다.
#
# ⚠️ 그리는 것은 `TraitStyle.draw_icon()` 하나다 — 이 파일은 **크기와 배치**만 정한다.
#    모양을 여기서 다시 그리면 배지와 타워 아이콘이 곧 갈라진다.
#
# ⚠️ `_draw()` 안에서 처음 `load()` 를 하지 않는다(§2.25) — 첫 프레임이 흰 사각형으로
#    구워진다. 여기서는 이미 preload 된 상수만 쓴다.
#
# class_name 을 쓰지 않는다 — 프로젝트 관례대로 preload 한다.
extends Control

const TraitStyle = preload("res://scripts/tower/TraitStyle.gd")

var trait_id: String = ""
var col: Color = Color.WHITE

## `p_px` 는 아이콘이 차지할 **정사각 한 변**. 컨테이너가 세로로 늘리면 그만큼 커지지 않고
## 가운데에 남는다(아래 `_draw` 주석).
func _init(p_trait_id: String, p_col: Color, p_px: float = 14.0) -> void:
	trait_id = p_trait_id
	col = p_col
	custom_minimum_size = Vector2(p_px, p_px)
	size = Vector2(p_px, p_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	# 반지름은 **가로**로만 잡는다(`size.x`) — 세로는 컨테이너가 늘릴 수 있어서, 그 값에
	# 반지름을 걸면 두 줄짜리 설명 옆에서 아이콘이 커졌다 작아졌다 한다. 중심은 `size * 0.5`
	# 라 세로로 늘어난 만큼 **가운데**에 그려진다(두 줄 설명 옆에서 한 줄에 붙지 않는다).
	TraitStyle.draw_icon(self, size * 0.5, size.x * 0.45, trait_id, col)
