# Refinamento Visual da Sala-Piloto — Etapa 13B

> Estado inicial deste documento: diagnóstico e plano registrados **antes** da
> implementação. As seções de resultado devem ser preenchidas somente depois
> da regeneração da cena, dos testes e da inspeção das capturas.
>
> Checkpoint anterior à etapa: tag `v0.13.0-pre-refinamento`, criada sobre o
> commit `7843f59` (documentação final da Sala-Piloto v0.13.0). A release
> anterior permanece identificada como `v0.13.0-sala-piloto-visual`.

## 1. Objetivo e limites

Transformar a Sala-Piloto v0.13.0 em uma referência visual mais realista para
o futuro laboratório do Black Sight, refinando somente a sala existente.

Esta etapa não implementa criatura, IA, objetivos, portas funcionais,
multiplayer, voz, combate, eventos de terror, morte, resgate, subfloor, mapa
completo, outras salas nem aplicação automática deste visual aos módulos do
primeiro andar. Movimentação, corrida, agachamento, stamina, câmera,
inventário, pickup/drop, interface, menus, configurações, modularização,
planta do primeiro andar, checkpoints e estrutura futura de multiplayer devem
ser preservados.

O realismo procurado é o de um laboratório moderno, funcional e mantido:
arquitetura construível, escala humana, materiais PBR coerentes, desgaste
funcional concentrado, iluminação com fontes físicas visíveis e detalhes que
tenham função. Não é uma ruína, um showroom, uma nave espacial ou um ambiente
neon.

## 2. Referências reais utilizadas

As referências abaixo orientam proporções e lógica construtiva. Nenhum layout,
asset ou identidade visual foi copiado.

| Tema | Referência | Princípio transferido para a sala |
|---|---|---|
| Projeto de laboratórios | NIH, *Design Requirements Manual* — <https://orf.od.nih.gov/TechnicalResources/Pages/DesignRequirementsManual.aspx> | Acabamentos laváveis e selados, piso monolítico com base sanitária/cove, penetrações vedadas, portas e painéis de acesso controlados. |
| Piso de sala limpa | Gerflor, linha Mipolam BioControl para cleanrooms — <https://www.gerflorusa.com/category/cleanrooms> | Piso contínuo em folha, soldável, com poucas juntas aparentes e transição sanitária para a parede, em vez de grandes placas alternadas. |
| Paredes modulares | Plascore Pharma Cleanrooms — <https://plascore.com/cleanrooms/pharmaceutical/> | Painéis flush, juntas estreitas e seladas, coving em piso/parede/teto, janelas e portas integradas sem ressaltos que acumulem sujeira. |
| Portas e janelas higiênicas | Dortek Cleanroom Windows — <https://dortek.com/product/cleanroom-windows/> | Vidro duplo com faces externas de aproximadamente 6 mm, montagem flush nas duas faces, caixilhos sem fixações aparentes. |
| Teto técnico | Armstrong TechZone — <https://www.armstrongceilings.com/commercial/en/commercial-ceilings-walls/ceilings/techzone-ceiling-family.html> | Organizar luz, difusores, retornos e sprinklers em zonas técnicas legíveis, em vez de espalhar componentes aleatoriamente pelo forro. |
| Luminárias de sala limpa | Signify/Philips Cleanroom CR350B — <https://www.signify.com/global/prof/indoor-luminaires/waterproof-and-cleanroom/cleanroom/philips-cleanroom-cr350b/LP_CF_CR350B_EU/family> | Painéis embutidos 600 × 600 mm, 4000 K, CRI > 90, baixo ofuscamento e vedação; a luz deve nascer de luminárias identificáveis. |
| Mobiliário científico | Kewaunee Signature Series — <https://www.kewaunee.in/pdfs/Wood_Casework.pdf> | Casework modular repetido, alturas de base em torno de 30–35 pol. e profundidades próximas de 22–27,5 pol.; frentes divididas em gavetas e portas reais. |
| Capela de exaustão | Labconco Protector — <https://www.labconco.com/product/6-protector-pass-through-laboratory-hood-with-2-fixtures-1-receptacle-le> | Proporções de capela de bancada, sash de vidro temperado, altura de linha de visão e monitor de fluxo como elementos funcionais. |
| Sistemas prediais | Terra Universal, componentes de cleanroom — <https://www.terrauniversal.com/cleanroom-construction-components.php> | Forro modular com FFUs, painéis cegos e luminárias substituíveis pelo lado da sala; serviços organizados por módulos. |
| Renderer do projeto | Documentação oficial do Godot, renderers — <https://docs.godotengine.org/en/4.4/tutorials/rendering/renderers.html> | O projeto permanece em Compatibility; não presumir VoxelGI/SDFGI nem reflexões caras. Contato e hierarquia devem vir de geometria, AO de material, sombras locais e luzes bem posicionadas. |

### Decisão de escala do teto

A v0.13.0 usa forro a aproximadamente 5,2 m. Para uma sala de pesquisa de
10 × 12 m com bancadas de 0,90 m, porta de 2,56 m e capela de bancada, esse
pé-direito produz leitura de galpão/showroom e afasta as luminárias do plano
de trabalho. O refinamento rebaixa o forro acabado para aproximadamente
**3,20 m**, faixa compatível com laboratórios técnicos e salas limpas com
dutos, FFUs e luminárias embutidas. A planta 10 × 12 m, o spawn, a circulação
e as colisões de piso/paredes serão preservados; a colisão do teto acompanhará
o novo forro.

## 3. Técnicas extraídas de jogos comerciais

Somente princípios de produção foram estudados. Nenhum asset, layout, textura
ou identidade de outro jogo foi copiado.

| Jogo / fonte | Técnica observada | Aplicação permitida aqui | Limite |
|---|---|---|---|
| Half-Life: Alyx — Valve Developer Community, *Hotspot Texturing* <https://developer.valvesoftware.com/wiki/Half-Life:_Alyx_Workshop_Tools/Level_Design/Hotspot_Texturing> | Retângulos de textura/trim mantêm densidade visual e repetição controlada em painéis e bordas. | Painéis, perfis, batentes e trims reutilizáveis com poucos materiais compartilhados. | A ferramenta de hotspot do Source 2 não existe neste gerador; aplica-se só o princípio. |
| Control — Adobe/Substance, biblioteca brutalista de materiais <https://www.adobe.com/products/substance3d/magazine/control-how-one-senior-environment-artist-created-entire-brutalist-material-library.html> | Materiais tileáveis criados em escala conhecida (4 × 4 m) e grande consistência de microdetalhe. | Declarar escala das texturas procedurais e manter variação fina, sem detalhes pequenos demais para a distância de leitura. | Não copiar o brutalismo nem os concretos específicos de Control. |
| Alan Wake 2 — Adobe Blog, tecnologia de arte de ambientes da Remedy <https://blog.adobe.com/en/publish/2024/08/07/remedy-entertainments-environment-art-technology-workflow-alan-wake-2> | Materiais ajustados a faixas PBR com checker; camadas combinadas por altura e máscaras. | Conferir faixas de albedo/roughness/metallic e concentrar desgaste por máscaras funcionais, não por sujeira aleatória. | Northlight, Megascans e o pipeline de camadas da Remedy não são transferíveis ao Godot Compatibility. |
| Prey — 80 Level, produção de arte <https://80.lv/articles/art-production-of-prey> | Poucos conjuntos robustos de parede (executivo, laboratório, industrial, exterior) reutilizados com set dressing. | Tratar a sala como um kit coerente: parede, piso, teto, bancada e equipamento com linguagem única e reutilizável. | Não copiar a identidade Neo Deco nem a Talos I. |
| Ready or Not — VOID Interactive, Vol. 82 <https://voidinteractive.net/vol-82-ready-or-not-development-briefing/> | Níveis fundamentados em pesquisa e referências reais; protótipos descartáveis antes do passe de arte. | Manter a ordem arquitetura → materiais → modelos → detalhes → luz, com função antes de decoração. | Não copiar ambientes, temas ou assets do jogo. |
| Resident Evil 4 Remake — PlayStation Blog <https://blog.playstation.com/2023/03/22/ps5-creators-how-resident-evil-4-harnesses-ps5s-power/> | Ênfase em sombras, silhuetas e detalhes dinâmicos para tensão, sem simplesmente escurecer tudo. | Usar contraste e sombras de contato para dar peso aos objetos, mantendo laboratório legível e mantido. | Não transformar a sala limpa em ambiente degradado de horror. |
| Metro Exodus — NVIDIA/4A Games, GI em Metro Exodus <https://developer.nvidia.com/blog/global-illumination-in-metro-exodus/> | Luz indireta e materiais trabalhando juntos para profundidade. | Simular indireta com ambiente contido, AO, superfícies de rebote claras e sombras locais. | RTGI não é viável nem necessário no renderer Compatibility atual. |
| The Last of Us Part II — Naughty Dog no SIGGRAPH 2020 <https://www.naughtydog.com/blog/naughty_dog_at_siggraph_2020> | Iluminação ambiente baked/probes cuidadosamente integrada a objetos e orçamento de memória. | Priorizar hierarquia de luz estável e contato, com poucas luzes dinâmicas caras. | O sistema baked/probes da Naughty Dog não está disponível neste projeto; não prometer equivalência. |

## 4. Fontes de assets e licenças

Nenhum asset externo será incorporado nesta etapa sem necessidade comprovada.
A sala continuará com texturas procedurais próprias geradas pelo projeto, o
que preserva licença, estilo, desempenho e reprodutibilidade do gerador.

| Fonte | Licença verificada | Candidatos / características | Decisão para a 13B |
|---|---|---|---|
| Poly Haven — <https://polyhaven.com/license> | CC0; uso comercial e redistribuição permitidos, sem atribuição obrigatória. | Texturas PBR com Diffuse/AO/ARM/Rough/Normal GL e Displacement; exemplos de concreto são majoritariamente gastos demais para piso principal de sala limpa. | Não incorporar agora; manter como candidato futuro para microdetalhe pontual após inspeção de arquivo e escala. |
| ambientCG — <https://ambientcg.com/> | CC0, conforme a página institucional e a licença do site. | Metais pintados, placas e superfícies técnicas em múltiplas resoluções. | Não incorporar agora; evitar dependência de download e conversão sem ganho claro sobre o PBR procedural. |
| CGBookcase — <https://www.cgbookcase.com/textures/painted-metal-03> | O site declara CC0 para a textura; mapas Metalness/Roughness e canal-packed, Normal em DirectX. | `Painted Metal 03` seria candidato para armários/equipamentos. | Não incorporar agora; se usado no futuro, converter Normal DirectX → OpenGL e registrar resolução/bytes antes. |
| ShareTextures — <https://www.sharetextures.com/p/license> | “Custom CC0” com restrições: sem redistribuição e sem downloads automatizados/hotlink. | Texturas e modelos fotográficos variados. | Não usar nesta etapa; a licença não deve ser tratada como CC0 irrestrito. |
| Fab — <https://www.fab.com/listings/2982d33a-5ca2-4b30-b315-562afbae25e0> | Licença por listing; o exemplo declara uso pessoal/comercial sem crédito, mas é voltado a FBX/Unreal e exige conferência do listing e dos arquivos. | Pacotes de laboratório com modelos FBX e texturas PBR 2K/4K. | Não incorporar; formatos, polígonos, materiais e custo de conversão não foram verificados arquivo a arquivo. |
| Sketchfab | Licença por asset (CC0, CC BY e variantes). | Modelos individuais de equipamentos e props. | Não incorporar sem abrir cada asset, autor, licença, formato e contagem de polígonos. |

Conclusão de assets: **procedural próprio** para a 13B. Isso não é uma
afirmação de que assets CC0 sejam inadequados; é uma decisão de escopo para
não introduzir dependências, conversões e variação de estilo sem inspeção
completa dos arquivos.

## 5. Diagnóstico da v0.13.0

Baseline medida antes da alteração:

- Cena: 702 nós declarados pelo gerador, 631 `MeshInstance3D`, 23
  `CollisionShape3D`, 9 luzes (7 `OmniLight3D` e 2 `SpotLight3D`), 8 `Label3D`.
- 34 materiais e 20 PNGs PBR, somando 2.318.610 bytes de texturas.
- Captura Linux do CI: 437 draw calls, 19.240 primitivas, 61.793.195 bytes de
  memória de texturas e 68.652.915 bytes de memória de vídeo no quadro medido.
- Problemas visuais prioritários:
  1. pé-direito de 5,2 m incompatível com a escala dos móveis e da porta;
  2. paredes legíveis como caixas finas empilhadas, com pouca profundidade
     entre estrutura, painel, junta, inspeção e proteção;
  3. piso em placas de 2,0 m com alternância visível, sem leitura de folha
     contínua, juntas soldadas e desgaste de circulação;
  4. teto pesado e distante, com duto central dominante e luminárias que não
     coincidem com as principais fontes de luz;
  5. luz principal vinda de quatro `OmniLight3D` flutuantes a meia altura,
     com ambiente relativamente uniforme e pouco contato;
  6. bancadas, armários e equipamentos corretos na função, mas com frentes
     planas, poucos batentes, vedações, trilhos, painéis de controle e bordas;
  7. janela e porta com boa presença, mas vidro, gaxetas, dobradiças, trilhos
     e profundidade de batente ainda simplificados;
  8. rótulos em paredes leste/oeste com orientação suspeita de espelhamento
     por yaw incorreto para a face da parede.

## 6. Classificação A / B / C / D

### A — Manter

- Planta interna de 10 × 12 m, spawn, centro, rota do jogador e colisões
  funcionais já aprovadas.
- Posição e função da porta sul, janela leste com sala de observação e
  vestíbulo.
- Funções de bancada oeste, bancada central, bancada leste, estação de
  trabalho, capela, cabine de segurança, refrigerador e incubadora.
- Sinalização em português, lava-olhos/chuveiro, extintor, primeiros socorros
  e pontos de serviço quando tiverem função clara.
- Pipeline procedural PBR do projeto e reuso de malhas/materiais.

### B — Melhorar

- Paredes: camadas, relevos, juntas, painéis de inspeção, colunas de serviço,
  proteção localizada e variação sutil de cor/roughness/normal.
- Piso: leitura contínua, juntas finas, desgaste em circulação/porta/bancadas
  e contato sob móveis.
- Teto: módulos menores, perfis, zonas técnicas, FFUs, difusores, painéis de
  acesso e luminárias 1200 × 300 mm equivalentes.
- Porta e janela: gaxetas, batentes profundos, dobradiças, trilhos de sash,
  vidro duplo, molduras e sinalização com yaw corrigido.
- Bancadas e armários: frentes divididas, gavetas, puxadores, rodapés,
  tampos com borda, prateleiras com apoios e serviços conectados.
- Equipamentos: capela e cabine com trilhos, baffle, painel de controle,
  exaustão e luz de trabalho; instrumentos com controles e cabos curtos.
- Iluminação: fontes coincidentes com luminárias, spots principais com
  sombra seletiva, luz de tarefa local e ambiente mais contido.
- Detalhes funcionais: tomadas, dados, gases, conduítes, trilhos, sensores,
  grelhas e etiquetas sem multiplicar objetos aleatórios.

### C — Substituir

- O sistema visual de parede em faixas/caixas uniformes por montagem em
  camadas com painéis de profundidades variadas e elementos de inspeção.
- O piso em placas alternadas de 2,0 m por base contínua com juntas finas e
  manchas de uso controladas.
- O teto de painéis grandes e duto central dominante por forro técnico
  modular a 3,20 m com zonas de serviço organizadas.
- As quatro luzes omni principais flutuantes por spots descendentes nas
  luminárias do forro, mantendo luzes locais apenas onde houver fonte.
- O vidro único simplificado da janela por conjunto com dois panos, espaçador,
  gaxetas e moldura flush mais legível.

### D — Remover / não adicionar

- Não adicionar ferrugem aleatória, sujeira pesada, neon, hologramas ou
  clutter sem função para “parecer realista”.
- Não adicionar equipamentos novos sem papel claro na sala.
- Não remover testes, colisões ou sistemas para esconder problemas visuais.
- Não introduzir asset externo de licença, formato ou escala não verificados.

## 7. Ordem de implementação

1. Arquitetura: teto a 3,20 m, paredes em camadas, piso contínuo, porta e
   janela com profundidade.
2. Materiais: ampliar o PBR procedural (metal pintado, metal perfurado,
   contato/AO local) e corrigir orientação de rótulos.
3. Modelos: bancadas, armários, capela, cabine e instrumentos com frentes,
   trilhos, controles e conexões.
4. Detalhes funcionais: conduítes, tomadas/dados/gases, sensores, grelhas,
   bandejas e sinalização consistente.
5. Iluminação: luminárias físicas primeiro; depois spots/omnis locais,
   sombras seletivas e ambiente.
6. Primeira pessoa e performance: rota existente, aproximações, contagens,
   draw calls, primitivas, texturas e memória de vídeo.

## 8. Resultados

Implementação em três commits sobre o checkpoint `v0.13.0-pre-refinamento`:

- `dd8cdcd` — refinamento principal (arquitetura em camadas, PBR procedural,
  forro técnico a 3,20 m, porta/janela detalhadas, iluminação por
  luminárias);
- `8fdf838` — passada corretiva após inspeção das capturas do CI (a primeira
  versão refinada estava escura demais);
- `b4b73ff` — correção da placa da janela e métricas na vista geral.

Cena final (`maps/pilot/pilot_research_room.tscn`, gerada por
`tools/arch/build_pilot_room.py`):

| Item | v0.13.0 | v0.13.1 |
| --- | ---: | ---: |
| Nós | 702 | 929 |
| `MeshInstance3D` | 631 | 855 |
| `CollisionShape3D` | 23 | 23 |
| Luzes | 9 | 12 (8 spots + 4 omnis; 2 spots com sombra) |
| `Label3D` | 8 | 8 |
| Materiais `.tres` | 34 | 43 |
| Texturas PNG | 20 | 28 (2.687.815 bytes) |
| Malhas reutilizáveis | 288 | 446 |
| Formas de colisão reutilizáveis | — | 14 |
| Duplicados entre irmãos | 0 | 0 |

Validação (run `39704865799`, commit
`b4b73ff04ab82530c3b55fb551784de719e6ad40`, verde no Linux e no Windows):

- sala-piloto: **62/62 verificações** no Linux e **62/62** no Windows;
- Windows: fumaça **405**, fluxo de interface **95**, controlador **598**,
  modular **364**, primeiro andar **347** — todas aprovadas;
- métricas do renderizador (Linux, Xvfb/llvmpipe, 1600 × 900,
  `gl_compatibility`, vista geral `01_sala_inteira`): **822 draw calls**,
  **31.544 primitivas**, **70.181.795 bytes** de texturas e **77.248.215
  bytes** de memória de vídeo. A v0.13.0 media 437 draw calls e 19.240
  primitivas em enquadramento amplo comparável: a densidade de detalhes
  quase dobrou as draw calls, que hoje são o custo dominante (as primitivas
  continuam baixas). É aceitável para uma sala isolada em GPU intermediária,
  mas **não deve ser replicado para o prédio inteiro sem instanciamento,
  mesclagem de geometria estática ou LOD**;
- capturas: **15 imagens** (12 obrigatórias + 3 closes de sinalização) em
  `docs/screenshots/sala-piloto/`.

Defeitos encontrados na inspeção das capturas e corrigidos antes da entrega:

- iluminação geral escura demais (ambiente 0,34→0,55; spots principais
  2,35→3,6 com ângulo 72° e atenuação 0,85; difusores 1,55→2,3; sombras de
  spots reduzidas de 4 para 2; luz vermelha de emergência 0,35→0,16);
- guarda-corpo da parede sul atravessando a folha da porta — segmentado fora
  do vão (−2,95…−1,45);
- juntas do piso pretas e largas — 12 mm em cinza médio;
- vigas do forro pretas e pesadas — perfil de 0,14 m em `ceiling_panel`;
  soffits em `painted_metal_gray`;
- fitas luminosas sob prateleiras largas demais — 0,28/0,24 m → 0,12 m;
- rótulo "OBSERVAÇÃO" cortado ao meio: a causa raiz **não era orientação**
  (o teste de base — determinante +1 e eixo Y para cima — sempre esteve
  verde, e os rótulos de EPI e da porta sempre renderizaram corretos). A
  placa (topo em 3,00 m) ficava com a metade superior dentro do soffit do
  forro (2,88–3,08 m), que a cortava exatamente na linha do texto. Placa e
  rótulo desceram para 2,76 m (placa de 0,18 m, entre a verga da janela,
  topo 2,67 m, e o soffit). Verificação visual nos closes
  `13_sinalizacao_janela.png`, `14_sinalizacao_epi.png` e
  `15_sinalizacao_porta.png`.

Entrega:

- tag/release: `v0.13.1-sala-piloto-refinamento` (alvo `b4b73ff`);
- ZIP: `BlackSight-Sala-Piloto-Refinada-Windows-x86_64.zip`,
  **42.567.970 bytes**;
- SHA-256: `38514d90280357b3af2c5db37f6db1ee1e47f83c07f20cb90db0db8922c9e3cb`
  (calculado pelo job do Windows durante o empacotamento; o ZIP também
  contém `SHA256SUMS.txt`);
- avaliação manual do usuário: **pendente** — esta etapa para aqui.

## 9. Avaliação honesta

Notas internas 0–10 após inspeção das 15 capturas finais comparadas com a
v0.13.0. São uma leitura técnica da equipe, **não aprovação do usuário** —
a direção visual definitiva depende da avaliação manual.

| Categoria | Nota | Justificativa curta |
| --- | ---: | --- |
| Arquitetura e legibilidade construtiva | 7 | Paredes em camadas, soffits, forro técnico e rodapé cove leem como laboratório; encontros ainda são caixas primitivas. |
| Materiais e PBR | 6 | PBR procedural completo (albedo/roughness/metallic/normal/AO local) e coerente; sem texturas fotográficas, o microdetalhe em close extremo é limitado. |
| Iluminação | 6 | Hierarquia nasce das luminárias, com contraste e sombras seletivas; sem GI/bake, alguns cantos (sala de observação) seguem escuros e o llvmpipe do CI achata o resultado. |
| Mobiliário e equipamentos | 6 | Silhuetas, frentes, trilhos e controles plausíveis; interiores de capela/cabine e instrumentos seguem simplificados. |
| Detalhes funcionais e sinalização | 7 | Sinalização em pt-BR consistente e legível nos closes; detalhes têm função (tomadas, sensores, grelhas, extintor, inspeções) sem clutter aleatório. |
| Escala e primeira pessoa | 7 | Teto 3,20 m, bancadas e porta em escala; circulação e aproximações validadas por colisões e raios no teste do piloto. |
| Performance | 5 | 822 draw calls numa única sala é alto; exige estratégia de instanciamento/mesclagem antes de virar padrão do prédio. Texturas e primitivas estão sob controle. |
| **Conjunto como referência visual** | **6,5** | Um laboratório mantido, técnico e crível em primeira pessoa — claramente acima da v0.13.0 —, ainda longe de asset de produção AAA. Bom o bastante para avaliar direção; não é a direção definitiva declarada. |
