# Reconstrução 3D da imagem de referência — cozinha (0.14.0)

Registro da reconstrução da imagem de referência fornecida (cozinha
doméstica degradada, 2560×1440) como cena 3D real e navegável em primeira
pessoa no Godot. A imagem é a fonte de verdade; este documento registra a
análise, as decisões permitidas onde a imagem não alcança e o ciclo de
comparação visual.

## Análise da imagem (Etapa A)

- **Composição:** foto tirada do canto sudeste de uma cozinha, olhando para
  noroeste. À esquerda, porta branca acorrentada na parede oeste; ao fundo,
  cozinha corrida na parede norte (armários aéreos e inferiores, pia,
  micro-ondas, fogão); em primeiro plano, ilha/balcão escuro com xícara
  caída; no chão, diante da ilha, um braço decepado sobre carpete manchado;
  à direita, sombra profunda com abertura escura.
- **Luz:** duas fontes no teto — luminária redonda de luz quente sobre a
  porta e painel fluorescente retangular de luz fria sobre a cozinha;
  fita de luz sob o armário da pia. Contraste alto, cantos escuros e
  atmosfera dessaturada e esverdeada.
- **Desgaste:** paredes com mofo e descascados densos (mais pesados junto à
  porta e na coluna), azulejos encardidos, sangue no rodapé da geladeira e
  no carpete, correntes enferrujadas com cadeados.

## Geometria e escala (Etapa B — decisões)

- Cômodo de **7,2 × 6,4 m**, pé-direito de **2,75 m**, paredes de 15 cm.
- Porta de 1,04 × 2,16 m na parede oeste (z = −0,8); cozinha corrida na
  parede norte (bancada de 0,66 m de profundidade, armários aéreos de
  0,38 m); geladeira de 0,96 × 0,78 × 1,94 m; fogão de 0,75 m; ilha de
  2,5 × 0,98 m com tampo em balanço; coluna de 0,66 × 0,68 m junto à
  parede norte, entre a porta e a geladeira.
- Abertura escura na parede leste (1,0 × 2,15 m) levando a um cômodo sem
  luz — corresponde à massa de sombra no lado direito da foto.
- Câmera da foto estimada em **(3,02; 1,66; 2,82)** olhando para
  **(−1,75; 0,92; −2,05)**, FOV ≈ **63°**; é a câmera `kitchen_01_referencia`
  da verificação visual e a direção inicial do jogador (spawn no mesmo canto).
- Partes ocultas completadas de forma coerente e simples (laterais dos
  eletrodomésticos, traseiras de armários encostadas nas paredes, interior
  escuro do vão leste), sem alterar silhuetas visíveis.

## Construção

- Gerador procedural `tools/arch/build_kitchen_reference.py` (somente
  biblioteca padrão, seed fixa) gera texturas PBR (albedo/normal/roughness/AO),
  materiais e a cena `maps/reference/kitchen_reference.tscn`.
- **13 conjuntos de textura** procedurais (parede, parede pesada, teto,
  carpete, armários, esmalte, frente da geladeira com sangue, pintura da
  porta, azulejo mofado, tampo escuro, ferrugem, madeira, papel) + mancha
  alfa; **32 materiais** nomeados por superfície real.
- **~375 nós**: arquitetura com sanca em dois degraus e rodapés, coluna
  revestida, porta com painéis em relevo, **96 elos de corrente** em curvas
  com flecha e dois cadeados, cozinha completa (pia com torneira pescoço de
  ganso, micro-ondas, torradeira, fogão com chaleira e boca acesa,
  forno elétrico, potes), geladeira com fotos e bilhetes, ilha com xícara
  caída e café derramado, braço com mão e dedos no carpete, moscas perto
  das luzes.
- Iluminação: omni quente (porta) + spot frio com sombra (fluorescente) +
  fill frio + spot de trabalho da pia; ambiente escuro com ajuste de
  contraste/saturação reduzida para o clima da foto. Colisões em piso,
  paredes, coluna, geladeira, bancada e ilha.

## Integração

- Menu **RECONSTRUÇÃO 3D** → `match/scenes/kitchen_reference.tscn`
  (sessão `match/scripts/kitchen_reference_session.gd`, mesmo padrão da
  sala de movimentação: spawn, ESC pausa, configurações, HUD).
- Verificação visual (Linux + Windows): `tools/ci/kitchen_reference_visual_check.*`
  captura 5 ângulos, incluindo a câmera da referência, em
  `ci-logs/kitchen_captures/` (branch `ci-diagnostics`/`ci-windows`).

## Ciclo de comparação

- **Rodada 1** (CI `39861675002`, verde): composição confirmada — porta
  acorrentada, cozinha corrida, ilha e braço nos lugares certos. Diferenças:
  cena clara demais, tampo da ilha espelhado, armários aéreos baixos,
  vão leste selado por painel, manchas duras demais.
- **Rodada 2** (CI `39862585051`, verde): ambiente e albedos escurecidos,
  tampo fosco, armários aéreos elevados até perto da sanca, elos de
  corrente maiores, pele/sangue ajustados. Resultado próximo do clima
  da foto.
- **Rodada 3** (CI `39863626683`, verde): vão leste aberto com moldura em
  tiras (escuridão real), cromo menos preto, tábua/caixa/chaleira
  corrigidas, luzes sem estouro, câmera da foto ajustada (1,63 m).
  Conferência nos dois sistemas: SMOKE 357, UI FLOW 53, MOVEMENT 598,
  DROP 156, KITCHEN 13/13.

**Diferenças restantes (honestas):** a referência tem grão de filme,
profundidade de campo e penumbras mais profundas no canto direito —
efeitos de pós-processo além do escopo do renderizador Compatibility
usado no projeto; o mofo procedural é mais regular que o da foto; objetos
muito pequenos (ganchos, ímãs, fiação) são simplificados. A geometria, as
proporções, a posição da câmera e as duas luzes principais reproduzem a
referência, e a cena é navegável de qualquer ângulo.
