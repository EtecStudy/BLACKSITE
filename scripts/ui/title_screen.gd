extends Control
## Cena inicial do Black Sight (Etapa 1).
##
## Responsabilidades desta etapa:
## - apresentar a identidade visual do projeto;
## - exibir o estado do build (versão e engine);
## - permitir sair do jogo e alternar tela cheia (F11).
##
## Nenhuma mecânica de jogo (jogador, mapa, inventário, criaturas, etc.)
## pertence a esta etapa.

const FADE_IN_DURATION: float = 1.3
const FADE_OUT_DURATION: float = 0.55
const EMBLEM_BREATH_DURATION: float = 3.2

@onready var _fade: ColorRect = %Fade
@onready var _content: VBoxContainer = %Content
@onready var _emblem: TextureRect = %Emblem
@onready var _build_label: Label = %BuildLabel
@onready var _start_button: Button = %StartButton
@onready var _quit_button: Button = %QuitButton

var _quitting: bool = false


func _ready() -> void:
	_build_label.text = "F11 · TELA CHEIA      %s      %s" % [
		AppInfo.version_label(), AppInfo.engine_label()
	]
	_start_button.disabled = true
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


func _on_quit_pressed() -> void:
	if _quitting:
		return
	_quitting = true
	_quit_button.disabled = true

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


func _toggle_fullscreen() -> void:
	var current_mode: int = DisplayServer.window_get_mode()
	var is_fullscreen: bool = (
		current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN
	)
