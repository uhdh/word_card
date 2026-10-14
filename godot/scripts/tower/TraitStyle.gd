# TraitStyle.gd
# 특성(trait) 하나의 **이름 · 색 · 아이콘** 을 한 곳에서 정의한다.
#
# 왜 필요한가:
#   같은 정보가 세 곳에 흩어져 서로 어긋나 있었다.
#     1. WordTower.TRAIT_NAMES  — 한국어 이름 (11종)
#     2. TowerInfoModal._synergy_style() — 이름→(글리프, 색) 표 (9종, 한국어 라벨 키)
#     3. Projectile._apply_trait_appearance() — 탄 외형/색
#   그래서 2번에 없는 선회/유성은 ◆ 로 떨어졌고, 라벨 접두사가 "특성: " 에서
#   "뜻: " 로 늘어나면서 **표에 있던 특성까지 전부 ◆** 가 됐다(실측: 정보 모달의
#   활성 시너지 줄이 ◆ 4개로만 채워져 있었다).
#
#   그리고 글리프를 이모지(⚡💥🔗❄🔥🎯🗡⚖)로 쓰고 있었다. 이 게임의 유일한 폰트인
#   neodgm.ttf 에는 그 코드포인트가 **하나도 없다**(실측: ⚡ 와 \uFFFD 의 잉크 픽셀 수가
#   160 으로 동일 = 둘 다 두부).
#
#   다만 실기에서는 이모지가 **보인다** — Godot 이 OS 폰트로 대체해 주기 때문이다.
#   (실측: neodgm 에 없는 ★·🪙·✖ 가 각각 별·주황 동전·보라 X 로 그려진다.
#    Windows 의 Segoe UI Emoji 가 쓰인다.)
#   그래도 **타워 위 아이콘은 직접 그린다**: OS 폰트 대체에 기대면 빌드/플랫폼에 따라
#   아이콘이 통째로 두부가 될 수 있고, 무엇보다 이모지는 서로 모양이 달라도
#   작은 크기에서는 '노란 얼룩' 으로 뭉개져 구분이 안 된다. 직접 그리면 모양이
#   서로 확실히 다르고, 어떤 환경에서도 같은 그림이 나온다.
#   (텍스트 표면인 정보 모달은 이모지를 그대로 쓴다 — 거기서는 크기가 충분하다)
#
# class_name 을 쓰지 않는다 — 전역 클래스 캐시를 다시 만들어야 다른 스크립트가
# 인식하고, 그걸 빠뜨리면 Parse Error 로 죽는다. 프로젝트 관례대로 preload 한다.
extends RefCounted

## 특성 id → 한국어 이름. WordTower.TRAIT_NAMES 의 단일 출처가 이것이다.
##
## ⚠️ **여기에 상성을 손으로 적지 마라 — §2.18 · §5.2 29 (C), 2026-10-01.**
##    예전에는 네 줄이 `(중갑/방어형에 효과적)` 같은 괄호를 달고 있었고, 그중 `rapid` 는
##    **거짓**이었다 — *"민첩/고속형에 효과적"* 이라 약속하는데 표에서 `rapid` 는 질풍에
##    **1.00(중립)** 이고 오히려 **중갑 0.65 · 재생 0.70** 으로 깎인다. 게다가 `민첩`·`고속형`·
##    `방어형` 은 **배지 라벨이 아니라서** 플레이어가 머릿속에서 번역해야 했다.
##    이제 상성은 `MonsterRoster.trait_counter_text()` 가 **표에서 뽑는다**
##    (`type_counter_text()` 와 같은 규칙). 손으로 적은 사본이 없으므로 표를 고치면 문구가
##    따라오고, 드리프트가 **원리적으로 불가능**하다.
##    → 문구가 필요한 곳은 이 표를 직접 읽지 말고 `MonsterRoster.trait_full_desc()` 를 써라.
##
## 이 표가 담는 것은 **행동 설명**뿐이다. `orbit` 의 `(우클릭으로 방향 전환)` 은 상성이
## 아니라 조작 안내이므로 여기 남는다.
const DESCRIPTIONS: Dictionary = {
	"pierce": "관통: 적을 꿰뚫어 뒤편의 적까지 다수(최대 3체)를 동시에 타격합니다.",
	"splash": "폭발: 착탄 지점 주변의 적들에게 폭발 피해를 입힙니다.",
	"rapid": "연사: 매우 빠른 속도로 탄환을 쉼 없이 난사합니다.",
	"sniper": "저격: 긴 사거리와 강력한 단발 위력으로 목표를 저격합니다.",
	"control": "둔화: 착탄 지점 주변의 적들에게 스플래쉬 냉기 피해를 입히고 이동 속도를 둔화시킵니다.",
	"damage_over_time": "지속 피해: 화염/독 등으로 적에게 지속 피해를 누적시킵니다.",
	"chain": "연쇄: 전격이 적중한 적 주변의 다른 적들에게 연쇄적으로 튕기며 피해를 줍니다.",
	"bounce": "3연속 바운스: 탄환이 주변 적들 사이를 최대 3회 튕기며 타격합니다.",
	"orbit": "선회: 타워 주위를 도는 구체가 적에게 닿을 때마다 지속 피해를 줍니다. (우클릭으로 방향 전환)",
	"meteor": "유성: 하늘에서 거대한 유성이 떨어져 넓은 범위를 강력하게 불태웁니다.",
	"balanced": "균형: 사거리와 공격 주기가 안정적인 기본 공격 형태입니다.",
}

static func desc_for(trait_id: String) -> String:
	return str(DESCRIPTIONS.get(trait_id, ""))

## 설명 문구 안에서 특성 키워드를 찾는 표. **구체적인 것이 먼저** 온다 — "3연속 바운스" 가
## "바운스" 보다, "지속 관통" 이 "관통" 보다 먼저 잡혀야 한다. **이 순서가 곧 우선순위다.**
##
## ⚠️ 이 표를 쓰는 곳이 둘이다: `enrich_text_with_hints`(툴팁 힌트) 와
##    `trait_id_in_text`(상점 유물 카드의 특성 배지). **사본을 만들지 마라** — 한쪽만
##    고치면 같은 문구가 두 화면에서 다른 특성으로 읽힌다.
const KEYWORDS: Array = [
	{"word": "3연속 바운스", "trait": "bounce"},
	{"word": "지속 피해", "trait": "damage_over_time"},
	{"word": "지속 관통", "trait": "pierce"},
	{"word": "방어관통", "trait": "pierce"},
	{"word": "신속관통", "trait": "pierce"},
	{"word": "관통기공파", "trait": "pierce"},
	{"word": "관통", "trait": "pierce"},
	{"word": "폭발", "trait": "splash"},
	{"word": "연사", "trait": "rapid"},
	{"word": "저격", "trait": "sniper"},
	{"word": "둔화", "trait": "control"},
	{"word": "제어", "trait": "control"},
	{"word": "연쇄", "trait": "chain"},
	{"word": "선회", "trait": "orbit"},
	{"word": "유성", "trait": "meteor"},
	{"word": "바운스", "trait": "bounce"},
]

## 설명 문구 내의 특성 키워드에 마우스 오버 시 설명 팝업이 뜨는 [hint] BBCode를 적용합니다.
## filter_trait_id 가 지정되면 해당 타워가 실제로 가진 특성 키워드에만 힌트를 적용합니다.
static func enrich_text_with_hints(text: String, filter_trait_id: String = "") -> String:
	var tokens: Dictionary = {}
	var token_idx := 0
	var result := text

	for kw in KEYWORDS:
		var w: String = kw["word"]
		var tid: String = kw["trait"]
		if filter_trait_id != "" and tid != filter_trait_id:
			continue
		if result.contains(w):
			var token := "@@TRAIT_%d@@" % token_idx
			token_idx += 1
			var desc := desc_for(tid)
			var col := color_for(tid).to_html(false)
			tokens[token] = "[hint=%s][color=#%s][u]%s[/u][/color][/hint]" % [desc, col, w]
			result = result.replace(w, token)

	for token in tokens:
		result = result.replace(token, tokens[token])

	return result


## 문구가 말하는 **첫 특성**의 id. 어느 키워드도 없으면 `""`.
##
## ⚠️ 문구에서 **가장 앞에 나오는** 키워드가 아니라 **표 순서상 먼저 오는** 키워드를 고른다.
##    `KEYWORDS` 가 구체적인 것부터 정렬돼 있어야 "3연속 바운스" 가 "바운스" 로 읽히지
##    않는다 — 툴팁 힌트(`enrich_text_with_hints`)와 **같은 규칙**이어야 두 표면이 같은
##    문구를 같은 특성으로 가리킨다.
##
## 쓰는 곳: 상점 유물 카드가 설명 앞에 붙일 **특성 배지**를 고를 때.
static func trait_id_in_text(text: String) -> String:
	for kw in KEYWORDS:
		if text.contains(str(kw["word"])):
			return str(kw["trait"])
	return ""


const NAMES: Dictionary = {
	"balanced": "균형", "sniper": "저격", "damage_over_time": "지속 피해",
	"splash": "폭발", "rapid": "연사", "pierce": "관통", "control": "둔화",
	"chain": "연쇄", "bounce": "3연속 바운스", "orbit": "선회", "meteor": "유성",
}

## ⚠️ §2.38 (2026-10-06) — 여기 있던 `GLYPHS`(11종) 와 `glyph_for()` 를 **지웠다.**
##    유일한 소비자가 `TowerInfoModal` 의 *텍스트* 시너지 표면이었는데, 그 표면이
##    씬에서 `visible = false` 이고 `visible = true` 대입이 `godot/` 전체에 0건이라
##    **영영 안 보였다.** 배지가 같은 정보를 벡터 아이콘(`TraitIcon`)으로 나르므로
##    잃는 정보는 0 이다 — 그리고 그 이모지들은 이 폰트에 없어 **OS 폴백**으로 그려졌다
##    (§2.30-4 · §2.37: 폰트 밖 글리프 14종이 이 표면들에서 나왔다).
##    ⚠️ 여기 남은 `NAMES` · `COLORS` 는 **배지가 실제로 쓴다** — 지우면 안 된다.

## 특성 id → 아이콘 색.
## 예전 TowerInfoModal 의 색을 그대로 이어받되, 빠져 있던 선회/유성을 채웠다.
## (선회 = 궤도를 도는 차가운 청록, 유성 = 낙하하는 주황)
const COLORS: Dictionary = {
	"balanced": Color("#8de8ff"),
	"sniper": Color("#ff8a65"),
	"damage_over_time": Color("#ffb04a"),
	"splash": Color("#ff6b9d"),
	"rapid": Color("#ffe66d"),
	"pierce": Color("#d7dce5"),
	"control": Color("#72cfff"),
	"chain": Color("#c99cff"),
	"bounce": Color("#80e27e"),
	"orbit": Color("#7fe3d4"),
	"meteor": Color("#ff9a5c"),
}

const FALLBACK_COLOR := Color("#ffffff")


static func name_for(trait_id: String) -> String:
	return str(NAMES.get(trait_id, trait_id))


static func color_for(trait_id: String) -> Color:
	return COLORS.get(trait_id, FALLBACK_COLOR)


## 이 특성이 '아이콘을 그릴 만한가'.
## 균형은 아무 특징이 없다는 뜻이라 배지를 달지 않는다 — 배지가 기본값이면
## 아무 정보도 되지 못하고 타워만 지저분해진다.
static func has_icon(trait_id: String) -> bool:
	return trait_id != "balanced" and COLORS.has(trait_id)


## 특성 아이콘을 직접 그린다. 폰트에 의존하지 않는다.
##
## center 는 그릴 중심, radius 는 아이콘이 차지할 수 있는 최대 반지름(px).
## 모든 도형은 이 원 안에 들어가도록 비율로만 잡는다 — 타워 크기가 바뀌어도
## 같이 커지고 작아진다.
static func draw_icon(canvas: CanvasItem, center: Vector2, radius: float, trait_id: String, col: Color) -> void:
	var r := radius
	match trait_id:
		"sniper":
			# 조준 십자 — 링 + 사방 눈금
			canvas.draw_arc(center, r * 0.45, 0, TAU, 20, col, 1.3)
			for i in 4:
				var a := TAU * float(i) / 4.0
				var d := Vector2(cos(a), sin(a))
				canvas.draw_line(center + d * r * 0.45, center + d * r, col, 1.3)
		"splash":
			# 폭발 — 중심에서 뻗는 8가닥 + 가운데 점
			for i in 8:
				var a := TAU * float(i) / 8.0
				var d := Vector2(cos(a), sin(a))
				canvas.draw_line(center + d * r * 0.3, center + d * r, col, 1.4)
			canvas.draw_circle(center, r * 0.26, col)
		"rapid":
			# 연사 — 오른쪽으로 겹쳐지는 3개의 화살촉
			for i in 3:
				var x := center.x - r * 0.55 + r * 0.55 * float(i)
				canvas.draw_line(Vector2(x - r * 0.3, center.y - r * 0.6), Vector2(x, center.y), col, 1.5)
				canvas.draw_line(Vector2(x, center.y), Vector2(x - r * 0.3, center.y + r * 0.6), col, 1.5)
		"chain":
			# 연쇄 — 작은 고리 둘을 선으로 이음
			var a := center + Vector2(-r * 0.45, 0)
			var b := center + Vector2(r * 0.45, 0)
			canvas.draw_arc(a, r * 0.36, 0, TAU, 16, col, 1.3)
			canvas.draw_arc(b, r * 0.36, 0, TAU, 16, col, 1.3)
			canvas.draw_line(a, b, col, 1.1)
		"control":
			# 제어 — 눈송이(6갈래) + 끝의 잔가지
			for i in 3:
				var a := TAU * float(i) / 3.0
				var d := Vector2(cos(a), sin(a))
				canvas.draw_line(center - d * r, center + d * r, col, 1.3)
				for s in [-1.0, 1.0]:
					var tip: Vector2 = center + d * r * s
					var back: Vector2 = center + d * r * 0.55 * s
					var side := Vector2(-d.y, d.x) * r * 0.3
					canvas.draw_line(tip, back + side, col, 1.1)
					canvas.draw_line(tip, back - side, col, 1.1)
		"damage_over_time":
			# 지속 피해 — 불꽃 잎사귀
			canvas.draw_polygon(PackedVector2Array([
				center + Vector2(0, -r),
				center + Vector2(r * 0.5, -r * 0.1),
				center + Vector2(r * 0.32, r * 0.55),
				center + Vector2(0, r * 0.8),
				center + Vector2(-r * 0.32, r * 0.55),
				center + Vector2(-r * 0.5, -r * 0.1),
			]), PackedColorArray([col]))
		"pierce":
			# 관통 — 화살 (자루 + 촉)
			canvas.draw_line(center + Vector2(-r, r * 0.6), center + Vector2(r * 0.5, -r * 0.35), col, 1.5)
			canvas.draw_polygon(PackedVector2Array([
				center + Vector2(r, -r * 0.75),
				center + Vector2(r * 0.15, -r * 0.5),
				center + Vector2(r * 0.45, r * 0.3),
			]), PackedColorArray([col]))
		"orbit":
			# 선회 — 궤도 링 + 그 위를 도는 점
			canvas.draw_arc(center, r * 0.72, 0, TAU, 24, col, 1.2)
			canvas.draw_circle(center + Vector2(r * 0.72, 0), r * 0.28, col)
		"meteor":
			# 유성 — 덩어리 + 꼬리 3줄
			canvas.draw_circle(center + Vector2(r * 0.3, r * 0.3), r * 0.45, col)
			for i in 3:
				var off := r * (0.12 + 0.24 * float(i))
				canvas.draw_line(center + Vector2(-r * 0.75, -r * 0.75) + Vector2(off, off) * 0.35,
					center + Vector2(-r * 0.15, -r * 0.15) + Vector2(off, off) * 0.35, col, 1.2)
		"bounce":
			# 3연속 바운스 — 포물선 위의 점 3개
			for i in 3:
				var t := float(i) / 2.0
				var p := center + Vector2((t - 0.5) * r * 1.6, -sin(t * PI) * r * 0.55 + r * 0.35)
				canvas.draw_circle(p, r * 0.24, col)
		_:
			# 표에 없는 특성 — 최소한 '무엇인가 있다' 는 것만 보인다.
			canvas.draw_arc(center, r * 0.6, 0, TAU, 20, col, 1.4)
