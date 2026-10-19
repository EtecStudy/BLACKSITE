# Módulo `ui/`

**Responsabilidade:** interfaces, menus e HUD — tela inicial, menus, pausa e
HUD em jogo.

**Estado atual (Etapa 3):** tela inicial da Etapa 1 preservada integralmente
(mesma cena, mesmas animações, mesmo comportamento) + tela de configurações com
abas de controles, áudio e vídeo.

| Caminho | O que é |
| --- | --- |
| `ui/scenes/title_screen.tscn` | Cena inicial (fundida do antigo `scenes/boot/`) |
| `ui/scripts/title_screen.gd` | Fade, respiração do emblema, F11, CONFIGURAÇÕES, sair |
| `ui/scenes/settings_screen.tscn` | Tela de configurações (abas + rodapé de ações) |
| `ui/scripts/settings_screen.gd` | Orquestra as seções, aplicar, restaurar, voltar |
| `ui/scripts/settings/settings_section.gd` | Base das seções e helpers de layout |
| `ui/scripts/settings/controls_section.gd` | Sensibilidade, inverter eixo, controles previstos |
| `ui/scripts/settings/audio_section.gd` | Volumes de geral, efeitos, ambiente e música |
| `ui/scripts/settings/video_section.gd` | Resolução, modo de janela e VSync |

A tela de configurações não lê nem grava arquivos: ela conversa com o autoload
`GameSettings` (`shared/settings/`), que é o único dono da persistência.

## O que entra aqui

| Tipo | Local | Exemplos |
| --- | --- | --- |
| Cenas | `ui/scenes/` | `title_screen.tscn`, `settings_screen.tscn` (existem), `pause_menu.tscn`, `hud.tscn` |
| Scripts | `ui/scripts/` | `title_screen.gd`, `settings_screen.gd`, `settings/` |
| Assets próprios | `ui/assets/` | texturas exclusivas de HUD/menu |

> O tema e as fontes **não** ficam em `assets/` deste módulo: são compartilhados
> e vivem em `shared/themes/` e `shared/fonts/`.

## Regras do módulo

- Só depende de `shared/`. Para ler estado de jogo, escuta sinais — **nunca**
  altera o mundo diretamente.
- Nenhuma regra de gameplay aqui: botão que pausa apenas emite sinal.
- Nomes de arquivos em `snake_case` (`pause_menu.tscn`) e nós em `PascalCase`.
- Cena inicial continua registrada em `run/main_scene` no `project.godot`.
- Botão novo na tela inicial entra em `Content/Buttons` e usa os mesmos
  `unique_name_in_owner` dos existentes.

## Como será usado nas próximas etapas

1. HUD de inventário/objetivos consome sinais de `items/` e `objectives/`.
2. Menu de pausa escuta `match/` para saber se pode pausar.
3. Todo texto visível passa pelo tema global em `shared/themes/`.

## Dependências

`ui/` → `shared/` (permitido). Qualquer outra seta é proibida.
