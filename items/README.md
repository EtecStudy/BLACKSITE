# Módulo `items/`

**Responsabilidade:** itens, inventário e interação com objetos — definição de
itens, coleta, empilhamento, uso e objetos interativos do cenário.

**Estado atual (Etapa 2):** apenas estrutura/documentação. Nenhum item,
inventário ou sistema de coleta foi implementado.

## O que entra aqui

| Tipo | Local | Exemplos |
| --- | --- | --- |
| Cenas | `items/scenes/` | `pickup.tscn`, `interactable_base.tscn` |
| Scripts | `items/scripts/` | `item_definition.gd` (Resource), `inventory.gd`, `pickup.gd` |
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

1. Criar `ItemDefinition` (Resource) com campos `id`, `nome`, `icone`, `pilha`.
2. `Inventory` como nó reutilizável com sinais.
3. `pickup.tscn` usando área de detecção + `interactable_base`.

## Dependências

`items/` → `shared/` (permitido). Qualquer outra seta é proibida.
