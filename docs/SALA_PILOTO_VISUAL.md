# Sala-Piloto Visual — pesquisa, direção e avaliação

> Etapa de avaliação visual. Este documento registra a pesquisa, a linguagem
> adotada e a construção de **uma única sala independente**. Ele não aprova a
> reconstrução do laboratório, não altera a planta da Etapa 12A e não avança
> para outra etapa.

## 1. Preservação

Antes da sala-piloto, o estado da Etapa 12A foi preservado em:

- commit de checkpoint: `806cb9671b1862c71401b63cbc54498e1f730c62`;
- tag: `v0.12.1-pre-sala-piloto`;
- base da Etapa 12A: `ba5e463f2b3db763a8408cd257c055a519599ae1`;
- release anterior: `v0.12.0-etapa12a-primeiro-andar`.

Jogador, movimentação, corrida, agachamento, inventário, drop, interface,
configurações e demais sistemas aprovados não foram substituídos. A nova
sessão reutiliza a sessão existente e apenas troca cenário e nascimento.

## 2. Pergunta que a sala responde

A Etapa 12A provou escala e circulação, mas os módulos antigos usam materiais
planos, painéis repetidos e pouca informação de superfície. A pergunta desta
etapa é estreita:

> Uma sala de pesquisa/análise de aproximadamente 10 × 12 m, construída com
> arquitetura em camadas, PBR local, iluminação técnica e objetos plausíveis,
> parece um laboratório real do futuro próximo quando vista em primeira pessoa
> — inclusive perto das paredes?

A resposta depende da avaliação manual do usuário. Testes automáticos medem
estrutura, colisão, percurso e renderização; não declaram aprovação estética.

## 3. Síntese da pesquisa

### 3.1 Paredes e salas limpas

Fontes primárias e fabricantes apontam para sistemas flush, laváveis e
modulares, com juntas estreitas, cantos protegidos e serviços acessíveis por
painéis removíveis. A direção adotada não é uma parede lisa pintada: é um
sistema em camadas.

- estrutura opaca de fundo;
- painéis principais com textura sutil e juntas reais na geometria;
- faixa inferior mais resistente;
- faixa de serviços em metal escovado;
- faixa superior mais discreta;
- rodapé sanitário curvo/cove na transição para o piso;
- guarda de parede em áreas de circulação;
- painéis de acesso, grelhas, tomadas, sensores e sinalização pontual.

Referências influentes: sistemas de painéis para salas limpas e hospitais,
portas/janelas higiênicas flush da Dortek, requisitos NIH para laboratórios,
módulos laboratoriais do Fermilab IERC e salas limpas do CERN.

### 3.2 Piso

A referência principal é o vinil homogêneo técnico soldável (Gerflor
Mipolam), e não concreto gasto. Portanto:

- base epóxi/vinílica contínua cinza-azulada;
- flocos minerais muito pequenos;
- painéis de 2 × 2 m apenas como ritmo de instalação/controle;
- variação alternada quase imperceptível;
- cove sanitário subindo pela parede;
- soleira metálica na porta;
- nada de um plano cinza uniforme, azulejos domésticos ou concreto demolido.

O piso da sala usa textura procedural local de 1024 × 1024 com albedo,
normal, roughness e AO derivados do mesmo campo de altura.

### 3.3 Teto

A referência Armstrong TechZone organiza o teto em zonas técnicas, em vez de
espalhar lâmpadas. A sala usa:

- forro perfurado em módulos;
- vigas/soffits periféricos;
- luminárias embutidas 600 × 600 mm equivalentes;
- difusores lineares com aletas;
- duto e quedas técnicas localizadas;
- sprinklers e detectores;
- painel de acesso;
- luz principal fria e neutra, luz de tarefa sobre bancadas, luz fraca no
  vestíbulo/observação e emergência vermelha apenas junto à porta.

Não há teto como laje vazia nem neon decorativo. O pé-direito interno útil é
de aproximadamente 5,2 m até o forro, compatível com o laboratório de 6 m da
Etapa 12A quando somadas estrutura e espessura arquitetônica.

### 3.4 Portas e janelas

A Dortek documenta folhas higiênicas de GRP com cerca de 40 mm, visor flush e
ausência de ressaltos. A porta da sala traduz isso para:

- vão principal na parede sul;
- folha espessa dupla leitura (sala/vestíbulo);
- visor vertical estreito;
- batente metálico contínuo;
- dobradiças, maçaneta de alavanca, leitor de acesso e placa de empurrar;
- soleira metálica;
- vestíbulo escuro atrás, para o visor não mostrar vazio absoluto.

A janela de observação usa vidro duplo/laminado em moldura flush, montantes
reais, peitoril contínuo e sala de observação escura atrás do vidro. Ela fica
sobre a bancada leste, como janela técnica de acompanhamento, não como vitrine
decorativa.

### 3.5 Mobiliário e equipamentos

As dimensões seguem a lógica de casework científico (Kewaunee), capelas
Labconco e serviços de bancada Legrand:

- bancada perimetral oeste com prateleiras e serviços;
- ilha central de 5,0 × 1,2 m com espinha de utilidades;
- bancada leste de análise sob a janela;
- mesa de trabalho com gaveteiros e monitores;
- armários altos fechados;
- carrinho móvel;
- capela de exaustão ao norte;
- cabine de segurança biológica;
- refrigerador e incubadora laboratoriais;
- instrumentos de bancada, centrífuga/analisador simplificado, monitores,
  recipientes, caixas, papéis e cabos curtos organizados.

Os equipamentos são plausíveis e contemporâneos: volumes fechados, painéis,
visores, respiros, botões e indicadores pequenos. Não há máquinas impossíveis,
hologramas ou formas sci-fi aleatórias. Funcionamento interativo não faz parte
desta etapa.

### 3.6 Iluminação

A referência Signify/Philips para salas limpas usa painéis embutidos em torno
de 4000 K, CRI alto e formatos 600 × 600 / 1200 × 300. A sala traduz isso
para o Godot Compatibility com:

- quatro pontos omni principais frios e suaves;
- spots de tarefa sobre a ilha e a bancada oeste;
- luz fraca azulada na sala de observação;
- emergência vermelha localizada;
- materiais emissivos apenas onde uma luminária ou tela existe;
- ambiente frio de baixa energia e tonemap ACES do projeto.

Não se buscou “boate neon”. A luz deve revelar materiais e volumes, não pintar
a sala inteira com uma cor.

### 3.7 Sinalização e pequenos detalhes

Brady/ANSI/ISO orientam sinalização por função e cor, sem excesso. A sala usa
rótulos em português e objetos pequenos com motivo:

- “PESQUISA 04” e “SALA DE PESQUISA E ANÁLISE”;
- saída/rota de fuga;
- extintor e primeiros socorros;
- EPI obrigatório;
- lava-olhos;
- tomadas e pontos de gás na espinha;
- painel elétrico e painel de gases;
- detector, câmera discreta, sensor PIR e interruptor;
- códigos curtos de bancada e armário.

### 3.8 Jogos estudados — princípios, não cópia

- **Control / Alan Wake 2:** consistência de escala dos materiais e
  microdetalhe; pipelines proprietários e ray tracing não são transferidos.
- **Half-Life: Alyx:** densidade de trims e superfícies pensadas para perto da
  câmera.
- **Prey:** poucos conjuntos arquitetônicos fortes, reutilizados com set
  dressing coerente.
- **Ready or Not:** pesquisa de ambientes reais, passes separados de colisão
  e visibilidade.
- **The Last of Us Part II / Metro Exodus:** importância de luz ambiente e
  materiais gastos com parcimônia; GI avançada não é a base no Compatibility.

Nenhum layout, asset ou identidade desses jogos foi copiado.

## 4. Direção visual adotada

| Sistema | Decisão concreta |
|---|---|
| Paredes | Painéis técnicos claros em camadas, faixa inferior resistente, faixa de serviços metálica, juntas e painéis de acesso reais |
| Piso | Vinil/epóxi contínuo cinza-azulado com floco mineral fino, cove sanitário e soleira metálica |
| Teto | Forro perfurado modular, zonas técnicas, difusores, duto localizado, sprinklers e detectores |
| Porta | Folha higiênica espessa com visor flush, batente metálico, leitor e vestíbulo escuro |
| Janela | Vidro duplo flush sobre a bancada leste, com sala de observação escura atrás |
| Móveis | Casework modular claro/grafite, tampos escuros, armários altos e carrinho técnico |
| Equipamentos | Capela, cabine, refrigeração, incubação, analisadores e monitores plausíveis |
| Iluminação | Painéis LED neutros, tarefa localizada, observação fraca e emergência pontual |
| Paleta | Cinza quente, cinza-azulado, grafite, inox, verde-azulado contido e acentos de segurança |
| Desgaste | Baixo a moderado: microvariação, riscos discretos e sujeira localizada; nada destruído |
| Densidade | Alta o bastante para escala e uso, mas com corredores livres e cada objeto com função |

## 5. Assets e licenças

Nenhum asset externo foi baixado ou incorporado nesta implementação. As
tentativas diretas de download a partir do sandbox falharam por TLS; portanto
não se declarou nenhum pacote externo como usado.

As texturas são procedurais, geradas por `tools/arch/build_pilot_room.py`
somente com a biblioteca padrão do Python:

- `wall_panel` — painel pintado técnico;
- `floor_epoxy` — piso epóxi/vinílico;
- `ceiling_panel` — forro metálico perfurado;
- `brushed_metal` — metal escovado;
- `bench_top` — tampo escuro de bancada.

Cada conjunto tem albedo, normal, roughness e AO em PNG. Os materiais ficam
em `maps/pilot/materials/` e as texturas em `maps/pilot/textures/`.

Candidatos pesquisados, **não usados**:

| Fonte/recurso | Situação registrada |
|---|---|
| Poly Haven (`painted_concrete_02`, `concrete_wall_001`, `hangar_concrete_floor`, `metal_plate`) | CC0 na licença geral do site; adequação visual limitada para esta sala |
| ambientCG (`Metal016`, `PaintedMetal001`, `MetalPlates013`, `Tiles074`) | CC0 1.0; alguns enferrujados ou inadequados ao piso principal |
| CGBookcase (`painted-metal-03`, `striped-metal-wall-01`) | Site declara CC0; normal DirectX exigiria conversão para OpenGL |
| ShareTextures | Licença customizada restrita; não tratar como CC0 irrestrito |
| Fab — packs de laboratório | Preço, tier, formatos e licença de cada listing: **não verificados** para uso |

## 6. Construção da sala

Arquivos principais:

- gerador: `tools/arch/build_pilot_room.py`;
- cena: `maps/pilot/pilot_research_room.tscn`;
- sessão: `match/scenes/pilot_room.tscn`;
- sessão script: `match/scripts/pilot_room_session.gd`;
- teste técnico: `tools/ci/pilot_room_test.tscn`;
- capturas: `tools/ci/pilot_room_visual_check.tscn`.

Medidas internas:

- 10,0 m (X) × 12,0 m (Z);
- forro técnico em torno de 5,2 m;
- porta principal ao sul;
- janela de observação a leste;
- circulação livre ao redor da ilha e entre bancadas;
- spawn em `(-2,60; 0,05; 4,35)`, olhando para o interior na sessão jogável.

Contagem estática gerada:

- 689 nós declarados, incluindo a raiz;
- 619 `MeshInstance3D`;
- 23 `CollisionShape3D` em dois corpos estáticos;
- 8 luzes (6 omni + 2 spots);
- 8 `Label3D`;
- 34 materiais;
- 275 malhas reutilizáveis e 14 formas de colisão reutilizáveis, segundo o
  gerador;
- texturas PNG somam 2.301.285 bytes antes da importação/compressão do Godot.

O custo real de draw calls, primitivas e memória de texturas deve ser lido do
log da captura no CI, não estimado a partir da contagem de nós.

## 7. Como testar manualmente

1. Abra o jogo e clique em **SALA-PILOTO VISUAL**.
2. Comece olhando da entrada para a ilha, a capela e os armários.
3. Aproxime-se de uma parede até poucos centímetros e observe juntas,
   rodapé/cove, faixa de serviços e textura.
4. Olhe para o teto: luminárias, difusores, duto, sprinklers e detectores.
5. Desça o olhar para o piso junto das bancadas: floco, cove, soleira e
   reflexo/roughness.
6. Contorne a ilha pelos dois lados; confira capela, cabine, refrigerador,
   incubadora, mesa, monitores e armários.
7. Pare diante da porta e da janela de observação; verifique visor, batente,
   leitor e o espaço escuro atrás dos vidros.
8. Teste ESC, configurações, VOLTAR AO MENU e retorne à sala.
9. Percorra encostado às bancadas para procurar colisões invisíveis, objetos
   flutuando, z-fighting ou repetições evidentes.

## 8. Validação automática e capturas

Seção a ser preenchida com os resultados reais do CI desta etapa:

- run Linux/Windows: **pendente**;
- verificações da sala-piloto: **pendente**;
- capturas geradas: **pendente**;
- draw calls/primitivas/memória de texturas: **pendente**;
- build Windows e SHA-256: **pendente**;
- percurso manual do usuário: **pendente**.

## 9. Limites honestos

- A geometria é construída com primitivas do Godot e texturas procedurais;
  isso testa direção, escala, materiais e densidade, mas não é um modelo
  escaneado nem um asset de produção final.
- O renderizador é `gl_compatibility`; reflexos e GI são limitados. A sala
  não usa LightmapGI, ReflectionProbe, VoxelGI ou ray tracing nesta etapa.
- Alguns detalhes pequenos podem precisar de ajuste após a avaliação em
  primeira pessoa. Esse é o objetivo da sala-piloto: decidir antes de gastar
  esforço reconstruindo ambientes.
- Nada aqui autoriza reconstruir os 23 ambientes. A próxima decisão é do
  usuário após testar a sala.
