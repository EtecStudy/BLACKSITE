# BLACKSITE

**Black Sight** — jogo de terror cooperativo em primeira pessoa, desenvolvido em
**Godot 4.7.2**.

> **Status:** Etapa 6 concluída — stamina na corrida, modos de agachamento
> (ALTERNAR/SEGURAR) e lista real de controles, com configurações acessíveis
> durante a partida.

![Tela inicial do Black Sight](docs/screenshots/title_screen.png)

![Tela de configurações do Black Sight](docs/screenshots/settings_screen.png)

![Sala de teste do controlador FPS](docs/screenshots/movement_test.png)

## Download do jogo (Windows)

**https://github.com/EtecStudy/BLACKSITE/releases/download/v0.6.0-etapa6/BlackSight-Etapa6-Windows-x86_64.zip**

Arquivo: `BlackSight-Etapa6-Windows-x86_64.zip` (TAMANHO_ZIP)

SHA-256 do ZIP: `SHA256_ZIP`

1. Baixe e extraia o ZIP (mantenha `BlackSight.exe` e `BlackSight.pck` na mesma pasta).
2. Duplo clique em **BlackSight.exe**.
3. Clique em **TESTAR MOVIMENTAÇÃO** para entrar na sala 3D.

Requisitos: Windows 10/11 64 bits e GPU com OpenGL 3.3+ (renderizador *GL Compatibility*).

## Controles

| Tecla | Ação |
| --- | --- |
| `W` `A` `S` `D` | Andar (relativo à direção da câmera) |
| `Shift` | Correr (consome stamina; nunca agachado) |
| `Ctrl` | Agachar — **ALTERNAR** (padrão): um toque agacha, outro levanta; **SEGURAR**: mantenha pressionado |
| Mouse | Olhar (limite de ±89° na vertical) |
| `Esc` | Liberar o mouse / abrir a pausa |
| `F11` | Alternar janela ↔ tela cheia |
| **SAIR DO JOGO** | Fechar o jogo (na tela inicial) |

Na pausa da cena de teste: **CONTINUAR** (ou `Esc`) captura o mouse de novo,
**CONFIGURAÇÕES** abre a mesma tela da Etapa 3 por cima da partida pausada
(VOLTAR/Esc retornam à pausa) e **VOLTAR AO MENU** retorna à tela inicial.

A sensibilidade do mouse, a inversão vertical e o **modo de agachamento** são
os configurados em **CONFIGURAÇÕES → CONTROLES**. A lista mostrada ali é a dos
controles que existem de verdade — sem interação, lanterna, pulo ou inventário.

## O que existe hoje

- Tela inicial com emblema, fade, partículas, vinheta e botão de saída (Etapa 1).
- Arquitetura em módulos por responsabilidade (Etapa 2).
- Tela de configurações com abas de **Controles**, **Áudio** e **Vídeo**, com
  persistência em `%APPDATA%\BlackSight\settings.cfg` (Etapa 3).
- **Controlador FPS** (Etapa 4): `CharacterBody3D`, câmera em primeira pessoa,
  WASD, gravidade, colisão, limite de pitch, integração com a sensibilidade e a
  inversão vertical, pausa com liberação do cursor e retorno ao menu.
- **Estados de movimento** (Etapa 5): parado, andando, correndo (Shift) e
  agachado (Ctrl), com velocidades próprias, prioridade do agachamento sobre a
  corrida, câmera que acompanha a altura e cápsula que só volta a ficar em pé
  quando há espaço.
- **Stamina e agachamento configurável** (Etapa 6): correr consome 20/s (máximo
  100), recupera 15/s parado/andando/agachado, para ao esgotar e volta a partir
  de 20. O modo de agachamento (**ALTERNAR** padrão ou **SEGURAR**) fica em
  `settings.cfg` e vale na hora, inclusive durante a partida.
- **Sala de teste 3D** com piso, paredes, pilares e caixas — apenas para validar
  movimentação e colisão, sem arte final.

Ainda **não** existe: pulo, inventário, interação, criaturas, multiplayer,
voz e o mapa definitivo. Também não há HUD de stamina nesta etapa.
Ver [`docs/ETAPA-6.md`](docs/ETAPA-6.md).

## Arquitetura

O projeto é dividido em módulos por responsabilidade. Detalhes completos em
[`docs/ARQUITETURA.md`](docs/ARQUITETURA.md).

```
players/       jogador: player.tscn + player_controller.gd
creatures/     criaturas e IA (estrutura)
maps/          mapas e salas — test_room.tscn
items/         itens, inventário e interação (estrutura)
objectives/    objetivos e progressão (estrutura)
match/         orquestração — movement_test (sala + jogador + pausa)
ui/            menus e HUD — tela inicial e configurações
audio/         buses de áudio e sons da interface
shared/        recursos, tema, configurações e autoloads
```

Cada módulo tem seu próprio `README.md` com a responsabilidade, o que entra nele
e o que não entra.

## Configurações

Documentação completa em [`docs/CONFIGURACOES.md`](docs/CONFIGURACOES.md).

| Item | Onde |
| --- | --- |
| Arquivo do usuário | `user://settings.cfg` → `%APPDATA%\BlackSight\settings.cfg` |
| Esquema, padrões e limites | `shared/settings/settings_schema.gd` |
| Leitura, gravação e aplicação | `shared/settings/game_settings.gd` (autoload `GameSettings`) |
| Aplicação de áudio | `shared/settings/audio_applier.gd` |
| Aplicação de vídeo | `shared/settings/video_applier.gd` |
| Consumo pelo jogador | `players/scripts/player_controller.gd` |
| Buses | `audio/default_bus_layout.tres` |
| Tela | `ui/scenes/settings_screen.tscn` |

## Rodar a partir do código-fonte

1. Instale o [Godot 4.7.2](https://github.com/godotengine/godot/releases/tag/4.7.2-stable) (versão padrão, sem .NET).
2. Abra o Godot → **Import** → selecione `project.godot`.
3. Pressione **F5**. A cena inicial é `ui/scenes/title_screen.tscn`.

Exportar novamente para Windows (com os export templates instalados):

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/BlackSight.exe
```

## Configuração do projeto

| Item | Valor |
| --- | --- |
| Engine | Godot 4.7.2 (GL Compatibility) |
| Resolução lógica | 1920 × 1080 (16:9) |
| Janela inicial | 1600 × 900, redimensionável |
| Stretch | `canvas_items`, aspecto `keep` |
| VSync | Ativado |
| Cena principal | `ui/scenes/title_screen.tscn` |
| Autoloads | `AppInfo`, `GameSettings`, `UiAudio` |
| Buses de áudio | `Master`, `Music`, `SFX`, `Ambience`, `Voice` |
| Input Map | `move_forward/back/left/right` (W/S/A/D), `move_sprint` (Shift), `move_crouch` (Ctrl) e `release_mouse` (Esc) |

## Testes

O workflow [`.github/workflows/build.yml`](.github/workflows/build.yml) roda em
dois runners:

- **Linux**: importa o projeto, roda os testes de fumaça, de fluxo da interface
  e do controlador FPS, executa a cena inicial, renderiza sob Xvfb/OpenGL,
  exporta e inspeciona o pacote.
- **Windows** (`windows-latest`): repete os testes, gera o `.exe`, executa o
  `.exe` exportado, verifica o `settings.cfg` em `%APPDATA%`, abre com janela e
  valida metadados — é este job que publica a release.

```bash
# configurações, cenas e persistência
godot --headless --path . --audio-driver Dummy res://tools/ci/smoke_test.tscn

# navegação real entre menus e cena de teste
godot --headless --path . --fixed-fps 60 res://tools/ci/ui_flow_test.tscn

# controlador FPS: movimento, câmera, física e colisões
godot --headless --path . --fixed-fps 60 --audio-driver Dummy res://tools/ci/movement_test.tscn
```

## Documentação

| Documento | Conteúdo |
| --- | --- |
| [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md) | Módulos, dependências, convenções, comunicação |
| [`docs/CONFIGURACOES.md`](docs/CONFIGURACOES.md) | Onde ficam as configurações e como adicionar parâmetros |
| [`docs/ETAPA-6.md`](docs/ETAPA-6.md) | Stamina, modos de agachamento e controles reais |
| [`docs/ETAPA-5.md`](docs/ETAPA-5.md) | Estados de movimento, agachamento e pausa com configurações |
| [`docs/ETAPA-4.md`](docs/ETAPA-4.md) | Controlador FPS, cena de teste e resultados |
| [`docs/ETAPA-3.md`](docs/ETAPA-3.md) | Configurações de controles, áudio e vídeo |
| [`docs/ETAPA-2.md`](docs/ETAPA-2.md) | Estrutura interna em módulos |
| [`docs/ETAPA-1.md`](docs/ETAPA-1.md) | Fundação do projeto |

## Créditos

- Fonte **Cinzel** — NDISCOVER / The Cinzel Project Authors, licença **SIL OFL 1.1**
  (`shared/fonts/cinzel/OFL.txt`).
- Assets visuais (fundo, vinheta, emblema, ícone, poeira) gerados proceduralmente
  por `tools/generate_brand_assets.py`.
- Sons de interface gerados proceduralmente por `tools/generate_ui_sounds.py`.
- Godot Engine — MIT.
