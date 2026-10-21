# Black Sight — Etapa 11 · Correção da biblioteca modular (v0.11.1)

**Tag:** `v0.11.1-etapa11-correcao`
**Arquivo:** `BlackSight-Etapa11-Correcao-Windows-x86_64.zip` (Windows x86_64)
**Base:** `v0.11.0-etapa11-modular-rooms` (preservada, não é sobrescrita)

Correção da Etapa 11: a biblioteca modular foi revisada para uma instalação
industrial de grande escala, a cena de demonstração foi reconstruída sobre ela
e dois bugs relatados no teste manual foram corrigidos: **ESC travava/voltava
ao menu sem controle** e **a corrida ficava presa depois de soltar SHIFT**.

Nenhum sistema das etapas anteriores foi removido. Movimentação, stamina,
interação, inventário e descarte continuam iguais (Etapas 5–9), assim como a
sala de teste e a HUD aprovada.

## O que mudou na biblioteca

- **Escala industrial:** pé-direito de **6 m**, paredes de **0,40 m** de
  espessura, corredor principal de **6 m** e secundário de **4 m**, salas de
  pesquisa de **10 × 10 m** e **12 × 16 m**, sala técnica de **14 × 20 m**.
- **25 peças**: pisos e tetos de 2 × 2 m, painéis de parede de 2 m, módulos de
  **porta (4 m, vão 2,4 × 3,0 m)** e **abertura (4 m, vão 3,6 × 4,2 m)**,
  cantos internos/externos, pilastra de encontro, pilar I, viga de 6 m, coluna
  de apoio, guarda-corpo, escada e seis peças de corredor (reto principal,
  reto secundário, canto em L, T, cruzamento em X e terminação com comporta).
- **Salas prontas**: pesquisa 10 × 10, pesquisa 12 × 16, técnica 14 × 20 e
  equipamentos 8 × 8, todas com piso, teto e pilares.
- **Encaixe documentado** (grade de 2 m, pivôs, eixos, alturas) e verificado:
  paredes compartilhadas entre ambientes (sem duplicação), pisos que terminam
  na face da parede e soleiras que emendam os pisos.

## O que mudou na demonstração

- Corredor principal de **40 m** com vigas e luminárias industriais.
- Sala de pesquisa A (10 × 10) com **dois acessos**: porta de 2,4 m e abertura
  de 3,6 m.
- Sala de pesquisa B (12 × 16) com porta de 2,4 m.
- Ramal secundário de 4 m ligando o corredor à sala técnica, com **junção
  modular** (`wall_opening_4m`, com pilares de 0,20 m) dos dois lados.
- Sala técnica de 14 × 20 com **pórtico de 4 pilares e 6 vigas**, mezanino em
  `y = 3,2`, **8 guarda-corpos** e **escada de 16 degraus** com guardas.
- Sala de equipamentos 8 × 8 ligada à sala técnica.
- 12 luzes pontuais, ambiente com névoa e tonemap, materiais industriais.
- **706 nós** de geometria: 257 placas de piso, 239 lajes de teto (227 cegas
  + 12 luminárias), 137 painéis de parede, 3 portas, 3 aberturas, 14 blocos de
  canto, 12 pilares, 10 vigas, 8 guarda-corpos, 3 colunas de apoio e 1 escada.

## Correções

- **ESC:** o menu de pausa agora é real (CONTINUAR / CONFIGURAÇÕES / VOLTAR AO
  MENU). O ESC abre e fecha a pausa; a troca de cena no botão de menu é
  agendada com `call_deferred`, fora do evento de teclado. Abrir e fechar
  repetidamente não corrompe estado e não trava.
- **SHIFT:** o pressionamento/soltura passa a ser registrado por evento
  (`_input`), e não só pelo estado da ação a cada frame — o estado da ação pode
  ficar preso no Godot 4.7.2. Soltar Shift desliga a corrida imediatamente;
  retomar depois da pausa não herda corrida.
- **Peças atravessadas:** painéis duplicados no mesmo plano e cantos com braços
  invadindo a parede foram eliminados na geração; a demonstração é validada
  sem sobreposições nem frestas.

## Testes deste build (Windows e Linux, código de saída 0)

| Suíte | Verificações |
| --- | --- |
| Fumaça (`smoke_test`) | 359 |
| Fluxo de interface (`ui_flow_test`) | 76 |
| Controlador FPS + inventário + drop (`movement_test`) | 598 |
| Drop junto a obstáculos (`drop_obstacle_test`) | 156 |
| Sistema modular de salas (`modular_test`) | 327 |

O build também importa o projeto, executa as cenas headless, renderiza as
cenas com Xvfb/OpenGL, exporta o `.exe` e executa o pacote exportado. **Nada
disso substitui o teste manual abaixo** — a aprovação depende dele.

## Como testar manualmente

1. Extraia o ZIP e mantenha `BlackSight.exe` e `BlackSight.pck` na mesma pasta.
2. Execute `BlackSight.exe` → **DEMONSTRAR MÓDULOS**.
3. Ande e corra pelo corredor; solte SHIFT e confirme que a corrida para na
   hora.
4. Entre na sala de pesquisa pelos dois acessos (porta e abertura).
5. Siga pelo ramal até a sala técnica e entre na sala de equipamentos.
6. Suba a escada, ande pelo mezanino e encoste no guarda-corpo.
7. Pressione **ESC** 5 vezes (abrir/fechar) e confirme que o jogador volta a
   andar ao retomar.
8. Abra **CONFIGURAÇÕES** pelo menu e volte; use **VOLTAR AO MENU** e entre na
   demonstração outra vez.
9. Confira que não há parede piscando nem fresta no piso dos corredores.

## Controles (inalterados)

`W A S D` andar · `Shift` correr · `Ctrl` agachar · `E` interagir/pegar ·
`1 2 3` selecionar · `G` soltar item · `R` remover · `Esc` pausa ·
`F11` tela cheia

## Pacote publicado

| Item | Valor |
| --- | --- |
| Release | <https://github.com/EtecStudy/BLACKSITE/releases/tag/v0.11.1-etapa11-correcao> |
| Arquivo | `BlackSight-Etapa11-Correcao-Windows-x86_64.zip` |
| Tamanho | 40.728.124 bytes |
| SHA-256 | `876a5c5bde28a9a3232b5beda48323b4769713bc17e3635d0c9bc7f3df49094f` |
| Commit | `53851dc` |

## Ainda fora do escopo

Laboratório definitivo, portas funcionais, geração procedural, criaturas,
objetivos de partida e multiplayer.
