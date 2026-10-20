extends Node3D
## Sessão de teste da movimentação (Etapa 4 → Etapa 5).
##
## Responsabilidades — apenas **orquestração** de `match/`:
## - montar a cena de teste (`maps/scenes/test_room.tscn`) com o jogador
##   (`players/scenes/player.tscn`) no ponto de nascimento;
## - capturar o mouse ao entrar e liberar no Escape;
## - oferecer **CONTINUAR**, **CONFIGURAÇÕES** e **VOLTAR AO MENU**;
## - abrir a tela de configurações existente (`ui/`) como sobreposição, sem
##   trocar de cena, para não perder a posição/estado do jogador;
## - manter F11 (tela cheia) funcionando, como nas telas anteriores.
##
## Nenhuma regra de movimentação mora aqui: ela está em `PlayerController`.
## Nenhum valor de configuração é lido aqui: o jogador lê `GameSettings`.

const TITLE_SCENE: String = "res://ui/scenes/title_screen.tscn"
const SETTINGS_SCENE: String = "res://ui/scenes/settings_screen.tscn"
const HINT_DURATION: float = 7.0
const SPAWN_OFFSET := Vector3(0.0, 0.05, 0.0)

@onready var _player: PlayerController = $Player
@onready var _spawn: Marker3D = $TestRoom/Spawn
@onready var _pause_root: Control = %PauseRoot
@onready var _hint_label: Label = %HintLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _settings_button: Button = %SettingsButton
@onready var _menu_button: Button = %MenuButton
@onready var _settings_layer: CanvasLayer = $SettingsLayer

var _paused: bool = false
var _leaving: bool = false
var _settings_screen: SettingsScreen = null
var _settings


func _ready() -> void:
	_settings = get_node_or_null("/root/GameSettings")
	_pause_root.visible = false
	_continue_button.pressed.connect(resume_session)
	_settings_button.pressed.connect(open_settings)
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
	# Para na hora: sem deslize residual enquanto o menu está aberto.
	_player.velocity.x = 0.0
	_player.velocity.z = 0.0
	_capture_mouse(false)
	_continue_button.grab_focus()


## Fecha a pausa e captura o mouse novamente.
func resume_session() -> void:
	if not _paused or _leaving or _settings_screen != null:
		return
	_paused = false
	_pause_root.visible = false
	_player.movement_enabled = true
	_capture_mouse(true)


## Abre a tela de configurações existente por cima da partida pausada.
## Não troca de cena, não recria o jogador e não perde posição/estado.
func open_settings() -> void:
	if _settings_screen != null or _leaving:
		return
	if not _paused:
		pause_session()
	var packed: PackedScene = load(SETTINGS_SCENE) as PackedScene
	if packed == null:
		push_error("Não foi possível carregar %s" % SETTINGS_SCENE)
		return
	var screen: SettingsScreen = packed.instantiate() as SettingsScreen
	if screen == null:
		return
	screen.set_embedded(true)
	screen.back_requested.connect(close_settings)
	_settings_layer.add_child(screen)
	_settings_screen = screen
	_pause_root.visible = false
	_capture_mouse(false)
	print("[Black Sight] Configurações abertas durante a pausa")


## Fecha as configurações e devolve o controle ao menu de pausa.
func close_settings() -> void:
	if _settings_screen == null:
		return
	var screen: SettingsScreen = _settings_screen
	_settings_screen = null
	screen.queue_free()
	if not _leaving:
		_pause_root.visible = true
		_continue_button.grab_focus()
		_capture_mouse(false)
	print("[Black Sight] Configurações fechadas — de volta à pausa")


func is_settings_open() -> bool:
	return _settings_screen != null


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
	# Com as configurações abertas, o Esc/F11 pertencem à tela de configurações.
	if _settings_screen != null:
		return

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
	if captured and _player != null:
		_player.reset_look_input()


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
