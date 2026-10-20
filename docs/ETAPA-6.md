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
  `stamina_changed(current, maximum)` — estrutura pronta para uma HUD futura,
  **sem HUD nesta etapa**.

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
| `project.godot`, `shared/autoload/app_info.gd`, `export_presets.cfg`, `title_screen.tscn` | versão 0.6.0 / Etapa 6 |
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
| `LEIA-ME.txt` / `SHA256SUMS.txt` | 2.281 / 190 bytes |

### 8.5 Teste no Windows real

Job `windows-latest` `118397362234`, tudo verde: 238/238 (fumaça), 49/49
(fluxo) e 205/205 (controlador); o `.exe` executado *headless* carregou a tela
inicial `v0.6.0`; `%APPDATA%\BlackSight\settings.cfg` foi criado com
`mouse_sensitivity_x`, `crouch_mode`, `master_volume`, `window_mode` e `vsync`;
o `.exe` aberto com janela ficou vivo por 25 s com o título “Black Sight”.


## 9. Limitações desta etapa

- Não existe HUD de stamina: o valor é interno, com sinal e `get_stamina_ratio()`
  prontos para uma barra futura.
- Não há som nem animação de cansaço; a corrida simplesmente passa a andar.
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
