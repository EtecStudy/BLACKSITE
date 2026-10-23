# Black Sight — Etapa 5: Estados de movimento

Relatório da Etapa 5. As Etapas 1–4 foram concluídas e testadas anteriormente
(tela inicial, módulos, configurações e controlador FPS).

## 1. Objetivo

Dar ao jogador quatro estados explícitos — **PARADO**, **ANDANDO**,
**CORRENDO** e **AGACHADO** — com transições automáticas, velocidades próprias
e agachamento coerente (cápsula e câmera). Além disso, o menu de pausa passou a
oferecer **CONFIGURAÇÕES** sem abandonar a partida.

Fora do escopo: pulo, stamina, interação, inventário, criaturas e combate.

## 2. Estados

`players/scripts/player_controller.gd` define:

```gdscript
enum MovementState { IDLE, WALKING, RUNNING, CROUCHING }
```

| Estado | Quando |
| --- | --- |
| `IDLE` | nenhuma direção pressionada |
| `WALKING` | direção pressionada, sem Shift |
| `RUNNING` | direção + Shift, sem Ctrl |
| `CROUCHING` | Ctrl pressionado (com ou sem direção) |

Regras aplicadas:

- **Ctrl tem prioridade sobre Shift**: `CTRL + SHIFT = AGACHADO`, nunca corrida.
- Soltar Shift correndo → `WALKING`; parar correndo → `IDLE`.
- Soltar Ctrl agachado em movimento → `WALKING`; parado → `IDLE`.
- Enquanto a pausa está aberta o estado **não é recalculado** (é preservado).
- O sinal `state_changed(previous, current)` fica disponível para HUD/sons
  futuros.

Não existe estado de pulo, queda, ataque ou stamina.

## 3. Velocidades

Definidas como propriedades exportadas, sem números mágicos espalhados:

| Propriedade | Valor padrão | Uso |
| --- | --- | --- |
| `walk_speed` | `3.2 m/s` | andando |
| `run_speed` | `5.6 m/s` | correndo (1,75× a caminhada) |
| `crouch_speed` | `1.6 m/s` | agachado (metade da caminhada) |
| `acceleration` | `22.0 1/s` | aproximação/desaceleração |

`speed_for_state(state)` centraliza a escolha; `IDLE` devolve `0`.

## 4. Corrida e preparação para a stamina (Etapa 6)

A corrida exige **Shift + direção + não agachado**. Para a Etapa 6 não precisar
reescrever o controlador, existe um ponto único:

```gdscript
## Etapa 6 (stamina) chamará isto; nesta etapa permanece sempre true.
var sprint_allowed: bool = true

func set_sprint_allowed(value: bool) -> void:
	sprint_allowed = value
```

A condição de corrida já consulta `sprint_allowed`. Basta a Etapa 6
alterná-lo (por exemplo, quando a stamina chegar a zero) que o estado cai para
`WALKING`/`IDLE` automaticamente. **Nenhuma stamina é consumida nesta etapa.**

## 5. Agachamento

- `Ctrl` alterna a cápsula de `1.8 m` para `1.2 m` **encolhendo a partir do
  topo**: os pés continuam na origem, então agachar nunca empurra o corpo para
  dentro do chão ou de um obstáculo.
- A câmera (nó `Head`) desce de `1.62 m` para `1.02 m` com interpolação
  exponencial independente da taxa de quadros (`crouch_blend_speed = 12`),
  sem teletransporte e sem alterar a posição horizontal.
- Yaw, pitch, limites verticais, sensibilidade e inversão **não mudam**.
- Ao soltar Ctrl, `_can_stand()` faz uma consulta simples de forma
  (`PhysicsDirectSpaceState3D.intersect_shape`) com a cápsula em pé, excluindo
  o próprio corpo. Se houver teto/objeto acima, o jogador **permanece
  agachado** — não atravessa nada.
- A cápsula é duplicada em `_ready`, para que alterar a altura não afete outras
  instâncias do jogador.

## 6. Pausa com configurações

O menu do ESC agora tem três opções:

```
CONTINUAR
CONFIGURAÇÕES
VOLTAR AO MENU
```

Fluxo:

```
JOGO ──ESC──► PAUSA ──CONFIGURAÇÕES──► CONFIGURAÇÕES ──VOLTAR/ESC──► PAUSA ──CONTINUAR──► JOGO
```

Implementação:

- `match/scripts/movement_test.gd` instancia **a mesma cena**
  `ui/scenes/settings_screen.tscn` numa `CanvasLayer` por cima da partida, em
  **modo embutido** (`set_embedded(true)`);
- a tela de configurações, quando embutida, **não troca de cena**: emite
  `back_requested` e o `match/` volta ao menu de pausa;
- a partida continua pausada (`_paused = true`, `movement_enabled = false`)
  durante todo o fluxo — o jogador não anda e o mouse fica visível;
- posição, estado de movimento e orientação do jogador são preservados; nada é
  recriado;
- as alterações continuam indo para `GameSettings` → `user://settings.cfg` e o
  controlador reage ao sinal `applied` (a sensibilidade nova vale assim que o
  jogador escolher **CONTINUAR**);
- a tela "sozinha" (tela inicial → CONFIGURAÇÕES) mantém o comportamento
  antigo de voltar para a tela inicial.

## 7. Arquivos

| Arquivo | O que mudou |
| --- | --- |
| `players/scripts/player_controller.gd` | enum de estados, corrida, agachamento, velocidades, altura dos olhos, `_can_stand()`, hook de stamina |
| `players/scripts/player_controller.gd` / cena | nenhuma mudança de nós; cápsula/olhos originais preservados |
| `match/scripts/movement_test.gd` | botão CONFIGURAÇÕES, sobreposição da tela, pausa preservada |
| `match/scenes/movement_test.tscn` | `SettingsButton` e `SettingsLayer`; textos de ajuda |
| `ui/scripts/settings_screen.gd` | sinal `back_requested`, modo embutido |
| `ui/scenes/settings_screen.tscn` | dica lateral com nome único (`BackHint`) |
| `project.godot` | `move_sprint` (Shift) e `move_crouch` (Ctrl); versão 0.5.0 |
| `tools/ci/movement_test.gd` | grupos 12–16 |
| `tools/ci/smoke_test.gd` | grupo 14 (estados, velocidades, menu de pausa) |
| `tools/ci/ui_flow_test.gd` | fluxo pausa → configurações → pausa → continuar |
| `shared/autoload/app_info.gd`, `export_presets.cfg` | versão 0.5.0 / Etapa 5 |
| `README.md`, `docs/ARQUITETURA.md`, `docs/CONFIGURACOES.md`, READMEs | documentação |

## 8. Testes executados

Workflow [`build.yml`](https://github.com/EtecStudy/BLACKSITE/blob/main/.github/workflows/build.yml),
execução **[39349449302](https://github.com/EtecStudy/BLACKSITE/actions/runs/39349449302)**
(commit `bf5829a`), jobs Linux `118389914171` e Windows `118389914266` — ambos
**verdes**.

### 8.1 Automatizados (executados de verdade)

| Teste | O que cobre | Linux | Windows |
| --- | --- | --- | --- |
| `tools/ci/smoke_test.tscn` | Configuração, cenas, módulos, Input Map, estados, velocidades, menu de pausa | **195/195** | **195/195** |
| `tools/ci/ui_flow_test.tscn` | Menu → configurações → F11 → TESTAR MOVIMENTAÇÃO → pausa → CONFIGURAÇÕES → pausa → CONTINUAR → menu | **40/40** | **40/40** |
| `tools/ci/movement_test.tscn` | Controlador FPS e estados — 16 grupos | **122/122** | **122/122** |

Grupos **novos** do teste do controlador (os grupos 1–11 da Etapa 4 continuam
passando, incluindo colisões, gravidade, tremor e sensibilidade):

| Grupo | Resultado |
| --- | --- |
| `[12]` Estados de movimento | PARADO → ANDANDO → CORRENDO → soltar Shift → ANDANDO → AGACHADO (Ctrl + Shift continua agachado) → soltar Ctrl → ANDANDO/PARADO |
| `[13]` Velocidades | corrida 5,60 > caminhada 3,20 > agachado 1,60 m/s; 2,78 m vs 1,59 m vs 0,79 m em 30 frames; diagonal correndo normalizada |
| `[14]` Câmera ao agachar | desce de 1,62 m para 1,02 m e volta; sem teletransporte (máx. 0,109 m/frame); sem deslocamento horizontal; limite vertical mantido |
| `[15]` Agachar sob obstáculo | jogador permanece AGACHADO ao soltar Ctrl sob uma caixa e levanta quando ela é removida |
| `[16]` Pausa com configurações | CONTINUAR/CONFIGURAÇÕES/VOLTAR presentes; CONFIGURAÇÕES abre a mesma tela embutida; WASD bloqueado; posição e estado (AGACHADO) preservados; sensibilidade aplicada; VOLTAR retorna à pausa; CONTINUAR retoma |

### 8.2 Verificações estáticas e de empacotamento

| Verificação | Resultado |
| --- | --- |
| Sintaxe de todos os `.gd` (`gdparse`) | OK |
| Estrutura de todas as `.tscn` | OK |
| Execução *headless* da cena inicial (editor e build exportado Linux) | `v0.5.0`, sem `SCRIPT ERROR` |
| Render sob Xvfb/OpenGL (título, configurações, cena de teste) | 3 frames válidos |
| Inspeção do `.pck` | formato 4, **68 recursos**; jogador, sala e cena de teste presentes; `tools/` e `docs/` fora do pacote |
| Binário Windows | PE32+ x86-64, `FileVersion=0.5.0.0`, `FileDescription=Black Sight — Etapa 5` |

### 8.3 Manuais

Não foram executados por uma pessoa: o teste humano (sensação de corrida e
agachamento, ESC/recaptura, configurações na pausa) é o próximo passo, com o
usuário rodando o `.exe` publicado.

### 8.4 Release publicada

| Item | Valor |
| --- | --- |
| Tag | `v0.5.0-etapa5` |
| Download | <https://github.com/EtecStudy/BLACKSITE/releases/download/v0.5.0-etapa5/BlackSight-Etapa5-Windows-x86_64.zip> |
| Tamanho do ZIP | **40.630.076 bytes** (≈ 38,7 MiB) |
| SHA-256 do ZIP | `4ebc60d966a14edee54036f3f2c24dfb845a6224d1b381c191b8b6c68228308e` |
| `BlackSight.exe` | 109.193.728 bytes |
| `BlackSight.pck` | 1.411.380 bytes |
| `LEIA-ME.txt` / `SHA256SUMS.txt` | 2.048 / 164 bytes |

### 8.5 Teste no Windows real

Job `windows-latest` `118389914266`, tudo verde: 195/195 (fumaça), 40/40
(fluxo), 122/122 (controlador); `.exe` executado *headless* carregou a tela
inicial `v0.5.0`; `%APPDATA%\BlackSight\settings.cfg` foi criado com
`mouse_sensitivity_x`, `master_volume`, `window_mode` e `vsync`; `.exe` aberto
com janela ficou vivo por 25 s com o título “Black Sight”.

## 9. Limitações desta etapa

- Ainda não há stamina, pulo, interação, inventário, criaturas nem combate.
- O agachamento não tem animação de corpo nem som (não há corpo visível).
- `_can_stand()` é uma consulta de forma simples; não cobre casos exóticos como
  rampas sobrepostas. A arquitetura está pronta para evoluir.
- A câmera desce apenas em altura; não há inclinação/inércia adicional.

## 10. Como testar manualmente

1. Abra `BlackSight.exe` → **TESTAR MOVIMENTAÇÃO**.
2. Ande com **WASD**; segure **SHIFT** para correr e solte para voltar a andar.
3. Segure **CTRL** para agachar; ande devagar; tente **CTRL + SHIFT** (deve
   continuar agachado) e solte CTRL para levantar.
4. Olhe com o mouse agachado e em pé; confirme que o limite vertical e a
   sensibilidade continuam iguais.
5. **ESC** → **CONFIGURAÇÕES** → altere a sensibilidade → **APLICAR** →
   **VOLTAR** (volta à pausa) → **CONTINUAR** (mesmo lugar e mesmo estado).
6. Confirme que **VOLTAR AO MENU** e **SAIR DO JOGO** continuam funcionando.
7. Teste **F11** e feche o jogo normalmente.

## 11. Documentos relacionados

- [`ETAPA-4.md`](ETAPA-4.md) — controlador FPS e sala de teste.
- [`CONFIGURACOES.md`](CONFIGURACOES.md) — onde ficam as configurações.
- [`ARQUITETURA.md`](ARQUITETURA.md) — módulos e dependências.
- [`RELEASE_NOTES_ETAPA5.md`](RELEASE_NOTES_ETAPA5.md) — notas da release.
