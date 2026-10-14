@echo off
set "VK_LOADER_LAYERS_DISABLE=*"
"%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" --path "%~dp0godot" --rendering-driver d3d12 --rendering-method forward_plus --gpu-index 0 %*
