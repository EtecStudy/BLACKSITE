# Black Sight — Etapa 11 · Sistema modular de salas (v0.11.0)

**Tag:** `v0.11.0-etapa11-modular-rooms`
**Arquivo:** `BlackSight-Etapa11-Modular-Rooms-Windows-x86_64.zip` (Windows x86_64)
**Base:** `v0.9.1-etapa9-drop-fix`

Esta entrega adiciona a **biblioteca modular de salas** e uma **cena de
demonstração independente**, sem substituir a cena de teste de movimentação nem
alterar os sistemas aprovados das etapas anteriores.

## O que foi adicionado

### Biblioteca (`maps/modular/`)

- **Grade de 2 m** com convenções documentadas (origem, eixos, espessuras,
  pontos de encaixe).
- **Paredes**: reta de 2 m, reta de 4 m, vão de porta (1,2 × 2,4 m), abertura de
  conexão (2,0 × 2,6 m), canto interno, canto externo e pilastra de junção.
- **Pisos** de 2 × 2 m com o topo em `y = 0` e espessura de 0,25 m.
- **Corredores**: reto (4 m), canto de 90° e junção em T (6 m + ramo de 2 m).
- **Salas**: quadrada de 10 × 10 m e retangular de 10 × 14 m, montadas com as
  mesmas peças (25 e 35 pisos, 4 cantos e 12/11 paredes).
- **Estrutura**: pilar de 0,5 m com capitel e guarda-corpo de 2 m.
- **Escada reta**: 20 degraus de 0,20 × 0,30 m, 4 m de subida em 6 m
  (**33,7°**), rampa de colisão única e guardas laterais.
- **Materiais compartilhados**: cinco `StandardMaterial3D`; nenhum modelo,
  textura ou plugin externo.

### Demonstração (`match/scenes/modular_demo.tscn`)

Aberta pelo botão **DEMONSTRAR MÓDULOS** na tela inicial (ou pela cena no
editor). Usa o **mesmo jogador, a mesma HUD e o mesmo controlador** das outras
cenas.

O cenário (`maps/scenes/modular_demo_room.tscn`) contém:

- sala quadrada com porta no norte e abertura no leste;
- corredor norte com fundo fechado (parede + pilastras);
- corredor leste → canto de 90° → corredor sul → sala retangular;
- sala retangular com mezanino em `y = 4` (15 pisos), 15 guarda-corpos e a
  escada que liga os dois níveis;
- quatro pilares na sala quadrada;
- `Spawn` e iluminação própria (ambiente + 6 luzes pontuais).

## Como testar manualmente

1. Extraia o ZIP e mantenha `BlackSight.exe` e `BlackSight.pck` na mesma pasta.
2. Execute `BlackSight.exe`.
3. Clique em **DEMONSTRAR MÓDULOS**.
4. Ande pelo corredor, entre nas duas salas, passe pela porta e pela abertura,
   suba a escada até o mezanino (`y = 4`) e desça de volta.
5. Confira que os guarda-corpos seguram nas bordas fechadas do mezanino e que
   não há frestas entre as peças.
6. `ESC` volta ao menu; `F11` alterna a tela cheia.

A cena **TESTAR MOVIMENTAÇÃO** (Etapa 5/9) continua exatamente como antes.

## Controles (inalterados)

`W A S D` andar · `Shift` correr · `Ctrl` agachar · `E` interagir/pegar ·
`1 2 3` selecionar slot · `G` soltar item · `R` remover (provisória) ·
`Mouse` olhar · `Esc` pausa/menu · `F11` tela cheia.

## Testes automatizados

- `tools/ci/modular_test.tscn` — 10 grupos com física real: catálogo, dimensões,
  vãos, cantos/piso, salas, corredores, escada, demonstração, caminhada e
  escada com o jogador.
- Regressão completa: `smoke_test`, `ui_flow_test`, `movement_test` (contém a
  suíte do inventário e do drop), `drop_obstacle_test` e o build exportado.

As contagens reais desta execução (Linux e Windows) e o SHA-256 do ZIP estão
nas seções geradas automaticamente abaixo.

## Limitações (propositais)

- A demonstração é uma **amostra** das peças, não o laboratório final.
- Sem geração procedural, portas funcionais/trancadas, chaves, cartões,
  objetivos, distribuição de itens, criaturas/IA, multiplayer ou novas
  mecânicas do jogador.
- Paredes de altura fixa (4 m), salas sem teto e escada reta de 2 m de largura.
- A posição definitiva da escada no mapa final não foi decidida.
- O mezanino é uma plataforma com guarda-corpos, não um segundo andar fechado.
