# TargetingStyle.gd
# 조준(targeting) 우선순위 하나의 **아이콘 · 색** 을 한 곳에서 정의한다.
#
# 왜 필요한가:
#   정보 모달의 조준 행은 오랫동안 `진급 우선 — 가장 가까운 적부터 노린다…` 라는
#   **글자만** 보여 줬다. 네 모드가 전부 같은 모양이라, 플레이어는 문장을 다 읽어야만
#   지금 무엇을 노리는지 알 수 있었다. 바로 위의 유물 칩에는 아이콘이 붙는데 조준 행만
#   비어 있어서, 같은 모달 안에서 두 행의 정보 밀도가 달랐다(2026-10-05).
#
#   이름·설명은 WordTower.gd(TARGETING_NAMES · TARGETING_DESCS)에 있다 — **여기에 다시
#   적지 않는다.** 이 파일은 `id → 아이콘·색` 만 담는다. 두 표가 서로 다른 것을 담으므로
#   ("채널이 하나면 작성자도 하나") 갈라질 여지가 없다. 모드를 새로 추가하고 여기를
#   안 고치면 그 모드만 아이콘 없이 나오는데, `TargetingProbe` 가
#   `TARGETING_MODES ⊆ COLORS` 를 단언해 그 조용한 누락을 잡는다.
#
#   아이콘은 **직접 그린다** — TraitStyle 과 같은 이유다. 이모지는 OS 폰트 대체에
#   기대게 되고, 12px 줄에서는 네 모드가 서로 구분되지 않는 '노란 얼룩' 이 된다.
#   (TraitStyle 은 "텍스트 표면인 정보 모달은 이모지를 그대로 쓴다" 고 적어 두었지만,
#    그건 *설명 문장 속* 의 경우다. 여기 아이콘은 **네 개를 구별해야 하는 부호**라
#    모양이 확실히 달라야 한다.)
#
#   ⚠️ 아이콘은 **거짓말하지 않는다** — 모양이 실제 선택 규칙과 같아야 한다.
#   규칙은 WordTower._targeting_score() 다:
#     first  = progress 최대(기지에 가장 가까운 적) → 기지 막대에 **닿은** 화살촉
#     last   = progress 최소(가장 뒤처진 적)         → 기지에서 **멀리 물러난** 화살촉
#     strong = hp 최대                              → 큰 덩어리
#     close  = 타워와의 거리 최소                    → 나를 감싸는 동심 링
#
# class_name 을 쓰지 않는다 — 프로젝트 관례대로 preload 한다.
extends RefCounted

## 조준 모드 id → 아이콘 색. 네 모드가 서로 다른 색이라, 모양이 작아도 '방금 바뀌었다'
## 는 것이 즉시 보인다(전환 버튼을 누르는 순간의 피드백).
## 특성 배지 색(TraitStyle.COLORS)과 겹치지 않게 골랐다 — 한 모달 안에 둘이 같이 뜬다.
const COLORS: Dictionary = {
	"first": Color("#ffd166"),   # 진급 — 기지에 가장 가까운 적. 따뜻한 금색.
	"last": Color("#b9c6dd"),    # 후미 — 가장 뒤처진 적. 차분한 청회색.
	"strong": Color("#ff7a7a"),  # 강적 — 체력이 가장 높은 적. 붉은색.
	"close": Color("#7fd8ff"),   # 근접 — 내 타워에 가장 가까운 적. 하늘색.
}

const FALLBACK_COLOR := Color("#c8d2e0")

## '맥락' 요소(기지 막대·작은 적)의 색. 강조색을 어둡게 깎아 만든다 —
## 색을 하나 더 손으로 적으면 그 색만 표에서 떨어져 나간다.
## ⚠️ 0.45 로 두었더니 **14px 에서 막대·작은 점이 사라졌다**(실측 스크린샷) —
## 12px 줄에 놓이는 부호라 맥락 요소도 배경 대비를 확보해야 한다.
const CONTEXT_DARKEN := 0.30

## **채워진** 맥락 요소(작은 적 덩어리)는 얇은 선(막대·링)보다 잉크가 많아 덜 깎아도 보인다.
## 선과 같은 값으로 두면 강조색과 구별되지 않아 '큰 놈 + 작은 놈' 이 한 덩어리로 뭉친다.
const CONTEXT_DARKEN_FILLED := 0.25


static func color_for(mode: String) -> Color:
	return COLORS.get(mode, FALLBACK_COLOR)


## 조준 아이콘을 직접 그린다. 폰트에 의존하지 않는다.
##
## center 는 그릴 중심, radius 는 아이콘이 차지할 수 있는 최대 반지름(px).
## 모든 도형은 이 원 안에 들어가도록 비율로만 잡는다 — 행 높이가 바뀌어도 같이 커진다.
static func draw_icon(canvas: CanvasItem, center: Vector2, radius: float, mode: String, col: Color) -> void:
	var r := radius
	var dim := col.darkened(CONTEXT_DARKEN)
	match mode:
		"first":
			# 기지(오른쪽 세로 막대)에 **닿은** 적 — 막대를 향해 뻗은 화살촉.
			var bx := center.x + r * 0.85
			canvas.draw_line(Vector2(bx, center.y - r * 0.85), Vector2(bx, center.y + r * 0.85), dim, 1.8)
			canvas.draw_polygon(PackedVector2Array([
				Vector2(bx - r * 1.05, center.y - r * 0.50),
				Vector2(bx - r * 1.05, center.y + r * 0.50),
				Vector2(bx - r * 0.05, center.y),
			]), PackedColorArray([col]))
		"last":
			# 같은 기지 막대에서 **멀리 물러난** 적 — 뒤를 향해 돌아선 화살촉.
			var bx := center.x + r * 0.85
			canvas.draw_line(Vector2(bx, center.y - r * 0.85), Vector2(bx, center.y + r * 0.85), dim, 1.8)
			# first 와 **같은 크기**(폭 1.0r)의 화살촉을 뒤집어, 막대에서 멀리 둔다.
			canvas.draw_polygon(PackedVector2Array([
				Vector2(center.x - r * 1.00, center.y),
				Vector2(center.x, center.y - r * 0.50),
				Vector2(center.x, center.y + r * 0.50),
			]), PackedColorArray([col]))
		"strong":
			# 큰 적 하나 + 작은 적 하나 — '가장 큰 놈' 을 고른다는 뜻.
			canvas.draw_circle(center + Vector2(-r * 0.28, -r * 0.06), r * 0.60, col)
			canvas.draw_circle(center + Vector2(r * 0.58, r * 0.50), r * 0.30, col.darkened(CONTEXT_DARKEN_FILLED))
		"close":
			# 바로 앞의 적 — 나(중심)를 좁은 링이 감싼다.
			canvas.draw_arc(center, r * 0.80, 0, TAU, 20, dim, 1.5)
			canvas.draw_circle(center, r * 0.32, col)
		_:
			# 표에 없는 모드 — 최소한 '무엇인가 있다' 는 것만 보인다.
			canvas.draw_arc(center, r * 0.6, 0, TAU, 20, col, 1.4)
