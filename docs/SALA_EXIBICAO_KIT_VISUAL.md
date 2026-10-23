# Sala de Exibição do Kit Visual (0.15.0)

Showroom temporário para desenvolver e avaliar, um por um, os elementos
do kit visual do Black Sight. **Não é uma sala do jogo** — é uma área de
exposição neutra, espaçosa e navegável em primeira pessoa.

## Estrutura

- Galeria retangular de **32 × 14 m**, pé-direito de **5,0 m**, piso e
  paredes neutros apenas para circulação e observação.
- Entrada (spawn) na extremidade oeste; elementos dispostos ao longo do
  eixo central, separados por espaço livre:
  1. **PISO DE TESTE** (x = −9): seção de 6 × 4 m do novo piso vinílico
     de laboratório, embutida no piso neutro (topo 2 mm acima), com
     perfil metálico de borda e soleira de transição. Textura PBR
     procedural de 1024 px desenhada para a placa de 6 m: folhas de 2 m
     com costuras soldadas, speckle mineral e desgaste central leve.
  2. **PAREDE DE TESTE** (x = 0): parede isolada de 6,0 × 2,8 m com 5
     painéis compostos de 1,2 m nas **duas faces**, núcleo escuro visível
     nas junções de 6 mm, tampas superiores, rodapé do sistema com topo
     chanfrado e remate superior de alumínio. Três tintas levemente
     variadas para leitura de painel a painel.
  3. **TETO DE TESTE** (x = 9,6): trecho de 4,8 × 3,6 m a 3,0 m com
     cantoneiras perimetrais, perfis T (malha de 600 mm), 47 placas
     600×600 microperfuradas, **uma célula aberta** para inspecionar a
     construção, uma placa-luminária (apagada nesta etapa) e 6 tirantes
     de suspensão até o teto da galeria.
- **Iluminação neutra inicial**: ambiente claro (0,55), 4 spots de teto
  (2 com sombra) e painéis emissivos simples — apenas para avaliar
  materiais, sem clima de terror nem efeitos.

## Arquivos

- Gerador: `tools/arch/build_exhibition_room.py` (procedural, seed fixa).
- Cena: `maps/exhibition/exhibition_room.tscn` + materiais/texturas em
  `maps/exhibition/materials|textures` (15 materiais, 5 conjuntos PBR).
- Sessão: `match/scenes/exhibition_room.tscn` +
  `match/scripts/exhibition_session.gd` (mesmo padrão da sala de
  movimentação: spawn, ESC pausa, configurações, HUD — controlador
  existente, sem substituições).
- Menu: botão **SALA DE EXIBIÇÃO** na tela inicial.
- Verificação: `tools/ci/exhibition_visual_check.*` (TESTE 3g no Linux,
  TESTE W3c no Windows) com 4 capturas em `ci-logs/exhibition_captures/`.

## Fora desta etapa (propositalmente)

Sem portas, janelas, móveis, equipamentos, props, placas/sinalização,
luminárias definitivas ou qualquer gameplay novo. Os próximos elementos
serão adicionados um por vez, mediante aprovação.
