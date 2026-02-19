@echo off
echo Building Flutter web app...
call flutter build web --release

echo.
echo Deploying to Firebase...
call firebase deploy --only hosting

echo.
echo ✓ Deployment complete!
pause
