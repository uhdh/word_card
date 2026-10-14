@echo off
cd /d "%~dp0"
echo [Word Card] 활자 도감  http://127.0.0.1:5174/lexicon.html
start "" "http://127.0.0.1:5174/lexicon.html"
node tools\lexicon-server.mjs
