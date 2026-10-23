# Black Sight — Etapa 7: sistema genérico de interação

**Versão:** 0.7.0 · **Base:** v0.6.2-etapa6-stamina · **Tag prevista:** `v0.7.0-etapa7-interaction`

Esta etapa cria a **interação por olhar** do jogo. O jogador mira um objeto
interativo a até **2,5 m**, vê a indicação discreta `[E] Interagir` e pressiona
**E**; quem executa a ação é o **próprio objeto**. Nada de porta, chave, item ou
inventário foi antecipado.

## 1. Objetivo

- Contrato genérico e reutilizável para qualquer objeto interativo.
- Detecção por **raycast a partir do centro da câmera** em primeira pessoa.
- **Linha de visão**: parede/caixa entre o jogador e o objeto bloqueia.
- Distância máxima de **2,5 m**, centralizada em uma única constante.
- Indicação visual pequena, com a mesma linguagem da HUD e das configurações.
- Ação de input **`interact`** no InputMap (tecla **E**), sem tecla codificada.
- Pausa e configurações **não** executam nem processam a interação.

## 2. Arquitetura

```
shared/interaction/interactable.gd          contrato do objeto (class_name Interactable)
players/scripts/interaction/interaction_detector.gd   olhar → foco (class_name InteractionDetector)
players/scenes/player.tscn
└── Head/Camera/InteractionDetector           componente do jogador, filho da câmera

maps/scripts/interaction_test_panel.gd      objeto de teste (class_name InteractionTestPanel)
maps/scenes/interaction_test_panel.tscn

ui/scripts/hud/interaction_prompt.gd        indicação [E] Interagir (class_name InteractionPrompt)
ui/scenes/hud/interaction_prompt.tscn
└── instanciada por ui/scenes/hud/player_hud.tscn

match/scripts/movement_test.gd              liga HUD ↔ detector e suspende na pausa
```

Direção das dependências mantida:

- `shared/` não importa nenhum outro módulo (o contrato não conhece jogador, HUD
  nem sala).
- `players/` depende de `shared/` (contrato) e da própria câmera.
- `ui/` **não** importa `players/`: `PlayerHud.bind_interaction(detector: Node)`
  só usa os sinais `focus_changed` / `focus_text_changed` e o método
  `get_current_interactable()`.
- `match/` é quem junta as peças (cena de teste), como nas etapas anteriores.

Nada de arquitetura paralela: o detector é um componente da cena do jogador e a
indicação vive dentro da HUD já existente.

## 3. Contrato `Interactable`

`shared/interaction/interactable.gd`:

| Membro | Papel |
| --- | --- |
| `@export interaction_text: String = "Interagir"` | texto mostrado na indicação |
| `@export interaction_enabled: bool = true` | disponibilidade |
| `signal interaction_performed(actor)` | emitido depois da ação |
| `can_interact(actor) -> bool` | o objeto decide se pode ser usado agora |
| `get_interaction_text(actor) -> String` | texto/indicação, pode variar |
| `interact(actor) -> bool` | executa a ação do objeto |
| `_on_interact(actor)` | gancho que as subclasses implementam |
| `set_interaction_enabled(value)` | liga/desliga sem remover a colisão |

Regras:

- Quem **executa** é o objeto. O detector nunca sabe o que o objeto faz.
- Subclasses sobrescrevem `_on_interact()` (e, se precisarem, `can_interact()` e
  `get_interaction_text()`).
- O detector também aceita qualquer nó que implemente os três métodos, mas
  herdar de `Interactable` é o caminho recomendado.
- **Não existe** `if objeto is porta`, `is chave` ou `is item` em lugar nenhum.
  O detector só pergunta `é Interactable?`, `can_interact()?` e chama
  `interact()`.

## 4. Detector (`InteractionDetector`)

Componente `Node3D` filho de `Head/Camera` em `players/scenes/player.tscn`.

A cada frame de física:

1. Se a detecção está bloqueada (pausa/configurações/desligada), esconde a
   indicação, zera a borda do input e **preserva** o foco atual.
2. Lança um raio de `camera.global_position` na direção `-camera.global_transform.basis.z`
   (centro exato da visão) com alcance `interaction_distance` (**2,5 m**).
3. Usa `PhysicsDirectSpaceState3D.intersect_ray` (Physics Ray Query), máscara
   padrão **1**, `collide_with_bodies` e `collide_with_areas` ligados,
   `hit_from_inside = false`, excluindo o RID do próprio jogador.
4. O primeiro corpo atingido é a resposta de linha de visão: se for uma parede,
   caixa ou pilar, o foco é `null` — não há como interagir através dela.
5. Sobe a árvore a partir do corpo atingido até achar um `Interactable`.
6. Consulta `can_interact(actor)`; se negar, o foco é `null`.
7. Atualiza `current_interactable` e só emite sinais **quando o estado muda**:
   `focus_changed(objeto|nulo)` e `focus_text_changed(texto)`.

Execução:

- A ação `interact` é lida com **borda própria** (`Input.is_action_pressed` +
  flag), do mesmo jeito que o Ctrl da Etapa 5 — funciona com
  `Input.action_press` nos testes e com o teclado real.
- `try_interact()` revalida o foco, chama `can_interact()`, executa
  `interact(actor)` e, se o objeto mudou de estado, reavalia a mira.
- Perder a referência: olhar para outro objeto, para o vazio, afastar-se além de
  2,5 m, perder a linha de visão ou o objeto deixar de ser interativo.
- `is_instance_valid()` protege contra objetos removidos da cena enquanto
  estavam focados.

API exposta: `get_current_interactable()`, `get_focus_text()`, `has_focus()`,
`try_interact()`, `refresh()`, `set_detection_enabled()`,
`is_detection_blocked()`, `get_interaction_distance()`.
Sinais: `focus_changed`, `focus_text_changed`, `interaction_triggered`.

## 5. Indicação `[E] Interagir`

`ui/scenes/hud/interaction_prompt.tscn` é instanciada **uma única vez** dentro de
`player_hud.tscn` (é um nó, não uma UI criada por frame).

- Fundo `Color(0.031, 0.031, 0.035, 0.55)`, borda `Color(0.62, 0.58, 0.51, 0.22)`,
  raio 2 — **os mesmos tokens** do painel de stamina e das configurações.
- Texto em pergaminho: ação `Color(0.83, 0.8, 0.73)`, tecla `Color(0.92, 0.89, 0.82)`.
- Tipografia do tema (Cinzel), 15 px na ação e 14 px na tecla; caixa da tecla com
  fundo próprio, como um "keycap" discreto.
- Ancorada no rodapé, **centralizada** (`anchor_left/right = 0.5`,
  `anchor_top/bottom = 1.0`, `offset_top = offset_bottom = -84`), acima da barra
  de stamina, sem cobrir o centro da tela.
- Não captura o mouse (`MOUSE_FILTER_IGNORE` em todo o ramo).
- Aparece com fade de 0,12 s e some **imediatamente** quando o alvo deixa de ser
  válido (nunca mostra um alvo já inválido).
- A tecla exibida é lida do InputMap (`interact`); se o mapa mudar, a indicação
  acompanha sem alterar o script.

## 6. Ação de input `interact`

```ini
interact={
"deadzone": 0.2,
"events": [Object(InputEventKey,...,"physical_keycode":69,...)]
}
```

- Tecla física **E** (`physical_keycode = 69`), mesmo padrão das outras ações.
- Proibido `Input.is_key_pressed(KEY_E)`: o detector só usa
  `Input.is_action_pressed("interact")`.
- **Sem** tela de remapeamento nesta etapa.
- W A S D, SHIFT, CTRL, mouse, ESC e F11 **não** foram alterados.

A lista de controles das configurações ganhou a linha **`E — Interagir`**
(6 → 7 linhas). É a única mudança na tela existente, exigida para não listar um
controle que não existe nem esconder um que existe.

## 7. Objeto de teste — Painel de Teste de Interação

`maps/scenes/interaction_test_panel.tscn` (`InteractionTestPanel extends
Interactable`), instanciado em `match/scenes/movement_test.tscn` à frente do
ponto de partida.

- Raiz `Node3D` + `Stand` (`StaticBody3D`, 0,5 × 1 × 0,34) + `Screen`
  (`StaticBody3D`, 1 × 0,62 × 0,09) com `CollisionShape3D` — o raio acerta a
  colisão e sobe até a raiz `Interactable`.
- `Title` (`Label3D`) "PAINEL DE TESTE" e `ScreenFace` levemente emissivo.
- Ao interagir: conta a interação, acende a tela e mostra **"INTERAÇÃO EXECUTADA"**
  por `feedback_duration` (1,8 s), com fade nos últimos 0,6 s.
- `interaction_text = "Interagir"`; a segunda instância usada nos testes troca o
  texto para "Examinar" e prova que o texto vem do objeto.
- Nada de porta, item, inventário, som ou animação complexa.

## 8. Pausa e configurações

- `pause_session()` desliga a detecção (`set_detection_enabled(false)`) e
  `resume_session()` religa.
- Durante a pausa/configurações: a indicação fica oculta, **E não interage**,
  `try_interact()` devolve `false` e o foco atual é preservado.
- Ao **CONTINUAR**, a mesma referência volta a valer e a indicação reaparece.
- O detector também consulta `movement_enabled` do jogador, então qualquer outro
  caminho que congele o jogador bloqueia a interação de forma consistente.

## 9. Arquivos

### Criados

| Arquivo | Conteúdo |
| --- | --- |
| `shared/interaction/interactable.gd` | contrato genérico (`Interactable`) |
| `players/scripts/interaction/interaction_detector.gd` | detector por raycast |
| `ui/scripts/hud/interaction_prompt.gd` | indicação `[E] Interagir` |
| `ui/scenes/hud/interaction_prompt.tscn` | cena da indicação |
| `maps/scripts/interaction_test_panel.gd` | objeto de teste |
| `maps/scenes/interaction_test_panel.tscn` | cena do painel |
| `docs/ETAPA-7.md`, `docs/RELEASE_NOTES_ETAPA7_INTERACTION.md` | documentação |

### Modificados

| Arquivo | Mudança |
| --- | --- |
| `project.godot` | ação `interact` (E) e versão 0.7.0 |
| `players/scenes/player.tscn` | nó `Head/Camera/InteractionDetector` |
| `players/scripts/player_controller.gd` | apenas `get_interaction_detector()` |
| `ui/scenes/hud/player_hud.tscn` | instância da indicação |
| `ui/scripts/hud/player_hud.gd` | `bind_interaction()` e handlers dos sinais |
| `match/scenes/movement_test.tscn` | painel de teste + E no texto de ajuda |
| `match/scripts/movement_test.gd` | liga HUD↔detector e respeita a pausa |
| `ui/scripts/settings/controls_section.gd` | linha `E — Interagir` |
| `tools/ci/smoke_test.gd`, `tools/ci/ui_flow_test.gd` | 7 linhas de controle e `interact` |
| `tools/ci/movement_test.gd` | grupo `[22]` de interação |
| `shared/autoload/app_info.gd`, `export_presets.cfg`, `ui/scenes/title_screen.tscn` | versão 0.7.0 |
| `.github/workflows/build.yml` | ZIP/tag/notas da Etapa 7 |
| `README.md`, `docs/ARQUITETURA.md` | atualização |

## 10. Testes

### 10.1 Automatizados

Grupo `[22] Interação (Etapa 7)` em `tools/ci/movement_test.gd`. Roda na cena
real da partida, com a física real:

- **Configuração**: detector presente na câmera; distância 2,5 m; ação
  `interact` no InputMap; E como tecla padrão; nenhuma tecla codificada no
  script.
- **Detecção**: objeto dentro do alcance vira foco; fora do alcance não; olhar
  para o vazio limpa o foco; parede não interativa não vira foco; outro objeto
  passa a ser o foco.
- **Linha de visão**: uma parede temporária entre o jogador e o painel bloqueia
  a detecção (e a execução); ao removê-la o foco volta.
- **Indicação**: aparece com texto e tecla corretos, fica no terço inferior,
  centralizada, compacta, dentro da tela, não captura o mouse e é o **mesmo nó**
  (nada instanciado por frame). Desaparece fora do alcance, com obstáculo, no
  vazio e quando o objeto é desativado/removido.
- **Execução**: E chama `interact()` uma vez; outras ações não chamam; fora do
  alcance e através da parede não chamam; o texto de retorno do objeto aparece.
- **Integridade**: interagir **não** altera a stamina e a HUD continua coerente;
  a indicação não bloqueia o movimento.
- **Pausa**: indicação oculta, E não interage, `try_interact()` falso, foco
  preservado; abrir/fechar configurações não interage; **CONTINUAR** restaura a
  indicação e a interação.
- **Regressão**: movimento, câmera, corrida, stamina, agachamento, HUD, F11,
  configurações, VOLTAR AO MENU e SAIR DO JOGO continuam cobertos pelos grupos
  anteriores (1–21), executados na mesma rodada.

### 10.2 Verificações estáticas

- `gdparse` (gdtoolkit) em todos os scripts novos e alterados.
- Revisão de `project.godot` (ação `interact`, tecla física 69) e dos `.tscn`
  (nós, caminhos e `load_steps`).

### 10.3 Build

`.github/workflows/build.yml` importa o projeto, roda fumaça/fluxo/movimento no
Linux e no Windows, exporta o `.exe`, executa o build exportado, inspeciona o
`.pck`, confere `FileVersion`, empacota o ZIP e publica a release.

**Resultado:** run `39478005585` verde nos dois jobs; ZIP publicado com
**40.653.078 bytes** e SHA-256
`3cdac8c7d64008235694996c145dbe734bb0e7aabc499f1f9b24a8e203f25878`.

### 10.4 Inspeção visual (captura automática)

A captura da cena de teste (`ci-logs/movement_test.png`, 1920×1080) mostra o
texto de ajuda já com **“E INTERAGIR”**, a HUD de stamina intacta no canto
inferior esquerdo e o **Painel de Teste** à direita, com o título legível. A
indicação `[E] Interagir` **não** aparece nessa captura porque a câmera da
captura olha para o centro da sala, não para o painel; o posicionamento e o
estilo dela são cobertos pelos testes de layout (rodapé, centralizada, 137 px de
largura, 36 px de altura) e devem ser confirmados visualmente no teste manual.

## 11. Resultados

Execução **39478005585** (`ce95812`), concluída com sucesso nos dois jobs.

| Verificação | Resultado |
| --- | --- |
| Fumaça (Linux) | **251/251** |
| Fluxo de interface (Linux) | **50/50** |
| Controlador FPS (Linux) | **363/363** (inclui o grupo `[22]`, 61 verificações) |
| Fumaça / UI / movimento (Windows) | **251 / 50 / 363**, todos aprovados |
| Versão interna | `v0.7.0 · Godot 4.7.2-stable (official) · gl_compatibility` |
| `FileVersion` / `FileDescription` | `0.7.0.0` / `Black Sight — Etapa 7` (`ProductName=Black Sight`) |
| `.pck` | formato 4, **90 recursos**, `PACOTE OK` |
| Execução real do `.exe` | headless OK; janela viva após 25 s, título “Black Sight” |
| `settings.cfg` | criado em `%APPDATA%\BlackSight`; `crouch_mode="toggle"` preservado |
| ZIP | **40.653.078 bytes**, 4 arquivos (`exe`, `pck`, `LEIA-ME`, `SHA256SUMS`) |
| SHA-256 do ZIP | `3cdac8c7d64008235694996c145dbe734bb0e7aabc499f1f9b24a8e203f25878` |

Release: <https://github.com/EtecStudy/BLACKSITE/releases/tag/v0.7.0-etapa7-interaction>

## 12. Limitações desta etapa

- Um único alvo por vez (o primeiro corpo atingido pelo raio).
- Não há som, animação de mão, contorno de objeto ou ícone — só a indicação
  textual.
- Não há inventário, porta, chave, item, missão, criatura nem multiplayer.
- O painel de teste é um objeto de demonstração; será substituído pelos objetos
  reais das próximas etapas.
- O teste manual no Windows é do usuário: nada aqui declara que ele foi feito.

## 13. Como testar manualmente (Windows)

**A. Indicação**
1. Abra `BlackSight.exe` → **TESTAR MOVIMENTAÇÃO**.
2. Olhe para o painel à frente: `[E] Interagir` aparece no rodapé.
3. Olhe para o lado/para cima: a indicação some. Olhe de volta: reaparece.

**B. Alcance**
1. Fique perto do painel e confirme a indicação.
2. Ande para trás até passar de ~2,5 m: a indicação some; E não faz nada.
3. Volte a se aproximar: a indicação volta.

**C. Linha de visão**
1. Coloque uma caixa/pilar entre você e o painel (ou use o canto da sala).
2. Sem ver o painel, a indicação não aparece; E não interage.

**D. Execução**
1. Com a indicação visível, pressione **E**: o painel mostra
   "INTERAÇÃO EXECUTADA" e a tela acende por instantes.
2. Pressione outras teclas (W, SHIFT, CTRL, mouse): nada é executado.

**E. Pausa**
1. Com a indicação visível, pressione **ESC**: a indicação some.
2. Pressione **E** com a pausa aberta: nada acontece.
3. Abra CONFIGURAÇÕES e volte; **CONTINUAR**: a indicação reaparece e E volta a
   funcionar.

**F. Regressão**
1. Movimento, câmera, corrida, stamina (consumo/atraso/recuperação) e
   agachamento (ALTERNAR/SEGURAR) devem se comportar como na v0.6.2.
2. A HUD de stamina continua no canto inferior esquerdo, sem mudanças.
3. F11 alterna tela cheia; ESC pausa; VOLTAR AO MENU e SAIR DO JOGO funcionam.
4. Em CONFIGURAÇÕES → CONTROLES, a lista mostra 7 linhas, com `E — Interagir`.

## 14. Documentos relacionados

- [`ETAPA-6.md`](ETAPA-6.md) — stamina, modos de agachamento e controles.
- [`ARQUITETURA.md`](ARQUITETURA.md) — visão geral dos módulos.
- [`../README.md`](../README.md) — download e controles.
