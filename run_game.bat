@echo off
REM D3D12 + forward_plus launcher.
REM
REM project.godot sets renderer/rendering_method="gl_compatibility" (OpenGL3).
REM Passing only --rendering-driver d3d12 leaves the method at gl_compatibility,
REM which is a mismatched pair: gl_compatibility needs the opengl3 driver.
REM So both flags must be given together.
REM
REM Use this when the OpenGL path dies in nvoglv64.dll (see tools/check_gpu.sh).
set "VK_LOADER_LAYERS_DISABLE=*"
echo [Word Card] Starting Hangul Tower Defense (D3D12 + forward_plus)...
start "" "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" --path "%~dp0godot" --rendering-driver d3d12 --rendering-method forward_plus --gpu-index 0
