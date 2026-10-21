# Black Sight — Etapa 12A · Primeiro andar do laboratório (v0.12.0)

**Tag:** `v0.12.0-etapa12a-primeiro-andar`
**Arquivo:** `BlackSight-Etapa12A-Primeiro-Andar-Windows-x86_64.zip` (Windows x86_64)
**Base:** `v0.11.2-etapa11-rodape` (preservada)

Planta estrutural completa do **primeiro andar** do laboratório Black Sight,
montada somente com os módulos aprovados na Etapa 11. Sem móveis,
equipamentos, objetos interativos, objetivos, criaturas, IA, portas
funcionais, energia, eventos de terror ou multiplayer.

## O que há de novo

- Botão **PRIMEIRO ANDAR** na tela inicial abre a nova cena jogável
  (`match/scenes/laboratory.tscn`), com o mesmo controlador, HUD, pausa (ESC),
  corrida (SHIFT), agachamento (CTRL), coleta e descarte das etapas anteriores.
- **23 ambientes** em seis setores: entrada, recepção, segurança, posto de
  controle, corredor principal (5,6 m livres), grande cruzamento central
  (21,6 × 21,6 m, teto de 12 m), pesquisa A, análises (com divisórias),
  observação (pé-direito duplo, dois vãos para análises), armazenamento,
  escritórios (subdivididos), arquivo (subdividido), área de funcionários,
  apoio logístico, elétrica, acesso à manutenção e as duas casas de escada.
- **Área construída de 7.248 m²**, extensão de 127,6 × 93,6 m, pé-direito de
  6 m (12 m nos grandes volumes).
- **Duas escadas funcionais** para o subsolo, em regiões opostas do mapa
  (norte, x 23–25; sul, x 67–69), com poço, hall inferior em −3,2 m, paredes
  e guarda-corpos.
- 40 vãos (30 portas de 2,4 × 3,0 m, 6 aberturas de 3,6 × 4,2 m e 4 bocas de
  corredor de 6 m), 23 pilares, 5 vigas e teto real em toda a planta.

## O que **não** mudou

- Biblioteca modular (`maps/modular/`): **nenhum módulo foi criado ou editado**.
- Escala e planta da Etapa 11 (demo `modular_demo_room.tscn` intacta).
- Movimentação, corrida, agachamento, inventário de três slots, coleta com E,
  drop com G, tela de configurações, ESC e SHIFT.
- Processo de exportação Windows e formato do ZIP.

## Escadas (decisão)

O módulo `stairs_straight` sobe 3,2 m. Para descer ao subsolo **sem alterar a
biblioteca**, o módulo foi instalado com o topo no piso do andar e o pé no hall
inferior (−3,2 m), dentro de um poço de 2 × 10 m. O hall tem piso contínuo,
paredes do fundo até a laje e guarda-corpos nas três bordas abertas.

## Testes

- **Novo** `tools/ci/first_floor_test.tscn`: hierarquia, dimensões, piso e teto
  (mais de 500 amostras com raio), vedação de todos os lados de todos os
  ambientes, geometria dos vãos, ausência de peças duplicadas/sobrepostas,
  travessia real dos 40 vãos com o controlador, descida e subida das duas
  escadas, rota completa de 40 pontos e pausa/retomada.
- `smoke_test.gd` ganhou o grupo `[26] Primeiro andar (Etapa 12A)`.
- `ui_flow_test.gd` passou a abrir o primeiro andar pela tela inicial, pausar,
  retomar e voltar ao menu.
- Validação da planta em Python antes de gerar a cena
  (`tools/arch/build_first_floor.py --check`).
- CI Linux e Windows executam o teste headless e o job Windows gera **14
  capturas** do andar para revisão.

## Publicação

| Item | Valor |
| --- | --- |
| Tag | `v0.12.0-etapa12a-primeiro-andar` |
| Commit | `9d508281294199332dc6f9c93ce917be5a168027` |
| ZIP | 40.802.508 bytes |
| SHA-256 | `4234515572ce9a646a45a6b5422476ea39f1f938eb8881371e4efe58d59e8d52` |
| CI | run `39685967579` — Linux e Windows verdes |
| Testes | planta 347 (duas plataformas), fumaça 381, interface 85, controlador 598, modular 364 |
| Capturas | 14/14 |

O **percurso manual** descrito em `docs/ETAPA-12A.md` §6.2 ainda precisa ser
feito por uma pessoa; os testes automatizados não substituem essa revisão.

## Limitações desta etapa

- Iluminação **provisória** (33 luzes + ambiente leve); a iluminação final é de
  uma etapa futura.
- Sem móveis, equipamentos, objetos, objetivos, criaturas, portas funcionais,
  energia ou eventos.
- Sem subsolo construído: as escadas terminam no hall inferior.
- Cena pesada (4.749 nós); desempenho precisa ser medido na máquina alvo.
- As capturas e os testes de renderização só rodam onde há GPU (CI Windows e
  Xvfb no Linux); a validação visual final é manual.
