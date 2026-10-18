# BLACKSITE 0.1 — preparação e validação no Windows

> Este documento descreve como executar e recolher evidências localmente. O projeto não inclui Godot, Blender, templates de exportação nem um `.exe`; ainda não foi validado no runtime Windows. O GLB existente passou no validador Khronos, mas a importação Godot continua por confirmar.

## 1. Requisitos

- Windows 10/11 de 64 bits.
- Godot **4.3 ou posterior**, versão standard ou console. A variante console é recomendada para recolher logs. O projeto não requer Blender para abrir: o recurso GLB pequeno já está no repositório.
- Python 3 é recomendado para testes estruturais. No Windows, instale-o com o launcher `py` ou coloque `python.exe` no PATH. Os testes usam somente a biblioteca padrão.
- Extraia/clone o repositório inteiro; abra a pasta que contém `project.godot`. Não mova apenas o `.exe` ou o GLB.

## 2. Abrir o projeto

1. Abra um terminal na raiz do projeto.
2. Execute `INICIAR_BLACKSITE.bat`.
3. O script procura `GODOT_EXE`, depois `godot.exe`/`godot_console.exe` no PATH. Se não encontrar, solicita o caminho completo do executável. Pode-se definir `GODOT_EXE` para não receber a pergunta:

```powershell
$env:GODOT_EXE = (Resolve-Path 'CAMINHO_REAL\Godot_v4.x-stable_win64_console.exe').Path
.\INICIAR_BLACKSITE.bat
```

Substitua `CAMINHO_REAL\...` pelo local real da sua instalação; não é um caminho predefinido pelo projeto. O iniciador verifica a existência do executável e recusa versões anteriores a 4.3 quando `--version` retorna a versão; alguns executáveis GUI podem não expor a saída no console e, nesse caso, solicita confirmação manual explícita antes de continuar. Por padrão abre o editor, importa os recursos e carrega o projeto. Pressione **F5** para executar a cena principal (`scenes/menu/main_menu.tscn`). `INICIAR_BLACKSITE.bat game` tenta iniciar o jogo diretamente sem abrir o editor.

Na primeira abertura, aguarde o import de recursos concluir. O cache fica em `.godot/`, ignorado pelo Git. Erros/warnings do editor devem ser registrados; não os trate como testes aprovados.

## 3. Verificações automatizadas

Execute `VALIDAR_BLACKSITE.bat` na raiz do projeto. O script:

- confere arquivos essenciais;
- procura Python (`py -3` ou `python`) e roda `python -m unittest discover -s tests -p "test_*.py" -v`;
- roda `gdformat --check` e `gdlint` somente se essas ferramentas estiverem instaladas;
- se encontra Godot, executa `--headless --editor --path <projeto> --quit` para tentar importar/carregar o projeto sem interface.

Ausência de Python/Godot/lint é indicada como **não executado**, e não como aprovado. Mesmo quando a etapa headless da Godot termina com código zero, ela **não testa gameplay, rede, colisões visuais nem exportação**. Leia mensagens e warnings exibidos pelo Godot. Código de saída diferente de zero indica falha nas verificações automatizáveis disponíveis.

Comandos equivalentes para Python:

```powershell
py -3 -m unittest discover -s tests -p 'test_*.py' -v
```

Lint GDScript opcional (requer `gdtoolkit` instalado no Python escolhido):

```powershell
python -m pip install gdtoolkit
gdformat --check scripts/networking/menu.gd scripts/networking/net.gd scripts/player/avatar.gd scripts/player/sector.gd
gdlint scripts/networking/menu.gd scripts/networking/net.gd scripts/player/avatar.gd scripts/player/sector.gd
```

## 4. Teste multiplayer local com host + cliente

Use o roteiro detalhado em [`../tests/MULTIPLAYER_MANUAL.md`](../tests/MULTIPLAYER_MANUAL.md). Para executar com logs no Windows:

1. Abra **duas janelas PowerShell** na pasta raiz do projeto. Em cada uma, resolva o executável real. Se estiver no PATH:

```powershell
$godot = (Get-Command godot.exe -ErrorAction Stop).Source
$godot
```

Se não estiver no PATH, use o caminho real que escolheu para instalar Godot:

```powershell
$godot = (Resolve-Path 'CAMINHO_REAL\Godot_v4.x-stable_win64_console.exe').Path
& $godot --version
```

2. **Janela 1 — host:** execute a cena principal (F5 no editor) ou inicie uma instância de jogo. No menu, clique **HOSPEDAR PARTIDA**. O host usa UDP 24560 por padrão.
3. **Janela 2 — cliente:** inicie uma segunda instância, conecte a `127.0.0.1`, porta `24560`, e clique **ENTRAR NA PARTIDA**.
4. Confirme que os dois IDs aparecem. Movimente os dois jogadores ao mesmo tempo, teste a câmera local, paredes, caixa e colisões entre personagens. Feche o cliente e confirme que o host remove seu ID. Inspecione ambas as saídas por `SCRIPT ERROR`, falhas de RPC ou erro físico.
5. Grave o resultado observado, versão completa de Godot, comandos usados e mensagens relevantes em `blacksite-host.log` e `blacksite-client.log` (ou arquivos equivalentes). Não inclua tokens, credenciais ou dados pessoais. Esse teste local não comprova funcionamento pela LAN ou internet.

### Abrir duas instâncias de runtime via PowerShell

Os comandos abaixo exigem que `$godot` contenha o caminho real do executável console e que o terminal esteja na pasta do projeto. Rode cada comando em uma janela PowerShell distinta; o processo permanece aberto enquanto a instância roda e encaminha a saída para um log local ignorado pelo Git:

```powershell
$godot = (Get-Command godot.exe -ErrorAction Stop).Source
& $godot --path (Get-Location).Path --position 100,100 2>&1 | Tee-Object -FilePath .\blacksite-host.log
```

Na segunda janela, repita com posição e log diferentes:

```powershell
$godot = (Get-Command godot.exe -ErrorAction Stop).Source
& $godot --path (Get-Location).Path --position 700,100 2>&1 | Tee-Object -FilePath .\blacksite-client.log
```

Hospede na primeira janela e conecte a segunda em `127.0.0.1:24560`. Para Godot não presente no PATH, atribua `$godot` ao caminho real via `Resolve-Path` antes de cada comando. Se `--position` não reposicionar a janela nessa versão, mova-as manualmente; isso não altera a rede.

**Critérios a registrar:** host iniciado; cliente conectado; roster mostra dois IDs; movimento de ambos sincronizado; colisões de parede/caixa/personagem; desconexão remove o cliente; ausência/presença de erros críticos. Marque apenas o que observou. Para limite, inclua mais clientes: máximo esperado é um host + três clientes. Para LAN, use o IP privado do host e permita UDP 24560 no firewall; para internet é necessário host UDP acessível/encaminhamento e CGNAT pode impedir conexões.

## 5. Assets e build Windows

- Arquivo referenciado pelo cenário: `assets/models/blacksite_crate.glb` (GLB próprio, 12 triângulos), carregado em `scripts/player/sector.gd` e acompanhado de collider da cena. Khronos validou o arquivo com zero erros/avisos, mas verifique visualmente orientação, escala e material no editor Godot.
- O `.blend` ainda não existe. Para criar o fonte e exportar uma variante detalhada quando Blender 4.x estiver disponível: `blender -b --python blender/source/generate_props.py`. Depois reabra o projeto e confirme import/render do GLB dentro do cenário.
- A build Windows **não foi gerada**. Para exportar: instale templates de exportação compatíveis com a versão do editor; abra **Project > Export > Add… > Windows Desktop**, escolha x86_64, defina `export/BLACKSITE.exe` e exporte. Confira os recursos embutidos/arquivos acompanhantes e execute o build no Windows. Registre versão, saída do export e resultado de execução. Não confunda a etapa headless de importação com export ou teste do `.exe`.

## 6. Entrega de evidências para a próxima correção

Antes de reportar falhas, preserve o conteúdo de `blacksite-host.log`, `blacksite-client.log`, saída do `VALIDAR_BLACKSITE.bat`, versão de Godot, etapas de reprodução e capturas de tela reais do editor/cena. Não inclua o diretório `.godot` no Git; ele é cache gerado localmente. Mantenha o projeto-fonte e os logs sem segredos.
