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

Executados automaticamente pelo workflow `.github/workflows/etapa1-godot-build.yml`
em um runner Linux com **Godot 4.7.2-stable** oficial:

1. **Importação de recursos** — `godot --headless --path . --import`.
2. **Teste de fumaça** — `godot --headless --path . --script tools/ci/smoke_test.gd`,
   verificando: nome/versão do projeto, renderizador, resolução, stretch, cena
   principal, autoload, tema, carregamento das fontes, importação das texturas,
   estrutura de nós da cena inicial e preset de exportação.
3. **Execução da cena inicial em modo headless** (240 frames) com checagem do log
   por `ERROR` / `SCRIPT ERROR`.
4. **Renderização real** da cena inicial sob Xvfb + OpenGL (Mesa/llvmpipe),
   gerando frames de captura para inspeção visual.
5. **Exportação Windows** (`--export-release "Windows Desktop"`) e verificação do
   binário com `file` (PE32+ x86-64) + conferência de `BlackSight.exe` e `BlackSight.pck`.

Os resultados de cada execução ficam registrados nos logs do workflow e no
artifact `black-sight-etapa1-logs`.

> Observação importante: o executável Windows é gerado e verificado no runner
> Linux (assinatura PE, tamanho, presença do `.pck`). **A execução do `.exe` em
> um Windows real é feita pelo usuário** — este ambiente não possui Windows nem
> Wine para emular o binário.

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
