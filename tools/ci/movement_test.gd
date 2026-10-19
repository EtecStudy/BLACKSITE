extends Node
## Teste automatizado do controlador FPS e da cena de teste (Etapa 4).
##
## Uso:
##     godot --headless --path . --fixed-fps 60 --audio-driver Dummy \
##         res://tools/ci/movement_test.tscn
##
## O teste instancia a **cena real** (`match/scenes/movement_test.tscn`) e
## verifica movimento, câmera, física, colisões e integração com as
## configurações da Etapa 3. As entradas são simuladas com `Input.action_press`,
## que é o mesmo caminho usado pelo teclado.
##
## Sai com 0 em caso de sucesso e 1 em caso de falha.

const MOVEMENT_SCENE := "res://match/scenes/movement_test.tscn"
const TEST_CONFIG := "user://test_movement_settings.cfg"

const MOVE_ACTIONS := ["move_forward", "move_back", "move_left", "move_right"]

var _scene: Node
var _player
var _settings
var _checks: int = 0
var _failures: PackedStringArray = PackedStringArray()
var _original_path: String = ""
var _original_values: Dictionary = {}


func _ready() -> void:
	print("=== Black Sight · teste do controlador FPS ===")

	_settings = get_node_or_null("/root/GameSettings")
	if _settings != null:
		_original_path = _settings.config_path
		_original_values = _settings.current()
		_settings.config_path = TEST_CONFIG
		_remove_test_file()
		_settings.apply(SettingsSchema.defaults())

	_check_input_map()
	await _start_scene()
	if _scene == null:
		_finish()
		return

	await _test_spawn_and_floor()
	await _test_directions()
	await _test_diagonal()
	await _test_relative_movement()
	await _test_idle_stability()
	await _test_look()
	await _test_pause()
	await _test_gravity()
	await _test_collisions()

	_finish()


# --- Montagem ---------------------------------------------------------------

func _check_input_map() -> void:
	print("[1] Input Map")
	var expected := {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
	}
	for action: String in expected:
		_expect(InputMap.has_action(action), "ação '%s' existe" % action)
		_expect(
			InputMap.action_get_events(action).size() > 0,
			"ação '%s' tem pelo menos uma tecla" % action
		)
		var found: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key != null and key.physical_keycode == expected[action]:
				found = true
		_expect(found, "ação '%s' vinculada a %s" % [
			action, OS.get_keycode_string(expected[action])
		])
	_expect(InputMap.has_action("release_mouse"), "ação 'release_mouse' existe (Escape)")


func _start_scene() -> void:
	print("[2] Cena de teste")
	var packed: PackedScene = load(MOVEMENT_SCENE) as PackedScene
	_expect(packed != null, "cena de teste carrega")
	if packed == null:
		return
	_scene = packed.instantiate()
	add_child(_scene)
	await _frames(10)

	_player = _scene.get_node_or_null("Player")
	_expect(_player != null, "jogador instanciado na cena")
	_expect(_player is CharacterBody3D, "jogador é um CharacterBody3D")
	_expect(_scene.get_node_or_null("TestRoom") != null, "sala de teste instanciada")
	_expect(_scene.get_node_or_null("Interface/PauseRoot") != null, "camada de pausa existe")
	var menu_button: Button = _scene.get_node_or_null(
		"Interface/PauseRoot/Center/Panel/Margin/Content/MenuButton"
	) as Button
	_expect(menu_button != null, "botão VOLTAR AO MENU existe")
	if menu_button != null:
		_expect(
			menu_button.pressed.get_connections().size() > 0,
			"botão VOLTAR AO MENU está conectado"
		)


# --- Movimento --------------------------------------------------------------

func _test_spawn_and_floor() -> void:
	print("[3] Nascimento e piso")
	var spawn := _scene.get_node_or_null("TestRoom/Spawn") as Marker3D
	_expect(spawn != null, "ponto de nascimento existe")

	# O spawn fica alguns centímetros acima do piso: espera o assentamento antes
	# de medir, senão a queda inicial seria confundida com tremor.
	var settled: bool = false
	for index: int in 60:
		await get_tree().physics_frame
		if _player.is_on_floor():
			settled = true
			break
	_expect(settled and _player.is_on_floor(), "jogador começa apoiado no piso")
	await _frames(10)

	var flat := Vector2(
		_player.global_position.x - spawn.global_position.x,
		_player.global_position.z - spawn.global_position.z
	)
	_expect(flat.length() < 0.25, "nasce sobre o ponto de nascimento (%.2f m)" % flat.length())

	var head := _player.get_node_or_null("Head") as Node3D
	var camera := _player.get_node_or_null("Head/Camera") as Camera3D
	_expect(head != null and camera != null, "cabeça e câmera existem")
	if head != null:
		_expect(
			absf(head.position.y - 1.62) < 0.01,
			"câmera na altura dos olhos (%.2f m)" % head.position.y
		)
	_expect(camera != null and camera.current, "câmera em primeira pessoa ativa")

	var y0: float = _player.global_position.y
	var max_deviation: float = 0.0
	for index: int in 90:
		await get_tree().physics_frame
		max_deviation = maxf(max_deviation, absf(_player.global_position.y - y0))
	_expect(max_deviation < 0.02, "sem tremor no piso (variação máx. %.3f m)" % max_deviation)


func _test_directions() -> void:
	print("[4] Direções (WASD)")
	var forward: Vector3 = await _measure(Vector3(0, 0.05, 0), 0.0, ["move_forward"], 30)
	_expect(forward.z < -0.8, "W anda para frente (-Z): %.2f m" % forward.z)
	_expect(absf(forward.x) < 0.05, "W não desvia para os lados (x=%.3f)" % forward.x)

	var backward: Vector3 = await _measure(Vector3(0, 0.05, 0), 0.0, ["move_back"], 30)
	_expect(backward.z > 0.8, "S anda para trás (+Z): %.2f m" % backward.z)

	var left: Vector3 = await _measure(Vector3(0, 0.05, 0), 0.0, ["move_left"], 30)
	_expect(left.x < -0.8, "A anda para a esquerda (-X): %.2f m" % left.x)

	var right: Vector3 = await _measure(Vector3(0, 0.05, 0), 0.0, ["move_right"], 30)
	_expect(right.x > 0.8, "D anda para a direita (+X): %.2f m" % right.x)


func _test_diagonal() -> void:
	print("[5] Diagonal")
	var straight: Vector3 = await _measure(Vector3(0, 0.05, 0), 0.0, ["move_forward"], 30)
	var diagonal: Vector3 = await _measure(
		Vector3(0, 0.05, 0), 0.0, ["move_forward", "move_right"], 30
	)
	var straight_distance: float = Vector2(straight.x, straight.z).length()
	var diagonal_distance: float = Vector2(diagonal.x, diagonal.z).length()
	_expect(straight_distance > 0.8, "deslocamento reto medido (%.2f m)" % straight_distance)
	_expect(
		absf(diagonal_distance - straight_distance) <= straight_distance * 0.06,
		"diagonal não é mais rápida (%.2f m vs %.2f m)" % [diagonal_distance, straight_distance]
	)


func _test_relative_movement() -> void:
	print("[6] Movimento relativo à visão")
	var rotated: Vector3 = await _measure(
		Vector3(0, 0.05, 0), PI / 2.0, ["move_forward"], 30
	)
	_expect(rotated.x < -0.8, "com a visão a 90°, W anda para -X: %.2f m" % rotated.x)
	_expect(absf(rotated.z) < 0.15, "movimento acompanha a orientação (z=%.3f)" % rotated.z)


func _test_idle_stability() -> void:
	print("[7] Estabilidade parado")
	await _place(Vector3(0, 0.05, 0), 0.0)
	var origin: Vector3 = _player.global_position
	for index: int in 60:
		await get_tree().physics_frame
	var drift := Vector2(
		_player.global_position.x - origin.x, _player.global_position.z - origin.z
	).length()
	_expect(drift < 0.01, "não se desloca sozinho parado (%.4f m)" % drift)


# --- Câmera -----------------------------------------------------------------

func _test_look() -> void:
	print("[8] Câmera e configurações")
	var scale: float = float(_player.mouse_sensitivity_scale)

	_settings.apply(SettingsSchema.defaults())
	_player.set_look(0.0, 0.0)
	_player.apply_look(Vector2(100.0, 0.0))
	_expect(_player.get_yaw() < 0.0, "mouse à direita gira a visão para a direita")
	_expect(
		absf(_player.get_yaw() + 100.0 * scale) < 0.0005,
		"sensibilidade 1.0 aplicada ao eixo horizontal"
	)

	var doubled: Dictionary = SettingsSchema.defaults()
	doubled[SettingsSchema.SECTION_CONTROLS]["mouse_sensitivity_x"] = 2.0
	_settings.apply(doubled)
	_player.set_look(0.0, 0.0)
	_player.apply_look(Vector2(100.0, 0.0))
	_expect(
		absf(_player.get_yaw() + 200.0 * scale) < 0.0005,
		"sensibilidade 2.0 dobra o giro horizontal"
	)
	_expect(
		absf(_player.get_sensitivity().x - 2.0) < 0.001,
		"jogador leu a sensibilidade do GameSettings"
	)

	_player.set_look(0.0, 0.0)
	_player.apply_look(Vector2(0.0, 100.0))
	_expect(_player.get_pitch() < 0.0, "mouse para baixo olha para baixo")

	_player.set_look(0.0, 0.0)
	_player.apply_look(Vector2(0.0, 100000.0))
	_expect(
		absf(_player.get_pitch()) <= deg_to_rad(89.0) + 0.001,
		"visão vertical limitada ao olhar para baixo (%.1f°)" % rad_to_deg(_player.get_pitch())
	)
	_player.set_look(0.0, 0.0)
	_player.apply_look(Vector2(0.0, -100000.0))
	_expect(
		absf(_player.get_pitch()) <= deg_to_rad(89.0) + 0.001,
		"visão vertical limitada ao olhar para cima (%.1f°)" % rad_to_deg(_player.get_pitch())
	)

	var inverted: Dictionary = SettingsSchema.defaults()
	inverted[SettingsSchema.SECTION_CONTROLS]["invert_y"] = true
	_settings.apply(inverted)
	_player.set_look(0.0, 0.0)
	_player.apply_look(Vector2(0.0, 100.0))
	_expect(_player.get_pitch() > 0.0, "inverter eixo vertical funciona")
	_expect(_player.is_invert_y(), "jogador leu a inversão do GameSettings")

	_settings.apply(SettingsSchema.defaults())
	_player.set_look(0.0, 0.0)
	_expect(
		absf(_player.get_sensitivity().x - 1.0) < 0.001 and not _player.is_invert_y(),
		"voltar aos padrões restaura sensibilidade e inversão"
	)


# --- Pausa ------------------------------------------------------------------

func _test_pause() -> void:
	print("[9] Pausa e liberação do mouse")
	var pause_root: Control = _scene.get_node_or_null("Interface/PauseRoot") as Control
	_scene.pause_session()
	_expect(_scene.is_paused(), "pause_session marca a sessão como pausada")
	_expect(pause_root != null and pause_root.visible, "camada de pausa fica visível")
	_expect(not _player.movement_enabled, "pausa desativa o movimento do jogador")

	await _place(Vector3(0, 0.05, 0), 0.0)
	var before: Vector3 = _player.global_position
	for index: int in 30:
		Input.action_press("move_forward")
		await get_tree().physics_frame
	Input.action_release("move_forward")
	var moved: float = Vector2(
		_player.global_position.x - before.x, _player.global_position.z - before.z
	).length()
	_expect(moved < 0.05, "WASD não move durante a pausa (%.3f m)" % moved)

	_scene.resume_session()
	_expect(not _scene.is_paused(), "resume_session retira a pausa")
	_expect(pause_root != null and not pause_root.visible, "camada de pausa é escondida")
	_expect(_player.movement_enabled, "continuar reativa o movimento")


# --- Física -----------------------------------------------------------------

func _test_gravity() -> void:
	print("[10] Gravidade")
	await _place(Vector3(0, 4.0, 0), 0.0)
	_expect(not _player.is_on_floor(), "jogador começa no ar")
	for index: int in 120:
		await get_tree().physics_frame
	_expect(_player.is_on_floor(), "gravidade leva o jogador ao chão")
	_expect(
		absf(_player.global_position.y) < 0.15,
		"pousa no piso (y=%.3f)" % _player.global_position.y
	)


func _test_collisions() -> void:
	print("[11] Colisões")
	await _place(Vector3(0, 0.05, -9.0), 0.0)
	await _measure_from_current(["move_forward"], 150)
	_expect(
		_player.global_position.z > -11.6,
		"não atravessa a parede norte (z=%.2f)" % _player.global_position.z
	)
	_expect(
		_player.global_position.z < -11.0,
		"chega até a parede (z=%.2f)" % _player.global_position.z
	)

	await _place(Vector3(3.0, 0.05, 5.0), 0.0)
	await _measure_from_current(["move_forward"], 120)
	_expect(
		_player.global_position.z > 2.7,
		"não atravessa a caixa (z=%.2f)" % _player.global_position.z
	)
	_expect(
		_player.global_position.z < 3.3,
		"para na frente da caixa (z=%.2f)" % _player.global_position.z
	)

	# canto: andando na diagonal contra o canto sudeste (x=+12, z=+12)
	await _place(Vector3(10.0, 0.05, 10.0), -3.0 * PI / 4.0)
	await _measure_from_current(["move_forward"], 150)
	_expect(
		_player.global_position.x < 11.6 and _player.global_position.z < 11.6,
		"não atravessa o canto das paredes (%.2f, %.2f)" % [
			_player.global_position.x, _player.global_position.z
		]
	)

	var y0: float = _player.global_position.y
	var max_deviation: float = 0.0
	for index: int in 30:
		await get_tree().physics_frame
		max_deviation = maxf(max_deviation, absf(_player.global_position.y - y0))
	_expect(max_deviation < 0.02, "estável encostado na parede (máx. %.3f m)" % max_deviation)


# --- Utilidades -------------------------------------------------------------

func _place(position: Vector3, yaw: float) -> void:
	_release_all()
	_player.velocity = Vector3.ZERO
	_player.global_position = position
	_player.set_look(yaw, 0.0)
	await _frames(10)


func _measure(position: Vector3, yaw: float, actions: Array, frames: int) -> Vector3:
	await _place(position, yaw)
	return await _measure_from_current(actions, frames)


func _measure_from_current(actions: Array, frames: int) -> Vector3:
	var origin: Vector3 = _player.global_position
	for action: String in actions:
		Input.action_press(action)
	for index: int in frames:
		await get_tree().physics_frame
	for action: String in actions:
		Input.action_release(action)
	await _frames(6)
	return _player.global_position - origin


func _release_all() -> void:
	for action: String in MOVE_ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().physics_frame


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ " + description)
	else:
		_failures.append(description)
		printerr("  ✗ " + description)


func _finish() -> void:
	_release_all()
	if _scene != null:
		_scene.queue_free()
	await get_tree().process_frame

	if _settings != null:
		_settings.config_path = _original_path
		_settings.apply(_original_values)
	_remove_test_file()

	print("")
	if _failures.is_empty():
		print("MOVEMENT TEST OK — %d verificações aprovadas" % _checks)
		get_tree().quit(0)
		return
	printerr("MOVEMENT TEST FALHOU — %d de %d verificações" % [_failures.size(), _checks])
	for failure: String in _failures:
		printerr("  ✗ " + failure)
	get_tree().quit(1)


func _remove_test_file() -> void:
	if FileAccess.file_exists(TEST_CONFIG):
		DirAccess.remove_absolute(TEST_CONFIG)
