# Black Sight — Etapa 2: Estrutura interna do projeto

Relatório da organização da arquitetura interna. A Etapa 1 foi concluída e
validada no computador do usuário (tela inicial, animações e botão de saída
funcionando).

## 1. Objetivo

Separar o projeto em **módulos por responsabilidade**, preparando a base para as
próximas etapas sem implementar nenhuma mecânica de jogo.

## 2. Estrutura final

```
BlackSight/
├── players/        jogadores
├── creatures/      criaturas e IA
├── maps/           mapas, salas e ambientes
├── items/          itens, inventário e interação
├── objectives/     objetivos e progressão
├── match/          fluxo e estados da partida
├── ui/             menus, HUD (contém a tela inicial)
├── audio/          áudio ambiente, SFX e voz
├── shared/         recursos e sistemas comuns
├── tools/          scripts de apoio (CI, geração de assets)
└── docs/           documentação
```

**Conteúdo real por módulo nesta etapa:**

| Módulo | Arquivos |
| --- | --- |
| `ui/` | `scenes/title_screen.tscn`, `scripts/title_screen.gd`, `README.md` |
| `shared/` | `autoload/app_info.gd`, `themes/black_sight.tres`, `fonts/cinzel/*`, `textures/{branding,ui,fx}/*`, `README.md` |
| `players/`, `creatures/`, `maps/`, `items/`, `objectives/`, `audio/`, `match/` | apenas `README.md` |

Nenhum script de gameplay foi criado. São **2 scripts** no projeto inteiro
(`app_info.gd` e `title_screen.gd`), ambos herdados da Etapa 1.

## 3. O que foi movido (preservação da Etapa 1)

| Antes | Depois |
| --- | --- |
| `scenes/boot/title_screen.tscn` | `ui/scenes/title_screen.tscn` |
| `scripts/ui/title_screen.gd` | `ui/scripts/title_screen.gd` |
| `scripts/autoload/app_info.gd` | `shared/autoload/app_info.gd` |
| `assets/themes/black_sight.tres` | `shared/themes/black_sight.tres` |
| `assets/fonts/cinzel/` | `shared/fonts/cinzel/` |
| `assets/textures/branding/` | `shared/textures/branding/` |
| `assets/textures/ui/` | `shared/textures/ui/` |
| `assets/textures/fx/` | `shared/textures/fx/` |

Os movimentos foram feitos com `git mv`, preservando o histórico de cada arquivo.
**O conteúdo dos arquivos não mudou** — apenas as referências de caminho
(`project.godot`, cena, tema, preset de exportação, teste de fumaça e gerador de
assets).

Preservados sem alteração de comportamento: cena inicial, animações (fade +
respiração do emblema), partículas, vinheta, tema, fontes, ícone, boot splash,
resolução 1920×1080, renderizador GL Compatibility, VSync, F11 e botão
**SAIR DO JOGO**.

## 4. Regras de dependência

```
shared/  ←  { players, creatures, maps, items, objectives, ui, audio }
match/   →  orquestra todos os módulos
ui/      →  apenas observa sinais; não altera estado de jogo
```

- Nenhum módulo de domínio importa outro módulo de domínio.
- Nenhuma dependência circular: apenas `shared/` é folha.
- `match/` é o único autorizado a conhecer vários módulos.
- Comunicação prevista: sinais locais → barramento em `shared/` → orquestração
  em `match/` (detalhado em `ARQUITETURA.md`).

## 5. Testes executados

Todos rodaram no workflow `.github/workflows/build.yml`, com o **Godot 4.7.2-stable
oficial** nos dois runners (Linux e Windows). Os resultados são lidos dos logs
de execução e reproduzidos abaixo.

### Job Linux (`ubuntu-latest`)

| # | Teste | Resultado |
| --- | --- | --- |
| 1 | Importação dos recursos (`--headless --import`) | ✅ |
| 2 | Teste de fumaça | ✅ **104 verificações aprovadas** |
| 3 | Execução da cena inicial em headless (240 frames) | ✅ |
| 4 | Renderização real sob Xvfb + OpenGL | ✅ frame capturado |
| 5 | Execução do build exportado (não-editor) | ✅ |
| 6 | Inspeção do `.pck` | ✅ 30 recursos, estrutura dos módulos |
| 7 | Validação do `.exe` (PE32+, metadados) | ✅ |
| 8 | Integridade do ZIP | ✅ |

### Job Windows (`windows-latest`)

| # | Teste | Resultado |
| --- | --- | --- |
| W1 | Importar recursos no Windows | ✅ |
| W2 | Teste de fumaça no Windows | ✅ `SMOKE TEST OK — 104 verificações` |
| W3 | Cena inicial headless (240 frames) | ✅ `[Black Sight] Tela inicial carregada — v0.2.0` |
| W4 | Exportar `BlackSight.exe` + `.pck` | ✅ |
| W5 | **Executar o `.exe` exportado** | ✅ iniciou e carregou a cena inicial |
| W6 | Abrir o `.exe` com janela | ✅ `vivo_apos_25s=True` / `titulo_janela=Black Sight` |
| W7 | Inspecionar `.pck` + metadados do `.exe` | ✅ `ProductName=Black Sight`, `FileVersion=0.2.0.0`, `FileDescription=Black Sight — Etapa 2` |

### Evidências da preservação da Etapa 1

O teste de fumaça (104 checagens) confirma, além dos módulos:

- `✓ caminho antigo removido: res://scenes/boot/title_screen.tscn` (e os demais 5);
- `✓ tela inicial está no módulo ui/` e `✓ script da tela inicial está no módulo ui/`;
- `✓ tema compartilhado está em shared/` e `✓ autoload AppInfo está em shared/`;
- `✓ módulo players ainda não tem scripts` (idem para os outros 6 preparatórios);
- cena inicial instanciada com todos os nós, botão de saída habilitado e
  **JOGAR** desabilitado;
- fonte, tema, texturas e preset de exportação intactos.

O `.pck` exportado contém exatamente os arquivos dos módulos:
`ui/scenes/title_screen.tscn.remap`, `ui/scripts/title_screen.gd(c)`,
`shared/autoload/app_info.gd(c)`, `shared/themes/black_sight.tres.remap`,
`shared/fonts/cinzel/*` e `shared/textures/**` — nada de `players/`, `creatures/`
etc., pois esses módulos só têm README (excluídos do pacote por `*.md`).

### Artefato publicado

- `BlackSight-Etapa2-Windows-x86_64.zip` — **40.574.862 bytes**
- SHA-256 do ZIP: `09007dae33d7a907a0b1631b9d56d96d6b3ee3bbf11b3d9aa6582d99af7e1fcf`
- Conteúdo: `BlackSight.exe` (109.193.728 B), `BlackSight.pck` (1.330.220 B),
  `LEIA-ME.txt`, `SHA256SUMS.txt`

### Testes NÃO realizados

- **Execução no computador do usuário** — pendente por definição; é o teste de
  aceite que o usuário fará com duplo clique.
- **Teste com GPU dedicada / múltiplos monitores** — o runner Windows do CI usa
  renderização por software.
- **Wine** — descartado (o Wine do container de desenvolvimento falha ao carregar
  o próprio Godot; não é evidência sobre o jogo).

## 6. Limitações e pendências desta etapa

- Os módulos `players/`, `creatures/`, `maps/`, `items/`, `objectives/`, `audio/`
  e `match/` contêm **apenas documentação** — nenhum script ou cena.
- O barramento de eventos (`shared/autoload/event_bus.gd`) está **planejado, não
  implementado**.
- O layout de buses de áudio não foi criado.
- O Input Map ainda não foi configurado.
- O botão **JOGAR** permanece desabilitado (decisão de escopo).

## 7. Como verificar a arquitetura

```bash
godot --headless --path . --script tools/ci/smoke_test.gd
```

O teste de fumaça falha se qualquer módulo previsto estiver ausente, sem
`README.md`, se algum caminho antigo da Etapa 1 reaparecer, ou se um módulo
marcado como "apenas estrutura" ganhar scripts fora de hora.

## 8. Documentos relacionados

- [`ARQUITETURA.md`](ARQUITETURA.md) — referência da arquitetura vigente.
- [`ETAPA-1.md`](ETAPA-1.md) — fundação do projeto.
- `README.md` de cada módulo.
