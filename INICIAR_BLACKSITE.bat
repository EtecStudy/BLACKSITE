@echo off
setlocal EnableExtensions
set "PROJECT_DIR=%~dp0"

if not exist "%PROJECT_DIR%project.godot" (
    echo [BLACKSITE] ERRO: project.godot nao foi encontrado em:
    echo   %PROJECT_DIR%
    pause
    exit /b 2
)

if defined GODOT_EXE if not exist "%GODOT_EXE%" (
    echo [BLACKSITE] ERRO: GODOT_EXE aponta para um arquivo inexistente:
    echo   %GODOT_EXE%
    echo Corrija a variavel GODOT_EXE ou deixe-a vazia para procurar no PATH.
    pause
    exit /b 2
)

if not defined GODOT_EXE (
    for /f "delims=" %%I in ('where godot.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%I"
)
if not defined GODOT_EXE (
    for /f "delims=" %%I in ('where godot_console.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%I"
)
if not defined GODOT_EXE (
    echo Godot nao foi encontrado no PATH.
    echo Digite o caminho completo para Godot 4.3 ou superior.
    echo Exemplo: C:\Apps\Godot\Godot_v4.4.1-stable_win64_console.exe
    set /p "GODOT_EXE=Caminho do executavel Godot: "
)
if not defined GODOT_EXE (
    echo [BLACKSITE] ERRO: nenhum executavel Godot foi informado.
    pause
    exit /b 2
)
if not exist "%GODOT_EXE%" (
    echo [BLACKSITE] ERRO: executavel Godot nao encontrado:
    echo   %GODOT_EXE%
    pause
    exit /b 2
)

set "GODOT_VERSION="
for /f "delims=" %%V in ('"%GODOT_EXE%" --version 2^>^&1') do if not defined GODOT_VERSION set "GODOT_VERSION=%%V"
if not defined GODOT_VERSION goto MANUAL_VERSION_CHECK
echo("%GODOT_VERSION%"| findstr /i /c:"Main executable" >nul
if not errorlevel 1 goto CONSOLE_TARGET_MISSING
for /f "tokens=1,2 delims=." %%A in ("%GODOT_VERSION%") do (
    set "GODOT_MAJOR=%%A"
    set "GODOT_MINOR=%%B"
)
if not "%GODOT_MAJOR%"=="4" (
    echo [BLACKSITE] ERRO: Godot 4.3 ou superior e necessario. Detectado: %GODOT_VERSION%
    pause
    exit /b 4
)
if %GODOT_MINOR% LSS 3 (
    echo [BLACKSITE] ERRO: Godot 4.3 ou superior e necessario. Detectado: %GODOT_VERSION%
    pause
    exit /b 4
)
goto START_BLACKSITE

:CONSOLE_TARGET_MISSING
echo [BLACKSITE] Este console exe e um launcher; o Godot principal que ele requer nao esta ao lado.
echo Detalhe retornado pelo launcher: "%GODOT_VERSION%"
echo Baixe tambem o executavel Windows padrao da mesma versao e coloque-o na mesma pasta.
echo O erro do console normalmente informa o nome exato que esta faltando (ex.: Godot_v4.x-stable_win64.exe).
echo Depois execute novamente e informe o caminho do console exe.
pause
exit /b 3

:MANUAL_VERSION_CHECK
echo [BLACKSITE] O executavel nao retornou versao no console (pode ser a versao GUI).
echo Confirme manualmente que o executavel e Godot 4.3 ou superior.
set "GODOT_CONFIRM="
set /p "GODOT_CONFIRM=Digite SIM para continuar com a verificacao manual: "
if /I not "%GODOT_CONFIRM%"=="SIM" (
    echo [BLACKSITE] Inicializacao cancelada; use o executavel Godot console ou confirme a versao.
    pause
    exit /b 3
)
set "GODOT_VERSION=4.3+ (confirmacao manual do usuario)"

:START_BLACKSITE
echo [BLACKSITE] Godot detectado: %GODOT_VERSION%
echo [BLACKSITE] Projeto: %PROJECT_DIR%
if /I "%~1"=="game" (
    echo Abrindo o jogo diretamente. Use este modo para uma instancia de teste.
    "%GODOT_EXE%" --path "%PROJECT_DIR%"
) else (
    echo Abrindo o editor. Pressione F5 no Godot para iniciar a cena principal.
    echo Para abrir diretamente o jogo: INICIAR_BLACKSITE.bat game
    "%GODOT_EXE%" --editor --path "%PROJECT_DIR%"
)
set "RUN_RESULT=%ERRORLEVEL%"
if not "%RUN_RESULT%"=="0" echo [BLACKSITE] Godot terminou com codigo %RUN_RESULT%.
exit /b %RUN_RESULT%
