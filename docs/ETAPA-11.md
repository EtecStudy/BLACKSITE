# Etapa 11 — Biblioteca modular industrial (revisão)

**Objetivo:** revisar e melhorar a biblioteca modular da Etapa 11 para uma
**instalação industrial subterrânea de grande escala**, com encaixes
documentados e verificáveis, e reconstruir a cena de demonstração sobre ela.
Nada de laboratório definitivo, geração procedural, criaturas, objetivos ou
multiplayer.

- Biblioteca: `maps/modular/` (25 cenas)
- Demonstração: `match/scenes/modular_demo.tscn` (geometria em
  `maps/scenes/modular_demo_room.tscn`)
- Botão na tela inicial: **DEMONSTRAR MÓDULOS**
- Teste automatizado: `tools/ci/modular_test.tscn`
- Capturas de encaixe (renderização real): `tools/ci/modular_visual_check.tscn`
- Validador geométrico (fora do Godot, no build): contagem de sobreposições,
  frestas de piso/teto e buracos de parede em toda a demonstração
- A sala de teste existente (`maps/scenes/test_room.tscn` +
  `match/scenes/movement_test.tscn`) **não foi alterada**.

---

## 1. Auditoria da versão anterior (0.11.0)

| Grupo | Peças | Classificação | O que foi feito |
| --- | --- | --- | --- |
| Piso e piso de soleira | `floor_tile`, `threshold_2m` | **aproveitável com correção** | espessura 0,30 m; topo em `y = 0`; sem cópia de material por peça |
| Parede reta | `wall_straight_2m`, `wall_straight_4m` | **reconstruir** | substituídas por `wall_panel_2m` (2 × 6 × 0,40 m) |
| Porta e abertura | `wall_door_2m`, `wall_opening_2m` | **reconstruir** | substituídas por módulos de 4 m (`wall_door_4m`, `wall_opening_4m`), com batente, verga e soleira |
| Cantos | `wall_corner_inner`, `wall_corner_outer` | **reconstruir** | viraram colunas de 0,40 × 0,40 m com acabamento, sem braços de 2 m (os braços eram a causa de sobreposição nos encontros) |
| Pilastra de encontro | `wall_junction` | **reconstruir** | agora é uma pilastra de face única (0,70 m) que não invade o volume da parede |
| Corredores | `corridor_straight`, `corridor_corner`, `corridor_junction` | **substituídas** | `corridor_main_8m`, `corridor_secondary_8m`, `corridor_corner_6`, `corridor_tee_6`, `corridor_cross_6`, `corridor_end_6` |
| Salas | `room_square`, `room_rect` | **substituídas** | `room_lab_10x10`, `room_lab_12x16`, `room_tech_14x20`, `room_equipment_8x8` |
| Estrutura | `pillar`, `railing_2m` | **aproveitável com correção** | pilar sem embutir a placa no piso; guarda-corpo com painel e colisão contínua |
| Estrutura | — | **novo** | `support_column` (2,90 m) e `beam_6m` |
| Tetos | — | **novo** | `ceiling_tile` e `ceiling_light` |
| Escada | `stairs_straight` | **aproveitável com correção** | 16 degraus de 0,20 × 0,35 m; rampa de colisão com a inclinação dos degraus; guardas e postes alinhados |
| Demonstração | `modular_demo_room` | **reconstruída** | corredor de 40 m, duas salas de pesquisa, ramal, sala técnica com mezanino e escada |

**Peças pretas/brancas se atravessando:** a causa era dupla — (a) painéis de
parede de 2 m e 4 m posicionados no mesmo plano, com faces coplanares
disputando o mesmo pixel; (b) canto/pilastra com braços que entravam no volume
da parede vizinha. A correção **não esconde** nada: cada parede tem uma única
peça no lugar, os cantos são colunas independentes que fecham o quadrado
diagonal da grade e toda a biblioteca é verificada por um validador de AABBs
(sobreposição entre instâncias diferentes = erro). Sobraram apenas as
interseções estruturais previstas: **ponta de viga apoiada em pilar/pilastra** e
**rampa da escada embutida na laje no pé do primeiro degrau** (o espelho é
invisível dentro do piso). Ambas estão listadas em "Limitações".

---

## 2. Grade e convenções finais

| Grandeza | Valor | Observação |
| --- | --- | --- |
| **GRID** | **2,0 m** | todas as peças têm dimensões múltiplas de 2 m (exceto espessuras) |
| Altura livre (pé-direito) | **6,0 m** | parede e teto encontram em `y = 6` |
| Espessura da parede | **0,40 m** | banda centrada na linha da grade |
| Espessura do piso | **0,30 m** | **topo** em `y = 0`; volume até `y = −0,30` |
| Espessura do teto | **0,20 m** | face inferior em `y = 6`; topo em `y = 6,20` |
| Corredor principal | **6,0 m** de largura | módulo de 8 m de comprimento |
| Corredor secundário | **4,0 m** de largura | módulo de 8 m de comprimento |
| Módulo de porta | **4,0 m** | vão de **2,4 × 3,0 m**, ombreiras de 0,8 m |
| Módulo de abertura | **4,0 m** | vão de **3,6 × 4,2 m**, pilares de 0,2 m |
| Pilar I | **0,60 × 0,92 m** | placa de base 0,92 × 0,26 m; altura 6 m |
| Viga | **6,0 m** | 0,44 m de aba; face inferior em `y = 5,21` |
| Guarda-corpo | **1,10 m** | módulo de 2 m |
| Escada | **16 degraus de 0,20 × 0,35 m** | 3,20 m de subida em 5,60 m → **29,7°** |
| Bloco de canto | **0,40 × 0,40 m** | fecha o quadrado diagonal entre duas bandas |

### Origem (pivô) de cada família

| Família | Origem local | Exemplo |
| --- | --- | --- |
| Piso | centro da pegada, **no topo do piso** (`y = 0`) | `floor_tile` cobre ±1 m em X/Z |
| Teto | centro da pegada, na **face inferior** (`y = 0` local) | instanciado na altura livre (6 m) |
| Parede | **centro do módulo no eixo da parede**, base em `y = 0` | `wall_panel_2m` cobre X ±1 m |
| Porta/abertura | **centro do módulo no eixo da parede**, base em `y = 0` | módulo de 4 m, vão centrado |
| Canto | **interseção da grade** | coluna de 0,40 m centrada no nó |
| Junção | **centro do módulo no eixo da parede**, face +Z | pilastra saliente de 9 cm |
| Pilar | **centro da seção**, base em `y = 0` | placa 0,92 × 0,92 m |
| Viga | **centro do vão**, eixo X local | 6 m; gira 90° para vencer Z |
| Escada | **centro do primeiro degrau**, no piso | sobe para `−Z`, topo em 3,20 m |

### Perfil dos acabamentos (parede, rodapé, batente, plinto)

Todas as cotas abaixo são **profundidade a partir do eixo da parede**
(a parede ocupa ±0,200). A regra única: **nenhuma face de acabamento pode
coincidir com a face da parede** — o acabamento entra pelo menos 2 cm no
sólido e fica pelo menos 5 cm à frente dele.

| Peça | Fundo | Frente | Situação |
| --- | --- | --- | --- |
| Parede / coluna | −0,200 | +0,200 | corpo |
| Rodapé (parede reta, porta) | 0,175 | 0,275 | 2,5 cm embutido, 7,5 cm saliente |
| Montante vertical (parede reta) | 0,190 | 0,260 | 6 cm saliente |
| Nervura (parede reta) | 0,190 | 0,270 | 7 cm saliente |
| Capitel / topo (parede reta) | 0,190 | 0,320 | 12 cm saliente |
| Batente de porta/abertura | 0,190 | 0,260 | 6 cm; entra 1 cm no vão |
| Plinto de canto | −0,285 | +0,285 | envolve a coluna (8,5 cm por lado) |
| Faixa de canto | ±0,220 | | 2 cm saliente |
| Pilastra de encontro (faixa) | 0,190 | 0,290 | 1 cm embutida |
| Rodapé/topo da pilastra | 0,190 | 0,320 | 3 cm à frente da faixa |

### Regras de encaixe (obrigatórias)

1. Posicione em **múltiplos de 2 m** e rotacione em **múltiplos de 90°**.
2. **O retângulo de uma sala é o INTERIOR.** As paredes ficam **fora** dele,
   na banda de 0,40 m. O piso termina na face da parede.
3. **Parede entre dois ambientes é compartilhada**: nunca instancie a mesma
   parede duas vezes em bandas vizinhas. O vão de porta/abertura pertence a
   uma única parede; a **soleira** do módulo preenche a banda e emenda os dois
   pisos.
4. Cantos de uma sala fechada usam **um bloco de canto** no nó da grade.
   Encontro em T de parede interna com parede contínua **não** leva bloco (a
   parede contínua já fecha o canto) — e **não** leva pilastra decorativa, que
   invadiria o volume.
5. A pilastra `wall_junction` é **de face única**: instancie na face onde ela
   deve aparecer, nunca no meio de outra parede.
6. Piso de mezanino é instanciado com `y` igual à altura do piso (3,20 m).
   A face inferior fica 0,30 m abaixo e é onde apoiam as colunas de 2,90 m.
7. Rotação `yaw = 0` deixa a parede ao longo de **X**; `yaw = 90°` ao longo de
   **Z**. `−Z` é "para frente" do jogador em `yaw = 0`.

### Sentido dos eixos

- `−Z` é "para frente" na cena (mesma convenção do jogador: `yaw = 0` olha
  para `−Z`).
- Rotação de 90° em Y leva `+X` para `−Z` e `+Z` para `+X`.
- Pisos, tetos e blocos de canto são simétricos: qualquer rotação de 90° vale.

---

## 3. Biblioteca de peças (25 cenas)

### Pisos — `maps/modular/floors/`

| Cena | Tamanho (X × Y × Z) | Uso |
| --- | --- | --- |
| `floor_tile.tscn` | 2,0 × 0,30 × 2,0 | placa de piso; topo em `y = 0` |
| `threshold_2m.tscn` | 2,0 × 0,30 × 0,40 | soleira na banda da parede, com faixa de metal |

### Tetos — `maps/modular/ceilings/`

| Cena | Tamanho | Uso |
| --- | --- | --- |
| `ceiling_tile.tscn` | 2,0 × 0,20 × 2,0 | laje de teto com nervuras aparentes |
| `ceiling_light.tscn` | 2,0 × 0,20 × 2,0 | laje + painel luminoso (a luz real é `OmniLight3D`) |

### Paredes — `maps/modular/walls/`

| Cena | Tamanho (X × Y × Z) | Colisão | Uso |
| --- | --- | --- | --- |
| `wall_panel_2m.tscn` | 2,0 × 6,0 × 0,40 | 1 caixa | painel reto com base, nervuras e montantes |
| `wall_door_4m.tscn` | 4,0 × 6,0 × 0,40 | 2 ombreiras + verga + soleira | vão de 2,4 × 3,0 m com batente |
| `wall_opening_4m.tscn` | 4,0 × 6,0 × 0,40 | 2 pilares + verga + soleira | vão de 3,6 × 4,2 m |
| `wall_corner_inner.tscn` | 0,40 × 6,0 × 0,40 | 1 caixa | canto interno com faixa e capitel |
| `wall_corner_outer.tscn` | 0,40 × 6,0 × 0,40 | 1 caixa | canto externo com base reforçada |
| `wall_junction.tscn` | 0,70 × 6,0 × 0,09 | 1 caixa (pilastra) | pilastra de encontro em T, face única |

### Estrutura — `maps/modular/structure/`

| Cena | Tamanho | Uso |
| --- | --- | --- |
| `pillar.tscn` | 0,60 × 6,0 × 0,92 | pilar I com placa de base e capitel |
| `support_column.tscn` | 0,48 × 2,90 × 0,48 | apoio curto de mezanino |
| `beam_6m.tscn` | 6,0 × 0,78 × 0,44 | viga I; face inferior em `y = 5,21` |
| `railing_2m.tscn` | 2,0 × 1,10 × 0,14 | guarda-corpo com painel e colisão |

### Escada — `maps/modular/stairs/`

| Cena | Tamanho | Uso |
| --- | --- | --- |
| `stairs_straight.tscn` | 2,0 × 3,20 × 5,60 | 16 degraus de 0,20 × 0,35 m, rampa de colisão única, guardas e postes |

### Corredores — `maps/modular/corridors/`

| Cena | Pegada | Uso |
| --- | --- | --- |
| `corridor_main_8m.tscn` | 8,0 × 6,0 m | trecho reto principal, com vigas e luminárias |
| `corridor_secondary_8m.tscn` | 8,0 × 4,0 m | trecho reto secundário |
| `corridor_corner_6.tscn` | 6,0 × 6,0 m | canto em L (saídas a oeste e norte) |
| `corridor_tee_6.tscn` | 8,0 × 6,0 m + ramo 4,0 × 4,4 m | junção em T com acesso para os dois lados |
| `corridor_cross_6.tscn` | 6,0 × 6,0 m | cruzamento em X, quatro saídas |
| `corridor_end_6.tscn` | 2,0 × 6,0 m | terminação com parede de fundo e comporta selada |

### Salas — `maps/modular/rooms/`

| Cena | Interior | Acessos | Pilares |
| --- | --- | --- | --- |
| `room_lab_10x10.tscn` | 10 × 10 m | porta de 4 m no sul | 4 |
| `room_lab_12x16.tscn` | 12 × 16 m | porta no norte + abertura no sul | 4 |
| `room_tech_14x20.tscn` | 14 × 20 m | abertura no sul + porta no oeste | 4 |
| `room_equipment_8x8.tscn` | 8 × 8 m | porta no leste | — |

Todas as salas incluem piso, teto (com luminárias), paredes externas, blocos
de canto e as aberturas declaradas. As paredes laterais ficam **fora** do
retângulo interno; a parede do lado do corredor é a **do corredor**.

---

## 4. Cena de demonstração

Planta (metros; `x` para leste, `z` para sul, `y` para cima):

| Ambiente | Interior | Pé-direito | Acessos |
| --- | --- | --- | --- |
| Corredor principal | 40 × 6 m (x 0–40, z 0–6) | 6 m | 3 portas/aberturas + comporta no fundo leste |
| Sala de pesquisa A | 10 × 10 m (x 6–16, z −10,4–−0,4) | 6 m | porta de 2,4 m **e** abertura de 3,6 m no corredor |
| Sala de pesquisa B | 12 × 16 m (x 20–32, z 6,4–22,4) | 6 m | porta de 2,4 m no corredor |
| Ramal secundário | 4 × 20 m (x 32–36, z −20,4–−0,4) | 6 m | portal no corredor e abertura na sala técnica |
| Sala técnica | 14 × 20 m (x 28–42, z −40,8–−20,8) | 6 m | abertura no ramal + porta para equipamentos |
| Sala de equipamentos | 8 × 8 m (x 19,6–27,6, z −30–−22) | 6 m | porta na sala técnica |
| Mezanino | 6 × 12 m (x 36–42, z −40,8–−28,8) | 2,8 m sobre o piso 3,2 m | escada de 16 degraus + guarda-corpo |

O que a cena contém:

- **706 nós** no total: 257 placas de piso, 239 de teto (227 cegas + 12
  luminárias), 143 módulos de parede (137 painéis, 3 portas e 3 aberturas),
  14 blocos de canto, 12 pilares, 10 vigas, 8 módulos de guarda-corpo,
  3 colunas de apoio, 1 escada, 12 `OmniLight3D` e o `WorldEnvironment`
  (fog + tonemap);
- **corredor principal de 40 m** com 6 m de largura, vigas a cada 8 m e
  luminárias no teto;
- **junção modular** do ramal: o vão de 4 m é uma `wall_opening_4m` da própria
  parede norte do corredor (`MainWallNOpen_14`), com pilares de 0,20 m nas
  duas pontas — sem peça avulsa atravessando a parede do ramal;
- **três portas** (salas A, B e equipamentos) e **três aberturas**;
- **paredes compartilhadas**: nenhuma parede entre ambientes é duplicada;
- **pórtico de 6 × 6 m** na sala técnica: 4 pilares + 6 vigas de 6 m
  (duas no eixo X e quatro no eixo Z, fechando os quatro nós do pórtico);
- **mezanino** em `y = 3,2` com 8 guarda-corpos e 3 colunas de apoio;
- **escada** de 16 degraus ligando o piso ao mezanino, com guardas laterais;
- **espaço para correr**: o corredor permite 40 m em linha reta (mais de 7 s
  em velocidade máxima).

Materiais: `wall`, `panel`, `floor`, `trim`, `accent`, `light` e `stair`, todos
`StandardMaterial3D` locais em `maps/modular/materials/`. Sem texturas, sem
imagens externas, sem neon.

---

## 5. Correções de ESC e SHIFT

### ESC (menu de pausa travava / trocava de cena no meio do evento)

**Causa real:** o `ESC` era tratado em `_unhandled_input` e chamava
`get_tree().change_scene_to_file()` **de dentro do próprio evento**, com o
mouse capturado. O Godot remove o nó da árvore durante o processamento do
evento; os eventos seguintes do mesmo frame chegam a um nó já fora da árvore
(`Condition "!is_inside_tree()"`, godotengine/godot#48607) e a troca de cena
fica pela metade (godotengine/godot#106053). Não havia `paused`, `process_mode`
nem `auto_accept_quit` no projeto — a pausa era só visual.

**Correção (sem remover a ação):**

- a demonstração ganhou um **menu de pausa real** (`PauseRoot`) com
  CONTINUAR, CONFIGURAÇÕES e VOLTAR AO MENU;
- `ESC` **alterna** a pausa: para o jogador (`movement_enabled = false`),
  solta o mouse, desliga interação e inventário e mostra o menu;
- `ESC` de novo (ou CONTINUAR) retoma: recaptura o mouse, reativa os sistemas
  e chama `reset_sprint_state()` para não herdar corrida;
- **VOLTAR AO MENU** usa `change_scene_to_file.call_deferred(...)`, fora do
  processamento do evento;
- `_exit_tree()` garante o cursor visível ao sair da cena;
- abrir/fechar repetidamente não recria a cena nem perde estado: o teste de
  interface faz 3 ciclos de abrir/fechar por visita e 2 visitas completas
  menu → demonstração → menu.

### SHIFT (corrida ficava presa)

**Causa real:** o estado de corrida era lido a cada frame por
`Input.is_action_pressed("move_sprint")`. No Godot 4.7.2 o estado da ação de
uma tecla modificadora pode continuar pressionado depois do evento de soltura
— o motor chega a entregar um eco extra de pressionamento depois do release
(godotengine/godot#122728, #122554, #120217; corrigido apenas em 4.8). Como a
corrida não era desligada por evento, ela ficava presa até pressionar e soltar
Shift outra vez.

**Correção (sem remover a corrida e sem mudar velocidades):**

- `PlayerController._input()` registra **pressionar/soltar** de Shift num
  latch (`_sprint_event_held`), que roda também com `movement_enabled = false`;
- `_sprint_pressed()` usa o latch quando ele já viu teclado; sem eventos
  (testes com `Input.action_press`), cai no estado da ação;
- `_update_stamina()` e `_update_state()` passam a usar `_sprint_pressed()`;
- `reset_sprint_state()` apenas sincroniza o latch quando nenhum evento foi
  visto — **não apaga** o histórico de eventos (apagar reintroduziria o bug);
- `is_sprint_held()` continua público para HUD/testes.

Velocidades e stamina permanecem exatamente como na Etapa 6.2: caminhada
3,2 m/s, corrida 5,6 m/s, agachado 1,6 m/s; 20 pontos/s de consumo, 1 s de
atraso e 15 pontos/s de recuperação.

---

## 5b. Correção 0.11.2 — rodapé atravessando a parede

**Sintoma relatado (teste manual):** o rodapé/acabamento preto aparecia
parcialmente *dentro* da parede clara em alguns encaixes — faixas escuras
"cortando" a parede e bordas tremulando.

**Causa real:** não era posição de cena nem offset de instância. O acabamento
das peças foi modelado pela **face**, e não por um perfil de profundidade:
várias caixas terminavam *exatamente* no plano da parede (±0,200) ou no plano
da peça vizinha. Duas faces coplanares com a mesma normal disputam o mesmo
pixel (z-fighting); como o rodapé é `trim` escuro e a parede é clara, o
resultado é o acabamento "atravessando" a parede.

Coincidências encontradas (geometria da 0.11.1):

| Peça | O que dividia plano |
| --- | --- |
| `wall_panel_2m` | rodapé em −0,270..**−0,200** (fundo na face da parede) e o **montante** com a mesma profundidade do rodapé: as duas frentes em −0,270 (0,14 × 0,35 m de briga por módulo) |
| `wall_corner_inner` | `CollarBase` com **0,400 × 0,400**, exatamente a coluna: plinto inteiro dentro da coluna e as quatro faces coplanares |
| `wall_corner_outer` | mesma coisa com base e capitel |
| `wall_door_4m` | batente e rodapé com a **mesma frente** (±0,265) e batente atravessando o rodapé |
| `wall_junction` | faixa em 0,200..0,290 com rodapé/topo também em 0,290 |
| `wall_opening_4m` | revestimento começando na face do vão (1,800) |

**Correção (na origem, dentro das cenas das peças, não nas cenas que as
instanciam):** o acabamento passou a ter um perfil de profundidade explícito
(tabela da seção 2). Em resumo:

- rodapé: 7 cm → **10 cm de espessura**, com 2,5 cm embutidos na parede;
- montante, nervura e capitel deixaram de compartilhar plano: as frentes
  ficaram em 0,26 / 0,27 / 0,32 m, contra 0,275 m do rodapé;
- plinto do canto: 0,40 → **0,57 m** (envolve a coluna em 8,5 cm por lado);
  capitel 0,40 → 0,50 m; faixa 0,404 → 0,44 m; aresta 5 cm → 3 cm sobre a quina;
- batente da porta/abertura: entra **1 cm no vão** (cobre a aresta do ombreiro)
  e passa a terminar **sob** a travessa superior;
- pilastra de encontro: faixa embutida 1 cm e rodapé/topo 3 cm à frente dela.

**O que não mudou:** escala, grade, planta da demonstração, corredores, salas,
pórtico, mezanino, escada, movimentação, inventário, ESC e SHIFT. **Nenhum
colisor foi criado:** o número de `CollisionShape3D` por peça de parede
continua 1 (parede, cantos, pilastra), 4 (porta) e 4 (abertura) — o teste
automático confere isso peça a peça.

### Verificação automatizada desta correção

Nova seção **[4b]** do `modular_test.gd`: para cada peça de parede, mede as
caixas de malha (material + caixa local) e exige que:

1. nenhuma face de acabamento coincida (folga < 2 mm) com a face do corpo no
   mesmo eixo — ignorando as faces internas (|coordenada| < 0,200), que são
   emendas escondidas dentro do sólido;
2. nenhum acabamento de material diferente compartilhe a face da frente;
3. nenhum acabamento fique inteiro dentro do corpo da peça;
4. a contagem de colisores por peça seja a esperada (nada de colisor novo).

Resultado: **0 conflitos** nas seis peças corrigidas. Rodando o mesmo teste
contra a geometria da 0.11.1, ele acusa **12 conflitos** — exatamente os que o
teste manual encontrou (rodapé × montante, batente × rodapé, plinto × coluna,
faixa × rodapé da pilastra).

### Evidência visual no build

`tools/ci/modular_visual_check.tscn` abre a demonstração com câmera própria e
salva **10 closes** em `ci-logs/visual/` (parede reta em duas distâncias,
canto interno, porta, abertura, junção em T do ramal, parede rotacionada 90°,
lado oposto da mesma parede, pilar do hall e corredor inteiro). As imagens são
publicadas junto do diagnóstico do build para revisão humana — elas **não**
substituem o teste manual.

## 6. Testes

### Automatizados (executados no build)

| Suíte | O que verifica |
| --- | --- |
| `tools/ci/smoke_test.tscn` | configuração, cenas, versão 0.11.2, sistemas das etapas 3–9 |
| `tools/ci/ui_flow_test.tscn` | fluxo real de telas, incluindo **menu → demonstração → ESC ×3 → pausa → menu**, duas vezes seguidas |
| `tools/ci/movement_test.tscn` | controlador FPS, stamina, inventário, drop e o grupo **[25] soltura do SHIFT / corrida presa** |
| `tools/ci/drop_obstacle_test.tscn` | descarte junto a obstáculos |
| `tools/ci/modular_test.tscn` | **biblioteca nova**: catálogo, dimensões, vãos, encaixes, **acabamentos (seção 4b)**, salas, corredores, escada, demonstração e caminhada real |

O teste modular verifica, entre outros pontos:

- as 25 cenas existem, carregam, instanciam e têm colisão na camada 1;
- **acabamentos**: em parede reta, canto, porta, abertura e pilastra, nenhuma
  face de rodapé/batente/plinto divide plano com a parede, nenhum acabamento
  fica enterrado e a contagem de colisores não muda (seção [4b]);
- parede de 2 × 6 × 0,40 m, piso de 2 × 2 × 0,30 m com topo em `y = 0`,
  teto com base em `y = 6`;
- porta com vão de 2,4 m e verga em 3,0 m; abertura com vão de 3,6 m e verga
  em 4,2 m (largura medida na geometria de colisão e passagem conferida com
  raios na cena real);
- dois painéis vizinhos encostam sem sobrepor e a junta continua sólida;
- salas 10 × 10, 14 × 20 e 8 × 8: piso contínuo, paredes contínuas fora dos
  vãos, portas e aberturas livres;
- corredores: principal (6 m), secundário (4 m), canto em L, T, X e
  terminação — piso e passagem livres;
- escada: 16 degraus, altura correta em 5 pontos da rampa, guarda lateral,
  topo em 3,20 m e inclinação de 29,7° (abaixo do limite de 45°);
- demonstração: carrega, tem jogador/HUD/Spawn, 4 pilares do pórtico,
  8 guarda-corpos, 18 placas de mezanino, 12 luzes e mais de 200 módulos;
- **caminhada real** com o controlador existente: porta da sala A, abertura da
  sala A, porta da sala B, portal do ramal, sala técnica, porta dos
  equipamentos, parede que barra o jogador, subida da escada e guarda-corpo
  do mezanino;
- pausa: com `movement_enabled = false` o jogador não anda com WASD; ao
  retomar, volta a andar (medido no meio do mezanino, longe do guarda-corpo).

Resultado do build que publicou este pacote (commit `53851dc`):

| Suíte | Windows | Linux |
| --- | --- | --- |
| `smoke_test` | 359 verificações | 359 |
| `ui_flow_test` | 76 | 76 |
| `movement_test` | 598 | 598 |
| `drop_obstacle_test` | 156 | 156 |
| `modular_test` | 327 | 327 |

Todos com código de saída 0; além deles o build roda a importação, a execução
headless, a renderização (Xvfb/OpenGL), a exportação Windows e a execução do
`.exe` exportado. Nada disso substitui o teste manual da seção seguinte.

### Manual (Linux ou Windows, com janela)

1. Abra o jogo → **DEMONSTRAR MÓDULOS**.
2. Ande pelo corredor (WASD), corra com **SHIFT** e solte: a corrida deve
   parar **na hora**.
3. Entre na sala de pesquisa A pela porta (x ≈ 10) e pela abertura (x ≈ 14).
4. Volte, siga até o ramal (x ≈ 34), desça até a sala técnica.
5. Suba a escada até o mezanino, encoste no guarda-corpo.
6. Pressione **ESC**: o menu deve abrir com o mouse livre e o jogador parado.
7. **ESC** de novo: o jogo retoma, o mouse volta a ser capturado e o jogador
   anda. Repita 5 vezes.
8. Abra **CONFIGURAÇÕES** pelo menu, volte e retome.
9. **VOLTAR AO MENU**: deve retornar à tela inicial sem travar.
10. Repita a visita à demonstração; entre e saia mais duas vezes.
11. Olhe o rodapé de perto e de rasante, encostado na parede: não pode haver
    faixa escura "dentro" do branco nem borda tremulando (z-fighting), nem em
    parede reta, nem no canto, nem na porta/abertura, nem na junção do ramal.
12. Verifique se não há parede "piscando" (faces coplanares) nem fresta no
    chão ao longo dos corredores.

---

## 7. Limitações conhecidas

- **Nós do pórtico**: as vigas de 6 m se cruzam no eixo dos pilares (duas no
  eixo X e quatro no eixo Z). As almas se interpenetram ~0,09 m dentro do nó,
  como numa ligação real; é intencional e invisível.
- **Ponta de viga dentro de pilar/pilastra**: a viga de 6 m termina no eixo do
  pilar (como uma viga apoiada). O volume da ponta fica embutido no pilar —
  é intencional e invisível.
- **Rampa da escada no pé do primeiro degrau**: a rampa de colisão tem a mesma
  inclinação dos degraus e a face inferior entra ~0,10 m na laje do piso no
  pé. Também é invisível (fica dentro do piso) e evita degrau fantasma.
- **Sem portas funcionais**: os módulos de porta têm vão, batente e soleira,
  mas não têm folha móvel.
- **Sem geração procedural**: a biblioteca é estática, feita de cenas `.tscn`.
- **Sem teto físico nos corredores**: o teto tem colisão, mas não impede o
  jogador (não há pulo).
- **Mezanino sem teto próprio**: o teto da sala técnica cobre o mezanino numa
  altura de 2,8 m — suficiente para andar, apertado para a escala industrial.
- **Colisões**: todas as peças estruturais usam `BoxShape3D`; não há
  `ConcavePolygonShape3D` nem malhas importadas.
- **Emendas internas**: algumas faces de acabamento continuam coincidentes
  *dentro* do sólido da parede (|coordenada| < 0,200) — são emendas
  escondidas, não aparecem e o teste [4b] as ignora de propósito.
- A demonstração é um recorte de teste, **não** o laboratório definitivo.

---

## 8. Release

A correção do rodapé é publicada como **`v0.11.2-etapa11-rodape`**, sem
sobrescrever **`v0.11.1-etapa11-correcao`** (publicada e testada) nem
`v0.11.0-etapa11-modular-rooms`.

| Item | Valor |
| --- | --- |
| Release | <https://github.com/EtecStudy/BLACKSITE/releases/tag/v0.11.2-etapa11-rodape> |
| Arquivo | `BlackSight-Etapa11-Rodape-Windows-x86_64.zip` |
| Tamanho | 40.728.233 bytes |
| SHA-256 | `9f4c187e2d96bc80dd8b9924491281766bde8153d04919bbe7526a2a952e9af8` |
| Commit do build | `3c62ec7` |
| CI (Windows real) | run `39664881723` — SUCCESS |

Testes automáticos desse build: 359 (fumaça), 76 (interface), 598
(controlador/inventário/drop) e **364** (modular, 37 delas da seção [4b]).
As 10 imagens de close dos encaixes ficam em `ci-logs/visual/` e são
publicadas no branch `ci-windows` junto do diagnóstico do build; o passo
`TESTE W6b` falha se menos de 10 forem geradas.

O ZIP contém `BlackSight.exe` (109.193.728 bytes), `BlackSight.pck`
(1.721.544 bytes), `LEIA-ME.txt` e `SHA256SUMS.txt`.
