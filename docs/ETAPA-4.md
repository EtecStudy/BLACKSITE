# Black Sight — Etapa 4: Controlador em primeira pessoa (FPS)

Relatório da Etapa 4. As Etapas 1, 2 e 3 foram concluídas e validadas
anteriormente (tela inicial, arquitetura em módulos e configurações).

## 1. Objetivo

Implementar o **controlador do jogador em primeira pessoa**: andar com WASD,
olhar com o mouse, colidir com o cenário e ser afetado pela gravidade — com uma
cena 3D de teste acessível pela tela inicial e retorno garantido ao menu.

Fora do escopo desta etapa: corrida, agachamento, stamina, pulo, inventário,
interação, criaturas, multiplayer e voz.

## 2. O que foi entregue

### 2.1 Controlador

- `CharacterBody3D` com cápsula de colisão (raio `0.35 m`, altura `1.8 m`),
  origem nos pés.
- Câmera em primeira pessoa a **1,62 m** (altura dos olhos), filha de um nó
  `Head` que recebe apenas a inclinação vertical.
- Movimento **relativo à orientação horizontal** do corpo: WASD anda para onde
  a câmera aponta.
- Diagonal normalizada: andar em diagonal tem a mesma velocidade que andar reto.
- Aceleração e desaceleração independentes da taxa de quadros
  (`1 - exp(-a·Δt)`), sem `delta` aplicado duas vezes.
- Gravidade vinda de `ProjectSettings` (`physics/3d/default_gravity`).
- Detecção de chão (`is_on_floor()`), `floor_snap_length = 0.35` e
  `floor_stop_on_slope` para não tremer nem quicar em superfícies planas.
- **Sem pulo**, conforme o projeto.

### 2.2 Câmera e configurações (integração com a Etapa 3)

- Mouse horizontal gira o corpo (yaw); mouse vertical inclina a cabeça (pitch).
- Pitch limitado a **±89°** — a câmera nunca dá uma volta completa.
- Sensibilidade horizontal e vertical lidas de `GameSettings`
  (`shared/settings/`), com os limites do `SettingsSchema` (0,1 a 5,0).
- Inversão do eixo vertical respeitada.
- Os valores são reaplicados quando o gerenciador emite `applied` — não é
  preciso reiniciar o jogo.
- Sem `GameSettings` (teste isolado), o controlador usa os padrões do esquema.
- Nenhum arquivo de configuração novo: continua sendo `user://settings.cfg`.

### 2.3 Cena de teste 3D

- `maps/scenes/test_room.tscn`: sala de **24 × 24 m**, piso com colisão, quatro
  paredes, teto com colisão, quatro pilares, caixas empilhadas, painéis de
  sinalização, duas luminárias de teto e iluminação por `OmniLight3D` +
  ambiente.
- Ponto de nascimento (`Marker3D`, `Spawn`) no centro-sul da sala, voltado para
  o interior.
- Visual de laboratório simples, com primitivas e materiais lisos — sem arte
  final, como pedido.

### 2.4 Acesso e saída

- Novo botão **TESTAR MOVIMENTAÇÃO** na tela inicial (o botão JOGAR continua
  desabilitado e o SAIR DO JOGO continua funcionando).
- Ao entrar na cena, o mouse é capturado.
- **ESC** libera o cursor e abre a pausa com **CONTINUAR** e **VOLTAR AO MENU**;
  ESC novamente (ou CONTINUAR) captura o mouse de volta.
- **VOLTAR AO MENU** retorna à tela inicial — o jogador nunca fica preso.
- **F11** continua alternando janela/tela cheia dentro da cena de teste.
- O cursor volta a ficar visível ao sair da cena por qualquer caminho.

### 2.5 O que não entrou (de propósito)

Corrida, agachamento, stamina, pulo, inventário, interação, HUD de jogo,
criaturas, multiplayer, voz e mapa definitivo.

## 3. Arquivos criados e modificados

| Arquivo | O que é |
| --- | --- |
| `players/scripts/player_controller.gd` | **Novo** — controlador FPS (movimento, câmera, gravidade, configurações) |
| `players/scenes/player.tscn` | **Novo** — corpo, cápsula, cabeça e câmera |
| `maps/scenes/test_room.tscn` | **Novo** — sala de teste com colisão e iluminação |
| `match/scripts/movement_test.gd` | **Novo** — orquestração da sessão, pausa e retorno ao menu |
| `match/scenes/movement_test.tscn` | **Novo** — cena de teste (sala + jogador + interface de pausa) |
| `tools/ci/movement_test.gd` / `.tscn` | **Novos** — testes automatizados do controlador |
| `tools/ci/smoke_test.gd` | Verificações do jogador, da sala, do Input Map e do botão |
| `tools/ci/ui_flow_test.gd` | Fluxo menu → cena de teste → menu |
| `ui/scenes/title_screen.tscn` | Botão **TESTAR MOVIMENTAÇÃO** e texto de apoio |
| `ui/scripts/title_screen.gd` | Navegação para a cena de teste |
| `project.godot` | Input Map (WASD + Escape) e versão 0.4.0 |
| `shared/autoload/app_info.gd` | Versão 0.4.0 / Etapa 4 |
| `export_presets.cfg` | Metadados 0.4.0.0 |
| `.github/workflows/build.yml` | Testes da Etapa 4, screenshots e release `v0.4.0-etapa4` |
| `README.md`, `docs/ARQUITETURA.md`, `docs/CONFIGURACOES.md`, READMEs dos módulos | Documentação |

## 4. Integração com as configurações

```
SettingsSchema.defaults()/sanitize()        (fonte única dos limites)
        ▲
        │ current()
GameSettings (autoload) ── sinal applied ──► PlayerController.reload_settings()
        ▲                                          │
        │ user://settings.cfg                      ▼
   tela de configurações                   sensibilidade X/Y, inverter Y
```

O controlador **não** lê `ConfigFile` e **não** guarda cópia própria dos valores:
ele consulta o autoload e reage ao sinal. Os valores padrão continuam valendo
quando o arquivo não existe, está inválido ou o jogo roda sem configurações.

## 5. Testes executados

Workflow [`build.yml`](https://github.com/EtecStudy/BLACKSITE/blob/main/.github/workflows/build.yml),
execução **[39344854993](https://github.com/EtecStudy/BLACKSITE/actions/runs/39344854993)**
(commit `ead68d7`), jobs Linux `118374897869` e Windows `118374898045` — ambos
**verdes**.

### 5.1 Automatizados (executados de verdade)

| Teste | O que cobre | Linux | Windows |
| --- | --- | --- | --- |
| `tools/ci/smoke_test.tscn` | Configuração, tela inicial, tema, fontes, sons, módulos, Input Map, jogador, sala e cena de teste | **175/175** | **175/175** |
| `tools/ci/ui_flow_test.tscn` | Navegação real: menu → CONFIGURAÇÕES → abas → aplicar/restaurar → F11 → **TESTAR MOVIMENTAÇÃO** → câmera ativa → **VOLTAR AO MENU** | **33/33** | **33/33** |
| `tools/ci/movement_test.tscn` | Controlador FPS — 11 grupos (abaixo) | **63/63** | **63/63** |

Grupos do teste do controlador (`movement_test.gd`):

1. **Input Map** — as 4 ações de movimento existem e apontam para W/S/A/D
   (físicas) + `release_mouse`.
2. **Cena de teste** — cena carrega, jogador é `CharacterBody3D`, sala e camada
   de pausa existem, botão VOLTAR AO MENU está conectado.
3. **Nascimento e piso** — nasce sobre o `Spawn`, assenta no chão, cabeça a
   1,62 m, câmera ativa, 90 frames com variação vertical < 0,02 m (sem tremor).
4. **Direções** — W → −Z, S → +Z, A → −X, D → +X, sem desvio lateral.
5. **Diagonal** — deslocamento diagonal igual ao reto (tolerância 6 %).
6. **Movimento relativo** — com a visão girada 90°, W anda em −X.
7. **Parado** — nenhum deslocamento espontâneo em 60 frames (< 0,01 m).
8. **Câmera e configurações** — sentido do yaw/pitch, sensibilidade 1× e 2×,
   limite de ±89°, inversão vertical, leitura via `GameSettings` e restauração
   dos padrões.
9. **Pausa** — `pause_session` mostra a camada, bloqueia WASD (< 0,05 m) e
   `resume_session` devolve o controle.
10. **Gravidade** — queda de 2 m até o piso, sem atravessar.
11. **Colisões** — parede norte (z ≈ −11,39), caixa (z ≈ 2,85), canto sudeste
    (11,40; 11,40) e estabilidade encostado (variação 0,001 m).

### 5.2 Verificações estáticas e de empacotamento

| Verificação | Resultado |
| --- | --- |
| Sintaxe de todos os `.gd` (`gdparse`) | OK |
| Estrutura das cenas `.tscn` (referências, sub-recursos, pais) | OK |
| Execução *headless* da cena inicial (editor e build exportado Linux) | tela inicial e configurações carregadas, sem `SCRIPT ERROR` |
| Render sob Xvfb/OpenGL (título, configurações, cena de teste) | 3 frames válidos — `docs/screenshots/movement_test.png` |
| Inspeção do `.pck` | formato 4, **68 recursos**; `player.scn`, `test_room.scn`, `movement_test.scn` e `player_controller.gdc` presentes; `tools/` e `docs/` fora do pacote |
| Binário Windows | PE32+ x86-64, metadados `0.4.0.0` / “Black Sight” / “EtecStudy” |

### 5.3 Manuais

Não foram executados por uma pessoa nesta etapa. O teste humano (mouse real,
sensação de sensibilidade, ESC/recaptura e retorno ao menu) depende de o usuário
baixar o ZIP e rodar o `.exe` — é o próximo passo desta entrega.

## 6. Teste no Windows real

Job **windows-latest** `118374898045`, tudo verde:

| Verificação | Resultado |
| --- | --- |
| Importação + fumaça + fluxo de interface + controlador no Windows | 175/175, 33/33 e 63/63 |
| `.exe` exportado executado *headless* | carregou a tela inicial, sem `SCRIPT ERROR` |
| `user://settings.cfg` criado pelo `.exe` | `%APPDATA%\BlackSight\settings.cfg` com `mouse_sensitivity_x`, `master_volume`, `window_mode`, `vsync` |
| `.exe` aberto com janela | vivo após 25 s, título “Black Sight” |
| Metadados do `.exe` | `ProductName=Black Sight`, `FileDescription=Black Sight — Etapa 4`, `FileVersion=0.4.0.0`, `CompanyName=EtecStudy` |
| ZIP conferido | 4 arquivos; tamanho e SHA-256 publicados |

## 6.1 Release publicada

| Item | Valor |
| --- | --- |
| Tag | `v0.4.0-etapa4` |
| Download | <https://github.com/EtecStudy/BLACKSITE/releases/download/v0.4.0-etapa4/BlackSight-Etapa4-Windows-x86_64.zip> |
| Tamanho do ZIP | **40.624.846 bytes** (≈ 38,7 MiB) |
| SHA-256 do ZIP | `da042476c11bffe8563cd3c73c883add77bbf3f53281b3f4ac900b0e134e0a66` |
| `BlackSight.exe` | 109.193.728 bytes |
| `BlackSight.pck` | 1.405.204 bytes |
| `LEIA-ME.txt` / `SHA256SUMS.txt` | 1.758 / 164 bytes |

O `SHA256SUMS.txt` dentro do ZIP repete o hash do `.exe` e do `.pck`, para
conferência local.

## 7. Limitações e pendências desta etapa

- Não há corrida, agachamento, stamina, pulo nem interação (próximas etapas).
- A cena de teste é uma sala de primitivas; não é o laboratório definitivo.
- Sem escadas nesta etapa (ficam junto do sistema de mapas).
- O controlador usa cápsula simples, sem animação de corpo (não há corpo
  visível em primeira pessoa).
- Não há som de passos.
- O mouse é capturado ao entrar na cena; em ambientes sem servidor gráfico
  (CI) a captura é ignorada de propósito.

## 8. Como testar manualmente

1. Abra `BlackSight.exe` e clique em **TESTAR MOVIMENTAÇÃO**.
2. Ande com **W A S D**; confira que a diagonal não é mais rápida.
3. Mova o mouse para olhar; tente olhar bem para cima/baixo (a câmera para).
4. Caminhe contra paredes, pilares e caixas — não deve atravessar.
5. Pressione **ESC**: o cursor aparece. Clique em **CONTINUAR** (ou ESC) e o
   mouse é capturado de novo.
6. Pressione **ESC** → **VOLTAR AO MENU**; o menu inicial volta.
7. Abra **CONFIGURAÇÕES**, mude a sensibilidade e a inversão vertical, aplique,
   volte ao menu e entre de novo no teste para sentir a diferença.
8. **SAIR DO JOGO** continua fechando o jogo normalmente.

## 9. Documentos relacionados

- [`CONFIGURACOES.md`](CONFIGURACOES.md) — onde ficam as configurações.
- [`ARQUITETURA.md`](ARQUITETURA.md) — módulos e dependências.
- [`RELEASE_NOTES_ETAPA4.md`](RELEASE_NOTES_ETAPA4.md) — notas da release.
