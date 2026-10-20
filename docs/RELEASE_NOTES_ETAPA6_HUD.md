# Black Sight — Etapa 6.1: HUD de stamina

Build Windows x86_64 da **correção da Etapa 6**: a stamina que já existia no
controlador agora aparece na partida em uma HUD discreta, com a mesma linguagem
visual do menu e das configurações.

## O que há de novo

- **Barra de stamina na partida**, no canto inferior esquerdo: rótulo `STAMINA`,
  valor em porcentagem (0–100%) e trilho desenhado nativamente, sem imagens.
- **Valor real, sem cópia**: a HUD escuta o sinal `stamina_changed` e lê
  `get_stamina()`/`get_max_stamina()` do próprio controlador. Não existe segunda
  variável de stamina nem valor simulado.
- **Acompanha o jogo**: cai ao correr (20/s), sobe ao parar, andar ou agachar
  (15/s), mostra 0% no esgotamento e acompanha a retomada a partir de 20 pontos.
- **Estável na pausa e nas configurações**: o valor exibido não muda enquanto o
  menu de pausa ou a tela de configurações estão abertos.
- **Discreta**: painel de baixa opacidade, borda de 1 px, Cinzel e paleta
  pergaminho/escuro do projeto. Alerta em vermelho discreto somente abaixo de
  20%; nada de verde/azul, neon, gradientes ou ícones.
- **Não interfere nos controles**: toda a HUD ignora o mouse e o foco; WASD,
  mouse, ESC, F11, pausa e configurações continuam iguais.
- **Preparada para crescer**: a pilha vertical no canto inferior esquerdo aceita
  novos componentes acima da barra sem refazer a HUD.

Nada de física, velocidades, balanceamento, controles ou arquivos de
configuração foi alterado nesta correção.

## Pacote

| Item | Valor |
| --- | --- |
| Arquivo | `BlackSight-Etapa6-HUD-Windows-x86_64.zip` |
| Conteúdo | `BlackSight.exe`, `BlackSight.pck`, `LEIA-ME.txt`, `SHA256SUMS.txt` |
| Tamanho | *(preenchido após o build)* |
| SHA-256 | *(preenchido após o build)* |

Este ZIP **substitui** o da v0.6.0 (`BlackSight-Etapa6-Windows-x86_64.zip`): é
uma compilação nova, com a HUD integrada.

## Como testar

1. Extraia o ZIP mantendo `BlackSight.exe` e `BlackSight.pck` na mesma pasta.
2. Duplo clique em **BlackSight.exe**.
3. Clique em **TESTAR MOVIMENTAÇÃO**.
4. Confira a HUD no canto inferior esquerdo: `STAMINA 100%` e a barra cheia.
5. Ande com **W A S D** e segure **SHIFT**: a barra cai de forma contínua até o
   esgotamento; ao soltar, ela sobe enquanto a stamina se recupera.
6. Espere a barra passar de 20% e segure **SHIFT** de novo: a corrida volta e a
   barra volta a cair.
7. **ESC** → a pausa cobre a tela; a barra não muda. **CONFIGURAÇÕES** → altere
   sensibilidade, inversão ou modo de agachamento → **APLICAR** → **VOLTAR** →
   **CONTINUAR**: a barra continua no mesmo valor.
8. Teste **CTRL** (ALTERNAR por padrão), **F11** (a HUD continua no canto, sem
   cortes), **VOLTAR AO MENU** e **SAIR DO JOGO**.

## Testes

A release é gerada pelo workflow
[`build.yml`](https://github.com/EtecStudy/BLACKSITE/blob/arena/aa5e0e47-blocksite/.github/workflows/build.yml),
no Linux e no Windows real, antes de publicar.

| Suíte | O que cobre |
| --- | --- |
| Fumaça | configuração, cenas, stamina, persistência, lista real de controles |
| Fluxo de interface | menu → configurações → F11 → partida → pausa → configurações → menu |
| Controlador | Etapas 4–6 + grupo novo **[20] HUD** (42 verificações) |

Resultados, evidências e limitações:
[`docs/ETAPA-6.md`](https://github.com/EtecStudy/BLACKSITE/blob/arena/aa5e0e47-blocksite/docs/ETAPA-6.md)
(seção 10).

## Limitações desta correção

- A HUD mostra somente a stamina; vida, criatura, objetivos e inventário
  continuam para as próximas etapas.
- Não há som ou animação de cansaço.
- O agachamento continua sem animação de corpo e a sala de teste segue sendo uma
  área de primitivas.
- Sem pulo, interação, inventário, criaturas, combate ou multiplayer.
- A conferência visual automatizada usa os frames renderizados no CI
  (Xvfb/OpenGL); o teste em Windows real com uma pessoa é o próximo passo.
