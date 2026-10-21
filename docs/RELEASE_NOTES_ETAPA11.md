# Black Sight — Etapa 11 · Correção do rodapé (v0.11.2)

**Tag:** `v0.11.2-etapa11-rodape`
**Arquivo:** `BlackSight-Etapa11-Rodape-Windows-x86_64.zip` (Windows x86_64)
**Base:** `v0.11.1-etapa11-correcao` (preservada) e `v0.11.0-etapa11-modular-rooms`

Correção de **um único problema visual** apontado no teste manual: o
rodapé/acabamento escuro aparecia parcialmente **dentro da parede clara** em
alguns encaixes. Escala, planta, corredores, salas, estrutura dos módulos,
movimentação, inventário, ESC e SHIFT **não foram alterados**.

## Causa

Não era posição de cena nem offset de instância. O acabamento das peças estava
modelado pela **face**, não por um perfil de profundidade: várias caixas
terminavam **exatamente** no plano da parede (±0,200) ou no plano da peça
vizinha. Duas faces coplanares com a mesma normal disputam o mesmo pixel
(z-fighting) — e, como o rodapé é escuro e a parede é clara, o acabamento
parece atravessar a parede.

Casos encontrados na 0.11.1:

- **parede reta:** rodapé em −0,270..**−0,200** (fundo exatamente na face da
  parede) e o montante vertical com a **mesma profundidade** do rodapé — as
  duas frentes em −0,270, brigando por 0,14 × 0,35 m em cada módulo;
- **canto interno/externo:** o plinto tinha **0,400 × 0,400**, exatamente a
  coluna — ficava inteiro dentro dela, com as quatro faces coplanares;
- **porta:** batente e rodapé com a **mesma frente** (±0,265), e o batente
  atravessando o rodapé;
- **abertura:** revestimento começando na face do vão (1,800);
- **pilastra de encontro:** faixa e rodapé/topo terminando no mesmo plano
  (0,290).

## Correção (na origem, nas cenas das peças)

Cada acabamento ganhou um **perfil de profundidade explícito** em relação ao
eixo da parede (que ocupa ±0,200). A regra: o acabamento entra pelo menos 2 cm
no sólido e fica pelo menos 5 cm à frente dele — nenhuma face coincide.

| Peça | Antes | Depois |
| --- | --- | --- |
| Rodapé da parede reta | 7 cm, fundo na face | **10 cm**, fundo 2,5 cm embutido |
| Montante / nervura / capitel | montante e rodapé na mesma frente | frentes em 0,26 / 0,27 / 0,32 m (6 / 7 / 12 cm) |
| Plinto de canto | 0,40 × 0,40 (igual à coluna) | **0,57 × 0,57** (envolve a coluna em 8,5 cm) |
| Capitel de canto | 0,40 × 0,40 | 0,50 × 0,50 |
| Faixa de canto | 0,404 | 0,44 |
| Aresta de canto | 5 cm enterrada | 3 cm sobre a quina |
| Batente de porta/abertura | frente igual ao rodapé | entra **1 cm no vão** e termina **sob** a travessa |
| Pilastra de encontro | faixa e rodapé no mesmo plano | faixa 1 cm embutida; rodapé/topo 3 cm à frente |

Nenhum colisor foi criado ou removido: o número de `CollisionShape3D` por peça
continua 1 (parede, cantos, pilastra), 4 (porta) e 4 (abertura).

## Verificação

- **Novo teste automático** (seção [4b] do `modular_test`): mede as caixas de
  malha de cada peça de parede e exige folga ≥ 2 mm entre a face de qualquer
  acabamento e a face do corpo, nenhum acabamento enterrado e a contagem de
  colisores inalterada. Resultado: **0 conflitos** nas seis peças; rodando
  contra a geometria da 0.11.1, acusa **12** — exatamente os do teste manual.
- **Capturas de close no build** (`tools/ci/modular_visual_check.tscn`):
  10 imagens em parede reta (duas distâncias), canto, porta, abertura, junção
  em T, parede rotacionada 90°, lado oposto da parede, pilar do hall e
  corredor inteiro. Ficam em `ci-logs/visual/` no branch `ci-windows`.
- Os testes existentes (fumaça, interface, controlador, drop e modular)
  continuam rodando e precisam passar; as contagens saem no corpo da release.

**Nada disso substitui o teste manual** — a aprovação depende dele.

## Como testar manualmente

1. Extraia o ZIP e mantenha `BlackSight.exe` e `BlackSight.pck` na mesma pasta.
2. Execute `BlackSight.exe` → **DEMONSTRAR MÓDULOS**.
3. Olhe o rodapé do corredor **de perto e de rasante**: nenhuma faixa escura
   dentro do branco, nenhuma borda tremulando.
4. Repita no **canto** oeste do corredor, na **porta** (x ≈ 10), na
   **abertura** (x ≈ 14) e na **junção do ramal** (x ≈ 34).
5. Vá até a sala técnica e olhe a base do pilar do pórtico.
6. Confirme que a escala, os corredores e as salas continuam iguais.
7. Confirme que SHIFT solta a corrida e que ESC abre/fecha a pausa (regressão).

## Controles (inalterados)

`W A S D` andar · `Shift` correr · `Ctrl` agachar · `E` interagir/pegar ·
`1 2 3` selecionar · `G` soltar item · `R` remover · `Esc` pausa ·
`F11` tela cheia

## Ainda fora do escopo

Laboratório definitivo, portas funcionais, geração procedural, criaturas,
objetivos de partida e multiplayer.
