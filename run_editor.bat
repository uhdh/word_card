@echo off
set "VK_LOADER_LAYERS_DISABLE=*"
echo [Word Card] Opening Godot Editor (RTX 5080)...
start "" "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" --editor --path "%~dp0godot" --rendering-driver d3d12 --rendering-method forward_plus --gpu-index 0
