#!/usr/bin/env bash
# GPU / 그래픽 드라이버 상태 점검.
#
# 목적: "게임이 안 켜진다" 를 **프로젝트 문제** 와 **PC(드라이버) 문제** 로 가른다.
#   2026-09-18 19:44 부터 이 PC 에서 창을 띄우는 Godot 은 전부 nvoglv64.dll 안에서
#   세그폴트(0xc0000005)로 죽었다. 프로젝트를 전혀 쓰지 않는 **프로젝트 매니저** 조차
#   죽었기 때문에 프로젝트가 원인이 아니라는 것이 바로 증명됐다. 그 판별을 자동화한다.
#
# 사용법:
#   bash tools/check_gpu.sh
#   GODOT=/path/to/godot bash tools/check_gpu.sh
#
# 종료 코드: 0 = 창 생성 가능, 2 = GPU 드라이버 문제, 1 = 그 밖의 실패
set -u

GODOT="${GODOT:-godot}"
TIMEOUT_SEC="${GPU_CHECK_TIMEOUT:-25}"
TMP="${TMPDIR:-/tmp}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

DRIVER_CRASHES=0
PM_CRASHES=0
OK_COUNT=0
OTHER_FAILS=0
PHASE="pm"

# check <작업디렉터리> <라벨> <godot 인자...>
#
# --quit 을 붙여 창을 만든 직후 스스로 끝나게 한다. 창이 만들어지지 못하면
# 크래시(exit 139)하거나 timeout(124) 으로 끝난다.
#
# 주의 1: cd 와 실행을 **서브셸 안에서** 한다. 서브셸로 감싸면 bash 가 찍는
#   "Segmentation fault" 줄도 로그로 들어가서 출력이 깨끗해진다.
# 주의 2: 이 함수를 `( check ... )` 처럼 서브셸로 부르면 안 된다. 그러면
#   DRIVER_CRASHES 증가가 사라져서 판정이 조용히 틀린다 (실제로 그렇게 만들었다가 겪음).
# 주의 3: --path 에 Git Bash 경로(/e/...)를 넘기면 Godot 이 못 읽는다.
#   반드시 그 디렉터리로 cd 한 뒤 `--path .` 을 쓴다.
check() {
  local dir="$1"; local label="$2"; shift 2
  local log="$TMP/gpucheck_${label}.log"

  ( cd "$dir" && timeout "$TIMEOUT_SEC" "$GODOT" "$@" --quit ) > "$log" 2>&1
  local rc=$?

  if [ "$rc" = "0" ]; then
    printf '  [OK]    %-22s 창 생성 성공\n' "$label"
    OK_COUNT=$((OK_COUNT + 1))
    return 0
  fi

  # 종료 코드 128 이상 = 시그널로 죽었다 (139 = SIGSEGV).
  # **종료 코드를 1차 신호로 쓴다.** 크래시 로그가 잘려서 CrashHandler 백트레이스가
  # 안 남는 경우가 실제로 있었다 (1줄만 남아 크래시를 [FAIL] 로 오분류했다).
  local crashed=0
  if [ "$rc" -ge 128 ] 2>/dev/null; then crashed=1; fi
  if grep -qE "CrashHandlerException|signal 11|nvoglv|amdxx|atio6axx|ig[0-9]+icd" "$log"; then
    crashed=1
  fi

  if [ "$crashed" = "1" ]; then
    local mod
    mod="$(grep -oE '(nvoglv64|nvoglv32|amdxx64|atio6axx|ig[0-9]+icd64|vulkan-1)\.dll' "$log" | head -1)"
    if [ -n "$mod" ]; then
      printf '  [CRASH] %-22s GPU 드라이버 크래시 (%s, exit %s)\n' "$label" "$mod" "$rc"
    else
      printf '  [CRASH] %-22s 시그널 크래시 (exit %s) — 드라이버 의심\n' "$label" "$rc"
    fi
    DRIVER_CRASHES=$((DRIVER_CRASHES + 1))
    # 프로젝트를 쓰지 않는 실행에서 죽었다면 프로젝트 코드는 원인이 될 수 없다.
    if [ "$PHASE" = "pm" ]; then PM_CRASHES=$((PM_CRASHES + 1)); fi
    return 2
  fi

  printf '  [FAIL]  %-22s exit %s\n' "$label" "$rc"
  grep -m1 -E "ERROR:" "$log" | sed 's/^/          /'
  OTHER_FAILS=$((OTHER_FAILS + 1))
  return 1
}

# 자식이 시그널로 죽으면 bash 가 "Segmentation fault" 를 **자기 stderr 로** 찍는다.
# (timeout 이 자식의 SIGSEGV 를 자기 자신에게 다시 올리기 때문이다.)
# 그 줄이 진단 출력을 어지럽히므로 이 그룹 안에서만 stderr 를 막는다.
# 함수 본문은 현재 셸에서 돌기 때문에 DRIVER_CRASHES 증가는 그대로 살아 있다.
quiet_check() { { check "$@"; } 2>/dev/null; }

echo "Godot: $(command -v "$GODOT" 2>/dev/null || echo "$GODOT")"
echo
echo "--- 1) 프로젝트를 쓰지 않는 Godot (프로젝트 매니저) ---"
echo "    여기서 죽으면 프로젝트 코드는 원인이 아니다."
quiet_check "$TMP" pm_opengl3 --rendering-driver opengl3
quiet_check "$TMP" pm_d3d12   --rendering-driver d3d12 --rendering-method forward_plus
quiet_check "$TMP" pm_vulkan  --rendering-driver vulkan --rendering-method forward_plus

echo
echo "--- 2) 이 프로젝트 ---"
PHASE="project"
quiet_check "$ROOT" project_opengl3 --path . --rendering-driver opengl3

echo
echo "--- 3) 헤드리스 (창이 필요 없는 경로) ---"
PHASE="headless"
quiet_check "$ROOT" headless --headless --path .

echo
echo "=== 판정 ==="
# **프로젝트를 쓰지 않는** 실행(프로젝트 매니저)이 죽으면, 프로젝트 코드는 원인이 될 수 없다.
# 이게 이 스크립트의 존재 이유다. 개수는 심각도 설명용일 뿐이다.
if [ "$PM_CRASHES" -ge 1 ]; then
  echo "  ✗ 프로젝트를 쓰지 않는 Godot 까지 죽었다 ($PM_CRASHES/3). **프로젝트 문제가 아니다.**"
  echo "    → 재부팅한다. 이게 유일하게 확실한 해결책이다."
  echo "      (드라이버에 걸린 Godot 프로세스는 스레드 0개 / 핸들 0개로 남고,"
  echo "       관리자 권한으로도 종료가 거부된다. 2026-09-19 실측)"
  echo "    → 재부팅 후에도 같으면 NVIDIA 드라이버를 재설치한다."
  echo "    → 프로세스 정리와 어댑터 재시작을 자동으로 해보려면 fix_godot.bat 을"
  echo "       '관리자 권한으로 실행' 한다."
  echo "    로그: $TMP/gpucheck_*.log"
  exit 2
fi

if [ "$OK_COUNT" -gt 0 ]; then
  echo "  ✓ 창 생성이 가능한 경로가 있다. 위의 [OK] 줄에 있는 인자로 실행하면 된다."
  exit 0
fi

if [ "$OTHER_FAILS" -gt 0 ]; then
  echo "  ? 드라이버 크래시는 아니지만 실패가 있다. 위 로그를 확인할 것:"
  echo "    $TMP/gpucheck_*.log"
  exit 1
fi

echo "  ? 판정 불가. 위 로그를 확인할 것: $TMP/gpucheck_*.log"
exit 1
