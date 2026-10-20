# Black Sight — Etapa 6: Stamina e agachamento configurável

Build Windows x86_64 com stamina na corrida, dois modos de agachamento e a lista
real de controles na tela de configurações.

## O que há de novo

- **Stamina na corrida**: 100 pontos, consumo de 20/s apenas enquanto o estado
  efetivo é CORRENDO, recuperação de 15/s parado, andando ou agachado. A corrida
  para sozinha ao esgotar (mesmo com SHIFT pressionado) e volta a partir de 20
  pontos.
- **Agachado nunca corre** e não consome stamina; levantar com SHIFT ainda
  pressionado volta a correr se a stamina permitir.
- **Modo de agachamento** em CONTROLES: **ALTERNAR** (padrão — um toque agacha,
  outro levanta) ou **SEGURAR** (mantenha CTRL). A escolha fica em
  `user://settings.cfg` e vale na hora, inclusive durante a partida.
- **Lista real de controles**: WASD, SHIFT, CTRL (texto conforme o modo), mouse,
  ESC e F11. Nada de E—Interagir, F—Lanterna, pulo, inventário ou ataque.
- **Pausa preserva tudo**: ESC → PAUSA → CONFIGURAÇÕES → CONTROLES → MODO DE
  AGACHAMENTO → APLICAR → VOLTAR → PAUSA → CONTINUAR mantém posição,
  orientação, estado, stamina e câmera.
- Continua **sem pulo** e sem HUD de stamina (a estrutura `stamina_changed` e
  `get_stamina_ratio()` já está pronta para uma barra futura).

## Pacote

| Item | Valor |
| --- | --- |
| Arquivo | `BlackSight-Etapa6-Windows-x86_64.zip` |
| Conteúdo | `BlackSight.exe`, `BlackSight.pck`, `LEIA-ME.txt`, `SHA256SUMS.txt` |

<!-- NUMEROS_DO_PACOTE -->

## Como testar

1. Extraia o ZIP mantendo `BlackSight.exe` e `BlackSight.pck` na mesma pasta.
2. Duplo clique em **BlackSight.exe**.
3. Clique em **TESTAR MOVIMENTAÇÃO**.
4. Ande com **W A S D**; segure **SHIFT** até a corrida parar; continue segurando
   e veja a corrida voltar depois da recuperação.
5. Toque em **CTRL** para agachar (modo ALTERNAR) e de novo para levantar.
6. **ESC** → **CONFIGURAÇÕES** → **CONTROLES** → **Agachar com Ctrl →
   SEGURAR** → **APLICAR** → **VOLTAR** → **CONTINUAR** (mesmo lugar, mesma
   stamina) e confirme que agora é preciso segurar Ctrl.
7. Confira a lista de controles e teste **F11**, **VOLTAR AO MENU** e
   **SAIR DO JOGO**.

## Testes

A release é gerada pelo workflow
[`build.yml`](https://github.com/EtecStudy/BLACKSITE/blob/arena/aa5e0e47-blocksite/.github/workflows/build.yml),
no Linux e no Windows real, antes de publicar.

<!-- RESULTADOS_DOS_TESTES -->

## Limitações desta etapa

- Sem pulo, interação, inventário, criaturas, combate ou multiplayer.
- Sem HUD, som ou animação de stamina: o valor é interno e a corrida apenas passa a
  andar quando esgota.
- O agachamento continua sem animação de corpo.
- A sala de teste continua sendo uma área de primitivas, não o laboratório
  definitivo.
