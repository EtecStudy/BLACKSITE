# Módulo `items/`

**Responsabilidade:** itens e objetos interativos do cenário — definição de
itens, coleta, empilhamento, uso e objetos do mundo.

**Estado atual (Etapa 9):** existem duas representações de item — o **item de
teste** (`InventoryTestItem`, Etapa 8) e o **item solto** (`WorldItem`, Etapa 9),
que usa um `RigidBody3D` e volta ao inventário com E. Os dois herdam de
`Interactable` (Etapa 7). O inventário vive em `players/scripts/inventory/` (é
estado do jogador) e o tipo de item (`ItemDefinition`) em `shared/items/`.
Nada de uso, pilha, peso, arremesso, transferência ou crafting.

## O que entra aqui

| Tipo | Local | Exemplos |
| --- | --- | --- |
| Cenas | `items/scenes/` | `inventory_test_item.tscn`, `world_item.tscn` |
| Scripts | `items/scripts/` | `inventory_test_item.gd`, `world_item.gd` |
| Recursos | `items/resources/` | `item_*.tres` (pilha, ícone, descrição) |
| Assets próprios | `items/assets/` | ícones de inventário, modelos de item |

## Regras do módulo

- Só depende de `shared/`.
- Definição de item é um `Resource` (`ItemDefinition`), **não** um dicionário
  solto nem `enum` global — permite criar itens sem tocar em código.
- O inventário não conhece a UI: emite sinais (`inventory_changed`) e `ui/`
  escuta.
- Quem pode pegar o quê (regras da partida) é decidido em `match/`.

## Como será usado nas próximas etapas

1. ~~`ItemDefinition` com `id` e nome~~ (feito na Etapa 8).
2. ~~Inventário com sinais~~ (feito em `players/scripts/inventory/`).
3. ~~Item solto no mundo com física e recolhimento~~ (feito na Etapa 9).
4. Modelos/ícones definitivos por item (`.tres`) e uso/consumo — próximas etapas.

## Dependências

`items/` → `shared/` (permitido). Qualquer outra seta é proibida.
