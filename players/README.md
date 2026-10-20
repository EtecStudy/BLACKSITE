# Módulo `players/`

**Responsabilidade:** tudo que pertence ao(s) jogador(es) — controlador em
primeira pessoa, câmera, entrada de input, "lanterna"/visão, atributos e estados.

**Estado atual (Etapa 5):** controlador FPS com estados de movimento
(parado, andando, correndo e agachado).

| Caminho | O que é |
| --- | --- |
| `players/scenes/player.tscn` | `CharacterBody3D` + cápsula + `Head` + `Camera3D` |
| `players/scripts/player_controller.gd` | Movimento, estados, câmera, gravidade e leitura das configurações |

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
| `CROUCHING` | Ctrl (prioridade sobre Shift) | `crouch_speed` = 1,6 m/s |

- `state_changed(previous, current)` é emitido a cada transição.
- `get_state()`, `get_state_name()`, `is_crouched()`, `speed_for_state()` e
  `get_eye_height()` são a API pública.
- Agachar reduz a cápsula de 1,8 m para 1,2 m **a partir do topo** e desce a
  câmera de 1,62 m para 1,02 m com suavização.
- `_can_stand()` impede levantar sob teto/objetos (consulta de forma).
- `sprint_allowed` / `set_sprint_allowed()` é o gancho da stamina da Etapa 6.

## O que ainda **não** existe

Stamina, pulo, interação, lanterna, dano, animações de corpo e som de passos.
Os pontos de extensão naturais:

| Próxima etapa | Onde mexer |
| --- | --- |
| Stamina | `sprint_allowed` / `set_sprint_allowed()` já existe; falta o recurso e o consumo |
| Interação | raycast na `Camera3D` + sinal para `match/` |
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
