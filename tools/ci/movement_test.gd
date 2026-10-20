extends Node
## Teste automatizado do controlador FPS e da cena de teste (Etapa 4 → Etapa 5).
##
## Uso:
##     godot --headless --path . --fixed-fps 60 --audio-driver Dummy \
##         res://tools/ci/movement_test.tscn
##
## O teste instancia a **cena real** (`match/scenes/movement_test.tscn`) e
## verifica movimento, estados (parado/andando/correndo/agachado), câmera,
## física, colisões, menu de pausa com configurações e integração com as
## configurações da Etapa 3. As entradas são simuladas com `Input.action_press`,
## que é o mesmo caminho usado pelo teclado.
##
## Sai com 0 em caso de sucesso e 1 em caso de falha.

const MOVEMENT_SCENE := "res://match/scenes/movement_test.tscn"
const TEST_CONFIG := "user://test_movement_settings.cfg"

const MOVE_ACTIONS := [
	"move_forward", "move_back", "move_left", "move_right",
	"move_sprint", "move_crouch",
]

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
	await _test_states()
	await _test_speeds()
	await _test_crouch_camera()
	await _test_crouch_ceiling()
	await _test_pause_settings()

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
	var extra := {
		"move_sprint": KEY_SHIFT,
		"move_crouch": KEY_CTRL,
	}
	for action: String in extra:
		_expect(InputMap.has_action(action), "ação '%s' existe" % action)
		var found_extra: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key != null and key.physical_keycode == extra[action]:
				found_extra = true
		_expect(found_extra, "ação '%s' vinculada a %s" % [
			action, OS.get_keycode_string(extra[action])
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
	# 2 m: abaixo do teto (4 m) mesmo com o jogador inteiro (1,8 m de altura).
	await _place(Vector3(0, 2.0, 0), 0.0)
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


# --- Estados (Etapa 5) ------------------------------------------------------

func _expect_state(expected: int, description: String) -> void:
	_expect(
		int(_player.get_state()) == expected,
		"%s (estado: %s)" % [description, _player.get_state_name()]
	)


func _test_states() -> void:
	print("[12] Estados de movimento")
	await _place(Vector3(0, 0.05, 0), 0.0)
	_expect_state(PlayerController.MovementState.IDLE, "sem entrada → PARADO")

	Input.action_press("move_forward")
	await _frames(6)
	_expect_state(PlayerController.MovementState.WALKING, "W → ANDANDO")

	Input.action_press("move_sprint")
	await _frames(8)
	_expect_state(PlayerController.MovementState.RUNNING, "W + SHIFT → CORRENDO")

	Input.action_press("move_crouch")
	await _frames(8)
	_expect_state(PlayerController.MovementState.CROUCHING, "CTRL durante corrida → AGACHADO (prioridade)")
	_expect(_player.is_crouched(), "cápsula fica agachada")

	Input.action_release("move_sprint")
	await _frames(4)
	_expect_state(PlayerController.MovementState.CROUCHING, "soltar SHIFT não levanta o agachamento")

	Input.action_release("move_crouch")
	await _frames(10)
	_expect_state(PlayerController.MovementState.WALKING, "soltar CTRL andando → ANDANDO")
	_expect(not _player.is_crouched(), "cápsula volta à altura normal")

	Input.action_release("move_forward")
	await _frames(10)
	_expect_state(PlayerController.MovementState.IDLE, "soltar W → PARADO")

	# corrida → parado; corrida → caminhada
	Input.action_press("move_forward")
	Input.action_press("move_sprint")
	await _frames(10)
	_expect_state(PlayerController.MovementState.RUNNING, "correndo de novo")
	Input.action_release("move_forward")
	await _frames(10)
	_expect_state(PlayerController.MovementState.IDLE, "parar durante a corrida → PARADO")
	Input.action_release("move_sprint")

	# agachar parado → soltar sem direção → parado
	Input.action_press("move_crouch")
	await _frames(8)
	_expect_state(PlayerController.MovementState.CROUCHING, "CTRL parado → AGACHADO")
	Input.action_release("move_crouch")
	await _frames(10)
	_expect_state(PlayerController.MovementState.IDLE, "soltar CTRL sem direção → PARADO")


func _test_speeds() -> void:
	print("[13] Velocidades")
	_expect(
		_player.run_speed > _player.walk_speed * 1.2,
		"corrida claramente maior que caminhada (%.2f m/s vs %.2f m/s)" % [
			_player.run_speed, _player.walk_speed
		]
	)
	_expect(
		_player.crouch_speed < _player.walk_speed * 0.8,
		"agachado claramente menor que caminhada (%.2f m/s vs %.2f m/s)" % [
			_player.crouch_speed, _player.walk_speed
		]
	)
	_expect(
		is_equal_approx(
			_player.speed_for_state(PlayerController.MovementState.IDLE), 0.0
		),
		"parado tem velocidade 0"
	)
	_expect(
		is_equal_approx(
			_player.speed_for_state(PlayerController.MovementState.WALKING),
			_player.walk_speed
		),
		"velocidade de caminhada vem de walk_speed"
	)

	var walk: Vector3 = await _measure(Vector3(0, 0.05, 0), 0.0, ["move_forward"], 30)
	var run: Vector3 = await _measure(
		Vector3(0, 0.05, 0), 0.0, ["move_forward", "move_sprint"], 30
	)
	var crouch: Vector3 = await _measure(
		Vector3(0, 0.05, 0), 0.0, ["move_forward", "move_crouch"], 30
	)
	var walk_distance: float = Vector2(walk.x, walk.z).length()
	var run_distance: float = Vector2(run.x, run.z).length()
	var crouch_distance: float = Vector2(crouch.x, crouch.z).length()
	_expect(run_distance > walk_distance * 1.25, "corrida percorre mais que caminhada (%.2f m vs %.2f m)" % [run_distance, walk_distance])
	_expect(crouch_distance < walk_distance * 0.8, "agachado percorre menos que caminhada (%.2f m vs %.2f m)" % [crouch_distance, walk_distance])

	# diagonal normalizada também correndo
	var run_diagonal: Vector3 = await _measure(
		Vector3(0, 0.05, 0), 0.0, ["move_forward", "move_right", "move_sprint"], 30
	)
	var run_diagonal_distance: float = Vector2(run_diagonal.x, run_diagonal.z).length()
	_expect(
		absf(run_diagonal_distance - run_distance) <= run_distance * 0.06,
		"diagonal correndo não é mais rápida (%.2f m vs %.2f m)" % [
			run_diagonal_distance, run_distance
		]
	)


func _test_crouch_camera() -> void:
	print("[14] Câmera ao agachar")
	await _place(Vector3(0, 0.05, 0), 0.0)
	await _frames(20)
	var origin: Vector3 = _player.global_position
	var standing_eye: float = _player.get_eye_height()
	_expect(
		absf(standing_eye - 1.62) < 0.05,
		"câmera em pé na altura dos olhos (%.2f m)" % standing_eye
	)

	Input.action_press("move_crouch")
	var previous: float = _player.get_eye_height()
	var max_step: float = 0.0
	for index: int in 45:
		await get_tree().physics_frame
		var current: float = _player.get_eye_height()
		max_step = maxf(max_step, absf(current - previous))
		previous = current

	_expect(
		_player.get_eye_height() < 1.15,
		"câmera desce ao agachar (%.2f m)" % _player.get_eye_height()
	)
	_expect(
		absf(_player.get_eye_height() - _player.crouched_eye_height) < 0.05,
		"câmera chega à altura agachada (%.2f m)" % _player.crouched_eye_height
	)
	_expect(max_step < 0.15, "descida suave, sem teletransporte (máx. %.3f m/frame)" % max_step)
	var flat := Vector2(
		_player.global_position.x - origin.x,
		_player.global_position.z - origin.z
	)
	_expect(flat.length() < 0.02, "agachar não desloca o jogador (%.3f m)" % flat.length())

	# o pitch continua válido durante o agachamento
	_player.set_look(0.0, 0.0)
	_player.apply_look(Vector2(0.0, 300.0))
	_expect(
		absf(_player.get_pitch()) <= deg_to_rad(89.0) + 0.001,
		"limite vertical continua valendo agachado"
	)
	_player.set_look(0.0, 0.0)

	Input.action_release("move_crouch")
	var max_step_up: float = 0.0
	previous = _player.get_eye_height()
	for index: int in 45:
		await get_tree().physics_frame
		var current: float = _player.get_eye_height()
		max_step_up = maxf(max_step_up, absf(current - previous))
		previous = current
	_expect(
		absf(_player.get_eye_height() - standing_eye) < 0.05,
		"câmera volta à altura normal (%.2f m)" % _player.get_eye_height()
	)
	_expect(max_step_up < 0.15, "subida suave, sem teletransporte (máx. %.3f m/frame)" % max_step_up)


func _test_crouch_ceiling() -> void:
	print("[15] Agachar sob obstáculo")
	await _place(Vector3(0, 0.05, 0), 0.0)
	Input.action_press("move_crouch")
	await _frames(10)
	_expect(_player.is_crouched(), "agacha antes do obstáculo")

	var blocker := StaticBody3D.new()
	blocker.name = "TestCeiling"
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 0.3, 2.0)
	collision.shape = box
	blocker.add_child(collision)
	_scene.add_child(blocker)
	blocker.global_position = _player.global_position + Vector3(0.0, 1.4, 0.0)
	await _frames(3)

	Input.action_release("move_crouch")
	await _frames(20)
	_expect(_player.is_crouched(), "não levanta com obstáculo acima")
	_expect_state(PlayerController.MovementState.CROUCHING, "estado continua AGACHADO sob o obstáculo")

	blocker.queue_free()
	await _frames(15)
	_expect(not _player.is_crouched(), "levanta quando o espaço fica livre")
	_expect_state(PlayerController.MovementState.IDLE, "volta a PARADO depois de levantar")


func _test_pause_settings() -> void:
	print("[16] Pausa com configurações")
	await _place(Vector3(0, 0.05, 0), 0.0)
	Input.action_press("move_crouch")
	await _frames(10)
	_expect_state(PlayerController.MovementState.CROUCHING, "agachado antes da pausa")
	var position_before: Vector3 = _player.global_position

	_scene.pause_session()
	await _frames(3)
	_expect(_scene.is_paused(), "pausa ativa")

	var content := "Interface/PauseRoot/Center/Panel/Margin/Content/"
	_expect(
		_scene.get_node_or_null(content + "ContinueButton") != null,
		"menu de pausa tem CONTINUAR"
	)
	var settings_button: Button = _scene.get_node_or_null(
		content + "SettingsButton"
	) as Button
	_expect(settings_button != null, "menu de pausa tem CONFIGURAÇÕES")
	_expect(
		_scene.get_node_or_null(content + "MenuButton") != null,
		"menu de pausa tem VOLTAR AO MENU"
	)
	if settings_button == null:
		Input.action_release("move_crouch")
		return

	settings_button.pressed.emit()
	await _frames(6)
	_expect(_scene.is_settings_open(), "CONFIGURAÇÕES abre por cima da partida")
	var screen: SettingsScreen = _scene.get_node_or_null(
		"SettingsLayer/SettingsScreen"
	) as SettingsScreen
	_expect(screen != null, "usa a mesma tela de configurações da Etapa 3")
	if screen != null:
		_expect(screen.is_embedded(), "tela aberta em modo embutido (sem trocar de cena)")
	_expect(not _player.movement_enabled, "jogador continua parado com as configurações abertas")
	_expect(not _scene.get_node("Interface/PauseRoot").visible, "menu de pausa fica oculto")

	var before_move: Vector3 = _player.global_position
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_release("move_forward")
	var moved := Vector2(
		_player.global_position.x - before_move.x,
		_player.global_position.z - before_move.z
	).length()
	_expect(moved < 0.05, "WASD não move com configurações abertas (%.3f m)" % moved)

	# As configurações continuam sendo as mesmas: alterar a sensibilidade pelo
	# autoload chega ao controlador sem reiniciar a partida.
	var doubled: Dictionary = SettingsSchema.defaults()
	doubled[SettingsSchema.SECTION_CONTROLS]["mouse_sensitivity_x"] = 2.0
	_settings.apply(doubled)
	await _frames(2)
	_expect(
		absf(_player.get_sensitivity().x - 2.0) < 0.001,
		"alteração de sensibilidade chega ao controlador"
	)

	var back_button: Button = null
	if screen != null:
		back_button = screen.get_node_or_null("%BackButton") as Button
	_expect(back_button != null, "configurações têm VOLTAR")
	if back_button != null:
		back_button.pressed.emit()
		await _frames(6)
	_expect(not _scene.is_settings_open(), "VOLTAR fecha as configurações")
	_expect(_scene.is_paused(), "VOLTAR leva de volta ao menu de pausa")
	_expect(_scene.get_node("Interface/PauseRoot").visible, "menu de pausa reaparece")
	_expect(
		_player.global_position.distance_to(position_before) < 0.02,
		"posição do jogador preservada"
	)
	_expect_state(PlayerController.MovementState.CROUCHING, "estado do jogador preservado (AGACHADO)")

	var continue_button: Button = _scene.get_node_or_null(
		content + "ContinueButton"
	) as Button
	if continue_button != null:
		continue_button.pressed.emit()
		await _frames(3)
	_expect(not _scene.is_paused(), "CONTINUAR retoma a partida")
	_expect(_player.movement_enabled, "jogador habilitado de novo")

	Input.action_release("move_crouch")
	await _frames(12)
	_expect(not _player.is_crouched(), "levanta ao continuar com o espaço livre")

	Input.action_press("move_forward")
	await _frames(20)
	Input.action_release("move_forward")
	_expect(
		_player.global_position.distance_to(position_before) > 0.3,
		"movimento volta a funcionar depois de CONTINUAR"
	)

	# Restaura os padrões para os testes seguintes.
	_settings.apply(SettingsSchema.defaults())


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
