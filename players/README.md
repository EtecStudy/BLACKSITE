# Módulo `players/`

**Responsabilidade:** tudo que pertence ao(s) jogador(es) — controlador em primeira
pessoa, câmera, entrada de input, "lanterna"/visão, atributos e estados do jogador.

**Estado atual (Etapa 2):** apenas estrutura/documentação. Nenhum script ou cena
foi criado — a jogabilidade começa em etapa posterior.

## O que entra aqui

| Tipo | Local | Exemplos |
| --- | --- | --- |
| Cenas | `players/scenes/` | `player.tscn` (CharacterBody3D + câmera) |
| Scripts | `players/scripts/` | `player_controller.gd`, `player_camera.gd` |
| Recursos | `players/resources/` | presets de configuração do jogador |
| Assets próprios | `players/assets/` | sons de passos, textos de HUD específicos |

## Regras do módulo

- Só depende de `shared/`.
- **Não** referencia `creatures/`, `items/`, `maps/` ou `objectives/` diretamente.
  Interação (pegar item, ser visto por criatura) é comunicada por sinais e
  mediada por `match/`.
- Input deve ser declarado em `Project Settings → Input Map`, com nomes em
  `snake_case` (`move_forward`, `interact`, `flashlight`).
- Nenhum estado de partida (placar, objetivo) mora aqui — isso é `match/`.

## Como será usado nas próximas etapas

1. Etapa de jogador: criar `players/scenes/player.tscn` + controlador.
2. A câmera em primeira pessoa fica como filha do jogador (`Camera3D`).
3. O HUD correspondente **não** fica aqui: vai para `ui/hud/`.

## Dependências

`players/` → `shared/` (permitido). Qualquer outra seta é proibida.
