# BLACKSITE 0.1

Fundação de protótipo cooperativo de terror 3D com Godot 4 e rede ENet. Estado de sessão e movimentação compartilhada são mantidos pelo host; até quatro peers por sala.

## Executar

Abra `project.godot` no Godot 4.3 ou posterior. Hospede no botão correspondente; para testar localmente, abra uma segunda instância e conecte em `127.0.0.1`, UDP `24560`. Controles: WASD, Shift, mouse; Esc libera o cursor; clique recaptura. Use `SAIR` para encerrar.

Headless estrutural (requer Python 3): `python3 -m unittest discover -s tests -p 'test_*.py' -v`. A validação de runtime em Godot requer o executável Godot instalado. Execute o script Blender com `blender -b --python blender/source/generate_props.py` para gerar o fonte `.blend` e a exportação completa do asset, com Blender 4.x.

## Rede

ENet usa UDP 24560 por padrão, configurável no menu. LAN: informar IP privado do host e permitir a porta no firewall do servidor. Internet: o host precisa encaminhamento UDP 24560 no roteador/firewall ou hospedagem com UDP público; CGNAT pode inviabilizar conexões entrantes. Não há relay, matchmaking online, criptografia, autenticação ou proteção anti-cheat. Não exponha um servidor sem considerar esses limites.

## Arquivos e limitações

- `scenes/`: menu, avatar e setor.
- `scripts/networking/`: ciclo de conexão e estado autoritativo; `scripts/player/`: avatar e mapa.
- `assets/models/blacksite_crate.glb`: GLB 2.0 próprio e leve; `blender/source/generate_props.py`: fonte procedural Blender para asset detalhado.
- `docs/ASSET_CATALOG.md`: pesquisa e procedência; `docs/ETAPA_1_RELATORIO.md`: evidência e limites da validação.
- Sem criatura, áudio, sistema de salas remotas, persistência de partidas ou build Windows nesta fundação.
