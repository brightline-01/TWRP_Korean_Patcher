@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

set BASEDIR=%~dp0
set INPUT_DIR=%BASEDIR%input_twrp_tar
set WORKSPACE=%BASEDIR%workspace
set "TWRP_TAR="
set TWRES=%WORKSPACE%\ramdisk\twres
set RES=%BASEDIR%RES
set "OUTPUT=%BASEDIR%output"
set "ORIG_TAR="
set "OUT_TAR="

for %%Z in ("%INPUT_DIR%\*.tar") do (
    set "TWRP_TAR=%%~fZ"
    set "ORIG_TAR_NAME=%%~nZ"
    set "ORIG_TAR_EXT=%%~xZ"
    goto :found_tar
)

echo [경고] input_twrp_tar 폴더에 TWRP tar 파일을 넣어주세요.
exit /b 0

:found_tar
echo 감지된 TWRP tar 파일:
echo !TWRP_TAR!

echo [알림] TWRP 압축 해제 중...
tar -xf "!TWRP_TAR!" -C "%INPUT_DIR%"

if errorlevel 1 (
    echo [오류] TWRP의 압축을 해제하는 중 오류가 발생했습니다.
    pause
    exit /b 1
)

if not exist "%INPUT_DIR%\recovery.img" (
    echo [오류] recovery.img를 찾을 수 없습니다.
    pause
    exit /b 1
)

echo [알림] TWRP를 성공적으로 압축 해제했습니다.

move /Y "%INPUT_DIR%\recovery.img" "%WORKSPACE%\recovery.img" >nul

if errorlevel 1 (
    echo [오류] recovery.img를 이동하는 중 오류가 발생했습니다.
    pause
    exit /b 1
)

echo [알림] recovery.img를 workspace 폴더로 이동합니다...

echo [알림] recovery.img를 압축 해제합니다...
call "%WORKSPACE%\unpack_twrp.bat" >nul 2>&1

echo [알림] 폰트 패치를 적용합니다...
if exist "%TWRES%\fonts" (
    rd /s /q "%TWRES%\fonts"
    xcopy "%RES%\fonts" "%TWRES%\fonts\" /e /i /y
)

echo [알림] 언어 패치를 적용합니다...
if exist "%TWRES%\languages" (
    rd /s /q "%TWRES%\languages"
    xcopy "%RES%\languages" "%TWRES%\languages\" /e /i /y
)

echo [알림] recovery.img를 다시 압축합니다...
call "%WORKSPACE%\repack_twrp.bat" >nul 2>&1

if not exist "%WORKSPACE%\image-new.img" (
    echo [오류] image-new.img 생성 중 오류가 발생했습니다.
    goto end_wait
)

move /y "%WORKSPACE%\image-new.img" "%OUTPUT%\recovery.img" >nul

echo [알림] recovery.img를 성공적으로 압축했습니다.

set "TMP_DIR=%BASEDIR%_tar_tmp"
if "%TMP_DIR:~-1%"=="\" set "TMP_DIR=%TMP_DIR:~0,-1%"

if exist "%TMP_DIR%" rd /s /q "%TMP_DIR%"
mkdir "%TMP_DIR%"

copy "%OUTPUT%\recovery.img" "%TMP_DIR%\recovery.img" >nul
set "OUT_TAR=%OUTPUT%\%ORIG_TAR_NAME%_Korean%ORIG_TAR_EXT%"

echo [알림] tar로 다시 압축합니다...
tar -cf "%OUT_TAR%" -C "%TMP_DIR%" recovery.img

echo [알림] 정리 중...
rd /s /q "%TMP_DIR%"
if exist "%WORKSPACE%\recovery.img" del /f /q "%WORKSPACE%\recovery.img"
if exist "%OUTPUT%\recovery.img" del /f /q "%OUTPUT%\recovery.img"
call "%WORKSPACE%\cleanup.bat" >nul 2>&1

:end_wait
echo.
echo [알림] TWRP를 성공적으로 패치했어요.
echo 결과 파일:
echo %OUT_TAR%
echo 아무 키나 눌러 종료하세요.
pause >nul
exit /b
