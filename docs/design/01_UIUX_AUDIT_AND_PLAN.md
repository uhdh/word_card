# UI/UX 감사 & 현대화 계획 (Director's Directive)
### 대상: 《언어의 조각 : 말의 심연》 (Fragments of Language: Word Card)
### 본편: Godot 4.7 / `godot/scenes/TowerDefenseMain.tscn`
### 작성: 게임 디렉터 (AI) · 2026-09-13 · **배포 전 폴리시 패스**

---

## 0. 요약 (Executive Summary)

현재 게임의 **코어 루프는 완성도가 높다** — 자모 타일을 트레이에 놓으면 단어가 되고,
단어가 타워가 되고, 타워가 길을 막는 S자 경로 위의 적을 막는다. 시스템은 이미
365개 단어 · 25종 유물 · 3막 × 20웨이브 · 마스터리 · 시너지까지 갖췄다.

문제는 **그 시스템을 플레이어에게 전달하는 껍데기(UI/UX)가 심각하게 낡았다**는 것.
가장 큰 3가지 근본 원인:

| # | 근본 원인 | 증상 |
|---|---|---|
| 1 | **디자인 시스템(Theme) 부재** | 8개 이상 스크립트가 각자 `StyleBoxFlat`을 인라인 생성. 팔레트가 보라/금, 슬레이트/시안, 기본 회색으로 **서로 충돌** |
| 2 | **세로 공간 파산** | 720p에서 상단바 78px + 벨트 300px + 모달이 필드를 짓눌러 **전장이 420px도 안 됨** |
| 3 | **보이지 않는 어포던스** | 최상단 버튼 7개 `visible=false`, 슬롯 라벨 공백, 스폰/베이스/도로 전부 숨김, `????` 깨진 문자열 |

이 문서는 위 3가지를 **게임 필러(Jerry/Balatro/StS)와 실경쟁작(Rogue Tower /
Dungeon Warfare 2 / Brotato)을 벤치마크**하여 해결하는 실행 계획이다.

---

## 1. 벤치마크: 장르 트렌드 (2026)

### 1.1 리서치로 확인된 로그라이크 TD의 현재 문법

조사 출처: Switchblade Gaming "Best Tower Defense 2026", towersdefense.org
"Tower Defense in 2026", GDKeys "Card Games UI Design" 분석,
Balatro/Slay the Spire UX 분석, Steam 로그라이크 TD 카테고리.

**A. 짧고 반복 가능한 런 (20~40분)**
Rogue Tower 20–30분, Brotato 30분 이하, Dungeon Defenders: Going Rogue 30–40분.
장르 전체가 "한 판만 더" 사이클로 수렴 중. → 우리 게임의 3막 × 20웨이브도
**런 요약(Run Summary) 화면**이 있어야 "한 판이 끝났다"는 감각이 생긴다.

**B. 랜덤 드래프트로 선택지를 제시 (고정 트리가 아님)**
Rogue Tower는 카드 드로우, Brotato는 라운드 사이 랜덤 업그레이드,
Going Rogue는 200+ 룬. → 우리의 **자모 보상 3택**은 이미 이 문법과 일치한다.
문제는 `WaveRewardModal`이 **구현됐는데 연결이 안 돼 있다**는 것 (Dead UI).

**C. 빌드 적응 > 맵 암기**
Rogue Tower의 길이 매 웨이브 확장되고, Dungeon Warfare 2는 물리 지형이 핵심.
→ 우리 게임은 S자 고정 경로라 맵 암기 게임이 될 위험이 있다.
**타워 배치 슬롯(11개)의 시각적 유도**와 **경로 위협 예고**로 적응형 사고를 유도해야 한다.

**D. 액션 지향 / 관전 탈피**
장르는 "수동적 관전"에서 벗어나는 중 (Brotato의 액션, DW2의 물리).
→ 우리는 **타일 조작 + 실시간 배치**가 이미 능동적이다. 다만 **피드백(juice)이 빈약**해
관전처럼 느껴질 수 있다.

**E. 메타 = 다양성, 파워 아님 (Slay the Spire 원칙)**
StS의 업적 해금은 "공간을 넓히되 기본 스탯은 안 올림".
→ 우리의 **도감 해금(Lexicon Discovery)** 은 정확히 이 원칙을 이미 따른다. 강점.

**F. 의도(Intent) 텔레그래프**
StS의 적 의도 아이콘은 장르 표준이 됐다.
→ 우리는 `next_round_preview()`가 문자열로 존재하지만 **`visible=false`인 라벨**에
묻혀 있다. **적 의도를 시각화하는 것**이 최우선 UX 개선 항목.

### 1.2 UI/UX 디자인 패턴 (3대 카드게임 → 우리에게 주는 규칙)

GDKeys 분석에서 추출한 재사용 가능 규칙:

| 규칙 | 출처 | 우리 게임 적용 |
|---|---|---|
| **Progressive Disclosure** (핵심 정보는 항상, 상세는 호버) | 3사 공통 | 타워/타일 상세를 툴팁으로. 기본은 요약만 |
| **색상 코드 + 보조 지표(아이콘/모양)** | 3사 공통 | 등급을 색+문양 이중 부호화 (색맹 대응) |
| **공간 일관성** (핵심 요소는 화면상 고정 위치) | 3사 공통 | HP/골드는 좌상단 고정, 벨트는 항상 하단 |
| **모든 행동에 즉각 시청각 반응 (juice)** | Balatro | 타일 결합·타워 공격·피격에 스쿼시/셰이크/사운드 |
| **상점: 아이템 크기 확대 + 배경 단순화 + 카테고리화** | StS 개선案 | ShopModal 카드 확대, 배경 정리 |
| **버프/디버프 세로 정렬, 진영 구분** | StS 개선案 | 타워 상태이상 아이콘 세로 정렬 |
| **스탯(비용/공격/HP)은 어떤 배율에서도 보여야** | Hearthstone | 타일 카드가 벨트/대기/픽 셋 다에서 읽혀야 |
| **글로벌 배속 조절** | Balatro | 이미 있음 (`set_speed_scale`) ✓ |

### 1.3 Godot 테마 시스템 (기술 근거)

출처: UhiyamaLab "Building Consistent UI with the Theme System" + Godot 4.x 공식 문서.

- Theme은 **Color / Constant / Font / Icon / StyleBox** 5요소로 구성
- 적용 우선순위: `노드 override` > `노드 자체 theme` > `부모로부터 상속` >
  `프로젝트 기본 theme` > `에디터 기본`
- **원칙: 90%를 전역 Theme에, 10%만 예외로 override**
- **금지: `get_theme_stylebox()` 반환값을 그대로 수정** → 반드시 `.duplicate()`
- Theme Type Variation (`theme_type_variation`) 으로 `PanelCard`, `ButtonPrimary`
  같은 **의미론적 변형**을 만들 수 있음 → 우리 디자인 시스템의 핵심 도구

---

## 2. 현재 상태 진단 (코드 근거)

### 2.1 🔴 P0 — 즉시 고쳐야 배포 가능

| ID | 문제 | 위치 | 영향 |
|---|---|---|---|
| P0-1 | **깨진 한글 `????` 노출** | `TowerDefenseMain.gd` L106–110, L164, L314 | 플레이어가 모달/툴팁에서 `????`를 봄. 치명적 |
| P0-2 | **`spawn_timer_label` null 크래시** | `TowerDefenseMain.gd` L289 `_process` | 매 프레임 스크립트 에러 스팸 |
| P0-3 | **`WaveRewardModal` 미연결 (Dead UI)** | `_grant_round_reward` / `_on_wave_cleared` | 로그라이크 보상 루프가 게임에 없음 |
| P0-4 | **테마가 사실상 비어 있음** | `default_theme.tres` (8줄) | 모든 UI가 ad-hoc. 시각적 통일성 0 |
| P0-5 | **에셋 UID 무효 경고** | `default_theme.tres`, `DefenseField.tscn`, `TowerDefenseMain.tscn` | 매 실행 콘솔 경고 (uid://font_neodgm_001 등) |

### 2.2 🟠 P1 — 배포 품질에 직접 영향

| ID | 문제 | 근거 |
|---|---|---|
| P1-1 | **세로 공간 파산** | TopBar 78 + VBox top 84 + Belt 300 (`custom_minimum_size`) = 720p에서 필드 여유 336px. `DefenseField.custom_minimum_size = (1000, 420)`는 **오버플로** |
| P1-2 | **팔레트 3중 충돌** | Main/Shop=보라+금 `(0.68,0.45,0.98)`, JamoBelt=슬레이트+시안 `Color("182238")`/`Color("7dd3fc")`, TowerInfoModal=**Godot 기본 회색** |
| P1-3 | **어포던스 은닉** | `BtnStartWave/Reset/Save/Load/Lexicon/Lore/Mute` 전부 `visible=false`; `SlotLabel.text=""`; `SpawnSpot/BaseSpot/RoadLine` 전부 `visible=false` |
| P1-4 | **적 의도 미표시** | `next_round_preview()`는 존재하나 `NextRoundLabel.visible=false` |
| P1-5 | **스토리 텍스트 불일치** | `_on_lore_pressed`가 "현자의 핵 / 혼돈의 도가니 / 누더기 괴물", "1장 연구소 앞뜰…" 언급. 실제 `ACT_NAMES`는 "초원의 문자 / 고대 유적의 어둠 / 차원의 심연" |
| P1-6 | **몬스터 애니메이션 없음** | `EnemyUnit.gd`는 `sin()` 보빙만. 프레임 애니 0 |
| P1-7 | **인트로 미연결** | `assets/intro/`에 `ref_tower_bul_start/end`, `ref_brush_*`, `make_*_frames.py` 존재. 게임은 이를 로드하지 않음 |

### 2.3 🟡 P2 — 있으면 좋은 것

| ID | 문제 |
|---|---|
| P2-1 | 문서 vs 코드 불일치 (HANDOFF: 6웨이브/0.65s/HP20 ↔ 코드: 20웨이브/0.8s/gold30·40) |
| P2-2 | 레거시 씬 잔존 (`BattleView`, `Main`, `MapView`, `DeckModal`, `RewardModal`) |
| P2-3 | `assets/ui/` 폴더가 **완전히 비어 있음** (UI 전용 에셋 없음) |
| P2-4 | 사운드가 전부 8비트 절차 합성 (chiptune) — HANDOFF가 "비치프튠 BGM"을 미완으로 명시 |
| P2-5 | `HangulEngine.get_rarity_bg_color()`가 모든 등급에 동일 배경 반환 → 등급 차이가 테두리뿐 |

---

## 3. 디자인 시스템 정의 (Art Bible)

> **이 섹션이 이후 모든 UI 작업의 단일 진실 공급원(Single Source of Truth)이다.**
> 픽셀 폰트(neodgm) 기반 32px 픽셀아트 · 파스텔 팔레트가 이미 에셋에 깔려 있으므로,
> **"먹과 먹지(ink & paper) + 심연의 보라"** 를 축으로 통일한다.

### 3.1 팔레트 (확정)

게임 서사("활자술사가 말의 심연을 봉인한다")에 맞춰 **먹빛 어둠 위에 발광하는 활자**를
핵심 은유로 삼는다. Balatro가 "어두운 카지노 테이블 위 형광 조커"로 대비를 만들었듯,
우리는 **어두운 먹지 위 형광 활자**로 대비를 만든다.

```
■ 배경 계층 (Background Layers)
  bg_void      #0B0A10   최하단 (거의 검정, 보랏빛 tint)
  bg_deep      #12101A   필드 배경
  bg_panel     #1A1726   일반 패널
  bg_panel_hi  #241F33   강조 패널 / 호버
  bg_inset     #0E0C15   입력창 / 함몰 영역

■ 테두리 (Borders)
  line_subtle  #2E2840   기본 구분선
  line_normal  #453C5E   패널 테두리
  line_strong  #6B5A94   강조 테두리

■ 텍스트 (Text)
  tx_primary   #F0ECF7   본문
  tx_secondary #A99FC4   보조 설명
  tx_muted     #6E6486   비활성 / 미해금
  tx_gold      #F5C451   골드/수치 강조

■ 시맨틱 (Semantic — 게임 상태)
  hp_good      #4ADE80   HP 정상 (>60%)
  hp_warn      #FBBF24   HP 경고 (30~60%)
  hp_danger    #F87171   HP 위험 (<30%)
  gold         #F5C451   골드
  wave         #7DD3FC   웨이브/진행
  mana_ink     #A78BFA   활자/자모 강조 (브랜드 컬러)

■ 등급 (Rarity — 색 + 문양 이중 부호화)
  common       #8B93A8   (문양: 없음)
  rare         #7DD3FC   (문양: ◆)
  super_rare   #F0A6FF   (문양: ✦)
```

### 3.2 타이포그래피

기존 `neodgm.ttf`(네오둥근모) 유지 — 한글 픽셀 폰트로 세계관에 완벽히 맞음.
`neodgm_code.ttf`는 **숫자/수치 전용**으로 분리 (골드·데미지 정렬이 예뻐짐).

| 역할 | 크기 | 폰트 | 용도 |
|---|---|---|---|
| Display | 34 | neodgm | 3글자 타워 대형 글자 |
| Title | 22 | neodgm | 모달 제목 |
| Heading | 18 | neodgm | 섹션 헤더 |
| Body | 14 | neodgm | 본문 (기본값) |
| Caption | 12 | neodgm | 설명 |
| Micro | 10 | neodgm | 각주 / 조합식 |
| Numeric | 16/20/28 | **neodgm_code** | 골드·HP·데미지 숫자 |

### 3.3 간격 · 형태 (Spacing & Shape)

```
간격 스케일:  4 / 8 / 12 / 16 / 24 / 32
모서리 반경:  card 8 · panel 10 · modal 12 · pill 999
패널 패딩:    16 (기본) / 12 (컴팩트) / 24 (모달)
그림자:       y+3, blur 6, alpha 0.35 (일관)
테두리 폭:    1 (기본) / 2 (강조) / 3 (등급)
```

### 3.4 모션 (Motion)

기존 코드의 tween을 표준화한다.

| 동작 | 시간 | 이징 | 비고 |
|---|---|---|---|
| 버튼 호버 | 0.10s | OUT | scale 1.0→1.04 |
| 패널 등장 | 0.18s | BACK_OUT | scale 0.92→1.0 + fade |
| 타일 결합 | 0.25s | BACK_OUT | 스쿼시 1.0→1.15→1.0 |
| 피해 숫자 | 0.65s | OUT | 현재값 유지 ✓ |
| 화면 흔들림 | 0.15s | 선형 감쇠 | magnitude에 비례 |
| 타워 건설 | 0.30s | ELASTIC_OUT | 아래에서 솟아오름 |

**원칙: 모든 플레이어 행동에는 즉각적 시각+청각 반응이 따라야 한다 (Balatro 원칙).**

### 3.5 레이아웃 (720p 기준 재설계)

```
┌───────────────────────────────────────────────────────────┐
│ TOP BAR  56px  : ❤HP ████ 20/20 │💰40│ 🌊 3/20 │ ⚡2x │⚙│  │
├───────────────────────────────────────────────────────────┤
│                                                           │
│                    전장 (DefenseField)                    │
│                   ≈ 480px  (기존 336 → +43%)              │
│         [경로 / 스폰 / 베이스 / 슬롯 11개 전부 가시]        │
│                                                           │
├───────────────────────────────────────────────────────────┤
│ 예고 바 32px : 다음 웨이브: 군집·중갑 12체  [🔮의도 아이콘] │
├───────────────────────────────────────────────────────────┤
│ JAMO BELT 200px : [트레이1][트레이2][트레이3] │ 대기타일   │
│                   🧩자음 🧩모음 ✂️제거 💡추천 📖도감      │
└───────────────────────────────────────────────────────────┘
```

**핵심 변경**: TopBar 78→56 (+22px), Belt 300→200 (+100px) → 전장 +122px 확보.
접기 토글(Collapse)로 벨트를 44px까지 숨겨 필요시 전장을 580px까지 확보.

---

## 4. 실행 계획 (Phased Roadmap)

> ⚠️ **2026-10-04 점검 — 아래 체크박스는 *작성 시점(2026-09-13) 그대로* 이고 40개 전부 미체크다.**
> **미체크를 "안 했다" 로 읽지 마라.** 실제로는 Phase 0~6 이 집행됐고, 완료 보고는 같은 폴더의
> `02_UIUX_CHANGELOG.md` 다(디자인 시스템 · 레이아웃 · 보상 루프 · 주스 · 타이틀 화면 · 3단계
> 코치마크 · 레거시 이동까지). **코드로 확인한 것만** 갈라 적는다.
>
> **✅ 확인됨 — 미체크지만 완료** — 0-1(`????` 0건) · 0-2(`spawn_timer_label` 자체가 사라졌다) ·
> 0-4(`assets/ui/` 없음) · 1-1~1-4(`game_theme.tres` 변형 등록 · `scripts/ui/Palette.gd` ·
> `project.godot` 의 `theme/custom`) · 2-1 · 2-3 · 2-4 · 2-5(예고 바) ·
> 2-6(HP바가 `add_theme_stylebox_override`) · 3-1~3-4 · 4-1~4-5 · 5-1 ·
> 5-3(**3단계 코치마크** — `TowerDefenseMain._show_first_run_coachmark()`) · 5-4 · 6-2(`legacy/scenes/`)
>
> **❌ 아직 미완 (실측)** —
> **0-3** 무효 UID — **미완.** `default_theme.tres` 가 **고아 파일로 남아 있고**(참조 0건) 손으로
> 쓴 `uid="uid://default_theme_001"` 을 그대로 갖는다. 실측 **자리표시자 UID 21개 / 19개 파일**
> (`default_theme.tres` · `scenes/` 3 · `scenes/tower/` 8 · `tools/SyncTestScene.tscn` ·
> `legacy/scenes/` 6).
> ⚠️ **동작에는 지장이 없다** — `ext_resource` 에 `path=` 가 함께 적혀 있어 그쪽으로 풀리고,
> **헤드리스 로드에서 UID 경고가 한 줄도 안 났다**(2026-10-04 실측). ⚠️ 고칠 때는 **정의와
> 참조가 쌍**이라(`DefenseField.tscn` ↔ `TowerDefenseMain.tscn`) 한쪽만 바꾸면 갈라진다.
> **1-5** 인라인 `StyleBoxFlat` 이 8개 스크립트에 33회 남아 있다(동적 색 HP바 등 정당한 용례 포함 —
> **전수 제거는 안 했다**). **2-2** JamoBelt 는 슬림화됐지만 **접기 토글이 없다**.
> **6-3** 몬스터 프레임 애니메이션 없음. **6-4** BGM 없음(감사 §2.12 (d) 와 일치).
> **5-2** 는 "전면 재작성" 여부를 판정하지 않았다(`ACT_NAMES` 는 존재·사용 중).
>
> ⚠️ `02_UIUX_CHANGELOG.md` 의 *"범위: Phase 0~6 전체"* 도 **약간 과대**하다 — 위 ❌ 다섯은
> 그 보고서에 없다.

### Phase 0 — 응급 처치 (P0) · 선행 필수
> 배포 불가 상태를 배포 가능 상태로 만든다. 다른 어떤 작업보다 먼저.

- [ ] **0-1** `TowerDefenseMain.gd`의 `????` 전부 복원 (L106–110, L164, L314)
- [ ] **0-2** `spawn_timer_label` null 가드 추가 (L289)
- [ ] **0-3** 무효 UID 제거 (`default_theme.tres`, `DefenseField.tscn`, `TowerDefenseMain.tscn`)
- [ ] **0-4** `assets/ui/` 에 UI 스프라이트가 정말 없는지 확정 → 필요시 생성 계획

### Phase 1 — 디자인 시스템 (P0) · 모든 UI의 토대
- [ ] **1-1** `ui/theme/game_theme.tres` 신규 작성: 5요소 전부 정의
      (Button 3상태 + Panel + PanelContainer + Label + ProgressBar + LineEdit + ScrollBar + Tooltip)
- [ ] **1-2** `ui/theme/palette.gd` — 팔레트 상수 싱글턴 (스크립트에서 색 참조용)
- [ ] **1-3** Theme Type Variation 등록: `TitleCard`, `StatChip`, `RarityCommon/Rare/SuperRare`,
      `ButtonPrimary/Ghost/Danger`, `PanelInset`
- [ ] **1-4** `default_theme.tres` → `game_theme.tres` 로 교체, project.godot 갱신
- [ ] **1-5** 전 스크립트의 인라인 `StyleBoxFlat` 제거 → 테마 참조로 교체
      (대상: TowerDefenseMain, JamoBelt, ShopModal, WordTower, LexiconModal, WaveRewardModal, TowerInfoModal)

### Phase 2 — 레이아웃 & 가시성 (P1)
- [ ] **2-1** TopBar 78→56px 재설계, 액션 버튼 전부 표시 (아이콘+툴팁)
- [ ] **2-2** JamoBelt 300→200px + 접기 토글
- [ ] **2-3** `DefenseField` 오버플로 해소 (min_size 420 → 유동)
- [ ] **2-4** 스폰 포탈 / 베이스 크리스탈 / 도로 / 슬롯 라벨 전부 가시화
- [ ] **2-5** 예고 바(Telegraph Bar) 신설 — `next_round_preview` 시각화, 의도 아이콘
- [ ] **2-6** 적 HP바 커스텀 스타일 (기본 Godot 회색 탈피)

### Phase 3 — 보상 루프 활성화 (P1) ★ 게임필러 개선
- [ ] **3-1** `WaveRewardModal` 을 `_grant_round_reward` 에 실제 연결
- [ ] **3-2** 보상 화면을 "3택 드래프트" 문법으로 재설계 (StS/Rogue Tower 문법)
- [ ] **3-3** 런 요약(Run Summary) 화면 신설 — 골드/도감/마스터리/시너지 통계
- [ ] **3-4** 도감 해금 순간의 연출 (새 단어 발견 시 토스트)

### Phase 4 — 피드백 & 주스 (P1)
- [ ] **4-1** 타워 건설/공격/피격에 스쿼시 + 사운드 동기화
- [ ] **4-2** 화면 흔들림 (피해량 비례)
- [ ] **4-3** 데미지 숫자 스타일 통일 (치명타/속성별 색)
- [ ] **4-4** 픽셀 파티클 (타격/소환/파괴)
- [ ] **4-5** 툴팁 시스템 통일 (`Progressive Disclosure`)

### Phase 5 — 온보딩 & 서사 (P1/P2)
- [ ] **5-1** `assets/intro/` 활용한 인트로 연출 (`ref_tower_bul_start → end` 모프)
- [ ] **5-2** 스토리 텍스트를 실제 `ACT_NAMES`에 맞춰 전면 재작성
- [ ] **5-3** 첫 3웨이브 튜토리얼 코치마크 (자모 결합 → 타워 배치 → 웨이브)
- [ ] **5-4** 시작 시 강제 로어 팝업 제거 → 타이틀 화면으로 대체

### Phase 6 — 정리 (P2)
- [ ] **6-1** 문서 ↔ 코드 수치 일치화 (HANDOFF/GAME_DESIGN 갱신)
- [ ] **6-2** 레거시 씬 `legacy/` 로 이동 (삭제 아님 — HANDOFF 금지사항 준수)
- [ ] **6-3** 몬스터 프레임 애니메이션
- [ ] **6-4** BGM (비치프튠)

---

## 5. 성공 지표 (측정 가능)

| 지표 | 현재 | 목표 |
|---|---|---|
| 인라인 `StyleBoxFlat` 생성 지점 수 | ≥ 25곳 | **≤ 3곳** (테마 예외만) |
| 전장(DefenseField) 세로 픽셀 | ~336px | **≥ 460px** |
| 게임 시작 후 60초 내 화면에 보이는 어포던스 버튼 | 3개 | **≥ 9개** |
| 게임 시작 후 60초 내 플레이어 행동 수 | ~2 | **≥ 5** |
| UI에서 `????` 노출 | 다수 | **0** |
| 실행 시 콘솔 에러/경고 | 다수 | **0** |
| 로그라이크 보상 루프 | **없음** | 웨이브마다 3택 |

---

## 6. 리스크 & 가드레일

**반드시 지킬 것 (HANDOFF.md 준수)**
- ❌ 웹 동기화 금지 (`src/`, `index.html`, `main/` 는 본편 아님)
- ❌ 턴제 `BattleView`/`CardSystem` 부활 금지
- ❌ `main/` 정리 금지
- ❌ 레거시 씬 **삭제** 금지 → `legacy/` 이동만
- ❌ 게임 로직(수치 밸런스) 변경 금지 — 이번 패스는 **프레젠테이션 계층**만

**리스크**
| 리스크 | 대응 |
|---|---|
| 테마 교체가 기존 레이아웃을 깨뜨림 | Phase별로 헤드리스 테스트 3종 실행 후 진행 |
| `StyleBoxFlat` 일괄 제거 중 회귀 | 파일 단위로 커밋, 매 단계 테스트 |
| 팔레트 변경이 기존 픽셀아트와 충돌 | 파스텔 에셋 유지, 배경만 어둡게 (대비 ↑) |
| 세로 공간 확보가 필드를 왜곡 | `_layout_sanctuary()` 스케일 로직 검증 |

**검증 명령 (매 Phase 종료 시)**
```bash
GODOT="/c/Users/maktu/AppData/Local/Microsoft/WinGet/Links/godot"
$GODOT --headless --path godot res://tests/test_tower_traits.tscn
$GODOT --headless --path godot res://tests/test_wave_balance.tscn
$GODOT --headless --path godot res://tests/early_wave_playtest.tscn
# 기대: exit 0, "tower trait tests passed" / "base HP 20/20"
```

---

## 7. 다음 액션

**즉시 착수 권장: Phase 0 + Phase 1**
Phase 0은 배포 차단 요소라 논의 없이 진행 가능.
Phase 1(테마)은 이후 모든 작업의 토대이므로 **가장 먼저** 확정해야 함.

Phase 1-1(테마 리소스 작성)과 Phase 1-2(팔레트 싱글턴)를 함께 진행하면
Phase 2~5가 전부 "테마 참조"로 단순화된다.

---

*이 문서는 리빙 도큐먼트다. 각 Phase 완료 시 체크박스를 갱신하고,
발견된 새 이슈는 해당 Phase에 추가한다.*
