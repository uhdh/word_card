# 언어의 조각 : 말의 심연 — 최종 개선 보고서

**완료일:** 2026-09-14  
**총 작업량:** 14개 태스크 (Phase 0~6 + 추가 개선 4가지 + 성능 최적화)  
**검증 상태:** 모든 테스트 통과, zero errors/warnings

---

## 1. 디자인 시스템 (Phase 1)

### Palette.gd — 20개 상수 + 5개 헬퍼
- 배경 5단계, 선 3단계, 텍스트 5단계, 시맨틱 6색, 등급 3색
- 헬퍼: `hp_color()`, `rarity_color()`, `rarity_glyph()`, `contrast_text()`, `with_alpha()`

### build_theme.gd → game_theme.tres
- 33개 타입, 765줄 코드 생성 테마
- Button/Panel/Label/ProgressBar 등 + 변형 23개

---

## 2. 레이아웃 & 가시성 (Phase 2)

| 영역 | 변경 전 | 변경 후 |
|------|---------|---------|
| TopBar | 78px | 58px |
| JamoBelt | 300px | 210px |
| DefenseField | (1000,420) | (960,300) |
| 타일 | 72×72 | 64×62 |
| Telegraph Bar | 없음 | 신규 |
| Base HP Bar | 없음 | 신규 |
| Enemy HP Bar | 고정 색 | 동적 색상 + 실드 테두리 |

---

## 3. 보상 루프 (Phase 3)

- WaveRewardModal 전면 재작성 (희귀도 카드 스타일링, 스태거 애니메이션)
- 웨이브 클리어 → 보상 자동 연결
- 토스트 시스템 (`_toast()`)
- 런 요약 개선

---

## 4. 피드백 & 주스 (Phase 4)

- `Juice.gd`: shake, punch, damage_style
- 기지 피격: 화면 흔들림 + 붉은 비네트
- 적 처치: 골드 숫자 + 금색 파편
- 데미지 숫자: 크기/색/드리프트
- 타워 배치: BACK_OUT 등장
- 단어 완성: 골드 배너
- 저 HP 맥동 경고

---

## 5. 온본딩 & 서사 (Phase 5)

- TitleScreen 신규 (실행 진입점)
- 3단계 코치마크
- 강제 서사 팝업 제거
- `project.godot` main_scene → TitleScreen

---

## 6. 정리 (Phase 6)

- UI 이모지 전면 제거
- 레거시 6개 씬/스크립트 → `legacy/`
- 테스트 assertion 동기화

---

## 7. 추가 개선사항

### 사운드 (Task #8)
- 볼륨 카테고리 분리 (master/sfx/ui)
- 설정 저장/복원
- 플레이어 풀 8→12
- 웨이브 시작음 전용 사운드

### 폰트 (Task #9)
- MSDF 활성화로 크기별 가독성 향상

### 모바일 (Task #10)
- 핸드헬드 방향 설정
- 터치 영역 유지

### 밸런싱 (Task #11)
- 적 HP: 점진적 증가 (base * wave * act)
- 골드: 모든 적 1G+, 보스 5+G
- 웨이브 본us: 5 + wave + 보스 본us
- 타워 데미지: [4,15,28] → [8,22,42]
- 시작 골드: 30 → 40

### 애니메이션 (Task #12)
- Projectile 방향 회전

### 설정 (Task #13)
- 볼륨 설정 모달 (3개 슬라이더)

### 성능 (Task #14)
- 메모리 누수 확인 완료
- 오브젝트 정리 메커니즘 확인

---

## 검증 결과

| 테스트 | 결과 |
|--------|------|
| test_tower_traits.tscn | ✅ passed |
| early_wave_playtest.tscn | ✅ base HP 20/20 |
| AutoPlayTDTest.tscn | ✅ ALL TESTS PASSED |
| project --quit | ✅ zero errors/warnings |

---

## 게임 실행 방법

```bash
# Godot 에디터로 열기
godot --path godot

# 헤드리스 테스트
godot --headless --path godot res://scenes/tower/AutoPlayTDTest.tscn

# 빌드
# 프로젝트 → 납품 → Windows Desktop
```

---

## 다음 단계 (선택사항)

1. **실제 플레이테스트** — 3막 20라운드 전체 클리어 테스트
2. **스팀/itch.io 배포** — 빌드 및 업로드
3. **추가 콘텐츠** — 새로운 단어, 타워, 적 종류
4. **멀티플레이어** — 리더보드, 도전 과제
