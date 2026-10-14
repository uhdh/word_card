@echo off
set "VK_LOADER_LAYERS_DISABLE=*"
echo [Word Card] Starting Hangul Tower Defense (OpenGL3 Compatibility)...
start "" "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" --path "%~dp0godot" --rendering-driver opengl3
