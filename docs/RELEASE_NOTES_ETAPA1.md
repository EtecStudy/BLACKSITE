# Black Sight · Etapa 1 — Fundação do projeto

Primeira versão executável do projeto **Black Sight**, jogo de terror em primeira pessoa.

## O que está incluído

- Projeto Godot 4.7.2 configurado como **Black Sight**.
- Resolução lógica 1920 × 1080 (16:9), janela inicial 1600 × 900, redimensionável.
- Renderizador **GL Compatibility** (OpenGL 3.3+), compatível com GPUs integradas.
- Cena inicial **funcional**: título, emblema animado, poeira, vinheta, fade de entrada.
- Botão **SAIR DO JOGO** e atalho **F11** para alternar tela cheia.
- Ícone, splash de boot e tema de UI próprios.

## O que NÃO está incluído (escopo das próximas etapas)

Jogador, criaturas, mapa, portas, inventário, objetivos, multiplayer e qualquer
outra mecânica de jogo. O botão **JOGAR** aparece desabilitado por esse motivo.

## Como executar

1. Extraia `BlackSight-Etapa1-Windows-x86_64.zip` em uma pasta.
2. Mantenha `BlackSight.exe`, `BlackSight.pck` e `LEIA-ME.txt` juntos.
3. Duplo clique em `BlackSight.exe`.

Requisitos: Windows 10/11 64 bits, GPU com OpenGL 3.3 ou superior.

## Verificação do download

O arquivo `SHA256SUMS.txt` (dentro do ZIP) contém os hashes de `BlackSight.exe`
e `BlackSight.pck`.

## Testes executados na geração deste pacote

- Importação de recursos do projeto (`--import`).
- Teste de fumaça automatizado (`tools/ci/smoke_test.gd`): configuração, tema,
  fontes, texturas, cena inicial e preset de exportação.
- Execução da cena inicial em modo headless (240 frames) sem `SCRIPT ERROR`.
- Renderização real da cena sob Xvfb + OpenGL, com captura de frame.
- Exportação Windows e validação da assinatura PE32+ x86-64 e do `.pck`.

> O binário é gerado no CI (Linux, Godot oficial). A execução em Windows real é
> validada pelo usuário.
