# Módulo `players/`

**Responsabilidade:** tudo que pertence ao(s) jogador(es) — controlador em
primeira pessoa, câmera, entrada de input, "lanterna"/visão, atributos e estados.

**Estado atual (Etapa 8):** controlador FPS com estados de movimento
(parado, andando, correndo e agachado), **stamina** na corrida,
**agachamento configurável** (ALTERNAR ou SEGURAR), **detector de interação**
(Etapa 7) e **inventário de três slots** (Etapa 8).

| Caminho | O que é |
| --- | --- |
| `players/scenes/player.tscn` | `CharacterBody3D` + cápsula + `Head` + `Camera3D` |
| `players/scripts/player_controller.gd` | Movimento, estados, câmera, gravidade e leitura das configurações |
| `players/scripts/interaction/interaction_detector.gd` | Raycast da câmera, foco e ação `interact` (Etapa 7) |
| `players/scripts/inventory/inventory.gd` | Inventário de 3 slots, API e sinais (Etapa 8) |
| `players/scripts/inventory/inventory_slot.gd` | Slot individual (um item) |
| `players/scripts/inventory/inventory_input.gd` | Teclas 1/2/3 e R pelo InputMap |

## O que está implementado

- Andar com **W A S D** relativo à orientação horizontal do corpo.
- Diagonal normalizada (mesma velocidade do movimento reto).
- Aceleração/desaceleração independente da taxa de quadros.
- Gravidade (`physics/3d/default_gravity`), `is_on_floor()`, `move_and_slide()`,
  `floor_snap_length` e `floor_stop_on_slope`.
- Mouse: yaw no corpo, pitch na cabeça, limite de **±89°**.
- Sensibilidade X/Y e inversão vertical lidas de `GameSettings`, com
  reaplicação no sinal `applied`.
- `movement_enabled` para a pausa parar o jogador sem descarregar a física.

## Estados de movimento (Etapa 5)

```gdscript
enum MovementState { IDLE, WALKING, RUNNING, CROUCHING }
```

| Estado | Regra | Velocidade |
| --- | --- | --- |
| `IDLE` | sem direção | `0` |
| `WALKING` | direção pressionada | `walk_speed` = 3,2 m/s |
| `RUNNING` | direção + Shift, sem Ctrl | `run_speed` = 5,6 m/s |
| `CROUCHING` | Ctrl (prioridade sobre Shift; ALTERNAR ou SEGURAR) | `crouch_speed` = 1,6 m/s |

- `state_changed(previous, current)` é emitido a cada transição.
- `get_state()`, `get_state_name()`, `is_crouched()`, `speed_for_state()` e
  `get_eye_height()` são a API pública.
- Agachar reduz a cápsula de 1,8 m para 1,2 m **a partir do topo** e desce a
  câmera de 1,62 m para 1,02 m com suavização.
- `_can_stand()` impede levantar sob teto/objetos (consulta de forma).
- `sprint_allowed` / `set_sprint_allowed()` continua sendo o único gancho da
  corrida — agora ligado à stamina.

## Stamina e modos de agachamento (Etapa 6)

| Parâmetro | Valor | Regra |
| --- | --- | --- |
| `max_stamina` | 100 | teto |
| `stamina_drain_rate` | 20/s | só no estado `RUNNING` |
| `stamina_recovery_rate` | 15/s | `IDLE`, `WALKING` e `CROUCHING` |
| `sprint_resume_threshold` | 20 | mínimo para liberar a corrida de novo |

- O consumo depende do **estado efetivo**, nunca da tecla: soltar Shift, parar,
  agachar ou abrir a pausa encerram a corrida e o consumo.
- Ao chegar a 0, `set_sprint_allowed(false)` derruba `RUNNING` → `WALKING` no
  mesmo frame; com Shift pressionado, a corrida volta sozinha ao recuperar 20.
- Agachado nunca corre e recupera stamina.
- API: `get_stamina()`, `get_max_stamina()`, `get_stamina_ratio()`,
  `set_stamina()`, `is_sprint_allowed()` e o sinal
  `stamina_changed(current, maximum)` (HUD futura, sem HUD nesta etapa).
- `crouch_mode` (`hold`/`toggle`) vem de `GameSettings` e é relido no sinal
  `applied`. ALTERNAR é o padrão; SEGURAR mantém o comportamento antigo.
- `_can_stand()` vale nos dois modos.

## Inventário (Etapa 8)

- `Inventory` é um nó de **dados** filho do jogador: três slots
  (`SLOT_COUNT = 3`), primeiro slot livre, remoção, substituição, seleção e
  consulta do item selecionado. Não desenha, não lê teclado e não processa por
  frame.
- `InventoryInput` lê `inventory_slot_1..3` e `inventory_remove` (R, provisória)
  do **InputMap**, com borda própria. Na pausa (`movement_enabled == false` ou
  `set_input_enabled(false)`) nada muda.
- O controlador só expõe `get_inventory()` e `get_inventory_input()`.
- A HUD escuta sinais; o módulo continua dependendo apenas de `shared/`.

## O que ainda **não** existe

Pulo, uso/descarte de item, peso, pilha, equipamentos, lanterna, dano,
animações de corpo e som de passos.
Os pontos de extensão naturais:

| Próxima etapa | Onde mexer |
| --- | --- |
| HUD de stamina | escutar `stamina_changed` em `ui/` e usar `get_stamina_ratio()` |
| Uso de item | `Inventory.get_selected_item()` + uma ação `use_item` |
| Lanterna | `SpotLight3D` filho da câmera |
| Animações | novo nó de malha filho do corpo (a câmera não muda) |

## Regras do módulo

- Só depende de `shared/` (em especial `shared/settings/`).
- **Não** referencia `creatures/`, `items/`, `maps/` ou `objectives/`.
  Interação é comunicada por sinais e mediada por `match/`.
- Input declarado em `Project Settings → Input Map`, com nomes em `snake_case`
  (`move_forward`, `move_sprint`, `move_crouch`, `release_mouse`).
- Nenhum estado de partida mora aqui — isso é `match/`.
- A cena de teste que **monta** o jogador com a sala fica em `match/`; o módulo
  `players/` não conhece mapas.

## Dependências

`players/` → `shared/` (permitido). Qualquer outra seta é proibida.
