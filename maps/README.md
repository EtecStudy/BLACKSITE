# Módulo `maps/`

**Responsabilidade:** mapas, salas e ambientes — geometria, iluminação, pontos
de spawn, portas e transições de área.

**Estado atual (Etapa 11):** existe **uma sala de teste** para validar o
controlador em primeira pessoa e uma **biblioteca modular de peças** de salas.

| Caminho | O que é |
| --- | --- |
| `maps/scenes/test_room.tscn` | Sala 24 × 24 m: piso, paredes, pilares, caixas, luzes e `Spawn` |
| `maps/scenes/modular_demo_room.tscn` | Cenário da demonstração modular (salas, corredores, mezanino e escada) |
| `maps/modular/walls/` | Paredes retas (2 m/4 m), porta, abertura, cantos interno/externo e pilastra |
| `maps/modular/floors/` | Piso 2 × 2 m com topo em `y = 0` |
| `maps/modular/corridors/` | Corredor reto, canto e junção em T |
| `maps/modular/rooms/` | Sala quadrada 10 × 10 m e sala retangular 10 × 14 m |
| `maps/modular/stairs/` | Escada reta: 4 m de subida em 6 m (33,7°) |
| `maps/modular/structure/` | Pilar e guarda-corpo de 2 m |
| `maps/modular/materials/` | Os quatro materiais compartilhados por todas as peças |

Convenções de grade, origens, medidas e instruções de encaixe estão em
[`docs/ETAPA-11.md`](../docs/ETAPA-11.md).

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
