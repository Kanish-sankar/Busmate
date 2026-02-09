@echo off
echo ========================================
echo EMERGENCY FIX - Kill all stuck processes
echo ========================================

echo.
echo Killing all Chrome processes...
taskkill /F /IM chrome.exe 2>nul
taskkill /F /IM chromedriver.exe 2>nul

echo.
echo Killing all Dart/Flutter processes...
taskkill /F /IM dart.exe 2>nul
taskkill /F /IM flutter.exe 2>nul

echo.
echo Cleaning Flutter cache...
cd /d "C:\Users\kanis\OneDrive\Desktop\Jupenta Codes Final\jupenta-busmate\busmate_web"
flutter clean

echo.
echo Removing build folders...
rmdir /S /Q build 2>nul
rmdir /S /Q .dart_tool 2>nul

echo.
echo Getting packages...
flutter pub get

echo.
echo ========================================
echo Now try: flutter run -d web-server
echo This will open on localhost:8080
echo ========================================
pause
