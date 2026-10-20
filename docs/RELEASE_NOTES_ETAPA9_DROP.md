# Black Sight — Etapa 9: soltar itens no ambiente 3D

Build Windows x86_64 da **Etapa 9**. Movimento, câmera, stamina, interação, HUD,
inventário e configurações continuam como na v0.8.0; o que entra é o **drop**.

## O que há de novo

- **G solta o item do slot selecionado** no chão, à frente do jogador. O objeto
  aparece com o nome e pode ser recolhido de novo com **E**.
- **Posição validada por física**: piso com normal para cima, espaço livre para
  a caixa do item e linha de visão. Nada de item dentro de parede, pilar, caixa
  ou da cápsula do jogador — e nada suspenso no ar.
- **Item no mundo com física simples**: assenta no chão, não quica, não rola e
  não bloqueia corredores. Sem arremesso.
- **Recolhimento pelo sistema existente**: `[E] Pegar`, `add_item()` no primeiro
  slot vazio e o objeto só desaparece depois da confirmação.
- **Inventário cheio**: o objeto continua no chão, nenhum item é removido e
  aparece `INVENTÁRIO CHEIO` (aviso da Etapa 8).
- **Slot vazio**: G não cria nada e mostra `SLOT VAZIO`. Nenhum outro slot é
  escolhido automaticamente.
- **Sem espaço**: o drop é cancelado e o item **continua no inventário**
  (`SEM ESPAÇO PARA SOLTAR`).
- **Segurar G solta uma vez só** (borda pelo InputMap).
- **R continua** como remoção provisória de teste; **G** é o caminho normal.
- **Pausa**: G, E, 1/2/3 e R bloqueados; inventário e itens soltos consistentes.
- **Lista de controles** com 9 linhas (`G — Soltar item no chão`).

Sem arremesso, uso, consumo, pilha, peso, equipamentos, crafting, transferência
entre jogadores, drop por morte, criaturas ou multiplayer. Stamina e controles
anteriores intactos.

## Pacote

| Item | Valor |
| --- | --- |
| Arquivo | `BlackSight-Etapa9-Drop-Windows-x86_64.zip` |
| Conteúdo | `BlackSight.exe`, `BlackSight.pck`, `LEIA-ME.txt`, `SHA256SUMS.txt` |
| Tamanho | gerado no build — seção **Pacote verificado neste build** |
| SHA-256 | gerado no build — seção **Pacote verificado neste build** |
| Download | <https://github.com/EtecStudy/BLACKSITE/releases/download/v0.9.0-etapa9-drop/BlackSight-Etapa9-Drop-Windows-x86_64.zip> |

Este ZIP **substitui** o da v0.8.0: é uma compilação nova.

## Como testar

1. Extraia o ZIP mantendo `BlackSight.exe` e `BlackSight.pck` na mesma pasta.
2. Duplo clique em **BlackSight.exe** → **TESTAR MOVIMENTAÇÃO**.
3. Pegue **ITEM A** com **E**.
4. Pressione **G**: o item sai do slot 1, aparece no chão com o nome e o slot
   mostra `VAZIO` (os outros slots não mudam).
5. Olhe para o item e pressione **E**: ele volta para o primeiro slot vazio.
6. Com os três slots cheios, olhe para um item no chão e pressione **E**:
   aparece `INVENTÁRIO CHEIO` e o objeto continua no lugar.
7. Selecione um slot vazio e pressione **G**: aparece `SLOT VAZIO` e nada é
   criado.
8. Fique de frente para uma parede e pressione **G**: aparece
   `SEM ESPAÇO PARA SOLTAR` e o item continua no inventário.
9. **ESC**: G, E, 1/2/3 e R não fazem nada. **CONTINUAR** devolve tudo.
10. Confira a regressão: WASD, mouse, SHIFT (stamina com atraso de 1 s), CTRL
    (ALTERNAR/SEGURAR), F11, ESC, VOLTAR AO MENU, SAIR DO JOGO e
    **CONFIGURAÇÕES → CONTROLES** com 9 linhas.

## Testes automatizados

| Suíte | Resultado |
| --- | --- |
| Fumaça (`smoke_test.gd`) | 348 verificações aprovadas |
| Fluxo de interface (`ui_flow_test.gd`) | 53 verificações aprovadas |
| Controlador FPS + inventário + drop (`movement_test.gd`) | 586 verificações aprovadas |
| Renderização do drop sob Xvfb/OpenGL | `DROP VISUAL OK` — `drop_hud.png` |

Os três jobs do workflow passaram (Linux e Windows): importação, exportação do
`.exe`, execução do build exportado, inspeção do `.pck` e publicação do pacote.
**Este teste automatizado não substitui o teste manual do usuário.**

## Requisitos

- Windows 10 ou 11 (64 bits)
- GPU com OpenGL 3.3 ou superior (renderizador GL Compatibility)
