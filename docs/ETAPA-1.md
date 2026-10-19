# Black Sight — Etapa 1: Fundação do projeto

Jogo de terror em primeira pessoa, desenvolvido em **Godot 4.7.2**.
Este documento registra o que foi criado na Etapa 1, as decisões técnicas e os
testes realizados.

## 1. Objetivo da etapa

Criar a fundação do projeto: configuração de engine, resolução, renderizador,
cena inicial funcional e estrutura de pastas — **sem implementar jogabilidade**.

## 2. Decisões técnicas

| Item | Decisão | Motivo |
| --- | --- | --- |
| Engine | Godot **4.7.2-stable** | Versão estável atual na data da etapa |
| Nome do projeto | `Black Sight` | Nome definido pela etapa |
| Resolução lógica | **1920 × 1080 (16:9)** | Base full HD para terror em primeira pessoa |
| Janela inicial | 1600 × 900, redimensionável | Abre confortável em monitores 1080p |
| Stretch | `canvas_items` + aspecto `keep` | UI nítida em qualquer resolução, sem distorção (barras pretas em aspectos diferentes, adequado a terror) |
| Renderizador | **GL Compatibility** (`gl_compatibility`) | Compatível com GPUs integradas e placas antigas; mais seguro para distribuição ampla em terror de baixo custo visual |
| Cena principal | `res://scenes/boot/title_screen.tscn` | Cena inicial/tela-título da fundação |
| VSync | Ativado | Evita tearing e consumo desnecessário |
| Ícone / splash | Gerados a partir do emblema do jogo | Identidade visual desde o boot |

### Por que GL Compatibility (e não Forward+)?

O projeto abre mão de recursos avançados de iluminação (SSAO, SDFGI, volumétricos)
em troca de compatibilidade máxima. Para a Etapa 1 (UI 2D) o resultado é idêntico.
A troca para `Forward+` é uma alteração de uma linha em `project.godot` e pode ser
reavaliada quando as etapas de iluminação/terror 3D forem definidas.

## 3. Estrutura de pastas

```
.
├── project.godot                 # configuração da engine (nome, resolução, renderer, autoload)
├── export_presets.cfg            # preset "Windows Desktop"
├── assets/
│   ├── fonts/cinzel/             # Cinzel (SIL OFL 1.1) + licença
│   ├── themes/black_sight.tres   # tema global da UI
│   └── textures/
│       ├── branding/             # emblema, ícone (.ico/.png), boot splash
│       ├── fx/                   # sprite de poeira
│       └── ui/                   # fundo e vinheta
├── scenes/boot/title_screen.tscn # cena inicial
├── scripts/
│   ├── autoload/app_info.gd      # metadados globais (nome/versão/engine)
│   └── ui/title_screen.gd        # comportamento da tela inicial
├── tools/
│   ├── generate_brand_assets.py  # gerador dos assets de marca (Pillow)
│   └── ci/smoke_test.gd          # teste automatizado de fumaça
├── docs/
│   ├── ETAPA-1.md                # este documento
│   └── RELEASE_NOTES_ETAPA1.md   # notas da release
└── .github/workflows/etapa1-godot-build.yml  # importar → testar → exportar → release
```

As pastas `scenes/`, `scripts/` e `assets/` estão prontas para receber os
conteúdos das próximas etapas (ex.: `scenes/levels/`, `scripts/player/`,
`assets/audio/`), **sem que nada disso seja implementado agora**.

## 4. O que a cena inicial faz

- Fundo escuro com vinheta e partículas de poeira lentas (atmosfera).
- Emblema "olho" com respiração suave (alpha em loop).
- Título **BLACK SIGHT** e subtítulo.
- Botão **JOGAR** desabilitado, com a indicação “A jogabilidade começa na Etapa 2”.
- Botão **SAIR DO JOGO** (com fade de saída antes de fechar).
- Rodapé com versão, engine/renderer e atalho **F11** (tela cheia).
- Fade de entrada ao abrir.

Nenhum jogador, criatura, mapa, porta, inventário, objetivo ou multiplayer foi
implementado — conforme o escopo.

## 5. Testes realizados

Todos executados automaticamente pelo workflow
`.github/workflows/etapa1-godot-build.yml`, com o **Godot 4.7.2-stable oficial**
(o mesmo binário usado para exportar).

### Job Linux (`ubuntu-latest`)

| # | Teste | Resultado |
| --- | --- | --- |
| 1 | Importação dos recursos (`--headless --import`) | ✅ |
| 2 | Fumaça (`tools/ci/smoke_test.gd`) — 68 verificações | ✅ 68/68 |
| 3 | Execução da cena inicial em headless (240 frames) | ✅ |
| 4 | Renderização real sob Xvfb + OpenGL (llvmpipe) | ✅ frame capturado |
| 5 | Execução do **build exportado** (não-editor) sob Xvfb | ✅ |
| 6 | Inspeção do `.pck` (diretório do pacote) | ✅ conteúdo correto |
| 7 | Validação do `.exe` (PE32+ x86-64, metadados) | ✅ |
| 8 | Conteúdo e integridade do ZIP | ✅ |

### Job Windows (`windows-latest`) — validação final

| # | Teste | Resultado real |
| --- | --- | --- |
| W1 | Importar recursos no Windows | ✅ |
| W2 | Teste de fumaça no Windows | ✅ `SMOKE TEST OK — 68 verificações` |
| W3 | Executar a cena inicial (headless, 240 frames) | ✅ `[Black Sight] Tela inicial carregada` |
| W4 | Exportar `BlackSight.exe` + `BlackSight.pck` | ✅ |
| W5 | **Executar o `.exe` exportado** no Windows | ✅ iniciou e carregou a cena inicial |
| W6 | Abrir o `.exe` com janela | ✅ janela "Black Sight" viva após 25 s |
| W7 | Inspecionar `.pck` e metadados do `.exe` | ✅ `ProductName=Black Sight`, `FileVersion=0.1.0.0`, `CompanyName=EtecStudy` |

Artefato publicado (gerado pelo job Windows):

- `BlackSight-Etapa1-Windows-x86_64.zip` — 40.574.790 bytes
- SHA-256: `aee6340f93162f89b7e46c8433d9d2f6ff4f5abea2218391da0dec7a6ed64672`
- Conteúdo: `BlackSight.exe` (109.193.728 B), `BlackSight.pck` (1.330.208 B),
  `LEIA-ME.txt`, `SHA256SUMS.txt`

### Testes que NÃO foram realizados

- **Execução no seu computador** — é exatamente o teste que fica pendente com
  você. O CI prova que o `.exe` roda em Windows Server 2022 (runner
  `windows-latest`); GPU, driver e versão do seu Windows só o teste local
  confirma.
- **Execução do `.exe` via Wine** — tentada em ciclos anteriores e **removida**:
  o Wine do container falha no próprio carregamento do Godot
  (`page fault`), o que não indica problema no jogo. Substituída pelo job
  Windows real, que é uma validação legítima.
- **Teste em placa de vídeo dedicada / múltiplos monitores** — o runner usa
  renderização por software/Mesa.

## 6. Como abrir e rodar no editor

1. Instale o **Godot 4.7.2** (ou 4.7.x) — versão padrão, sem .NET.
2. Abra o Godot → *Import* → selecione o arquivo `project.godot` deste repositório.
3. Pressione **F5** (ou o botão ▶) para rodar a cena inicial.

## 7. Como gerar o executável novamente

No editor: *Project → Export… → Windows Desktop → Export Project*.
Ou pela linha de comando (com os export templates instalados):

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/BlackSight.exe
```

O resultado são dois arquivos que devem ficar juntos: `BlackSight.exe` e `BlackSight.pck`.

## 8. Pendências conhecidas

- O botão **JOGAR** está intencionalmente desabilitado (jogabilidade é Etapa 2+).
- O `.exe` precisa ser validado em um Windows real pelo usuário.
- Nenhum asset de áudio foi incluído nesta etapa (não faz parte do escopo).
