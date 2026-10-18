# BLACKSITE.exe — inicializador Windows

## O que o arquivo faz

`BLACKSITE.exe` é um inicializador nativo Windows x64 de interface gráfica, compilado a partir de `launcher/windows/blacksite_launcher.c`. Ao dar dois cliques, ele:

1. usa o caminho do próprio executável para localizar a pasta do projeto;
2. verifica `project.godot`, a cena inicial e recursos/scripts essenciais;
3. verifica a instalação gráfica da Godot no caminho informado pelo usuário: `C:\Users\kimfe\Desktop\GODOT\Godot_v4.7.2-stable_win64.exe`;
4. inicia esse executável diretamente com `--path "<pasta-do-projeto>"`. A Godot abre o jogo configurado como cena principal, sem abrir o editor primeiro;
5. apresenta uma caixa de erro clara se Godot ou os arquivos do projeto estiverem ausentes.

## Pacote e arquivos necessários

Use `BLACKSITE-Windows-Package.zip`. Extraia **o pacote inteiro** para uma pasta normal e mantenha `BLACKSITE.exe` ao lado de `project.godot`, `scenes/`, `scripts/` e `assets/`. Não execute o inicializador de dentro do visualizador do ZIP nem copie apenas o `.exe`.

Este inicializador **não contém a engine Godot**. O executável externo precisa existir exatamente em:

```text
C:\Users\kimfe\Desktop\GODOT\Godot_v4.7.2-stable_win64.exe
```

O launcher usa somente APIs do Windows (`KERNEL32.dll`, `USER32.dll`); não requer uma instalação de C runtime de terceiros. Não há argumento manual, PATH ou terminal necessário para abrir o jogo. O binário não está assinado digitalmente; se SmartScreen mostrar um aviso de publisher desconhecido, confira se baixou o ZIP deste projeto antes de escolher executar.

## Como o binário foi produzido e o que foi verificado

- Fonte: `launcher/windows/blacksite_launcher.c`.
- Toolchain: Zig 0.13.0 (pacote PyPI) com target `x86_64-windows-gnu`; compilado com subsistema Windows GUI e sem CRT.
- `BLACKSITE.exe` é um PE Windows x86-64 real (5.632 bytes na build registrada), subsistema GUI, imports somente `KERNEL32.dll` e `USER32.dll`. Cabeçalho PE, arquitetura, subsistema, strings do caminho da Godot, `--path` e ausência de imports de CRT foram inspecionados com Python/PE parser.
- O ambiente de compilação é Linux e não dispõe de Windows, Wine ou `cmd.exe`; por isso **o inicializador não foi executado em Windows** e o jogo não foi iniciado por ele nesta sessão. A validação acima é estática do binário, não prova de lançamento funcional.
- O arquivo `prova#D.exe` não foi encontrado no checkout nem em `/home/user`; não foi possível inspecionar ou reproduzir seu método anterior.

## Erros possíveis

- **Godot ausente:** confira o caminho acima e confirme que o arquivo é o executável gráfico `...win64.exe`, não o launcher `...console.exe` que procura outro executável irmão.
- **Projeto ausente:** extraia o ZIP completo; o `.exe` deve ficar ao lado de `project.godot`.
- **Godot inicia mas mostra erro do projeto:** preserve a mensagem/tela e compartilhe-a. A importação Godot, o multiplayer e a renderização ainda precisam ser validados na máquina Windows.
