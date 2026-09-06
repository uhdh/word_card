# 🤝 Project Handoff: 한글 활자술사: 타워 디펜스 (Word Alchemist TD)

본 문서는 **한글 활자술사: 타워 디펜스** 프로젝트의 진행 현황, 크롬 제미나이(Chrome Gemini) 이미지 자동화 파이프라인, 완료된 에셋 및 다음 작업자가 즉시 이어받아 수행해야 할 세부 작업 목록을 정리한 핸드오프 문서입니다.

---

## 1. 프로젝트 개요 및 핵심 요구사항

1. **게임 장르**: **한글 자모 결합 로그라이크 타워 디펜스 (Hangul Roguelike Tower Defense)**
   - 자모 벨트("ㅂ", "ㅜ", "ㄹ" 등)에서 글자를 결합하여 단어 타워("불", "물", "돌", "벽", "벌" 등)를 연성하여 S자 길을 따라 침공하는 몬스터를 막는 게임.
   - **엔진/플랫폼**: HTML5 Canvas 웹 앱 (`index.html` + `src/js/app.js`) 및 Godot 4.x (`godot/`) 듀얼 구조.
2. **범위 확정 (사용자 명시 피드백)**:
   - ⚠️ **"이거 게임이 바뀌어서, 타워디펜스야. 적들의 전투 장면은 필요 없을걸"**
   - 기존의 턴제 사이드뷰 카드 배틀 아레나 전투 배경은 **완전히 제외**.
   - 타워 디펜스 전용 에셋(필드 맵, 차원문 포탈, 현자의 핵 기지 수정, 타워 연성 제단, 단어 카드 아이콘, 몬스터 크립)에 집중.
3. **그래픽 스타일 가이드**:
   - 16비트/32px 레트로 픽셀아트, 부드러운 파스텔톤 팔레트, 굵고 선명한 짙은 픽셀 외곽선 (SNES / GBA / Golden Sun 스타일).
   - **텍스트 배제 규칙**: 생성 이미지 내 한글, 영어, UI, 버튼 등이 절대 인쇄되지 않도록 순수 환경 및 오브젝트만 생성.

---

## 2. 크롬 제미나이(Chrome Gemini) 자동화 파이프라인 (Method B)

사용자의 구글 제미나이 토큰을 활용하여 크롬 브라우저에서 고화질 이미지를 즉시 생성하고 추출하는 자동화 파이프라인이 구축되어 있습니다.

### 시스템 환경
- **OS**: Windows (PowerShell 환경)
- **제어 도구**: `orca computer` CLI
- **Chrome 창**: HWND `198360`
- **Gemini 채팅 탭**: `https://gemini.google.com/app/56fbf17453c36e93?hl=ko` (제목: `Pixel Art Sword Description - Google Gemini`)

### 이미지 생성 및 고속 추출 프로세스
1. **프롬프트 입력**:
   - `orca computer get-app-state`로 'Gemini 프롬프트 입력' element-index 동적 탐색 (대화 길이에 따라 인덱스 변경됨).
   - `set-value`로 프롬프트 주입 후 Return 또는 '단추 메시지 보내기' 클릭.
2. **이미지 추출 (클립보드 고속 파이프라인)**:
   - 브라우저 다운로드 버튼은 모달 창 지연이 발생하므로 **사용하지 않음**.
   - Gemini가 생성한 최신 `단추 이미지 복사`를 찾아 `orca computer click` 실행.
   - Python `PIL.ImageGrab.grabclipboard()`로 1024×1024 원본 즉시 추출.
3. **투명 RGBA 변환 및 규격화**:
   - 순백색 배경 제거: `(r > 240 & g > 240 & b > 240) -> alpha = 0`
   - Bounding Box 크롭 후 512×512 RGBA 캔버스 중앙에 `NEAREST` 필터로 리사이징(픽셀 선명도 유지).

### 주요 자동화 스크립트 위치
- `C:\Users\maktu\.gemini\antigravity-cli\brain\d8bb84bc-7147-4605-a092-b0fe8a2ca7e8\scratch\`:
  - `generate_td_map.py`: 와이드 필드 맵 생성 스크립트
  - `generate_td_objects.py`: 포탈, 기지 핵, 타워 제단 생성 스크립트
  - `generate_remaining_icons.py`: 단어 카드 아이콘 투명화 배치 스크립트

---

## 3. 현재까지 완료 및 저장된 에셋 (Git 커밋 완료)

모든 작업물은 `main` 브랜치에 안전하게 커밋되어 있습니다:
`commit: feat(assets): TD field map, spawn portal, sage core, tower pedestal pixel art revamp`

| 에셋 구분 | 파일 경로 | 설명 및 상태 |
| :--- | :--- | :--- |
| **제1막 TD 필드 맵** | `assets/map/map_act1_garden_td_1024x352.png`<br>`assets/map_grand_sanctuary/map_grand_sanctuary_1024x352.png` | 1024×352 와이드 파노라마 픽셀아트. S자 구불구불한 흙길, 고대 룬 석주 아치, 연금술 오두막 폐허, 석제 우물, 야생화 지형. 텍스트 완전 배제. |
| **차원문 (Spawn Portal)** | `assets/map_ui/map_spawn_portal_32px_pastel.png` | 512×512 투명 RGBA. 고대 룬 석판 림과 보라빛 차원 균열 소용돌이. |
| **현자의 핵 (Sage Core)** | `assets/map_ui/map_base_crystal_32px_pastel.png` | 512×512 투명 RGBA. 룬 제단 위에서 부유하는 청록빛/황금빛 다면체 연금술 마나 수정 핵. |
| **타워 연성 제단** | `assets/map_ui/map_tower_pedestal_32px_pastel.png` | 512×512 투명 RGBA. 4개 타워 슬롯에 놓일 고대 룬 마법진 석제 제단. |
| **맵 노드 인장 (6종)** | `assets/map_ui/map_node_*.png` | 전투(검), 정예(악령 뿔 해골), 휴식(모닥불), 상점(배낭), 이벤트(이끼 비석), 보스(왕관 해골). |
| **제1막 양피지 지도** | `assets/map/map_act1_fractured_grove_bg.png` | 고대 양피지 지도 스타일 (선택적 맵 네비게이션용). |
| **단어 카드 샘플** | `assets/01_무기_공격/sword_검/gemini_sword_sample_512.png` | 32px 레트로 기사의 검. |

---

## 4. 인계받은 Agent가 즉시 진행해야 할 다음 작업

### Task 1. 불일치 단어 카드 아이콘 리뉴얼 (우선순위 최고)
현재 `assets/words_1letter/` 및 `assets/word_assets_manifest.json`에 등록된 기초 단어들이 엉뚱한 이미지로 되어 있어 교체가 시급합니다.

1. 🔥 **'불' (화염)**:
   - 파일: `assets/words_1letter/word_1_불_fire_32px_pastel.png`, `assets/03_원소_마법/fire_불/fire_1_32px_pastel.png`
   - 현재: 보라색 알에 나뭇잎 (불과 무관)
   - 프롬프트: `A 32x32 retro pixel art game icon of a blazing mystical fireball, burning flame magic, vibrant orange red gold colors, crisp dark pixel outlines, retro pastel palette, centered, completely isolated on pure solid white background, no floor shadow, no text.`
2. 💧 **'물' (수류)**:
   - 파일: `assets/words_1letter/word_1_물_water_32px_pastel.png`, `assets/03_원소_마법/water_물/water_1_32px.png`
   - 현재: 노란색 별 2개와 달 단추 (물과 무관)
   - 프롬프트: `A 32x32 retro pixel art game icon of a swirling magical water droplet, aqua whirlpool splash, glowing cyan and deep ocean blue colors, crisp dark pixel outlines, retro pastel palette, centered, completely isolated on pure solid white background, no floor shadow, no text.`
3. 🪨 **'돌' (암석)**:
   - 파일: `assets/words_1letter/word_1_돌_stone_32px_pastel.png`, `assets/03_원소_마법/stone_돌/stone_1_32px_pastel.png`
   - 현재: 파란색 찻잔과 클로버 (돌과 무관)
   - 프롬프트: `A 32x32 retro pixel art game icon of an ancient heavy cracked rune stone boulder, solid rock, earthy gray and mossy highlights with subtle glowing cyan cracks, crisp dark pixel outlines, retro pastel palette, centered, completely isolated on pure solid white background, no floor shadow, no text.`
4. 🏰 **'벽' (성벽)**:
   - 파일: `assets/words_1letter/word_1_벽_wall_32px_pastel.png`, `assets/05_구조_필드/wall_벽/wall_1_32px_pastel.png`
   - 현재: 흐릿하고 뭉개진 회색 블록
   - 프롬프트: `A 32x32 retro pixel art game icon of a fortified ancient stone castle wall battlement with iron gate reinforcement, crisp dark pixel outlines, sturdy stone gray and glowing rune crest, retro pastel palette, centered, completely isolated on pure solid white background, no floor shadow, no text.`
5. 🐝 **'벌' (소환)**:
   - 파일: `assets/words_1letter/word_1_벌_bee_32px_pastel.png`, `assets/04_생물_소환/wasp_bee_벌/wasp_bee_1_32px_pastel.png`
   - 현재: 분홍색 펭귄 새 (벌과 무관)
   - 프롬프트: `A 32x32 retro pixel art game icon of a fierce yet cute striped bumblebee hornet with translucent wings and sharp stinger, yellow and dark black stripes, crisp dark pixel outlines, retro pastel palette, centered, completely isolated on pure solid white background, no floor shadow, no text.`
6. 기타 주요 단어: '빙'/'얼음', '북', '빛', '별', '창', '활', '도', '도끼' 등 순차 진행.

### Task 2. 타워 디펜스 인게임 캔버스 렌더링 연동 (`src/js/app.js`)
현재 `src/js/app.js`에서 타워 슬롯은 단순한 사각형(`roundRect`)으로 그려지고 있습니다:
- 신규 제작된 `map_tower_pedestal_32px_pastel.png`를 4개 슬롯 `(189, 135), (358, 135), (528, 135), (698, 135)`에 제단 스프라이트로 표시.
- `map_spawn_portal_32px_pastel.png`를 스폰 지점 `(44, 54)`에 표시.
- `map_base_crystal_32px_pastel.png`를 기지 지점 `(43, 219)`에 표시.

### Task 3. 몬스터 크립 스프라이트 (Creep Sprites)
S자 경로를 따라 이동하는 적 크립 스프라이트 제작:
- 낱자 슬라임 (보라색 / 초록색 먹물 젤리)
- 사나운 멧돼지 (돌진형 저돌 몬스터)
- 서예 먹물 골렘 (묵직한 단어 파괴자 보스)

### Task 4. 제2막 및 제3막 필드 맵 파노라마 (1024×352)
- 제2막: "버려진 바위 광산 / 고대 유적의 어둠" (어두운 암석 동굴과 룬 광석 선로)
- 제3막: "천공의 연금 성채 / 차원의 심연" (공중에 뜬 성채와 보라빛 우주 심연)

---

## 5. 중요 참고사항 및 파일 매핑 규칙

- 에셋을 저장할 때는 Web(`assets/`, `dist/`, `public/`)과 Godot(`godot/assets/`) 양쪽에 동시 복사해야 양쪽 환경에서 모두 정상 동작합니다.
- 복사본 자동 배치 경로:
  - `E:\project\word_card\assets\`
  - `E:\project\word_card\godot\assets\`
  - `E:\project\word_card\dist\assets\`
  - `E:\project\word_card\public\assets\`
- 크롬 제미나이 탭이 다른 탭으로 넘어갈 경우:
  `orca computer get-app-state --app chrome --no-screenshot --json`으로 탭 목록 확인 후 `Pixel Art Sword Description - Google Gemini` 탭을 클릭하여 포커스 복원.
