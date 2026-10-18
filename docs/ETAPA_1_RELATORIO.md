# BLACKSITE 0.1 — preparação e validação Windows

**Status do jogo:** Etapa 1 **não concluída**. O Windows launcher foi criado como PE nativo, mas o jogo ainda não foi executado em Godot, e o launcher não pôde ser executado no Windows deste ambiente Linux.

## Branch, estado e auditoria

- Trabalho iniciado na branch `arena/6823859e-blacksite`. Estado remoto conferido: `c7329c2` (descendente de `b6ea196`). A árvore estava limpa.
- Cena principal: `res://scenes/menu/main_menu.tscn`; autoload `Net`: `res://scripts/networking/net.gd`.
- O setor realmente carrega `res://assets/models/blacksite_crate.glb`. Testes verificam que as referências `res://` em `project.godot`, `.tscn` e `.gd` existem.
- Quatro scripts GDScript passam `gdformat`/`gdlint`; isso não é compilação/validação semântica da Godot 4.7.
- O artefato anterior `prova#D.exe` não foi encontrado no repositório nem em `/home/user`; o método anterior não pôde ser inspecionado.

## Inicializador Windows criado

- `BLACKSITE.exe` na raiz: PE nativo Windows x64, subsystem GUI (sem janela de terminal), compilado de `launcher/windows/blacksite_launcher.c` com Zig 0.13.0, cross-target `x86_64-windows-gnu`. SHA-256: `7fbcc94b5bead48686a56053e0bf5512b51bbdd681a2868689119f763a34b643`.
- O launcher procura o projeto na própria pasta, verifica `project.godot`, cena principal, script de rede e GLB, e usa exatamente `C:\Users\kimfe\Desktop\GODOT\Godot_v4.7.2-stable_win64.exe`.
- Inicia o jogo diretamente com `CreateProcessW(..., --path "<pasta do projeto>")`; não abre o editor, não requer PATH nem CMD/PowerShell e deixa a Godot escolher a cena principal configurada no projeto.
- Ausência da Godot ou de arquivos essenciais produz caixa de erro clara. O launcher não inclui nem finge incluir a engine.
- PE produzido: 6.144 bytes, arquitetura x86-64, subsistema GUI; imports inspecionados: apenas `KERNEL32.dll` e `USER32.dll` (sem C runtime de terceiros).
- `BLACKSITE-Windows-Package.zip` contém `BLACKSITE.exe` junto com o projeto-fonte. **Extraia o ZIP inteiro** e mantenha o executável ao lado de `project.godot`, pastas `scenes/`, `scripts/` e `assets/`. A Godot externa precisa estar no caminho absoluto acima.
- Guia técnico: `docs/BLACKSITE_WINDOWS_LAUNCHER.md`.

## Verificações e limites do inicializador

### Aprovados (executados)

- Compilação cross-target Windows x64 concluída com Zig 0.13.0.
- Cabeçalho PE analisado: `MZ`, assinatura PE, máquina `0x8664` (x64), subsystem `2` (Windows GUI), entrypoint presente.
- Tabela de imports analisada com `pefile`: somente `KERNEL32.dll` e `USER32.dll`.
- Strings UTF-16 do caminho da instalação fornecida e argumento `--path` presentes no executável.
- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: **8 testes aprovados**, incluindo estrutura PE, caminho Godot compilado, subsystem, dependências do launcher, caminhos de recursos e testes anteriores do GLB/rede.
- `gdformat --check` e `gdlint`: quatro scripts GDScript aprovados.
- `git diff --check`: sem erros de whitespace.
- Validação Khronos anterior do GLB: zero erros/avisos; arquivo inalterado.

### Não executados

- Executar `BLACKSITE.exe` em Windows 10/11: não há Windows, Wine ou `cmd.exe` neste ambiente Linux. A validação do PE não prova que o launcher inicia com sucesso no computador do usuário.
- Verificar que o arquivo Godot informado realmente existe na máquina Windows ou que a versão do motor abre o projeto.
- Godot editor/runtime, carregamento da cena, multiplayer, colisões, renderização e mensagens reais do console.
- Importar o GLB no Godot, validar visualmente a cena ou construir/exportar um **build do jogo**. O PE criado é apenas inicializador; não é o jogo compilado nem contém Godot.
- O ZIP foi montado localmente para entrega; o próprio launcher e o pacote completo ainda precisam de clique/teste real no Windows.

## Ambiente / dependências externas

- Linux x86-64, Python 3.11.2, Zig 0.13.0 instalado temporariamente de PyPI para cross-compilar. Godot e Blender não estão instalados; não foi repetida tentativa de download da Godot.
- O path da Godot foi configurado no código a partir do caminho explicitamente informado pelo usuário. Se a instalação for movida/renomeada, o launcher mostrará que ela está ausente; nesse caso será necessária nova build com caminho atualizado.
- Supabase Storage não está disponível nas ferramentas. Bucket `BLACKSITE` não foi consultado ou alterado.

## Como usar e próxima ação

1. Baixe `BLACKSITE-Windows-Package.zip` e extraia todos os arquivos para uma pasta normal.
2. Confirme que `C:\Users\kimfe\Desktop\GODOT\Godot_v4.7.2-stable_win64.exe` existe. O launcher espera o executável gráfico padrão, não o `*_console.exe` wrapper.
3. Dê dois cliques em `BLACKSITE.exe`. A Godot deve iniciar o projeto diretamente; se houver arquivo ausente, o launcher exibe uma caixa de erro.
4. Para validar o jogo, depois que abrir, testar menu, colisões e duas instâncias conforme `tests/MULTIPLAYER_MANUAL.md`; salvar erros/telas reais.

A Etapa 1 só pode avançar após confirmar o duplo clique no Windows, a abertura da cena e os testes de runtime multiplayer/colisões. O inicializador pode ser baixado/testado agora, mas o jogo ainda não foi declarado funcional.
