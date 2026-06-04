@echo off
cd /d "%~dp0"

echo === Seclore Skill — Push Update ===
echo.

git add -A

set /p msg="Commit message (or press Enter for default): "
if "%msg%"=="" set msg=Update skill content

git commit -m "%msg%"

if %errorlevel% neq 0 (
    echo.
    echo Nothing to commit or commit failed.
    pause
    exit /b 1
)

echo.
echo Pulling remote changes (rebase)...
git pull --rebase origin main

if %errorlevel% neq 0 (
    echo.
    echo Pull/rebase failed. Resolve conflicts manually, then run again.
    pause
    exit /b 1
)

echo.
echo Pushing to origin...
git push origin main

if %errorlevel% neq 0 (
    echo.
    echo Push failed. Check your remote/network.
    pause
    exit /b 1
)

echo.
echo Done — skill updates pushed.
pause
