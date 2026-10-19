# Black Sight — Arquitetura do projeto

Documento de referência da organização interna (Etapa 2).
Motor: **Godot 4.7.2**, renderizador **GL Compatibility**.

Regra de ouro: **cada pasta de módulo tem uma responsabilidade única**, e as
dependências apontam sempre em uma direção só.

---

## 1. Visão geral

```
BlackSight/
├── project.godot              # configuração da engine (nome, cena inicial, tema, autoload)
├── export_presets.cfg         # presets de exportação (Windows, Linux)
├── players/                   # jogadores (estrutura)
├── creatures/                 # criaturas e IA (estrutura)
├── maps/                      # mapas, salas e ambientes (estrutura)
├── items/                     # itens, inventário e interação (estrutura)
├── objectives/                # objetivos e progressão (estrutura)
├── match/                     # fluxo e estados da partida (estrutura)
├── ui/                        # menus, HUD — contém a tela inicial atual
├── audio/                     # áudio ambiente, SFX e voz (estrutura)
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
| `players/` | Controlador em primeira pessoa, câmera, input, visão/lanterna, atributos | apenas `README.md` |
| `creatures/` | Criaturas: percepção, máquina de estados, patrulha, perseguição, spawn | apenas `README.md` |
| `maps/` | Mapas, salas, iluminação, portas, pontos de spawn | apenas `README.md` |
| `items/` | Definição de itens, inventário, coleta e objetos interativos | apenas `README.md` |
| `objectives/` | Objetivos, condições de conclusão e progressão | apenas `README.md` |
| `ui/` | Menus, HUD e tela inicial | `scenes/title_screen.tscn`, `scripts/title_screen.gd` |
| `audio/` | Áudio ambiente, efeitos sonoros e comunicação por voz | apenas `README.md` |
| `match/` | Estados e fluxo da partida; orquestração entre módulos | apenas `README.md` |
| `shared/` | Recursos e sistemas usados por 2+ módulos | autoload `AppInfo`, tema, fontes, texturas |

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
| `players/`, `creatures/`, `maps/`, `items/`, `objectives/`, `audio/`, `match/` | **Só documentação.** Nenhum script, cena ou lógica |
| `shared/autoload/event_bus.gd` | Planejado, **não existe** |
| Layout de buses de áudio | Planejado, **não existe** (projeto usa só `Master`) |
| Input Map | **Não configurado** (entra na etapa de jogador) |
| Multiplayer / rede | **Não iniciado** |
| Autoloads | Apenas `AppInfo` (Etapa 1) |

**Total de código de jogo hoje:** 2 scripts (`app_info.gd`, `title_screen.gd`) +
1 cena (`title_screen.tscn`) + 1 tema.

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
