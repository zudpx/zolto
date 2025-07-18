@echo off
:: ZOLTO Installer - Proper Npcap Detection
:: Correctly checks for existing Npcap installation

:: Set working directory to script location
pushd "%~dp0"

:: Check for admin rights
NET FILE > NUL 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process -FilePath '%~dpnx0' -Verb RunAs"
    exit /b
)

:: Set console title
title ZOLTO Installer

:: Configuration
set PYTHON_VERSION=3.10.11
set PYTHON_URL=https://www.python.org/ftp/python/%PYTHON_VERSION%/python-%PYTHON_VERSION%-amd64.exe
set PYTHON_INSTALLER=python_installer.exe
set NPCAP_URL=https://npcap.com/dist/npcap-1.82.exe
set NPCAP_INSTALLER=npcap-setup.exe

:: Initialize colors
for /F %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"
set "COLOR_RED=%ESC%[91m"
set "COLOR_GREEN=%ESC%[92m"
set "COLOR_YELLOW=%ESC%[93m"
set "COLOR_BLUE=%ESC%[94m"
set "COLOR_RESET=%ESC%[0m"

:: Main installation
call :main
popd
exit /b

:main
    cls
    echo %COLOR_BLUE%=== ZOLTO INSTALLATION ===%COLOR_RESET%
    echo.
    echo %COLOR_YELLOW%This will install:%COLOR_RESET%
    echo - Python %PYTHON_VERSION%
    echo - All Python dependencies
    echo - Npcap (if not detected)
    echo.
    echo %COLOR_YELLOW%Installation directory:%COLOR_RESET% %CD%
    echo.
    pause
    
    call :install_python
    if %ERRORLEVEL% NEQ 0 exit /b 1
    
    call :install_dependencies
    if %ERRORLEVEL% NEQ 0 (
        call :create_requirements_file
        call :install_dependencies || (
            echo %COLOR_RED%Critical error: Failed to install Python packages%COLOR_RESET%
            pause
            exit /b 1
        )
    )
    
    call :check_npcap
    call :cleanup_files
    
    echo.
    echo %COLOR_GREEN%=== INSTALLATION COMPLETE ===%COLOR_RESET%
    echo.
    pause
    exit /b 0

:install_python
    echo %COLOR_YELLOW%[1/3] Checking Python %PYTHON_VERSION%...%COLOR_RESET%
    
    where python >nul 2>&1 && (
        python --version | find "%PYTHON_VERSION%" >nul 2>&1 && (
            echo %COLOR_GREEN%Python %PYTHON_VERSION% already installed%COLOR_RESET%
            goto :eof
        )
    )
    
    echo %COLOR_YELLOW%Downloading Python...%COLOR_RESET%
    powershell -Command "(New-Object Net.WebClient).DownloadFile('%PYTHON_URL%', '%PYTHON_INSTALLER%')" || (
        echo %COLOR_RED%Download failed! Check internet connection%COLOR_RESET%
        exit /b 1
    )
    
    echo %COLOR_YELLOW%Installing Python...%COLOR_RESET%
    start /wait "" "%PYTHON_INSTALLER%" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
    del "%PYTHON_INSTALLER%" 2>nul
    
    where python >nul 2>&1 || (
        echo %COLOR_RED%Python installation failed%COLOR_RESET%
        exit /b 1
    )
    
    echo %COLOR_GREEN%Python installed successfully%COLOR_RESET%
    exit /b 0

:install_dependencies
    echo %COLOR_YELLOW%[2/3] Installing Python packages...%COLOR_RESET%
    
    if not exist "requirements.txt" (
        echo %COLOR_RED%requirements.txt not found%COLOR_RESET%
        exit /b 1
    )
    
    pip install --upgrade pip >nul 2>&1 || (
        echo %COLOR_RED%Failed to upgrade pip%COLOR_RESET%
        exit /b 1
    )
    
    pip install -r requirements.txt >nul 2>&1 || (
        echo %COLOR_RED%Package installation failed%COLOR_RESET%
        exit /b 1
    )
    
    echo %COLOR_GREEN%All packages installed successfully%COLOR_RESET%
    exit /b 0

:create_requirements_file
    echo %COLOR_YELLOW%Creating default requirements.txt...%COLOR_RESET%
    (
        echo PyQt5
        echo psutil
        echo keyboard
        echo requests
        echo paramiko
        echo scapy
        echo inputs
        echo pygame
    ) > requirements.txt
    exit /b 0

:check_npcap
    echo %COLOR_YELLOW%[3/3] Checking Npcap installation...%COLOR_RESET%
    
    :: More thorough Npcap detection
    reg query "HKLM\SOFTWARE\Npcap" >nul 2>&1 && (
        echo %COLOR_GREEN%Npcap is already installed - skipping download%COLOR_RESET%
        goto :eof
    )
    
    :: Additional check for Npcap in Program Files
    if exist "%ProgramFiles%\Npcap\*" (
        echo %COLOR_GREEN%Npcap found in Program Files - skipping download%COLOR_RESET%
        goto :eof
    )
    
    :: If we get here, Npcap isn't installed
    call :download_npcap
    call :npcap_instructions
    exit /b 0

:download_npcap
    if exist "%NPCAP_INSTALLER%" (
        echo %COLOR_GREEN%Npcap installer already downloaded%COLOR_RESET%
        goto :eof
    )
    
    echo %COLOR_YELLOW%Downloading Npcap installer...%COLOR_RESET%
    powershell -Command "(New-Object Net.WebClient).DownloadFile('%NPCAP_URL%', '%NPCAP_INSTALLER%')" || (
        echo %COLOR_RED%Failed to download Npcap installer%COLOR_RESET%
        exit /b 1
    )
    
    echo %COLOR_GREEN%Npcap installer downloaded successfully%COLOR_RESET%
    echo File saved as: %NPCAP_INSTALLER%
    exit /b 0

:npcap_instructions
    echo.
    echo %COLOR_BLUE%=== Npcap Installation Required ===%COLOR_RESET%
    echo.
    echo %COLOR_YELLOW%To complete installation:%COLOR_RESET%
    echo 1. Locate: %COLOR_YELLOW%%NPCAP_INSTALLER%%COLOR_RESET%
    echo 2. Right-click and select "Run as administrator"
    echo 3. Follow these steps:
    echo    - Click %COLOR_YELLOW%"I Agree"%COLOR_RESET% to license
    echo    - CHECK these options:
    echo      %COLOR_YELLOW%☑ Support raw 802.11 traffic%COLOR_RESET%
    echo      %COLOR_YELLOW%☑ Install in WinPcap API-compatible Mode%COLOR_RESET%
    echo    - Click %COLOR_YELLOW%"Install"%COLOR_RESET%
    echo    - Click %COLOR_YELLOW%"Finish"%COLOR_RESET% when done
    echo.
    echo %COLOR_YELLOW%Note:%COLOR_RESET% Restart your computer after installation
    echo.
    exit /b 0

:cleanup_files
    echo %COLOR_YELLOW%Cleaning up installation files...%COLOR_RESET%
    
    :: Keep these essential files
    set KEEP_FILES=zolto.exe InstallZOLTO.bat commands.txt requirements.txt
    
    :: Only keep Npcap installer if Npcap isn't installed
    reg query "HKLM\SOFTWARE\Npcap" >nul 2>&1 || (
        if exist "%NPCAP_INSTALLER%" set KEEP_FILES=%KEEP_FILES% %NPCAP_INSTALLER%
    )
    
    :: Delete all other files in directory
    for %%F in (*) do (
        set "DELETE_FILE=1"
        for %%K in (%KEEP_FILES%) do (
            if /i "%%~nxF"=="%%~nxK" set "DELETE_FILE=0"
        )
        if !DELETE_FILE!==1 (
            del /q "%%F" 2>nul
        )
    )
    
    :: Delete all other folders in directory
    for /D %%D in (*) do (
        rd /s /q "%%D" 2>nul
    )
    
    echo %COLOR_GREEN%Cleanup complete. Only essential files remain.%COLOR_RESET%
    exit /b 0