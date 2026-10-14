# UI/UX 개선 완료 보고서

**기간:** 2026-09-13  
**담당:** 게임 디렉터 (AI)  
**범위:** 디자인 시스템 → 레이아웃 → 보상 루프 → 피드백/주스 → 온본딩 → 정리 (Phase 0~6 전체)

---

## 1. 디자인 시스템 (Phase 1)

### Palette.gd — 20개 상수 + 5개 헬퍼
- 배경 5단계 (Void → Deep → Panel → Panel Hi → Inset)
- 선 3단계 (Subtle → Normal → Strong)
- 텍스트 5단계 (Primary → Secondary → Muted → Gold → On Dark)
- 시맨틱 6색 (HP Good/Warn/Danger, Gold, Wave, Mana Ink)
- 등급 3색 (Common → Rare → Super Rare)
- 헬퍼: `hp_color(ratio)`, `rarity_color()`, `rarity_glyph()`, `contrast_text()`, `with_alpha()`

### build_theme.gd → game_theme.tres
- 33개 타입, 765줄의 코드 생성 테마
- Button(5상태), Panel, PanelContainer, Label, RichTextLabel, ProgressBar, LineEdit, ScrollBar, PopupMenu, TooltipPanel
- 변형: ModalPanel, CardPanel, InsetPanel, TopBarPanel, TelegraphPanel, BeltPanel
- 텍스트 변형: TitleLabel, HeadingLabel, MutedLabel, StatLabel, DangerLabel
- 버튼 변형: PrimaryButton, GhostButton, DangerButton, ChipButton
- 등급 변형: RarityCommon, RarityRare, RaritySuperRare

---

## 2. 레이아웃 & 가시성 (Phase 2)

| 영역 | 변경 전 | 변경 후 | 효과 |
|------|---------|---------|------|
| TopBar | 78px, 숨김 버튼 | 58px, 전부 드러남 | 필드 가시 영역 +26px |
| JamoBelt | 300px, 슬레이트 팔레트 | 210px, 통일 팔레트 | 벨트 슬림화, 정보 밀도 향상 |
| DefenseField | min_size (1000,420) | (960,300) | 전체 화면 균형 |
| 타일 | 72×72 | 64×62 | 슬롯당 2개 더 촘촘 |
| Telegraph Bar | 없음 | 신규 (다음 라운드 요약 + 타이머) | 전략적 준비 시간 확보 |
| Base HP Bar | 없음 | 신규 (ProgressBar + 동적 색상) | 기지 상태 즉시 파악 |
| Enemy HP Bar | 고정 색 | 동적 색상 (비율 기반) + 실드 테두리 | 적 위협도 직관화 |

---

## 3. 보상 루프 활성화 (Phase 3)

- **WaveRewardModal** 전면 재작성
  - 희귀도별 카드 스타일링 (테두리 두께/색/문양 차등)
  - 등장 스태거 애니메이션 (0.05s 간격)
  - 페이드아웃 종료 (즉시 queue_free 제거)
- **보상 연결**: `_on_wave_cleared` → `_show_wave_reward` 자동 호출
- **토스트 시스템**: `_toast()` — 화면 하단 정보 피드백 (활자 획득, 유물 획득)
- **런 요약 개선**: 타워 누적 피해 랭킹 + 도달 지점 + 유물/활자 수

---

## 4. 피드백 & 주스 (Phase 4)

- **Juice.gd** 신규 유틸
  - `shake(node, intensity, duration)` — 감쇠 진동 (기지 피격, 화면 흔들림)
  - `punch(node, scale, duration)` — 스케일 펀치 (버튼/획득)
  - `damage_style(amount, kind)` — 데미지 숫자 스타일 분류
- **기지 피격**: 화면 흔들림(7px/0.26s) + 붉은 비네트 플래시(0.18s)
- **적 처치**: 골드 획득 숫자 + 금색 파편 4~6개 사방 분산
- **데미지 숫자**: 크기/색/좌우 드리프트 (큰 피해 60+ 강조)
- **타워 배치**: scale 0.8→1.0 BACK_OUT 등장 (0.22s)
- **단어 완성**: "단어 완성 · [단어]" 골드 배너 중앙 상단 (0.75s)
- **저 HP 경고**: HP 30% 이하 시 기지 표시 맥동 (0.5s 주기)

---

## 5. 온본딩 & 서사 (Phase 5)

- **TitleScreen.tscn** 신규 (실행 진입점)
  - 게임 로고 + 부제 + 세계관 한 줄 소개
  - 시작 / 이어하기 / 세계관 / 도감 / 종료
  - 페이드 인 + 로고 슬라이드 인트로 연출
- **3단계 코치마크** (첫 실행 시)
  1. 활자를 모으세요 (벨트 구매)
  2. 단어가 곧 타워 (슬롯 조합)
  3. 기지를 지키세요 (적 방어)
- **강제 서사 팝업 제거** — 세계관 버튼으로 언제든 열 수 있음
- **project.godot** main_scene → TitleScreen.tscn

---

## 6. 정리 및 문서 일치화 (Phase 6)

- **UI 이모지 전면 제거**: ⚔️🏆🪙🎲⏩🔥✨ 등 → 깔끔한 타이포그래피
- **레거시 이전**: Main, AutoPlayTest, MapView, BattleView, DeckModal, RewardModal → `legacy/`
- **legacy/README.md**: 구조 설명 + 복원 방법
- **테스트 assertion 업데이트**: belt 300→210, tile 72→64×62

---

## 검증 결과

| 테스트 | 결과 |
|--------|------|
| test_tower_traits.tscn | ✅ passed |
| early_wave_playtest.tscn | ✅ base HP 20/20 |
| AutoPlayTDTest.tscn | ✅ ALL TESTS PASSED |
| TitleScreen.tscn | ✅ clean parse |
| project --quit | ✅ zero errors |

---

## 다음 단계 제안

1. **사운드 시스템 점검** — 현재 SoundEngine.play_xxx 가 stub인지 실제 파일인지 확인
2. **폰트 최적화** — neodgm.ttf 가 모든 UI에 적합한지, 서체 크기별 hinting 확인
3. **모바일 대응** — 현재 PC 해상도 기준; 모바일 터치 영역/스케일 검토 필요
4. **밸런싱** — 3막 20라운드 구성의 실제 난이도 곡선 플레이테스트
