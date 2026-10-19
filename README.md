# BLACKSITE

**Black Sight** — jogo de terror em primeira pessoa, desenvolvido em **Godot 4.7.2**.

> **Status:** Etapa 1 concluída — fundação do projeto (sem jogabilidade ainda).

![Tela inicial do Black Sight](docs/screenshots/title_screen.png)

## Download do jogo (Windows)

**https://github.com/EtecStudy/BLACKSITE/releases/download/v0.1.0-etapa1/BlackSight-Etapa1-Windows-x86_64.zip**

SHA-256: `aee6340f93162f89b7e46c8433d9d2f6ff4f5abea2218391da0dec7a6ed64672`

1. Baixe e extraia o ZIP (mantenha `BlackSight.exe` e `BlackSight.pck` na mesma pasta).
2. Duplo clique em **BlackSight.exe**.
3. `F11` alterna tela cheia; **SAIR DO JOGO** fecha o jogo.

Requisitos: Windows 10/11 64 bits e GPU com OpenGL 3.3+ (renderizador *GL Compatibility*).

## Rodar a partir do código-fonte

1. Instale o [Godot 4.7.2](https://github.com/godotengine/godot/releases/tag/4.7.2-stable) (versão padrão, sem .NET).
2. Abra o Godot → **Import** → selecione `project.godot`.
3. Pressione **F5**. A cena inicial é `scenes/boot/title_screen.tscn`.

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
| Cena principal | `scenes/boot/title_screen.tscn` |

## Estrutura

```
assets/     fontes, tema e texturas (branding, ui, fx)
scenes/     cenas do jogo (boot/ = cena inicial)
scripts/    código GDScript (autoload/, ui/)
tools/      gerador de assets e teste de fumaça do CI
docs/       documentação da etapa
```

Detalhes completos: [`docs/ETAPA-1.md`](docs/ETAPA-1.md).

## Testes

O workflow [`.github/workflows/etapa1-godot-build.yml`](.github/workflows/etapa1-godot-build.yml)
roda em dois runners:

- **Linux**: importa o projeto, roda o teste de fumaça, executa a cena inicial,
  renderiza sob Xvfb/OpenGL, exporta e inspeciona o pacote.
- **Windows** (`windows-latest`): gera o `.exe`, executa o `.exe` exportado,
  abre com janela e valida metadados — é este job que publica a release.

```bash
# teste de fumaça local
godot --headless --path . --script tools/ci/smoke_test.gd
```

## Créditos

- Fonte **Cinzel** — NDISCOVER / The Cinzel Project Authors, licença **SIL OFL 1.1**
  (`assets/fonts/cinzel/OFL.txt`).
- Assets visuais (fundo, vinheta, emblema, ícone, poeira) gerados proceduralmente
  por `tools/generate_brand_assets.py`.
- Godot Engine — MIT.
