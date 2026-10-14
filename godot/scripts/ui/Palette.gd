# Palette.gd
# 게임 전체의 단일 색상 소스 (Single Source of Truth).
# docs/design/01_UIUX_AUDIT_AND_PLAN.md §3.1 의 팔레트를 그대로 구현한다.
#
# 규칙: UI 스크립트에서 Color(0.68, 0.45, 0.98) 같은 리터럴을 쓰지 말고
#       반드시 Palette.XXX 를 참조한다. 색을 바꿀 때 이 파일만 고치면 된다.
#
# 사용법:
#   const Palette = preload("res://scripts/ui/Palette.gd")
#   label.add_theme_color_override("font_color", Palette.TX_GOLD)
extends RefCounted
class_name Palette

# ── 배경 계층 (Background Layers) ─────────────────────────────
const BG_VOID      := Color("#0B0A10")   # 최하단, 거의 검정 + 보랏빛
const BG_DEEP      := Color("#12101A")   # 필드 배경
const BG_PANEL     := Color("#1A1726")   # 일반 패널
const BG_PANEL_HI  := Color("#241F33")   # 강조 패널 / 호버
const BG_INSET     := Color("#0E0C15")   # 입력창 / 함몰 영역

# 반투명 버전 (모달 dim, 오버레이)
const BG_VOID_96   := Color(0.043, 0.039, 0.063, 0.96)
const BG_VOID_98   := Color(0.043, 0.039, 0.063, 0.98)

# ── 테두리 (Borders) ──────────────────────────────────────────
const LINE_SUBTLE  := Color("#2E2840")   # 기본 구분선
const LINE_NORMAL  := Color("#453C5E")   # 패널 테두리
const LINE_STRONG  := Color("#6B5A94")   # 강조 테두리

# ── 텍스트 (Text) ────────────────────────────────────────────
const TX_PRIMARY   := Color("#F0ECF7")   # 본문
const TX_SECONDARY := Color("#A99FC4")   # 보조 설명
const TX_MUTED     := Color("#6E6486")   # 비활성 / 미해금
const TX_GOLD      := Color("#F5C451")   # 골드 / 수치 강조
const TX_ON_DARK   := Color("#FFFFFF")   # 어두운 배경 위 흰 글자

# ── 시맨틱 (Semantic — 게임 상태) ─────────────────────────────
const HP_GOOD      := Color("#4ADE80")   # HP > 60%
const HP_WARN      := Color("#FBBF24")   # HP 30~60%
const HP_DANGER    := Color("#F87171")   # HP < 30%
const GOLD         := Color("#F5C451")
const WAVE         := Color("#7DD3FC")
const MANA_INK     := Color("#A78BFA")   # 브랜드 컬러 — 활자/자모 강조
## 적의 **방어도**(shield). 차가운 청회색이다.
##
## 한 색을 두 곳이 나눠 쓴다: 방어도가 피해를 먹었을 때 뜨는 피해 숫자(Juice)와,
## 방어도가 남아 있는 동안의 적 HP 바(EnemyUnit). 같은 값이 두 화면에 나오면
## 포맷터도 하나여야 한다 — 예전에는 바가 MANA_INK(브랜드 보라)를 썼고 숫자는
## 다른 파랑을 썼는데, 숫자 쪽 색은 아무도 안 써서 화면에 나온 적이 없었다.
##
## '중갑' 몬스터 라벨 색(MonsterRoster `armored` = 0.58,0.68,0.82)과 같은 계열이라
## 방어도는 화면 전체에서 하나의 색으로 읽힌다.
const SHIELD       := Color("#A6B8F2")   # 방어도(shield) — 피해 숫자 + HP 바

# ── 등급 (Rarity) — 색 + 문양 이중 부호화 ─────────────────────
const RARITY_COMMON      := Color("#8B93A8")
const RARITY_RARE        := Color("#7DD3FC")
const RARITY_SUPER_RARE  := Color("#F0A6FF")

const RARITY_GLYPH := {
	"common": "",
	"rare": "◆",
	"super_rare": "✦",
}

# ── 파생 헬퍼 ────────────────────────────────────────────────

## HP 비율에 따른 색. 0.0~1.0
static func hp_color(ratio: float) -> Color:
	if ratio > 0.6:
		return HP_GOOD
	elif ratio > 0.3:
		return HP_WARN
	return HP_DANGER

## 등급 id → 색
static func rarity_color(rarity: String) -> Color:
	match rarity:
		"super_rare": return RARITY_SUPER_RARE
		"rare":       return RARITY_RARE
		_:            return RARITY_COMMON

## 등급 id → 문양 (색맹 대응용 보조 지표)
static func rarity_glyph(rarity: String) -> String:
	return RARITY_GLYPH.get(rarity, "")

## 색 위에 올릴 대비 텍스트 색 (밝은 배경 → 어두운 글자)
static func contrast_text(bg: Color) -> Color:
	var lum := 0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b
	return Color("#12101A") if lum > 0.55 else TX_PRIMARY

## 알파 조정 헬퍼
static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
