# BLACKSITE

**Black Sight** — jogo de terror em primeira pessoa, desenvolvido em **Godot 4.7.2**.

> **Status:** Etapa 2 concluída — arquitetura interna em módulos (ainda sem jogabilidade).

![Tela inicial do Black Sight](docs/screenshots/title_screen.png)

## Download do jogo (Windows)

**https://github.com/EtecStudy/BLACKSITE/releases/download/v0.2.0-etapa2/BlackSight-Etapa2-Windows-x86_64.zip**

Arquivo: `BlackSight-Etapa2-Windows-x86_64.zip` (40.574.862 bytes)

SHA-256 do ZIP: `09007dae33d7a907a0b1631b9d56d96d6b3ee3bbf11b3d9aa6582d99af7e1fcf`

1. Baixe e extraia o ZIP (mantenha `BlackSight.exe` e `BlackSight.pck` na mesma pasta).
2. Duplo clique em **BlackSight.exe**.
3. `F11` alterna tela cheia; **SAIR DO JOGO** fecha o jogo.

Requisitos: Windows 10/11 64 bits e GPU com OpenGL 3.3+ (renderizador *GL Compatibility*).

## Arquitetura

O projeto é dividido em módulos por responsabilidade. Detalhes completos em
[`docs/ARQUITETURA.md`](docs/ARQUITETURA.md).

```
players/       jogadores (estrutura)
creatures/     criaturas e IA (estrutura)
maps/          mapas, salas e ambientes (estrutura)
items/         itens, inventário e interação (estrutura)
objectives/    objetivos e progressão (estrutura)
match/         fluxo e estados da partida (estrutura)
ui/            menus, HUD — tela inicial atual
audio/         áudio ambiente, SFX e voz (estrutura)
shared/        recursos e sistemas comuns (base de todos)
```

Cada módulo tem seu próprio `README.md` com a responsabilidade, o que entra nele
e o que não entra.

## Rodar a partir do código-fonte

1. Instale o [Godot 4.7.2](https://github.com/godotengine/godot/releases/tag/4.7.2-stable) (versão padrão, sem .NET).
2. Abra o Godot → **Import** → selecione `project.godot`.
3. Pressione **F5**. A cena inicial é `ui/scenes/title_screen.tscn`.

Exportar novamente para Windows (com os export templates instalados):

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/BlackSight.exe
```

## Configuração do projeto

| Item | Valor |
| --- | --- |
| Engine | Godot 4.7.2 (GL Compatibility) |
| Resolução lógica | 1920 × 1080 (16:9) |
| Janela inicial | 1600 × 900, redimensionável |
| Stretch | `canvas_items`, aspecto `keep` |
| VSync | Ativado |
| Cena principal | `ui/scenes/title_screen.tscn` |
| Autoload | `AppInfo` (`shared/autoload/app_info.gd`) |

## Testes

O workflow [`.github/workflows/build.yml`](.github/workflows/build.yml) roda em
dois runners:

- **Linux**: importa o projeto, roda o teste de fumaça, executa a cena inicial,
  renderiza sob Xvfb/OpenGL, exporta e inspeciona o pacote.
- **Windows** (`windows-latest`): gera o `.exe`, executa o `.exe` exportado,
  abre com janela e valida metadados — é este job que publica a release.

```bash
# teste de fumaça local
godot --headless --path . --script tools/ci/smoke_test.gd
```

## Documentação

| Documento | Conteúdo |
| --- | --- |
| [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md) | Módulos, dependências, convenções, comunicação |
| [`docs/ETAPA-2.md`](docs/ETAPA-2.md) | O que mudou na Etapa 2 e resultados dos testes |
| [`docs/ETAPA-1.md`](docs/ETAPA-1.md) | Fundação do projeto (engine, resolução, cena inicial) |

## Créditos

- Fonte **Cinzel** — NDISCOVER / The Cinzel Project Authors, licença **SIL OFL 1.1**
  (`shared/fonts/cinzel/OFL.txt`).
- Assets visuais (fundo, vinheta, emblema, ícone, poeira) gerados proceduralmente
  por `tools/generate_brand_assets.py`.
- Godot Engine — MIT.
