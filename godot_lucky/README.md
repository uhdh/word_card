# 언어의 조각 : 무한 병합 (godot_lucky)

**그리드 병합 랜덤 디펜스** — 기존 『언어의 조각 : 말의 심연』(자모 결합 타워 디펜스)의
**자모 → 단어 조합은 그대로 가져오고**, **무대만** 참고 영상의 형식으로 바꾼 새 게임.

> 현재 단계: **규칙·조작·전투까지 구현 완료.** 헤드리스 프로브 **110개 판정 전부 통과**(`fails=0`),
> 화면은 스크린샷으로 확인. 밸런스 수치는 `MergeRules.gd` 한 파일에 모여 있고 **바꿔도 되는 값**이다.

---

## 왜 별도 프로젝트인가

기존 `godot/` 은 감독 결정 없이 손대지 않는 **동결** 상태다(`WordTower.gd` · `DefenseField.gd` ·
`TowerDefenseMain.gd` 등 동결 6종 + 판정형 프로브 39개 스위트). 그래서 **독립 프로젝트**로 만들었다 —
기존 스위트에 영향 0, 되돌리기 쉬움. 폰트와 테마, 그리고 **자모 코어 4개 + 사전 JSON 2개**만 복사해 왔다
(바이트 동일 — `sha256sum` 으로 확인).

| | 경로 |
|---|---|
| 기존 게임(동결) | `E:\project\word_card\godot` |
| **이 프로젝트** | `E:\project\word_card\godot_lucky` |
| 참고 영상 | `C:\Users\maktu\Documents\카카오톡 받은 파일\KakaoTalk_20261008_153157386.mp4` |
| 프레임 추출본 | `E:\project\word_card\tmp\kakao_video\` |
| 스크린샷(빈 보드 / 플레이) | `E:\project\word_card\_mock_shot.png` · `_merge_play.png` |
| **바탕화면 바로가기** | `C:\Users\maktu\Desktop\언어의 조각 - 무한 병합.lnk` |

---

## 게임 규칙 (내가 정한 값 — `scripts/MergeRules.gd`)

| | 규칙 |
|---|---|
| **보드** | 7×7. **바깥 한 줄(24칸) = 적이 걷는 경로**, **안쪽 5×5(25칸) = 배치 슬롯** |
| **경로** | `(0,0)` 스폰 → 위 → 오른쪽 → 아래 → 왼쪽 → **`(1,0)` 기지**. 길이 23칸 |
| **뽑기** | 자모 1장이 빈 칸에 놓인다. 값 = `20 + 5n` (20·25·30·35…). **3번째마다 모음 확정** |
| **병합** | 같은 자모·같은 등급 **3장 → 1장, 등급 +1** (자동). 등급 1~7 |
| **단어** | 안쪽 **가로 5줄 + 세로 5열**을 한 줄씩 `HangulStreamParser` 로 파싱. 그 줄이 곧 **단어 타워** |
| **공격 형태** | `AttackStyle.style_for()` — 단어 뜻 → 특성(splash/chain/control/damage_over_time/…). 못 찾으면 분류 폴백 |
| **강화** | 등급 × 40 G → 등급 +1 |
| **조합** | 30 G + 같은 자모·같은 등급 1장 → 등급 +1 |
| **판매** | 등급 × 15 G 환급 |
| **타워** | 사거리 3.4칸 · 0.75초마다 발사 · 피해 = 사전 피해 × (1 + 0.45 × (평균등급 − 1)) |
| **웨이브** | 적 수 `4 + n` · HP `24 × 1.19^(n−1)` · **5라운드마다 보스**(HP ×7 · 피해 3) · 처치 3 G · 클리어 `25 + 6n` G |
| **시작** | 골드 120 · 기지 HP 50 |
| **조작** | `[SPACE]` 웨이브 · `[1~4]` 뽑기/강화/조합/판매 · `[TAB]` 배속(1×/2×/4×) · `[R]` 다시 · 타일 클릭 → 빈 칸 클릭이면 이동 |

**설계 의도**
- **"미지의 활자"** — 사전에 없는 조합도 타워가 된다(`make_unknown_word_data`). 없으면 운 나쁜 판이 아무것도 못 한다.
- **모음 확정** — 기존 `generate_reward_choices` 와 같은 이유(자음만 쌓이면 단어가 영영 안 선다).
- **뽑기 값 상승** — 무한히 뽑아 보드를 채우는 게 항상 최선이면 선택이 사라진다.
- **타일 이동** — 빈 칸을 누르면 고른 타일이 옮겨진다. 단어 배치가 퍼즐이 된다.

---

## 참고 영상에서 옮긴 것 (실측)

영상은 **회전 메타데이터(-90)** 가 있어 표시 크기는 **884×1400 세로**다. 1프레임을 뽑아
(`tmp/kakao_video/tmp_full_01.png`) 픽셀을 직접 재서 배치와 색을 옮겼다.

| 잰 것 | 값 (884×1400 기준) |
|---|---|
| 보드 | **728×728** · x 77~805 · y 400~1128 · 타일 89px · 간격 15px · **피치 104px** |
| 격자 | **7×7** — 바깥 한 줄 = 적이 걷는 경로, **안쪽 5×5 = 배치 슬롯** |
| 하단 버튼 | 뽑기(파랑) · 강화(보라) · 조합 · 판매 |
| 색 | 경로 `#B59567` · 빈 슬롯 `#423732` · 상단 판 `#2A355D` · 뽑기 `#355CD8` · 강화 `#894DDA` |

설계 해상도는 **720×1140** (= 884:1400 과 같은 비율 0.6316). 창은 540×855 로 띄운다(1080p 화면에 맞춤).

---

## 구조

```text
godot_lucky/
├── project.godot              # 720×1140 세로 · GL Compatibility · neodgm · 오토로드 3개
├── icon.svg                   # 프로젝트 아이콘 (Godot 기본)
├── icon.ico                   # ★ 바탕화면 바로가기용 6크기 아이콘 (tools 스크립트가 생성)
├── scenes/MergeMain.tscn      # 본편 엔트리
├── scripts/
│   ├── MergeMain.gd           # 화면 조립 + 입력 (게임 로직 없음)
│   ├── MergeBoard.gd          # 7×7 뷰 — 경로 링·슬롯·타워·타일·적·투사체·사거리 원
│   ├── MergeTile.gd           # 타일 하나 그리기 (자모 + 별 등급) — **정적 함수, 노드 아님**
│   ├── MergePalette.gd        # 색 (영상 실측값 + 특성색)
│   ├── MergeRules.gd          # ★ 설계 수치 전부 — 밸런스는 여기만 고치면 된다
│   ├── MergeGame.gd           # ★ 규칙·상태 전부 — 그리기 없음 (뽑기/병합/단어/전투/웨이브)
│   ├── MergeData.gd           # 경로 장식 점
│   └── core/                  # 기존 게임에서 **바이트 동일** 복사
│       ├── HangulEngine.gd        # 자모 조합 · 가중 뽑기 · compose_syllable
│       ├── HangulStreamParser.gd  # 자모열 → 음절 → 단어 (최장 일치)
│       ├── WordDatabase.gd        # 사전 366 단어
│       └── AttackStyle.gd         # 단어 뜻 → 공격 형태
├── assets/data/               # word_database_265.json + _expansion_100.json
├── tools/
│   ├── MergeProbe.gd/.tscn    # ★ 규칙 프로브 110 판정 (헤드리스)
│   ├── LayoutDiag.gd/.tscn    # ★ 레이아웃 진단 (넘침·잘림·화면 글자 덤프)
│   ├── Shot.gd/.tscn          # 스크린샷 (목업 / play=1)
│   └── make_desktop_shortcut.py  # ★ 바탕화면 바로가기 + icon.ico 재생성 (파이썬)
├── fonts/neodgm.ttf           # 기존 프로젝트에서 복사
└── ui/theme/game_theme.tres   # 기존 프로젝트에서 복사
```

---

## 실행 · 검증

```bash
GODOT=/c/Users/maktu/AppData/Local/Microsoft/WinGet/Links/godot

# 그냥 실행 (창이 뜬다)
"$GODOT" --path E:/project/word_card/godot_lucky

# 오류 없이 뜨는지 (창을 띄우고 200프레임 뒤 스스로 종료)
"$GODOT" --path E:/project/word_card/godot_lucky --quit-after 200

# ★ 규칙 프로브 — 110 판정. `PROBE_DONE checks=110 fails=0` + RC=0 이어야 통과
"$GODOT" --headless --path E:/project/word_card/godot_lucky res://tools/MergeProbe.tscn

# ★ 레이아웃 진단 — `min_width_offenders=0 tall_over=0 clipped=0` 이어야 한다. 화면 글자도 덤프한다
#   ⚠️ `TALL_LEAD` 는 판정이 아니라 조사 목록이다(보드를 담은 컨테이너는 정당하게 크다).
"$GODOT" --path E:/project/word_card/godot_lucky res://tools/LayoutDiag.tscn

# 스크린샷 (빈 보드 / 타일·타워·적이 올라간 판)
"$GODOT" --path E:/project/word_card/godot_lucky res://tools/Shot.tscn \
  -- out=E:/project/word_card/_mock_shot.png wait=15
"$GODOT" --path E:/project/word_card/godot_lucky res://tools/Shot.tscn \
  -- out=E:/project/word_card/_merge_play.png play=1 wait=20

# 폰트·아이콘 재임포트 → `SCRIPT ERROR` 0 줄이어야 한다
"$GODOT" --headless --path E:/project/word_card/godot_lucky --import
```

⚠️ **`--check-only --script` 로 판정하지 마라** — 오토로드를 못 풀어 `Identifier not found: HangulEngine`
를 **모든 스크립트가 낸다**. 진짜 문법 오류만 보려면 그 출력에서 내 파일 이름으로 grep 해라.

---

## 바탕화면 바로가기

`C:\Users\maktu\Desktop\언어의 조각 - 무한 병합.lnk` — 더블클릭하면
`godot.exe --path E:\project\word_card\godot_lucky` 가 실행된다(에디터 아님, 바로 플레이).

```bash
# 다시 만들기 (아이콘까지 새로 생성한다). `VERIFY fails=0` + `ShellExecuteW 42` + RC=0 이어야 통과
PYTHONIOENCODING=utf-8 ~/.workbuddy-ai/binaries/python/envs/default/Scripts/python.exe \
  tools/make_desktop_shortcut.py
```

⚠️ **이 환경은 COM 생성을 막는다** — `WScript.Shell`(`New-Object -ComObject`)도, PowerShell 툴 자체도
쓸 수 없다(툴 단에서 차단되고, 출력도 안 돌려준다). 아이콘은 **Pillow** 로 `icon.svg` 를 2배로 다시 그려
`.ico` 여섯 크기로 굽는다.

### ⚠️ `.lnk` 는 `pylnk3` 로 만들면 **안 된다** (실측 2026-10-09)

`pylnk3` 는 **파서지 생성기가 아니다.** 만든 `.lnk` 는 필드가 전부 정상으로 읽히는데도
**더블클릭하면 아무 일이 없다**(`ShellExecuteW` → **5 액세스 거부**).

| 시도 | `ShellExecuteW` |
|---|---|
| `pylnk3.for_file()` 로 새로 만든 것 | **5** |
| 정상 `.lnk` 를 파싱해 **그대로 되쓰기만** 한 것 (1063 → 2004 B) | **5** |
| 기존 정상 `.lnk` (대조군) | 42 |

→ `IDList` 재직렬화가 셸 규격과 어긋난다. **고침 = 바이트 이식** — 정상 `.lnk` 의
**앞부분(헤더 76B + IDList + LinkInfo)을 복사**하고 **StringData 만** 갈아 끼운다.
`IDList`·`LinkInfo` 는 **타깃만 가리키므로**, 타깃이 같으면 Windows 가 만든 바이트를 그대로 써도 된다.
타깃이 같은 `.lnk` 를 바탕화면·시작 메뉴에서 자동 탐색하고, 없으면 **번들 픽스처**(804 B hex)로 떨어진다.
템플릿의 `LinkFlags` 중 **우리가 안 쓰는 비트는 지운다**(`0x4000 HasExpIcon` — 블록을 안 넣으므로).

⚠️ **타깃은 `WinGet\Links\godot.exe`(심볼릭 링크)로 잡아라** — `WinGet\Packages\...\Godot_v4.7.2-stable_win64.exe`
를 직접 가리키면 Godot 이 버전업될 때 exe 이름이 바뀌어 바로가기가 조용히 깨진다.

⚠️ **검증은 필드 대조로 끝내지 마라** — `ShellExecuteW` 로 **실제로 열어 봐야** 한다
(>32 = 셸이 열었다 / 5 = 깨짐). 그리고 **게임 프로세스가 떴는지**까지 보라 —
`Links\godot.exe` 는 심볼릭 링크라 프로세스 이미지 이름이 **`Godot_v4.7.2-stable_win64.exe`** 다
(`godot.exe` 로 찾으면 못 찾는다 — 거짓 음성).

⚠️ **`.lnk` 를 `os.replace` 로 쓰지 마라** — 파일 신원이 바뀌어 **바탕화면 아이콘 자리가 초기화**된다
(실측 `(672,5) → (224,1633)` = 왼쪽 아래 구석 → "바로가기가 없다" 는 착각을 만든다).
**제자리 `open(path,"wb")`** 를 쓰고 **내용이 같으면 아예 쓰지 않는다.**
자리가 옮겨졌으면 `word_card/tools/desktop_icon_check.py --move-to-top "언어의 조각"` 로 되돌린다.

---

## ⚠️ 밟은 함정 (다음 사람이 같은 데 빠지지 않게)

1. **`trait` 는 예약어다** (Godot 4.4+ 의 GDScript trait 기능). `var trait := ...` 는
   `Parse Error: Expected variable name after "var"` 로 **스크립트 전체를 못 쓰게** 만든다.
   지역 변수·매개변수 이름으로 쓰지 마라. (딕셔너리 **키** `"trait"` 는 문자열이라 안전하다.)
2. **`:=` 로 Variant 를 추론하면 경고가 아니라 오류다** — `inference_on_variant` 의 기본 심각도가
   `error` 라 `var sel := dict.get(k, {})` 가 `Parse Error` 가 된다. 타입을 명시해라
   (`var sel: Dictionary = dict.get(k, {})`).
3. **`class_name` 을 빠뜨리면 `Could not find type "X"` 로 씬이 통째로 안 뜬다.**
   `MergeBoard`·`MergeTile` 둘 다 처음에 빠져 있었다.
4. **`low_processor_mode=true` 면 정지 화면에서 프레임이 멈춘다** → `frame_post_draw` 가 다시 오지 않아
   **캡처가 영영 안 된다**(첫 판이 90초 타임아웃). `Shot.gd` 가 켜자마자 끈다.
5. **줄바꿈(`autowrap`) Label 은 폭이 정해지기 전에 *글자마다* 접힌다** — 그래서 최소 높이가
   **928px** 로 폭발하고(실측), 그 높이가 `VBox → MarginContainer` 로 올라가 화면이 세로로 넘친다.
   반대로 줄바꿈을 끄면 긴 안내문이 **최소 폭 800px** 을 요구해 가로로 넘친다(4번째 버튼이 사라졌다).
   → **긴 문구는 짧은 줄 둘로 나눠 쌓아라.** 어느 쪽이든 `LayoutDiag` 로 재서 확인해라.
6. **단어 라벨을 타일보다 먼저 그리면 위 칸 타일이 라벨을 덮는다** — 맨 아랫줄 단어('나무')가 반쯤 가려졌다.
   라벨은 `_draw_tower_labels()` 로 **타일 뒤에** 그린다.
7. **사거리 원은 보드 밖으로 나간다** — 사거리 3.4칸짜리 타워의 `draw_arc` 는 시안 고리 바깥까지 그려져
   "보드가 잘린 것처럼" 보인다. 원을 잘게 나눠 보드 rect 안 조각만 잇는다(`_draw_range`).
8. **같은 자모·같은 등급 3장이 모이면 자동 병합이 보드를 바꾼다** — 스크린샷 시드에 `ㅏ` 를 5장 깔았더니
   병합이 단어를 부숴 '사자'·'바다' 가 '사'·'다' 로 굳었다. 시드를 짤 때 **반복 자모는 등급을 달리** 해라.
9. **neodgm.ttf 에 `★ ☆ ☀ → ⚙ ♥` 가 없다** (실측). 그래서 **별은 글자가 아니라 도형으로 그린다**
   (`MergeTile.star_points()`). 쓸 수 있는 기호는 `▶ ● ◆ × ·` 정도다.
   — 기존 프로젝트의 §2.37 "폰트 밖 글리프" 와 **같은 함정**이다.
10. **`matched` 는 "사전 단어인가" 가 아니다** — `AttackStyle` 에서 **"공격 형태가 단어의 뜻에서
    왔는가"**(exact/rule)다. 사전에 있어도 분류 폴백으로 떨어지는 단어가 많다. 처음에 UI 에
    `(사전 N)` 이라고 썼다가 거짓말이 되어 `(뜻 반영 N)` 으로 고쳤다.
11. **`_wave_total` 을 `maxi` 로 누적하면 리셋 뒤에도 지난 판 최대치가 남는다** — 7라운드까지 가서
    다시 시작하면 1라운드 진행 바가 5/11 로 어긋난다. 라운드가 바뀔 때 다시 세라.
12. **창 크기에 기대지 마라** — 캡처는 `SubViewport` 720×1140 고정이라 창이 작아도 결과는 설계 해상도다.
13. **측정 도구의 임계값을 판정처럼 쓰지 마라** — `LayoutDiag` 가 처음엔 `min.y > 120` 을 그대로
    `tall` 로 세었다. 그런데 보드를 담은 컨테이너는 **정당하게 380px** 이라 아무 문제가 없는데도
    **늘 3개가 떠서** "회귀했다" 고 오해하게 만들었다. → **판정**(`tall_over` = 뷰포트 높이 초과)과
    **단서**(`TALL_LEAD`)를 나눴다. 초록이어야 할 것을 빨갛게 보이게 하는 도구는 도구가 아니다.
14. **필드가 다 맞아도 셸이 거절할 수 있다** — `pylnk3` 가 만든 `.lnk` 는 타깃·인자·작업폴더·아이콘이
    **전부 정상으로 읽히는데** `ShellExecuteW` 는 **5(액세스 거부)** 를 준다(더블클릭해도 무반응).
    **"고쳤다" 와 "고쳐졌다" 는 다르다** — 검증은 *실제로 열어 보는 것* 으로 끝내라.
15. **심볼릭 링크로 실행하면 프로세스 이름이 바뀐다** — `WinGet\Links\godot.exe` 를 실행하면
    프로세스 이미지 이름은 **`Godot_v4.7.2-stable_win64.exe`**(타깃 이름)다. `godot.exe` 로 찾으면
    **못 찾는다**(거짓 음성). **전체 프로세스 목록을 뜯어 before/after 로 diff** 해라.
    ⚠️ 그리고 **`tasklist` 는 OEM 코드페이지**(여기선 cp949)로 뱉는다 — utf-8 디코드는 터진다.
16. **같은 파일을 `os.replace` 로 갈아치우면 셸이 신원을 잃는다** — 바탕화면 아이콘 자리가
    초기화돼 **왼쪽 아래 구석**으로 간다(실측 `(672,5) → (224,1633)`). 그러면 감독은 다시
    "바로가기가 없다" 고 한다. **제자리 `open(wb)`**, 내용이 같으면 **아예 안 쓴다.**
    옮긴 자리는 `SHChangeNotify` 로 **셸백에 기록**해야 남는다(안 하면 새로고침에 되돌아간다).

---

## 다음 할 일 (감독 결정)

규칙·수치는 **내가 정한 값**이므로 전부 바꿔도 된다. 근거는 `MergeRules.gd` 주석에 있다.

- [ ] **밸런스 확인** — 실측: 웨이브 1은 나무 타워 **1개로 무피해 클리어**됐다(처치 골드 15 = 5킬).
      초반이 너무 쉽다. `TOWER_RANGE_CELLS`(3.4)가 보드 절반을 덮는 것도 세다.
- [ ] **`AUTO_MERGE` 를 끌지** — 끄면 "조합" 버튼이 유일한 병합 수단이 되어 더 퍼즐에 가까워진다.
- [ ] **경로 방향 · 보스 형태** — 지금은 보스가 잡몹과 같은 경로를 느리게 걷는다.
- [ ] **목표(전설 조합 / 신화 도전)** — 참고 영상의 상자 두 개는 아직 안 옮겼다.
- [ ] **에셋(유닛 아이콘)** · UI 를 `.tscn` 으로 굳힐지(지금은 코드가 화면을 만든다).
- [ ] 프로브를 `tests/run_all.sh` 류 스위트에 등록할지 (지금은 단독 실행).
