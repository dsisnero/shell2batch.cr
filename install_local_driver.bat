@echo off

REM Change to the script's directory
cd /d %~dp0

REM Read the first line of CLI_VERSION into a variable
set /p CLI_VERSION=<CLI_VERSION
set FILE_PREFIX=playwright-cli-%CLI_VERSION%

REM Check if the driver directory exists
if exist driver (
    echo %cd%\driver already exists, delete it first
    exit /b 1
)

REM Determine the platform
set PLATFORM=unknown
for /f "tokens=*" %%i in ('uname') do set UNAME=%%i
if "%UNAME%"=="Darwin" (
    set PLATFORM=mac
    echo Downloading driver for macOS
) else if "%UNAME%"=="Linux" (
    set PLATFORM=linux
    echo Downloading driver for Linux
) else if "%UNAME%"=="MINGW32" (
    set PLATFORM=win32
    echo Downloading driver for Win32
) else if "%UNAME%"=="MINGW64" (
    set PLATFORM=win32_x64
    echo Downloading driver for Win64
) else (
    echo Unknown platform '%UNAME%'
    exit /b 1
)

REM Create the driver directory and change to it
mkdir driver
cd driver

REM Function to download a file using bitsadmin
:download
setlocal
set URL=%1
set OUTPUT=%2
bitsadmin /transfer myDownloadJob /download /priority normal %URL% %OUTPUT%
endlocal
goto :eof

REM Download and unzip the driver
set FILE_NAME=%FILE_PREFIX%-%PLATFORM%.zip
echo Downloading driver for %PLATFORM% to %cd%
call :download https://playwright.azureedge.net/builds/cli/next/%FILE_NAME% %FILE_NAME%
unzip %FILE_NAME% -d .
del %FILE_NAME%
echo Installing browsers for %PLATFORM%
playwright-cli install
