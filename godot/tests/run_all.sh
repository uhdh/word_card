#!/usr/bin/env bash
# 모든 테스트를 실행한다.
#   - 대부분은 --headless 로 돈다.
#   - test_belt_drag_drop 은 GUI 히트테스트가 필요해 창을 띄워야 한다.
#     (--headless 로 돌리면 스스로 SKIP 한다)
#   - 판정형 프로브 39개(tools/)도 함께 돈다 → 전체 ≈4분(실측 4분01초 · 프로브 등록 전에는 ≈43초).
#     36개로 4회 연속 실행해 36/36 통과·실패 0 을 확인했다(2026-10-03). 37·38번째는 같은 날
#     추가해 **각각 주입으로 반증**한 뒤 등록했다 — `TowerRebuildProbe`(가드 제거 RC=3 · 팝 제거 RC=2),
#     `ControlSplashProbe`(반경 블록 제거 RC=2 · 둔화 가드 제거 RC=1). 38개 등록 후 1회 `REAL_RC=0`.
#     39번째 `FixInvariantProbe`(2026-10-04) — 감사 ✅ 중 **프로브가 아무도 안 지키던 넷**
#     (§2.1 사장 필드 · §2.3 HP 바 감쇠 · §6.6 사망 연출 · §6.7 bounce 회전/섬광)의 회귀 가드.
#     주입 4회 전부 검출(S1 RC=2 · S2 RC=1 · S3 RC=1 · S4 RC=2).
#     ⚠️ 첫 판의 S4 는 "회전이 **변했다**" 만 재서 **자기 되돌림을 못 잡았다**(0 → π 로 통과) —
#     "spin_speed × delta 만큼 돈다" 로 고쳤다. **변했다 ≠ 계약대로다.**
#     ⚠️ 런타임 난수 의존은 **0** 이다(유일한 RNG 언급 `CritSignalProbe` 는 소스 텍스트 스캔).
#     다만 12개는 타이머/`await` 를 쓴다 — 그래도 4회 모두 같은 결과였다.
# Godot 경로를 직접 지정하려면:  GODOT=/path/to/godot ./run_all.sh
#
# 종료 코드: 0 = 전부 통과, 1 = 하나 이상 실패(또는 결과 줄 없음).
# 예전에는 항상 0 으로 끝나서, 결과 줄을 못 찾아도 CI 가 성공으로 봤다.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# '이 테스트가 실제로 돌았다' 를 뜻하는 줄들.
RESULT_RE='passed|HP [0-9]+/[0-9]+|기지 [0-9]+/[0-9]+|SKIPPED|ALL TESTS PASSED|PROBE_OK'

FAILED=0
SKIPPED=0

find_godot() {
  local c
  for c in "${GODOT:-}" godot godot4 \
           "$HOME/AppData/Local/Microsoft/WinGet/Links/godot" \
           "/c/Users/${USER:-}/AppData/Local/Microsoft/WinGet/Links/godot" \
           "$LOCALAPPDATA/Microsoft/WinGet/Links/godot" \
           "$LOCALAPPDATA/Microsoft/WinGet/Links/godot.exe"; do
    [ -n "$c" ] && [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

GODOT="$(find_godot)" || { echo "Godot 실행 파일을 찾지 못했습니다. GODOT=... 로 지정하세요."; exit 2; }
echo "Godot: $GODOT"

# run <이름> [--retry] [--skip-on-gl-crash] -- <godot 인자...>
#   --retry 를 주면 결과 줄을 못 찾았을 때 한 번 더 돌린다.
#   GUI 테스트(test_belt_drag_drop)는 창 생성이 다른 프로세스와 경합하면
#   결과 줄을 못 내고 끝나는 일이 실제로 있었다 (2026-09-18, 6회 중 1회).
#   --skip-on-gl-crash 는 창 생성이 GPU 드라이버에서 죽을 때 SKIPPED 로 넘긴다.
run() {
  local name="$1"; shift
  local attempts=1
  local skip_gl=0
  if [ "${1:-}" = "--retry" ]; then attempts=2; shift; fi
  if [ "${1:-}" = "--skip-on-gl-crash" ]; then skip_gl=1; shift; fi
  local attempt=1

  while :; do
    if [ "$attempt" -gt 1 ]; then
      printf '=== %s (재시도 %d) ===\n' "$name" "$attempt"
    else
      printf '=== %s ===\n' "$name"
    fi

    local out
    # 반드시 timeout 으로 감싼다. 씬 스크립트에 파싱 에러가 있으면 스크립트가 로드되지 않아
    # _ready 도 quit() 도 안 불리고 Godot 프로세스가 영원히 끝나지 않는다.
    # (실제로 이걸로 7분을 날렸다 — tests/README 또는 SKILL.md 참고)
    out="$(cd "$ROOT" && timeout "${TEST_TIMEOUT:-240}" "$GODOT" "$@" 2>&1)"
    local rc=$?
    if [ "$rc" = "124" ]; then
      printf '!! %s: %s초 안에 끝나지 않았습니다 (무한 대기 — 파싱 에러를 의심할 것)\n' \
        "$name" "${TEST_TIMEOUT:-240}"
    fi

    local has_result=0
    if printf '%s\n' "$out" | grep -qE "$RESULT_RE"; then has_result=1; fi

    # 통과 조건은 '결과 줄이 있다' AND '종료 코드 0' 이다.
    # 종료 코드를 보지 않으면, 결과 줄을 항상 찍는 도구는 실패해도 통과로 보인다.
    # 실제 예: DifficultyPlaytest 는 성공/실패와 무관하게 '기지 HP n/n' 을 찍는다.
    # 그래서 난이도 게이트가 위반으로 exit 1 을 내도 러너가 조용히 통과시켰다.
    if [ "$has_result" = "1" ] && [ "$rc" = "0" ]; then
      # SCRIPT ERROR / Parse Error 는 '호출 시그니처가 바뀌었는데 호출부를 안 고쳤다'
      # 같은 것을 뜻한다. 결과 줄은 멀쩡히 찍히므로 통과로 넘기면 조용히 썩는다.
      # (2026-09-19: _update_boss_bar() 가 delta 인자를 받게 됐는데 테스트가 인자 없이
      #  부르고 있었고, 결과 줄은 'passed' 라서 스위트가 초록으로 통과했다)
      if printf '%s\n' "$out" | grep -qE "SCRIPT ERROR|Parse Error"; then
        printf '%s\n' "$out" | grep -E "SCRIPT ERROR|Parse Error" | head -3
        printf '!! %s: 결과는 나왔지만 스크립트 에러가 있습니다 — 실패로 처리합니다\n' "$name"
        return 1
      fi
      printf '%s\n' "$out" | grep -E "$RESULT_RE"
      return 0
    fi

    # 창 생성이 GPU 드라이버에서 죽는 경우 — 코드 문제가 아니라 이 환경의 문제다.
    # 통과로 위장하지도, 실패로 몰지도 않고 SKIPPED 로 남기고 이유를 함께 찍는다.
    # (2026-09-18: nvoglv64.dll 에서 signal 11. 같은 세션 초반에는 창이 정상이었다)
    if [ "$skip_gl" = "1" ] && printf '%s\n' "$out" | grep -qE "nvoglv|CrashHandlerException|signal 11"; then
      printf '!! %s: SKIPPED — 창 생성이 GPU 드라이버에서 죽었습니다 (이 환경에서 실행 불가)\n' "$name"
      printf '%s\n' "$out" | grep -E "CrashHandlerException|nvoglv" | head -2 | sed 's/^/    /'
      SKIPPED=$((SKIPPED + 1))
      return 0
    fi

    if [ "$attempt" -lt "$attempts" ]; then
      printf '   결과 줄이 없거나 종료 코드가 0이 아니라 한 번 더 실행합니다 (창 생성 경합일 수 있음)\n'
      attempt=$((attempt + 1))
      continue
    fi

    if [ "$has_result" = "0" ]; then
      # 결과 줄을 못 찾았다 = 이 테스트가 실제로 돌았는지 알 수 없다.
      # 예전에는 여기서 '결과를 찾지 못했습니다' 한 줄만 찍어서 원인을 알 수 없었다.
      # 이제 원본 출력의 꼬리를 남긴다.
      printf '!! %s: 결과를 찾지 못했습니다 — 원본 출력 마지막 25줄:\n' "$name"
      printf '%s\n' "$out" | tail -25 | sed 's/^/    /'
    else
      printf '!! %s: 결과 줄은 나왔지만 종료 코드가 %s 입니다 — 실패로 처리합니다\n' "$name" "$rc"
      printf '%s\n' "$out" | grep -E "✗|위반|FAIL|실패" | head -10 | sed 's/^/    /'
    fi
    printf '%s\n' "$out" | grep -E "SCRIPT ERROR|Parse Error" | head -3
    return 1
  done
}

for t in test_tower_traits test_wave_balance test_word_expansion early_wave_playtest; do
  run "$t" --headless --path . "res://tests/$t.tscn" || FAILED=1
done

run test_belt_drag_drop --retry --skip-on-gl-crash --path . res://tests/test_belt_drag_drop.tscn || FAILED=1
run AutoPlayTDTest --headless --path . res://scenes/tower/AutoPlayTDTest.tscn || FAILED=1

# ── 판정형 프로브 (tools/) ──────────────────────────────────────────────
# `tests/` 스위트와 달리 tools/ 의 프로브는 **오랫동안 등록되지 않아** 아무도 안 돌렸다.
# 그 대가: "고침이 프로브를 깨뜨려도" 스위트는 초록이었다. 2026-10-01~03 에 실제로
# 셋(§2.22·§2.23·§2.16)과 §2.2→BossDeathProbe 가 그렇게 **미검출**됐다.
#
# ⚠️ 여기 넣지 않는 것 (넣으면 스위트가 거짓말하거나 못 돈다):
#   · **창 전용 3** — `FrameStrip` · `Shot` · `TraitImpactProbe`. 헤드리스에서
#     `RenderingServer.frame_post_draw` 가 오지 않아 **RC=124 로 멈춘다**. 판정이 아니라
#     환경 문제다(각 파일 헤더가 스스로 그렇게 적고 있다).
#   · **플레이테스트 2** — `DifficultyPlaytest` · `EconomyPlaytest`. RC 가 단언이 아니라
#     **봇의 승패**다(`quit(0 if victory else 1)`). 여기 넣으면 스위트가 동전 던지기가 된다.
#     (`DifficultyPlaytest` 는 TEST_SLOW 게이트로 이미 따로 돈다 — 아래.)
#   · **보고 전용 7** — `BeltTextWidth` · `EconomyProbe` · `HintValueProbe` · `MeaningAudit` ·
#     `OrbitBalanceProbe` · `Probe` · `TargetingProbe`. `quit(0)` 뿐이라 **실패할 수 없다**
#     (등록해도 아무것도 안 잡는다).
#   · **`SyncTestScene`** — 프로브가 아니라 **빌드 도구**다(`AutoPlayTDTest.tscn` 을 재생성).
#     본편 씬을 바꿨으면 스위트보다 **먼저** 이걸 돌려야 한다.
#
# 판정은 러너 규칙 그대로 — **rc==0 이고 `*_PROBE_OK` 마커가 찍혔고 SCRIPT/Parse Error 가 없을 때**만 통과.
PROBES="
ActClearModalProbe AttackProbe AttrDescReachProbe BannerLayoutProbe BaseHitSignalProbe
BeltBlockReasonProbe BossDeathProbe BossEntranceProbe BossWeaknessProbe BotClaimProbe
CelebrationProbe ControlSplashProbe CountdownDedupProbe CounterThresholdProbe CritSignalProbe
DiceVisibilityProbe FixInvariantProbe
FlashProbe GameOverProbe LowHpWarningProbe OrphanSoundProbe PauseAbilityProbe
RerollSoundProbe RewardFlightProbe SaveSchemaProbe SfxStackProbe ShakeCoherenceProbe
ShieldSignalProbe ShopReasonProbe SwapNoOpProbe TelegraphOptionMeasure TelegraphTextWidth
TilePressProbe TooltipAuthorProbe TooltipTruthProbe TowerRebuildProbe TraitBlastProbe
TraitCounterTruthProbe WordShapeProbe
"
for p in $PROBES; do
  TEST_TIMEOUT=120 run "$p" --headless --path . "res://tools/$p.tscn" || FAILED=1
done

# 난이도 게이트 (느림 — 기본 3회, 약 6분). 기본은 꺼져 있고 TEST_SLOW=1 로 켠다.
#   TEST_SLOW=1 bash tests/run_all.sh
#
# ⚠️ **한 회차의 RC 는 판정이 아니다.** 같은 시드 7회가 남은 HP 60~120% 로 흩어졌고
#    그 흩어짐이 문턱(75%)을 넘나들었다(위반 6 · 통과 1). 그래서 도구가 `runs` 회차를
#    돌려 **중앙값**으로 판정한다. 1회 ≈2분이라 3회 ≈6분 — 기본 타임아웃(240초)으로는
#    잘리므로 여기서 늘려 준다.
#    ⚠️ 900 이 아니라 **1200** 인 이유: 도구 자체의 회차당 상한이 `TIMEOUT_MS`(300초)라
#       3회가 모두 그 상한에 닿으면 900초에 닿는다. 그러면 러너의 timeout 이 먼저 걸려
#       **RC=124** 가 되고, 그건 "무한 대기 — 파싱 에러를 의심할 것" 이라는 **거짓 진단**을 낸다.
#
# ⚠️ **이 게이트의 RC 는 '회귀' 가 아니다.** 2026-10-03 실측: 같은 코드로 5회를 돌려도
#    *"96% 로 클리어"* 와 *"40R 에서 전멸"* 이 **같은 표본 안에서** 나왔다(난이도 분산은
#    곡선이 아니라 **뽑기**가 지배한다 — docs/design/05 §7.6). 즉 3회 표본의 합/불은
#    동전 던지기에 가깝다. **빨개지면 "회귀" 가 아니라 "분포를 보라" 로 읽어라** —
#    실패 메시지의 도달 라운드·남은 HP 분포를 먼저 확인할 것.
# 이게 없으면 '60라운드 전체를 자명하게 만드는' 변경도 위의 스위트를 그대로 통과한다.
# 2026-09-18 에 실제로 그렇게 난이도가 뒤집혔다 (봇 3막 5R 사망 → 60라운드 완주).
#
# 인자는 `이름=값` 형태여야 한다. 대시를 붙이면(_read_int_arg 는 이제 흡수하지만)
# 다른 도구와 헷갈리기 쉬우니 여기서는 대시 없이 쓴다.
# buffer=0 이 중요하다 — 봇이 골드를 쥐고 있으면 '난이도' 가 아니라 '봇의 경제 정책' 을 잰다.
if [ "${TEST_SLOW:-0}" != "0" ]; then
  TEST_TIMEOUT=1200 run DifficultyGate --headless --path . res://tools/DifficultyPlaytest.tscn \
    -- gate=1 buffer=0 runs=3 || FAILED=1
fi

echo "=== done ==="
if [ "$SKIPPED" != "0" ]; then
  echo "   (건너뜀 $SKIPPED개 — 위의 SKIPPED 줄에 이유가 있습니다)"
fi
if [ "$FAILED" != "0" ]; then
  echo "!! 일부 테스트가 실패했습니다 (위의 !! 줄을 확인하세요)"
  exit 1
fi
exit 0
