# BLACKSITE 0.1 — Relatório da Etapa 1

**Data da inspeção:** 18/10/2026 (UTC)  
**Estado:** fundação e arquivos de projeto implementados; critério de conclusão integral **não atingido**, pois o ambiente não contém Godot/Blender e não permite executar a demonstração em runtime.

## Resumo executivo

Foi criado um projeto Godot 4 organizado com menu de sessão, host/cliente ENet, sala nominal de quatro peers, geração de um pequeno setor industrial, avatar em primeira pessoa, input de movimento enviado ao servidor, snapshots e recursos próprios. Foi feito um GLB mínimo de caixa procedural e criada uma fonte Blender Python para produzir a versão mais detalhada, `.blend` e export GLB quando Blender estiver disponível.

Foram executados cinco testes Python estruturais e o lint/formatação GDScript via `gdtoolkit`: todos passaram. Esses testes não executam a engine, não verificam o importador GLB da Godot e não demonstram multiplayer. **Não afirmar como validado:** menu em execução, conexões entre peers, movimento em dois clientes, colisão durante jogo, visualização/renderização nem export Windows.

## Inspeção do ambiente e proveniência

- Repositório inicial: somente `README.md`, sem prova de conceito anterior nem arquivos de jogo para reaproveitar.
- Godot/Godot4: não instalados e não encontrados no sistema. Tentativa de obtenção do binário oficial 4.4.1 via GitHub foi redirecionada para `objects.githubusercontent.com`, host fora da lista permitida; conexão falhou. Não há versão efetivamente instalada.
- Templates de exportação: não encontrados em `~/.local/share/godot/export_templates` nem em configuração local. Sem editor Godot, não foi possível confirmar instalação por outro mecanismo.
- Blender: não instalado/encontrado. A fonte `blender/source/generate_props.py` existe, porém não foi executada e nenhum arquivo `.blend` foi produzido neste ambiente.
- Python: 3.11.2. Testes usam somente biblioteca padrão. `gdtoolkit` foi instalado temporariamente em `/tmp/gdcheck` para validar estilo/sintaxe GDScript, não é dependência do produto.
- Memória observada: 3.8 GiB total, 3.6 GiB disponíveis; armazenamento de `/`: 21 GiB total, 20 GiB disponíveis.
- GCC e G++ disponíveis; CMake e Ninja não encontrados. Ferramentas de exportação Windows não disponíveis.
- GitHub CLI autenticado como `EtecStudy` durante a inspeção. O bucket Supabase BLACKSITE não foi listado nem alterado: as ferramentas Supabase expostas nesta sessão não incluem Storage/buckets; não foram criados projetos, buckets ou credenciais.
- Persistência: commit `0a377f7` enviado com sucesso para `origin/arena/6823859e-blacksite`; arquivos preservados no GitHub, sem criar PR. Checkout local limpo após push.

## O que foi implementado

- `project.godot`: projeto Godot 4, cena inicial, autoload da rede, controles WASD/Shift e renderer compatível.
- `scenes/menu/main_menu.tscn`, `scripts/networking/menu.gd`: menu para hospedar, conectar por IP/porta e encerrar.
- `scripts/networking/net.gd`: ENet UDP, limite nominal de quatro peers, status de conexão/erro, entrada/saída, estado de jogador, input de movimento recebido pelo host e snapshots de posição/yaw/pitch.
- `scenes/maps/sector.tscn`, `scripts/player/sector.gd`: construção modular de sala de entrada, corredores e quatro salas laterais/conectadas, paredes/pisos com `StaticBody3D` e caixas de colisão, molduras, luminárias, crates, painel e spawn markers.
- `scenes/player/avatar.tscn`, `scripts/player/avatar.gd`: capsule, corpo provisório, câmera local, controle mouse, WASD e corrida. Avatares remotos não criam câmera.
- `assets/models/blacksite_crate.glb`: GLB 2.0 independente, próprio, 12 triângulos e material metálico simples; inclui collider criado na cena. A estrutura do container/JSON e tamanhos foram verificados por teste Python. Ainda não foi importado pela Godot.
- `blender/source/generate_props.py`: fonte Python `bpy` de caixa industrial com reforços, rebites e três materiais; quando executada no Blender, grava `blender/source/blacksite_crate.blend` e exporta `assets/models/blacksite_crate.glb`. Não executada por falta de Blender.
- `tests/build_glb.py`, `tests/test_project.py`: geração GLB leve e verificações estruturais reproduzíveis.
- `docs/ASSET_CATALOG.md`: recursos encontrados, páginas, licença consultada, metadados conhecidos, limitações e decisões. Nenhum asset de terceiros foi baixado ou redistribuído.

## Pesquisa e decisão de assets

As páginas consultadas estão listadas em `docs/ASSET_CATALOG.md`. Fontes avaliadas: Kenney Factory Kit e City Kit Industrial (páginas indicam CC0), categoria industrial da Poly Haven (categoria declara CC0), categoria Concrete do ambientCG, e modelo low-poly do Sketchfab de Colin.Greenall (página aponta CC BY; detalhes de asset/licença integral não foram baixados e precisam ser rechecados). Não se inferiu autorização de arquivo específico sem download/inspeção.

Decisão para esta etapa: usar geometria própria procedimental e materiais de cor simples no cenário, sem texturas pesadas nem áudio de terceiros. A modelagem procedural do mapa é direta no GDScript; o prop de caixa possui GLB próprio e fonte de produção Blender. A versão BLEND e a verificação Blender→Godot continuam bloqueadas pela ausência das duas aplicações necessárias.

## Testes e validação observada

| Verificação | Resultado observado |
|---|---|
| `python3 -m unittest discover -s tests -p 'test_*.py' -v` | **Aprovado:** 5 testes estruturais passaram (arquivos e referências básicas, sinais/features de rede presentes no código, intenção de colisão/props declarada, GLB 2.0/JSON/accessor coerentes, catálogo/fonte Blender presentes). Não equivalem a teste de execução. |
| `gdformat` e `gdlint` nos quatro scripts GDScript | **Aprovado:** scripts formatados; `gdlint` reportou “Success: no problems found”. É lint/parser externo, não compilação da Godot. |
| `git diff --check` | **Aprovado:** sem whitespace errors no momento da verificação. |
| Abrir projeto e menu na Godot | **Não executado:** Godot ausente. |
| Hospedar e encerrar partida pelo menu | **Não executado:** Godot ausente. |
| Cliente local, dois clientes, LAN ou internet | **Não executado:** Godot ausente; nenhuma afirmação de multiplayer funcional em runtime. |
| Movimento remoto, câmera local exclusiva e desconexão em runtime | **Não executado:** Godot ausente. |
| Colisão jogador-parede em runtime | **Não executado:** há colliders no código/cena, mas simulação não foi rodada. Além disso, a posição autoritativa do servidor ainda usa limites de área e integração de input, sem resolução de colisão autoritativa por `CharacterBody3D`; corrigir antes de chamar esta arquitetura de servidor de movimento plenamente autoritativo. |
| Blender salvar `.blend` e exportar GLB | **Não executado:** Blender ausente. |
| Importação e validação visual do GLB na Godot | **Não executado:** Godot ausente. |
| Export Windows e execução no Windows | **Não executado:** engine/templates Windows ausentes; ambiente Linux. |

## Comandos

```sh
# Abrir e executar (em máquina com Godot 4.3+)
godot --path .

# Executar testes Python estruturais
python3 -m unittest discover -s tests -p 'test_*.py' -v

# Gerar GLB mínimo (Python padrão)
python3 tests/build_glb.py

# Gerar BLEND e export detalhado (requer Blender 4.x)
blender -b --python blender/source/generate_props.py

# GDScript lint, quando gdtoolkit está instalado
gdformat --check scripts/networking/menu.gd scripts/networking/net.gd scripts/player/avatar.gd scripts/player/sector.gd
gdlint scripts/networking/menu.gd scripts/networking/net.gd scripts/player/avatar.gd scripts/player/sector.gd
```

## Multiplayer e conectividade

Porta padrão: UDP 24560. Para LAN, conectar ao IP privado do host e permitir UDP no firewall. Para internet, o host precisa IP público/encaminhamento de porta UDP ou servidor hospedado; CGNAT pode impedir entrada. Não foi implementado relay, autenticação, matchmaking público, criptografia nem anti-cheat. Não foram expostos serviços nem credenciais.

## Export e arquivos

- Build Windows: **não produzida**. Não havia Godot nem templates; não confundir o GLB com build executável.
- Projeto fonte: raiz deste repositório; estrutura resumida em `README.md`.
- GLB gerado: `assets/models/blacksite_crate.glb` (1.588 bytes no momento da geração).
- Fonte Blender procedural: `blender/source/generate_props.py`.
- Arquivo `.blend`: **não gerado** neste ambiente.
- ZIP do projeto: **não gerado**; o GitHub/repositório é o meio de persistência pretendido, evitando incluir `.git` ou caches em um pacote não necessário.
- Relatório: `docs/ETAPA_1_RELATORIO.md`.

## Limitações e correções obrigatórias antes de ampliar

1. Instalar Godot 4.x e rodar a cena, corrigir quaisquer erros de parser/recursos, testar duas instâncias e capturar evidências reais.
2. Atualizar a simulação de host para movimentar `CharacterBody3D` autoritativos com colisões, gravidade/estado e validar limites de input/velocidade; o código atual aceita input remoto de movimento/corrida e integra posição numericamente no servidor, mas não tem validação anti-cheat robusta nem colisão física autoritativa.
3. Validar câmera, sincronização, conexão/recusa, saída, quatro peers e encerramento em engine real.
4. Instalar Blender, rodar o script, verificar o `.blend` e os materiais/escala; importar GLB no Godot e comparar a orientação/escala visualmente.
5. Confirmar export templates e fazer export Windows; Windows real ainda requer teste fora deste Linux.
6. O cenário é protótipo geométrico procedimental, não revisão artística final. Não há criatura, efeitos sonoros, animações ou texturas. A fonte Blender tem um crate mais detalhado, mas a cena atual usa GLB mínimo.
7. Reavaliar regras/atribuição de cada asset externo individual antes de o integrar; catálogo enumera páginas pesquisadas, não downloads.

## Próxima etapa recomendada

Executar primeiro a validação em Godot/Blender em ambiente com as ferramentas; fechar a autoridade física e replicação com testes automatizados de duas instâncias e colisão; então substituir o GLB mínimo pelo crate detalhado, registrar captura de importação e gerar a primeira build Windows.
