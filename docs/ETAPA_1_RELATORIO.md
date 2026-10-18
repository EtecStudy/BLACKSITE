# BLACKSITE 0.1 — relatório de preparação e validação

**Estado:** projeto preparado para validação local no Windows. A Etapa 1 **permanece aberta**: não foi possível executar Godot neste ambiente, nem comprovar runtime multiplayer, colisões visuais, importação Godot do GLB ou build Windows.

## Repositório e auditoria

- Branch conferida: `arena/6823859e-blacksite`. O workspace local chegou inicialmente ao commit base `4594975` apesar do commit solicitado estar no remoto. Fiz fetch explícito do ramo, comparei todo o conteúdo local preparado contra `origin/arena/6823859e-blacksite` e não havia divergências. Atualizei a branch local para `b9d6344` sem descartar arquivos ou histórico; os commits remotos anteriores permanecem ancestrais.
- Cena principal de `project.godot`: `res://scenes/menu/main_menu.tscn`.
- Autoload: `Net` → `res://scripts/networking/net.gd`.
- As referências `res://` em `project.godot`, `.tscn` e `.gd` agora são verificadas pelo teste `test_all_godot_resource_paths_resolve`.
- Quatro scripts GDScript existentes foram formatados e verificados com `gdformat`/`gdlint`; lint/parser passou. Isso não substitui a compilação pela Godot 4.3.
- `scripts/player/sector.gd` carrega `res://assets/models/blacksite_crate.glb` como `PackedScene`, instancia-o na cena jogável e cria seu collider. O GLB existente é o arquivo referenciado, não uma cópia de teste. Validação Khronos anterior reportou zero erros/avisos; isso não prova import/render no Godot.
- As cenas, scripts, GLB, catálogo e fonte Blender estão no repositório. Não há `.blend`, template de exportação ou executável Windows. O Blender fonte é um script real, não um arquivo `.blend` simulado.

## Preparação Windows adicionada

- `INICIAR_BLACKSITE.bat`: verifica `project.godot`, procura `GODOT_EXE`/PATH, solicita caminho real se necessário, valida Godot 4.3+, e abre o editor (ou runtime com argumento `game`).
- `VALIDAR_BLACKSITE.bat`: confere arquivos essenciais, executa testes Python se Python estiver acessível, executa lint se instalado e tenta importação headless somente se encontrar Godot. Mostra explicitamente etapas não executadas e não afirma aprovação de gameplay/multiplayer.
- `docs/VALIDACAO_WINDOWS.md`: instruções completas para abrir, validar, exportar e registrar evidências no Windows.
- `tests/MULTIPLAYER_MANUAL.md`: PowerShell para duas instâncias usando Godot encontrado no PATH ou caminho real escolhido pelo usuário, logs separados, movimento simultâneo, colisões, desconexão e limite.
- `.gitignore`: cache Godot `.godot/`, logs locais e artefatos de exportação não são adicionados ao Git.
- `README.md`: aponta para os dois scripts e o guia Windows.

Os `.bat` foram revisados e cobertos por verificações **estáticas**, mas não foram executados por `cmd.exe` neste Linux. Assim, sua execução real ainda precisa ser confirmada no Windows.

## Logs de rede

`net.gd` agora produz mensagens pontuais com prefixo `[BLACKSITE][NET]`: falha de criação ENet, host/porta e capacidade, tentativa/resultado de conexão, entrada e saída de peer e primeira intenção de movimento válida. Um timeout de input (250 ms) gera aviso uma única vez até a retomada do input. Não há log de movimento a cada quadro nem registro de credenciais; o endereço/IP não é incluído nas mensagens de status do cliente.

## Testes desta rodada

### Aprovados (executados)

- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: **7 testes passaram**, incluindo resolução dos caminhos de recurso, cena principal/versão declarada, guardas de multiplayer/câmera, GLB e conteúdo real dos scripts Windows.
- `gdformat --check` nos quatro scripts GDScript: **4 sem necessidade de reformatação**.
- `gdlint` nos mesmos scripts: **Success: no problems found**.
- `git diff --check`: sem erros de whitespace antes do commit.
- Validação Khronos GLB de rodada anterior: zero erros/avisos; o GLB não foi alterado nesta preparação.

### Reprovados (tentativas anteriores, não repetidas nesta rodada)

- Download da Godot foi bloqueado após redirecionamento a host de artefatos fora dos hosts permitidos.
- `apt-get update` foi impedido por falta de permissão nos índices do sistema.
- Alternativa Blender `bpy==4.3.0` não pôde importar por ausência de `libXrender.so.1`.

### Não executados

- Godot editor/runtime e importação headless: executáveis ausentes. O script Windows de validação ainda precisa testar isso numa máquina com Godot.
- Cena visual, menu, host/cliente, sincronização, desconexões, colisões de parede/caixa/personagem e ausência de erros críticos no console.
- Execução efetiva dos `.bat` em Windows/`cmd.exe`.
- Importação do GLB no Godot, pipeline `.blend`→`.glb`→Godot e geração/teste de `.exe` Windows.
- LAN ou internet; nenhuma conexão externa foi testada.

## Como validar no Windows

1. Repositório completo extraído; Python 3 recomendado; instalar Godot 4.3+.
2. `INICIAR_BLACKSITE.bat` abre editor. Se Godot não estiver no PATH, informar o caminho completo do executável. F5 inicia a cena principal.
3. `VALIDAR_BLACKSITE.bat` roda o que estiver disponível. A etapa headless, se houver Godot, é apenas importação/carregamento, não o teste do jogo.
4. Para multiplayer, seguir `tests/MULTIPLAYER_MANUAL.md`: duas janelas PowerShell, host em UDP 24560 e cliente em `127.0.0.1:24560`; mover ambos simultaneamente, bater em paredes/caixa/avatares, fechar cliente e verificar que o host o remove. Guardar logs reais e a versão Godot.
5. Build: editor → **Project > Export > Add… > Windows Desktop**, instalar templates da mesma versão, x86_64, exportar para `export/BLACKSITE.exe` e executar no Windows. Nenhum executável foi gerado nesta sessão.

## Assets, preservação e próxima ação

- O catálogo verificável permanece em `docs/ASSET_CATALOG.md`; assets de terceiros pesquisados não foram baixados nem incorporados. O crate é próprio e gerado por Python simples; o script Blender pode gerar uma versão detalhada quando Blender estiver disponível.
- Supabase Storage não está exposto nas ferramentas desta sessão. Bucket `BLACKSITE` não foi consultado ou alterado; não houve upload.
- Próxima ação concreta: no Windows, executar `VALIDAR_BLACKSITE.bat`, abrir pelo `INICIAR_BLACKSITE.bat`, completar os passos de `tests/MULTIPLAYER_MANUAL.md` e enviar os dois logs/erros observados. Só depois corrigir falhas de runtime, validar visualmente o GLB e exportar a build Windows.
