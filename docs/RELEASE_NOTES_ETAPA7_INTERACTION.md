# Black Sight — Etapa 7: sistema genérico de interação

Build Windows x86_64 da **Etapa 7**. A stamina, os controles anteriores e a HUD
aprovada continuam exatamente iguais aos da v0.6.2; o que entra é a
**interação por olhar**.

## O que há de novo

- **Interação por olhar**: um raycast sai do **centro da câmera** em primeira
  pessoa, com alcance de **2,5 m**. Não é distância até o corpo do jogador.
- **Linha de visão**: paredes, pilares e caixas bloqueiam. O que está atrás de
  um obstáculo não pode ser usado.
- **Indicação discreta `[E] Interagir`** no rodapé, centralizada, com os mesmos
  painéis, bordas, tipografia e cores da HUD e das configurações. Sem HUD nova,
  sem ícones, sem neon.
- **Ação `interact` no InputMap**, tecla **E**. Nenhuma tecla está codificada no
  detector: ele usa a ação, então o teclado real e os testes seguem o mesmo
  caminho.
- **O objeto executa a própria ação**: `can_interact()`, `get_interaction_text()`
  e `interact()`. O detector não conhece tipo nenhum de objeto — não existe
  `if objeto is porta`.
- **Objeto de teste**: Painel de Teste de Interação à frente do ponto de partida.
  Ao interagir, mostra **"INTERAÇÃO EXECUTADA"** por instantes e acende a tela.
- **Pausa**: a indicação some, **E não interage** e o foco é preservado. Ao
  **CONTINUAR**, tudo volta a funcionar no mesmo ponto.
- **Lista de controles**: agora com **7 linhas**, incluindo `E — Interagir`.

Nada de inventário, itens, portas, chaves, objetivos, criaturas ou multiplayer
foi antecipado. A stamina (máxima, consumo, atraso de 1 s, recuperação, limiar,
velocidades, sprint, agachamento e HUD) está intacta.

## Pacote

| Item | Valor |
| --- | --- |
| Arquivo | `BlackSight-Etapa7-Interaction-Windows-x86_64.zip` |
| Conteúdo | `BlackSight.exe`, `BlackSight.pck`, `LEIA-ME.txt`, `SHA256SUMS.txt` |
| Tamanho | **40.653.078 bytes** (≈ 38,8 MiB) |
| SHA-256 | `3cdac8c7d64008235694996c145dbe734bb0e7aabc499f1f9b24a8e203f25878` |
| Download | <https://github.com/EtecStudy/BLACKSITE/releases/download/v0.7.0-etapa7-interaction/BlackSight-Etapa7-Interaction-Windows-x86_64.zip> |

Este ZIP **substitui** o da v0.6.2: é uma compilação nova.

## Como testar

1. Extraia o ZIP mantendo `BlackSight.exe` e `BlackSight.pck` na mesma pasta.
2. Duplo clique em **BlackSight.exe** → **TESTAR MOVIMENTAÇÃO**.
3. Olhe para o **Painel de Teste** (à frente, um pouco à direita): a indicação
   `[E] Interagir` aparece no rodapé.
4. Pressione **E**: o painel mostra **INTERAÇÃO EXECUTADA** e a tela acende.
5. Afaste-se mais de **2,5 m** ou olhe para outro lugar: a indicação some e **E**
   não faz nada.
6. Tente olhar o painel por trás de uma parede/caixa: sem linha de visão, não há
   interação.
7. **ESC** com a indicação visível: ela some e **E** não interage. **CONTINUAR**:
   a indicação volta e a interação funciona de novo.
8. Confira a regressão: WASD, mouse, SHIFT (stamina com atraso de 1 s), CTRL
   (ALTERNAR/SEGURAR), F11, ESC, VOLTAR AO MENU e SAIR DO JOGO.
9. Em **CONFIGURAÇÕES → CONTROLES**, a lista deve ter 7 linhas, com
   **E — Interagir**.

## Testes automatizados

Run `39478005585` (`ce95812`), aprovado no Linux e no Windows:

- Fumaça: **251/251**
- Fluxo de interface: **50/50**
- Controlador FPS / interação: **363/363** (grupo `[22]` com 63 verificações)
- `.exe`: `FileVersion 0.7.0.0`, executa headless e com janela (vivo após 25 s)
- `.pck`: formato 4, 90 recursos

O teste manual no Windows (itens A–F de `docs/ETAPA-7.md`) é do usuário e não é
declarado como concluído aqui.

## Requisitos

- Windows 10 ou 11 (64 bits)
- GPU com OpenGL 3.3 ou superior (renderizador GL Compatibility)
