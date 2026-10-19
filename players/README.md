# Módulo `players/`

**Responsabilidade:** tudo que pertence ao(s) jogador(es) — controlador em
primeira pessoa, câmera, entrada de input, "lanterna"/visão, atributos e estados.

**Estado atual (Etapa 4):** controlador FPS funcional.

| Caminho | O que é |
| --- | --- |
| `players/scenes/player.tscn` | `CharacterBody3D` + cápsula + `Head` + `Camera3D` |
| `players/scripts/player_controller.gd` | Movimento, câmera, gravidade e leitura das configurações |

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

## O que ainda **não** existe

Corrida, agachamento, stamina, pulo, interação, lanterna, dano, animações de
corpo e som de passos. Os pontos de extensão naturais:

| Próxima etapa | Onde mexer |
| --- | --- |
| Corrida / estados de movimento | `_physics_process` (`walk_speed` → velocidade por estado) |
| Stamina | novo recurso/atributo no controlador ou em `players/scripts/` |
| Agachamento | altura da cápsula + posição do `Head` |
| Interação | raycast na `Camera3D` + sinal para `match/` |
| Lanterna | `SpotLight3D` filho da câmera |

## Regras do módulo

- Só depende de `shared/` (em especial `shared/settings/`).
- **Não** referencia `creatures/`, `items/`, `maps/` ou `objectives/`.
  Interação é comunicada por sinais e mediada por `match/`.
- Input declarado em `Project Settings → Input Map`, com nomes em `snake_case`
  (`move_forward`, `release_mouse`).
- Nenhum estado de partida mora aqui — isso é `match/`.
- A cena de teste que **monta** o jogador com a sala fica em `match/`; o módulo
  `players/` não conhece mapas.

## Dependências

`players/` → `shared/` (permitido). Qualquer outra seta é proibida.
