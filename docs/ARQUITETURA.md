# Black Sight — Arquitetura do projeto

Documento de referência da organização interna (atualizado na Etapa 6).
Motor: **Godot 4.7.2**, renderizador **GL Compatibility**.

Regra de ouro: **cada pasta de módulo tem uma responsabilidade única**, e as
dependências apontam sempre em uma direção só.

---

## 1. Visão geral

```
BlackSight/
├── project.godot              # configuração da engine (nome, cena inicial, tema, autoload)
├── export_presets.cfg         # presets de exportação (Windows, Linux)
├── players/                   # jogador: controlador FPS + câmera
├── creatures/                 # criaturas e IA (estrutura)
├── maps/                      # mapas e salas — sala de teste 3D
├── items/                     # itens, inventário e interação (estrutura)
├── objectives/                # objetivos e progressão (estrutura)
├── match/                     # orquestração — sessão de teste da movimentação
├── ui/                        # menus, HUD — tela inicial e configurações
├── audio/                     # buses, sons de interface e (futuro) ambiente/voz
├── shared/                    # recursos e sistemas comuns — base de todos
├── tools/                     # scripts de apoio (CI, geração de assets)
└── docs/                      # documentação
```

### Diagrama de dependências

```
                 ┌──────────────┐
                 │   shared/    │   (sem dependências)
                 └──────┬───────┘
        ┌───────┬───────┼────────┬─────────┬──────────┬────────┐
        ▼       ▼       ▼        ▼         ▼          ▼        ▼
    players creatures  maps    items  objectives     ui      audio
        └───────┴───────┴────────┴─────────┴──────────┴────────┘
                                 ▲
                                 │  (orquestra todos)
                            ┌────┴─────┐
                            │  match/  │
                            └──────────┘
```

- `shared/` é folha: **não importa** nada dos outros módulos.
- Módulos de domínio importam **somente** `shared/`.
- `match/` é o único que pode conhecer vários módulos (orquestração).
- `ui/` **observa**; não altera estado de gameplay.
- Não há dependência circular: nenhum módulo de domínio referencia `match/`.

---

## 2. Finalidade de cada módulo

| Módulo | Finalidade | Conteúdo real hoje |
| --- | --- | --- |
| `players/` | Controlador em primeira pessoa, câmera, input, visão/lanterna, atributos, detecção de interação e inventário | `scenes/player.tscn`, `scripts/player_controller.gd`, `scripts/interaction/`, `scripts/inventory/` |
| `creatures/` | Criaturas: percepção, máquina de estados, patrulha, perseguição, spawn | apenas `README.md` |
| `maps/` | Mapas, salas, iluminação, portas, pontos de spawn | `scenes/test_room.tscn` (sala de teste) |
| `items/` | Definição de itens, inventário, coleta e objetos interativos | apenas `README.md` |
| `objectives/` | Objetivos, condições de conclusão e progressão | apenas `README.md` |
| `ui/` | Menus, HUD e tela inicial | `scenes/title_screen.tscn`, `scenes/settings_screen.tscn`, `scenes/hud/player_hud.tscn` |
| `audio/` | Áudio ambiente, efeitos sonoros e comunicação por voz | `default_bus_layout.tres`, autoload `UiAudio`, `assets/sfx/*.wav` |
| `match/` | Estados e fluxo da partida; orquestração entre módulos | `scenes/movement_test.tscn`, `scripts/movement_test.gd` |
| `shared/` | Recursos e sistemas usados por 2+ módulos | autoloads `AppInfo`/`GameSettings`, tema, fontes, texturas, `settings/` |

Cada módulo tem um `README.md` próprio, com regras específicas e sugestões de
nomes de arquivos para as próximas etapas.

---

## 3. Convenção interna de um módulo

Quando um módulo ganhar conteúdo, use **apenas as subpastas necessárias** (não
crie pastas vazias por antecipação):

```
<módulo>/
├── README.md      # obrigatório: responsabilidade e regras
├── scenes/        # cenas (.tscn) do módulo
├── scripts/       # scripts (.gd) do módulo
├── resources/     # Resources (.tres) — dados configuráveis
└── assets/        # somente o que for exclusivo deste módulo
```

| Tipo | Onde | Exemplo |
| --- | --- | --- |
| Cena | `scenes/` | `players/scenes/player.tscn` |
| Script de nó | `scripts/` | `players/scripts/player_controller.gd` |
| Dado configurável | `resources/` | `items/resources/item_lanterna.tres` |
| Asset exclusivo | `assets/` | `audio/assets/sfx/passos_01.wav` |
| Asset de 2+ módulos | `shared/` | `shared/textures/ui/fundo.png` |

---

## 4. Convenções de nomenclatura

| Elemento | Convenção | Exemplo |
| --- | --- | --- |
| Arquivos (`.gd`, `.tscn`, `.tres`) | `snake_case` | `title_screen.tscn`, `match_manager.gd` |
| Nós na cena | `PascalCase` | `PlayerCamera`, `StartButton` |
| Variáveis e funções | `snake_case` | `move_speed`, `_on_quit_pressed` |
| Constantes | `SCREAMING_SNAKE_CASE` | `FADE_IN_DURATION` |
| Funções privadas | prefixo `_` | `_play_intro()` |
| Sinais | verbo no passado, `snake_case` | `objective_completed`, `door_opened` |
| Resources customizados | `PascalCase` no `class_name` | `class_name ItemDefinition` |
| Nós únicos na cena | `%Nome` (`unique_name_in_owner`) | `%Fade`, `%QuitButton` |

Idioma: **código em inglês**, comentários e documentação em **português**, textos
de UI em **português**.

### Nomes de cenas
`<contexto>_<função>.tscn` — `title_screen.tscn`, `pause_menu.tscn`,
`creature_base.tscn`. Variantes numeradas quando fizer sentido (`sala_01.tscn`).

---

## 5. Como os módulos vão se comunicar

**Regra:** nenhum módulo de domínio chama outro diretamente. A comunicação
acontece de três formas, em ordem de preferência:

### 5.1 Sinais locais (preferido)
Quando um nó já tem referência direta (pai/filho), use `signal` + `connect`.
Ex.: o botão de sair da tela inicial já emite via `pressed` → `_on_quit_pressed()`.

### 5.2 Barramento de eventos em `shared/` (previsto)
Para eventos entre módulos que não se conhecem, a etapa de integração criará
`shared/autoload/event_bus.gd`, com sinais tipados:

```gdscript
# PLANEJADO — não implementado na Etapa 2
signal item_picked_up(item_id: StringName)
signal objective_completed(objective_id: StringName)
signal player_spotted(player: Node3D)
```

Quem emite não sabe quem escuta; quem escuta não conhece o emissor.

### 5.3 Orquestração por `match/`
O `match/` assina sinais, valida regras da partida e dispara transições de
estado. É o único ponto que "vê" vários módulos ao mesmo tempo.

**Ordem de leitura recomendada para novo código:** `shared/` → módulo de
domínio → `match/` → `ui/`.

---

## 6. O que ainda é apenas estrutura preparatória

| Item | Situação |
| --- | --- |
| `creatures/`, `items/`, `objectives/` | **Só documentação.** Nenhum script, cena ou lógica |
| `shared/autoload/event_bus.gd` | Planejado, **não existe** |
| Layout de buses de áudio | **Existe** desde a Etapa 3 (`Master`, `Music`, `SFX`, `Ambience`, `Voice`) |
| Input Map | `move_forward/back/left/right` (WASD), `move_sprint` (Shift), `move_crouch` (Ctrl) e `release_mouse` (Esc) |
| Multiplayer / rede | **Não iniciado** |
| Autoloads | `AppInfo` (Etapa 1), `GameSettings` e `UiAudio` (Etapa 3) |

**Total de código hoje:** 3 autoloads, 2 cenas de interface, o jogador
(`players/`), a sala de teste (`maps/`), a sessão de teste (`match/`), scripts de
configurações em `shared/settings/` e tema global.

---

## 6.1 Configurações (Etapa 3)

As configurações seguem a mesma regra de direção única:

```
ui/scripts/settings/*  ──►  GameSettings (shared/settings/)  ──►  motor
   (monta a tela)            (valida, salva, aplica)              (AudioServer / DisplayServer)
                                      │
                                      ├── AudioApplier
                                      └── VideoApplier
```

- A UI nunca lê nem grava `ConfigFile`; só mantém uma cópia de trabalho.
- `GameSettings` não conhece botões nem cenas.
- `SettingsSchema` não aplica nada: só descreve padrões, limites e validação.
- O arquivo fica em `user://settings.cfg` (nunca na pasta de instalação).

Detalhes e receita para adicionar parâmetros: [`CONFIGURACOES.md`](CONFIGURACOES.md).

---

## 6.2 Jogador, estados e stamina (Etapas 4–6)

```
players/scenes/player.tscn          CharacterBody3D + cápsula + Head + Camera3D
players/scripts/player_controller.gd  movimento, câmera, gravidade, configurações

match/scenes/movement_test.tscn      orquestra:
├── maps/scenes/test_room.tscn       geometria + colisão + Spawn
├── players/scenes/player.tscn       jogador no Spawn
├── Interface
│   ├── ui/scenes/hud/player_hud.tscn  barra de stamina (inferior esquerdo)
│   └── pausa (ESC): CONTINUAR / CONFIGURAÇÕES / MENU
└── SettingsLayer                    ui/scenes/settings_screen.tscn em modo embutido
```

Estados (`players/scripts/player_controller.gd`):

```
IDLE ◄─► WALKING ◄─► RUNNING
  ▲          ▲
  └──────── CROUCHING ◄── Ctrl tem prioridade sobre Shift
```

- `players/` continua dependendo só de `shared/`: não conhece a sala.
- `maps/` expõe geometria e um `Marker3D` de spawn; não conhece o jogador.
- `match/` é o único que instancia os dois juntos e controla a sessão.
- A UI da tela inicial apenas troca de cena por caminho; não importa classes de
  gameplay.
- A sensibilidade, a inversão vertical e o modo de agachamento são lidos de
  `GameSettings` e reaplicados no sinal `applied`.
- A stamina (Etapa 6) vive no próprio controlador: 100 máx., consumo de 20/s só
  em `RUNNING`, recuperação de 15/s nos demais estados e retorno da corrida em
  20. O gancho `set_sprint_allowed()` da Etapa 5 continua sendo o único caminho
  para bloquear/liberar a corrida.
- A HUD (`ui/scenes/hud/`) escuta `stamina_changed` e lê `get_stamina()` /
  `get_max_stamina()` por `bind_player(Node)` — sem importar `players/` e sem
  guardar stamina própria. Nenhuma regra de gameplay mora em `ui/`.
- A tela de configurações é **a mesma** nos dois fluxos: sozinha (menu inicial)
  ou embutida na pausa (`set_embedded(true)`), emitindo `back_requested` em vez
  de trocar de cena. Nenhum estado da partida é perdido.

## 6.3 Interação (Etapa 7)

```
shared/interaction/interactable.gd        contrato: can_interact / get_interaction_text / interact

players/scenes/player.tscn
└── Head/Camera/InteractionDetector       raycast do centro da câmera, 2,5 m, LOS
        │  focus_changed / focus_text_changed (sinais)
        ▼
ui/scenes/hud/player_hud.tscn
└── InteractionPrompt                     “[E] Interagir” (nó único, sem UI por frame)

maps/scenes/interaction_test_panel.tscn   objeto de teste (InteractionTestPanel)
match/scripts/movement_test.gd            liga HUD ↔ detector; suspende na pausa
```

- O **objeto** executa a própria ação. O detector só pergunta “é interativo?”,
  “pode agora?” e chama `interact()`; não existe verificação de tipo concreto.
- O raio parte de `camera.global_position` na direção `-basis.z`, com máscara de
  física padrão 1 (mundo), excluindo o corpo do jogador. O primeiro corpo
  atingido define a linha de visão: parede/caixa bloqueia.
- A distância máxima (**2,5 m**) fica em `InteractionDetector`, em uma única
  constante (`DEFAULT_INTERACTION_DISTANCE`) exportada como `interaction_distance`.
  Não há opção nas configurações.
- A ação `interact` vem do InputMap (`physical_keycode` 69 = E). O detector usa
  `Input.is_action_pressed`, com borda própria — nunca `Input.is_key_pressed`.
- A HUD continua sem importar `players/`: `bind_interaction(detector: Node)` usa
  apenas os sinais e `get_current_interactable()`.
- Na pausa/configurações a detecção é suspensa (`set_detection_enabled(false)`
  via `match/`), a indicação é escondida, `interact` não roda e o foco é
  preservado para a retomada.

## 6.4 Inventário (Etapa 8)

```
shared/items/item_definition.gd            ItemDefinition (Resource: id + display_name)

players/scenes/player.tscn
├── Inventory                              Inventory (3 slots, API, sinais)
│   └── InventorySlot × 3                  item + estado de cada slot
└── InventoryInput                         teclas 1/2/3 e R (InputMap)

items/scenes/inventory_test_item.tscn      InventoryTestItem extends Interactable

ui/scenes/hud/inventory_bar.tscn           InventoryBar (3 slots + realce)
ui/scenes/hud/player_hud.tscn              barra + aviso "INVENTÁRIO CHEIO"

match/scripts/movement_test.gd             liga HUD ↔ inventário; pausa a entrada
```

- O inventário é **dado**: não desenha, não lê teclado e não processa por frame.
  `ui/` observa os sinais `inventory_changed`, `selection_changed` e
  `item_rejected`.
- A entrada (`InvInput`) lê o **InputMap** (`inventory_slot_1..3`,
  `inventory_remove`) com borda própria; nenhuma tecla é codificada.
- O item pegável (`items/`) pede o inventário ao ator por contrato
  (`actor.get_inventory()`) e só esconde a si mesmo quando o `add_item()`
  devolve sucesso — `items/` não importa `players/`.
- `ItemDefinition` vive em `shared/` porque é o tipo comum entre `players/`,
  `items/` e `ui/`, do mesmo jeito que `Interactable`.
- A pausa desliga `InteractionDetector` e `InventoryInput`; seleção, remoção e
  coleta ficam bloqueadas e o estado é preservado.

## 6.5 Itens soltos no mundo (Etapa 9)

```
shared/mapping/space_probe.gd              SpaceProbe (piso + espaço + visão)

players/scenes/player.tscn
└── Head/Camera
    ├── InteractionDetector                (Etapa 7, inalterado)
    └── ItemDropper                        decide e executa o drop
        └── world_item_scene ────────────► items/scenes/world_item.tscn
                                             WorldItem extends Interactable
                                             └── RigidBody3D (colisão + física)

ui/scenes/hud/player_hud.tscn              painel de aviso reaproveitado
```

- `SpaceProbe` é geometria de física pura em `shared/` (não conhece item nem
  jogador) e responde "dá ou não dá" com o motivo.
- `ItemDropper` fica na câmera do jogador: lê o slot selecionado, valida a
  posição, instancia o item e **só depois** remove do inventário. Se qualquer
  passo falhar, o item continua no slot.
- `WorldItem` vive em `items/`, usa o contrato `Interactable` da Etapa 7 e
  `add_item()` da Etapa 8; não importa `players/`.
- A HUD escuta `drop_blocked` e mostra o texto no mesmo painel de aviso da
  Etapa 8 — não existe segunda barra nem estado duplicado.
- A pausa desliga `InventoryInput` (G, 1/2/3, R) e o `InteractionDetector` (E).

Detalhes: [`ETAPA-4.md`](ETAPA-4.md), [`ETAPA-5.md`](ETAPA-5.md),
[`ETAPA-6.md`](ETAPA-6.md), [`ETAPA-7.md`](ETAPA-7.md),
[`ETAPA-8.md`](ETAPA-8.md) e [`ETAPA-9.md`](ETAPA-9.md).

---

## 7. O que foi preservado da Etapa 1

A Etapa 2 **moveu** arquivos para os módulos; o conteúdo é idêntico.

| Antes (Etapa 1) | Depois (Etapa 2) |
| --- | --- |
| `scenes/boot/title_screen.tscn` | `ui/scenes/title_screen.tscn` |
| `scripts/ui/title_screen.gd` | `ui/scripts/title_screen.gd` |
| `scripts/autoload/app_info.gd` | `shared/autoload/app_info.gd` |
| `assets/themes/black_sight.tres` | `shared/themes/black_sight.tres` |
| `assets/fonts/cinzel/` | `shared/fonts/cinzel/` |
| `assets/textures/branding/` | `shared/textures/branding/` |
| `assets/textures/ui/` | `shared/textures/ui/` |
| `assets/textures/fx/` | `shared/textures/fx/` |

Preservados sem alteração de comportamento: resolução 1920×1080 (stretch
`canvas_items`/`keep`), renderizador GL Compatibility, VSync, tema, fontes,
ícone, boot splash, fade de entrada, animação de respiração do emblema,
partículas de poeira, vinheta, F11 e botão **SAIR DO JOGO**.
