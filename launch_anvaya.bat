@echo off
title Anvaya Demo Launcher

cd /d "C:\Users\memuz\anvaya_app"

:: Use port 8085 to completely bypass Chrome's cached Flutter favicon
start "" /b python -m http.server 8085 --directory "build\web"

timeout /t 1 /nobreak >nul

start chrome --app=http://localhost:8085 --window-size=430,932

exit