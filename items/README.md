# Módulo `items/`

**Responsabilidade:** itens e objetos interativos do cenário — definição de
itens, coleta, empilhamento, uso e objetos do mundo.

**Estado atual (Etapa 8):** existe o **item de teste pegável**
(`InventoryTestItem`), que usa o `Interactable` da Etapa 7 e guarda o item no
inventário do jogador. O inventário em si vive em `players/scripts/inventory/`
(é estado do jogador) e o tipo de item (`ItemDefinition`) em `shared/items/`.
Nada de uso, pilha, peso, drop ou crafting.

## O que entra aqui

| Tipo | Local | Exemplos |
| --- | --- | --- |
| Cenas | `items/scenes/` | `inventory_test_item.tscn` |
| Scripts | `items/scripts/` | `inventory_test_item.gd` |
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
3. Tipos definitivos de item (`.tres`) e uso/descarte — próximas etapas.

## Dependências

`items/` → `shared/` (permitido). Qualquer outra seta é proibida.
