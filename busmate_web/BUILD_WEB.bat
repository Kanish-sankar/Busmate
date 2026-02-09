@echo off
echo ========================================
echo FLUTTER WEB BUILD TEST
echo ========================================
echo.

cd /d "C:\Users\kanis\OneDrive\Desktop\Jupenta Codes Final\jupenta-busmate\busmate_web"
echo Current directory: %CD%
echo.

echo Step 1: Checking Flutter...
flutter --version
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter not found!
    pause
    exit /b 1
)

echo.
echo Step 2: Cleaning...
call flutter clean
echo Clean done.

echo.
echo Step 3: Getting packages...
call flutter pub get
echo Pub get done.

echo.
echo Step 4: Building web (this may take 2-5 minutes)...
echo Please wait...
call flutter build web --release
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================
    echo BUILD FAILED! See errors above.
    echo ========================================
    pause
    exit /b 1
)

echo.
echo ========================================
echo BUILD SUCCEEDED!
echo Files are in: build\web
echo ========================================
pause
