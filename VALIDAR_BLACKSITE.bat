@echo off
setlocal EnableExtensions
set "PROJECT_DIR=%~dp0"
set "FAILED=0"

if not exist "%PROJECT_DIR%project.godot" (
    echo [BLACKSITE] ERRO: project.godot nao encontrado em %PROJECT_DIR%
    exit /b 2
)
if not exist "%PROJECT_DIR%scenes\menu\main_menu.tscn" (
    echo [BLACKSITE] ERRO: cena principal ausente: scenes\menu\main_menu.tscn
    set "FAILED=1"
)
if not exist "%PROJECT_DIR%assets\models\blacksite_crate.glb" (
    echo [BLACKSITE] ERRO: recurso GLB ausente: assets\models\blacksite_crate.glb
    set "FAILED=1"
)

set "PYTHON_COMMAND="
where py >nul 2>&1
if not errorlevel 1 set "PYTHON_COMMAND=py -3"
if not defined PYTHON_COMMAND (
    where python >nul 2>&1
    if not errorlevel 1 set "PYTHON_COMMAND=python"
)
if not defined PYTHON_COMMAND (
    echo [BLACKSITE] NAO EXECUTADO: Python 3 nao encontrado; testes estruturais indisponiveis.
    set "FAILED=1"
) else (
    echo [BLACKSITE] Executando testes estruturais Python. Isto nao executa o jogo.
    %PYTHON_COMMAND% -m unittest discover -s "%PROJECT_DIR%tests" -p "test_*.py" -v
    if errorlevel 1 (
        echo [BLACKSITE] FALHA: testes estruturais Python.
        set "FAILED=1"
    ) else (
        echo [BLACKSITE] APROVADO: testes estruturais Python.
    )
)

where gdformat >nul 2>&1
if errorlevel 1 (
    echo [BLACKSITE] NAO EXECUTADO: gdformat nao instalado; lint GDScript opcional ignorado.
) else (
    echo [BLACKSITE] Executando gdformat --check.
    gdformat --check "%PROJECT_DIR%scripts\networking\menu.gd" "%PROJECT_DIR%scripts\networking\net.gd" "%PROJECT_DIR%scripts\player\avatar.gd" "%PROJECT_DIR%scripts\player\sector.gd"
    if errorlevel 1 set "FAILED=1"
    where gdlint >nul 2>&1
    if errorlevel 1 (
        echo [BLACKSITE] NAO EXECUTADO: gdlint nao instalado.
    ) else (
        gdlint "%PROJECT_DIR%scripts\networking\menu.gd" "%PROJECT_DIR%scripts\networking\net.gd" "%PROJECT_DIR%scripts\player\avatar.gd" "%PROJECT_DIR%scripts\player\sector.gd"
        if errorlevel 1 set "FAILED=1"
    )
)

if defined GODOT_EXE if not exist "%GODOT_EXE%" (
    echo [BLACKSITE] NAO EXECUTADO: GODOT_EXE nao existe: %GODOT_EXE%
    set "GODOT_EXE="
)
if not defined GODOT_EXE (
    for /f "delims=" %%I in ('where godot.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%I"
)
if not defined GODOT_EXE (
    for /f "delims=" %%I in ('where godot_console.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%I"
)
if not defined GODOT_EXE (
    echo [BLACKSITE] NAO EXECUTADO: Godot nao encontrado. Importacao Godot, runtime e rede nao foram testados.
) else (
    echo [BLACKSITE] Godot encontrado: %GODOT_EXE%
    "%GODOT_EXE%" --version
    echo [BLACKSITE] Tentando importacao/headless do editor. Isto NAO e teste de gameplay ou multiplayer.
    "%GODOT_EXE%" --headless --editor --path "%PROJECT_DIR%" --quit
    if errorlevel 1 (
        echo [BLACKSITE] FALHA: Godot retornou erro na etapa headless; examine as mensagens acima.
        set "FAILED=1"
    ) else (
        echo [BLACKSITE] Processo headless terminou sem erro de codigo. Revise warnings acima; gameplay nao foi validado.
    )
)

echo.
echo [BLACKSITE] Esta rotina nao declara gameplay, multiplayer ou build Windows aprovados.
if "%FAILED%"=="0" (
    echo [BLACKSITE] Verificacoes disponiveis terminaram sem falha reportada.
) else (
    echo [BLACKSITE] Uma ou mais verificacoes falharam ou nao estavam disponiveis.
)
exit /b %FAILED%
