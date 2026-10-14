# 언어의 조각 : 말의 심연 (Godot 4.7)

한글 자모 결합 로그라이크 타워 디펜스. 이 폴더가 본편이다. 웹 클라이언트는 동결되어 있다.

엔트리: `scenes/TowerDefenseMain.tscn`

## 구현된 기능

1. **한글 자모 엔진** (`HangulEngine.gd`, `HangulStreamParser.gd`)
   - 15종 코어 자모, 회전, 된소리/겹모음, 최장 단어 파싱
2. **슬롯별 자모 트레이** (`JamoBelt.gd`)
   - 슬롯 3개 고정 + 대기 트레이. 새 자모는 대기. 세이브에 `slot_assignments` 포함
   - 자모 값은 구매할 때마다 오른다 — 유물 구매와 같은 지갑을 두고 경쟁한다
3. **단어 타워 DB** (`WordDatabase.gd`)
   - `word_database_265.json` (265종) + `word_database_expansion_100.json` (100종)
     + 코드에서 추가하는 1종 = **366종**
4. **음절 길이 = 화력** (`WordTower.gd`)
   - 1/2/3글자 → 투사체 1/2/3개, 공격 간격 ×1.00/0.85/0.70, 투사체 크기 ×1.00/1.18/1.38
   - 실측 DPS 12.5 / 34.9 / 73.7 — 강함이 숫자가 아니라 화면에 보인다
5. **단어 뜻 → 공격 형태** (`AttackStyle.gd`)
   - exact → rule → category 3단계. 폴백이면 툴팁에 `형태: 무기 분류` 로 밝힌다
6. **캠페인** (`DefenseField.gd`)
   - 3막 × 20라운드 (총 60), 기지 HP 50, 5라운드마다 보스
   - 3막 경로가 맵 폭의 79% 를 쓴다
7. **몬스터 명단** (`MonsterRoster.gd`)
   - 막별 5/5/4종 + 보스 3종, 이름·아트 중복 없음
   - 속성 4종: 재생 / 분열 / 결계 / 질주. 적 머리 위 색 배지로 표시
   - 보스는 1.9배 실루엣 + 배너 + HP 바 + 약점 순환 (관통→폭발→제어→지속 피해)
8. **타워↔유물 시너지**
   - 유물 28종 (그중 특성 유물 5종은 그 특성 타워만 강화)
   - 짝 특성 보너스 + 같은 특성 밀집 +12% + 음절 사다리 +15%, 전부 툴팁에 표시
9. **상점·유물·보상·도감·세이브**
10. **절차적 칩튠** (`SoundEngine.gd`)

레거시 턴제 장면(`BattleView`, `MapView`)은 본편이 아니다.

## 실행

Godot 4.7 에디터에서 `E:\project\word_card\godot\project.godot` 를 연다.

```powershell
godot --path "E:\project\word_card\godot"
```

## 테스트

```bash
cd /e/project/word_card/godot && bash tests/run_all.sh
```

헤드리스 스위트 4개 + GUI 드래그 + 자동 플레이. 실패하면 종료 코드 1.

난이도 게이트까지 돌리려면 (약 2분 추가):

```bash
TEST_SLOW=1 bash tests/run_all.sh
```

`tools/` 의 검증 도구:

| 도구 | 용도 |
| :--- | :--- |
| `check_gpu.sh` | **창이 안 뜰 때 먼저 이것.** 프로젝트 문제인지 GPU 드라이버 문제인지 가른다 |
| `DifficultyPlaytest.tscn` | 60라운드 완주 난이도 측정. `gate=1` 이면 밴드 이탈 시 종료 코드 1 |
| `MeaningAudit.tscn` | 366종의 뜻→형태 판정을 분류하고 폴백 비율 감시 |
| `Shot.tscn` | 스크린샷 (`act=`, `boss=1`, `monsters=`, `out=`, `fresh=1`) |
| `mapgen/check_sync.py` | 지도 생성 결과와 `DefenseField.gd` 경로·발판 동기 확인 |

인자는 `이름=값` 형태다 (`--` 뒤에 그대로). 예:

```bash
godot --headless --path . res://tools/DifficultyPlaytest.tscn -- slots=1 gate=1
```

## 창이 안 뜰 때 (2026-09-18 실제 사례)

```bash
bash tools/check_gpu.sh
```

이 스크립트는 **프로젝트를 쓰지 않는 Godot(프로젝트 매니저)** 를 먼저 띄워 본다.
거기서도 죽으면 원인은 프로젝트가 아니라 그래픽 스택이다. 판정 기준:

- `[CRASH] ... GPU 드라이버 크래시 (nvoglv64.dll)` — NVIDIA OpenGL 드라이버가
  창 생성 중 세그폴트(0xc0000005). 이때는 **코드를 고쳐도 소용없다.**
  1. **재부팅한다.** 이게 유일하게 확실한 해결책이다.
     드라이버에 걸린 Godot 프로세스는 **스레드 0개 / 핸들 0개**로 남고,
     **관리자 권한으로도 종료가 거부된다** (2026-09-19 `taskkill /F` 로 확인).
     실행할 때마다 걸린 프로세스가 하나씩 쌓이므로 반복 실행은 무의미하다.
  2. 프로세스 정리와 어댑터 재시작을 자동으로 시도하려면 `fix_godot.bat` 을
     **관리자 권한으로 실행**한다. 선택 사항이고, 어댑터 재시작은 화면이 몇 초 검게 변한다.
  3. 재부팅 후에도 같으면 NVIDIA 드라이버를 재설치한다.
- `[OK] headless` 인데 창만 안 뜬다 — 게임 로직은 정상이다. 렌더러만 문제다.
  `run_game.bat`(D3D12) 또는 `run_game_opengl.bat`(OpenGL3) 을 번갈아 시도한다.

> 렌더러를 바꿀 때는 `--rendering-driver` 와 `--rendering-method` 를 **함께** 줘야 한다.
> `project.godot` 이 `gl_compatibility` 이므로 드라이버만 d3d12 로 바꾸면 짝이 안 맞는다.


