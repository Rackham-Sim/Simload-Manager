@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: SimLoadManager - Build & Deploy
:: ============================================================
:: CONFIGURATION
:: ============================================================
set "XPLANE_SCRIPTS=D:\X-Plane\X-Plane 12\Resources\plugins\FlyWithLua\Scripts"
set "LUAJIT_EXE=C:\Users\Etien\Documents\SITES-PLUGINS\plugins\LuaJIT-For-Windows\bin\luajit.exe"
set "LUAJIT_LUA=C:\Users\Etien\Documents\SITES-PLUGINS\plugins\LuaJIT-For-Windows\lua"
:: ============================================================

:: -- Ajouter le dossier lua au module path
set "LUA_PATH=%LUAJIT_LUA%\?.lua;%LUAJIT_LUA%\?\init.lua;;"

set "SRC=%~dp0src"
set "DIST=%~dp0dist"
set "ERRORS=0"

echo.
echo ====================================================
echo  SimLoadManager - Build ^& Deploy
echo ====================================================
echo  Source  : %SRC%
echo  Output  : %DIST%
echo  XPlane  : %XPLANE_SCRIPTS%
echo  LuaJIT  : %LUAJIT_EXE%
echo ====================================================
echo.

:: -- Verifier luajit
if not exist "%LUAJIT_EXE%" (
    echo [ERREUR] luajit introuvable : %LUAJIT_EXE%
    pause
    exit /b 1
)

:: -- Verifier src
if not exist "%SRC%" (
    echo [ERREUR] Dossier src\ introuvable : %SRC%
    pause
    exit /b 1
)

:: -- Creer dist si absent
if not exist "%DIST%" mkdir "%DIST%"
if not exist "%DIST%\SLM-Data" mkdir "%DIST%\SLM-Data"

:: ============================================================
:: Deploiement SLM-Data (avant compilation pour creer les dossiers cibles)
:: ============================================================
if not exist "%XPLANE_SCRIPTS%" (
    echo.
    echo [AVERT.] Dossier X-Plane introuvable : %XPLANE_SCRIPTS%
    echo          Les fichiers compiles sont disponibles dans dist\
    pause
    exit /b 0
)

echo Deploiement des ressources SLM-Data...
echo.

:: -- Copie du dossier audio
set "SOUNDS_SRC=%SRC%\SLM-Data\SimLoad-Manager-Sounds"
set "SOUNDS_DIST=%DIST%\SLM-Data\SimLoad-Manager-Sounds"
set "SOUNDS_DST=%XPLANE_SCRIPTS%\SLM-Data\SimLoad-Manager-Sounds"
if exist "%SOUNDS_SRC%" (
    xcopy /e /i /y "%SOUNDS_SRC%" "%SOUNDS_DIST%" >nul
    if errorlevel 1 (
        echo [ECHEC]  Copie du dossier audio vers dist\SLM-Data\
        set "ERRORS=1"
    ) else (
        echo [OK]     SimLoad-Manager-Sounds -^> dist\SLM-Data\
    )
    xcopy /e /i /y "%SOUNDS_SRC%" "%SOUNDS_DST%" >nul
    if errorlevel 1 (
        echo [ECHEC]  Copie du dossier audio vers X-Plane\SLM-Data\
        set "ERRORS=1"
    ) else (
        echo [OK]     SimLoad-Manager-Sounds -^> X-Plane\SLM-Data\
    )
) else (
    echo [AVERT.] Dossier audio introuvable dans src\SLM-Data\, ignore.
)

:: -- Copie de aircraft.json
if exist "%SRC%\SLM-Data\aircraft.json" (
    copy /y "%SRC%\SLM-Data\aircraft.json" "%DIST%\SLM-Data\aircraft.json" >nul
    if errorlevel 1 (
        echo [ECHEC]  Copie aircraft.json vers dist\SLM-Data\
        set "ERRORS=1"
    ) else (
        echo [OK]     aircraft.json -^> dist\SLM-Data\
    )
    copy /y "%SRC%\SLM-Data\aircraft.json" "%XPLANE_SCRIPTS%\SLM-Data\aircraft.json" >nul
    if errorlevel 1 (
        echo [ECHEC]  Copie aircraft.json vers X-Plane\SLM-Data\
        set "ERRORS=1"
    ) else (
        echo [OK]     aircraft.json -^> X-Plane\SLM-Data\
    )
) else (
    echo [AVERT.] aircraft.json introuvable dans src\SLM-Data\, ignore.
)

echo.

:: ============================================================
:: Compilation
:: ============================================================
echo Compilation...
echo.

for %%f in ("%SRC%\*.lua") do (
    set "FNAME=%%~nxf"
    set "TMPFILE=%DIST%\~tmp_%%~nxf"

    :: -- Version RELEASE pour dist\ (dev_mode = false)
    powershell -Command "(Get-Content '%%f') -replace 'local slm_dev_mode = (true|false)', 'local slm_dev_mode = false' | Set-Content '!TMPFILE!'"
    "%LUAJIT_EXE%" -b "!TMPFILE!" "%DIST%\!FNAME!" 2>&1
    if errorlevel 1 (
        echo [ECHEC]  !FNAME! (release^)
        set "ERRORS=1"
    ) else (
        echo [OK]     !FNAME! -^> dist\ (dev_mode=false^)
    )

    :: -- Version DEV pour X-Plane (dev_mode = true)
    powershell -Command "(Get-Content '%%f') -replace 'local slm_dev_mode = (true|false)', 'local slm_dev_mode = true' | Set-Content '!TMPFILE!'"
    "%LUAJIT_EXE%" -b "!TMPFILE!" "%XPLANE_SCRIPTS%\!FNAME!" 2>&1
    if errorlevel 1 (
        echo [ECHEC]  !FNAME! (dev^)
        set "ERRORS=1"
    ) else (
        echo [OK]     !FNAME! -^> X-Plane\ (dev_mode=true^)
    )

    del "!TMPFILE!" >nul 2>&1
)

for %%f in ("%SRC%\SLM-Data\*.lua") do (
    set "FNAME=%%~nxf"
    set "TMPFILE=%DIST%\SLM-Data\~tmp_%%~nxf"

    :: -- Version RELEASE pour dist\SLM-Data\ (dev_mode = false)
    powershell -Command "(Get-Content '%%f') -replace 'local slm_dev_mode = (true|false)', 'local slm_dev_mode = false' | Set-Content '!TMPFILE!'"
    "%LUAJIT_EXE%" -b "!TMPFILE!" "%DIST%\SLM-Data\!FNAME!" 2>&1
    if errorlevel 1 (
        echo [ECHEC]  SLM-Data\!FNAME! (release^)
        set "ERRORS=1"
    ) else (
        echo [OK]     SLM-Data\!FNAME! -^> dist\SLM-Data\ (dev_mode=false^)
    )

    :: -- Version DEV pour X-Plane (dev_mode = true)
    powershell -Command "(Get-Content '%%f') -replace 'local slm_dev_mode = (true|false)', 'local slm_dev_mode = true' | Set-Content '!TMPFILE!'"
    "%LUAJIT_EXE%" -b "!TMPFILE!" "%XPLANE_SCRIPTS%\SLM-Data\!FNAME!" 2>&1
    if errorlevel 1 (
        echo [ECHEC]  SLM-Data\!FNAME! (dev^)
        set "ERRORS=1"
    ) else (
        echo [OK]     SLM-Data\!FNAME! -^> X-Plane\SLM-Data\ (dev_mode=true^)
    )

    del "!TMPFILE!" >nul 2>&1
)

if !ERRORS! == 1 (
    echo.
    echo [ERREUR] Compilation echouee.
    pause
    exit /b 1
)

echo.
if !ERRORS! == 1 (
    echo [ERREUR] Deploiement incomplet.
) else (
    echo ====================================================
    echo  Build et deploiement termines avec succes.
    echo  Plugins -^> FlyWithLua -^> Reload all Lua scripts
    echo ====================================================
)

echo.
pause
exit /b 0