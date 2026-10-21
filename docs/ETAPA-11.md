# Etapa 11 — Sistema modular de salas

**Objetivo:** entregar uma **biblioteca de peças modulares** (paredes, pisos,
corredores, salas e escada) com dimensões consistentes e colisões reais, mais
**uma cena de demonstração independente** que use essas peças e o jogador já
existente. Nada de laboratório completo, geração procedural, portas
funcionais, criaturas, objetivos ou multiplayer.

- Biblioteca: `maps/modular/`
- Demonstração: `match/scenes/modular_demo.tscn` (geometria em
  `maps/scenes/modular_demo_room.tscn`)
- Botão na tela inicial: **DEMONSTRAR MÓDULOS**
- Teste automatizado: `tools/ci/modular_test.tscn`
- A sala de teste existente (`maps/scenes/test_room.tscn` +
  `match/scenes/movement_test.tscn`) **não foi alterada**.

---

## 1. Grade e convenções

| Grandeza | Valor | Observação |
| --- | --- | --- |
| **GRID** | **2,0 m** | todas as peças têm dimensões múltiplas de 2 m (exceto espessuras) |
| Altura da parede | 4,0 m | a parede nasce em `y = 0` e termina em `y = 4` |
| Espessura da parede | 0,25 m | a parede é centrada na linha da grade |
| Espessura do piso | 0,25 m | o **topo** do piso é `y = 0`; o volume desce até `y = −0,25` |
| Pilastra de junção | 0,34 × 0,34 m | cobre a costura de duas peças, 0,17 m para cada lado |
| Vão de porta | 1,2 m × 2,4 m | dentro de um módulo de 2 m (ombreiras de 0,4 m) |
| Abertura de conexão | 2,0 m × 2,6 m | vão total do módulo, com verga acima |
| Escada | 20 degraus de 0,20 m (espelho) × 0,30 m (piso) | 4,0 m de subida em 6,0 m → **33,7°** |
| Guarda-corpo | 1,0 m de altura | módulo de 2 m, com colisão de 0,1 m de espessura |

### Origem (pivô) de cada família

| Família | Origem local | Exemplo |
| --- | --- | --- |
| Piso | centro da pegada, **no piso** (`y = 0`) | `floor_tile` cobre ±1 m em X/Z |
| Parede | centro do vão **no eixo** da parede, no piso | `wall_straight_2m` cobre X ±1 m |
| Canto | **interseção da grade** (encontro das duas paredes) | braços de 2 m para os lados "internos" |
| Corredor reto | centro do trecho, no piso | 2 pisos + 4 paredes de 2 m |
| Canto de corredor | nó da grade onde o corredor vira | trecho reto + ramo em L |
| Escada | **centro do primeiro degrau**, no piso | sobe para `−Z` |

Regras práticas:

1. **Posicione sempre em múltiplos de 2 m** (`x`, `z`) e **rotacione em
   múltiplos de 90°**. Assim as faces encostam sem fresta.
2. A parede é centrada na linha: em `z = −5` a parede ocupa
   `z ∈ [−5,125, −4,875]`. O piso encosta na linha e entra 0,125 m na parede —
   essa pequena penetração é intencional e elimina a fresta.
3. O **canto interno** (`wall_corner_inner`) já contém os dois trechos de 2 m
   que saem do nó. Ao fechar uma sala, conte 2 m de cada lado para o canto e
   só depois posicione as paredes retas.
4. O **canto externo** (`wall_corner_outer`) tem os braços em `+X` e `−Z`; serve
   para esquinas de fora (varandas, reentrâncias).
5. A **pilastra de junção** (`wall_junction`) fecha a costura de duas peças em
   ângulo reto (por exemplo, o fim de um corredor com a parede de tampo).

### Sentido dos eixos

- `−Z` é "para frente" na cena (mesma convenção do jogador: `yaw = 0` olha
  para `−Z`).
- Rotação de 90° em Y leva `+X` para `−Z` e `+Z` para `+X` (giro anti-horário
  visto de cima, regra do Godot).
- Os pisos são simétricos, então qualquer rotação de 90° é aceita.

---

## 2. Biblioteca de peças

### Paredes — `maps/modular/walls/`

| Cena | Tamanho (X × Y × Z) | Colisão | Uso |
| --- | --- | --- | --- |
| `wall_straight_2m.tscn` | 2,0 × 4,0 × 0,25 | 1 caixa | trecho reto de 2 m |
| `wall_straight_4m.tscn` | 4,0 × 4,0 × 0,25 | 1 caixa | trecho reto de 4 m (dois módulos) |
| `wall_door_2m.tscn` | 2,0 × 4,0 × 0,25 | ombreiras + verga | vão de porta 1,2 × 2,4 m |
| `wall_opening_2m.tscn` | 2,0 × 4,0 × 0,25 | verga | abertura de conexão 2,0 × 2,6 m |
| `wall_corner_inner.tscn` | 2,125 × 4,0 × 2,125 | 2 braços + pilastra | canto interno (braços `+X`, `+Z`) |
| `wall_corner_outer.tscn` | 2,125 × 4,0 × 2,125 | 2 braços + pilastra | canto externo (braços `+X`, `−Z`) |
| `wall_junction.tscn` | 0,34 × 4,12 × 0,34 | 1 caixa | pilastra de encontro entre paredes |

Todas as raízes são `StaticBody3D` na **camada 1** (mundo). A malha e a
colisão de cada peça têm **exatamente o mesmo tamanho**; não existe collider
invisível maior que a geometria.

### Pisos — `maps/modular/floors/`

| Cena | Tamanho | Topo | Uso |
| --- | --- | --- | --- |
| `floor_tile.tscn` | 2,0 × 0,25 × 2,0 | `y = 0` | piso composto por repetição |

### Estrutura — `maps/modular/structure/`

| Cena | Tamanho | Uso |
| --- | --- | --- |
| `pillar.tscn` | 0,5 × 4,0 × 0,5 (capitel 0,62 × 0,22 × 0,62 em `y = 4,11`) | pilar interno; a colisão cobre só o fuste e o capitel |
| `railing_2m.tscn` | 2,0 × 1,0 × 0,1 | guarda-corpo de mezanino/borda; a colisão é uma barreira de 1 m |

### Corredores — `maps/modular/corridors/`

| Cena | Pegada | Descrição |
| --- | --- | --- |
| `corridor_straight.tscn` | 2 m de largura × 4 m de comprimento | 2 pisos de 2 m e 4 paredes de 2 m nas laterais |
| `corridor_corner.tscn` | 4 × 4 m (L) | trecho reto + curva de 90°; tem parede interna e pilastra no nó |
| `corridor_junction.tscn` | 6 × 4 m (T) | corredor passante de 6 m + ramo de 2 m, com as duas pilastras |

Os corredores têm **1,75 m livres** entre as paredes (2 m menos a espessura).
As pontas são abertas para encaixar em salas, cantos ou tampas.

### Salas — `maps/modular/rooms/`

| Cena | Dimensões | Composição |
| --- | --- | --- |
| `room_square.tscn` | 10 × 10 m | 25 pisos, 4 cantos, 12 paredes (porta no norte, abertura no leste) |
| `room_rect.tscn` | 10 × 14 m | 35 pisos, 4 cantos, 11 paredes (abertura no norte; 4 m + 2 m nas laterais) |

A sala quadrada demonstra que o mesmo conjunto de peças fecha um perímetro de
40 m; a retangular demonstra a mistura de módulos de 4 m e de 2 m no mesmo
perímetro. Os cantos são os únicos elementos que "gastam" 2 m de cada lado; o
resto é preenchido com `wall_straight_2m`/`wall_straight_4m`, `wall_door_2m`
e `wall_opening_2m`.

### Escada — `maps/modular/stairs/`

| Cena | Pegada | Altura | Inclinação |
| --- | --- | --- | --- |
| `stairs_straight.tscn` | 2,0 m de largura × 6,0 m de comprimento | 4,0 m | 33,7° |

- 20 degraus: espelho de 0,20 m e piso de 0,30 m (a malha é sólida até o chão).
- **A colisão é uma única rampa** (caixa de 2 × 0,2 × 7,21 m girada 33,7°),
  com o plano superior exatamente sobre os narizes dos degraus. Isso evita o
  jogador "tropeçar" em 20 quinas e mantém a caminhada suave.
- Dois guardas laterais de 0,12 × 0,32 m acompanham a rampa (malha + colisão),
  para o jogador não cair de lado.
- A subida (4 m) é menor que o limite de rampa do `CharacterBody3D`
  (`floor_max_angle` de 45°), e **não é preciso pular**.
- Encaixe: a **borda do topo** da escada fica no fim dos 6 m (a 4 m de altura);
  o piso do nível superior deve começar exatamente nessa borda. Ex.: escada em
  `(12, 0, 19)` tem o topo em `z = 13` e `y = 4` — o mezanino começa em
  `z = 13`.

### Materiais compartilhados — `maps/modular/materials/`

Todos os módulos usam os mesmos cinco `StandardMaterial3D`:
`wall_material.tres`, `floor_material.tres`, `trim_material.tres`,
`stair_material.tres` e `light_panel_material.tres`. Nenhuma textura, modelo
ou plugin externo foi adicionado.

---

## 3. Cena de demonstração

**Como abrir**

1. No jogo: tela inicial → **DEMONSTRAR MÓDULOS**.
2. No editor/CI: abra `match/scenes/modular_demo.tscn` e execute (F6/F5).

A cena instancia o jogador existente (`players/scenes/player.tscn`) e a HUD
(`ui/scenes/hud/player_hud.tscn`); o controlador, a stamina e o inventário são
os mesmos das outras cenas. `ESC` volta ao menu, `F11` alterna tela cheia.

**Layout montado** (todos os números em metros, `y = 0` no piso térreo):

| Nó | Peça | Posição | Observação |
| --- | --- | --- | --- |
| `RoomSquare` | sala quadrada 10 × 10 | `(0, 0, 0)` | porta no norte (`z = −5`), abertura no leste (`x = 5`) |
| `CorridorNorth` | corredor reto | `(0, 0, −7)` | liga a porta norte ao fundo fechado |
| `CorridorCap` + 2 junções | parede 2 m + pilastras | `(0, 0, −9)` e `(±1, 0, −9)` | fecha a ponta do corredor |
| `CorridorEast` | corredor reto (girado 270°) | `(7, 0, 0)` | sai da abertura leste |
| `CorridorCorner` | canto de corredor | `(11, 0, 1)` | vira para `+Z` |
| `CorridorSouth` | corredor reto | `(12, 0, 5)` | liga o canto à sala retangular |
| `RoomRect` | sala retangular 10 × 14 | `(12, 0, 14)` | abertura no norte em `x = 12` |
| `Stairs` | escada | `(12, 0, 19)` | sobe para `−Z`; topo em `z = 13`, `y = 4` |
| 15 × `Mezzanine_*` | piso | `y = 4` | cobre `x ∈ [7, 17]`, `z ∈ [7, 13]` |
| 15 × `Rail*` | guarda-corpo | `y = 4` | fecha as bordas, com vão de 2 m para a escada |
| 4 × `Pillar` | pilar | `(±2, 0, ±2)` | dentro da sala quadrada |
| `Spawn` | `Marker3D` | `(0, 0,1, 3)` | ponto de nascimento do jogador |

**O que observar**

- A porta norte, a abertura leste e a abertura da sala retangular: passe por
  elas sem encostar.
- O corredor leste termina no canto e vira para o sul, encontrando a sala
  retangular sem degrau nem fresta.
- A escada sobe 4 m e desemboca no mezanino; os guarda-corpos impedem a queda
  nas bordas fechadas.
- Não há collider invisível: onde a malha termina, a colisão também termina.
- As paredes têm 4 m e não há teto — é uma demonstração de peças, não uma sala
  final.

---

## 4. Como montar (instruções de encaixe)

1. **Escolha o nó da grade.** Trabalhe com coordenadas pares (0, 2, 4, …) para
   as linhas de parede e com o **centro do módulo** para as peças retas.
2. **Coloque os cantos primeiro.** Em uma sala de 10 × 10 com paredes em
   `x = ±5` e `z = ±5`, os cantos vão em `(±5, 0, ±5)`, com rotações
   `0°` (NO), `270°` (NE), `180°` (SE) e `90°` (SO). Cada canto cobre 2 m de
   cada lado.
3. **Preencha o vão entre os cantos** com módulos de 2 m ou de 4 m. Em 10 m de
   parede sobram 6 m entre os cantos: três módulos de 2 m (ou 4 m + 2 m).
4. **Recorte os vãos.** Troque um módulo reto por `wall_door_2m` (porta) ou
   `wall_opening_2m` (conexão). Nunca sobreponha um módulo de vão a outro.
5. **Pisos por último** (ou antes, tanto faz): repita `floor_tile` a cada 2 m,
   com o centro nos ímpares (`1, 3, 5, …`) para que as bordas coincidam com as
   linhas de parede.
6. **Corredores:** alinhe a ponta do corredor com a abertura da sala. A ponta
   do corredor é aberta; use um canto, uma junção, uma sala ou uma tampa
   (parede + duas pilastras) para fechar.
7. **Escada:** o topo tem 4 m; o piso de cima começa na borda do topo (6 m
   depois do primeiro degrau). Deixe 2 m livres antes do primeiro degrau para
   o jogador tomar impulso.
8. **Mezanino:** use `floor_tile` em `y = 4` e `railing_2m` nas bordas. Deixe
   um vão de 2 m no guarda-corpo exatamente sobre a largura da escada.

Erros comuns (e o que acontece):

| Erro | Sintoma | Correção |
| --- | --- | --- |
| posição em coordenada ímpar | fresta de 1 m ou parede atravessando o piso | usar múltiplos de 2 m |
| canto no lugar de parede reta | 2 m de parede a mais, sobreposição visível | contar os 2 m do canto |
| parede girada 90° errada | parede atravessada no meio da sala | conferir o sentido dos braços |
| escada com o topo fora da borda do piso | degrau final no ar ou fresta | alinhar a borda do topo com a borda do piso |
| guarda-corpo contínuo sobre a escada | jogador não consegue subir | abrir 2 m no vão |

---

## 5. Testes

`tools/ci/modular_test.tscn` roda com física real:

```bash
godot --headless --path . --fixed-fps 60 --audio-driver Dummy \
  res://tools/ci/modular_test.tscn
```

Grupos verificados:

1. **Catálogo** — cada uma das 16 cenas existe, carrega, instancia, tem
   colisão com forma, na camada 1, com volume nos três eixos; os materiais
   compartilhados existem; a documentação está presente.
2. **Dimensões das paredes** — 2 m e 4 m de comprimento, 0,25 m de espessura,
   4 m de altura, nascendo no piso; a parede de 4 m mede o mesmo que duas de
   2 m.
3. **Vãos** — porta de 1,2 m livre até 2,4 m, com verga e ombreiras; abertura
   de 2,0 m livre até 2,6 m, com verga.
4. **Cantos, junção e piso** — braços do canto nos dois eixos, canto externo
   para `−Z`, pilastra maior que a costura, piso 2 × 2 m com topo em `y = 0`,
   dois pisos vizinhos encostados sem sobrepor.
5. **Salas** — piso amostrado em toda a área, varredura horizontal das quatro
   paredes (contínuas fora dos vãos), vãos livres na altura do jogador,
   ausência de teto.
6. **Corredores** — piso nas pontas, paredes laterais, passagem livre na
   altura da cápsula, canto com caminho interno livre, junção com ramo livre
   e lado fechado.
7. **Escada** — altura da rampa medida em 6 pontos (0,33 a 3,67 m), caminho
   livre 2,2 m acima, guardas laterais e inclinação de 33,7° < 45°.
8. **Demonstração** — a cena completa carrega, o jogador e a HUD existem, os
   módulos estão presentes, o jogador nasce no `Spawn`, o mezanino está em
   `y = 4` e as conexões (porta, abertura, canto, sala, escada) estão livres
   para raios na altura do jogador.
9. **Caminhada real** — atravessar a porta, a abertura leste e a abertura da
   sala retangular; bater na parede oeste.
10. **Escada com o jogador** — subir até `y > 3,6`, descer até o piso e
    confirmar que os guarda-corpos seguram nas bordas fechadas.

Resultados reais deste build (Linux e Windows): ver
[`RELEASE_NOTES_ETAPA11.md`](RELEASE_NOTES_ETAPA11.md) e o relatório da
entrega.

---

## 6. Arquivos

| Caminho | Conteúdo |
| --- | --- |
| `maps/modular/materials/` | 5 materiais compartilhados |
| `maps/modular/walls/` | 7 cenas de parede/canto/junção |
| `maps/modular/floors/floor_tile.tscn` | piso 2 × 2 m |
| `maps/modular/structure/` | pilar e guarda-corpo |
| `maps/modular/corridors/` | corredor reto, canto e junção |
| `maps/modular/rooms/` | sala quadrada e retangular |
| `maps/modular/stairs/stairs_straight.tscn` | escada de 4 m |
| `maps/scenes/modular_demo_room.tscn` | cenário montado da demonstração |
| `match/scenes/modular_demo.tscn` | sessão da demonstração (jogador + HUD) |
| `match/scripts/modular_demo.gd` | spawn, mouse, `ESC`, `F11`, leitura de módulos |
| `tools/ci/modular_test.gd` / `.tscn` | teste automatizado |
| `ui/scenes/title_screen.tscn` | botão **DEMONSTRAR MÓDULOS** |

---

## 7. Limitações (propositais)

- **Não** é o laboratório final: o layout da demonstração é só uma amostra.
- **Não** há geração procedural, portas funcionais, portas trancadas, chaves,
  cartões, objetivos, distribuição de itens, criaturas, IA, multiplayer nem
  novas mecânicas do jogador.
- As salas não têm teto e as paredes têm altura fixa de 4 m (sem segundo
  pavimento de paredes).
- A posição definitiva da escada no mapa final não foi decidida.
- Os materiais são cores simples, sem texturas, para manter o custo baixo.
- A escada é reta e tem largura fixa de 2 m; não há escada em L ou caracol.
- O mezanino da demonstração é uma plataforma de 6 × 10 m com guarda-corpos,
  não um segundo andar fechado.
