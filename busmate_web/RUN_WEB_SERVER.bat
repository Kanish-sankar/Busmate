@echo off
echo ========================================
echo Starting Flutter Web Server Mode
echo This BYPASSES Chrome debug issues
echo ========================================
echo.
cd /d "C:\Users\kanis\OneDrive\Desktop\Jupenta Codes Final\jupenta-busmate\busmate_web"
flutter run -d web-server --web-port=8080
