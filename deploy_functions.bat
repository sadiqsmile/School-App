@echo off
REM Firebase Cloud Functions Deployment Script

echo ========================================
echo Firebase Cloud Functions Setup
echo ========================================
echo.

echo [Step 1] Installing dependencies...
cd functions
call npm install
if errorlevel 1 (
    echo ERROR: npm install failed
    pause
    exit /b 1
)
echo.

cd ..

echo [Step 2] Ready to deploy!
echo.
echo Choose an option:
echo   1. Deploy all functions
echo   2. Deploy only auto-lock function
echo   3. Test in emulator
echo   4. View logs
echo.

set /p choice="Enter choice (1-4): "

if "%choice%"=="1" (
    echo Deploying all functions...
    call firebase deploy --only functions
)
if "%choice%"=="2" (
    echo Deploying auto-lock function...
    call firebase deploy --only functions:autoLockAttendance
)
if "%choice%"=="3" (
    echo Starting emulator...
    cd functions
    call npm run serve
)
if "%choice%"=="4" (
    echo Fetching logs...
    call firebase functions:log
)

echo.
echo ========================================
echo Done!
echo ========================================
pause
