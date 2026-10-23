# Limpeza das salas de teste — v0.13.2

Registro da remoção de todas as salas/cenas visuais de demonstração do
projeto. A partir desta versão, o único ambiente jogável de teste é a
**sala de movimentação**. Nenhuma sala nova foi criada.

## Checkpoint e recuperação

- Estado anterior completo (v0.13.1, sala-piloto refinada): tag
  `v0.13.1-pre-limpeza-salas` sobre o commit `e8c74df`.
- Recuperação de qualquer arquivo removido:
  `git checkout v0.13.1-pre-limpeza-salas -- <caminho>` (ou consultar a
  tag/release `v0.13.1-sala-piloto-refinamento`).
- Esta limpeza recebe a tag `v0.13.2-limpeza-salas`.

## O que foi apagado

### Sala-piloto visual (Etapa 13/13B)
- `maps/pilot/` inteiro: `pilot_research_room.tscn`, 43 materiais em
  `maps/pilot/materials/` e 28 texturas em `maps/pilot/textures/`.
- `match/scenes/pilot_room.tscn` e `match/scripts/pilot_room_session.gd`.
- `tools/ci/pilot_room_test.gd/.tscn` e
  `tools/ci/pilot_room_visual_check.gd/.tscn`.
- `tools/arch/build_pilot_room.py` (gerador exclusivo da sala).

### Primeiro andar do laboratório (Etapa 12A)
- `maps/scenes/laboratory_first_floor.tscn`.
- `match/scenes/laboratory.tscn` e `match/scripts/first_floor_session.gd`.
- `tools/ci/first_floor_test.gd/.tscn` e
  `tools/ci/first_floor_visual_check.gd/.tscn`.
- `tools/arch/build_first_floor.py`, `tools/arch/first_floor_layout.json` e
  `tools/arch/render_plan.py` (ferramentas exclusivas da planta).

### Sala de demonstração dos módulos (Etapa 11)
- `maps/scenes/modular_demo_room.tscn`.
- `match/scenes/modular_demo.tscn` e `match/scripts/modular_demo.gd`
  (sessão base usada apenas pelas três sessões removidas).
- `tools/ci/modular_test.gd/.tscn` e
  `tools/ci/modular_visual_check.gd/.tscn` (suítes da cena de demonstração).

### Menu, testes compartilhados e pipeline
- `ui/scripts/title_screen.gd` e `ui/scenes/title_screen.tscn`: botões
  **SALA-PILOTO VISUAL**, **PRIMEIRO ANDAR** e **DEMONSTRAR MÓDULOS**
  removidos (nós, constantes de cena, conexões e manipuladores), junto do
  texto de rodapé que os descrevia. Permanecem JOGAR (desabilitado),
  TESTAR MOVIMENTAÇÃO, CONFIGURAÇÕES e SAIR DO JOGO.
- `tools/ci/smoke_test.gd`: removidas as verificações das salas apagadas
  (`_check_stage12a`, `_check_pilot_room`, botões do menu) — todas as
  verificações de sistemas (controlador, inventário, drop, configurações,
  módulos do projeto) permanecem.
- `tools/ci/ui_flow_test.gd`: removidos os fluxos 10b (primeiro andar),
  10c (sala-piloto) e 11 (demonstração modular). O fluxo da sala de
  movimentação e das configurações permanece integral.
- `.github/workflows/build.yml`: removidos os passos de teste/renderização
  das salas apagadas nos jobs Linux e Windows, a criação de release da
  sala-piloto e as referências às cenas na lista de arquivos obrigatórios.
  O pacote passa a se chamar `BlackSight-Windows-x86_64.zip`, sem release
  automática nesta etapa.
- Versão do projeto: 0.13.1 → **0.13.2** (`project.godot`,
  `shared/autoload/app_info.gd`, `export_presets.cfg` e expectativas do
  teste de fumaça).
- `README.md`: removidos os passos de menu das salas apagadas e anotada a
  remoção nas descrições históricas.

## O que foi preservado

- **Sala de movimentação (única sala restante):**
  `match/scenes/movement_test.tscn`, `match/scripts/movement_test.gd`,
  `maps/scenes/test_room.tscn` (geometria da sala — é a sala de teste
  original das etapas iniciais e a base da sala de movimentação, por isso
  não é um arquivo separado a apagar), `maps/scenes/interaction_test_panel.tscn`,
  `maps/scripts/interaction_test_panel.gd` e
  `items/scenes/inventory_test_item.tscn`.
- **Biblioteca modular reutilizável:** todo o `maps/modular/` (paredes,
  pisos, tetos, corredores, salas, escadas, estrutura e materiais) — apenas
  a cena montada de demonstração e sua suíte foram removidas.
- **Sistemas:** jogador, câmera, movimentação/corrida/agachamento/stamina,
  inventário, pickup/drop (incl. `shared/mapping/space_probe.gd`, usado
  pelo drop), UI, menus, configurações, autoloads, áudio e temas.
- **Testes de sistemas:** fumaça, fluxo de interface, controlador/inventário/
  drop (`tools/ci/movement_test.gd`), drop com obstáculos e capturas de
  inventário/drop — todos apontam para a sala de movimentação.
- **Documentação histórica** das etapas removidas (inclusive
  `docs/SALA_PILOTO_VISUAL.md`, `docs/REFINAMENTO_VISUAL_SALA_PILOTO.md` e
  `docs/screenshots/sala-piloto/`): o histórico permanece legível; nada no
  jogo referencia essas salas.
- Configurações do Godot, estrutura de pastas e o Git (checkpoint acima).

## Validação

- CI (Linux + Windows) sobre o commit da limpeza: importar, fumaça, fluxo
  de interface, controlador, drop, renderizações da tela inicial/
  configurações/movimentação, exportações Windows/Linux, execução do build
  exportado e inspeção do `.pck`.
- Teste manual pendente: abrir o jogo, entrar em TESTAR MOVIMENTAÇÃO e
  percorrer andar/correr/agachar/câmera/colisões/stamina/inventário/
  pickup/drop/ESC/menu/configurações. O menu não deve mostrar nenhuma das
  salas removidas.
