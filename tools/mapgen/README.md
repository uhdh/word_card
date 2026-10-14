# tools/mapgen — TD 맵 경로/발판 생성 파이프라인

막별 맵 아트(1024×352)에 **칠해진 길**을 따라 적 경로를 뽑고,
그 길과 **절대 겹치지 않는** 타워 발판 좌표를 만든다.
결과는 `godot/scripts/tower/DefenseField.gd` 의 `ACT_PATHS` / `ACT_SLOTS` 로 들어간다.

## 왜 필요한가

`DefenseField.gd` 의 `Path2D` 는 적이 실제로 걷는 선이다.
발판이 이 선(또는 칠해진 길)에 겹치면 타워가 길 위에 서 있는 것처럼 보인다.
**길 폭이 막마다 다르기 때문에**(정원 44px / 광산 62px / 천공성 44px)
중심선에서 고정 거리만 띄우는 방식으로는 절대 해결되지 않는다.

## 실행 순서

```bash
PY=~/.workbuddy-ai/binaries/python/envs/default/Scripts/python.exe   # numpy/scipy/scikit-image/Pillow 필요
cd tools/mapgen

$PY extract_paths.py     # (검증용) 색 기반으로 길 리본을 뽑아 out/path_act*.png 생성
$PY build_pads.py        # ★ 실제로 쓰는 단계: out/layout.json + out/pads_act*.png
$PY verify_on_screen.py  # 게임 스크린샷 위에 발판/길을 겹쳐 out/verify_act*.png 생성
$PY check_sync.py        # ★ out/layout.json 과 DefenseField.gd 가 일치하는지 검사
```

## ★ `build_pads.py` 를 돌렸으면 `check_sync.py` 까지 돌린다

`build_pads.py` 의 결과는 **손으로 복사**되어 `DefenseField.gd` 의 `ACT_PATHS` /
`ACT_SLOTS` 로 들어간다. 맵 아트를 고치고 파이프라인만 다시 돌린 뒤 복사를 빠뜨리면
발판이 옛 길에 남아 **타워가 길 위에 서거나 죽은 자리에 놓인다.**
(2026-09-17 에 3막 경로를 전체 폭으로 바꾸면서 실제로 생긴 위험이다)

`check_sync.py` 는 여섯 개 집합(막 3 × 경로/발판)을 좌표 단위로 대조하고,
어긋나면 어느 인덱스가 얼마나 밀렸는지 출력한 뒤 종료 코드 1 로 끝난다.
좌표 허용 오차는 0.6px (소수 첫째 자리 반올림분).

## 파일

| 파일 | 역할 |
|---|---|
| `waypoints.py` | **손으로 검증한** 막별 경로 웨이포인트. 모든 계산의 기준. |
| `build_pads.py` | 발판 좌표 생성기 (v3). 아래 규칙 참고. |
| `extract_paths.py` | 색/스켈레톤 기반 길 추출기. `waypoints.py` 를 만들 때 쓴 도구. |
| `install_word_icons.py` | 100개 확장 단어 아이콘을 32×32 로 설치하고 JSON `icon` 경로를 고친다. |
| `verify_on_screen.py` | 실제 게임 화면 위에 결과를 겹쳐 눈으로 검증. |
| `check_sync.py` | `out/layout.json` 과 `DefenseField.gd` 의 `ACT_PATHS`/`ACT_SLOTS` 대조 (종료 코드 1 = 불일치). |
| `out/` | 생성된 `layout.json` + 검증 이미지 |
| `_scratch/` | 폐기된 이전 시행착오 스크립트 (gitignore) |

## build_pads.py 의 배치 규칙

```
need = ROAD_HALF[act] + PAD_R + GAP
     = 도로 반폭      + 32    + 8      # PAD_R 은 WordTower 카드 반지름(64/2)
```

* 후보는 `need` 이상, `need + REACH(132)` 이하 거리에만 놓는다 → 사거리 안에 유지.
* 1차: 경로를 11등분한 각 구간 중앙에서 도로 양옆으로 `need + {0,10,22,36,52,70,92,118}` 만큼 떨어뜨려 본다.
  자리를 못 찾으면 `step*0.25` 만 전진해 근처의 유효 지점을 다시 찾는다.
* 2차: 그래도 모자라면 유효 격자(8px)에서 최원거리 샘플링으로 채운다.
* 밝기 검사는 **맵 대비 상대값**(`percentile(lum,60) * 0.46`)을 쓴다.
  절대 임계값은 막별 명암차(정원 90 / 광산 44 / 천공성 87) 때문에 못 쓴다.

## ⚠️ 동기화 규칙

`DefenseField.gd` 의 다음 상수는 이 스크립트와 **반드시 같아야** 한다.

| DefenseField.gd | build_pads.py |
|---|---|
| `PAD_RADIUS = 32.0` | `PAD_R = 32.0` |
| `PAD_ROAD_GAP = 8.0` | `GAP = 8.0` |
| `ACT_ROAD_HALF = {1:23, 2:31, 3:22}` | `ROAD_HALF` |
| `ACT_SLOTS` | `out/layout.json` 의 `slots` |

발판 좌표를 바꾸려면 **생성기를 다시 돌리고** `ACT_SLOTS` 를 통째로 교체할 것.
`tests/test_wave_balance.gd::_test_enemy_path_follows_road_center` 가
`ACT_ROAD_HALF + PAD_RADIUS + 4` 이상을 요구하므로 어긋나면 즉시 실패한다.

## 참고: 타워 카드 크기

`WordTower.tscn` 은 64×64 다 (예전 88×96 → 맵을 너무 많이 가려서 축소).
**카드 크기를 키우면 `PAD_RADIUS` / `PAD_R` 도 같이 키우고 발판을 다시 생성해야 한다.**
