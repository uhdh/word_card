# legacy/ — 구버전 프로토타입 (보관용)

이 폴더의 파일들은 **현재 게임 빌드에서 사용되지 않습니다.** 참고/복원 목적으로만 보관합니다.

## 왜 여기 있나

초기 프로토타입은 `Main.tscn` 을 루트로 한 **씬 전환형 구조**였습니다.

```
Main.tscn
 ├─ MapView.tscn        (스테이지 선택 화면)
 ├─ BattleView.tscn     (전투 화면)
 ├─ DeckModal.tscn      (덱 편집)
 └─ RewardModal.tscn    (보상)
```

이후 타워 디펜스 로그라이크로 방향이 확정되면서, 현재 구조는 **단일 화면**입니다.

```
TitleScreen.tscn  →  TowerDefenseMain.tscn
                        └─ DefenseField / JamoBelt / TopBar ...
```

`TowerDefenseMain` 계열은 구 구조를 전혀 참조하지 않으므로 안전하게 분리했습니다.

## 현재 게임 진입점

- 실행 진입: `res://scenes/TitleScreen.tscn` (`project.godot` 의 `run/main_scene`)
- 실제 플레이: `res://scenes/TowerDefenseMain.tscn`

## 복원 방법

되살릴 일이 있다면 `scenes/`, `scripts/ui/` 로 파일을 옮기고
`.tscn` 안의 스크립트 경로(`res://scripts/ui/Main.gd` 등)가 맞는지 확인하세요.
