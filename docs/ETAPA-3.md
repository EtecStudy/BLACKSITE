# Black Sight — Etapa 3: Configurações básicas do projeto

Relatório da Etapa 3. As Etapas 1 e 2 foram concluídas e validadas
anteriormente (tela inicial, animações, arquitetura em módulos).

## 1. Objetivo

Dar ao jogador controle real sobre **teclado/mouse**, **áudio** e **vídeo**,
com os valores guardados entre execuções — sem implementar nenhuma mecânica de
jogo. Também era obrigatório não fingir funcionalidade: nada de opções que não
fazem nada.

## 2. O que foi entregue

### 2.1 Controles (teclado/mouse)

- Sensibilidade horizontal e vertical do mouse: `0.1` a `5.0`, passo `0.05`,
  padrão `1.00×`.
- Inverter eixo vertical (padrão: desligado).
- Lista dos controles padrão **previstos** (WASD, mouse, Shift, E, F, Esc),
  marcada na tela como referência para a etapa futura.
- Os valores são gravados e ficam prontos para o controlador do jogador.
  **Nenhuma movimentação é aplicada nesta etapa** — a tela diz isso.

### 2.2 Áudio

- Layout de buses em `audio/default_bus_layout.tres`:
  `Master` → `Music`, `SFX`, `Ambience`, `Voice`.
- Volumes de geral (80%), efeitos (80%), ambiente (70%) e música (60%), em
  porcentagem, com o valor numérico sempre visível ao lado do slider.
- Aplicação imediata (`linear_to_db`; `0%` silencia o bus) para pré-visualização.
- Dois sons originais de interface, sintetizados por
  `tools/generate_ui_sounds.py`, tocam no bus `SFX`:
  clique de botão e confirmação de aplicar. Servem para o ajuste de volume ser
  percebido de verdade.
- Categorias **sem sons** nesta etapa (escrito na própria tela): música,
  ambiente e voz. Os buses existem e os volumes são salvos.

### 2.3 Vídeo

- Modo de janela: **janela**, **janela maximizada** e **tela cheia**.
- Resoluções oferecidas: 1280×720, 1366×768, 1600×900, 1920×1080, 2560×1440 e
  3840×2160, filtradas pelo tamanho útil do monitor atual.
- VSync ligado/desligado (quando o driver respeita).
- Aplicação apenas ao clicar em **APLICAR** — dá para desistir sem mudar a janela.
- Segurança: toda resolução vinda do arquivo é limitada entre 1024×576 e o
  tamanho útil da tela; a proporção é preservada pelo stretch
  `canvas_items`/`keep`; `F11` funciona em qualquer tela; **RESTAURAR PADRÕES**
  está sempre visível.

### 2.4 Interface

- Botão **CONFIGURAÇÕES** na tela inicial, entre **JOGAR** e **SAIR DO JOGO**.
- Tela própria (`ui/scenes/settings_screen.tscn`) com as abas **Controles**,
  **Áudio** e **Vídeo**, painel com a mesma identidade visual (fundo, vinheta,
  poeira, Cinzel) e rodapé com **RESTAURAR PADRÕES**, **VOLTAR** e **APLICAR**.
- Mensagem de estado no rodapé ("alterações pendentes", "aplicadas e salvas").
- `Esc` volta ao menu; `F11` continua alternando tela cheia.
- **Preservados sem alteração**: emblema, animações de fade e respiração,
  partículas, vinheta, título, versão no rodapé e botão **SAIR DO JOGO**.

### 2.5 Persistência

- `ConfigFile` em `user://settings.cfg` → `%APPDATA%\BlackSight\settings.cfg`.
  Nunca na pasta de instalação.
- Carregamento na inicialização; arquivo ausente → padrões (e criação na
  primeira execução); arquivo inválido → padrões + aviso no log, sem impedir a
  abertura.
- Toda leitura passa por `SettingsSchema.sanitize()`: tipo correto, dentro dos
  limites, chaves ausentes preenchidas com o padrão.
- Gravação ao **APLICAR**; **RESTAURAR PADRÕES** repõe e grava; falha de
  escrita não derruba o jogo (só avisa).
- Estrutura extensível e documentada em [`CONFIGURACOES.md`](CONFIGURACOES.md).

## 3. Arquitetura da etapa

| Arquivo | Responsabilidade |
| --- | --- |
| `shared/settings/settings_schema.gd` | Esquema: padrões, limites, `sanitize`, descrição |
| `shared/settings/game_settings.gd` | Autoload `GameSettings`: ler, validar, aplicar, salvar |
| `shared/settings/audio_applier.gd` | Percentual → dB nos buses |
| `shared/settings/video_applier.gd` | Janela, resolução, VSync e limites de segurança |
| `audio/default_bus_layout.tres` | Buses do projeto |
| `audio/scripts/ui_audio.gd` | Autoload `UiAudio`: clique e confirmação |
| `ui/scenes/settings_screen.tscn` | Tela de configurações |
| `ui/scripts/settings_screen.gd` | Orquestração das seções e navegação |
| `ui/scripts/settings/settings_section.gd` | Base e helpers de layout |
| `ui/scripts/settings/controls_section.gd` | Seção CONTROLES |
| `ui/scripts/settings/audio_section.gd` | Seção ÁUDIO |
| `ui/scripts/settings/video_section.gd` | Seção VÍDEO |
| `tools/ci/smoke_test.gd` | Testes de configuração, persistência, áudio, vídeo e cenas |
| `tools/ci/ui_flow_test.gd` | Navegação real: menu → configurações → abas → aplicar → voltar |

A UI não conhece `ConfigFile`; o gerenciador não conhece botões. Cada seção
devolve apenas o seu fragmento de configuração.

## 4. Testes executados

_(a preencher com os resultados reais da execução do workflow)_

## 5. Teste no Windows real

_(a preencher com os resultados reais do job Windows)_

## 6. Limitações e pendências desta etapa

- Sem jogador/movimentação: sensibilidade e inversão ficam salvas, sem efeito
  visível (por definição do escopo).
- Música, ambiente e voz não têm sons; os volumes só terão efeito auditivo
  quando esses sistemas existirem.
- VSync pode ser ignorado por alguns drivers em GL Compatibility.
- "Janela maximizada" não guarda o tamanho anterior da janela.
- Não há remapeamento de teclas nesta etapa.

## 7. Como verificar manualmente

1. Abra `BlackSight.exe`, clique em **CONFIGURAÇÕES**.
2. Aba **Áudio**: mova os sliders (o clique da interface muda de volume) →
   **APLICAR**. Feche e reabra: os valores continuam iguais.
3. Aba **Vídeo**: escolha **Tela cheia** → **APLICAR**; pressione `F11` para
   voltar. Feche e reabra: o modo escolhido é reaplicado.
4. **RESTAURAR PADRÕES** → **APLICAR**; feche e reabra: tudo volta ao padrão.
5. **VOLTAR** retorna ao menu; **SAIR DO JOGO** continua fechando o jogo.
6. Confira o arquivo em `%APPDATA%\BlackSight\settings.cfg`.

## 8. Documentos relacionados

- [`CONFIGURACOES.md`](CONFIGURACOES.md) — onde ficam as configurações e como
  adicionar parâmetros.
- [`ARQUITETURA.md`](ARQUITETURA.md) — módulos e dependências.
- [`RELEASE_NOTES_ETAPA3.md`](RELEASE_NOTES_ETAPA3.md) — notas da release.
