extends Node3D
## Sessão da demonstração do sistema modular de salas (Etapa 11).
##
## Orquestra apenas o necessário para **caminhar pelo cenário**:
## - instancia a geometria (`maps/scenes/modular_demo_room.tscn`) e o jogador
##   existente (`players/scenes/player.tscn`), sem substituir nenhum dos dois;
## - posiciona o jogador no `Spawn` do cenário e captura o mouse;
## - liga a HUD (stamina, inventário, interação) ao mesmo jogador das outras
##   cenas — a HUD não sabe que esta cena é uma demonstração;
## - `ESC` volta ao menu inicial, `F11` alterna a tela cheia (Etapa 3).
##
## Nada de regras de jogo mora aqui: não há pausa com menu, criatura, itens ou
## objetivos. Esta cena existe para validar encaixe, colisões e a escada.

const TITLE_SCENE: String = "res://ui/scenes/title_screen.tscn"
const SPAWN_OFFSET := Vector3(0.0, 0.05, 0.0)
const HINT_DURATION: float = 11.0

@onready var _player: PlayerController = $Player
@onready var _room: Node3D = $ModularDemo
@onready var _spawn: Marker3D = $ModularDemo/Spawn
@onready var _hud: PlayerHud = %PlayerHud
@onready var _hint: Label = %HintLabel

var _leaving: bool = false
var _settings: Node = null


func _ready() -> void:
	_settings = get_node_or_null("/root/GameSettings")
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
	_player.set_yaw(_spawn.rotation.y)


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


## Volta ao menu inicial (sempre com o cursor visível).
func return_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	_capture_mouse(false)
	get_tree().change_scene_to_file(TITLE_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if event.is_action_pressed("release_mouse"):
		return_to_menu()
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
