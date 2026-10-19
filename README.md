# BLACKSITE

**Black Sight** — jogo de terror em primeira pessoa, desenvolvido em **Godot 4.7.2**.

> **Status:** Etapa 3 concluída — configurações de controles, áudio e vídeo
> (ainda sem jogabilidade).

![Tela inicial do Black Sight](docs/screenshots/title_screen.png)

## Download do jogo (Windows)

**https://github.com/EtecStudy/BLACKSITE/releases/download/v0.3.0-etapa3/BlackSight-Etapa3-Windows-x86_64.zip**

Arquivo: `BlackSight-Etapa3-Windows-x86_64.zip` (TAMANHO_BYTES bytes)

SHA-256 do ZIP: `SHA256_ZIP`

1. Baixe e extraia o ZIP (mantenha `BlackSight.exe` e `BlackSight.pck` na mesma pasta).
2. Duplo clique em **BlackSight.exe**.
3. **CONFIGURAÇÕES** abre a tela de ajustes; `F11` alterna tela cheia;
   **SAIR DO JOGO** fecha o jogo.

Requisitos: Windows 10/11 64 bits e GPU com OpenGL 3.3+ (renderizador *GL Compatibility*).

## O que existe hoje

- Tela inicial com emblema, fade, partículas, vinheta e botão de saída (Etapa 1).
- Arquitetura em módulos por responsabilidade (Etapa 2).
- **Tela de configurações** com abas:
  - **Controles** — sensibilidade horizontal/vertical do mouse, inverter eixo
    vertical e a lista dos controles padrão previstos.
  - **Áudio** — volume geral, efeitos, ambiente e música (buses reais, com
    pré-visualização ao mover o controle).
  - **Vídeo** — resolução, modo de janela (janela / maximizada / tela cheia) e
    VSync, com limites de segurança para nunca deixar a janela inacessível.
- Botões **APLICAR**, **RESTAURAR PADRÕES** e **VOLTAR**; valores salvos em
  `%APPDATA%\BlackSight\settings.cfg` e mantidos entre execuções.

Ainda **não** existe: jogador, movimentação, mapa, inventário, objetivos,
criaturas, multiplayer ou voz. Ver [`docs/ETAPA-3.md`](docs/ETAPA-3.md).

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
ui/            menus, HUD — tela inicial e configurações
audio/         buses de áudio e sons da interface
shared/        recursos e sistemas comuns (base de todos)
```

Cada módulo tem seu próprio `README.md` com a responsabilidade, o que entra nele
e o que não entra.

## Configurações

Documentação completa em [`docs/CONFIGURACOES.md`](docs/CONFIGURACOES.md).

| Item | Onde |
| --- | --- |
| Arquivo do usuário | `user://settings.cfg` → `%APPDATA%\BlackSight\settings.cfg` |
| Esquema, padrões e limites | `shared/settings/settings_schema.gd` |
| Leitura, gravação e aplicação | `shared/settings/game_settings.gd` (autoload `GameSettings`) |
| Aplicação de áudio | `shared/settings/audio_applier.gd` |
| Aplicação de vídeo | `shared/settings/video_applier.gd` |
| Buses | `audio/default_bus_layout.tres` |
| Tela | `ui/scenes/settings_screen.tscn` |

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
| Autoloads | `AppInfo`, `GameSettings`, `UiAudio` |
| Buses de áudio | `Master`, `Music`, `SFX`, `Ambience`, `Voice` |

## Testes

O workflow [`.github/workflows/build.yml`](.github/workflows/build.yml) roda em
dois runners:

- **Linux**: importa o projeto, roda o teste de fumaça, o teste de fluxo da
  interface, executa a cena inicial, renderiza sob Xvfb/OpenGL, exporta e
  inspeciona o pacote.
- **Windows** (`windows-latest`): gera o `.exe`, executa o `.exe` exportado,
  abre com janela e valida metadados — é este job que publica a release.

```bash
# teste de fumaça (configuração, cenas, persistência, áudio, limites de vídeo)
godot --headless --path . --audio-driver Dummy res://tools/ci/smoke_test.tscn

# fluxo real de interface (abrir configurações, abas, aplicar, restaurar, voltar, F11)
godot --headless --path . --fixed-fps 60 res://tools/ci/ui_flow_test.tscn
```

## Documentação

| Documento | Conteúdo |
| --- | --- |
| [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md) | Módulos, dependências, convenções, comunicação |
| [`docs/CONFIGURACOES.md`](docs/CONFIGURACOES.md) | Onde ficam as configurações e como adicionar parâmetros |
| [`docs/ETAPA-3.md`](docs/ETAPA-3.md) | O que mudou na Etapa 3 e resultados dos testes |
| [`docs/ETAPA-2.md`](docs/ETAPA-2.md) | Estrutura interna em módulos |
| [`docs/ETAPA-1.md`](docs/ETAPA-1.md) | Fundação do projeto (engine, resolução, cena inicial) |

## Créditos

- Fonte **Cinzel** — NDISCOVER / The Cinzel Project Authors, licença **SIL OFL 1.1**
  (`shared/fonts/cinzel/OFL.txt`).
- Assets visuais (fundo, vinheta, emblema, ícone, poeira) gerados proceduralmente
  por `tools/generate_brand_assets.py`.
- Sons de interface gerados proceduralmente por `tools/generate_ui_sounds.py`.
- Godot Engine — MIT.
