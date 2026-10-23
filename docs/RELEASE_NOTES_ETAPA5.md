# Black Sight — Etapa 5: Estados de movimento

Build Windows x86_64 com corrida, agachamento e configurações acessíveis pelo
menu de pausa, sem sair da partida.

## O que há de novo

- **Estados de movimento**: PARADO, ANDANDO, CORRENDO e AGACHADO, com
  transições automáticas.
- **SHIFT corre** (5,6 m/s) e **CTRL agacha** (1,6 m/s). Agachar tem prioridade:
  CTRL + SHIFT continua agachado, nunca correndo.
- **Câmera acompanha o agachamento**: desce suavemente de 1,62 m para 1,02 m e
  volta ao levantar. Yaw, pitch, limites, sensibilidade e inversão não mudaram.
- **Cápsula segura**: agachar encolhe a cápsula a partir do topo; levantar só
  acontece se houver espaço (consulta de forma) — nada de atravessar teto.
- **Menu de pausa** agora tem **CONTINUAR**, **CONFIGURAÇÕES** e **VOLTAR AO
  MENU**. CONFIGURAÇÕES abre a mesma tela da Etapa 3 por cima da partida
  pausada; VOLTAR/Esc retornam à pausa, e só CONTINUAR volta ao jogo.
- Posição, orientação e estado do jogador são preservados ao abrir/fechar as
  configurações. Nenhuma segunda tela, nenhum segundo `GameSettings`.
- Ainda **sem pulo** — o jogador não possui nenhum mecanismo de salto.

## Pacote

| Item | Valor |
| --- | --- |
| Arquivo | `BlackSight-Etapa5-Windows-x86_64.zip` |
| Tamanho | 40.630.076 bytes (≈ 38,7 MiB) |
| SHA-256 | `4ebc60d966a14edee54036f3f2c24dfb845a6224d1b381c191b8b6c68228308e` |
| Conteúdo | `BlackSight.exe`, `BlackSight.pck`, `LEIA-ME.txt`, `SHA256SUMS.txt` |

## Como testar

1. Extraia o ZIP mantendo `BlackSight.exe` e `BlackSight.pck` na mesma pasta.
2. Duplo clique em **BlackSight.exe**.
3. Clique em **TESTAR MOVIMENTAÇÃO**.
4. Ande com **W A S D**; **SHIFT** corre; **CTRL** agacha (ande agachado e teste
   CTRL + SHIFT).
5. **ESC** → **CONFIGURAÇÕES** → mude a sensibilidade → **APLICAR** →
   **VOLTAR** (volta à pausa) → **CONTINUAR** (mesmo lugar).
6. **ESC** → **VOLTAR AO MENU**; **F11** alterna janela/tela cheia.

## Testes

A release é gerada pelo workflow
[`build.yml`](https://github.com/EtecStudy/BLACKSITE/blob/arena/aa5e0e47-blacksite/.github/workflows/build.yml),
que rodou, na execução
[39349449302](https://github.com/EtecStudy/BLACKSITE/actions/runs/39349449302),
195 verificações de fumaça, 40 de fluxo da interface e **122 do controlador**
(estados, velocidades, câmera do agachamento, obstáculo acima e pausa com
configurações) — no Linux e no Windows real — antes de publicar.
Resultados, evidências e limitações:
[`docs/ETAPA-5.md`](https://github.com/EtecStudy/BLACKSITE/blob/arena/aa5e0e47-blacksite/docs/ETAPA-5.md).

## Limitações desta etapa

- Sem stamina (Etapa 6), pulo, interação, inventário, criaturas, multiplayer ou
  voz.
- O agachamento não tem animação de corpo nem som de passos.
- A sala de teste continua sendo uma área de primitivas, não o laboratório
  definitivo.
