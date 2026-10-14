@echo off
setlocal
REM ============================================================================
REM  fix_godot.bat - repair helper for "Godot will not open"
REM
REM  Symptom this fixes:
REM    Every windowed Godot dies inside nvoglv64.dll (NVIDIA OpenGL driver) with
REM    exception 0xc0000005, and the dead processes stay behind at 0 threads /
REM    0 handles and refuse to be killed from a normal Task Manager.
REM
REM  Run this by RIGHT-CLICK -> "Run as administrator".
REM  If you double-click it, it will ask for elevation by itself.
REM
REM  ASCII only on purpose: a .bat with non-ASCII text can be garbled by the
REM  console codepage.
REM ============================================================================

net session >nul 2>&1
if errorlevel 1 (
  echo [elevate] Requesting administrator rights...
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  exit /b
)

echo [1/4] Administrator rights: OK
echo.

echo [2/4] Killing stuck Godot processes...
taskkill /F /IM Godot_v4.7.2-stable_win64.exe >nul 2>&1
taskkill /F /IM godot.exe >nul 2>&1
taskkill /F /IM Godot_v4.7.2-stable_win64_console.exe >nul 2>&1
timeout /t 2 /nobreak >nul

echo [3/4] Checking what is left...
set STUCK=0
for /f %%c in ('tasklist /FI "IMAGENAME eq Godot_v4.7.2-stable_win64.exe" /NH 2^>nul ^| find /C /I "Godot"') do set STUCK=%%c

if "%STUCK%"=="0" (
  echo       none - the process list is clean.
  echo       Godot should start now. Try:  run_game.bat
) else (
  echo       %STUCK% process^(es^) still present. They are wedged inside the GPU
  echo       driver, so not even an elevated kill can remove them.
  echo       ^>^> A REBOOT is required. Nothing else will clear them.
)
echo.

echo [4/4] Restart the display adapter?  (optional, and risky)
echo       This resets the GPU driver without rebooting. The screen goes black
echo       for a few seconds. Only useful if step 3 already came back clean but
echo       Godot still crashes.
echo       If in doubt, answer N and reboot instead.
set /p ANS=Type Y to restart the GPU adapter, or N to skip: 
if /I not "%ANS%"=="Y" goto :done

echo       Restarting display adapters...
powershell -NoProfile -Command "Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'OK' } | ForEach-Object { Write-Host ('  - ' + $_.FriendlyName); Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3; Enable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue }"
echo       Adapter restart finished.

:done
echo.
echo Next step: verify with
echo     bash tools/check_gpu.sh
echo Look for [OK] on the pm_opengl3 line. If it still says [CRASH], reboot.
echo.
pause
