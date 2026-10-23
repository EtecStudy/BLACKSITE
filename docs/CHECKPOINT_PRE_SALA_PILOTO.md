# Checkpoint de segurança — antes da Sala-Piloto Visual

**Data do registro:** 21 de outubro de 2026  
**Objetivo:** preservar o estado aprovado da Etapa 12A antes de qualquer experimento visual em uma sala independente.

## Referência principal

- **Commit-base da Etapa 12A preservado:** `ba5e463f2b3db763a8408cd257c055a519599ae1`
- **Mensagem:** `Detalha as 9 portas internas das divisorias na documentacao`
- **Release publicada da Etapa 12A:** `v0.12.0-etapa12a-primeiro-andar`
- **Commit da build da Etapa 12A:** `9d508281294199332dc6f9c93ce917be5a168027`
- **Tag já existente da Etapa 12A:** `v0.12.0-etapa12a-primeiro-andar`
- **Tag nova de segurança desta etapa:** `v0.12.1-pre-sala-piloto` — aponta para o commit de checkpoint criado imediatamente antes da Sala-Piloto.

## Arquivos que representam a planta atual

- `docs/ETAPA-12A.md` — especificação, escala e validação da planta.
- `docs/RELEASE_NOTES_ETAPA12A.md` — notas da release publicada.
- `tools/arch/first_floor_layout.json` — dados da planta do primeiro andar.
- `tools/arch/build_first_floor.py` — gerador da cena do primeiro andar.
- `tools/arch/render_plan.py` — renderização/registro da planta.
- `maps/scenes/laboratory_first_floor.tscn` — cena arquitetônica do primeiro andar.
- `match/scenes/laboratory.tscn` — sessão/cena jogável que instancia a planta.
- `match/scripts/first_floor_session.gd` — sessão do primeiro andar.
- `tools/ci/first_floor_test.gd` e `tools/ci/first_floor_test.tscn` — testes automatizados da planta.
- `tools/ci/first_floor_visual_check.gd` e `tools/ci/first_floor_visual_check.tscn` — verificações/capturas visuais.

## Sistemas independentes que não devem ser apagados

- `players/` — jogador, controlador, interação, inventário e drop.
- `ui/` — título, HUD, configurações e prompts.
- `shared/` — autoloads, configurações, temas, fontes e recursos compartilhados.
- `audio/` — buses e sons de interface.
- `items/`, `objectives/`, `creatures/` — módulos independentes do cenário.
- `project.godot` e `export_presets.cfg` — configuração e exportação do projeto.

## Regra de restauração

Para restaurar a Etapa 12A, use a tag `v0.12.0-etapa12a-primeiro-andar` ou o commit-base `ba5e463f2b3db763a8408cd257c055a519599ae1`. A tag `v0.12.1-pre-sala-piloto` registra o checkpoint imediatamente anterior ao experimento da Sala-Piloto, incluindo a pesquisa de paredes já entregue.
