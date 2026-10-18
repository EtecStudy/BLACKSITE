# BLACKSITE 0.1 — Relatório da Etapa 1 e continuação

**Data:** 18/10/2026
**Status:** projeto preservado e com correções de arquitetura aplicadas; etapa **não concluída** porque Godot runtime, dois peers, importação visual e build Windows não puderam ser executados.

## Base verificada e ambiente

A continuação inicial partiu de `arena/6823859e-blacksite`, commit `8167bfb`. Esta rodada de auditoria iniciou em `f66c6db`, verificado como `HEAD` e `origin` antes das alterações desta rodada. Estrutura, README, este relatório, catálogo, scripts GDScript, cenas, GLB, fonte Blender e testes foram inspecionados. Todo o histórico anterior foi preservado.

- Python 3.11.2; memória 3.8 GiB total / 3.6 GiB disponível; disco 21 GiB, 20 GiB disponíveis.
- Godot não encontrado em `/usr/bin`, `/usr/local/bin`, `/opt`, Snap ou `~/.local/bin`. Tentativa de download oficial 4.4.1 pelo GitHub foi redirecionada a `objects.githubusercontent.com`, bloqueado pela política de hosts, e falhou com `SSL_ERROR_SYSCALL`. Não há Godot instalado.
- `apt-get update` não pôde ser usado: índices locais não existem e a operação falhou por permissão em `/var/lib/apt/lists/partial`. Templates de exportação não foram encontrados.
- Blender binário também não encontrado. Alternativa tentada: `bpy==4.3.0` instalado em venv temporário via PyPI; import do módulo falha com `ImportError: libXrender.so.1: cannot open shared object file`. Sem permissão para instalar a dependência de sistema. Portanto **não foi criado `.blend`** nem foi executado o pipeline Blender.
- GCC/G++ presentes; CMake/Ninja, Snap, Flatpak, Docker/Podman e `xvfb-run` não encontrados.
- Supabase connector está habilitado, mas suas ferramentas expostas são para projetos, bancos, auth, functions e secrets; não há ferramenta de Storage/buckets. O bucket `BLACKSITE` não foi examinado nem alterado. Nenhum arquivo foi enviado ao Supabase, nenhuma credencial foi criada ou exposta.
- Persistência: auditoria/correções desta rodada foram commitadas e enviadas a `origin/arena/6823859e-blacksite` (commit `a6ee684`; implementação anterior `2dd2733`; commit inicial `8167bfb` preservado).

## Alterações realizadas nesta continuação

1. **Multiplayer e autoridade:** `scripts/networking/net.gd` agora valida vetor e ângulos finitos, normaliza/clampa inputs e recebe somente intenção do cliente. O host dirige os `CharacterBody3D` de todos os peers, usando movimento, gravidade e `move_and_slide()` contra a geometria física do mapa, e então distribui snapshots. Há limite de um host + três clientes, entradas/saídas e erros de conexão existentes preservados. Isso melhora a autoridade de movimento, mas continua sem rate limiting/anti-cheat abrangente e não foi verificado em runtime.
2. **Avatar/câmera:** `scripts/player/avatar.gd` diferencia predição local de simulação autoritativa no host; os clientes reconciliam posição com snapshots. A câmera começa inativa na cena e só a instância do jogador local a ativa; avatares remotos removem sua câmera.
3. **Conectividade do cenário:** `scripts/player/sector.gd` divide paredes laterais e extremidades apenas onde há módulos vizinhos, alinhando aberturas entre corredores e salas; as paredes externas permanecem fechadas. Adicionada névoa sutil à iluminação existente. Colliders seguem em pisos, paredes e objetos; a caixa importada tem collider separado.
4. **Resiliência da rede e UI:** input remoto sem atualização por 250 ms é zerado para impedir que perda de pacotes deixe um jogador andando continuamente. O roster agora monta IDs com `PackedStringArray`, evitando passar um `Array` genérico para `String.join`.
5. **GLB:** `tests/build_glb.py` gera agora o mesmo prop no sistema de coordenadas Y-up do glTF. `assets/models/blacksite_crate.glb` foi regenerado (1.588 bytes, 12 triângulos); o teste estrutural verifica a extensão vertical Y. Isto não equivale a importá-lo no Godot.
6. **Reprodutibilidade:** adicionados `tests/MULTIPLAYER_MANUAL.md` com roteiro local e Windows de dois clientes, movimento simultâneo, paredes/props/personagem, desconexão, erros críticos e limite de quatro players; README e catálogo/report atualizados. O roteiro é plano reproduzível, não teste executado.

A fonte `blender/source/generate_props.py` existente continua a produzir o modelo detalhado e salvar `.blend`/GLB se executada em Blender real; ela não foi executada porque a alternativa `bpy` requer a biblioteca ausente.

## Assets e licenças

O catálogo está em `docs/ASSET_CATALOG.md`. Foram consultadas páginas de Kenney Factory Kit e City Kit (Industrial), categoria Industrial da Poly Haven, categoria Concrete do ambientCG e um modelo de armazém low-poly no Sketchfab. Os assets de terceiros não foram baixados nem incorporados. As licenças referem-se às páginas pesquisadas, não a arquivos específicos não inspecionados; detalhes desconhecidos estão marcados. O GLB procedimental é próprio. Nenhum modelo de jogo comercial foi usado.

## Testes — resultados desta continuação

### Aprovado (executado)

- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: **5/5 aprovados**. Incluem estrutura do projeto, sinais/guardas de autoridade no código, colisões declaradas, container GLB 2.0, JSON/accessors e eixo Y vertical.
- `/tmp/gdcheck/bin/gdformat --check scripts/networking/menu.gd scripts/networking/net.gd scripts/player/avatar.gd scripts/player/sector.gd`: **4 scripts sem necessidade de reformatação**.
- `/tmp/gdcheck/bin/gdlint scripts/networking/menu.gd scripts/networking/net.gd scripts/player/avatar.gd scripts/player/sector.gd`: **Success: no problems found**. É análise externa do GDScript, não compilação pelo Godot.
- Validador oficial Khronos glTF Validator (`gltf-validator` npm 2.0.0-dev.3.10) executado sobre `assets/models/blacksite_crate.glb`: 0 erros, 0 warnings, 0 infos, 0 hints; identifica glTF 2.0, 1 material, 24 vértices, 12 triângulos e uma cena default. Isso comprova validade glTF estrutural, não o importador Godot.
- `git diff --check`: sem erros de whitespace.

### Reprovado (executado e falhou)

- Import da alternativa Blender `bpy==4.3.0`: reprovado por dependência de sistema não instalada, `libXrender.so.1`; nenhuma modelagem foi alegada como executada com Blender.
- Obtenção do binário Godot oficial: falhou após redirect para host de artefato não permitido. Não é teste do jogo.
- Tentativa `apt-get update`: bloqueada por falta de permissão para diretório de índices; nenhum pacote foi instalado por apt.

### Não executado (limitação objetiva)

- Abrir/rodar projeto, menu, sessão, conexão entre dois ou mais peers, desconexão, sync/câmera, colisão real, renderização e cenas no Godot: sem executável Godot.
- Importação visual do GLB no Godot e fluxo end-to-end Blender→Godot; salvar `.blend`: dependem de Blender e Godot operacionais.
- Exportar ou executar build Windows: sem Godot e templates; ambiente Linux. Nenhum `.exe` foi criado.
- Teste LAN/internet: nenhum servidor foi iniciado. Nenhuma conexão externa foi tentada.

## Procedimento manual multiplayer

Siga exatamente `tests/MULTIPLAYER_MANUAL.md`. Resumo: em dois terminais, executar `godot --path . --position 100,100` e `godot --path . --position 700,100`; hospedar no primeiro, conectar ao `127.0.0.1:24560` no segundo, verificar roster/movimento/câmera, bater em parede/caixa, fechar cliente e testar o limite (host + 3 clientes). Registrar versão, logs e resultados observados. Para LAN, usar IP privado e liberar UDP 24560 no firewall; teste local não valida internet.

## Executar, conteúdo e export Windows

- Projeto: abrir `project.godot` no Godot 4.3+ e executar a cena principal; instruções em `README.md`.
- Testes estruturais: `python3 -m unittest discover -s tests -p 'test_*.py' -v`.
- GDScript lint, se `gdtoolkit` instalado: `gdformat --check scripts/networking/menu.gd scripts/networking/net.gd scripts/player/avatar.gd scripts/player/sector.gd` e `gdlint` sobre os mesmos caminhos.
- GLB mínimo: `python3 tests/build_glb.py`.
- Pipeline Blender quando Blender 4.x estiver operacional: `blender -b --python blender/source/generate_props.py`; os resultados esperados são `blender/source/blacksite_crate.blend` e `assets/models/blacksite_crate.glb`.
- Windows: abrir projeto em Windows com Godot 4.3+ e templates da mesma versão; no editor, **Project > Export > Add… > Windows Desktop**, instalar/baixar os templates quando solicitado, selecionar x86_64, definir `export/BLACKSITE.exe` e exportar. Revisar recursos incluídos e iniciar o executável no Windows. Essas etapas ainda precisam ser executadas e comprovadas.
- Build Windows atual: **não existe**. Arquivo `.blend` atual: **não existe**. Não confundir o GLB do crate com executável.

## Limitações e próxima ação

- Embora o código agora simule os corpos no host e contenha colliders físicos, não há prova de que o parser Godot, importadores, sincronização ou colisões estejam funcionando sem engine.
- A primeira ação necessária é disponibilizar um host de validação com Godot 4.3+ e templates; abrir o projeto, corrigir erros de import/engine e executar o roteiro de dois peers. Depois disso, validar Blender/GLB e build Windows em máquina Windows.
- Integração Supabase Storage continua indisponível nesta sessão por ausência de ferramentas de buckets; projeto fonte preservado no GitHub.
- Etapa continua **aberta** até demonstração real de multiplayer de pelo menos dois jogadores com movimentação sincronizada e cenário com colisões, seguida da verificação de assets/build aplicável.
