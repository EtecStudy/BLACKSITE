# Remoção da sala de reconstrução 3D (0.14.1)

Registro da remoção completa da sala criada para a reconstrução 3D da
imagem de referência (cozinha), a pedido do usuário. A sala não será mais
utilizada e deixou de existir no projeto ativo e no menu.

## Checkpoint antes da exclusão

- Tag **`v0.14.0-pre-remocao-reconstrucao`** criada no commit `f3efb45`
  (estado completo com a sala) antes de apagar qualquer arquivo.
- A sala permanece recuperável pelo histórico:
  `git checkout v0.14.0-pre-remocao-reconstrucao -- maps/reference match/scenes/kitchen_reference.tscn match/scripts/kitchen_reference_session.gd tools/ci/kitchen_reference_visual_check.gd`

## Apagado (exclusivo da sala)

- `maps/reference/` inteiro: cena `kitchen_reference.tscn`, 33 materiais
  e 53 texturas procedurais (paredes, carpete, azulejos, ferrugem etc.).
- `match/scenes/kitchen_reference.tscn` (sessão jogável) e
  `match/scripts/kitchen_reference_session.gd`.
- `tools/arch/build_kitchen_reference.py` (gerador da sala; a pasta
  `tools/arch/` ficou vazia e foi removida).
- `tools/ci/kitchen_reference_visual_check.gd/.tscn` (teste visual
  exclusivo) e os passos **TESTE 3f** (Linux) e **TESTE W3b** (Windows)
  do workflow.
- `docs/RECONSTRUCAO_REFERENCIA.md` (documentação da sala; este arquivo
  é o registro da remoção).
- Capturas da sala existiam apenas nos branches de diagnóstico do CI
  (`ci-diagnostics`/`ci-windows`), fora do projeto.

## Referências removidas

- Menu: botão **RECONSTRUÇÃO 3D** (`KitchenReferenceButton`), constante
  `KITCHEN_REFERENCE_SCENE`, ligação e função no `title_screen.gd`,
  texto do `StageHint` e o nó esperado no smoke test.
- Workflow: passos de captura da cozinha, textos de versão/LEIA-ME e o
  padrão de tag da release atualizados para a 0.14.1.
- `README.md`: passo que abria a sala removido.

## Preservado (compartilhado)

Player/câmera, movimentação, corrida, agachamento, stamina, inventário,
pickup/drop, UI/menus, configurações, biblioteca modular
(`maps/modular/`), sala de movimentação e seus testes — nada disso foi
tocado além da remoção do botão da sala excluída. As palavras genéricas
"reconstruir" em comentários antigos (HUD, detector de interação, docs
históricas) não têm relação com a sala e foram mantidas.

## Validação

CI (Linux + Windows) verde após a remoção: SMOKE, UI FLOW, MOVEMENT e
DROP OBSTACLE aprovados; busca por `kitchen`/`maps/reference` no projeto
sem resultados.
