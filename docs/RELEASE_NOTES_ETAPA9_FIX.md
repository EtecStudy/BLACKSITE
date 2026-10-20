# Black Sight — Etapa 9.1: correção do drop junto a obstáculos

Build Windows x86_64 da **correção do bug** encontrado no teste manual da
Etapa 9. Movimento, câmera, stamina, interação, HUD, inventário e
configurações continuam iguais; o que mudou é **onde o item pode nascer**.

## O que estava errado

Itens soltos perto de **caixas, pilares, paredes e do painel** podiam:

- entrar parcialmente dentro do objeto;
- ficar presos ou afundar;
- cair para uma posição inadequada;
- ficar inacessíveis ou "desaparecer" depois de vários drops.

**Causa:** a posição era validada com **um único raio no centro do item**. Se
ele caísse sobre a **quina** de uma caixa (ou sobre um topo fino), o ponto
passava e o item nascia apoiado só num canto. Sendo um corpo físico, ele
tombava, escorregava pela lateral e podia terminar encaixado na geometria. A
posição nunca era reconferida depois de o item entrar na cena.

## O que mudou

- **Apoio completo:** a pegada inteira do item precisa repousar na **mesma
  superfície** (grade 3×3 de raios, tolerância de 3 cm). Quina, borda ou topo
  fino são recusados.
- **Drop sobre o objeto continua funcionando:** se o topo da caixa tem espaço,
  a busca desliza até 0,4 m sobre esse topo para achar a área apoiada. Não é a
  área em volta do objeto que fica proibida — só o apoio parcial.
- **Confirmação depois de instanciar:** com o item já na cena, a caixa é
  consultada de novo (espaço livre + pegada apoiada). Falhou? O nó é removido,
  o item **continua no inventário** e a HUD mostra `SEM ESPAÇO PARA SOLTAR`.
- **Item não tomba ao assentar:** rotação travada no corpo físico — ele cai,
  assenta e desliza, mas não rola nem vira.
- **Teto não vira chão:** o raio de piso ignora tetos e faces inferiores.

## O que **não** mudou

Inventário de 3 slots, seleção com 1/2/3, **G** para soltar, **E** para
recolher, **R** como remoção provisória, mensagens `SLOT VAZIO`,
`SEM ESPAÇO PARA SOLTAR` e `INVENTÁRIO CHEIO`, pausa bloqueando G/E/1/2/3/R,
HUD, interação da Etapa 7, stamina e controles.

## Testes automatizados (run 39516840747)

| Suíte | Linux | Windows |
| --- | --- | --- |
| Fumaça (`smoke_test.gd`) | 356 | 356 |
| Fluxo de interface (`ui_flow_test.gd`) | 53 | 53 |
| Controlador FPS + inventário + drop (`movement_test.gd`) | 586 | 586 |
| **Drop junto a obstáculos (`drop_obstacle_test.gd`)** | **156** | **156** |

O CI também exporta o `.exe`, executa o build exportado, inspeciona o `.pck`,
confere `FileVersion 0.9.1.0` e renderiza o drop sob Xvfb/OpenGL.
**Isso não substitui o teste manual do usuário.**

## Como testar

1. Extraia o ZIP mantendo `BlackSight.exe` e `BlackSight.pck` na mesma pasta.
2. **BlackSight.exe** → **TESTAR MOVIMENTAÇÃO**.
3. Pegue **ITEM A** com **E** e solte **G** perto de uma caixa: o item deve
   ficar no chão, encostado mas **fora** da caixa.
4. Fique de frente para a caixa e solte outro item: ele deve subir no **topo**
   da caixa, inteiro, sem tombar.
5. Repita perto do pilar, do painel e das paredes. Nenhum item pode ficar
   dentro de nada, afundar ou desaparecer.
6. Encoste de frente na parede e aperte **G**: `SEM ESPAÇO PARA SOLTAR` e o
   item continua no inventário.
7. Recolha tudo com **E** (olhar → `[E] Pegar`).
8. Confira a regressão: WASD, mouse, SHIFT, CTRL, F11, ESC, pausa e
   CONFIGURAÇÕES → CONTROLES com 9 linhas.

## Pacote

| Item | Valor |
| --- | --- |
| Arquivo | `BlackSight-Etapa9-Drop-Fix-Windows-x86_64.zip` |
| Conteúdo | `BlackSight.exe`, `BlackSight.pck`, `LEIA-ME.txt`, `SHA256SUMS.txt` |
| Tamanho | gerado no build — seção **Pacote verificado neste build** |
| SHA-256 | gerado no build — seção **Pacote verificado neste build** |
| Download | <https://github.com/EtecStudy/BLACKSITE/releases/download/v0.9.1-etapa9-drop-fix/BlackSight-Etapa9-Drop-Fix-Windows-x86_64.zip> |

Este ZIP **substitui** o da v0.9.0 (que continua publicado, sem a correção).

## Requisitos

- Windows 10 ou 11 (64 bits)
- GPU com OpenGL 3.3 ou superior (renderizador GL Compatibility)
