# Módulo `audio/`

**Responsabilidade:** áudio ambiente, efeitos sonoros e comunicação por voz —
reprodução, mistura de buses e priorização de sons.

**Estado atual (Etapa 2):** apenas estrutura/documentação. Nenhum arquivo de
áudio, nenhum autoload de áudio e nenhum barramento customizado foi criado. O
projeto continua com o bus padrão (`Master`) do Godot.

## O que entra aqui

| Tipo | Local | Exemplos |
| --- | --- | --- |
| Scripts | `audio/scripts/` | `audio_director.gd`, `footstep_player.gd` |
| Cenas | `audio/scenes/` | `ambience.tscn`, `music_player.tscn` |
| Assets próprios | `audio/assets/` | `ambience/`, `sfx/`, `voice/` |
| Buses | `audio/default_bus_layout.tres` | quando a etapa de áudio começar |

## Regras do módulo

- Só depende de `shared/`.
- Buses previstos: `Master` → `Music`, `SFX`, `Ambience`, `Voice`. O layout
  **não** foi criado nesta etapa para não antecipar sistemas.
- Reprodução sempre por `AudioStreamPlayer`/`AudioStreamPlayer3D`; nunca por
  chamadas globais espalhadas em outros módulos.
- Voz (comunicação entre jogadores) é tratada aqui, mas depende de rede —
  implementação em etapa posterior, junto do multiplayer.

## Como será usado nas próximas etapas

1. Criar o layout de buses e aplicar volumes.
2. `AudioDirector` como autoload leve, se necessário.
3. Sons posicionais nas próprias cenas (mapa, criatura), referenciando streams
   de `audio/assets/`.

## Dependências

`audio/` → `shared/` (permitido). Qualquer outra seta é proibida.
