extends Node3D
## Sessão da demonstração do sistema modular de salas (Etapa 11 → revisão).
##
## Orquestra apenas o necessário para **caminhar pelo cenário**:
## - instancia a geometria (`maps/scenes/modular_demo_room.tscn`) e o jogador
##   existente (`players/scenes/player.tscn`), sem substituir nenhum dos dois;
## - posiciona o jogador no `Spawn` do cenário e captura o mouse;
## - liga a HUD (stamina, inventário, interação) ao mesmo jogador das outras
##   cenas — a HUD não sabe que esta cena é uma demonstração;
## - `ESC` abre/fecha o menu de pausa (CONTINUAR, CONFIGURAÇÕES, VOLTAR AO
##   MENU), como na cena de teste de movimentação; `F11` alterna a tela cheia.
##
## Corrigido na revisão da Etapa 11:
## - o `ESC` **não** troca de cena dentro do manipulador de entrada. Ele abre a
##   pausa; a troca de cena só acontece no botão VOLTAR AO MENU e é agendada
##   com `change_scene_to_file.call_deferred`, fora do processamento do evento;
## - a pausa para o jogador, solta o mouse e desliga interação/inventário;
## - retomar restaura o movimento e descarta qualquer estado de corrida herdado
##   da pausa (`reset_sprint_state`).
##
## Nada de regras de jogo mora aqui: não há criatura, itens ou objetivos.

const TITLE_SCENE: String = "res://ui/scenes/title_screen.tscn"
const SETTINGS_SCENE: String = "res://ui/scenes/settings_screen.tscn"
const SPAWN_OFFSET := Vector3(0.0, 0.05, 0.0)
const HINT_DURATION: float = 12.0

@onready var _player: PlayerController = $Player
@onready var _room: Node3D = $ModularDemo
@onready var _spawn: Marker3D = $ModularDemo/Spawn
@onready var _hud: PlayerHud = %PlayerHud
@onready var _hint: Label = %HintLabel
@onready var _pause_root: Control = %PauseRoot
@onready var _continue_button: Button = %ContinueButton
@onready var _settings_button: Button = %SettingsButton
@onready var _menu_button: Button = %MenuButton
@onready var _settings_layer: CanvasLayer = $SettingsLayer

var _paused: bool = false
var _leaving: bool = false
var _settings_screen: SettingsScreen = null
var _settings: Node = null


func _ready() -> void:
	_settings = get_node_or_null("/root/GameSettings")
	_pause_root.visible = false
	_continue_button.pressed.connect(resume_session)
	_settings_button.pressed.connect(open_settings)
	_menu_button.pressed.connect(return_to_menu)
	if _hud != null:
		_hud.bind_player(_player)
		_hud.bind_interaction(_player.get_interaction_detector())
		_hud.bind_inventory(_player.get_inventory())
		_hud.bind_drop_input(_player.get_item_dropper())
	_place_player_at_spawn()
	_capture_mouse(true)
	_fade_hint_later()
	print("[Black Sight] Cena modular carregada — %d módulos no cenário" % count_modules())


func _place_player_at_spawn() -> void:
	if _player == null or _spawn == null:
		return
	_player.global_position = _spawn.global_position + SPAWN_OFFSET
	_player.velocity = Vector3.ZERO
	_player.set_look(_spawn.rotation.y, 0.0)


## Quantos módulos diretos o cenário instancia (leitura para testes/logs).
func count_modules() -> int:
	if _room == null:
		return 0
	var count: int = 0
	for child: Node in _room.get_children():
		if child is Node3D:
			count += 1
	return count


## Jogador da demonstração (o mesmo controlador das outras cenas).
func get_player() -> PlayerController:
	return _player


## Raiz da geometria modular instanciada.
func get_demo_room() -> Node3D:
	return _room


## HUD ligada ao jogador.
func get_hud() -> PlayerHud:
	return _hud


## Abre a pausa: libera o cursor e para de responder ao mouse/WASD.
func pause_session() -> void:
	if _paused or _leaving:
		return
	_paused = true
	_pause_root.visible = true
	_player.movement_enabled = false
	_set_interaction_enabled(false)
	_set_inventory_input_enabled(false)
	_player.velocity.x = 0.0
	_player.velocity.z = 0.0
	_capture_mouse(false)
	_continue_button.grab_focus()
	print("[Black Sight] Demonstração modular pausada")


## Fecha a pausa, captura o mouse e restaura o movimento sem estados herdados.
func resume_session() -> void:
	if not _paused or _leaving or _settings_screen != null:
		return
	_paused = false
	_pause_root.visible = false
	_player.movement_enabled = true
	_player.reset_sprint_state()
	_set_interaction_enabled(true)
	_set_inventory_input_enabled(true)
	_capture_mouse(true)
	print("[Black Sight] Demonstração modular retomada")


func is_paused() -> bool:
	return _paused


func _set_interaction_enabled(value: bool) -> void:
	var detector: InteractionDetector = _player.get_interaction_detector()
	if detector != null:
		detector.set_detection_enabled(value)


func _set_inventory_input_enabled(value: bool) -> void:
	var inventory_input: InventoryInput = _player.get_inventory_input()
	if inventory_input != null:
		inventory_input.set_input_enabled(value)


## Abre a tela de configurações existente por cima da demonstração pausada.
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
##
## A troca de cena é agendada: nunca acontece no meio do processamento do
## evento de teclado (causa do travamento relatado ao apertar ESC na versão
## anterior, que chamava `change_scene_to_file` de dentro de `_unhandled_input`
## enquanto o mouse estava capturado).
func return_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	_capture_mouse(false)
	get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)
	print("[Black Sight] Demonstração modular encerrada — voltando ao menu")


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
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _capture_mouse(captured: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	if captured and _player != null:
		_player.reset_look_input()


func _fade_hint_later() -> void:
	if _hint == null:
		return
	var timer: SceneTreeTimer = get_tree().create_timer(HINT_DURATION)
	timer.timeout.connect(func() -> void:
		if not is_inside_tree() or _hint == null:
			return
		var tween: Tween = create_tween()
		tween.tween_property(_hint, "modulate:a", 0.0, 0.9)
	)
