# Configurações do Black Sight (Etapa 3)

Documento de referência das configurações do jogo: onde ficam, como são
validadas, quais arquivos cuidam de cada parte e como acrescentar um novo
parâmetro sem quebrar arquivos já salvos.

## 1. Onde as configurações são gravadas

| Item | Valor |
| --- | --- |
| Caminho na Godot | `user://settings.cfg` |
| Windows | `%APPDATA%\BlackSight\settings.cfg` |
| Linux | `~/.local/share/BlackSight/settings.cfg` |
| Formato | `ConfigFile` (texto `chave = valor`, editável à mão) |

O nome da pasta vem de `config/use_custom_user_dir=true` e
`config/custom_user_dir_name="BlackSight"` no `project.godot`.

**Nunca** é gravado dentro da pasta de instalação do jogo: o ZIP extraído pode
estar em `C:\Program Files` (sem permissão de escrita) e cada usuário do
Windows tem a sua própria pasta em `%APPDATA%`.

Se o arquivo não existir, o jogo abre com os valores padrão e cria o arquivo na
primeira execução. Se existir mas estiver corrompido, o jogo **também abre**:
a leitura falha, os padrões são usados e um aviso vai para o log. Apagar o
arquivo é a forma mais simples de "resetar" tudo por fora do jogo.

## 2. Estrutura do arquivo

```ini
[meta]
version=1
game="Black Sight"

[controls]
mouse_sensitivity_x=1.0
mouse_sensitivity_y=1.0
invert_y=false

[audio]
master_volume=80
sfx_volume=80
ambience_volume=70
music_volume=60

[video]
window_mode=0
resolution_x=1600
resolution_y=900
vsync=true
```

`window_mode`: `0` = janela, `1` = janela maximizada, `2` = tela cheia.

## 3. Chaves, limites e padrões

| Seção | Chave | Padrão | Limites / observações |
| --- | --- | --- | --- |
| `controls` | `mouse_sensitivity_x` | `1.0` | `0.1` a `5.0`, passo `0.05` |
| `controls` | `mouse_sensitivity_y` | `1.0` | `0.1` a `5.0`, passo `0.05` |
| `controls` | `invert_y` | `false` | inverte o eixo vertical do olhar |
| `audio` | `master_volume` | `80` | `0` a `100` (%) |
| `audio` | `sfx_volume` | `80` | `0` a `100` (%) |
| `audio` | `ambience_volume` | `70` | `0` a `100` (%) |
| `audio` | `music_volume` | `60` | `0` a `100` (%) |
| `video` | `window_mode` | `0` (janela) | `0` janela · `1` maximizada · `2` tela cheia |
| `video` | `resolution_x` | `1600` | `1024` a `7680` |
| `video` | `resolution_y` | `900` | `576` a `4320` |
| `video` | `vsync` | `true` | depende do driver de vídeo |

Os limites ficam em `shared/settings/settings_schema.gd`, que é a **fonte única
da verdade**. A tela não redefine limites: ela lê as constantes do esquema.

## 4. Quais arquivos cuidam de cada parte

| Arquivo | Responsabilidade |
| --- | --- |
| `shared/settings/settings_schema.gd` | Estrutura, padrões, limites e validação (`sanitize`) |
| `shared/settings/game_settings.gd` | Autoload `GameSettings`: carrega, aplica e salva o arquivo |
| `shared/settings/audio_applier.gd` | Converte percentual em dB e aplica nos buses |
| `shared/settings/video_applier.gd` | Modo de janela, resolução, VSync e limites de segurança |
| `audio/default_bus_layout.tres` | Buses `Master`, `Music`, `SFX`, `Ambience`, `Voice` |
| `ui/scenes/settings_screen.tscn` | Tela de configurações com abas |
| `ui/scripts/settings_screen.gd` | Orquestra as seções, aplica, restaura e volta ao menu |
| `ui/scripts/settings/controls_section.gd` | Seção CONTROLES |
| `ui/scripts/settings/audio_section.gd` | Seção ÁUDIO |
| `ui/scripts/settings/video_section.gd` | Seção VÍDEO |

O gerenciador **não** conhece botões, e a interface **não** conhece
`ConfigFile`: a tela monta uma cópia de trabalho (`_staged`), e o autoload é o
único que lê/grava o disco.

### Fluxo de uma alteração

```
tela de configurações          autoload GameSettings              motor
──────────────────────         ─────────────────────              ─────
slider move  ───────────────►  preview_audio() (só áudio)  ────►  AudioServer
APLICAR      ───────────────►  sanitize() → apply()
                                ├─ AudioApplier.apply()    ────►  AudioServer
                                ├─ VideoApplier.apply()    ────►  DisplayServer
                                └─ ConfigFile.save(user://settings.cfg)
VOLTAR       ───────────────►  preview_audio(valores salvos)  (descarta o resto)
```

O áudio é pré-visualizado ao vivo porque o ouvido precisa da resposta imediata;
vídeo **só** muda ao clicar em APLICAR, para ninguém perder a janela no meio de
um ajuste.

## 5. Segurança de vídeo (nunca prender o usuário)

- A lista de resoluções é filtrada pelo tamanho útil do monitor
  (`DisplayServer.screen_get_usable_rect`), então não aparece opção maior que a
  tela.
- Qualquer valor vindo do arquivo é limitado entre `1024×576` e o tamanho útil
  da tela atual antes de ser aplicado.
- Em tela cheia a proporção é preservada pelo stretch `canvas_items` com
  aspecto `keep` (a imagem não deforma; sobram faixas pretas se necessário).
- `F11` continua alternando janela ↔ tela cheia em qualquer tela e grava a
  preferência.
- `RESTAURAR PADRÕES` está sempre visível na tela de configurações e não
  depende de o modo atual ser legível.

## 6. Áudio e categorias ainda sem sons

Os buses existem e os volumes são reais:

| Bus | Conteúdo atual |
| --- | --- |
| `Master` | soma de todos |
| `SFX` | cliques e confirmação da interface (`audio/assets/sfx/`) |
| `Music` | **sem trilha sonora nesta etapa** |
| `Ambience` | **sem sons de ambiente nesta etapa** |
| `Voice` | **sem voz nesta etapa** (depende de multiplayer) |

Mover os sliders de música/ambiente/voz já altera o bus correspondente, mas o
efeito só será audível quando esses sons existirem. Isso está escrito na
própria tela, abaixo dos controles.

Volume em `0%` silencia o bus (`mute`) em vez de aplicar `-inf dB`.

## 7. Controles

A tela mostra os controles do jogador (WASD, mouse, Shift, E, F, Esc). Na
Etapa 4, **WASD e mouse já funcionam** na cena de teste; Shift (correr), E
(interagir), F (lanterna) e Esc (pausa do jogo) entram nas próximas etapas —
Esc já libera o cursor na cena de teste.

Sensibilidade horizontal/vertical e inversão do eixo vertical são lidas pelo
`PlayerController` (`players/scripts/player_controller.gd`) na entrada da cena
e reaplicadas sempre que o gerenciador emite `applied`. O controlador não lê
`ConfigFile` e não guarda cópia dos valores: `GameSettings` continua sendo a
fonte única.

## 8. Como acrescentar um novo parâmetro

1. **Esquema** (`settings_schema.gd`): acrescente a chave em `defaults()` e a
   validação em `sanitize()` (use `_to_float`, `_to_int`, `_to_bool` ou
   `_to_volume`). Se necessário, crie uma constante de limite.
2. **Aplicação**: use o valor em `audio_applier.gd`, `video_applier.gd` ou no
   futuro sistema que o consome (ex.: controlador do jogador).
3. **Interface**: adicione o controle na seção correspondente
   (`ui/scripts/settings/*.gd`) e devolva a chave em `read_values()`.
4. **Teste**: acrescente uma verificação em `tools/ci/smoke_test.gd`
   (saneamento) e, se for visível, em `tools/ci/ui_flow_test.gd`.

Arquivos antigos continuam válidos: chaves ausentes caem no padrão e chaves
desconhecidas são ignoradas na leitura (não são reescritas até o próximo
APLICAR).

## 9. Limitações conhecidas desta etapa

- Não há corrida, agachamento, stamina, pulo nem interação; a sensibilidade e
  a inversão vertical já afetam a câmera (Etapa 4).
- Música, ambiente e voz não têm sons; só os buses respondem.
- VSync depende do driver: em GL Compatibility alguns drivers ignoram a opção.
- O modo "janela maximizada" não guarda o tamanho anterior da janela.
- Não há controle de teclas/remap nesta etapa.
