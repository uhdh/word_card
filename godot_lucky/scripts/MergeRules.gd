class_name MergeRules
extends RefCounted
## 이 게임의 **설계 수치 전부**. 밸런스를 만질 때는 이 파일만 고치면 된다.
##
## ⚠️ 감독 지시 "2~4는 알아서 해줘" 로 내가 정한 값이다 — **바꿔도 되는 값**이지
##    지켜야 하는 계약이 아니다. 근거는 각 상수 옆 주석에 적었다.

# ── 보드 ────────────────────────────────────────────────
const GRID := 7          ## 보드 한 변
const INNER := 5         ## 안쪽 배치 슬롯 한 변 (1..5 좌표)
const RING := 1          ## 바깥 경로 두께

# ── 시작 자원 ────────────────────────────────────────────
const START_GOLD := 120
const START_HP := 50

# ── 뽑기 ────────────────────────────────────────────────
## 값이 오르는 이유: 무한히 뽑아 보드를 채우는 것이 항상 최선이면 선택이 사라진다.
const PULL_COST_BASE := 20
const PULL_COST_STEP := 5
## 3번째 뽑기마다 모음 확정 — 기존 게임 `generate_reward_choices` 와 같은 이유
## (모음이 안 나오면 자음만 쌓여 **단어가 영영 안 서고** 보드가 죽는다).
const PULL_VOWEL_EVERY := 3

# ── 강화 / 조합 / 판매 ───────────────────────────────────
const UPGRADE_COST_PER_TIER := 40   ## 등급 × 40 G
const COMBINE_COST := 30            ## 같은 자모·같은 등급 2장을 골드로 합친다
const SELL_GOLD_PER_TIER := 15      ## 등급 × 15 G 환급
const MAX_TIER := 7

# ── 병합 ────────────────────────────────────────────────
const MERGE_COUNT := 3       ## 같은 자모·같은 등급 3장 → 1장, 등급 +1
## ⚠️ 참고 영상은 **자동** 병합이다. 그래서 켜 두었다.
##    끄면 "조합" 버튼이 유일한 병합 수단이 된다(그쪽이 더 퍼즐에 가깝다).
const AUTO_MERGE := true

# ── 단어 타워 ────────────────────────────────────────────
const TOWER_RANGE_CELLS := 3.4    ## 칸 단위 사거리
const TOWER_INTERVAL := 0.75      ## 발사 간격(초)
## 평균 등급 1 초과분 1당 피해 배수. 3장 병합으로 등급이 오르면 그 줄이 세진다.
const DAMAGE_PER_TIER := 0.45
## 사전에 없는 조합("미지의 활자")도 타워가 된다 — 안 그러면 운 나쁜 판이 아무것도 못 한다.
## (그 값은 HangulStreamParser.make_unknown_word_data 가 정한다)

# ── 특성별 부가 효과 (AttackStyle 의 trait id 를 그대로 쓴다) ──
const SPLASH_RADIUS := 1.35       ## splash: 목표 주변까지
const CHAIN_RADIUS := 1.8         ## chain: 두 번째 대상 탐색 반경
const CHAIN_RATIO := 0.6
const SLOW_TIME := 1.6            ## control: 이동 감속 지속
const SLOW_MULT := 0.45
const BURN_TIME := 3.0            ## damage_over_time: 화상 지속
const BURN_DPS_RATIO := 0.35      ## 발당 피해의 35% 를 초당 화상으로

# ── 웨이브 ──────────────────────────────────────────────
const WAVE_ENEMY_BASE := 4
const WAVE_HP_BASE := 24.0
const WAVE_HP_GROWTH := 1.19
const BOSS_EVERY := 5
const BOSS_HP_MULT := 7.0
const BOSS_SPEED_MULT := 0.72
const BOSS_DAMAGE := 3            ## 기지에 줄 때
const ENEMY_DAMAGE := 1
const SPAWN_INTERVAL := 0.85      ## 초
const ENEMY_SPEED_CELLS := 1.05   ## 초당 칸
const GOLD_PER_KILL := 3
const GOLD_PER_WAVE_BASE := 25
const GOLD_PER_WAVE_STEP := 6

# ── 연출 ────────────────────────────────────────────────
const SHOT_LIFE := 0.13           ## 투사체 궤적 표시 시간(초)


## N 라운드의 적 HP.
static func enemy_hp(wave: int) -> float:
	return WAVE_HP_BASE * pow(WAVE_HP_GROWTH, float(maxi(wave, 1) - 1))


## N 라운드의 적 수.
static func enemy_count(wave: int) -> int:
	if wave % BOSS_EVERY == 0:
		return 1 + int(wave / 2)      ## 보스 라운드는 잡몹이 줄고 보스가 선다
	return WAVE_ENEMY_BASE + wave


static func is_boss_wave(wave: int) -> bool:
	return wave > 0 and wave % BOSS_EVERY == 0


static func pull_cost(pull_count: int) -> int:
	return PULL_COST_BASE + pull_count * PULL_COST_STEP


static func wave_gold(wave: int) -> int:
	return GOLD_PER_WAVE_BASE + wave * GOLD_PER_WAVE_STEP
