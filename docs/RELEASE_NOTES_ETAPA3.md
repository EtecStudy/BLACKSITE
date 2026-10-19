# Black Sight — Etapa 3: Configurações básicas

Build Windows x86_64 do Black Sight, com a tela de configurações (controles,
áudio e vídeo) e persistência em `user://settings.cfg`.

## O que há de novo

- **Botão CONFIGURAÇÕES** na tela inicial, abrindo uma tela própria com abas
  **Controles**, **Áudio** e **Vídeo** — sem alterar emblema, animações,
  partículas, vinheta, título, F11 ou o botão **SAIR DO JOGO**.
- **Controles**: sensibilidade horizontal e vertical do mouse, inverter eixo
  vertical e a lista dos controles padrão previstos para o futuro controlador.
  Os valores ficam salvos; não há movimentação nesta etapa.
- **Áudio**: volumes de geral, efeitos, ambiente e música em buses reais
  (`Master`, `SFX`, `Ambience`, `Music`, `Voice`), com pré-visualização ao vivo
  e valor em porcentagem visível. Clique e confirmação da interface passam a
  ter som.
- **Vídeo**: resolução, modo de janela (janela / maximizada / tela cheia) e
  VSync. A lista de resoluções é limitada ao monitor atual e a resolução
  aplicada nunca passa do tamanho útil da tela — o jogo não fica inacessível.
- **APLICAR**, **RESTAURAR PADRÕES** e **VOLTAR**; o arquivo fica em
  `%APPDATA%\BlackSight\settings.cfg` (nunca na pasta do jogo).
- **Persistência validada**: valores fora dos limites são corrigidos; arquivo
  corrompido cai nos padrões sem impedir a abertura.

## Pacote

| Item | Valor |
| --- | --- |
| Arquivo | `BlackSight-Etapa3-Windows-x86_64.zip` |
| Tamanho | 40.611.269 bytes |
| SHA-256 | `d55afd98a80271808df3c67b2095e88e7fd42b4f1032b3faec3418aad0b72fcf` |
| Conteúdo | `BlackSight.exe`, `BlackSight.pck`, `LEIA-ME.txt`, `SHA256SUMS.txt` |

## Como usar

1. Extraia o ZIP mantendo `BlackSight.exe` e `BlackSight.pck` na mesma pasta.
2. Duplo clique em **BlackSight.exe**.
3. Clique em **CONFIGURAÇÕES**, ajuste o que quiser e clique em **APLICAR**.
4. Feche e abra o jogo: os valores continuam aplicados.
5. **RESTAURAR PADRÕES** + **APLICAR** volta tudo ao original.

`F11` alterna tela cheia em qualquer tela. **VOLTAR** (ou `Esc`) retorna ao menu
sem aplicar o que não foi confirmado.

## Testes

O pacote publicado é exatamente o gerado pelo workflow
[`build.yml`](https://github.com/EtecStudy/BLACKSITE/blob/main/.github/workflows/build.yml), que roda testes automatizados no
Linux e no Windows real antes de publicar. Resultados, evidências e limitações
estão em [`docs/ETAPA-3.md`](https://github.com/EtecStudy/BLACKSITE/blob/main/docs/ETAPA-3.md).

## Limitações desta etapa

- Não há jogador, movimentação, mapa, inventário, objetivos, criaturas,
  multiplayer nem voz.
- Música, ambiente e voz ainda não têm sons; apenas os buses respondem.
- VSync depende do driver de vídeo.
