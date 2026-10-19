# Black Sight · Etapa 2 — Arquitetura interna (Windows x86_64)

Segunda versão executável. **A jogabilidade ainda não existe**: esta etapa
organiza a estrutura interna do projeto em módulos.

## O que mudou em relação à Etapa 1

- Projeto reorganizado em módulos por responsabilidade: `players/`, `creatures/`,
  `maps/`, `items/`, `objectives/`, `ui/`, `audio/`, `match/`, `shared/`.
- Tela inicial, tema, fontes, texturas e autoload **movidos** para os módulos
  (`ui/` e `shared/`) — conteúdo e comportamento idênticos.
- Documentação de arquitetura em `docs/ARQUITETURA.md` + `README.md` por módulo.
- Versão do projeto atualizada para **0.2.0**.

## O que continua igual

A tela inicial é a mesma da Etapa 1: fundo, vinheta, partículas, emblema
animado, título, botão **SAIR DO JOGO** e atalho **F11** (tela cheia).
Resolução 1920×1080, renderizador GL Compatibility e tema não mudaram.

## Como executar

1. Extraia o ZIP em uma pasta.
2. Mantenha `BlackSight.exe`, `BlackSight.pck` e `LEIA-ME.txt` juntos.
3. Duplo clique em `BlackSight.exe`.

Requisitos: Windows 10/11 64 bits, GPU com OpenGL 3.3 ou superior.

## Verificação do download

`SHA256SUMS.txt` (dentro do ZIP) traz os hashes de `BlackSight.exe` e
`BlackSight.pck`.

SHA-256 do próprio ZIP:
`09007dae33d7a907a0b1631b9d56d96d6b3ee3bbf11b3d9aa6582d99af7e1fcf`

## Testes executados na geração deste pacote

- Importação de recursos (`--import`) no Linux e no Windows.
- Teste de fumaça automatizado, incluindo verificação dos nove módulos.
- Execução da cena inicial (headless) no Windows.
- Exportação Windows e execução do `.exe` gerado em `windows-latest`.
- Abertura do `.exe` com janela e leitura do título da janela.
- Inspeção do `.pck` (cena, scripts, tema, fontes e texturas presentes).

> O binário é gerado e executado no CI (Windows Server 2022, renderização por
> software). A execução no computador do usuário é validada por ele.
