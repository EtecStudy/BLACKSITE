extends Node3D
## Sessão de teste da movimentação (Etapa 4).
##
## Responsabilidades — apenas **orquestração** de `match/`:
## - montar a cena de teste (`maps/scenes/test_room.tscn`) com o jogador
##   (`players/scenes/player.tscn`) no ponto de nascimento;
## - capturar o mouse ao entrar e liberar no Escape;
## - oferecer **CONTINUAR** e **VOLTAR AO MENU** (ninguém fica preso na cena);
## - manter F11 (tela cheia) funcionando, como nas telas anteriores.
##
## Nenhuma regra de movimentação mora aqui: ela está em `PlayerController`.
## Nenhum valor de configuração é lido aqui: o jogador lê `GameSettings`.

const TITLE_SCENE: String = "res://ui/scenes/title_screen.tscn"
const HINT_DURATION: float = 7.0
const SPAWN_OFFSET := Vector3(0.0, 0.05, 0.0)

@onready var _player: PlayerController = $Player
@onready var _spawn: Marker3D = $TestRoom/Spawn
@onready var _pause_root: Control = %PauseRoot
@onready var _hint_label: Label = %HintLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _menu_button: Button = %MenuButton

var _paused: bool = false
var _leaving: bool = false
var _settings


func _ready() -> void:
	_settings = get_node_or_null("/root/GameSettings")
	_pause_root.visible = false
	_continue_button.pressed.connect(resume_session)
	_menu_button.pressed.connect(return_to_menu)
	_place_player_at_spawn()
	_capture_mouse(true)
	_fade_hint_later()
	print("[Black Sight] Cena de teste carregada — controlador FPS ativo")


func _place_player_at_spawn() -> void:
	if _player == null or _spawn == null:
		return
	_player.global_position = _spawn.global_position + SPAWN_OFFSET
	_player.velocity = Vector3.ZERO
	_player.set_yaw(_spawn.rotation.y)


## Abre a pausa: libera o cursor e para de responder ao mouse/WASD.
func pause_session() -> void:
	if _paused or _leaving:
		return
	_paused = true
	_pause_root.visible = true
	_player.movement_enabled = false
	_capture_mouse(false)
	_continue_button.grab_focus()


## Fecha a pausa e captura o mouse novamente.
func resume_session() -> void:
	if not _paused or _leaving:
		return
	_paused = false
	_pause_root.visible = false
	_player.movement_enabled = true
	_capture_mouse(true)


## Volta ao menu inicial (sempre com o cursor visível).
func return_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	_capture_mouse(false)
	get_tree().change_scene_to_file(TITLE_SCENE)


func is_paused() -> bool:
	return _paused


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if event.is_action_pressed("release_mouse"):
		if _paused:
			resume_session()
		else:
			pause_session()
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_F11:
		if _settings != null:
			_settings.toggle_fullscreen()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	# Garante que o cursor volta ao sair da cena por qualquer caminho.
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _capture_mouse(captured: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = (
		Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	)


func _fade_hint_later() -> void:
	if _hint_label == null:
		return
	var timer: SceneTreeTimer = get_tree().create_timer(HINT_DURATION)
	timer.timeout.connect(func() -> void:
		if not is_inside_tree() or _hint_label == null:
			return
		var tween: Tween = create_tween()
		tween.tween_property(_hint_label, "modulate:a", 0.0, 0.8)
	)
