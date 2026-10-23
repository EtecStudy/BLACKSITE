# Módulo `creatures/`

**Responsabilidade:** criaturas e seus sistemas de comportamento — percepção,
máquina de estados de IA, patrulha, perseguição, ataque e spawn.

**Estado atual (Etapa 2):** apenas estrutura/documentação. Nenhuma criatura,
nenhum estado de IA e nenhuma lógica de perseguição foram implementados.

## O que entra aqui

| Tipo | Local | Exemplos |
| --- | --- | --- |
| Cenas | `creatures/scenes/` | `creature_base.tscn`, variantes |
| Scripts | `creatures/scripts/` | `creature_base.gd`, `perception.gd`, `states/` |
| Recursos | `creatures/resources/` | `CreatureProfile` (velocidade, alcance de visão) |
| Assets próprios | `creatures/assets/` | modelos, animações, vozes |

## Regras do módulo

- Só depende de `shared/`.
- A criatura **não** conhece o jogador como classe concreta: ela reage a alvos
  (`Node3D`) recebidos por parâmetro ou sinal, para reduzir acoplamento.
- Estado global de criaturas (quantas vivas, dificuldade) pertence a `match/`.
- Não desenha HUD; avisos visuais de perigo vão para `ui/`.

## Como será usado nas próximas etapas

1. Definir `creature_base.gd` com a máquina de estados comum.
2. Especializar comportamentos em cenas próprias (`creature_x.tscn`).
3. Dados de balanceamento em `Resource` (`CreatureProfile`) e não em constantes
   espalhadas.

## Dependências

`creatures/` → `shared/` (permitido). Qualquer outra seta é proibida.
