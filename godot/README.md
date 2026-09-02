# 언어의 조각 : 말의 심연 (Godot 4 버전)
**Fragments of Language: Word Card (Godot Engine Port)**

한글 자모 결합 로그라이크 덱빌더 『언어의 조각 : 말의 심연』의 Godot 4.x 포팅 프로젝트입니다.

---

## 🎮 주요 기능 구현 목록
1. **한글 자모 조합 엔진 (`HangulEngine.gd`)**:
   - 초성 19자, 중성 21자, 종성 28자 Unicode 조합 및 분해
   - 타일 90도 회전 (`ㄱ↔ㄴ`, `ㅏ↔ㅜ↔ㅓ↔ㅗ`, `ㅣ↔ㅡ`)
   - 자모 합성 (된소리, 겹받침, 이중모음 합성)
2. **100개 단어 데이터베이스 (`WordDatabase.gd`)**:
   - 시작 덱으로 조합 가능한 100개 단어 및 고유 특수 능력
   - 에테르AI 32px 파스텔 에셋 아이콘 매핑 (`res://assets/...`)
3. **전투 시스템 (`BattleManager.gd`, `CardSystem.gd`, `EnemyAI.gd`)**:
   - 턴제 전투, 슬롯 장착, AP 관리, 적 의도(Intent) 시스템
   - 흡혈(Vamp), 가시/반격(Thorns), 지속재생(Regen), 빙결/기절(Freeze/Stun), 방패파괴(Shield Break), 정화(Cleanse), 처형(Execute) 등 100개 단어 특수 메커니즘 지원
4. **절차적 오디오 엔진 (`SoundEngine.gd`)**:
   - 외부 사운드 파일 없이도 실시간 절차적 칩튠 효과음(타격, 방어, 회복, 마법, 팡파레 등 14종) 합성 재생
5. **15층 분기 맵 시스템 (`MapManager.gd`, `MapView.tscn`)**:
   - 일반 전투, 엘리트, 모닥불 휴식, 상점, 고대 비석 이벤트, 1막 보스 서예 골렘
6. **단어 도감 100종 모달 (`LexiconModal.tscn`)**:
   - 6개 카테고리 탭 필터링 및 실시간 검색 기능

---

## 🚀 실행 방법
- **Godot 4.x (4.2+)** 에디터 실행 후 `E:\project\word_card\godot\project.godot` 열기
- 또는 터미널에서 실행:
  ```powershell
  godot --path "E:\project\word_card\godot"
  ```
