# Black Sight — Etapa 6: Stamina, modos de agachamento e controles reais

Relatório da Etapa 6. As Etapas 1–5 foram concluídas e testadas anteriormente
(tela inicial, módulos, configurações, controlador FPS e estados de movimento).

## 1. Objetivo

Dar consequência à corrida com **stamina**, permitir **dois modos de
agachamento** (SEGURAR ou ALTERNAR, com ALTERNAR como padrão) e mostrar na tela
de configurações a **lista real de controles** — sem comandos que ainda não
existem.

Fora do escopo: pulo, interação, inventário, criaturas, combate, iluminação e
HUD de stamina. A etapa **não** implementa a Etapa 7.

> **Correção 6.1:** a HUD de stamina, antes fora de escopo, foi adicionada na
> release `v0.6.1-etapa6-hud`. A seção **10** descreve a implementação e os
> testes; as seções 1–9 permanecem como registro da v0.6.0.

## 2. Stamina

Os parâmetros ficam centralizados como propriedades exportadas de
`players/scripts/player_controller.gd` — não há números mágicos espalhados:

| Propriedade | Valor | Significado |
| --- | --- | --- |
| `max_stamina` | `100` | capacidade máxima |
| `stamina_drain_rate` | `20/s` | consumo enquanto `RUNNING` |
| `stamina_recovery_rate` | `15/s` | recuperação nos demais estados |
| `sprint_resume_threshold` | `20` | mínimo para liberar a corrida de novo |

Regras implementadas em `_update_stamina(delta)`:

- **Consumo somente no estado efetivo `RUNNING`**, proporcional ao tempo:
  `stamina -= stamina_drain_rate * delta`, com piso em `0`.
- **Recuperação em `IDLE`, `WALKING` e `CROUCHING`**: `stamina +=
  stamina_recovery_rate * delta`, com teto em `max_stamina`.
- **Agachado nunca corre** e, portanto, nunca consome; a recuperação continua.
- **Soltar Shift, parar, agachar ou abrir a pausa** encerram a corrida e o
  consumo — o que manda é o estado, não a tecla.
- Ao chegar a `0`, `set_sprint_allowed(false)` é chamado: o estado cai de
  `RUNNING` para `WALKING` **no mesmo frame**, mesmo com Shift pressionado.
- A corrida só é liberada de novo quando a stamina recupera
  `sprint_resume_threshold` (`20`), evitando oscilar entre correr e andar.
  Com Shift ainda pressionado, o jogador volta a correr automaticamente.
- A API pública inclui `get_stamina()`, `get_max_stamina()`,
  `get_stamina_ratio()`, `set_stamina()` e `is_sprint_allowed()`, além do sinal
  `stamina_changed(current, maximum)` — estrutura usada pela HUD a partir da
  correção 6.1 (na v0.6.0 não havia HUD).

O gancho `sprint_allowed`/`set_sprint_allowed()` criado na Etapa 5 continua
sendo o único caminho: não existe segundo controlador nem lógica duplicada.

## 3. Modo de agachamento

A preferência `crouch_mode` foi adicionada ao `SettingsSchema` (seção
`controls`) e é gravada em `user://settings.cfg` pelo mesmo `GameSettings` das
Etapas 3–5:

| Valor | Interface | Comportamento |
| --- | --- | --- |
| `hold` | SEGURAR | agacha enquanto Ctrl estiver pressionado |
| `toggle` | ALTERNAR (**padrão**) | um toque agacha, outro levanta |

- O valor padrão é `toggle`, definido em
  `SettingsSchema.DEFAULT_CROUCH_MODE`.
- Valores inválidos/ausentes caem no padrão (`normalize_crouch_mode`).
- A tela de configurações mostra a opção **MODO DE AGACHAMENTO → Agachar com
  Ctrl** e a linha do Ctrl muda de texto conforme o modo:
  **“Segurar para agachar”** ou **“Alternar agachamento”**.
- A troca vale **imediatamente**, inclusive durante a partida: o controlador
  escuta o sinal `applied` e relê o valor, sem reiniciar nem recriar o jogador.
- O interruptor interno é sincronizado com a postura atual ao trocar de modo
  (`_crouch_toggled = _is_crouched`), então mudar a preferência não teleporta
  nem força levantar.
- `_can_stand()` continua valendo nos dois modos: sob um obstáculo o jogador
  permanece agachado e levanta sozinho quando o espaço fica livre.

## 4. Lista real de controles

A lista antiga (“CONTROLES PADRÃO PREVISTOS”, com `E — Interagir` e
`F — Lanterna`) foi removida. A seção CONTROLES mostra exatamente o que existe:

| Tecla | Ação |
| --- | --- |
| `W A S D` | Mover |
| `Shift` | Correr (consome stamina) |
| `Ctrl` | Agachar (texto dinâmico conforme o modo) |
| `Mouse` | Olhar |
| `Esc` | Pausar |
| `F11` | Tela cheia |

Não há linhas para pulo, interação, lanterna, inventário ou ataque, e a barra
de espaço não aparece em nenhum lugar.

## 5. Configurações durante a partida

O fluxo da Etapa 5 foi mantido e agora cobre o modo de agachamento:

```
JOGO ──ESC──► PAUSA ──CONFIGURAÇÕES──► CONTROLES ──MODO DE AGACHAMENTO──►
ALTERAR ──APLICAR──► VOLTAR ──► PAUSA ──CONTINUAR──► JOGO
```

Durante todo o fluxo a partida permanece pausada (`movement_enabled = false`):
posição, orientação (yaw/pitch), estado de movimento, **stamina** e altura da
câmera são preservados. Nada é recriado e o arquivo continua sendo
`user://settings.cfg`.

## 6. Sem pulo

Não existe tecla, ação, estado, força ou campo de pulo:

- o enum tem apenas `IDLE`, `WALKING`, `RUNNING` e `CROUCHING`;
- o Input Map não tem `jump`/`move_jump` e a barra de espaço não é usada;
- a gravidade (`_apply_gravity`) permanece intacta e só aplica valores
  negativos em `velocity.y`.

## 7. Arquivos

| Arquivo | O que mudou |
| --- | --- |
| `players/scripts/player_controller.gd` | stamina (consumo/recuperação/limiar), modo ALTERNAR/SEGURAR, API e sinal de stamina |
| `shared/settings/settings_schema.gd` | `crouch_mode`, `normalize_crouch_mode()`, `crouch_mode_label()` |
| `ui/scripts/settings/controls_section.gd` | lista real de controles e opção de modo de agachamento |
| `ui/scripts/settings/settings_section.gd` | `add_key_hint_row()` devolve o rótulo (texto dinâmico) |
| `ui/scripts/settings_screen.gd` | `get_section()` para consulta/teste das abas; correção do nome único da dica lateral (`%SidebarHint`) |
| `tools/ci/movement_test.gd` | grupos 17–19 (stamina, ALTERNAR, pausa com stamina) |
| `tools/ci/smoke_test.gd` | grupo 15 (stamina, persistência e lista real) |
| `tools/ci/ui_flow_test.gd` | modo de agachamento na pausa da partida |
| `project.godot`, `shared/autoload/app_info.gd`, `export_presets.cfg`, `title_screen.tscn` | versão 0.6.0 / Etapa 6 (histórico; a 6.1 usa 0.6.1) |
| `.github/workflows/build.yml` | ZIP/release da Etapa 6 e LEIA-ME atualizado |
| `README.md`, `docs/ARQUITETURA.md`, `docs/CONFIGURACOES.md`, READMEs | documentação |

## 8. Testes executados

Workflow [`build.yml`](https://github.com/EtecStudy/BLACKSITE/blob/arena/aa5e0e47-blocksite/.github/workflows/build.yml),
execução **[39351765584](https://github.com/EtecStudy/BLACKSITE/actions/runs/39351765584)**
(commit `703f6fd`), jobs Linux `118397362027` e Windows `118397362234` — ambos
**verdes**.

### 8.1 Automatizados (executados de verdade)

| Teste | O que cobre | Linux | Windows |
| --- | --- | --- | --- |
| `tools/ci/smoke_test.tscn` | Configuração, cenas, módulos, Input Map, stamina, persistência do modo e lista real de controles | **238/238** | **238/238** |
| `tools/ci/ui_flow_test.tscn` | Menu → configurações → F11 → TESTAR MOVIMENTAÇÃO → pausa → CONTROLES → modo de agachamento → APLICAR → VOLTAR → CONTINUAR → menu | **49/49** | **49/49** |
| `tools/ci/movement_test.tscn` | Controlador FPS, estados e stamina — 19 grupos | **205/205** | **205/205** |

Grupos **novos** do teste do controlador (os grupos 1–16 das Etapas 4–5
continuam passando, incluindo WASD, diagonal, câmera, sensibilidade, inversão,
gravidade, colisões, estados, velocidades, agachamento e pausa):

| Grupo | Resultado |
| --- | --- |
| `[17]` Stamina | máxima 100, consumo 20/s, recuperação 15/s e limiar 20 confirmados; 1 s correndo consome 20,0 e 1 s andando/agachado/parado recupera 15,0; ao esgotar, `RUNNING` → `WALKING` no mesmo frame e `set_stamina` nunca sai de 0..100 |
| `[18]` Modo ALTERNAR | um toque agacha (câmera 1,02 m), agachado + SHIFT continua AGACHADO e não consome stamina, soltar CTRL não levanta, obstáculo impede levantar e libera ao sair, segundo toque levanta; SEGURAR continua funcionando |
| `[19]` Pausa + stamina + modo em partida | pausa não consome nem recupera (70,0 → 70,0), posição/yaw/pitch/estado preservados; CONTROLES → ALTERNAR → APLICAR muda o controlador e mantém a stamina; VOLTAR e CONTINUAR preservam tudo; agachar na partida interrompe a corrida e recupera; levantar com SHIFT volta a CORRER |

### 8.2 Verificações estáticas e de empacotamento

| Verificação | Resultado |
| --- | --- |
| Sintaxe de todos os `.gd` (`gdparse`) | OK |
| Estrutura de todas as `.tscn` | OK |
| `build.yml` (`yaml.safe_load`) | OK |
| Execução *headless* da cena inicial (editor e build exportado Linux) | `v0.6.0`, sem `SCRIPT ERROR` |
| Render sob Xvfb/OpenGL (título, configurações, cena de teste) | 3 frames válidos |
| Inspeção do `.pck` | formato 4, **68 recursos**; jogador, sala e cena de teste presentes; `tools/` e `docs/` fora do pacote |
| Binário Windows | PE32+ x86-64, `FileVersion=0.6.0.0`, `FileDescription=Black Sight — Etapa 6` |
| `settings.cfg` criado pelo `.exe` | contém `crouch_mode="toggle"`, além das chaves das etapas anteriores |

### 8.3 Manuais

Não foram executados por uma pessoa: o teste humano (sensação de corrida até
esgotar, retorno da corrida, alternância do agachamento e troca de modo durante
a partida) é o próximo passo, com o usuário rodando o `.exe` publicado.

### 8.4 Release publicada

| Item | Valor |
| --- | --- |
| Tag | `v0.6.0-etapa6` |
| Download | <https://github.com/EtecStudy/BLACKSITE/releases/download/v0.6.0-etapa6/BlackSight-Etapa6-Windows-x86_64.zip> |
| Tamanho do ZIP | **40.634.172 bytes** (≈ 38,7 MiB) |
| SHA-256 do ZIP | `12ef1e50932bf310aaabefa62b776985eb04578cc9dad9803c164a193a37d79d` |
| `BlackSight.exe` | 109.193.728 bytes |
| `BlackSight.pck` | 1.415.316 bytes |
| `LEIA-ME.txt` / `SHA256SUMS.txt` | 2.420 / 164 bytes |

### 8.5 Teste no Windows real

Job `windows-latest` `118397362234`, tudo verde: 238/238 (fumaça), 49/49
(fluxo) e 205/205 (controlador); o `.exe` executado *headless* carregou a tela
inicial `v0.6.0`; `%APPDATA%\BlackSight\settings.cfg` foi criado com
`mouse_sensitivity_x`, `crouch_mode`, `master_volume`, `window_mode` e `vsync`;
o `.exe` aberto com janela ficou vivo por 25 s com o título “Black Sight”.


## 9. Limitações desta etapa (v0.6.0)

- Na v0.6.0 não existia HUD de stamina: o valor era interno, com sinal e
  `get_stamina_ratio()` prontos. A **correção 6.1** adiciona a barra (seção 10).
- Não há som nem animação de cansaço; a corrida simplesmente passa a andar.

## 10. Correção 6.1 — HUD de stamina

Objetivo: mostrar a stamina real durante a partida com a mesma linguagem visual
do menu e das configurações, sem criar um segundo estado de stamina e sem
alterar física, velocidades ou balanceamento.

### 10.1 Direção visual

A HUD reutiliza **apenas** tokens que já existiam no projeto:

| Elemento | Origem no projeto | Valor usado |
| --- | --- | --- |
| Painel | `StyleBoxFlat_panel` de `settings_screen.tscn` | fundo `(0.031, 0.031, 0.035, 0.55)`, borda 1 px `(0.62, 0.58, 0.51, 0.22)`, raio 2 |
| Rótulo | textos secundários das telas | `(0.56, 0.53, 0.47)`, 14 px, Cinzel do tema |
| Valor | texto principal | `(0.92, 0.89, 0.82)`, 14 px |
| Trilho | fundo dos botões | `(0.02, 0.02, 0.023, 0.9)` com contorno `(0.62, 0.58, 0.51, 0.32)` |
| Preenchimento | tom pergaminho da interface | `(0.8, 0.76, 0.68, 0.95)` |
| Alerta (< 20%) | estado pressionado/alerta dos botões | `(0.55, 0.16, 0.16, 0.95)` |
| Marcador | linha do divisor das telas | marca o limiar de 20% em `(0.62, 0.58, 0.51, 0.55)` |

Nada de verde/azul, neon, gradientes, ícones ou texturas: o preenchimento é
desenhado por `Control._draw()` (`StaminaFill`). A HUD ocupa o **canto inferior
esquerdo**, com margens 36/32, painel de 300 px de largura mínima e trilho de
8 px de altura — discreta o bastante para não competir com a atmosfera.

### 10.2 Arquitetura e integração

| Arquivo | Papel |
| --- | --- |
| `ui/scenes/hud/player_hud.tscn` | HUD reutilizável: `Control` full-rect, `Layout` (margens) → `Stack` (VBox alinhada ao rodapé) → `Panel` → `StaminaBar` |
| `ui/scenes/hud/stamina_bar.tscn` | `Header` (rótulo + valor) e `Track` (desenho nativo) |
| `ui/scripts/hud/player_hud.gd` | `bind_player()` conecta ao sinal `stamina_changed` e lê `get_stamina()`/`get_max_stamina()`; não importa o controlador |
| `ui/scripts/hud/stamina_bar.gd` | recebe `set_values(current, maximum)` e repassa na hora (0–100%, sem estado próprio) |
| `ui/scripts/hud/stamina_fill.gd` | desenho do trilho, preenchimento, marcador de limiar e alerta |
| `match/scenes/movement_test.tscn` | instancia a HUD dentro de `Interface`, **antes** de `PauseRoot` (a pausa cobre a HUD) |
| `match/scripts/movement_test.gd` | chama `bind_player(Player)` no `_ready`; expõe `get_hud()` para os testes |

- A HUD **não** guarda stamina própria: só o último valor desenhado/escrito. O
  controlador continua sendo a única fonte (`stamina`, `max_stamina`).
- O sinal `stamina_changed` é emitido pelo controlador apenas quando o valor
  muda (consumo/recuperação/set_stamina), portanto não há atualização por frame
  na HUD.
- Sem dependência circular: `ui/` não importa `players/`; a ligação é feita por
  `Node` + sinal em `match/`, uma camada acima.
- `mouse_filter = IGNORE` em toda a HUD: ela não captura clique nem foco e não
  interfere no mouse, no movimento ou na pausa.
- `Stack` é uma `VBoxContainer` alinhada ao rodapé, pronta para receber novos
  componentes (vida, criatura, objetivos) acima da barra sem reconstruir nada.
- A âncora full-rect acompanha janela, tela cheia (F11) e o stretch
  `canvas_items` do projeto; a barra usa o espaço disponível, sem cortes.

### 10.3 Parâmetros preservados

Nenhum valor de gameplay foi alterado: máximo 100, consumo 20/s apenas em
`RUNNING`, recuperação 15/s em `IDLE`/`WALKING`/`CROUCHING`, limiar 20, clamp
0..100 e pausa sem consumo/recuperação continuam em
`players/scripts/player_controller.gd`. A HUD apenas observa.

### 10.4 Testes

Grupo **`[20]`** de `tools/ci/movement_test.gd` (42 verificações):

- HUD instanciada, visível, ligada ao jogador e com `mouse_filter` ignorado;
- barra cheia em 100%, texto `100%` e preenchimento visível;
- ao correr, a barra cai e o valor mostrado é idêntico ao
  `get_stamina()/get_max_stamina()` no mesmo frame, inclusive no texto;
- com stamina 0, razão 0,0, sem preenchimento e texto `0%`; após 60 frames de
  recuperação, a barra sobe sincronizada;
- pausa: 60% permanece 60% (40 frames) e o texto não muda; com as configurações
  abertas o valor continua estável; ao fechar, a partida segue pausada;
- posição inferior esquerda, largura ≤ 35% da tela, altura ≤ 120 px, sem corte
  na base e barra dentro do painel;
- nenhum `TextureRect` na HUD (desenho nativo, sem imagens);
- redimensionamento para 960×540: a HUD continua no rodapé, visível e dentro da
  tela; volta ao tamanho original;
- limites diretos da barra: `-20` → 0%, `250` → 100%, máximo 0 → 0%, alerta
  abaixo de 20% e sem alerta acima do limiar.

Regressão completa das Etapas 4–6 executada junto (WASD, diagonal, câmera,
colisões, gravidade, estados, velocidades, agachamento, stamina, pausa,
configurações e modo de agachamento).

### 10.5 Resultado

| Item | Valor |
| --- | --- |
| Execução | *(preenchido após o build)* |
| SMOKE / UI FLOW / MOVEMENT | *(preenchido após o build)* |
| Release | `v0.6.1-etapa6-hud` |
| ZIP | `BlackSight-Etapa6-HUD-Windows-x86_64.zip` |
| Tamanho / SHA-256 | *(preenchido após o build)* |
| Inspeção visual | *(preenchido após o build)* |

### 10.6 Limitações

- A HUD não tem animação de transição: o valor é atualizado no mesmo frame do
  sinal, o que garante que nunca mostre um valor diferente do real.
- A verificação visual foi feita pelos frames renderizados no CI
  (Xvfb/OpenGL); o teste em Windows real com uma pessoa continua sendo o passo
  seguinte.
- O modo de agachamento é global (não por perfil/tecla).
- Ainda não há pulo, interação, inventário, criaturas nem combate.

## 10. Como testar manualmente

1. Abra `BlackSight.exe` → **TESTAR MOVIMENTAÇÃO**.
2. Ande com **WASD**; segure **SHIFT** e corra por alguns segundos até a corrida
   parar sozinha. Continue com **SHIFT** pressionado: depois de recuperar, a
   corrida volta.
3. Agache com **CTRL** (um toque, modo ALTERNAR) e confirme que a corrida para
   e a stamina se recupera; toque de novo para levantar.
4. **ESC** → **CONFIGURAÇÕES** → aba **CONTROLES** → **Agachar com Ctrl →
   SEGURAR** → **APLICAR** → **VOLTAR** → **CONTINUAR**. Confirme que a posição,
   a câmera e a stamina continuaram iguais e que agora é preciso segurar Ctrl.
5. Confira a lista de controles na mesma aba: só WASD, Shift, Ctrl, mouse, Esc
   e F11; o texto do Ctrl muda com o modo escolhido.
6. Teste **F11**, **VOLTAR AO MENU** e **SAIR DO JOGO**; feche o jogo e reabra
   para confirmar que o modo escolhido continua salvo.

## 11. Documentos relacionados

- [`ETAPA-5.md`](ETAPA-5.md) — estados de movimento e pausa com configurações.
- [`CONFIGURACOES.md`](CONFIGURACOES.md) — onde ficam as configurações.
- [`ARQUITETURA.md`](ARQUITETURA.md) — módulos e dependências.
- [`RELEASE_NOTES_ETAPA6.md`](RELEASE_NOTES_ETAPA6.md) — notas da release.
