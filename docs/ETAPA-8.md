# Black Sight — Etapa 8: inventário de três slots

**Versão:** 0.8.0 · **Base:** v0.7.0-etapa7-interaction · **Tag prevista:** `v0.8.0-etapa8-inventory`

Esta etapa cria a base do inventário do jogador: **exatamente três slots**, adição,
seleção, remoção, substituição e consulta do item selecionado, com uma barra
discreta na HUD e um item de teste pegável pelo sistema de interação da Etapa 7.

Nada de drop, uso, pilha, peso, equipamento, transferência ou inventário
multiplayer foi antecipado.

## 1. Objetivo

- Inventário reutilizável, com API clara para as próximas etapas.
- Três slots fixos, número centralizado em uma constante.
- Item genérico identificado por **id** e **nome**, sem propriedades de gameplay
  que ainda não existem.
- Coleta por interação (`[E] Pegar`), usando o `Interactable` da Etapa 7.
- HUD com os três slots na identidade visual existente.
- Seleção com **1 / 2 / 3** pelo InputMap (sem tecla codificada).
- Remoção provisória com **R**, só para validar o sistema.
- Inventário cheio recusa o item novo e avisa de forma discreta.
- Pausa bloqueia interação, seleção, remoção e coleta.

## 2. Arquitetura

```
shared/items/item_definition.gd            ItemDefinition (Resource: id + display_name)

players/scenes/player.tscn
├── Inventory                              players/scripts/inventory/inventory.gd
│   └── (3 × InventorySlot)                players/scripts/inventory/inventory_slot.gd
├── InventoryInput                         players/scripts/inventory/inventory_input.gd
└── Head/Camera/InteractionDetector        (Etapa 7)

items/scenes/inventory_test_item.tscn      InventoryTestItem extends Interactable
items/scripts/inventory_test_item.gd

ui/scenes/hud/inventory_bar.tscn           InventoryBar (3 slots, realce do selecionado)
ui/scripts/hud/inventory_bar.gd
ui/scenes/hud/player_hud.tscn              instancia a barra + aviso "INVENTÁRIO CHEIO"

match/scripts/movement_test.gd             liga HUD ↔ inventário e pausa a entrada
```

Direção das dependências (mantida):

| Módulo | Depende de | Observação |
| --- | --- | --- |
| `shared/` | nada | `ItemDefinition` é o tipo comum entre módulos |
| `players/` | `shared/` | guarda os itens; não conhece HUD nem cena |
| `items/` | `shared/` | o item pegável usa o ator por contrato (`actor.get_inventory()`), sem importar `players/` |
| `ui/` | `shared/` | desenha o que o inventário informa; não guarda estado |
| `match/` | todos | orquestra a cena de teste |

Nenhum módulo foi duplicado: o item de teste herda do `Interactable` da Etapa 7 e
é detectado pelo mesmo `InteractionDetector`; a HUD é a mesma (`PlayerHud`), com
um componente novo.

## 3. `ItemDefinition`

`shared/items/item_definition.gd` (`class_name ItemDefinition extends Resource`):

| Campo | Tipo | Papel |
| --- | --- | --- |
| `id` | `StringName` | identificador estável (ex.: `&"item_a"`) |
| `display_name` | `String` | nome exibido na HUD e na etiqueta 3D |

Métodos: `is_valid()` (exige `id`), `get_display_name()` (recuo para o `id`),
`matches(outro)`.

- Nada de ícone, peso, pilha, durabilidade ou uso — entram quando o sistema que
  os consome existir.
- Um `.tres` por item pode ser criado depois sem tocar no inventário: o
  inventário só conhece este contrato.
- Os itens de teste são criados em tempo de execução a partir dos `@export`
  `item_id` / `item_name` de cada instância.

## 4. `Inventory` (3 slots)

`players/scripts/inventory/inventory.gd` (`class_name Inventory extends Node`).

- `const SLOT_COUNT := 3` — **único lugar** com o número de slots; o resto lê
  `get_slot_count()` ou a própria constante.
- Nó de **dados**: não desenha, não lê teclado, não acessa a câmera e não
  processa nada por frame (`set_process(false)` em `_ready`).
- `PlayerHud` nunca consulta por frame: só reage aos sinais.

### API

| Método | Comportamento |
| --- | --- |
| `get_slot_count()` | `3` |
| `is_valid_index(i)` | índice entre 0 e 2 |
| `get_slot(i)` | `InventorySlot` (ou `null` se inválido) |
| `get_item(i)` | item do slot (ou `null`) |
| `is_slot_empty(i)` | vazio/ocupado |
| `get_used_slot_count()` | quantos slots têm item |
| `has_free_slot()` | existe slot livre |
| `find_first_free_slot()` | índice do primeiro livre, `-1` se cheio |
| `add_item(item)` | **primeiro slot livre**; `false` se cheio ou item inválido |
| `remove_item(i)` | esvazia o slot; `false` se já vazio/índice inválido |
| `replace_item(i, item)` | troca o item do slot; `false` se inválido |
| `select_slot(i)` | seleciona (inclusive vazio); `false` só se índice inválido |
| `get_selected_slot()` | índice selecionado (começa em `0`) |
| `get_selected_item()` | item do slot selecionado (`null` se vazio) |
| `is_slot_selected(i)` | comparação com a seleção |
| `clear()` | esvazia todos os slots (testes/reinício) |

### Regras

- **Adicionar**: procura o primeiro slot livre, coloca, emite sinais e devolve
  `true`. Com os três ocupados **nada** é apagado ou substituído: emite
  `item_rejected` e devolve `false`.
- **Remover**: esvazia o slot e devolve o item ao esquecimento — **não** existe
  drop no chão nesta etapa.
- **Substituir**: o item anterior sai daquele slot e **não** vai para outro slot
  nem para o chão.
- **Selecionar**: vale para slot vazio também (o realce aparece mesmo em
  `VAZIO`); selecionar o mesmo slot de novo não emite sinal.
- Item nulo ou sem `id` é recusado sem alterar nada.

### Sinais

| Sinal | Quando |
| --- | --- |
| `inventory_changed` | qualquer mudança de conteúdo (a HUD redesenha os 3 slots) |
| `selection_changed(slot_index, item)` | a seleção mudou (a HUD move o realce) |
| `item_added(slot_index, item)` | um item entrou |
| `item_removed(slot_index, item)` | um item saiu |
| `item_replaced(slot_index, previous, current)` | um item foi trocado |
| `item_rejected(item)` | tentativa com inventário cheio (a HUD mostra o aviso) |

## 5. `InventorySlot`

`players/scripts/inventory/inventory_slot.gd` (`class_name InventorySlot extends
RefCounted`): `index`, `item`, `is_empty()`, `has_item()`, `get_item()`,
`set_item()`, `clear()` (devolve o item anterior), `get_display_name()`.

Guardar o slot como objeto evita espalhar checagens de `null` pelo inventário e
dá identidade ao slot para as próximas etapas.

## 6. Entrada (`InventoryInput`)

`players/scripts/inventory/inventory_input.gd` — componente filho do jogador.

| Ação (InputMap) | Tecla | Efeito |
| --- | --- | --- |
| `inventory_slot_1` | `1` | seleciona o slot 1 |
| `inventory_slot_2` | `2` | seleciona o slot 2 |
| `inventory_slot_3` | `3` | seleciona o slot 3 |
| `inventory_remove` | `R` | **provisória**: remove o item do slot selecionado |

- Chaves físicas (**49, 50, 51 e 82**), no mesmo formato das demais ações.
- Proibido `Input.is_key_pressed(KEY_1)`: o componente lê o **InputMap**, com
  detecção de borda própria (estado anterior + atual), igual ao Ctrl da Etapa 5
  e ao E da Etapa 7 — funciona com teclado real e com `Input.action_press` nos
  testes.
- **R é ação de teste**: existe apenas para validar `remove_item()`. Será
  substituída quando houver descarte/uso de item. Por isso ela **não** aparece na
  lista de controles das configurações (que ganhou apenas `1 2 3 — Selecionar
  slot`).
- **Sem mouse wheel** nesta etapa (o sistema está preparado para receber outras
  ações, mas nada foi adicionado além do pedido).
- Bloqueio: `set_input_enabled(false)` (chamado pela sessão na pausa) ou
  `movement_enabled == false` no jogador. Bloqueado, as teclas não fazem nada e
  o estado delas é re-sincronizado, para não disparar uma borda atrasada ao
  continuar.

## 7. Item de teste (`InventoryTestItem`)

`items/scenes/inventory_test_item.tscn` + `items/scripts/inventory_test_item.gd`
(`class_name InventoryTestItem extends Interactable`).

- Base metálica fina + cubo levemente emissivo + etiqueta 3D com o nome do item.
- `StaticBody3D` com colisão (poste e cubo) na camada 1 — o mesmo raio da Etapa 7
  o encontra e sobe até a raiz `Interactable`.
- `interaction_text = "Pegar"` → a HUD mostra `[E] Pegar` (a tecla vem do
  InputMap).
- Ao interagir: pede `add_item(item)` ao inventário de quem interagiu. Se o item
  entrou, o objeto **some** (visível = false, colisão desligada, deixa de ser
  foco). Se o inventário está cheio, o objeto continua no lugar e o aviso
  "INVENTÁRIO CHEIO" aparece na HUD.
- `can_interact()` continua `true` com o inventário cheio — senão o jogador não
  receberia a indicação nem o aviso.
- Não é uma porta, chave ou item definitivo: é um objeto de validação.

### Cena de teste

Quatro instâncias em `match/scenes/movement_test.tscn`, à esquerda do ponto de
partida, cada uma visível individualmente:

| Nó | Item | Posição (x, z) |
| --- | --- | --- |
| `TestItemA` | ITEM A | (-1,7 · 6,1) |
| `TestItemB` | ITEM B | (-3,1 · 5,3) |
| `TestItemC` | ITEM C | (-4,2 · 4,3) |
| `TestItemD` | ITEM D | (-1,3 · 3,9) |

O Painel de Teste da Etapa 7 continua à direita (1,6 · 6,2). Nenhum item bloqueia
os percursos usados pelos testes de movimento.

## 8. HUD

`ui/scenes/hud/inventory_bar.tscn` (instanciada uma única vez em
`player_hud.tscn`) + aviso `INVENTÁRIO CHEIO`.

- **Canto inferior direito**, alinhado com a margem de 32 px da HUD de stamina;
  não compete com a barra de stamina (inferior esquerdo) nem com a indicação de
  interação (rodapé central).
- Cada slot mostra o **número** (1/2/3) e o **nome do item** ou `VAZIO`.
- Mesmos tokens visuais do jogo: fundo `Color(0.031, 0.031, 0.035, 0.55)`, borda
  `Color(0.62, 0.58, 0.51, 0.22)`, raio 2, fonte do tema, texto em pergaminho.
- **Slot selecionado**: fundo `Color(0.085, 0.08, 0.078, 0.78)` e borda
  `Color(0.72, 0.66, 0.55, 0.6)` (os mesmos valores do *hover* dos botões) e
  número mais claro — sem cor nova, sem brilho, sem ícone.
- `mouse_filter = IGNORE` em toda a barra: não captura mouse nem foco.
- Nada é instanciado por frame: `bind_inventory()` conecta os sinais e só
  redesenha quando o inventário avisa.
- **Aviso de inventário cheio**: painel discreto acima dos slots, texto
  `INVENTÁRIO CHEIO`, visível por 1,6 s e fade de 0,3 s; some sozinho.

## 9. Pausa

`pause_session()` passou a chamar também `_set_inventory_input_enabled(false)` e
`resume_session()` religa. Durante a pausa e a tela de configurações:

- E **não** coleta (o `InteractionDetector` já está bloqueado desde a Etapa 7);
- 1/2/3 **não** mudam a seleção;
- R **não** remove item;
- o foco da interação e o conteúdo do inventário ficam preservados;
- ao **CONTINUAR**, tudo volta a funcionar no mesmo estado.

## 10. Arquivos

### Criados

| Arquivo | Conteúdo |
| --- | --- |
| `shared/items/item_definition.gd` | `ItemDefinition` |
| `players/scripts/inventory/inventory.gd` | `Inventory` (3 slots, API, sinais) |
| `players/scripts/inventory/inventory_slot.gd` | `InventorySlot` |
| `players/scripts/inventory/inventory_input.gd` | `InventoryInput` (InputMap) |
| `items/scripts/inventory_test_item.gd` | `InventoryTestItem` |
| `items/scenes/inventory_test_item.tscn` | cena do item de teste |
| `ui/scripts/hud/inventory_bar.gd` | `InventoryBar` |
| `ui/scenes/hud/inventory_bar.tscn` | barra dos 3 slots |
| `tools/ci/inventory_visual.gd` / `.tscn` | verificação renderizada do inventário |
| `docs/ETAPA-8.md`, `docs/RELEASE_NOTES_ETAPA8_INVENTORY.md` | documentação |

### Modificados

| Arquivo | Mudança |
| --- | --- |
| `project.godot` | ações `inventory_slot_1..3` e `inventory_remove`; versão 0.8.0 |
| `players/scenes/player.tscn` | nós `Inventory` e `InventoryInput` |
| `players/scripts/player_controller.gd` | `get_inventory()` e `get_inventory_input()` |
| `ui/scenes/hud/player_hud.tscn` | barra de slots + aviso de inventário cheio |
| `ui/scripts/hud/player_hud.gd` | `bind_inventory()` e handlers dos sinais |
| `match/scenes/movement_test.tscn` | quatro itens de teste e textos de ajuda |
| `match/scripts/movement_test.gd` | liga HUD ↔ inventário; bloqueia a entrada na pausa |
| `ui/scripts/settings/controls_section.gd` | linha `1 2 3 — Selecionar slot` |
| `tools/ci/movement_test.gd` | grupo `[23]` de inventário |
| `tools/ci/smoke_test.gd` | grupo `[16]` e lista de 8 controles |
| `tools/ci/ui_flow_test.gd` | lista real com 8 linhas |
| `shared/autoload/app_info.gd`, `export_presets.cfg`, `ui/scenes/title_screen.tscn` | versão 0.8.0 |
| `.github/workflows/build.yml` | ZIP/tag/notas da Etapa 8 + captura do inventário |
| `README.md`, `docs/ARQUITETURA.md`, `items/README.md`, `players/README.md` | atualização |

## 11. Testes

### 11.1 Automatizados (headless, cena real)

Grupo `[23] Inventário (Etapa 8)` em `tools/ci/movement_test.gd`:

- **InputMap**: as quatro ações existem e usam 1, 2, 3 e R; o componente não tem
  tecla codificada.
- **API isolada**: 3 slots, começa vazio, primeiro slot livre, adicionar A/B/C,
  inventário cheio recusa D sem alterar nada, `item_rejected`, remover, slot
  vazio, substituir (o antigo não fica em outro slot), selecionar 1/2/3,
  selecionar vazio, `get_selected_item()`, índices inválidos, `clear()`.
- **HUD**: 3 slots numerados, `VAZIO`/nome do item, realce do selecionado, posição
  no canto inferior direito, sem sobrepor stamina nem a indicação, aviso de
  inventário cheio que desaparece sozinho.
- **Coleta**: item detectado, indicação `Pegar`, E guarda no primeiro slot livre,
  o item desaparece e deixa de ser foco, E de novo não duplica, stamina intacta.
- **Alcance e LOS**: item fora de 2,5 m não é detectado; parede bloqueia.
- **Pausa**: 1/2/3 não mudam seleção, R não remove, E não coleta, foco e conteúdo
  preservados; configurações também bloqueiam; após CONTINUAR tudo funciona.
- **Regressão**: HUD de stamina coerente e movimento funcionando ao final.

### 11.2 Verificação renderizada (não headless)

`tools/ci/inventory_visual.tscn` roda a **cena real renderizada** sob Xvfb:
posiciona o jogador diante do item A, coleta com a ação `interact`, seleciona o
slot 3 e espera alguns frames para a captura. O CI guarda o frame em
`ci-logs/inventory_hud.png` e falha se o estado esperado não aparecer.

### 11.3 Fumaça e fluxo de interface

- `smoke_test.gd` ganhou o grupo `[16]` (versão, InputMap, arquivos, inventário
  isolado, cena do jogador, HUD e cena de teste) e a lista de controles passou a
  exigir **8 linhas** com `1 2 3 — Selecionar slot`.
- `ui_flow_test.gd` confere a lista real (8 linhas, com `E` e `1 2 3`) dentro da
  partida.

### 11.4 Build

`.github/workflows/build.yml` importa o projeto, roda fumaça/fluxo/movimento no
Linux e no Windows, renderiza a cena com o inventário, exporta o `.exe`, executa
o build exportado, inspeciona o `.pck`, confere `FileVersion`, empacota o ZIP e
publica a release.

## 12. Resultados

Execução `39486518665` do workflow (Linux e Windows), concluída com sucesso.

| Verificação | Resultado |
| --- | --- |
| Fumaça (Linux) | **308/308** verificações |
| Fluxo de interface (Linux) | **51/51** verificações |
| Controlador FPS + inventário (Linux) | **505/505** verificações |
| Fumaça / UI / movimento (Windows) | **308/308**, **51/51** e **505/505** |
| Captura renderizada do inventário | `INVENTORY VISUAL OK` — frame em `ci-logs/inventory_hud.png` |
| Versão interna e `FileVersion` | 0.8.0 · `FileVersion=0.8.0.0` · `FileDescription=Black Sight — Etapa 8` |
| `.pck` (formato/recursos) | `PACOTE OK`: cena inicial, scripts e assets presentes |
| ZIP publicado | `BlackSight-Etapa8-Inventory-Windows-x86_64.zip` — **40.669.748 bytes** (≈ 38,8 MiB) |
| SHA-256 do ZIP | `4596a98981514a10b94e7a28af22174aa39a576fdb91f21ee645247718e01764` |

O SHA-256 e o tamanho são os do **asset da release** (`v0.8.0-etapa8-inventory`),
conferidos na API do GitHub (`digest` do arquivo). O ZIP do job Linux é outro
arquivo (empacotado com outra ferramenta) e **não** é o publicado.

O frame da captura renderizada está em
[`screenshots/inventory_hud.png`](screenshots/inventory_hud.png): três slots no
canto inferior direito, **ITEM A** no slot 1, `VAZIO` nos demais e o **slot 3
selecionado** com borda e fundo mais claros. A HUD de stamina continua no canto
inferior esquerdo e não há indicação de interação porque o item A já foi pego.

## 13. Limitações desta etapa

- Remoção só pela tecla provisória **R** — não há descarte no chão, uso,
  transferência, pilha, peso ou equipamento.
- O inventário é do jogador local; não existe inventário multiplayer.
- Não há tela de inventário, ícones, arrastar-e-soltar nem mouse wheel.
- A lista de controles mostra `1 2 3` (implementado); **R não** aparece porque é
  provisória e será substituída.
- Os itens de teste não são itens definitivos do jogo.
- Não há som ao pegar o item.
- O teste manual no Windows é do usuário: nada aqui declara que ele foi feito.

## 14. Próximos passos (fora desta etapa)

- Uso/consumo de item e descarte no chão (substituindo a tecla R).
- Portas, chaves e objetivos usando o mesmo contrato `Interactable`.
- Inventário completo com ícones, descrições e mouse wheel.
- Itens definitivos como `.tres` de `ItemDefinition` (sem mudar a API).

## 15. Como testar manualmente (Windows)

**A. Pegar itens**
1. `BlackSight.exe` → **TESTAR MOVIMENTAÇÃO**.
2. Olhe para **ITEM A** (à frente, à esquerda) e pressione **E**: o item some e
   aparece no slot 1 (canto inferior direito).
3. Repita com **ITEM B** e **ITEM C**: vão para os slots 2 e 3.

**B. Inventário cheio**
1. Com os três slots ocupados, olhe para **ITEM D** e pressione **E**.
2. Nada é trocado; aparece **INVENTÁRIO CHEIO** por instantes e o item continua
   no lugar.

**C. Seleção**
1. Pressione **1**, **2** e **3**: o realce muda de slot, inclusive em slot vazio.
2. O slot selecionado tem fundo e borda mais claros.

**D. Remoção**
1. Selecione um slot ocupado e pressione **R**: o item sai e o slot volta a
   `VAZIO`. (Tecla provisória de teste.)

**E. Substituição**
1. Este caminho é exercitado pelos testes automatizados (`replace_item`); não há
   tecla de substituição nesta etapa.

**F. Pausa**
1. Com um item na mira, pressione **ESC**: a indicação some.
2. Pressione **E**, **1**, **2**, **3** e **R**: nada muda.
3. **CONTINUAR**: o inventário continua igual e as teclas voltam a funcionar.

**G. Regressão**
1. WASD, mouse, SHIFT (stamina com atraso de 1 s), CTRL (ALTERNAR/SEGURAR),
   F11, ESC, VOLTAR AO MENU e SAIR DO JOGO continuam como na v0.7.0.
2. A HUD de stamina continua no canto inferior esquerdo, sem mudanças.
3. Em CONFIGURAÇÕES → CONTROLES a lista mostra 8 linhas, com `E — Interagir` e
   `1 2 3 — Selecionar slot`.

## 16. Documentos relacionados

- [`ETAPA-7.md`](ETAPA-7.md) — sistema genérico de interação.
- [`ETAPA-6.md`](ETAPA-6.md) — stamina, agachamento e controles.
- [`ARQUITETURA.md`](ARQUITETURA.md) — visão geral dos módulos.
- [`../README.md`](../README.md) — download e controles.
