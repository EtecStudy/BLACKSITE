# Módulo `shared/`

**Responsabilidade:** sistemas e recursos compartilhados entre módulos.
É o nível mais baixo da arquitetura: **não depende de nenhum outro módulo**.

## Estado atual (Etapa 2): conteúdo real

| Caminho | O que é |
| --- | --- |
| `shared/autoload/app_info.gd` | Autoload `AppInfo` — nome, versão e engine do build (criado na Etapa 1) |
| `shared/themes/black_sight.tres` | Tema global da interface (Etapa 1) |
| `shared/fonts/cinzel/` | Fontes Cinzel + licença SIL OFL 1.1 (Etapa 1) |
| `shared/textures/branding/` | Emblema, ícone (.ico/.png) e boot splash (Etapa 1) |
| `shared/textures/ui/` | Fundo e vinheta usados pela tela inicial (Etapa 1) |
| `shared/textures/fx/` | Sprite de poeira para partículas (Etapa 1) |

## O que pode entrar aqui no futuro

- Barramento de eventos (`event_bus.gd`) para comunicação entre módulos sem
  acoplamento direto.
- Constantes globais, enums e utilitários puros (`math_utils.gd`).
- Recursos usados por 2+ módulos (um ícone usado por `items/` e `ui/`).

**Nunca** coloque aqui regra de gameplay, estado de partida ou algo específico de
um único módulo.

## Regras do módulo

- `shared/` **não** importa nada de `players/`, `creatures/`, `maps/`, `items/`,
  `objectives/`, `ui/`, `audio/` ou `match/`.
- Utilitários devem ser funções puras, sem efeitos colaterais.
- Assets aqui precisam ser efetivamente compartilhados; assets de um módulo só
  ficam no módulo.

## Dependências

Nenhuma. Todos os módulos podem depender de `shared/`, e só dele (exceto
`match/`, que orquestra).
