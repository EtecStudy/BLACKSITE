# Pesquisa técnica e visual — Paredes 3D realistas para o Black Sight

**Data da pesquisa:** 21 de outubro de 2026  
**Status:** pesquisa documental concluída; **nenhuma alteração de produção foi feita**  
**Escopo desta etapa:** pesquisar, analisar, comparar e documentar. Não modelar paredes, não substituir módulos, não alterar cenas, não criar uma nova biblioteca e não baixar assets para o projeto.

> **Decisão solicitada ao final:** aprovar, ajustar ou rejeitar a linguagem visual e a lista curta de experimentos antes de qualquer reconstrução de módulos.

---

## 1. Resumo executivo

O problema visual atual do Black Sight não parece ser “falta de polígonos”. A inspeção dos arquivos mostra um sistema modular coerente, mas com materiais `StandardMaterial3D` **planos, sem texturas**, e uma parede principal de **2 × 6 × 0,40 m** cujo relevo decorativo se repete nos dois lados. Em um FPS com corredores longos, isso tende a produzir três efeitos:

1. **Leitura plástica/artificial:** cor, rugosidade e metalicidade constantes não respondem à luz com a microvariação de uma superfície real.
2. **Repetição evidente:** o mesmo ritmo de nervuras aparece em corredores de 5,6 m e 3,6 m, sem hierarquia entre estrutura, painel, junta, rodapé, acesso de manutenção e instalações.
3. **Espessura pouco plausível como acabamento:** 0,40 m pode representar núcleo estrutural ou parede técnica espessa, mas sistemas reais de laboratório/sala limpa normalmente combinam substrato/estrutura com painéis ou revestimentos de aproximadamente **12–76 mm**, juntas seladas, caixilhos flush e transições curvas.

A direção mais fundamentada é:

> **Laboratório científico industrial funcional, construído em camadas:** núcleo/estrutura escura e recuada; painéis laváveis finos; juntas reais e controladas; rodapé curvo ou proteção mecânica; faixas de serviço e painéis de acesso; portas e janelas integradas ao plano da parede; cores funcionais além do cinza; desgaste localizado e legível, sem transformar o laboratório em cenário de nave espacial.

Para uma futura etapa experimental — ainda não executada — os candidatos mais seguros são materiais **CC0** de concreto pintado/mineral e metal pintado, combinados com geometria modular simples. Os packs prontos de Fab/Unreal e os modelos muito low-poly de Sketchfab servem melhor como referência de composição do que como base de produção para Godot.

---

## 2. Método, limites e níveis de evidência

### 2.1 O que foi verificado

- Arquivos locais do projeto: `project.godot`, `README.md`, `.github/workflows/build.yml`, `maps/modular/walls/wall_panel_2m.tscn`, `maps/modular/materials/*.tres` e `docs/ETAPA-12A.md`.
- Páginas diretas de assets e licenças em Poly Haven, ambientCG, CGBookcase e ShareTextures.
- Páginas diretas de produtos/sistemas em Fab e Sketchfab.
- Páginas oficiais de fabricantes e instituições: AES Clean Technology, PortaFab, Plascore, Terra Universal, Trespa, Payette, UT Dallas e Perkins&Will/Fermilab.
- Documentação oficial do Godot para materiais, limitações do Compatibility, LightmapGI, ReflectionProbe, occlusion culling e Mesh LOD.
- Fontes primárias ou próximas da produção dos jogos: Valve Developer Community, Adobe/Substance com artistas da Remedy, ArtStation de artista de *Prey*, blog oficial da VOID Interactive e página técnica oficial da 4A Games.

### 2.2 Níveis de evidência usados neste relatório

| Nível | Significado | Como deve ser lido |
|---|---|---|
| **A — Primária/oficial** | Página do próprio asset, licença oficial, fabricante, instituição ou documentação da engine. | Pode fundamentar licença, mapas declarados, dimensões de produto e comportamento da engine. |
| **B — Produção/artista responsável** | Entrevista, breakdown ou portfólio de quem trabalhou no jogo/projeto. | Boa evidência de workflow e intenção; não prova todos os detalhes internos do produto final. |
| **C — Marketplace/vendedor** | Descrição comercial de pack ou modelo. | Útil para inventário e especificações declaradas; expressões como “AAA” e “otimizado” são alegações do vendedor. |
| **D — Observação visual** | Leitura de screenshots, trailers ou gameplay. | Serve para hipóteses visuais, nunca para afirmar tecnologia interna não documentada. |
| **Não verificado** | Campo não exposto pela fonte consultada ou não confirmado em fonte primária. | Não deve ser transformado em especificação de produção sem nova checagem. |

Nenhuma imagem externa foi incorporada ao repositório. Quando a licença ou a origem não justificava incorporação, este relatório usa **link direto + descrição do que observar**.

---

## 3. Diagnóstico do estado atual do Black Sight

### 3.1 Fatos confirmados nos arquivos

| Item | Evidência local | Leitura |
|---|---|---|
| Engine | `README.md` e `.github/workflows/build.yml` indicam **Godot 4.7.2**. | A pesquisa deve mirar Godot 4.7.2, não uma versão presumida. |
| Renderizador | `project.godot`: `renderer/rendering_method="gl_compatibility"` e `renderer/rendering_method.mobile="gl_compatibility"`. | O projeto usa **Compatibility** no desktop e no mobile. |
| Viewport | `project.godot`: 1920 × 1080, VSync ativado. | A meta visual precisa funcionar em tela cheia, mas sem presumir Forward+ ou efeitos indisponíveis. |
| Escala do mapa | `docs/ETAPA-12A.md`: 127,6 × 93,6 m; 7.248 m²; corredores principais de 5,6 m; corredores de serviço de 3,6 m; pé-direito comum de 6 m e volumes de 12 m. | O problema é de repetição em grande escala, não de uma sala isolada. |
| Módulo-base | `maps/modular/walls/wall_panel_2m.tscn`: corpo de **2 × 6 × 0,40 m**. | A largura/altura são aproveitáveis como grade; a espessura deve ser lida como núcleo/estrutura, não como painel de acabamento realista. |
| Relevo atual | O mesmo módulo tem base, nervuras horizontais, remate e montante repetidos nas duas faces. | A simetria bilateral reforça a sensação de “peça de brinquedo” quando repetida em duas fachadas internas diferentes. |
| Materiais atuais | Sete `StandardMaterial3D` em `maps/modular/materials/`; nenhum usa textura de albedo, normal, roughness, AO ou metallic. | Toda a variação atual vem de cor plana + geometria + iluminação. |

### 3.2 Materiais atuais observados

| Arquivo | Cor / resposta atual | Função provável |
|---|---|---|
| `wall_material.tres` | Cinza-azulado escuro; roughness 0,88; metallic 0,05 | Superfície principal da parede |
| `panel_material.tres` | Cinza-azulado médio; roughness 0,72; metallic 0,15 | Painéis/nervuras |
| `trim_material.tres` | Quase preto; roughness 0,45; metallic 0,65 | Acabamentos e montantes |
| `accent_material.tres` | Mostarda; roughness 0,55; metallic 0,35 | Destaque funcional |
| `floor_material.tres` | Cinza muito escuro; roughness 0,94; metallic 0,05 | Piso |
| `stair_material.tres` | Cinza escuro; roughness 0,62; metallic 0,45 | Escadas |
| `light_material.tres` | Branco-azulado emissivo, energia 3,2 | Luminárias |

### 3.3 Diagnóstico

**Pontos fortes a preservar**

- Grade modular clara e escala já aprovada nas etapas anteriores.
- Mapa grande com compartimentação favorável a occlusion culling.
- Materiais compartilhados e geometria estática, portanto uma base potencialmente barata.
- Ausência de dependência atual de texturas enormes ou shaders complexos.

**Fragilidades visuais**

- **Superfície sem microescala:** sem variação de albedo/roughness/normal, poeira, poros, riscos, manchas e desgaste não existem; a luz desliza de forma uniforme.
- **Macroescala repetitiva:** nervuras iguais nos dois lados não distinguem sala limpa, corredor técnico, área de observação ou bastidor de serviço.
- **Construção pouco legível:** não há separação clara entre estrutura, painel removível, junta, caixilho, rodapé, trilho, painel de acesso e instalações.
- **Metal genérico:** valores únicos de metallic/roughness para grandes áreas tendem a ler como plástico pintado ou metal de maquete, dependendo da luz.
- **Cor monótona:** a paleta atual é predominantemente cinza-azulada; a arquitetura real de laboratório usa cor também como código funcional e orientação.

**Conclusão do diagnóstico:** a futura melhoria deve ser principalmente **material + lógica construtiva + variação controlada**, não simplesmente subdividir a parede em mais caixas.

---

## 4. Fundamentos PBR para paredes realistas

### 4.1 O que cada mapa faz

| Canal | O que controla | Uso recomendado em parede de laboratório | Erro comum |
|---|---|---|---|
| **Base Color / Albedo / Diffuse** | Cor base sem luz embutida. | Pintura, concreto, HPL, uPVC, metal pintado; variações sutis de lote, poeira e desgaste. | Usar foto com sombra/AO “queimados” ou cor quase branca/preta. |
| **Normal** | Direção microscópica da superfície; altera luz sem alterar silhueta. | Poros de concreto, costuras finas, textura de pintura, chapa, painéis acústicos, riscos rasos. | Aumentar demais a força e criar “casca de laranja” ou relevo impossível. |
| **Roughness** | Largura/intensidade do brilho. | Diferenças entre pintura fosca, metal escovado, áreas polidas por contato, poeira e umidade. | Roughness constante no módulo inteiro; tudo vira plástico uniforme. |
| **AO — Ambient Occlusion** | Quanto da luz ambiente é bloqueada em cavidades. | Juntas, recessos, atrás de trilhos, painéis e rodapés. | Usar AO forte como sujeira genérica ou duplicar sombra já presente no albedo. |
| **Height** | Altura usada pelo Godot para parallax/ray-marching no material. | Profundidade aparente de juntas, poros e chapas quando vista de frente. | Esperar silhueta, sombra real ou colisão; não substitui geometria em quinas e bordas. |
| **Displacement** | Altura de origem em pacotes PBR; em outros pipelines pode deslocar vértices. | Fonte para gerar Height/Normal ou geometria offline. | Importar como se o Compatibility fosse fazer tessellation automática equivalente a motores high-end. |
| **Metallic / Metalness** | Se a superfície se comporta como metal ou dielétrico. | Metal exposto, aço, alumínio, trilhos; em metal pintado, apenas riscos que expõem o substrato devem tender a metálico. | Marcar parede pintada inteira como metálica; isso escurece e artificializa a pintura. |
| **ARM / ORM empacotado** | Canais combinados: em geral AO/Roughness/Metallic ou Occlusion/Roughness/Metalness. | Economiza texturas quando o material/shader espera esse empacotamento. | Ligar ARM/ORM no slot errado do `StandardMaterial3D`, que usa mapas separados; para ORM, considerar `ORMMaterial3D`. |

### 4.2 Regras específicas para Godot 4.7.2 + Compatibility

1. **Normal precisa estar em estilo OpenGL (Y+).** Use o arquivo `nor_gl` quando existir. Se a fonte entregar apenas DirectX (Y−), inverta o canal verde na importação ou converta o arquivo. Poly Haven oferece Normal GL e DX; CGBookcase declara Normal DirectX; o preview do ambientCG também expõe NormalDX.
2. **Height não é geometria.** A documentação do Godot descreve Height como ilusão por ray-marching; quinas, soleiras, trilhos, rodapés e juntas profundas precisam de malha real.
3. **Texturas repetidas devem ser potência de dois e, para compatibilidade ampla, no máximo 4096 × 4096.** Em PCs modestos, 1K/2K por módulo deve ser o padrão; 4K fica para superfícies herói ou testes controlados.
4. **Compatibility tem menor precisão de cor e não usa HDR interno como Forward+.** Contraste legível de albedo, normal e roughness é mais importante do que depender de reflexos sutis ou pós-processamento.
5. **Transparência deve ser exceção.** Vidros e proteções transparentes são úteis, mas alpha blending tem custo e problemas de ordenação; quando a forma permitir, prefira geometria opaca, alpha scissor ou poucos painéis transparentes bem controlados.
6. **Subsurface scattering e trails de partículas de material não estão disponíveis no Compatibility**, conforme a documentação de `StandardMaterial3D`; não basear a linguagem visual nesses recursos.

### 4.3 Escala física, repetição e costuras

- **Defina metros por textura antes de escolher resolução.** Exemplo: uma textura de 2K cobrindo um painel de 2 m entrega cerca de 10 px/cm; a mesma textura esticada por 6 m cai para aproximadamente 3,4 px/cm e perde presença em FPS.
- **Evite feições únicas grandes dentro do tile.** Manchas memoráveis, rachaduras longas e riscos diagonais denunciam repetição em corredores.
- **Use a junta como parte do desenho.** Em vez de esconder toda costura, alinhe costuras de textura com juntas reais de painel, montantes e painéis de acesso.
- **Quebre o ritmo sem aleatoriedade falsa:** alterne painel liso, painel com acesso, faixa técnica, janela/porta e trecho estrutural em sequência compreensível.
- **Rotação/espelhamento só onde fizer sentido construtivo.** Painéis podem variar; trilhos, textos, setas e desgaste direcional não devem ser espelhados sem critério.
- **Desgaste deve seguir uso:** mais roughness/polimento e riscos perto de maçanetas, rodapés, quinas, carrinhos, portas e painéis removidos com frequência; não espalhar “grunge” uniforme.

### 4.4 Como evitar plástico, brilho falso e uniformidade

- Separar **pintura** de **metal exposto**: pintura é majoritariamente dielétrica; metal aparece em bordas, trilhos, fixadores e danos.
- Variar roughness em pelo menos três leituras: fosco mineral, semibrilho lavável e metal/proteção.
- Evitar albedo plano atrás de normal forte; a cor também precisa de variação de baixa frequência.
- Preferir bordas levemente quebradas por geometria ou normal de trim, em vez de caixas perfeitamente afiadas em close.
- Não usar “detail” genérico em tudo com a mesma escala; concreto, HPL, metal pintado e borracha têm microestruturas diferentes.
- Validar com luz rasante e luz frontal: material bom precisa sobreviver aos dois casos.

---

## 5. Arquitetura real: o que laboratórios e salas limpas ensinam

### 5.1 Sistemas e dimensões verificados

| Fonte direta | Sistema | Dados úteis para o Black Sight | Evidência |
|---|---|---:|---|
| [AES — Walls & Ceilings](https://www.aesclean.com/product/walls-ceilings/) | Profile Wall e Adapt Wall | Profile: painel modular de **50 mm**, acabamento uPVC e juntas cold-welded; Adapt: liner de **12 mm** sobre estrutura metálica com Z-Clips; remates flush em portas/janelas. | A |
| [AES — Windows & Doors](https://www.aesclean.com/product/windows-doors/) | Janelas e portas modulares | Janelas flush/frameless, portas flush com caixilhos soldados, vidro temperado/laminado, preparação para controle de acesso. | A |
| [PortaFab — CleanLine S3000](https://www.portafab.com/cleanline-s3000-wall-system.html) | Sistema autoportante de painéis | Painéis de **76 mm**, faces flush dos dois lados, alturas até **18 pés ≈ 5,49 m**, faces em HPL/FRP/PVC/alumínio/aço e núcleos variados, incluindo alumínio honeycomb. | A |
| [PortaFab — Cleanroom Coving](https://www.portafab.com/cleanroom-coving.html) | Rodapés e cantos curvos | Transições flush parede-piso, parede-teto e parede-parede; raio de **3 pol. ≈ 76 mm** em extrusões de coving. | A |
| [Plascore — Pharma Wall Systems](https://plascore.com/cleanrooms/pharmaceutical/) | Studless, liner e window walls | Studless de **51 mm**; liner de **13 mm**; painéis com faces metálicas ligadas a núcleo de alumínio honeycomb; portas/janelas flush; tetos modulares de 1,5 × 3 m. | A |
| [Terra Universal — BioSafe](https://www.terrauniversal.com/biosafe-wall-panel-systems.php) | Painéis monolíticos/flush | Faces em aço revestido com uPVC ou aço inoxidável; núcleos de alumínio honeycomb ou espuma; painéis desmontáveis, juntas flush e componentes integrados. | A |
| [Trespa — TopLab VERTICAL Uni Colours](https://www.trespa.com/en_US/products/toplab-vertical-uni-colours) + [brochura oficial](https://www.trespa.com/dam/jcr:5c08bcc6-b8b4-41f9-8c9f-e9695e7cab60/I4714_TRESPA%20TOPLAB%20Vertical%20ENGLISH%20web.pdf) | HPL científico para revestimento vertical | Superfície fechada por EBC, resistência química/umidade/impacto; brochura lista espessuras de **6, 8, 10 e 13 mm** e paleta ampla de cores sólidas. | A |
| [Payette — How to Skin a Cleanroom](https://www.payette.com/projects/how-to-skin-a-cleanroom/) | Pele de sala limpa com corredor de observação | Corredor de visita vê as baias sem entrar no envelope limpo; pele combina sólidos, vidro, portas, dutos, plenums e serviços em faixas coordenadas. | B |
| [UT Dallas — NSERL](https://research.utdallas.edu/facilities/nserl) | Laboratório universitário real | Laboratórios modulares flexíveis; grandes janelas dos laboratórios para estações colaborativas; salas de apoio/equipamentos lineares atrás dos módulos principais. | A/B |
| [Perkins&Will — Fermilab IERC](https://perkinswill.com/insights/fermilab-architecture-expansion/) | Laboratório de física/engenharia | Espinha central de serviços com energia, gases, dados e exaustão; laboratórios modulares plug-and-play; transparência entre espaços e laboratórios de aprendizagem visual. | B |

### 5.2 Princípios construtivos extraídos

1. **Parede é um sistema, não uma chapa decorada.** Estrutura, núcleo, face lavável, junta, caixilho e serviço têm profundidades diferentes.
2. **Painel fino sobre substrato é mais plausível** do que aplicar textura de painel diretamente em uma laje visual de 0,40 m sem recuos.
3. **Junta flush não significa junta invisível.** Sistemas reais usam juntas soldadas, seladas ou com spline; a linha pode ser discreta, mas existe e organiza a fachada.
4. **Rodapé é transição funcional:** cove curvo em áreas limpas; proteção reta/metálica em áreas de impacto e serviço.
5. **Altura de 6 m pede empilhamento ou faixa superior.** Como sistemas reais frequentemente trabalham com painéis altos ou chapas de até cerca de 3 m, uma junta horizontal, faixa técnica ou clerestório pode justificar o pé-direito sem repetir um painel único de 6 m.
6. **Observação é arquitetura:** janelas flush e corredores de visualização permitem ver laboratórios sem “entrar” neles — muito adequado para a sala Observation do Black Sight.
7. **Serviços devem aparecer com parcimônia:** eletrocalhas, painéis de acesso, registros, pontos de gás/energia e trilhos devem contar que o prédio funciona, sem virar ruído sci-fi.

### 5.3 O que observar nos links reais

- **AES Profile/Adapt:** observe como portas e janelas ficam no mesmo plano do painel e como o liner fino depende de estrutura atrás.
- **PortaFab S3000/Coving:** observe o rodapé curvo e a transição parede-teto; é o oposto de um rodapé-caixa aplicado sobre a parede.
- **Plascore:** observe a diferença entre parede studless autoportante e liner fino sobre substrato; também as janelas com a mesma espessura da parede.
- **Trespa TopLab:** observe a paleta de cores sólidas e acabamentos foscos/satinados; cor aqui é especificação técnica, não decoração aleatória.
- **Payette Nano3:** observe a pele como diagrama de serviços: vidro onde se observa, sólido onde há plenum/estrutura, portas e dutos coordenados.
- **Fermilab IERC:** observe a espinha de serviços e a ideia de laboratórios adaptáveis; isso ajuda corredores de serviço a parecerem infraestrutura real.

---

## 6. Materiais PBR concretos recomendados para experimentação futura

> “Recomendado” abaixo significa **candidato para teste isolado**, não asset aprovado para produção. Nenhum download foi incorporado ao projeto nesta pesquisa.

### 6.1 Poly Haven — Painted Concrete 02

- **Link direto:** https://polyhaven.com/a/painted_concrete_02
- **Aparência:** concreto pintado escuro, fosco, desgastado, com arranhões finos, marcas de uso e pequenas cavidades.
- **Mapas oferecidos na página:** Diffuse, AO, ARM, Rough, Normal DX, Normal GL e Displacement.
- **Escala/resolução:** página declara largura física de **4 m** e downloads até 16K; em 4K, a própria página indica **10,2 px/cm**. Formatos incluem JPG/PNG/EXR e pacotes por engine.
- **Licença/origem:** Poly Haven, **CC0**; uso comercial e redistribuição permitidos sem atribuição obrigatória, conforme https://polyhaven.com/license.
- **Aplicação no Black Sight:** áreas estruturais, bastidores, corredores de serviço, trechos inferiores sujeitos a desgaste e salas menos “limpas”.
- **Cuidados:** é mais sujo/urbano do que uma sala limpa nova; usar em trechos específicos ou misturar com superfícies mais limpas. Para Godot, usar **Normal GL**.

### 6.2 Poly Haven — Concrete Wall 001

- **Link direto:** https://polyhaven.com/a/concrete_wall_001
- **Aparência:** parede branca de concreto/gesso pintado com linhas de acabamento, tinta lascada, fissuras e desgaste sutil.
- **Mapas oferecidos:** Diffuse, AO, ARM, Rough, Normal DX, Normal GL e Displacement.
- **Escala/resolução:** largura física declarada de **1,5 m**; em 4K, **27,3 px/cm**. Formatos JPG/PNG/EXR e pacotes por engine.
- **Licença/origem:** Poly Haven, **CC0**.
- **Aplicação no Black Sight:** laboratórios claros, observação, escritórios técnicos e trechos onde o branco mineral ajuda a separar ambiente sem recorrer a branco puro.
- **Cuidados:** dano e fissuras podem ficar repetitivos se usados em corredores longos; melhor em painéis delimitados, salas ou trechos com geometria/juntas que interrompam o tile.

### 6.3 ambientCG — Metal016

- **Link direto:** https://ambientcg.com/view?id=Metal016
- **API oficial consultada:** https://ambientcg.com/api/v2/full_json?id=Metal016&include=downloadData,mapData,dimensionsData
- **Aparência:** aço pintado claro/branco, áspero e arranhado, com leitura industrial limpa.
- **Mapas confirmados na API:** Color, Displacement, Normal, Roughness e Metalness.
- **Resolução/formato:** ZIPs **1K, 2K, 4K e 8K**, em JPG e PNG. Para o projeto, 1K/2K seriam o ponto de partida racional.
- **Licença/origem:** ambientCG, **CC0 1.0**; a licença oficial permite uso comercial e inclusão dos arquivos brutos no jogo, sem crédito obrigatório: https://docs.ambientcg.com/license/.
- **Aplicação no Black Sight:** painéis metálicos pintados, portas técnicas, caixilhos, armários de parede e faixas de proteção.
- **Cuidados:** o preview usa NormalDX; verificar se o ZIP contém NormalGL ou inverter o canal verde. Não presumir AO separado — a API consultada não lista AO para este asset.

### 6.4 ambientCG — PaintedMetal001

- **Link direto:** https://ambientcg.com/view?id=PaintedMetal001
- **API oficial consultada:** https://ambientcg.com/api/v2/full_json?id=PaintedMetal001&include=downloadData,mapData,dimensionsData
- **Aparência:** metal pintado amarelo, arranhado e gasto.
- **Mapas confirmados na API:** Color, Displacement, Normal, Roughness, Opacity e Metalness.
- **Resolução/formato:** ZIPs **1K, 2K e 4K**, em JPG e PNG.
- **Licença/origem:** ambientCG, **CC0 1.0**.
- **Aplicação no Black Sight:** cor funcional pontual — proteção de quina, faixa de segurança, equipamento fixo, porta de serviço ou marcação de área técnica.
- **Cuidados:** amarelo é forte; usar como código e acento, não como revestimento dominante. Opacity provavelmente não é necessária para parede opaca.

### 6.5 CGBookcase — Painted Metal 03

- **Link direto:** https://www.cgbookcase.com/textures/painted-metal-03
- **Aparência:** metal pintado PBR de leitura genérica e controlável; a página o apresenta como material tileable com preview de repetição.
- **Mapas no workflow Metalness/Roughness:** Ambient Occlusion, Base Color, Height, Metallic, Normal (DirectX) e Roughness. Também há workflow channel-packed experimental com ORM.
- **Resolução:** 1K, 2K, 3K e 4K; download máximo indicado em 4K.
- **Licença/origem:** CGBookcase declara texturas sob **CC0 1.0**, sem crédito obrigatório: https://www.cgbookcase.com/textures.
- **Aplicação no Black Sight:** candidato principal para painéis metálicos pintados de cor neutra ou personalizável, portas e painéis removíveis.
- **Cuidados:** converter/inverter Normal DirectX para o padrão OpenGL do Godot; validar se a variação visual combina com painéis lisos de sala limpa ou se é rugosa demais.

### 6.6 CGBookcase — Striped Metal Wall 01

- **Link direto:** https://www.cgbookcase.com/textures/striped-metal-wall-01
- **Aparência:** parede metálica com faixas/estrias repetidas, mais industrial do que clínica.
- **Mapas:** Ambient Occlusion, Base Color, Height, Metallic, Normal (DirectX) e Roughness; channel-packed experimental com ORM.
- **Resolução:** 1K, 2K, 3K e 4K.
- **Licença/origem:** CGBookcase, **CC0 1.0** conforme a página de texturas.
- **Aplicação no Black Sight:** áreas de serviço, manutenção, elétrica, logística e trechos traseiros — não como pele principal de laboratório limpo.
- **Cuidados:** o padrão listrado pode dominar corredores; usar em faixas ou salas técnicas delimitadas.

### 6.7 ShareTextures — Brushed Metal 1

- **Link direto:** https://www.sharetextures.com/textures/metal/brushed-metal-1
- **Aparência:** metal escovado/alumínio com direção de escovação visível.
- **Mapas exibidos:** Normal, Specular, Diffuse, Displacement e AO.
- **Resolução indicada:** 1K na página consultada.
- **Licença/origem:** ShareTextures chama de “Custom CC0” com restrições. A página de licença permite uso pessoal/comercial sem atribuição, mas proíbe redistribuição em outros sites/plugins/coleções sem permissão escrita e impõe outras condições: https://www.sharetextures.com/p/license.
- **Aplicação no Black Sight:** apenas como candidato secundário para trilhos, caixilhos, placas e detalhes metálicos.
- **Cuidados importantes:** o workflow usa **Specular**, não um Metallic equivalente direto; exige conversão/validação. Pela licença customizada e pela tensão com os termos, **não tratar como CC0 irrestrito** nem redistribuir o arquivo bruto sem permissão.

### 6.8 ShareTextures — Metal Plate

- **Link direto:** https://www.sharetextures.com/textures/metal/metal-plate
- **Aparência:** chapa metálica de leitura industrial.
- **Mapas exibidos:** Diffuse, Normal, Specular, AO e Displacement.
- **Resolução indicada:** 1K na página consultada.
- **Licença/origem:** mesma cautela de “Custom CC0” restrito da ShareTextures.
- **Aplicação no Black Sight:** placas de piso/parede, proteções e painéis técnicos pontuais, se a licença for aceita após revisão.
- **Cuidados:** não é prioridade porque há alternativas CC0 mais limpas em Poly Haven, ambientCG e CGBookcase.

### 6.9 Materiais a procurar depois, se a etapa for aprovada

Estas são **categorias de busca**, não assets verificados:

- HPL/laminado liso com variação quase invisível, para painéis de sala limpa.
- uPVC/PVC lavável com junta e leve textura de pintura.
- Aço inoxidável escovado com anisotropia sutil e marcas de limpeza.
- Borracha industrial preta para rodapé de impacto e proteção de carrinhos.
- Painel acústico perfurado para escritórios/observação, com furos por geometria apenas em áreas próximas ou normal bem controlado.
- Concreto pré-moldado com juntas de forma e furos de tirante para áreas estruturais.

Nenhum item desta subseção deve ser citado como recurso concreto até ter página direta, mapas e licença verificados.

---

## 7. Modelos e packs 3D: valor real e limites

### 7.1 Fab — Modular Sci-Fi Research Facility

- **Link direto:** https://www.fab.com/listings/4812a333-7e6d-40fb-92d0-667b24d15e9b?lang=en
- **Conteúdo declarado:** paredes, pisos e tetos modulares; tubulações/ventilação; props de laboratório; computadores; máquinas; decals e avisos.
- **Dados técnicos declarados pelo vendedor:** 69 meshes únicos; vértices de 24 a 46.000; LODs e colisão; 5 master materials; 62 material instances; 233 texturas em 512–4096; formatos incluídos: **Unreal Engine**; compatibilidade declarada com Unreal Engine 5.4/5.7 e Nanite.
- **Preço observado:** a página consultada exibiu “From $79.99” em chunk posterior da listing; confirmar antes de qualquer compra.
- **Licença:** listings Fab podem usar Creative Commons Attribution ou Standard License. A documentação oficial explica as tiers Personal/Professional e o limite de receita de US$ 100 mil para Personal: https://dev.epicgames.com/documentation/fab/licenses-and-pricing-in-fab. A Fab Standard License permite uso comercial e distribuição do projeto com o asset incorporado, mas não revenda/redistribuição standalone: https://www.fab.com/eula?lang=en.
- **Uso recomendado:** referência de inventário modular e set dressing; **não** comprar presumindo importação direta para Godot. Sem FBX/glTF/obj de origem confirmado, a conversão pode ser trabalhosa ou inviável.
- **Evidência:** C para conteúdo/preço do vendedor; A para o framework geral de licenças da Fab.

### 7.2 Fab — Sci-Fi Laboratory: Modular Environment Pack

- **Link direto:** https://www.fab.com/listings/2c22570b-fb29-4742-a1cd-5a86dd911e2a
- **Conteúdo declarado:** paredes, pisos e tetos modulares e props de laboratório; formatos incluídos: **Unreal Engine**.
- **Uso recomendado:** referência visual de kit modular e densidade de props.
- **Limites:** preço, licença específica da listing, formatos-fonte e contagem técnica **não verificados** na leitura disponível; a página entrou em verificação de segurança após a descrição inicial.
- **Evidência:** C.

### 7.3 Sketchfab — Laboratory wall pc

- **Link direto:** https://sketchfab.com/3d-models/laboratory-wall-pc-aa5e7257a65b4b63bb958d499336a885
- **Dados do inspector:** 504 triângulos, 360 vértices; canais Base Color, Metalness, Roughness, Normal, AO, Emission e Specular F0.
- **Licença:** **CC Attribution** — gratuito com atribuição obrigatória, conforme a página.
- **Uso recomendado:** estudar uma parede de laboratório extremamente simples e o papel de um terminal/PC integrado.
- **Limites:** geometria muito leve para FPS próximo; não é um sistema de paredes. Crédito ao autor é obrigatório se for usado.

### 7.4 Sketchfab — Horror Wall (Clean)

- **Link direto:** https://sketchfab.com/3d-models/horror-wall-clean-2962fbba914e4b119a1e07a8a151a622
- **Dados do inspector:** 74 triângulos, 56 vértices; parede + porta de laboratório/horror; canais Base Color, Metalness, Roughness, Normal, AO e Specular F0.
- **Licença:** **CC Attribution**.
- **Uso recomendado:** referência de silhueta simples e porta integrada; observar como poucos polígonos dependem quase totalmente de textura.
- **Limites:** não serve como padrão de qualidade para close em FPS moderno; atribuição obrigatória.

### 7.5 ArtStation — SCI-FI Lab 25 e portfólios de jogo

- **Link direto:** https://www.artstation.com/artwork/986Lnq
- **Natureza:** vitrine de ambiente sci-fi de laboratório; nas páginas consultadas não há licença de uso dos assets nem pacote para download.
- **Uso recomendado:** observar composição, hierarquia de painéis, iluminação e set dressing.
- **Limite jurídico:** portfólio não é licença. Não baixar, copiar ou redistribuir imagens/assets sem permissão do autor.

---

## 8. O que os jogos analisados realmente ensinam

### 8.1 *Control* — biblioteca de concretos e escala de material

**Fonte primária de produção:** Adobe Substance Magazine, entrevista com Miro Vesterinen, Senior Environment Artist da Remedy:  
https://www.adobe.com/products/substance3d/magazine/control-how-one-senior-environment-artist-created-entire-brutalist-material-library.html

Fatos documentados:

- A Remedy adotou pipeline fortemente baseado em Substance para *Control*.
- A direção brutalista exigiu foco em forma, materiais e iluminação porque as superfícies eram simples e repetitivas.
- Foram criados nós reutilizáveis para poros, fissuras, micro-rugosidade, descascamento e outros geradores.
- Cerca de **75% dos materiais tileable eram algum tipo de concreto**, com aproximadamente **50 materiais de concreto** diferentes.
- Os materiais tileable de arquitetura foram criados em escala de **4 × 4 m** para troca e reuso consistentes.
- O workflow descrito começa pela height, depois diffuse e smoothness; o concreto foi tratado como material com variação de cor — marrons, verdes e azuis sutis — não como massa cinza.

**Lição para o Black Sight:** não basta “um concreto” ou “um painel”. É preciso uma pequena família de materiais com escala fixa, geradores/variações compartilhadas e diferenças funcionais entre estrutura, laboratório, serviço e observação.

**Limite:** *Control* usa Northlight e pipeline própria; não copiar números de performance nem presumir shaders equivalentes no Compatibility.

### 8.2 *Alan Wake 2* — PBR validado, camadas e scan data

**Fontes:**

- Adobe Blog com Benjamin Lindquist, Principal Technical Environment Artist da Remedy: https://blog.adobe.com/en/publish/2024/08/07/remedy-entertainments-environment-art-technology-workflow-alan-wake-2
- Portfólio do mesmo artista: https://www.artstation.com/artwork/yDPyrO
- Remedy/Northlight: https://www.remedygames.com/article/how-northlight-makes-alan-wake-2-shine

Fatos documentados:

- Materiais foram construídos com realismo e muito scan data; Megascans foi usado e ajustado em Substance Designer para coesão e faixas PBR aceitáveis.
- Tileables não baseados em scan eram majoritariamente procedurais em Designer; texturização única em Painter.
- O motor usava sistema de materiais em camadas combinando materiais por height e máscaras pintadas.
- Benjamin Lindquist desenvolveu PBR checker/swatches replicados entre Substance e engine para validar faixas de albedo/specular.
- A Remedy documenta GPU-driven rendering e meshlets no Northlight — tecnologia **não equivalente** ao Godot Compatibility.

**Lição para o Black Sight:** a parte transferível não é mesh shader nem ray tracing; é a disciplina de **faixas PBR, escala, validação e camadas controladas**. No Godot, camadas devem ser simples: material base + geometria de junta/trim + poucos decals/variações, não um shader de camadas pesado por padrão.

### 8.3 *Half-Life: Alyx* — hotspot/trim, densidade por retângulos e luz pré-calculada

**Fontes oficiais da Valve:**

- Hotspot Texturing: https://developer.valvesoftware.com/w/index.php?title=Half-Life:_Alyx_Workshop_Tools/Level_Design/Hotspot_Texturing
- Lighting: https://developer.valvesoftware.com/wiki/Half-Life:_Alyx_Workshop_Tools/Level_Design/Lighting

Fatos documentados:

- Hotspot texturing aplica retângulos predefinidos de uma textura a faces, especialmente útil para trims e painéis.
- O sistema ajuda a manter densidade de pixels consistente e automatizar alinhamento.
- A documentação de iluminação descreve lightmaps em geometria estática, light probes/cubemaps e modos de luz direta baked/indexed/per-pixel com trade-offs explícitos.

**Lição para o Black Sight:** mesmo sem o sistema Hotspot do Source 2, o princípio é aplicável: uma folha/trim bem desenhada + UVs disciplinadas + geometria modular podem render bordas, juntas e painéis com poucos materiais. No Godot, isso significa desenhar módulos e UVs para reuso, não depender de textura única gigante por parede.

**Limite:** não afirmar que todo o jogo usa exatamente a mesma receita em todas as cenas; a evidência é das ferramentas e do workflow documentado.

### 8.4 *Prey* (2017) — paredes modulares, reuso e otimização declarados pelo artista

**Fonte:** Joel Cuellar, 3D Environment Artist, “Prey — Hardware Labs | Power Plant”:  
https://www.artstation.com/artwork/q3Vne

Nas legendas do próprio portfólio, o artista afirma ter:

- modelado assets de parede personalizados para um corredor dos Hardware Labs;
- criado pisos personalizados e feito set dressing/otimização usando materiais e props existentes;
- reduzido polycount e eliminado materiais redundantes em tetos e na câmara;
- criado acesso/espaço de teto usando materiais existentes.

**Lição para o Black Sight:** realismo em FPS não exige material novo para cada peça; exige **kit modular + reuso inteligente + remoção de materiais redundantes**. Também reforça separar parede, piso, teto e acesso técnico como sistemas coordenados.

**Limite:** portfólio mostra resultado e responsabilidades, mas não publica orçamento de draw calls nem especificações completas de shaders.

### 8.5 *Ready or Not* — referência real, thresholds e passes de produção

**Fontes:**

- VOID Interactive, “Ready or Not Development Briefing Vol. 82”: https://voidinteractive.net/vol-82-ready-or-not-development-briefing/
- Mark Ranson, Art Director/Environment: https://markranson3d.com/projects/zPGnXq

Fatos documentados pela VOID:

- O processo parte de GDD, referências, protótipos e blockouts iterativos.
- Por ser um jogo realista, a equipe declara fazer pesquisa extensa, reunir referências reais e, quando possível, visitar locais para adequar arquitetura ao tema.
- Depois do alpha, há passes explícitos de colisão, visibilidade, navegação, portas e cobertura.

**Lição para o Black Sight:** parede boa também é gameplay: thresholds, portas, cobertura, visibilidade e colisão precisam ser desenhados junto. A troca futura de módulos não pode quebrar os vãos e rotas aprovados.

**Limite:** a fonte não publica uma receita PBR específica de parede; não inventar materiais internos.

### 8.6 *The Last of Us Part II* — luz ambiente baked e orçamento de plataforma

**Fonte:** Naughty Dog, “Naughty Dog at SIGGRAPH 2020”:  
https://www.naughtydog.com/blog/naughty_dog_at_siggraph_2020

A página lista apresentações sobre efeitos GPU-driven, otimizações de baixo nível, fog volumétrico e technical art. Na descrição de technical art, o estúdio enfatiza que grande parte do jogo é ambientemente iluminada e que melhorias no sistema de **baked ambient lighting** foram centrais para manter 30 fps no PS4 dentro do orçamento de memória.

**Lição para o Black Sight:** interiores críveis dependem tanto de luz ambiente coerente quanto de textura. Para o Godot Compatibility, o análogo prudente é **LightmapGI estático + ReflectionProbe bem posicionada**, não tentar reproduzir o renderer da Naughty Dog.

**Limite:** a fonte não é um breakdown de paredes; usar apenas como evidência de estratégia de iluminação/otimização.

### 8.7 *Metro Exodus Enhanced Edition* — o que **não** copiar

**Fonte oficial:** 4A Games, “In-Depth Technical Dive into Metro Exodus PC Enhanced Edition”:  
https://www.4a-games.com.mt/4a-dna/in-depth-technical-dive-into-metro-exodus-pc-enhanced-edition

A 4A descreve RTGI, reflexões ray-traced, materiais simplificados para amostragem de raios e um pipeline feito para GPUs com ray tracing. Isso é útil como contraste: **o Black Sight em Compatibility não deve basear realismo em RTGI, reflexões por pixel ou iluminação totalmente dinâmica**. O caminho compatível é pré-calcular o que é estático e reservar dinâmica para luzes de gameplay realmente necessárias.

### 8.8 *Resident Evil 4 Remake* — silhueta e sombra, sem inventar pipeline de parede

**Fonte:** PlayStation.Blog, “PS5 Creators: How Resident Evil 4 harnesses PS5’s power”, com Hirofumi Nakaoka, Art Director da Capcom:  
https://blog.playstation.com/2023/03/22/ps5-creators-how-resident-evil-4-harnesses-ps5s-power/

Hirofumi Nakaoka afirma que a equipe enfatizou **sombras e silhuetas** mais do que simplesmente escurecer o ambiente. Para o Black Sight, a lição é compositiva: portas, montantes, recessos e proteções precisam ler bem em silhueta antes de receber microdetalhe.

**Limite:** não foi encontrada, nesta pesquisa, fonte primária suficiente para afirmar uma receita específica de materiais de parede do remake. Qualquer afirmação sobre photogrammetry de ambientes deve ser marcada como **não verificado para RE4 Remake** até uma fonte da Capcom ser localizada.

---

## 9. Análise de geometria: o que deve ser malha, normal, cor ou cena separada

### 9.1 Matriz de decisão

| Elemento | Geometria real | Normal/Height | Albedo/Roughness/AO | Cena/peça separada | Motivo |
|---|:---:|:---:|:---:|:---:|---|
| Espessura de parede e vãos | ● |  |  |  | Silhueta, colisão, sombra e leitura espacial. |
| Juntas principais de painéis | ● | ● | ● |  | Junta real cria sombra e organiza módulos; normal aprofunda sem custo alto. |
| Juntas finas/selante |  | ● | ● |  | Escala pequena; geometria em tudo aumentaria peças. |
| Montantes/travessas | ● |  | ● |  | Precisam projetar sombra e marcar ritmo construtivo. |
| Painéis removíveis/acesso | ● | ● | ● | ● | Devem poder variar sem trocar a parede inteira. |
| Molduras de porta/janela | ● |  | ● | ● | Flush real exige caixilho, vedação e profundidade. |
| Vidro de observação | ● |  | ● | ● | Poucos painéis transparentes, com moldura e reflexo controlado. |
| Rodapé curvo | ● |  | ● |  | Curva parede-piso é silhueta e limpeza visual. |
| Proteção contra impacto/carrinhos | ● |  | ● | ● | Altura de impacto precisa de relevo e material próprio. |
| Trilhos de serviço/eletrocalhas | ● |  | ● | ● | Instalações devem ser legíveis e reutilizáveis. |
| Parafusos/fixadores |  | ● | ● |  | Muito pequenos para geometria em escala de mapa. |
| Poros, pintura, micro-riscos |  | ● | ● |  | Função clássica de PBR tileable. |
| Manchas, vazamentos, desgaste local |  |  | ● | decal/peça ocasional | Deve ser localizado; em tile repetido vira padrão. |
| Sinalização, números, avisos |  |  | ● | decal/placa separada | Texto não deve ser espelhado nem repetido no material base. |
| Luminárias e painéis de teto | ● |  | ● | ● | Afetam luz, silhueta e ritmo do corredor. |
| Dutos e shafts | ● |  | ● | ● | Volumes grandes e manutenção do mapa. |

### 9.2 Hierarquia construtiva proposta

Uma parede futura — se aprovada — deve ser pensada em camadas visuais:

1. **Núcleo/estrutura:** concreto, bloco ou parede técnica mais escura; aparece em vãos, shafts, trechos de serviço e onde o painel foi removido.
2. **Substrato/vedação:** faixa recessada escura atrás das juntas; evita ver “nada” entre painéis e cria profundidade barata.
3. **Painel de acabamento:** chapa fina visualmente entre 12–50 mm, com borda e junta compreensíveis.
4. **Sistema de fixação/junta:** montante, spline, selante ou perfil; não precisa modelar cada parafuso.
5. **Interfaces:** porta, janela, painel de acesso, registro, trilho, eletrocalha, luminária e sinalização encaixam na mesma grade.
6. **Proteção e uso:** rodapé curvo, guarda de parede, quinas e placas onde carrinhos e pessoas encostam.

### 9.3 Como tratar os 6 m de pé-direito

Um painel único de 6 m sem subdivisão tende a parecer textura esticada. Alternativas construtivas:

- **Painel inferior + painel superior** com junta horizontal coordenada.
- **Faixa técnica superior** para dutos, eletrocalhas, sensores e luminárias.
- **Clerestório/janela alta** apenas onde fizer sentido funcional.
- **Estrutura aparente** em grandes volumes, com painel apenas até certa altura.
- **Dupla pele parcial** em observação e recepção, sem aplicar a todo o mapa.

A escolha deve variar por função: laboratório limpo, corredor principal, serviço, observação e grandes volumes não devem receber a mesma seção de parede.

### 9.4 Cantos, encontros e vãos

- Canto interno de sala limpa: cove ou perfil arredondado; canto de serviço: quina protegida.
- Encontro parede-teto: faixa de sombra, perfil ou cove; evitar encostar painel texturizado diretamente no teto sem remate.
- Porta: caixilho com profundidade, vedação, dobradiça/maçaneta futuras e soleira coerente; a folha não deve ser apenas um retângulo colorido no plano.
- Janela de observação: vidro recessado ou flush com moldura dupla; reflexo deve ser controlado por roughness/probe, não por transparência excessiva.
- Abertura estrutural de 3,6 × 4,2 m e bocas de 6 m: tratar como pórtico/estrutura, não como “porta sem folha”.

---

## 10. Desempenho no Godot: recomendações fundamentadas

### 10.1 Restrições do renderizador atual

O projeto usa **Compatibility**. Isso favorece:

- materiais opacos e poucos transparentes;
- texturas moderadas e repetidas com escala consistente;
- iluminação estática pré-calculada para a arquitetura;
- probes de reflexão locais e baratas;
- occlusion culling em mapa compartimentado;
- geometria modular agrupada por sala/trecho, em vez de milhares de nós decorativos independentes.

### 10.2 Draw calls, agrupamento e materiais

- **Um material por função, não por peça:** painel claro, painel escuro, metal pintado, metal exposto, concreto, borracha/proteção, vidro e emissivo já formam uma biblioteca suficiente para teste.
- **Agrupar geometria estática por sala/corredor** quando a etapa de implementação for aprovada; manter separadas apenas peças que precisam de variação, interação futura ou culling independente.
- **Evitar um `MeshInstance3D` por nervura/parafuso.** Detalhe miúdo deve ir para normal/trim ou ser fundido à malha do módulo.
- **Manter colisores simples:** a colisão deve acompanhar núcleo, vãos e grandes volumes — não cada junta decorativa.
- **Reusar texturas entre módulos:** trocar cor por material instance/tint com cautela; muitas instâncias únicas aumentam memória e quebram batching/reuso.

### 10.3 Texturas e memória

- Padrão sugerido para teste: **1K ou 2K** por material tileable; 4K apenas em comparação controlada.
- Usar mipmaps e compressão adequada na importação; texturas de cor e dados não devem ser tratadas da mesma forma.
- Preferir **um conjunto coerente** a muitos conjuntos 4K diferentes. Em corredor, memória de textura e repetição importam mais do que resolução máxima.
- Normal/AO/Roughness podem ser menores que o albedo em superfícies secundárias, desde que a leitura não degrade.
- Se usar ORM/ARM, confirmar o empacotamento exato antes de ligar ao material; `StandardMaterial3D` e `ORMMaterial3D` não são intercambiáveis sem checagem.

### 10.4 Occlusion culling, LOD e visibilidade

- A documentação oficial do Godot afirma que occlusion culling é mais eficaz em interiores compartimentados e que apenas `MeshInstance3D` entra no bake automático de occluders; `MultiMeshInstance3D` não entra como occluder automático.
- O mapa do Black Sight, com salas e corredores compartimentados, é um bom candidato — mas isso precisa ser testado com a cena real, não presumido.
- Mesh LOD automático é gerado para cenas importadas (glTF/Blend/FBX etc.); **não presumir LOD automático equivalente para BoxMesh/primitivos atuais**.
- Para módulos simples de parede, LOD pode ser menos importante do que culling, agrupamento e redução de materiais; LOD faz mais sentido em props e peças complexas.

### 10.5 Iluminação e reflexos

- **LightmapGI** é estático e barato em runtime; a documentação recomenda combiná-lo com ReflectionProbe porque lightmap sozinho não fornece reflexos adequados.
- Lightmap exige UV2 válida e pode aumentar tempo de bake/arquivo; deve ser testado em um trecho antes de aplicar ao mapa inteiro.
- **ReflectionProbe em modo Once** é adequada para interiores estáticos e ajuda metais/vidros sem custo de probe em tempo real.
- Como o Compatibility não oferece VoxelGI/SDFGI/SSIL, não desenhar a parede esperando GI dinâmica de motores Forward+.
- Emissivo de luminária não ilumina a cena por si só no pipeline comum; luz real continua precisando de nós de luz ou GI baked.

### 10.6 Orçamento inicial sugerido para um futuro protótipo

Estes são **limites de experimento**, não especificações aprovadas:

| Item | Ponto de partida |
|---|---|
| Materiais de parede no protótipo | 4–6 |
| Texturas por material | Albedo + Normal + Roughness; AO/Metallic apenas quando mudarem a leitura |
| Resolução dominante | 1K/2K |
| Peças por módulo | Núcleo + painel + junta/trim + rodapé/proteção; evitar dezenas de nós |
| Transparência | Somente janela(s) do trecho de teste |
| Iluminação do teste | 1 configuração estática comparável à atual + probe Once |
| Medição | FPS, tempo de frame, draw calls, memória de textura e capturas em luz frontal/rasante |

---

## 11. Licenças e restrições: resumo jurídico-prático

> Isto é um resumo de pesquisa, não aconselhamento jurídico. Antes de incorporar qualquer asset, salvar a página da licença e a página do asset junto ao material de produção.

| Origem | Situação encontrada | Uso comercial | Atribuição | Redistribuição / arquivo bruto | Risco |
|---|---|:---:|:---:|---|:---:|
| **Poly Haven** | CC0 | Sim | Não obrigatória | Permitida, inclusive em produto vendido | Baixo |
| **ambientCG** | CC0 1.0 Universal | Sim | Não obrigatória | Expressamente permitida em jogo | Baixo |
| **CGBookcase** | Site declara CC0 1.0 | Sim | Não obrigatória | Seguir CC0; guardar snapshot da página | Baixo/médio — confirmar por asset |
| **ShareTextures** | “Custom CC0” com restrições | Declarado sim | Declarado não obrigatória | **Não redistribuir sem permissão escrita**; há restrições adicionais | Médio/alto |
| **Fab Standard** | Licença comercial da listing | Sim | Não exigida pela Standard | Não revender/redistribuir standalone; compartilhar com colaboradores do projeto | Médio; depende da tier e da listing |
| **Fab CC BY** | Creative Commons Attribution quando indicado | Sim, conforme CC BY | **Obrigatória** | Conforme CC BY | Médio; verificar listing |
| **Sketchfab CC BY** | Creative Commons Attribution nos dois modelos analisados | Sim, conforme CC BY | **Obrigatória** | Conforme CC BY | Baixo/médio |
| **ArtStation portfólio** | Vitrine, sem licença de asset | Não presumir | Não presumir | Não presumir | Alto se copiar |
| **Fabricantes reais** | Conteúdo institucional/proprietário | Não é asset de jogo | Não aplicável | Não incorporar imagens/modelos sem permissão | Alto se copiar mídia |

Regras práticas:

1. **CC0 verificado** pode entrar em experimento com registro de origem.
2. **CC BY** só entra com crédito planejado e rastreável.
3. **Fab** exige confirmar listing, tier, preço, formatos-fonte e se há arquivos fora do Unreal.
4. **ShareTextures** não deve ser tratado como CC0 comum.
5. **Referência visual não é licença.** ArtStation, fabricantes e jogos servem para estudar, não para extrair assets.

---

## 12. Linguagem visual proposta para o Black Sight

### 12.1 Conceito

**“Infraestrutura científica construída para durar, manter e vigiar.”**

O laboratório deve parecer um prédio real de pesquisa avançada: pesado onde precisa ser estrutural, limpo onde precisa ser controlado, técnico onde precisa ser mantido e legível onde o jogador precisa se orientar. O futuro próximo entra por sistemas integrados e precisão construtiva — não por neon, hologramas ou painéis de nave espacial.

### 12.2 Paleta funcional além do cinza

| Função | Cor/material proposto | Onde usar |
|---|---|---|
| Base mineral clara | Off-white quente, cinza-pedra, concreto pintado claro | Laboratórios, observação, escritórios técnicos |
| Estrutura/serviço | Grafite, concreto escuro, metal fosco | Shafts, manutenção, elétrica, logística, núcleos |
| Painel técnico | Azul-petróleo dessaturado, verde-sálvia escuro ou cinza-azulado controlado | Corredores principais e áreas de pesquisa |
| Segurança/energia | Amarelo mostarda/ocre, laranja queimado pontual | Proteções, faixas, portas de serviço, equipamentos fixos |
| Controle/observação | Vidro escuro, metal escovado, preto técnico | Janelas, caixilhos, postos de controle |
| Sinalização humana | Branco sujo, vermelho de emergência, verde de saída | Placas, números, rotas e avisos |

A cor deve funcionar como **código de lugar**: ao virar um corredor, o jogador entende se está em circulação principal, serviço, observação ou área restrita antes de ler uma placa.

### 12.3 Seção de parede por tipo de ambiente

| Ambiente | Linguagem proposta |
|---|---|
| **Corredor principal (5,6 m)** | Painéis grandes, junta horizontal superior, faixa técnica discreta, proteção inferior, portas/janelas ritmadas; leitura limpa e institucional. |
| **Corredor de serviço (3,6 m)** | Mais estrutura aparente, eletrocalhas, painéis de acesso, concreto/metal pintado, desgaste funcional e sinalização técnica. |
| **Laboratórios** | Painéis laváveis claros, juntas seladas, janelas flush, rodapé curvo, poucos acentos de cor por função. |
| **Observação/Controle** | Vidro amplo com moldura escura, painéis escuros de baixa reflexão, metal escovado e leitura de “vigiar sem entrar”. |
| **Recepção/Cruzamento** | Maior pé-direito tratado com estrutura, faixas superiores e painéis maiores; marco arquitetônico, não apenas corredor largo. |
| **Manutenção/Elétrica/Logística** | Concreto, chapa, trilhos, proteções de impacto, amarelo/ocre funcional e iluminação mais utilitária. |
| **Escadas/grandes volumes** | Estrutura e concreto ganham protagonismo; painel fino não precisa cobrir tudo. |

### 12.4 Repetição modular controlada

A repetição deve ser lida como **sistema construtivo**, não como cópia:

- Repetir: grade, junta, caixilho, rodapé, faixa de serviço e lógica de fixação.
- Variar: tipo de painel, presença de acesso, janela, trilho, cor funcional, desgaste e iluminação.
- Interromper: portas, cruzamentos, shafts, mudanças de material e volumes duplos.
- Evitar: mesma nervura decorativa em todas as salas, dos dois lados, sem função.

### 12.5 O que observar nas referências visuais

- Em **Control**: superfícies “simples” ficam interessantes por escala de material, variação de concreto e luz — não por excesso de props.
- Em **Prey/Hardware Labs**: corredor técnico com parede personalizada, teto com acesso e reuso de materiais; observe a coordenação parede-teto-serviço.
- Em **Payette/NSERL/Fermilab**: janelas de observação e espinha de serviços; observe como vidro e sólido contam a função do prédio.
- Em **AES/Plascore**: painéis flush, cove e caixilhos integrados; observe o rodapé e os encontros antes de olhar a cor.
- Em **Fab Research Facility**: inventário modular e densidade de props; observar composição, mas não copiar a estética sci-fi genérica nem presumir compatibilidade com Godot.

---

## 13. Tabela comparativa de referências concretas

| Referência | Categoria | Link | Aparência | Geometria | Mapas PBR | Licença | Aplicação no Black Sight | Desempenho | Evidência |
|---|---|---|---|---|---|---|---|---|---|
| Poly Haven — Painted Concrete 02 | Material PBR | https://polyhaven.com/a/painted_concrete_02 | Concreto pintado escuro, fosco e gasto | Tile para superfície plana; geometria por conta do módulo | Diffuse, AO, ARM, Rough, Normal DX/GL, Displacement | CC0 | Serviço, estrutura, trechos gastos | Alto se 1K/2K; evitar 8K/16K no mapa todo | A |
| Poly Haven — Concrete Wall 001 | Material PBR | https://polyhaven.com/a/concrete_wall_001 | Branco mineral com tinta lascada e fissuras | Tile de parede delimitada | Diffuse, AO, ARM, Rough, Normal DX/GL, Displacement | CC0 | Laboratório claro, observação, escritórios | Alto em 2K; dano pode repetir | A |
| ambientCG — Metal016 | Material PBR | https://ambientcg.com/view?id=Metal016 | Aço pintado claro, áspero e arranhado | Tile para painéis/chapas | Color, Displacement, Normal, Roughness, Metalness; AO não listado | CC0 1.0 | Painéis, portas e caixilhos pintados | Alto em 1K/2K; verificar Normal GL/DX | A |
| ambientCG — PaintedMetal001 | Material PBR | https://ambientcg.com/view?id=PaintedMetal001 | Metal amarelo pintado e arranhado | Tile para chapas/equipamentos | Color, Displacement, Normal, Roughness, Opacity, Metalness | CC0 1.0 | Acento de segurança/serviço | Alto; usar pontualmente pela cor | A |
| CGBookcase — Painted Metal 03 | Material PBR | https://www.cgbookcase.com/textures/painted-metal-03 | Metal pintado PBR controlável | Tile para painel/porta | AO, Base Color, Height, Metallic, Normal DX, Roughness; ORM experimental | CC0 declarado pelo site | Candidato principal a painel pintado | Alto em 1K/2K; converter Normal | A |
| CGBookcase — Striped Metal Wall 01 | Material PBR | https://www.cgbookcase.com/textures/striped-metal-wall-01 | Parede metálica listrada industrial | Tile com ritmo próprio | AO, Base Color, Height, Metallic, Normal DX, Roughness; ORM experimental | CC0 declarado pelo site | Manutenção, elétrica, logística | Alto; padrão pode dominar | A |
| ShareTextures — Brushed Metal 1 | Material PBR | https://www.sharetextures.com/textures/metal/brushed-metal-1 | Alumínio/metal escovado direcional | Tile para detalhes e trilhos | Normal, Specular, Diffuse, Displacement, AO | Custom CC0 restrito | Trilhos, placas, caixilhos | Médio; 1K e workflow Specular exige conversão | A para página/licença; uso cauteloso |
| ShareTextures — Metal Plate | Material PBR | https://www.sharetextures.com/textures/metal/metal-plate | Chapa metálica industrial | Tile para placas/proteções | Diffuse, Normal, Specular, AO, Displacement | Custom CC0 restrito | Proteção e painel técnico pontual | Médio; não prioritário | A para página/licença; uso cauteloso |
| Fab — Modular Sci-Fi Research Facility | Pack 3D | https://www.fab.com/listings/4812a333-7e6d-40fb-92d0-667b24d15e9b?lang=en | Laboratório sci-fi modular detalhado | 69 meshes declarados; paredes/pisos/tetos/props | PBR declarado; mapas individuais não verificados | Standard ou CC BY conforme listing; preço observado “From $79.99” | Referência de inventário, não base Godot | Declarado LOD/colisão; UE/Nanite não transferível | C + A para framework Fab |
| Sketchfab — Laboratory wall pc | Modelo 3D | https://sketchfab.com/3d-models/laboratory-wall-pc-aa5e7257a65b4b63bb958d499336a885 | Parede de laboratório com PC | 504 triângulos; modelo único | Base Color, Metalness, Roughness, Normal, AO, Emission, Specular F0 | CC Attribution | Referência de terminal integrado | Muito leve; detalhe insuficiente p/ close | A |
| Sketchfab — Horror Wall (Clean) | Modelo 3D | https://sketchfab.com/3d-models/horror-wall-clean-2962fbba914e4b119a1e07a8a151a622 | Parede + porta de laboratório/horror | 74 triângulos; plano simples | Base Color, Metalness, Roughness, Normal, AO, Specular F0 | CC Attribution | Referência de silhueta/porta | Muito leve; depende de textura | A |
| AES Profile / Adapt Wall | Arquitetura real | https://www.aesclean.com/product/walls-ceilings/ | Painel lavável flush, monolítico | Profile 50 mm; Adapt liner 12 mm sobre estrutura | Não aplicável — produto físico | Proprietário; só referência | Modelo construtivo principal | Inspira geometria simples e barata | A |
| PortaFab CleanLine S3000 + Coving | Arquitetura real | https://www.portafab.com/cleanline-s3000-wall-system.html | Painéis flush com faces variadas | Sistema de 76 mm; até 5,49 m; cove de ±76 mm | Não aplicável — produto físico | Proprietário; só referência | Painéis, rodapé curvo e encontros | Inspira poucas peças com silhueta clara | A |
| Plascore Pharma Wall Systems | Arquitetura real | https://plascore.com/cleanrooms/pharmaceutical/ | Painéis metálicos flush e janelas integradas | Studless 51 mm; liner 13 mm; núcleo honeycomb | Não aplicável — produto físico | Proprietário; só referência | Diferença entre parede autoportante e liner | Inspira camadas finas sobre núcleo | A |
| Trespa TopLab VERTICAL | Material real / arquitetura | https://www.trespa.com/en_US/products/toplab-vertical-uni-colours | HPL sólido fosco/satinado em muitas cores | Chapas de revestimento; brochura: 6–13 mm | Não aplicável — produto físico | Proprietário; só referência | Paleta e acabamento de painel científico | Inspira material liso com cor funcional | A |
| *Control* — biblioteca brutalista | Jogo | https://www.adobe.com/products/substance3d/magazine/control-how-one-senior-environment-artist-created-entire-brutalist-material-library.html | Concreto brutalista variado e consistente | Arquitetura simples; detalhe por material/luz | Pipeline Substance; mapas internos não públicos | Jogo comercial; só referência | Família de concretos e escala 4 × 4 m | Não transferível; workflow transferível | B |
| *Alan Wake 2* — Environment Art Technology | Jogo | https://blog.adobe.com/en/publish/2024/08/07/remedy-entertainments-environment-art-technology-workflow-alan-wake-2 | Realismo por scans, camadas e PBR validado | Assets/meshlets Northlight; não copiar engine | Scan/procedural + layered materials; mapas internos não públicos | Jogo comercial; só referência | Disciplina PBR, checker e camadas simples | Northlight não equivale ao Compatibility | B |
| *Prey* — Hardware Labs | Jogo | https://www.artstation.com/artwork/q3Vne | Laboratório/estação técnica modular | Paredes de corredor, pisos, teto e acesso modelados | Materiais existentes reutilizados; mapas não públicos | Portfólio; sem licença de asset | Kit modular e reuso parede/teto | Artista declara redução de materiais/polys | B |
| *Ready or Not* — processo de nível | Jogo | https://voidinteractive.net/vol-82-ready-or-not-development-briefing/ | Realismo grounded em referência real | Blockout, thresholds, portas, cobertura e visibilidade | Não publicado | Jogo comercial; só referência | Parede como gameplay e arquitetura | Passes de colisão/visibilidade documentados | B |
| Fermilab IERC — Perkins&Will | Arquitetura real | https://perkinswill.com/insights/fermilab-architecture-expansion/ | Laboratório modular com espinha de serviços | Labs plug-and-play, vidro e serviços centrais | Não aplicável — edifício real | Proprietário; só referência | Corredores de serviço e observação | Inspira organização, não custo de render | B |

---

## 14. Recursos prioritários para uma futura experimentação

A lista abaixo contém **8 recursos** — dentro da faixa pedida de 5–10. A ordem é de risco crescente e valor de teste.

| Prioridade | Recurso | Por que testar primeiro | Uso no protótipo | Risco principal |
|---:|---|---|---|---|
| 1 | **Poly Haven — Painted Concrete 02** (CC0) | Concreto pintado com mapas completos e Normal GL pronto para Godot. | Estrutura/serviço em um trecho de corredor. | Sujo demais para sala limpa se usado em tudo. |
| 2 | **CGBookcase — Painted Metal 03** (CC0 declarado) | Candidato direto a painel metálico pintado com AO/Height/Metallic/Roughness. | Painel principal de laboratório/corredor. | Normal DirectX exige conversão; validar aspereza. |
| 3 | **ambientCG — Metal016** (CC0) | Metal pintado claro com ZIPs 1K/2K e mapas confirmados por API. | Painéis/portas/caixilhos claros. | Sem AO listado; normal pode exigir inversão. |
| 4 | **Poly Haven — Concrete Wall 001** (CC0) | Branco mineral de alta densidade para ambientes claros. | Sala de observação/laboratório claro delimitado. | Fissuras e lascas repetem em corredor longo. |
| 5 | **CGBookcase — Striped Metal Wall 01** (CC0 declarado) | Ritmo industrial pronto para áreas técnicas. | Manutenção/elétrica/logística. | Pode virar “parede de contêiner” se dominar. |
| 6 | **ambientCG — PaintedMetal001** (CC0) | Acento amarelo funcional já gasto e metálico. | Proteção, porta de serviço ou faixa de segurança. | Cor forte; uso excessivo vira tema industrial genérico. |
| 7 | **AES Profile/Adapt + Plascore Pharma** (referência) | Sistemas reais de 50/51 mm e liners de 12/13 mm. | Desenhar a seção da parede: núcleo + liner + junta + cove. | Não é asset; exige modelagem própria futura. |
| 8 | **Trespa TopLab VERTICAL** (referência) | Paleta HPL científica e acabamentos foscos/satinados reais. | Definir cores e rugosidade alvo dos painéis. | Não é textura pronta; não copiar mídia do fabricante. |

**Fora da lista curta, por enquanto:** packs Fab/Unreal (custo, formato e conversão incertos), modelos Sketchfab CC BY (leves demais e com atribuição), ShareTextures (licença customizada e workflow Specular) e qualquer asset cuja licença/map não tenha sido verificada.

---

## 15. Recomendação final

### 15.1 Decisão visual recomendada

Adotar como hipótese de trabalho — **ainda não como implementação** — a seguinte linguagem:

> **Laboratório científico industrial funcional, com parede em camadas, painéis laváveis de 12–50 mm sobre núcleo/estrutura, juntas flush legíveis, rodapé curvo ou proteção mecânica conforme a função, portas e janelas integradas, faixas de serviço discretas, cores funcionais além do cinza e desgaste localizado por uso.**

### 15.2 O que essa decisão evita

- Parede-monolito de 0,40 m com nervura decorativa igual dos dois lados.
- Textura sci-fi genérica, neon excessivo, hologramas e painéis de nave.
- Concreto cinza único para o prédio inteiro.
- Metal pintado tratado como metal polido.
- Grunge uniforme, brilho plástico e repetição sem hierarquia.
- Dependência de packs Unreal/Nanite ou de efeitos indisponíveis no Compatibility.

### 15.3 Próximo passo sugerido, somente após aprovação

Se esta pesquisa for aprovada, a próxima etapa deve ser um **protótipo isolado e reversível**, sem reconstruir a planta da Etapa 12A:

1. Um trecho curto de corredor principal e um trecho de serviço.
2. Quatro a seis materiais no máximo.
3. Uma seção de parede em camadas aplicada a poucos módulos.
4. Capturas comparativas antes/depois em luz frontal, rasante e de corredor.
5. Medição de FPS/draw calls/memória no Godot 4.7.2/Compatibility.
6. Só depois decidir se a linguagem merece virar biblioteca.

### 15.4 Critérios de aprovação do protótipo futuro

- A parede precisa parecer construída, não texturizada por cima de uma caixa.
- A repetição precisa ser percebida como sistema, não como cópia.
- O jogador precisa distinguir circulação, laboratório, observação e serviço pela arquitetura.
- O custo precisa permanecer adequado a PCs modestos.
- Nenhum vão, rota, colisão ou módulo aprovado pode ser quebrado sem teste específico.

---

## 16. Referências e fontes diretas

### 16.1 Projeto Black Sight

- `project.godot` — renderizador Compatibility, viewport e VSync.
- `README.md` — Godot 4.7.2.
- `.github/workflows/build.yml` — Godot 4.7.2 no processo de build.
- `maps/modular/walls/wall_panel_2m.tscn` — módulo-base de 2 × 6 × 0,40 m.
- `maps/modular/materials/*.tres` — sete materiais atuais sem texturas.
- `docs/ETAPA-12A.md` — escala, corredores, pé-direito e planta aprovada.

### 16.2 Materiais PBR e licenças

- Poly Haven — Painted Concrete 02: https://polyhaven.com/a/painted_concrete_02
- Poly Haven — Concrete Wall 001: https://polyhaven.com/a/concrete_wall_001
- Poly Haven — License: https://polyhaven.com/license
- ambientCG — Metal016: https://ambientcg.com/view?id=Metal016
- ambientCG — PaintedMetal001: https://ambientcg.com/view?id=PaintedMetal001
- ambientCG — License: https://docs.ambientcg.com/license/
- ambientCG — API `full_json`: https://docs.ambientcg.com/api/v2/full_json/
- CGBookcase — Painted Metal 03: https://www.cgbookcase.com/textures/painted-metal-03
- CGBookcase — Striped Metal Wall 01: https://www.cgbookcase.com/textures/striped-metal-wall-01
- CGBookcase — Textures/License: https://www.cgbookcase.com/textures
- ShareTextures — Brushed Metal 1: https://www.sharetextures.com/textures/metal/brushed-metal-1
- ShareTextures — Metal Plate: https://www.sharetextures.com/textures/metal/metal-plate
- ShareTextures — License: https://www.sharetextures.com/p/license
- ShareTextures — Terms: https://www.sharetextures.com/p/terms

### 16.3 Modelos, packs e portfólios

- Fab — Modular Sci-Fi Research Facility: https://www.fab.com/listings/4812a333-7e6d-40fb-92d0-667b24d15e9b?lang=en
- Fab — Sci-Fi Laboratory Modular Environment Pack: https://www.fab.com/listings/2c22570b-fb29-4742-a1cd-5a86dd911e2a
- Fab — Licenses and Pricing: https://dev.epicgames.com/documentation/fab/licenses-and-pricing-in-fab
- Fab — Standard License/EULA: https://www.fab.com/eula?lang=en
- Sketchfab — Laboratory wall pc: https://sketchfab.com/3d-models/laboratory-wall-pc-aa5e7257a65b4b63bb958d499336a885
- Sketchfab — Horror Wall (Clean): https://sketchfab.com/3d-models/horror-wall-clean-2962fbba914e4b119a1e07a8a151a622
- ArtStation — SCI-FI Lab 25: https://www.artstation.com/artwork/986Lnq
- ArtStation — Joel Cuellar, *Prey* Hardware Labs: https://www.artstation.com/artwork/q3Vne
- ArtStation — Benjamin Lindquist, *Alan Wake 2* Environment Art R&D: https://www.artstation.com/artwork/yDPyrO

### 16.4 Arquitetura real e fabricantes

- AES — Walls & Ceilings: https://www.aesclean.com/product/walls-ceilings/
- AES — Windows & Doors: https://www.aesclean.com/product/windows-doors/
- PortaFab — CleanLine S3000: https://www.portafab.com/cleanline-s3000-wall-system.html
- PortaFab — Cleanroom Coving: https://www.portafab.com/cleanroom-coving.html
- Plascore — Pharmaceutical Cleanrooms: https://plascore.com/cleanrooms/pharmaceutical/
- Terra Universal — BioSafe Wall Panel System: https://www.terrauniversal.com/biosafe-wall-panel-systems.php
- Trespa — TopLab VERTICAL Uni Colours: https://www.trespa.com/en_US/products/toplab-vertical-uni-colours
- Trespa — Brochura TopLab VERTICAL: https://www.trespa.com/dam/jcr:5c08bcc6-b8b4-41f9-8c9f-e9695e7cab60/I4714_TRESPA%20TOPLAB%20Vertical%20ENGLISH%20web.pdf
- Payette — How to Skin a Cleanroom: https://www.payette.com/projects/how-to-skin-a-cleanroom/
- UT Dallas — NSERL: https://research.utdallas.edu/facilities/nserl
- Perkins&Will — Fermilab IERC: https://perkinswill.com/insights/fermilab-architecture-expansion/

### 16.5 Jogos e produção

- Adobe — *Control*: Creating a Brutalist Material Library: https://www.adobe.com/products/substance3d/magazine/control-how-one-senior-environment-artist-created-entire-brutalist-material-library.html
- Adobe — *Alan Wake 2*: Environment Art Technology and Workflows: https://blog.adobe.com/en/publish/2024/08/07/remedy-entertainments-environment-art-technology-workflow-alan-wake-2
- Remedy — How Northlight makes *Alan Wake 2* shine: https://www.remedygames.com/article/how-northlight-makes-alan-wake-2-shine
- Valve — *Half-Life: Alyx* Hotspot Texturing: https://developer.valvesoftware.com/w/index.php?title=Half-Life:_Alyx_Workshop_Tools/Level_Design/Hotspot_Texturing
- Valve — *Half-Life: Alyx* Lighting: https://developer.valvesoftware.com/wiki/Half-Life:_Alyx_Workshop_Tools/Level_Design/Lighting
- VOID Interactive — *Ready or Not* Development Briefing Vol. 82: https://voidinteractive.net/vol-82-ready-or-not-development-briefing/
- Mark Ranson — *Ready or Not* Valley of the Dolls: https://markranson3d.com/projects/zPGnXq
- Naughty Dog — Naughty Dog at SIGGRAPH 2020: https://www.naughtydog.com/blog/naughty_dog_at_siggraph_2020
- 4A Games — Metro Exodus PC Enhanced Edition technical dive: https://www.4a-games.com.mt/4a-dna/in-depth-technical-dive-into-metro-exodus-pc-enhanced-edition
- PlayStation.Blog — PS5 Creators: *Resident Evil 4*: https://blog.playstation.com/2023/03/22/ps5-creators-how-resident-evil-4-harnesses-ps5s-power/

### 16.6 Documentação oficial do Godot

- Standard Material 3D e ORM Material 3D: https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html
- Limitações de renderização 3D: https://docs.godotengine.org/en/stable/tutorials/3d/3d_rendering_limitations.html
- Introdução à iluminação global: https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/introduction_to_global_illumination.html
- LightmapGI: https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_lightmap_gi.html
- ReflectionProbe: https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/reflection_probes.html
- Occlusion culling: https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html
- Mesh LOD: https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html

---

## 17. Encerramento

Esta pesquisa termina aqui. **Nenhum módulo foi reconstruído, nenhuma cena foi alterada e nenhum asset foi incorporado ao jogo.**

Aguardar aprovação sobre:

1. a linguagem visual proposta;
2. a lista curta de 8 recursos prioritários;
3. a ideia de protótipo isolado e reversível antes de qualquer biblioteca nova.
