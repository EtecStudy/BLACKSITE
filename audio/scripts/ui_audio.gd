extends Node
## Autoload `UiAudio` — feedback sonoro curto da interface (Etapa 3).
##
## Escopo intencionalmente mínimo: apenas dois sons de UI, no bus `SFX`.
## Serve para que os volumes de Áudio tenham efeito audível imediato enquanto
## o jogo ainda não possui áudio de gameplay.
##
## Áudio ambiente, música e voz pertencem a etapas posteriores.

const CLICK_STREAM: AudioStream = preload("res://audio/assets/sfx/ui_click.wav")
const CONFIRM_STREAM: AudioStream = preload("res://audio/assets/sfx/ui_confirm.wav")

const SFX_BUS: String = "SFX"
const CLICK_VOLUME_DB: float = -10.0
const CONFIRM_VOLUME_DB: float = -8.0

var _click_player: AudioStreamPlayer
var _confirm_player: AudioStreamPlayer


func _ready() -> void:
	_click_player = _make_player(CLICK_STREAM, CLICK_VOLUME_DB)
	_confirm_player = _make_player(CONFIRM_STREAM, CONFIRM_VOLUME_DB)


## Clique de botão comum.
func play_click() -> void:
	_play(_click_player)


## Confirmação (aplicar configurações, por exemplo).
func play_confirm() -> void:
	_play(_confirm_player)


func _make_player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SFX_BUS
	player.volume_db = volume_db
	add_child(player)
	return player


func _play(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if AudioServer.get_bus_index(SFX_BUS) < 0:
		return
	player.play()
