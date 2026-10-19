# Módulo `match/`

**Responsabilidade:** gerenciamento das partidas — estados, fluxo de jogo,
orquestração entre módulos, início e fim de rodada.

**Estado atual (Etapa 2):** apenas estrutura/documentação. Nenhuma máquina de
estados de partida e nenhum gerenciador foram implementados.

## O que entra aqui

| Tipo | Local | Exemplos |
| --- | --- | --- |
| Scripts | `match/scripts/` | `match_manager.gd`, `match_state.gd` |
| Recursos | `match/resources/` | presets de partida |
| Cenas | `match/scenes/` | apenas se houver cena própria de partida |

## Regras do módulo

- Pode depender de `shared/` e **orquestrar** os demais módulos (é o único
  autorizado a conhecer vários módulos ao mesmo tempo).
- É aqui que uma futura máquina de estados de partida
  (`PREPARING → PLAYING → ENDED`) deve viver.
- Não contém regra de gameplay específica (movimento, dano, item): apenas
  coordena e reage a sinais.
- Não desenha UI; apenas expõe estado para `ui/`.

## Como será usado nas próximas etapas

1. `MatchManager` (autoload ou nó raiz de partida) com estados explícitos.
2. Escuta sinais dos outros módulos (`objective_completed`, `player_died`) e
   decide transições.
3. A tela inicial atual continuará sendo a porta de entrada; **não** é
   responsabilidade do `match/` desenhar menus.

## Dependências

`match/` → `shared/` e demais módulos (permitido, pois orquestra).
Nenhum módulo deve depender de `match/` diretamente — a comunicação é por sinais
e pelo barramento previsto em `shared/`.
