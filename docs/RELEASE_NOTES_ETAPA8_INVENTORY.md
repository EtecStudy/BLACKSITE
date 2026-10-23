# Black Sight — Etapa 8: inventário de três slots

Build Windows x86_64 da **Etapa 8**. Movimento, câmera, stamina, interação, HUD
e configurações continuam como na v0.7.0; o que entra é o **inventário**.

## O que há de novo

- **Três slots fixos** (`Inventory.SLOT_COUNT`), no canto inferior direito da HUD.
- **Coleta por interação**: olhe para um dos quatro itens de teste
  (ITEM A, B, C e D) e pressione **E**. O objeto some e o item entra no primeiro
  slot livre.
- **Seleção com 1 / 2 / 3** pelo InputMap — funciona também em slot vazio. O slot
  selecionado fica com fundo e borda mais claros (mesmos tokens dos botões).
- **Remoção provisória com R**: esvazia o slot selecionado. É uma tecla de teste,
  que será substituída quando existir descarte/uso de item.
- **Inventário cheio**: com os três slots ocupados, pegar o quarto item não troca
  nada — aparece **INVENTÁRIO CHEIO** por instantes e o item continua no cenário.
- **Substituição** (`replace_item`) pronta na API para as próximas etapas.
- **Pausa**: E não pega, 1/2/3 não selecionam e R não remove; ao CONTINUAR, tudo
  continua de onde estava.
- **Lista de controles** com 8 linhas (`1 2 3 — Selecionar slot`).

Sem drop no chão, uso de item, pilha, peso, equipamentos, crafting, objetivos,
portas, criaturas ou multiplayer. A stamina e os controles anteriores estão
intactos.

## Pacote

| Item | Valor |
| --- | --- |
| Arquivo | `BlackSight-Etapa8-Inventory-Windows-x86_64.zip` |
| Conteúdo | `BlackSight.exe`, `BlackSight.pck`, `LEIA-ME.txt`, `SHA256SUMS.txt` |
| Tamanho | 40.669.748 bytes ≈ 38,8 MiB |
| SHA-256 | `4596a98981514a10b94e7a28af22174aa39a576fdb91f21ee645247718e01764` |
| Download | <https://github.com/EtecStudy/BLACKSITE/releases/download/v0.8.0-etapa8-inventory/BlackSight-Etapa8-Inventory-Windows-x86_64.zip> |

Este ZIP **substitui** o da v0.7.0: é uma compilação nova.

## Como testar

1. Extraia o ZIP mantendo `BlackSight.exe` e `BlackSight.pck` na mesma pasta.
2. Duplo clique em **BlackSight.exe** → **TESTAR MOVIMENTAÇÃO**.
3. Olhe para **ITEM A** e pressione **E**: o item desaparece e aparece no slot 1.
4. Repita com **ITEM B** e **ITEM C** (slots 2 e 3).
5. Ainda com o inventário cheio, mire **ITEM D** e pressione **E**: aparece
   **INVENTÁRIO CHEIO** e nada é trocado.
6. Pressione **1**, **2** e **3**: o realce muda de slot, inclusive em slot vazio.
7. Selecione um slot ocupado e pressione **R**: o slot volta a `VAZIO`.
8. **ESC** com um item na mira: a indicação some e **E / 1 / 2 / 3 / R** não
   fazem nada. **CONTINUAR** devolve tudo.
9. Confira a regressão: WASD, mouse, SHIFT (stamina com atraso de 1 s), CTRL
   (ALTERNAR/SEGURAR), F11, ESC, VOLTAR AO MENU e SAIR DO JOGO.
10. Em **CONFIGURAÇÕES → CONTROLES** a lista deve ter 8 linhas, com
    **1 2 3 — Selecionar slot**.

## Requisitos

- Windows 10 ou 11 (64 bits)
- GPU com OpenGL 3.3 ou superior (renderizador GL Compatibility)
