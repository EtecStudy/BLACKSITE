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
| `ui/scripts/settings_screen.gd` | `get_section()` para consulta/teste das abas |
| `tools/ci/movement_test.gd` | grupos 17–19 (stamina, ALTERNAR, pausa com stamina) |
| `tools/ci/smoke_test.gd` | grupo 15 (stamina, persistência e lista real) |
| `tools/ci/ui_flow_test.gd` | modo de agachamento na pausa da partida |
| `project.godot`, `shared/autoload/app_info.gd`, `export_presets.cfg`, `title_screen.tscn` | versão 0.6.0 / Etapa 6 |
| `.github/workflows/build.yml` | ZIP/release da Etapa 6 e LEIA-ME atualizado |
| `README.md`, `docs/ARQUITETURA.md`, `docs/CONFIGURACOES.md`, READMEs | documentação |

## 8. Testes executados

<!-- RESULTADOS -->

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
