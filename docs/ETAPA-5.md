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

## 8. Testes

_a preencher com os resultados reais da execução do workflow_

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
