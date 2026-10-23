# Módulo `audio/`

**Responsabilidade:** áudio ambiente, efeitos sonoros e comunicação por voz —
reprodução, mistura de buses e priorização de sons.

**Estado atual (Etapa 3):** layout de buses criado e aplicado, com volumes
controlados pela tela de configurações. Existe **apenas** o feedback sonoro da
interface; música, ambiente e voz ainda não têm sons.

| Caminho | O que é |
| --- | --- |
| `audio/default_bus_layout.tres` | `Master` → `Music`, `SFX`, `Ambience`, `Voice` |
| `audio/scripts/ui_audio.gd` | Autoload `UiAudio` — clique e confirmação da interface |
| `audio/assets/sfx/ui_click.wav` | Clique de botão (sintetizado) |
| `audio/assets/sfx/ui_confirm.wav` | Confirmação de aplicar (sintetizado) |

Os dois WAV são gerados por `tools/generate_ui_sounds.py` (biblioteca padrão do
Python, sem dependências externas).

## O que entra aqui

| Tipo | Local | Exemplos |
| --- | --- | --- |
| Scripts | `audio/scripts/` | `ui_audio.gd` (existe), `audio_director.gd`, `footstep_player.gd` |
| Cenas | `audio/scenes/` | `ambience.tscn`, `music_player.tscn` |
| Assets próprios | `audio/assets/` | `sfx/` (existe), `ambience/`, `music/`, `voice/` |
| Buses | `audio/default_bus_layout.tres` | layout atual |

## Buses e volumes

O volume de cada bus vem de `GameSettings` (seção `audio`), em percentual, e é
convertido para decibéis por `shared/settings/audio_applier.gd`. Em `0%` o bus é
silenciado.

| Bus | Volume padrão | Situação nesta etapa |
| --- | --- | --- |
| `Master` | 80% | soma de todos |
| `Music` | 60% | sem trilha sonora ainda |
| `SFX` | 80% | sons da interface |
| `Ambience` | 70% | sem sons de ambiente ainda |
| `Voice` | — | reservado para o multiplayer |

## Regras do módulo

- Só depende de `shared/`.
- Reprodução sempre por `AudioStreamPlayer`/`AudioStreamPlayer3D`; nunca por
  chamadas globais espalhadas em outros módulos.
- Voz (comunicação entre jogadores) é tratada aqui, mas depende de rede —
  implementação em etapa posterior, junto do multiplayer.

## Próximas etapas

1. `AudioDirector` como autoload leve, se necessário.
2. Sons posicionais nas próprias cenas (mapa, criatura), referenciando streams
   de `audio/assets/`.
3. Trilha e ambiência próprias para os buses `Music` e `Ambience`.

## Dependências

`audio/` → `shared/` (permitido). Qualquer outra seta é proibida.
