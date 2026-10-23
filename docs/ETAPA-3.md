# Black Sight — Etapa 3: Configurações básicas do projeto

Relatório da Etapa 3. As Etapas 1 e 2 foram concluídas e validadas
anteriormente (tela inicial, animações, arquitetura em módulos).

## 1. Objetivo

Dar ao jogador controle real sobre **teclado/mouse**, **áudio** e **vídeo**,
com os valores guardados entre execuções — sem implementar nenhuma mecânica de
jogo. Também era obrigatório não fingir funcionalidade: nada de opções que não
fazem nada.

## 2. O que foi entregue

### 2.1 Controles (teclado/mouse)

- Sensibilidade horizontal e vertical do mouse: `0.1` a `5.0`, passo `0.05`,
  padrão `1.00×`.
- Inverter eixo vertical (padrão: desligado).
- Lista dos controles padrão **previstos** (WASD, mouse, Shift, E, F, Esc),
  marcada na tela como referência para a etapa futura.
- Os valores são gravados e ficam prontos para o controlador do jogador.
  **Nenhuma movimentação é aplicada nesta etapa** — a tela diz isso.

### 2.2 Áudio

- Layout de buses em `audio/default_bus_layout.tres`:
  `Master` → `Music`, `SFX`, `Ambience`, `Voice`.
- Volumes de geral (80%), efeitos (80%), ambiente (70%) e música (60%), em
  porcentagem, com o valor numérico sempre visível ao lado do slider.
- Aplicação imediata (`linear_to_db`; `0%` silencia o bus) para pré-visualização.
- Dois sons originais de interface, sintetizados por
  `tools/generate_ui_sounds.py`, tocam no bus `SFX`:
  clique de botão e confirmação de aplicar. Servem para o ajuste de volume ser
  percebido de verdade.
- Categorias **sem sons** nesta etapa (escrito na própria tela): música,
  ambiente e voz. Os buses existem e os volumes são salvos.

### 2.3 Vídeo

- Modo de janela: **janela**, **janela maximizada** e **tela cheia**.
- Resoluções oferecidas: 1280×720, 1366×768, 1600×900, 1920×1080, 2560×1440 e
  3840×2160, filtradas pelo tamanho útil do monitor atual.
- VSync ligado/desligado (quando o driver respeita).
- Aplicação apenas ao clicar em **APLICAR** — dá para desistir sem mudar a janela.
- Segurança: toda resolução vinda do arquivo é limitada entre 1024×576 e o
  tamanho útil da tela; a proporção é preservada pelo stretch
  `canvas_items`/`keep`; `F11` funciona em qualquer tela; **RESTAURAR PADRÕES**
  está sempre visível.

### 2.4 Interface

- Botão **CONFIGURAÇÕES** na tela inicial, entre **JOGAR** e **SAIR DO JOGO**.
- Tela própria (`ui/scenes/settings_screen.tscn`) com as abas **Controles**,
  **Áudio** e **Vídeo**, painel com a mesma identidade visual (fundo, vinheta,
  poeira, Cinzel) e rodapé com **RESTAURAR PADRÕES**, **VOLTAR** e **APLICAR**.
- Mensagem de estado no rodapé ("alterações pendentes", "aplicadas e salvas").
- `Esc` volta ao menu; `F11` continua alternando tela cheia.
- **Preservados sem alteração**: emblema, animações de fade e respiração,
  partículas, vinheta, título, versão no rodapé e botão **SAIR DO JOGO**.

### 2.5 Persistência

- `ConfigFile` em `user://settings.cfg` → `%APPDATA%\BlackSight\settings.cfg`.
  Nunca na pasta de instalação.
- Carregamento na inicialização; arquivo ausente → padrões (e criação na
  primeira execução); arquivo inválido → padrões + aviso no log, sem impedir a
  abertura.
- Toda leitura passa por `SettingsSchema.sanitize()`: tipo correto, dentro dos
  limites, chaves ausentes preenchidas com o padrão.
- Gravação ao **APLICAR**; **RESTAURAR PADRÕES** repõe e grava; falha de
  escrita não derruba o jogo (só avisa).
- Estrutura extensível e documentada em [`CONFIGURACOES.md`](CONFIGURACOES.md).

## 3. Arquitetura da etapa

| Arquivo | Responsabilidade |
| --- | --- |
| `shared/settings/settings_schema.gd` | Esquema: padrões, limites, `sanitize`, descrição |
| `shared/settings/game_settings.gd` | Autoload `GameSettings`: ler, validar, aplicar, salvar |
| `shared/settings/audio_applier.gd` | Percentual → dB nos buses |
| `shared/settings/video_applier.gd` | Janela, resolução, VSync e limites de segurança |
| `audio/default_bus_layout.tres` | Buses do projeto |
| `audio/scripts/ui_audio.gd` | Autoload `UiAudio`: clique e confirmação |
| `ui/scenes/settings_screen.tscn` | Tela de configurações |
| `ui/scripts/settings_screen.gd` | Orquestração das seções e navegação |
| `ui/scripts/settings/settings_section.gd` | Base e helpers de layout |
| `ui/scripts/settings/controls_section.gd` | Seção CONTROLES |
| `ui/scripts/settings/audio_section.gd` | Seção ÁUDIO |
| `ui/scripts/settings/video_section.gd` | Seção VÍDEO |
| `tools/ci/smoke_test.gd` | Testes de configuração, persistência, áudio, vídeo e cenas |
| `tools/ci/ui_flow_test.gd` | Navegação real: menu → configurações → abas → aplicar → voltar |

A UI não conhece `ConfigFile`; o gerenciador não conhece botões. Cada seção
devolve apenas o seu fragmento de configuração.

## 4. Testes executados

Workflow [`.github/workflows/build.yml`](../.github/workflows/build.yml),
execução **39341579671** (commit `1c8cdb9`), Godot **4.7.2-stable official**
nos dois runners.

| Job | Passos | Resultado |
| --- | --- | --- |
| Linux — importar, testar e validar o pacote | 22/22 | aprovado |
| Windows real — exportar e executar o `.exe` | 18/18 | aprovado |

### 4.1 Teste de fumaça (Linux e Windows)

`SMOKE TEST OK — 158 verificações aprovadas` nos dois sistemas.

Cobre:

- configuração do projeto: nome, versão, renderizador, resolução lógica
  1920×1080, stretch `canvas_items`/`keep`, cena principal, ícone, boot splash e
  layout de buses;
- autoloads `AppInfo`, `GameSettings` e `UiAudio` presentes e registrados;
- tema, fontes Cinzel e as texturas da identidade;
- os dois WAV de interface existem e importam;
- módulos, READMEs, documentação e ausência de código nos módulos preparatórios;
- cena inicial: todos os nós, JOGAR desabilitado, **CONFIGURAÇÕES** e
  **SAIR DO JOGO** presentes e conectados;
- esquema: sensibilidade fora da faixa é limitada; volume 500 → 100; volume
  negativo → 0; valor inválido → padrão; **modo de janela inválido → janela**
  (não tela cheia); resolução minúscula → mínimo legível;
- persistência: `apply()` grava; `load_settings()` relê; **uma nova instância do
  gerenciador lê o mesmo arquivo** (simula fechar e reabrir); arquivo corrompido
  cai nos padrões sem falhar; `restore_defaults()` grava os padrões;
- áudio: os 5 buses existem; 25% aplicado ao bus `SFX`; 0% silencia `Music`;
  voltar ao padrão reativa;
- vídeo: resolução absurda limitada ao tamanho da tela; resolução minúscula sobe
  ao mínimo; lista de resoluções válida; rótulos em português;
- tela de configurações: instancia, 3 abas, 3 seções, apenas uma visível por vez,
  troca de aba, 4 sliders no áudio, **APLICAR** grava 33%, **RESTAURAR PADRÕES**
  volta a 80%, 2 listas no vídeo (resolução e 3 modos de janela).

### 4.2 Fluxo real de interface (Linux e Windows)

`UI FLOW OK — 27 verificações aprovadas` nos dois sistemas. Diferente do teste
de fumaça, aqui as **cenas trocam de verdade** (menu → configurações → menu).

- tela inicial abre; emblema, título e rodapé com F11 presentes; SAIR conectado;
- **CONFIGURAÇÕES** abre a tela; 3 abas; CONTROLES por padrão; ÁUDIO com 4 sliders;
- volume 37% + **APLICAR** → valor em memória e no arquivo;
- **RESTAURAR PADRÕES** + **APLICAR** → 80% em memória e no arquivo;
- VÍDEO: resolução + 3 modos; **tela cheia** aplicada e gravada;
- **VOLTAR** retorna ao menu; reabrir mostra o modo de janela salvo;
- **F11** alterna (2 → 0) e volta (0 → 2), gravando a preferência.

### 4.3 Build exportado (Linux, sob Xvfb)

- `TESTE 5`: o executável exportado abriu a cena inicial.
- `TESTE 5b`: o build exportado **criou**
  `~/.local/share/BlackSight/settings.cfg` com as seções `[meta]`, `[controls]`,
  `[audio]` e `[video]` — prova de gravação em `user://`, fora da pasta do jogo.
- `TESTE 6`: `.pck` de **1.376.692 bytes**, formato 4, **58 recursos**,
  incluindo `default_bus_layout`, `settings_screen`, os 4 scripts de
  configuração e os 2 WAV importados.
- `TESTE 3b`: render real da tela de configurações em 1600×900 →
  [`docs/screenshots/settings_screen.png`](screenshots/settings_screen.png).

### 4.4 Pacote publicado

| Item | Valor |
| --- | --- |
| ZIP | `BlackSight-Etapa3-Windows-x86_64.zip` |
| Tamanho | **40.611.269 bytes** |
| SHA-256 | `d55afd98a80271808df3c67b2095e88e7fd42b4f1032b3faec3418aad0b72fcf` |
| `BlackSight.exe` | 109.193.728 bytes |
| `BlackSight.pck` | 1.376.692 bytes |
| Release | https://github.com/EtecStudy/BLACKSITE/releases/tag/v0.3.0-etapa3 |

O `digest` do asset no GitHub (`sha256:d55afd98…`) confere com o hash calculado
no job Windows: **o arquivo publicado é exatamente o que passou nos testes**.

## 5. Teste no Windows real

Job `windows` no runner `windows-latest` (máquina Windows real da nuvem),
18/18 passos.

| Teste | Evidência obtida |
| --- | --- |
| W1 — importação | `.godot/imported` criado; 13 arquivos obrigatórios presentes |
| W2 — fumaça | `SMOKE TEST OK — 158 verificações aprovadas` |
| W2b — fluxo | `UI FLOW OK — 27 verificações aprovadas` |
| W3 — cena inicial | `[Black Sight] Tela inicial carregada — v0.3.0 · Godot 4.7.2-stable (official) · gl_compatibility` e `Configurações carregadas: master=80 sfx=80 ambience=70 music=60 mode=windowed resolution=1600x900 vsync=true` |
| W4 — exportação | `BlackSight.exe` e `BlackSight.pck` gerados |
| W5 — `.exe` exportado | primeira execução: `Arquivo de configurações criado com os valores padrão` |
| W5b — `%APPDATA%` | `%APPDATA%\BlackSight\settings.cfg` criado pelo `.exe`, com `mouse_sensitivity_x`, `master_volume`, `window_mode` e `vsync` (conteúdo integral no log) |
| W6 — janela | `vivo_apos_25s=True` · `titulo_janela=Black Sight` |
| W7 — pacote e metadados | `PACOTE OK` · `ProductName=Black Sight` · `FileDescription=Black Sight — Etapa 3` · `FileVersion=0.3.0.0` |

O `.exe` executado no Windows é o mesmo empacotado no ZIP publicado.

## 6. Limitações e pendências desta etapa

- Sem jogador/movimentação: sensibilidade e inversão ficam salvas, sem efeito
  visível (por definição do escopo).
- Música, ambiente e voz não têm sons; os volumes só terão efeito auditivo
  quando esses sistemas existirem.
- VSync pode ser ignorado por alguns drivers em GL Compatibility.
- "Janela maximizada" não guarda o tamanho anterior da janela.
- Não há remapeamento de teclas nesta etapa.
- Os testes automatizados de fumaça e de fluxo rodam como cena e chamam
  `quit()` no mesmo frame; ao encerrar, a Godot imprime avisos de objetos
  liberados tardiamente (`ObjectDB instances were leaked at exit`). São avisos
  do processo de teste, não do jogo: o `.exe` exportado encerra sem esses
  avisos e o código de saída dos testes é 0.
- O teste em Windows foi feito no runner `windows-latest` (Windows Server da
  nuvem) com execução real do `.exe`; o teste na máquina do usuário é o passo
  final de aceite.

## 7. Como verificar manualmente

1. Abra `BlackSight.exe`, clique em **CONFIGURAÇÕES**.
2. Aba **Áudio**: mova os sliders (o clique da interface muda de volume) →
   **APLICAR**. Feche e reabra: os valores continuam iguais.
3. Aba **Vídeo**: escolha **Tela cheia** → **APLICAR**; pressione `F11` para
   voltar. Feche e reabra: o modo escolhido é reaplicado.
4. **RESTAURAR PADRÕES** → **APLICAR**; feche e reabra: tudo volta ao padrão.
5. **VOLTAR** retorna ao menu; **SAIR DO JOGO** continua fechando o jogo.
6. Confira o arquivo em `%APPDATA%\BlackSight\settings.cfg`.

## 8. Documentos relacionados

- [`CONFIGURACOES.md`](CONFIGURACOES.md) — onde ficam as configurações e como
  adicionar parâmetros.
- [`ARQUITETURA.md`](ARQUITETURA.md) — módulos e dependências.
- [`RELEASE_NOTES_ETAPA3.md`](RELEASE_NOTES_ETAPA3.md) — notas da release.
