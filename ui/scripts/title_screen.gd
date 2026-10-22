extends Control
## Tela inicial do Black Sight.
##
## Etapa 1: identidade visual, animações, saída e F11.
## Etapa 3: botão CONFIGURAÇÕES e F11 integrado às configurações salvas.
## Etapa 4: botão TESTAR MOVIMENTAÇÃO (cena de teste do controlador FPS).
##
## Limpeza das salas (0.13.2): os botões SALA-PILOTO VISUAL, PRIMEIRO ANDAR e
## DEMONSTRAR MÓDULOS foram removidos junto com as cenas de demonstração.
## Resta apenas a sala de movimentação como ambiente de teste.
##
## Nenhuma mecânica de jogo (jogador, mapa, inventário, criaturas, etc.)
## pertence a esta tela.

const SETTINGS_SCENE: String = "res://ui/scenes/settings_screen.tscn"
## Navegação por caminho: a UI não importa classes de gameplay, apenas troca de cena.
const MOVEMENT_TEST_SCENE: String = "res://match/scenes/movement_test.tscn"
## Sala de Exibição do Kit Visual (showroom temporário de avaliação).
const EXHIBITION_ROOM_SCENE: String = "res://match/scenes/exhibition_room.tscn"

const FADE_IN_DURATION: float = 1.3
const FADE_OUT_DURATION: float = 0.55
const EMBLEM_BREATH_DURATION: float = 3.2

@onready var _fade: ColorRect = %Fade
@onready var _content: VBoxContainer = %Content
@onready var _emblem: TextureRect = %Emblem
@onready var _build_label: Label = %BuildLabel
@onready var _start_button: Button = %StartButton
@onready var _test_button: Button = %TestMovementButton
@onready var _exhibition_button: Button = %ExhibitionRoomButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton

var _quitting: bool = false
var _settings
var _ui_audio


func _ready() -> void:
	_settings = get_node_or_null("/root/GameSettings")
	_ui_audio = get_node_or_null("/root/UiAudio")

	_build_label.text = "F11 · TELA CHEIA      %s      %s" % [
		AppInfo.version_label(), AppInfo.engine_label()
	]
	_start_button.disabled = true
	_test_button.pressed.connect(_on_test_movement_pressed)
	_exhibition_button.pressed.connect(_on_exhibition_room_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	print("[Black Sight] Tela inicial carregada — %s · %s" % [
		AppInfo.version_label(), AppInfo.engine_label()
	])
	_play_intro()


## Fade de entrada + respiração lenta do emblema.
func _play_intro() -> void:
	_fade.color.a = 1.0
	_content.modulate.a = 0.0

	var intro: Tween = create_tween()
	intro.set_parallel(true)
	intro.tween_property(_fade, "color:a", 0.0, FADE_IN_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	intro.tween_property(_content, "modulate:a", 1.0, FADE_IN_DURATION * 0.85) \
		.set_delay(0.25)

	var breath: Tween = create_tween().set_loops()
	breath.tween_property(_emblem, "modulate:a", 0.55, EMBLEM_BREATH_DURATION) \
		.set_trans(Tween.TRANS_SINE)
	breath.tween_property(_emblem, "modulate:a", 1.0, EMBLEM_BREATH_DURATION) \
		.set_trans(Tween.TRANS_SINE)

	_quit_button.grab_focus()


func _on_test_movement_pressed() -> void:
	_play_click()
	get_tree().change_scene_to_file(MOVEMENT_TEST_SCENE)


func _on_exhibition_room_pressed() -> void:
	_play_click()
	get_tree().change_scene_to_file(EXHIBITION_ROOM_SCENE)



func _on_settings_pressed() -> void:
	_play_click()
	get_tree().change_scene_to_file(SETTINGS_SCENE)


func _on_quit_pressed() -> void:
	if _quitting:
		return
	_quitting = true
	_quit_button.disabled = true
	_play_click()

	var outro: Tween = create_tween()
	outro.tween_property(_fade, "color:a", 1.0, FADE_OUT_DURATION)
	outro.tween_callback(func() -> void: get_tree().quit())


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F11:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()


## F11 alterna janela ↔ tela cheia e grava a preferência (Etapa 3).
func _toggle_fullscreen() -> void:
	if _settings != null:
		_settings.toggle_fullscreen()
		return

	# Reserva: funciona mesmo sem o autoload GameSettings (testes isolados).
	var current_mode: int = DisplayServer.window_get_mode()
	var is_fullscreen: bool = (
		current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN
	)


func _play_click() -> void:
	if _ui_audio != null:
		_ui_audio.play_click()
