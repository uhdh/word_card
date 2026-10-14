class_name MergePalette
extends RefCounted
## 새 게임(그리드 병합 랜덤 디펜스)의 색 팔레트.
##
## 값의 출처 — 참고 영상 `KakaoTalk_20261008_153157386.mp4` 를 회전(-90) 반영해
## 884×1400 으로 뽑은 뒤(`tmp/kakao_video/tmp_full_01.png`) **픽셀을 직접 실측**했다.
## 눈으로 고른 색이 아니라 재서 뽑은 색이다.

# ── 바탕 ────────────────────────────────────────────────
const BG_DEEP := Color("111e3a")      ## 화면 바닥 (좌하단 실측 #111E3A)
const BG_MID := Color("1c2650")       ## 보드 뒤 은은한 판 (보드밖 실측 #222B61 보다 한 단계 어둡게)
const PANEL := Color("232c56")        ## 상단 pill·목표 상자 (실측 #2A355D)
const PANEL_HI := Color("2b3568")     ## 한 단계 밝은 판
const PANEL_EDGE := Color("3d4a86")   ## 판 테두리

# ── 보드 ────────────────────────────────────────────────
const PATH_TILE := Color("c9a46b")    ## 경로 타일 (실측 #B59567 — 채도를 조금 올렸다)
const PATH_EDGE := Color("a8863f")
const SLOT_EMPTY := Color("463832")   ## 빈 배치 슬롯 (실측 #423732)
const SLOT_EMPTY_EDGE := Color("5d4a41")
const RING_CYAN := Color("4fd3e0")    ## 보드 바깥 고리
const RING_GOLD := Color("f5d24a")    ## 배치 슬롯 안쪽 고리 · 합체 예고

# ── 글자 ────────────────────────────────────────────────
const TEXT := Color("ffffff")
const TEXT_DIM := Color("b9c4e8")
const TEXT_MUTE := Color("7f8bb5")
const GOLD := Color("ffd34d")
const HP_RED := Color("e2434a")
const BOSS_RED := Color("d92b3a")

# ── 하단 버튼 4종 ───────────────────────────────────────
const BTN_PULL := Color("3a63e0")     ## 뽑기 (실측 #355CD8)
const BTN_PULL_EDGE := Color("6d8dff")
const BTN_UPGRADE := Color("8b4fdb")  ## 강화 (실측 #894DDA)
const BTN_UPGRADE_EDGE := Color("b98cff")
const BTN_SLATE := Color("2a3550")    ## 조합 · 판매 (실측 #2A364E)
const BTN_SLATE_EDGE := Color("3f4c72")

## 별 등급 색 (1★ ~ 7★). 등급이 오를수록 따뜻하고 밝아진다.
const TIER_COLORS := [
	Color("8d97ad"),  # 1
	Color("57c46a"),  # 2
	Color("3f8ce8"),  # 3
	Color("9b5ce0"),  # 4
	Color("ef9f27"),  # 5
	Color("e2444a"),  # 6
	Color("f5d24a"),  # 7
]

# ── 전투 ────────────────────────────────────────────────
const ENEMY := Color("6f7ba8")
const ENEMY_EDGE := Color("aab6e0")
const ENEMY_HP := Color("57c46a")
const ENEMY_SLOW := Color("7fd8ff")
const ENEMY_BURN := Color("ff8a3d")
const TOWER_RING := Color("ffffff")
const TOWER_UNKNOWN := Color("9aa4b8")   ## 사전에 없는 "미지의 활자" 타워

## AttackStyle 의 trait id → 색. 공격 형태가 색으로 읽힌다.
const TRAIT_COLORS := {
	"damage_over_time": Color("ff6a4a"),
	"splash": Color("ff9f45"),
	"control": Color("7fd8ff"),
	"chain": Color("ffe45c"),
	"sniper": Color("c8f07a"),
	"pierce": Color("ffd9a0"),
	"rapid": Color("8ef0c0"),
	"bounce": Color("ff9ad5"),
	"orbit": Color("b9a6ff"),
	"meteor": Color("fff0a0"),
	"balanced": Color("c8d2f0"),
}


static func trait_color(trait_id: String) -> Color:
	return TRAIT_COLORS.get(trait_id, TRAIT_COLORS["balanced"])


static func tier_color(tier: int) -> Color:
	return TIER_COLORS[clampi(tier - 1, 0, TIER_COLORS.size() - 1)]


## 등급색을 타일 바탕으로 쓸 수 있게 어둡게 깐다 (유닛 그림 대신 쓰는 임시 바탕).
static func tier_bg(tier: int) -> Color:
	var c := tier_color(tier)
	return Color(c.r * 0.30 + 0.05, c.g * 0.30 + 0.05, c.b * 0.30 + 0.06, 1.0)
