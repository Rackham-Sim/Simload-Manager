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

:: ============================================================
:: Compilation
:: ============================================================

echo Compilation...
echo.

for %%f in ("%SRC%\*.lua") do (
    set "FNAME=%%~nxf"
    "%LUAJIT_EXE%" -b "%%f" "%DIST%\!FNAME!" 2>&1
    if errorlevel 1 (
        echo [ECHEC]  !FNAME!
        set "ERRORS=1"
    ) else (
        echo [OK]     !FNAME! -^> dist\!FNAME!
    )
)

if !ERRORS! == 1 (
    echo.
    echo [ERREUR] Compilation echouee.
    pause
    exit /b 1
)

:: ============================================================
:: Deploiement
:: ============================================================
if not exist "%XPLANE_SCRIPTS%" (
    echo.
    echo [AVERT.] Dossier X-Plane introuvable : %XPLANE_SCRIPTS%
    echo          Les fichiers compiles sont disponibles dans dist\
    pause
    exit /b 0
)
echo.
echo Deploiement vers X-Plane...
echo.

:: -- Copie des scripts .lua
for %%f in ("%DIST%\*.lua") do (
    set "FNAME=%%~nxf"
    copy /y "%%f" "%XPLANE_SCRIPTS%\!FNAME!" >nul
    if errorlevel 1 (
        echo [ECHEC]  Copie de !FNAME!
        set "ERRORS=1"
    ) else (
        echo [OK]     !FNAME! deploye
    )
)

:: -- Copie du dossier audio
set "SOUNDS_SRC=%DIST%\SimLoad-Manager-Sounds"
set "SOUNDS_DST=%XPLANE_SCRIPTS%\SimLoad-Manager-Sounds"
if exist "%SOUNDS_SRC%" (
    xcopy /e /i /y "%SOUNDS_SRC%" "%SOUNDS_DST%" >nul
    if errorlevel 1 (
        echo [ECHEC]  Copie du dossier audio
        set "ERRORS=1"
    ) else (
        echo [OK]     SimLoad-Manager-Sounds deploye
    )
) else (
    echo [AVERT.] Dossier audio introuvable dans dist\, ignore.
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