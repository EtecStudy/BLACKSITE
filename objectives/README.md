# Módulo `objectives/`

**Responsabilidade:** objetivos e progressão das partidas — definição de
objetivos, condições de conclusão, ordem e recompensas.

**Estado atual (Etapa 2):** apenas estrutura/documentação. Nenhum objetivo e
nenhuma progressão foram implementados.

## O que entra aqui

| Tipo | Local | Exemplos |
| --- | --- | --- |
| Scripts | `objectives/scripts/` | `objective_definition.gd` (Resource), `objective_tracker.gd` |
| Recursos | `objectives/resources/` | `objective_*.tres` |
| Cenas | `objectives/scenes/` | apenas se um objetivo exigir cena própria |

## Regras do módulo

- Só depende de `shared/`.
- Objetivo é dado (`Resource`), não código: `id`, `titulo`, `descricao`,
  `condicao`, `proximo`.
- O módulo **não** altera o mundo diretamente; ele emite
  `objective_completed(id)` e `match/` decide a consequência.
- Nada de lógica de vitória/derrota aqui — isso é `match/`.

## Como será usado nas próximas etapas

1. `ObjectiveDefinition` como `Resource` com uma condição declarativa.
2. `ObjectiveTracker` como nó instanciado pela partida, escutando sinais.
3. A UI de objetivos vive em `ui/hud/` e apenas observa o tracker.

## Dependências

`objectives/` → `shared/` (permitido). Qualquer outra seta é proibida.
