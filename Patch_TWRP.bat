@echo off
chcp 65001 >nul

REM ## 경로 정의
set "Input_DIR=%~dp0Input_TWRP"
set "Output_DIR=%~dp0Output_TWRP"
set "Temp_DIR=%~dp0Temp"
set "Resources_DIR=%~dp0Resources"
set "AIK_DIR=%~dp0Binary\AIK_Win32"
set "TWRP_Type=IMG"

REM ## 폴더 생성 (존재하지 않으면)
if not exist "%Input_DIR%" mkdir "%Input_DIR%"
if not exist "%Output_DIR%" mkdir "%Output_DIR%"

set FOUND=0
for %%f in ("%Input_DIR%\*.img" "%Input_DIR%\*.tar") do (
if exist "%%f" set FOUND=1)

REM ## TWRP 파일 존재 확인
if "%FOUND%"=="0" (
    echo [오류] Input_TWRP 폴더에 TWRP 파일이 존재하지 않습니다. TWRP 파일 삽입 후 다시 실행해주세요.
    pause
    exit /b
)

if not exist "%Temp_DIR%" mkdir "%Temp_DIR%"

REM ## .tar 파일 처리
for %%f in ("%Input_DIR%\*.tar") do (
    if exist "%%f" (
        set "TWRP_Type=TAR"
        set "Original_TAR_Name=%%~nf"
        echo [정보] 감지된 TWRP 파일: %%~nxf
        tar -xf "%%f" -C "%Input_DIR%"

        if exist "%INPUT_DIR%\vbmeta.img" (
            echo [작업] vbmeta.img를 감지했습니다. 임시 폴더로 이동합니다.
            move /y "%INPUT_DIR%\vbmeta.img" "%Temp_DIR%"
        )
    )
)

REM ## .img 파일 처리
for %%f in ("%INPUT_DIR%\*.img") do (
    if exist "%%f" (
        set "Original_IMG_Name=%%~nf"
        echo [정보] 감지된 TWRP 이미지 파일: %%~nxf
        move /y "%%f" "%AIK_DIR%"
        echo [작업] TWRP 이미지를 AIK 폴더로 이동했습니다.
    )
)

REM ## AIK unpackimg.bat 실행
echo [작업] TWRP 이미지 파일을 압축 해제합니다...
pushd "%AIK_DIR%"
call unpackimg.bat >nul 2>&1
popd

cd /d "%~dp0"
echo [작업] TWRP 이미지 파일을 성공적으로 압축 해제했습니다.

REM ## 리소스 병합
echo [작업] 리소스 파일을 병합합니다...

if not exist "%AIK_DIR%\ramdisk\twres\" (
    echo [오류] 이미지 파일이 TWRP 파일이 아닌 것 같습니다.
    pause
    exit /b
) else (
    xcopy "%Resources_DIR%\*" "%AIK_DIR%\ramdisk\twres\" /E /H /C /I /Y >nul
    echo [작업] 리소스 파일을 병합했습니다.
)

REM ## AIK repackimg.bat 실행
echo [작업] TWRP 이미지 파일을 다시 압축합니다...
pushd "%AIK_DIR%"
call repackimg.bat >nul 2>&1
popd
echo [작업] TWRP 이미지 파일을 다시 압축했습니다.
if "%TWRP_Type%"=="TAR" (
move /y "%AIK_DIR%\image-new.img" "%Temp_DIR%\recovery.img"
) else (
move /y "%AIK_DIR%\image-new.img" "%Output_DIR%\%Original_IMG_Name%_Korean.img"
)

REM ## .tar 파일로 압축 (.tar일 때에만)
if "%TWRP_Type%"=="TAR" (
    echo [작업] TWRP 파일을 .tar 파일로 다시 압축합니다...

    cd /d "%Temp_DIR%"

    set "Output_TAR=%~dp0%Original_TAR_Name%_Korean.tar"
    if exist "%Temp_DIR%\vbmeta.img" (
        tar -cf "%Output_TAR%" recovery.img vbmeta.img
    ) else (
        tar -cf "%Output_TAR%" recovery.img
    )
    cd /d "%~dp0"
    echo [작업] TWRP 파일을 .tar 파일로 다시 압축했습니다.
)

REM ## Cleanup 코드
if "%TWRP_Type%"=="TAR" move /y "%Output_TAR%" "%Output_DIR%"

echo [작업] 정리를 시작합니다...
del /q "%AIK_DIR%\*.img"

pushd "%AIK_DIR%"
call cleanup.bat >nul 2>&1
popd

rmdir /s /q "%Temp_DIR%"
echo [작업] 정리를 완료했습니다.

echo ***********************
echo [완료] 생성된 TWRP 파일:
if "%TWRP_Type%"=="TAR" (
    echo %Output_TAR%
) else (
    echo %Output_DIR%\%Original_IMG_Name%_Korean.img
)

echo.
echo 아무 키를 눌러 종료하십시오...
pause >nul