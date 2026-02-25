@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: SimLoadManager - Build & Deploy
:: ============================================================
:: CONFIGURATION - Modifier cette variable selon votre installation
:: ============================================================
set XPLANE_SCRIPTS=C:\X-Plane 12\Resources\plugins\FlyWithLua\Scripts
:: ============================================================

set SRC=%~dp0src
set DIST=%~dp0dist
set ERRORS=0

echo.
echo ====================================================
echo  SimLoadManager - Build ^& Deploy
echo ====================================================
echo  Source  : %SRC%
echo  Output  : %DIST%
echo  XPlane  : %XPLANE_SCRIPTS%
echo ====================================================
echo.

:: -- Verifier que luajit est disponible
where luajit >nul 2>&1
if errorlevel 1 (
    echo [ERREUR] luajit introuvable dans le PATH.
    echo          Installez LuaJIT et ajoutez-le au PATH Windows.
    echo          Voir README_BUILD.md pour les instructions.
    exit /b 1
)

:: -- Verifier que le dossier source existe
if not exist "%SRC%" (
    echo [ERREUR] Dossier src\ introuvable : %SRC%
    exit /b 1
)

:: -- Creer dist/ si absent
if not exist "%DIST%" mkdir "%DIST%"

:: -- Compiler chaque fichier .lua de src/
echo Compilation...
echo.
for %%f in ("%SRC%\*.lua") do (
    set FNAME=%%~nxf
    luajit -b "%%f" "%DIST%\!FNAME!" 2>&1
    if errorlevel 1 (
        echo [ECHEC]  !FNAME!
        set ERRORS=1
    ) else (
        echo [OK]     !FNAME! -^> dist\!FNAME!
    )
)

if !ERRORS! == 1 (
    echo.
    echo [ERREUR] Compilation echouee. Correction requise avant le deploiement.
    exit /b 1
)

:: -- Verifier que le dossier X-Plane est accessible
if not exist "%XPLANE_SCRIPTS%" (
    echo.
    echo [AVERT.] Dossier X-Plane introuvable : %XPLANE_SCRIPTS%
    echo          Verifiez la variable XPLANE_SCRIPTS dans build.bat
    echo          Les fichiers compiles sont disponibles dans dist\
    exit /b 0
)

:: -- Copier vers X-Plane
echo.
echo Deploiement vers X-Plane...
echo.
for %%f in ("%DIST%\*.lua") do (
    set FNAME=%%~nxf
    copy /y "%%f" "%XPLANE_SCRIPTS%\!FNAME!" >nul
    if errorlevel 1 (
        echo [ECHEC]  Copie de !FNAME! vers X-Plane
        set ERRORS=1
    ) else (
        echo [OK]     !FNAME! -^> %XPLANE_SCRIPTS%\!FNAME!
    )
)

echo.
if !ERRORS! == 1 (
    echo [ERREUR] Deploiement incomplet.
    exit /b 1
) else (
    echo ====================================================
    echo  Build et deploiement termines avec succes.
    echo  Rechargez les scripts dans X-Plane :
    echo  Plugins -^> FlyWithLua -^> Reload all Lua scripts
    echo ====================================================
)
echo.
exit /b 0
