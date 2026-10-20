# Black Sight — Etapa 4: Controlador em primeira pessoa

Build Windows x86_64 com o primeiro jogador funcional: andar, olhar com o mouse,
gravidade e colisão em uma sala 3D de teste.

## O que há de novo

- **TESTAR MOVIMENTAÇÃO** na tela inicial abre uma sala 3D de laboratório com
  piso, paredes, pilares e caixas — tudo com colisão real.
- **Controlador FPS** (`CharacterBody3D`): WASD relativo à direção da câmera,
  diagonal normalizada, gravidade, detecção de chão e câmera na altura dos olhos.
- **Mouse olha** livremente na horizontal e até **±89°** na vertical.
- **Sensibilidade horizontal/vertical e inverter eixo vertical** vêm das
  configurações da Etapa 3 (`%APPDATA%\BlackSight\settings.cfg`) e valem na hora.
- **ESC** libera o cursor e abre a pausa com **CONTINUAR** e **VOLTAR AO MENU** —
  ninguém fica preso na cena.
- F11 continua alternando janela/tela cheia; SAIR DO JOGO continua funcionando.
- Tela inicial, animações, partículas, vinheta e tela de configurações
  preservadas.

## Pacote

| Item | Valor |
| --- | --- |
| Arquivo | `BlackSight-Etapa4-Windows-x86_64.zip` |
| Tamanho | 40.624.846 bytes (≈ 38,7 MiB) |
| SHA-256 | `da042476c11bffe8563cd3c73c883add77bbf3f53281b3f4ac900b0e134e0a66` |
| Conteúdo | `BlackSight.exe`, `BlackSight.pck`, `LEIA-ME.txt`, `SHA256SUMS.txt` |

## Como testar

1. Extraia o ZIP mantendo `BlackSight.exe` e `BlackSight.pck` na mesma pasta.
2. Duplo clique em **BlackSight.exe**.
3. Clique em **TESTAR MOVIMENTAÇÃO**.
4. Ande com **W A S D**, olhe com o **mouse**.
5. **ESC** libera o mouse; **CONTINUAR** volta a jogar; **VOLTAR AO MENU** volta
   à tela inicial.
6. Em **CONFIGURAÇÕES → CONTROLES**, ajuste a sensibilidade e a inversão
   vertical e sinta a diferença no teste.

## Testes

O pacote publicado é exatamente o gerado pelo workflow
[`build.yml`](https://github.com/EtecStudy/BLACKSITE/blob/main/.github/workflows/build.yml).
Antes de publicar, a execução
[39344854993](https://github.com/EtecStudy/BLACKSITE/actions/runs/39344854993)
rodou no Linux e no Windows real:

- 175 verificações de configuração/cenas (`SMOKE TEST OK`);
- 33 verificações de navegação da interface (`UI FLOW OK`);
- 63 verificações do controlador FPS (`MOVEMENT TEST OK`), incluindo WASD,
  diagonais, câmera, limites verticais, sensibilidade, pausa, gravidade e
  colisões.

Evidências, detalhes e limitações:
[`docs/ETAPA-4.md`](https://github.com/EtecStudy/BLACKSITE/blob/main/docs/ETAPA-4.md).

## Limitações desta etapa

- Ainda **não** há corrida, agachamento, stamina, pulo, inventário, interação,
  criaturas, multiplayer ou voz.
- A sala é uma área de teste com primitivas, não o laboratório definitivo.
- Não há som de passos nem animação de corpo.
