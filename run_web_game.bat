@echo off
cd /d "%~dp0"
echo [Word Card] Godot Web Game http://127.0.0.1:5175/
start "" "http://127.0.0.1:5175/"
node tools\web-game-server.mjs
