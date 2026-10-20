# Módulo `maps/`

**Responsabilidade:** mapas, salas e ambientes — geometria, iluminação, pontos
de spawn, portas e transições de área.

**Estado atual (Etapa 6):** existe **uma sala de teste** para validar o
controlador em primeira pessoa (movimento, colisão, agachamento e stamina).
Não é o laboratório definitivo e não tem portas.

| Caminho | O que é |
| --- | --- |
| `maps/scenes/test_room.tscn` | Sala 24 × 24 m: piso, paredes, pilares, caixas, luzes e `Spawn` |

A sala contém **apenas geometria e colisão** — nenhum jogador é instanciado
aqui. Quem monta sala + jogador é `match/scenes/movement_test.tscn`.

## O que entra aqui

| Tipo | Local | Exemplos |
| --- | --- | --- |
| Cenas | `maps/scenes/` | `map_base.tscn`, `rooms/sala_01.tscn` |
| Scripts | `maps/scripts/` | `map_base.gd`, `door.gd`, `spawn_point.gd` |
| Recursos | `maps/resources/` | listas de salas, presets de iluminação |
| Assets próprios | `maps/assets/` | materiais, malhas e texturas de ambiente |

## Regras do módulo

- Só depende de `shared/`.
- O mapa **não** decide quando a partida começa ou termina: `match/` controla o
  fluxo. O mapa apenas expõe pontos de spawn e sinais (`door_opened`, etc.).
- Dados de layout vêm de cena (`Node3D` com marcadores), não de código rígido.
- Assets reutilizáveis por mais de um módulo vão para `shared/`, não aqui.

## Como será usado nas próximas etapas

1. `map_base.gd` com marcadores de spawn e limites (a sala de teste já expõe
   um `Marker3D` chamado `Spawn`).
2. Salas como cenas separadas, compostas por instanciação.
3. Portas como nós próprios com sinal de abertura, mediado por `match/`.

## Dependências

`maps/` → `shared/` (permitido). Qualquer outra seta é proibida.
