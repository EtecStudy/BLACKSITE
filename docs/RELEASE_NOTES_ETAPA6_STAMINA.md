# Black Sight — Etapa 6.2: recuperação de stamina com atraso

Build Windows x86_64 da **correção da Etapa 6.1**. A HUD e tudo o que já estava
aprovado continuam iguais; mudou apenas **quando** a stamina começa a recuperar.

## O que há de novo

- **Atraso de 1 segundo**: ao soltar SHIFT, a stamina fica parada por 1 s antes
  de começar a recuperar (15/s). Vale também para corridas interrompidas antes
  de esgotar.
- **SHIFT pressionado bloqueia a recuperação**: exausto, o jogador fica em 0%
  enquanto continuar segurando SHIFT — não existe mais o ciclo automático
  `0% → recupera → 20% → volta a correr`.
- **SHIFT durante o atraso**: o atraso reinicia e nada recupera escondido; se
  houver stamina, a corrida volta normalmente.
- **Pausa e configurações** congelam a stamina **e** o atraso; ao continuar, tudo
  segue de onde estava, sem reiniciar o segundo.
- **Agachado** continua sem consumir e só recupera com o atraso concluído e
  SHIFT solto. ALTERNAR e SEGURAR não mudaram.
- **HUD intacta**: mesma posição, estilo, tipografia, painel, barra e marcador de
  limiar. Ela apenas continua exibindo `get_stamina() / get_max_stamina()`.

Nada de física, velocidades, consumo (20/s), recuperação (15/s), limiar (20) ou
arquivos de configuração foi alterado. O atraso não é uma opção em
CONFIGURAÇÕES.

## Pacote

| Item | Valor |
| --- | --- |
| Arquivo | `BlackSight-Etapa6-Stamina-Windows-x86_64.zip` |
| Conteúdo | `BlackSight.exe`, `BlackSight.pck`, `LEIA-ME.txt`, `SHA256SUMS.txt` |
| Tamanho | *(preenchido após o build)* |
| SHA-256 | *(preenchido após o build)* |

Este ZIP **substitui** o da v0.6.1 (HUD) e o da v0.6.0: é uma compilação nova.

## Como testar

1. Extraia o ZIP mantendo `BlackSight.exe` e `BlackSight.pck` na mesma pasta.
2. Duplo clique em **BlackSight.exe** → **TESTAR MOVIMENTAÇÃO**.
3. Corra com **SHIFT** até zerar e **continue segurando SHIFT**: a barra deve
   permanecer em **0%** e a corrida deve ficar interrompida.
4. Solte **SHIFT**: a barra fica parada por **1 segundo** e só então sobe. Ao
   passar de 20%, pressione **SHIFT** para correr de novo.
5. Corra, solte **SHIFT** e pressione de novo **antes de 1 segundo**: a corrida
   volta e a stamina não pode ter recuperado nesse intervalo.
6. **ESC** durante a recuperação, espere e **CONTINUAR**: stamina e atraso
   continuam de onde pararam.
7. Confira **CTRL** (ALTERNAR), **F11**, **VOLTAR AO MENU** e **SAIR DO JOGO**.

## Testes

A release é gerada pelo workflow
[`build.yml`](https://github.com/EtecStudy/BLACKSITE/blob/arena/aa5e0e47-blocksite/.github/workflows/build.yml),
no Linux e no Windows real, antes de publicar.

| Suíte | O que cobre |
| --- | --- |
| Fumaça | configuração, cenas, stamina (incl. atraso), persistência, controles |
| Fluxo de interface | menu → configurações → F11 → partida → pausa → configurações → menu |
| Controlador | Etapas 4–6.2: movimento, câmera, colisões, agachamento, stamina, HUD, atraso de recuperação e pausa |

Resultados, evidências e limitações:
[`docs/ETAPA-6.md`](https://github.com/EtecStudy/BLACKSITE/blob/arena/aa5e0e47-blocksite/docs/ETAPA-6.md)
(seção 11).

## Limitações desta correção

- O atraso não é exibido numericamente na HUD: a barra simplesmente fica parada
  durante o segundo de espera.
- Sem som ou animação de cansaço.
- A conferência visual automatizada usa os frames do CI (Xvfb/OpenGL); o teste
  manual no Windows com uma pessoa é o próximo passo e ainda não foi feito.
- Sem pulo, interação, inventário, criaturas, combate ou multiplayer.
