# Módulo `ui/`

**Responsabilidade:** interfaces, menus e HUD — tela inicial, menus, pausa e
HUD em jogo.

**Estado atual (Etapa 2):** já contém a **tela inicial da Etapa 1**, preservada
integralmente (mesma cena, mesmas animações, mesmo comportamento).

| Caminho | O que é |
| --- | --- |
| `ui/scenes/title_screen.tscn` | Cena inicial (fundida do antigo `scenes/boot/`) |
| `ui/scripts/title_screen.gd` | Fade de entrada, respiração do emblema, F11, botão sair |

## O que entra aqui

| Tipo | Local | Exemplos |
| --- | --- | --- |
| Cenas | `ui/scenes/` | `title_screen.tscn` (existe), `pause_menu.tscn`, `hud.tscn` |
| Scripts | `ui/scripts/` | `title_screen.gd` (existe), `hud.gd` |
| Assets próprios | `ui/assets/` | texturas exclusivas de HUD/menu |

> O tema e as fontes **não** ficam em `assets/` deste módulo: são compartilhados
> e vivem em `shared/themes/` e `shared/fonts/`.

## Regras do módulo

- Só depende de `shared/`. Para ler estado de jogo, escuta sinais — **nunca**
  altera o mundo diretamente.
- Nenhuma regra de gameplay aqui: botão que pausa apenas emite sinal.
- Nomes de arquivos em `snake_case` (`pause_menu.tscn`) e nós em `PascalCase`.
- Cena inicial continua registrada em `run/main_scene` no `project.godot`.

## Como será usado nas próximas etapas

1. HUD de inventário/objetivos consome sinais de `items/` e `objectives/`.
2. Menu de pausa escuta `match/` para saber se pode pausar.
3. Todo texto visível passa pelo tema global em `shared/themes/`.

## Dependências

`ui/` → `shared/` (permitido). Qualquer outra seta é proibida.
