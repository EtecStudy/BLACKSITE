# Black Sight — Etapa 9, correção do bug dos itens soltos

**Versão:** 0.9.1 · **Base:** v0.9.0-etapa9-drop · **Release:** `v0.9.1-etapa9-drop-fix`

Correção do problema encontrado no teste manual da Etapa 9: itens soltos
**perto de caixas, pilares, paredes e do painel** podiam aparecer parcialmente
dentro do objeto, ficar presos, afundar, cair para um lugar inadequado, ficar
inacessíveis ou "desaparecer" depois de alguns drops.

Nada da Etapa 10 (transferência entre jogadores) foi iniciado, e o multiplayer
continua fora do escopo. A Etapa 10 está deliberadamente pulada.

## 1. Causa do bug

O `SpaceProbe` da v0.9.0 validava a posição com **um único raio vertical no
centro do item** e uma **consulta de forma (caixa) 2 cm acima da superfície
encontrada**. Essa dupla respondia duas perguntas:

- "existe uma superfície com normal para cima nessa coluna?" → sim/não;
- "a caixa do item cabe livre **acima** dessa superfície?" → sim/não.

O que ela **não** perguntava era se a superfície encontrada **sustenta a pegada
inteira** do item. Consequência prática:

- se o raio caísse sobre a **quina** de uma caixa (ou sobre o **topo fino** do
  painel, de 9 cm, ou sobre o cubinho de um item de teste, de 26 cm), o ponto
  passava na validação e o item nascia **apoiado só num canto**;
- o `WorldItem` é um `RigidBody3D`: com 43% a 86% da base no vazio ele
  **tombava**, escorregava pela lateral do objeto e podia terminar
  encaixado entre o objeto e o piso — visualmente "dentro" da geometria, preso,
  ou fora do campo de visão ("desapareceu");
- a validação era feita **antes** de instanciar e **nunca era repetida** sobre o
  nó real, então nada detectava que o item havia ficado numa posição ruim;
- o corpo podia girar livremente ao assentar (`angular_damp` apenas freia),
  o que transformava qualquer apoio parcial em queda.

Medições com a geometria real da sala (grade de 3×3 raios sobre a pegada de
0,42 m) antes da correção:

| Local do drop | Drops aceitos | Aceitos com apoio parcial |
| --- | --- | --- |
| caixa de 1 m (`Crate1`) | 100 | 16 (57% a 61% da base apoiada) |
| caixa de 1,2 m (`Crate2`) | 68 | 12 (57% a 86%) |
| pilha de 2 m (`Crate3/4`) | 87 | 16 (57% a 61%) |
| pilar | 36 | 0 |
| painel de interação | 98 | 36 (14% a 29% — topo de 9 cm) |
| itens de teste (cubo de 26 cm) | 137 | 49 (24% a 33%) |

Os casos com apoio parcial são exatamente os que o teste manual descreveu. Não
havia `queue_free()` indevido nem remoção do item: o objeto continuava
existindo, apenas em uma posição inválida ou escondida.

## 2. Correção

### 2.1 Apoio completo da pegada (`shared/mapping/space_probe.gd`)

Nova etapa de validação, entre "existe piso" e "a caixa está livre":

- uma **grade 3×3 de raios curtos** cobre a pegada do item;
- **todas** as amostras precisam atingir a **mesma superfície** (tolerância de
  3 cm) com normal para cima;
- se uma quina, uma borda ou um topo fino aparecer, o ponto é **recusado**.

Assim o item nunca nasce apoiado parcialmente — ou fica inteiro no piso, ou
inteiro no topo do objeto, ou o drop é cancelado.

### 2.2 Deslizar sobre o topo do objeto

Recusar todo ponto sem apoio completo transformaria a área útil de uma caixa em
zona proibida. Para cumprir "sobre o cubo deve funcionar", quando a coluna tem
o **topo de um objeto** e o ponto direto não está totalmente apoiado, o
`SpaceProbe` procura em anéis de até 0,4 m **sobre a mesma superfície** um ponto
que tenha apoio completo, espaço livre e linha de visão, sempre à frente do
jogador e fora da cápsula. Se não achar, tenta a próxima distância
(1,15 m → 0,94 m → 0,74 m) e, no fim, cancela com `SEM ESPAÇO PARA SOLTAR`.

### 2.3 Superfície procurada com tolerância a teto/beirada

O raio vertical agora **itera**: se o primeiro contato não é uma face para cima
(teto, face inferior de uma viga), o raio recomeça logo abaixo desse ponto e
continua até achar um piso de verdade. Isso evita confundir teto com chão em
salas com cobertura ou saliência.

### 2.4 Confirmação depois de instanciar (`players/scripts/inventory/item_dropper.gd`)

Ordem final do drop, igual à do pedido de correção:

```
verificar item no slot
        ↓
calcular posição candidata (SpaceProbe)
        ↓
validar espaço físico + apoio + linha de visão
        ↓
instanciar WorldItem
        ↓
confirmar que a instância entrou e ficou na posição validada
        ↓
confirmar de novo, sobre o nó real: caixa livre + pegada apoiada
        ↓
remover item do inventário
```

`SpaceProbe.confirm_placement()` é chamado **já com o item na cena**, ignorando
os RIDs do próprio item e do jogador. Se falhar:

- o nó é **removido da cena e liberado** (`_discard_world_item`: `remove_child`
  + `free`, sem ficar um frame fantasma no grupo `world_items`);
- o item **continua no inventário**;
- a HUD mostra `SEM ESPAÇO PARA SOLTAR`.

Também há uma checagem de que o nó ficou exatamente na posição validada (se o
teleporte não acontecer, o drop é cancelado em vez de criar um item no lugar
errado).

### 2.5 Item estável ao assentar (`items/scenes/world_item.tscn`)

O `RigidBody3D` do item agora tem `axis_lock_angular_x/y/z = true`: ele cai,
assenta e desliza com a física, mas **não tomba nem rola**. Era o que a
documentação da Etapa 9 já prometia ("não tomba, não rola") e o que faltava
para o apoio parcial virar queda.

## 3. O que **não** mudou

- inventário de 3 slots, seleção 1/2/3, `G` para soltar, `E` para recolher,
  `R` como remoção provisória de teste;
- mensagens `SLOT VAZIO`, `SEM ESPAÇO PARA SOLTAR`, `INVENTÁRIO CHEIO`,
  `NÃO FOI POSSÍVEL SOLTAR`;
- pausa bloqueando G/E/1/2/3/R;
- sistema de interação da Etapa 7, HUD (mesma barra, mesmos slots, mesmo
  painel de aviso), arquitetura modular (`shared/` ↔ `players/` ↔ `items/`);
- valores de stamina, física do jogador, velocidades e balanceamento;
- ação `inventory_drop` no InputMap (G), sem leitura de tecla no código.

## 4. Testes

### 4.1 Novo teste de regressão (`tools/ci/drop_obstacle_test.gd`)

Roda na cena real e, para cada drop, mede com consultas próprias (sem reusar as
funções do `SpaceProbe`):

- **apoio**: grade 3×3 de raios sobre a pegada, exigindo 100% na mesma
  superfície;
- **espaço**: consulta de forma da caixa do item, ignorando o próprio item e o
  jogador, exigindo zero sobreposições;
- **piso**: raio sob a base, para detectar afundamento;
- **estabilidade**: 45 frames depois do drop, deslocamento máximo de 6 cm;
- **coleta**: foco pelo olhar, tecla E, item sai do mundo e entra no inventário.

Casos cobertos:

| Caso | O que verifica |
| --- | --- |
| Chão aberto | drop normal e recolhimento |
| Sobre a caixa | item **funciona** no topo da caixa (exigência do pedido) |
| Ao lado da caixa | item no piso, fora do colisor da caixa |
| Ao lado do pilar | item no piso, sem encostar no pilar |
| Ao lado da parede | item no piso, sem encostar na parede |
| Espaço insuficiente | `SEM ESPAÇO PARA SOLTAR`, item mantido, nada criado |
| Drops repetidos | 3 drops seguidos perto de caixa/pilar, nenhum desaparece |
| Itens A, B, C e D | 4 itens soltos ao mesmo tempo, todos recuperáveis |
| Inventário cheio | item continua no chão e nenhum item é removido |
| Pausa | G/R/E bloqueados com item solto no chão |

O passo roda em Linux (`TESTE 1d`) e Windows (`TESTE W2d`).

### 4.2 Fumaça

O grupo `[17]` do `smoke_test.gd` ganhou checagens de que a correção continua no
código: `_support_ok` e `confirm_placement` no `SpaceProbe`, a chamada de
confirmação no `ItemDropper`, a trava de rotação no item e a existência deste
documento e do novo teste.

### 4.3 Suíte existente

`smoke_test.gd`, `ui_flow_test.gd` e `movement_test.gd` (todos os grupos,
inclusive o `[24]` de drop) continuam rodando **sem mudança de expectativa**,
exceto a versão do projeto (0.9.0 → 0.9.1), que é o único número alterado.

## 5. Resultados

Run **[39516840747](https://github.com/EtecStudy/BLACKSITE/actions/runs/39516840747)** —
os dois jobs passaram (Linux e Windows), todos os passos verdes.

| Verificação | Linux | Windows |
| --- | --- | --- |
| Fumaça | 356/356 | 356/356 |
| Fluxo de interface | 53/53 | 53/53 |
| Controlador + inventário + drop | 586/586 | 586/586 |
| **Drop junto a obstáculos** | **156/156** | **156/156** |
| Captura renderizada do drop | `DROP VISUAL OK` | — |

Resultado observado nos casos novos (logs do run):

- chão aberto: item no piso, apoio 100%, zero colisões, recolhido com E;
- **sobre a caixa**: item no topo (y=1,020), centralizado em X, apoio 100%;
- ao lado da caixa: piso em z=1,143, fora da caixa;
- ao lado do pilar: piso em z=−5,336, fora do pilar;
- ao lado da parede: piso em x=−11,336, fora da parede;
- espaço insuficiente: `SEM ESPAÇO PARA SOLTAR`, item mantido, nada criado;
- drops repetidos: 3 de 3 no mundo, nenhum desapareceu, todos recolhidos;
- itens A, B, C e D: 4 no mundo ao mesmo tempo, todos recuperáveis;
- inventário cheio com item no chão: nada removido do mundo;
- pausa: G, E, 1/2/3 e R bloqueados, item intacto depois de retomar.

| Build | Valor |
| --- | --- |
| `.exe` | `FileVersion 0.9.1.0`, `ProductName=Black Sight`, executado sem janela e com janela no CI |
| `.pck` | Godot 4.7.2, formato 4, ~1,4 MB |
| ZIP publicado | `BlackSight-Etapa9-Drop-Fix-Windows-x86_64.zip` — 40.686.282 bytes |
| SHA-256 do ZIP | `52221c8fe68f02cd5b8c164e07fc81211af33916bb3d6dd08fc169a274a0d473` |

O tamanho e o SHA-256 são os do asset da release `v0.9.1-etapa9-drop-fix`,
conferidos na API do GitHub (`digest` do arquivo), e coincidem com o
`zip_sha256` calculado no job Windows.

O teste automatizado **não** substitui o teste manual do usuário.

## 6. Arquivos

### Criados

| Arquivo | Papel |
| --- | --- |
| `tools/ci/drop_obstacle_test.gd` | regressão do drop junto a obstáculos |
| `tools/ci/drop_obstacle_test.tscn` | cena do teste |
| `docs/ETAPA-9-CORRECAO.md` | este documento |
| `docs/RELEASE_NOTES_ETAPA9_FIX.md` | notas da release v0.9.1 |

### Modificados

| Arquivo | Mudança |
| --- | --- |
| `shared/mapping/space_probe.gd` | apoio 3×3, busca sobre o topo, raio com iteração, `confirm_placement` |
| `players/scripts/inventory/item_dropper.gd` | confirmação pós-instanciação, descarte limpo, checagem da posição real |
| `items/scenes/world_item.tscn` | rotação travada do corpo físico |
| `tools/ci/smoke_test.gd` | checagens da correção no grupo `[17]`; versão 0.9.1 |
| `.github/workflows/build.yml` | teste 1d/W2d, versão, ZIP, tag e notas da v0.9.1 |
| `project.godot`, `shared/autoload/app_info.gd`, `export_presets.cfg` | versão 0.9.1 |
| `README.md` | link da v0.9.1 e nota da correção |

## 7. Limitações que continuam

- Representação do item continua genérica (cubo + base + etiqueta), sem modelo
  por item.
- O item solto não é persistido entre sessões (não há save de partida).
- A busca de posição é local (até 0,4 m sobre o topo do objeto); se não houver
  área apoiada ali, o drop é cancelado — não existe "procurar em outro canto da
  sala".
- Superfícies acima de ~2 m do pés do jogador não são consideradas piso de
  drop, por escolha (o raio parte de 2 m acima dos pés para não confundir teto
  com chão).
- Não há arremesso, som, animação de mão nem física avançada.
- A remoção provisória com R continua existindo.
- A Etapa 10 (transferência entre jogadores) continua pulada e não foi
  iniciada.
- O resumo automático de testes da release lista as três suítes que já
  existiam; a linha do `drop_obstacle_test` foi acrescentada à mão nesta
  release. A próxima etapa deve incluir o novo log no passo
  `Resumo dos testes e do pacote (Windows)` do workflow.
