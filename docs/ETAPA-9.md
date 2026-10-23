# Black Sight — Etapa 9: soltar itens no ambiente 3D

**Versão:** 0.9.0 → **0.9.1** (correção) · **Base:** v0.8.0-etapa8-inventory · **Tags:** `v0.9.0-etapa9-drop` e `v0.9.1-etapa9-drop-fix`

> **Correção da v0.9.1:** itens soltos perto de caixas/pilares/paredes podiam
> nascer com apoio parcial, tombar e ficar presos ou fora de alcance. A causa
> e a correção estão em [`ETAPA-9-CORRECAO.md`](ETAPA-9-CORRECAO.md). Este
> documento descreve a arquitetura da etapa; a seção 5 já inclui o apoio
> completo da pegada.

Esta etapa liga o inventário ao mundo: o jogador solta o item do slot
selecionado com **G**, o item vira um objeto físico à frente dele e pode ser
recolhido de novo com **E**, pelo mesmo sistema de interação da Etapa 7.

Nada de arremesso, transferência entre jogadores, uso, consumo, pilha ou drop
por morte foi antecipado.

## 1. Objetivo

- Um caminho seguro para se desfazer de um item **sem perdê-lo**.
- Item solto como objeto do mundo: visível, com colisão, nome e interação.
- Posição de drop validada por física (piso, espaço livre e linha de visão).
- Recolhimento pelo `add_item()` existente, com o objeto só sumindo depois da
  confirmação.
- Pausa bloqueando drop, coleta, seleção e remoção.
- Nenhuma segunda barra de inventário e nenhuma cópia do estado.

## 2. Arquitetura

```
shared/mapping/space_probe.gd          SpaceProbe (consultas de física: piso,
                                       espaço livre e linha de visão)

players/scenes/player.tscn
├── Inventory                          (Etapa 8, inalterado)
├── InventoryInput                     + ação `inventory_drop`
└── Head/Camera
    ├── InteractionDetector            (Etapa 7, inalterado)
    └── ItemDropper                    players/scripts/inventory/item_dropper.gd
        └── world_item_scene ────────► items/scenes/world_item.tscn
                                         WorldItem extends Interactable

ui/scenes/hud/player_hud.tscn          mesmo painel de aviso da Etapa 8
```

| Módulo | Papel nesta etapa | Depende de |
| --- | --- | --- |
| `shared/` | `SpaceProbe`: geometria/física pura, sem item nem jogador | nada |
| `players/` | `ItemDropper` (decide e executa o drop) e a ação `inventory_drop` | `shared/`, `items/` (por cena exportada) |
| `items/` | `WorldItem`: representação física e coleta | `shared/` |
| `ui/` | mostra o texto de recusa no painel existente | `shared/` |
| `match/` | liga HUD ↔ `ItemDropper` e mantém a pausa | todos |

O `ItemDropper` **não** importa `items/`: recebe a cena por `@export`
(`world_item_scene`). `items/` **não** importa `players/`: pega o inventário
pelo ator (`actor.get_inventory()`), como na Etapa 8.

## 3. Integração com `ItemDefinition`

`ItemDefinition` continua sendo **só** `id` + `display_name` (Etapa 8). Nenhum
campo de modelo, textura ou cena foi adicionado.

- O item que sai do inventário é a **mesma instância** guardada no slot.
- `WorldItem.configure_item(item)` exige `item.is_valid()` (id não vazio).
- O nome exibido vem de `get_display_name()`; a cena tem uma representação
  genérica, igual para qualquer item.
- Modelos definitivos por item entram depois, trocando a cena (ou escolhendo
  outra por `id`), sem mexer no inventário nem no drop.

## 4. InputMap

| Ação | Tecla | Papel |
| --- | --- | --- |
| `inventory_drop` | **G** (física 71) | soltar o item do slot selecionado |
| `inventory_select_1..3` | 1/2/3 | (Etapa 8) seleção |
| `inventory_remove` | **R** | (Etapa 8) remoção provisória de teste |

- Nenhuma tecla é codificada: `InventoryInput` lê o InputMap e detecta a borda
  (estado anterior + atual), então **segurar G solta uma única vez**.
- `R` continua existindo e separada — é a remoção de teste da Etapa 8; **G** é
  o caminho normal, que preserva o item no mundo.
- A lista de controles das configurações passou de 8 para **9 linhas**
  (`G — Soltar item no chão`). R continua fora: é provisória.
- A cena de teste mostra `1 2 3 SLOTS · G SOLTAR · R REMOVER TESTE`.

## 5. Posição segura (`SpaceProbe`)

Ordem de decisão, à frente da câmera (`-basis.z`) na horizontal:

1. **Distâncias candidatas** — 1,15 m, 82% e 64% disso, descartando o que fica
   dentro da cápsula (`0,35 m` de raio + metade do item + 8 cm de folga).
2. **Piso** — raio vertical na coluna do ponto; a normal precisa apontar para
   cima (≥ 0,7). Parede, teto ou rampa íngreme reprovam.
3. **Espaço** — consulta de forma com a caixa do item (0,42 × 0,32 × 0,42) na
   altura de repouso, 2 cm acima do piso. Paredes, pilares, caixas, outros
   itens soltos e o próprio jogador reprovam.
4. **Apoio** — desde a v0.9.1, uma grade 3×3 de raios cobre a pegada do item;
   todas as amostras precisam atingir a **mesma** superfície. Quina de caixa,
   borda ou topo fino reprovam o ponto (o item nasceria apoiado só num canto,
   tombaria e poderia ficar preso). Se o topo de um objeto tem espaço, a busca
   desliza até 0,4 m sobre ele antes de desistir.
5. **Linha de visão** — raio do olho até o centro do item. Se algo bloqueia
   antes do ponto, ele é descartado (não soltar atravessando uma parede).

Depois de instanciar, `SpaceProbe.confirm_placement()` repete as checagens de
espaço e apoio **na posição real do nó**; se falhar, o item volta a existir só
no inventário.

Se nenhuma candidata passa, **o drop é cancelado e o item continua no
inventário**; a HUD mostra `SEM ESPAÇO PARA SOLTAR`.

A posição final fica **2 cm acima do piso** e o item assenta com a física —
nunca suspenso no ar, nunca dentro da cápsula, nunca atrás do jogador.

## 6. Física e colisões

`WorldItem` é `Node3D` (contrato `Interactable`) com um `RigidBody3D` filho:

- colisão única em caixa (0,42 × 0,32 × 0,42), camada 1 — a mesma do cenário e
  do raio de interação;
- massa 1, `linear_damp` 1,5 e `angular_damp` 6: assenta rápido, sem quicar,
  rodar ou deslizar;
- nasce com velocidade linear e angular **zero** — não existe arremesso;
- base baixa e larga (silhueta de 0,42 m) — não tomba, não bloqueia corredores;
- pode dormir normalmente (`can_sleep`), então não custa física parada.

Visual provisório, todo nativo: base metálica escura + cubo levemente emissivo
(mesmos materiais da Etapa 8) + `Label3D` com o nome, em modo *billboard*. A
etiqueta é filha do corpo físico e acompanha o assentamento.

## 7. Drop (ordem segura)

`ItemDropper.drop_selected_item()`:

1. bloqueado na pausa → não faz nada;
2. lê `get_selected_slot()` e `get_item(slot)` (API pública);
3. item nulo/inválido → `SLOT VAZIO`, nada muda;
4. `SpaceProbe` valida a posição → sem ponto: `SEM ESPAÇO PARA SOLTAR`;
5. instancia a cena, configura o item e adiciona à **cena atual**;
6. confirma que a instância entrou na árvore e recebeu o item;
7. **só então** chama `remove_item(slot)`;
8. se o `remove_item` falhar, a instância é liberada e o item fica no slot.

Qualquer falha em 5–6 (`world_item_scene` nula, `instantiate()` nulo, cena sem
`configure_item`, item inválido) libera o nó e mantém o item no inventário, com
`push_error` para depuração e o aviso `NÃO FOI POSSÍVEL SOLTAR`.

**Invariantes:** nada é duplicado (o item é a mesma instância que sai do slot) e
nada desaparece em silêncio (ou existe no mundo, ou continua no slot).

## 8. Coleta

`WorldItem` reutiliza a Etapa 7 sem tocar no detector:

| Passo | Mecanismo |
| --- | --- |
| detecção | raio da câmera, 2,5 m, camada 1, sobe até o `Interactable` |
| indicação | `[E] Pegar` (texto do próprio objeto) |
| ação | `_on_interact()` → `inventory.add_item(item)` |
| sucesso | objeto sai da árvore (`queue_free`) e do grupo `world_items` |
| inventário cheio | nada é removido; o objeto continua no chão, disponível |

- O objeto **só** desaparece depois de `add_item()` devolver `true`.
- Com o inventário cheio, `can_interact()` continua `true` de propósito: é
  assim que o jogador recebe a indicação e o aviso `INVENTÁRIO CHEIO`
  (`item_rejected` da Etapa 8).
- `_collected` + `queue_free()` + colisão desligada impedem coleta dupla.
- O item volta para o **primeiro slot vazio** (regra da Etapa 8).

## 9. HUD

- Mesma barra de 3 slots, mesmo realce, mesmos nomes. Depois do drop o slot
  mostra `VAZIO` imediatamente (`inventory_changed`).
- Mesmo painel de aviso da Etapa 8, agora também para `SLOT VAZIO`,
  `SEM ESPAÇO PARA SOLTAR` e `NÃO FOI POSSÍVEL SOLTAR` (1,6 s + 0,3 s de fade).
- `bind_drop_input(dropper)` conecta só o sinal `drop_blocked`; a HUD não
  importa `players/` e não guarda estado do drop.
- Stamina e a indicação de interação não mudaram.

## 10. Pausa

- `InventoryInput` é desligado (`set_input_enabled(false)`) na pausa: G, 1/2/3 e
  R não fazem nada.
- O `InteractionDetector` continua bloqueado (Etapa 7): E não recolhe nem aciona
  nada; a indicação some.
- `ItemDropper.is_blocked()` também consulta `movement_enabled`, como defesa
  extra.
- A física dos itens soltos segue o modelo de pausa já existente no projeto: o
  mundo continua simulando (o jogador é que para), então um item que ainda
  estivesse assentando termina de assentar. Nada é teleportado nem duplicado.
- Ao CONTINUAR, inventário e itens soltos continuam coerentes.

## 11. Arquivos

### Criados

| Arquivo | Conteúdo |
| --- | --- |
| `shared/mapping/space_probe.gd` | `SpaceProbe` (piso, espaço, linha de visão) |
| `items/scripts/world_item.gd` | `WorldItem` (item no mundo) |
| `items/scenes/world_item.tscn` | representação provisória + `RigidBody3D` |
| `players/scripts/inventory/item_dropper.gd` | `ItemDropper` (drop seguro) |
| `tools/ci/drop_visual.gd` / `.tscn` | verificação renderizada do drop |
| `docs/ETAPA-9.md`, `docs/RELEASE_NOTES_ETAPA9_DROP.md` | documentação |

### Modificados

| Arquivo | Mudança |
| --- | --- |
| `project.godot` | ação `inventory_drop` (G); versão 0.9.0 |
| `players/scenes/player.tscn` | `ItemDropper` na câmera + cena do item |
| `players/scripts/player_controller.gd` | `get_item_dropper()` |
| `players/scripts/inventory/inventory_input.gd` | `ACTION_DROP` + `drop_selected()` |
| `ui/scripts/hud/player_hud.gd` | `bind_drop_input()` e `show_message()` |
| `ui/scripts/settings/controls_section.gd` | linha `G — Soltar item no chão` |
| `match/scenes/movement_test.tscn` | dicas com `G SOLTAR` |
| `match/scripts/movement_test.gd` | liga a HUD ao drop e expõe o componente |
| `tools/ci/movement_test.gd` | grupo `[24]` (drop, coleta, cheio, falhas, pausa) |
| `tools/ci/smoke_test.gd` | grupo `[17]`, lista de 9 controles, `items/` com 2 scripts |
| `tools/ci/ui_flow_test.gd` | lista real com 9 linhas |
| `shared/autoload/app_info.gd`, `export_presets.cfg`, `ui/scenes/title_screen.tscn` | versão 0.9.0 |
| `.github/workflows/build.yml` | ZIP/tag/notas da Etapa 9 + captura do drop |
| `README.md`, `docs/ARQUITETURA.md`, `items/`, `players/`, `ui/README.md` | atualização |

Nada do inventário, da interação, do HUD de stamina ou das configurações foi
recriado.

## 12. Testes

### 12.1 Grupo `[24] Soltar itens no ambiente (Etapa 9)`

Em `tools/ci/movement_test.gd`, na cena real, com `Input.action_press`:

**Drop**
- ação `inventory_drop` existe e usa G; `inventory_remove` continua em R;
- nenhuma tecla codificada (`KEY_G`, `is_key_pressed`) no código do drop;
- componentes presentes, cena do item configurada, HUD ligada;
- soltar do slot 1 → slot 1 vazio, slots 2 e 3 intactos, HUD mostra `VAZIO`;
- soltar dos slots 2 e 3 → três itens no mundo, inventário vazio;
- posição: fora da cápsula, perto, à frente, no chão (y ≈ 0) e sem lançamento;
- slot vazio → nenhum objeto, inventário igual, aviso `SLOT VAZIO`;
- segurar G por 40 frames → **um** drop;
- soma `inventário + mundo` constante (sem duplicação).

**Recolhimento**
- item solto detectado pelo olhar, indicação `Pegar`;
- E recolhe, objeto sai do mundo, item volta ao primeiro slot vazio;
- inventário cheio → objeto continua, nenhum item removido, aviso
  `INVENTÁRIO CHEIO`;
- depois de abrir espaço com R, a nova tentativa recolhe;
- sem coleta duplicada.

**Falhas**
- parede a 0,45 m → drop cancelado, item no inventário, `SEM ESPAÇO PARA SOLTAR`;
- `world_item_scene` nula (falha de instanciação) → item mantido, nenhum
  objeto, `NÃO FOI POSSÍVEL SOLTAR`.

**Pausa**
- G não solta, E não recolhe, 1/2/3 não selecionam, R não remove;
- o item em foco continua em foco e o mundo não muda.

### 12.2 Grupo `[17] Soltar itens no ambiente (Etapa 9)` (fumaça)

Versão 0.9.0, `AppInfo`, InputMap, arquivos novos, cena do item (contrato,
`RigidBody3D`, colisão, etiqueta, `configure_item`), `ItemDropper` no jogador,
HUD ligada ao sinal e cena de teste com `G SOLTAR` e `R REMOVER TESTE`.

### 12.3 Fluxo de interface

`ui_flow_test.gd` exige 9 linhas na lista real, com `E`, `1 2 3` e `G`, e
confirma que R continua fora.

### 12.4 Verificação renderizada

`tools/ci/drop_visual.tscn` roda a cena real sob Xvfb: pega o ITEM A, solta com
G, espera assentar, mira o objeto e imprime `DROP VISUAL OK`. O frame vai para
`ci-logs/drop_hud.png`.

### 12.5 Regressão

As checagens da Etapa 8 (movimento, câmera, colisões, gravidade, stamina, atraso
de 1 s, limiar 20, agachamento ALTERNAR/SEGURAR, HUD de stamina, inventário,
coleta, seleção, R, interação 2,5 m, parede, pausa, F11) continuam rodando na
mesma suíte: o arquivo passou de 505 para **586** verificações, e todas passam.

## 13. Resultados

| Verificação | Resultado |
| --- | --- |
| Fumaça (Linux) | `SMOKE TEST OK — 348 verificações aprovadas` |
| Fluxo de interface (Linux) | `UI FLOW OK — 53 verificações aprovadas` |
| Controlador FPS + inventário + drop (Linux) | `MOVEMENT TEST OK — 586 verificações aprovadas` |
| Fumaça / UI / movimento (Windows) | W2, W2b e W2c verdes — 348 / 53 / 586 verificações |
| Captura renderizada do drop | `DROP VISUAL OK`; `drop_hud.png` 1600×900 ([`screenshots/drop_item.png`](screenshots/drop_item.png)) |
| Versão interna e `FileVersion` | `0.9.0` / `0.9.0.0` (`project.godot`, `export_presets.cfg`) |
| `.pck` (formato/recursos) | gerado pelo Godot 4.7.2, formato 4, ~1,4 MB (inspeção em `ci-logs/pck-windows.txt`) |
| ZIP publicado | `BlackSight-Etapa9-Drop-Windows-x86_64.zip` — 40.681.666 bytes (≈ 38,8 MiB) |
| SHA-256 do ZIP | `af21de8891167ef72393012a9da77de6c42e9e4e2b715abb4a2c129fe48c5900` |

O tamanho e o SHA-256 são os do asset da release `v0.9.0-etapa9-drop`,
conferidos na API do GitHub (`digest` do arquivo). O ZIP é gerado de novo a cada
build do workflow — por isso a própria release publica, no fim das notas, o
tamanho e o hash do arquivo que ela distribui.

## 14. Limitações desta etapa

- Representação genérica provisória: não há modelo por item.
- Sem arremesso: o item cai onde foi solto.
- Sem transferência entre jogadores, drop por morte ou inventário multiplayer.
- O drop é cancelado (não movido para outro ponto) quando não há espaço livre à
  frente; o jogador pode girar e tentar de novo.
- Itens soltos não são persistidos entre sessões (não há save de partida).
- A remoção provisória com R continua existindo; G é o caminho normal.
- Não há som nem animação de mão nesta etapa.
- O teste manual no Windows é do usuário: nada aqui declara que ele foi feito.

## 15. Próximos passos (fora desta etapa)

- Modelos/ícones definitivos por item (`.tres` + cena por `id`).
- Uso e consumo de item.
- Transferência entre jogadores (Etapa 10, **não** iniciada).
- Persistência dos itens soltos quando houver save de partida.

## 16. Como testar manualmente (Windows)

1. `BlackSight.exe` → **TESTAR MOVIMENTAÇÃO**.
2. Pegue **ITEM A** e **ITEM B** com E.
3. Pressione **1** e depois **G**: o ITEM A sai do slot 1, aparece no chão com
   o nome e o slot mostra `VAZIO`.
4. Olhe para o item e pressione **E**: ele volta para o primeiro slot vazio.
5. Com os três slots cheios, tente pegar um quarto item: aparece
   `INVENTÁRIO CHEIO`.
6. Selecione um slot vazio e pressione **G**: aparece `SLOT VAZIO`, nada é
   criado.
7. Encoste numa parede de frente e pressione **G**: aparece
   `SEM ESPAÇO PARA SOLTAR` e o item continua no inventário.
8. **ESC**: G, E, 1/2/3 e R não fazem nada. **CONTINUAR** devolve tudo.
9. Confira a regressão: WASD, mouse, SHIFT (stamina), CTRL (ALTERNAR/SEGURAR),
   F11, ESC, VOLTAR AO MENU, SAIR DO JOGO e CONFIGURAÇÕES → CONTROLES com 9
   linhas.

## 17. Documentos relacionados

- [`ETAPA-8.md`](ETAPA-8.md) — inventário de três slots.
- [`ETAPA-7.md`](ETAPA-7.md) — interação genérica.
- [`ETAPA-6.md`](ETAPA-6.md) — stamina, agachamento e controles.
- [`ARQUITETURA.md`](ARQUITETURA.md) — visão geral dos módulos.
- [`../README.md`](../README.md) — download e controles.
