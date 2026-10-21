extends Node
## Teste automatizado do controlador FPS e da cena de teste (Etapa 4 → Etapa 8).
##
## Uso:
##     godot --headless --path . --fixed-fps 60 --audio-driver Dummy \
##         res://tools/ci/movement_test.tscn
##
## O teste instancia a **cena real** (`match/scenes/movement_test.tscn`) e
## verifica movimento, estados (parado/andando/correndo/agachado), câmera,
## física, colisões, menu de pausa com configurações, integração com as
## configurações da Etapa 3, stamina (consumo, atraso de recuperação e
## exaustão), a HUD da Etapa 6.1, os dois modos de agachamento (SEGURAR e
## ALTERNAR, este último o padrão do jogo), o sistema de interação da Etapa 7
## (raycast, distância, linha de visão, indicação, pausa) e o inventário de três
## slots da Etapa 8 (API, coleta, seleção, remoção, substituição, inventário
## cheio e pausa) e o drop da Etapa 9 (soltar, posição segura, recolher,
## inventário cheio, falhas e pausa). As entradas são simuladas com
## `Input.action_press`, que é o mesmo caminho usado pelo teclado.
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
## Watchdog: se nenhuma verificação/espera avançar por este tempo, o teste
## imprime a última fase e encerra com código 2 (em vez de deixar o CI pendurado).
const WATCHDOG_MS := 60000
var _last_progress_ms: int = 0
var _last_step: String = "início"
var _finished: bool = false
## Marca que o grupo [24] chegou à última verificação (um erro de runtime no
## meio de uma coroutine encerraria o grupo sem falhar nada).
var _drop_completed: bool = false
var _original_path: String = ""
var _original_values: Dictionary = {}


func _ready() -> void:
	print("=== Black Sight · teste do controlador FPS ===")
	_touch("início")

	_settings = get_node_or_null("/root/GameSettings")
	if _settings != null:
		_original_path = _settings.config_path
		_original_values = _settings.current()
		_settings.config_path = TEST_CONFIG
		_remove_test_file()
		_settings.apply(SettingsSchema.defaults())

		# Os grupos [12]–[16] foram escritos para o modo SEGURAR (Etapa 5).
		# O padrão novo (ALTERNAR) é verificado no smoke test e no grupo [18].
		var hold_values: Dictionary = SettingsSchema.defaults()
		hold_values[SettingsSchema.SECTION_CONTROLS]["crouch_mode"] = "hold"
		_settings.apply(hold_values)

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
	await _test_stamina()
	await _test_crouch_toggle()
	await _test_pause_stamina_mode()
	await _test_hud()
	await _test_recovery_delay()
	await _test_interaction()
	await _test_inventory()
	await _test_drop()
	_expect(_drop_completed, "grupo [24] executado até o fim")
	await _test_sprint_release()

	_finish()


## Watchdog: o teste nunca deve ficar pendurado (uma falha dentro de uma
## coroutine deixaria o processo vivo para sempre no CI).
func _process(_delta: float) -> void:
	if _finished:
		return
	var idle: int = Time.get_ticks_msec() - _last_progress_ms
	if idle <= WATCHDOG_MS:
		return
	_finished = true
	printerr("MOVEMENT TEST TRAVOU — %d ms sem progresso (última etapa: %s)" % [idle, _last_step])
	printerr("verificações até aqui: %d · falhas: %d" % [_checks, _failures.size()])
	get_tree().quit(2)


func _touch(step: String = "") -> void:
	_last_progress_ms = Time.get_ticks_msec()
	if not step.is_empty():
		_last_step = step


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
	await _set_crouch_mode("hold")
	await _place(Vector3(0, 0.05, 0), 0.0)
	_player.set_stamina(_player.max_stamina)
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
	_player.set_stamina(_player.max_stamina)
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
	_player.set_stamina(_player.max_stamina)
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
	# Este grupo foi escrito para o modo SEGURAR (Etapa 5).
	doubled[SettingsSchema.SECTION_CONTROLS]["crouch_mode"] = "hold"
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

	# Restaura os padrões (sensibilidade 1.0) e o modo SEGURAR.
	_settings.apply(SettingsSchema.defaults())
	await _set_crouch_mode("hold")


# --- Stamina e modos de agachamento (Etapa 6) ------------------------------

func _test_stamina() -> void:
	print("[17] Stamina")
	await _set_crouch_mode("hold")
	await _place(Vector3(0, 0.05, 0), 0.0)
	_player.set_stamina(_player.max_stamina)

	_expect(is_equal_approx(_player.get_max_stamina(), 100.0), "stamina máxima = 100")
	_expect(is_equal_approx(_player.stamina_drain_rate, 20.0), "consumo = 20 por segundo")
	_expect(is_equal_approx(_player.stamina_recovery_rate, 15.0), "recuperação = 15 por segundo")
	_expect(
		_player.sprint_resume_threshold > 0.0 and _player.sprint_resume_threshold < 50.0,
		"limiar de retorno configurado (%.0f)" % _player.sprint_resume_threshold
	)
	_expect(is_equal_approx(_player.get_stamina(), 100.0), "stamina começa cheia")
	_expect(_player.is_sprint_allowed(), "corrida liberada com stamina cheia")
	_expect(is_equal_approx(_player.get_stamina_ratio(), 1.0), "razão de stamina = 1.0 cheia")

	# Consumo apenas no estado RUNNING.
	Input.action_press("move_forward")
	Input.action_press("move_sprint")
	await _frames(60)
	var consumed: float = 100.0 - _player.get_stamina()
	_expect_state(PlayerController.MovementState.RUNNING, "correndo com stamina")
	_expect(
		absf(consumed - _player.stamina_drain_rate) < 4.0,
		"1 s correndo consome ~%.0f (%.1f)" % [_player.stamina_drain_rate, consumed]
	)
	_expect(_player.get_stamina() > 0.0, "corrida curta não esgota a stamina")

	# Recuperação andando — só depois do atraso de 1 s (Etapa 6.2).
	# O atraso é aguardado parado para o jogador não terminar contra a parede.
	Input.action_release("move_sprint")
	await _frames(4)
	_expect_state(PlayerController.MovementState.WALKING, "soltar SHIFT → ANDANDO")
	Input.action_release("move_forward")
	await _frames(2)
	await _wait_recovery_delay()
	Input.action_press("move_forward")
	await _frames(6)
	_expect_state(PlayerController.MovementState.WALKING, "voltou a ANDAR")
	_player.set_stamina(40.0)
	var walk_start: float = _player.get_stamina()
	await _frames(60)
	var walk_gain: float = _player.get_stamina() - walk_start
	_expect(
		absf(walk_gain - _player.stamina_recovery_rate) < 4.0,
		"1 s andando recupera ~%.0f (%.1f)" % [_player.stamina_recovery_rate, walk_gain]
	)

	# Recuperação agachado (e nenhum consumo) — de volta ao centro da sala.
	await _place(Vector3(0, 0.05, 0), 0.0)
	_expect(not _player.is_crouched(), "em pé antes do teste agachado")
	Input.action_press("move_forward")
	Input.action_press("move_crouch")
	await _frames(8)
	_expect_state(PlayerController.MovementState.CROUCHING, "CTRL andando → AGACHADO")
	await _wait_recovery_delay()
	_player.set_stamina(40.0)
	var crouch_start: float = _player.get_stamina()
	await _frames(60)
	var crouch_gain: float = _player.get_stamina() - crouch_start
	_expect(crouch_gain > 0.0, "agachado recupera stamina (%.1f)" % crouch_gain)
	_expect(
		absf(crouch_gain - _player.stamina_recovery_rate) < 4.0,
		"recuperação agachado ≈ %.0f/s (%.1f)" % [_player.stamina_recovery_rate, crouch_gain]
	)
	Input.action_release("move_crouch")
	Input.action_release("move_forward")
	await _frames(12)

	# Recuperação parado.
	await _wait_recovery_delay()
	_player.set_stamina(40.0)
	var idle_start: float = _player.get_stamina()
	await _frames(60)
	var idle_gain: float = _player.get_stamina() - idle_start
	_expect(
		absf(idle_gain - _player.stamina_recovery_rate) < 4.0,
		"1 s parado recupera ~%.0f (%.1f)" % [_player.stamina_recovery_rate, idle_gain]
	)

	# Esgotamento: RUNNING → WALKING, bloqueio e retorno após o limiar.
	await _place(Vector3(0, 0.05, 0), 0.0)
	_expect(
		not _player.is_crouched(),
		"em pé antes do esgotamento (%s)" % _player.global_position
	)
	_player.set_stamina(3.0)
	_player.set_sprint_allowed(true)
	Input.action_press("move_forward")
	Input.action_press("move_sprint")
	var zero_seen: bool = false
	var interrupted: bool = false
	for index: int in 45:
		await get_tree().physics_frame
		if _player.get_stamina() <= 0.0:
			zero_seen = true
			if int(_player.get_state()) == PlayerController.MovementState.WALKING:
				interrupted = true
	_expect(zero_seen, "stamina chega a 0 sem ficar negativa")
	_expect(interrupted, "esgotar interrompe a corrida (RUNNING → WALKING)")
	_expect(not _player.is_sprint_allowed(), "corrida bloqueada com stamina esgotada")
	var low: float = _player.get_stamina()
	await _frames(20)
	_expect_state(PlayerController.MovementState.WALKING, "SHIFT pressionado não corre com stamina baixa")
	# Etapa 6.2: exausto e ainda segurando SHIFT = nenhuma recuperação.
	_expect(
		is_equal_approx(_player.get_stamina(), low),
		"SHIFT pressionado mantém a stamina parada (%.1f)" % _player.get_stamina()
	)

	# Retorno determinístico: abaixo do limiar continua bloqueada; ao passar do
	# limiar com SHIFT solto, a corrida é liberada e volta a correr.
	Input.action_release("move_forward")
	Input.action_release("move_sprint")
	await _frames(6)
	await _wait_recovery_delay()
	_player.set_stamina(_player.sprint_resume_threshold - 5.0)
	_expect(
		not _player.is_sprint_allowed(),
		"5 pontos abaixo do limiar: corrida continua bloqueada"
	)
	var unlocked: bool = false
	for index: int in 90:
		await get_tree().physics_frame
		if _player.is_sprint_allowed():
			unlocked = true
			break
	_expect(
		_player.get_stamina() >= 0.0,
		"stamina não fica negativa ao recuperar o limiar"
	)
	_expect(
		unlocked and _player.is_sprint_allowed(),
		"corrida liberada ao recuperar o limiar (%.1f)" % _player.get_stamina()
	)
	Input.action_press("move_forward")
	Input.action_press("move_sprint")
	var resumed: bool = false
	for index: int in 60:
		await get_tree().physics_frame
		if int(_player.get_state()) == PlayerController.MovementState.RUNNING:
			resumed = true
			break
	_expect(resumed, "com SHIFT pressionado, volta a CORRER ao recuperar o limiar")
	Input.action_release("move_forward")
	Input.action_release("move_sprint")
	await _frames(6)

	# Limites duros de set_stamina.
	_player.set_stamina(1.0e6)
	_expect(is_equal_approx(_player.get_stamina(), 100.0), "set_stamina limita ao máximo")
	_player.set_stamina(-5.0)
	_expect(is_equal_approx(_player.get_stamina(), 0.0), "set_stamina limita a zero")
	_expect(not _player.is_sprint_allowed(), "set_stamina(0) bloqueia a corrida")
	_player.set_stamina(_player.max_stamina)
	_expect(_player.is_sprint_allowed(), "set_stamina(cheia) libera a corrida")


func _test_crouch_toggle() -> void:
	print("[18] Modo ALTERNAR (padrão)")
	await _set_crouch_mode("toggle")
	await _place(Vector3(0, 0.05, 0), 0.0)
	_player.set_stamina(_player.max_stamina)
	_expect(_player.get_crouch_mode() == "toggle", "controlador lê o modo ALTERNAR")
	_expect(not _player.is_crouched(), "começa em pé")

	await _tap_crouch()
	await _frames(20)
	_expect(_player.is_crouched(), "um toque em CTRL agacha")
	_expect_state(PlayerController.MovementState.CROUCHING, "estado AGACHADO após o toque")
	var standing_eye: float = _player.standing_eye_height
	_expect(
		absf(_player.get_eye_height() - _player.crouched_eye_height) < 0.05,
		"câmera desce ao agachar em ALTERNAR (%.2f m)" % _player.get_eye_height()
	)

	# Agachado nunca corre nem consome stamina.
	Input.action_press("move_forward")
	Input.action_press("move_sprint")
	await _frames(30)
	_expect_state(PlayerController.MovementState.CROUCHING, "agachado + SHIFT continua AGACHADO")
	_expect(
		is_equal_approx(_player.get_stamina(), _player.max_stamina),
		"agachado não consome stamina (%.1f)" % _player.get_stamina()
	)
	Input.action_release("move_sprint")
	Input.action_release("move_forward")
	await _frames(10)
	_expect(_player.is_crouched(), "soltar CTRL não levanta em ALTERNAR")

	# Colisão: não levanta sob obstáculo; levanta quando o espaço fica livre.
	var blocker := StaticBody3D.new()
	blocker.name = "TestCeilingToggle"
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 0.3, 2.0)
	collision.shape = box
	blocker.add_child(collision)
	_scene.add_child(blocker)
	blocker.global_position = _player.global_position + Vector3(0.0, 1.4, 0.0)
	await _frames(3)

	await _tap_crouch()
	await _frames(20)
	_expect(_player.is_crouched(), "não levanta sob obstáculo em ALTERNAR")
	blocker.queue_free()
	await _frames(20)
	_expect(not _player.is_crouched(), "levanta ao liberar o espaço em ALTERNAR")
	_expect(
		absf(_player.get_eye_height() - standing_eye) < 0.05,
		"câmera volta à altura normal (%.2f m)" % _player.get_eye_height()
	)

	# Dois toques alternam de novo.
	await _tap_crouch()
	await _frames(12)
	_expect(_player.is_crouched(), "novo toque agacha de novo")
	await _tap_crouch()
	await _frames(12)
	_expect(not _player.is_crouched(), "outro toque levanta")

	# Modo SEGURAR: só permanece agachado enquanto CTRL está pressionado.
	await _set_crouch_mode("hold")
	await _frames(4)
	_expect(_player.get_crouch_mode() == "hold", "controlador lê o modo SEGURAR")
	Input.action_press("move_crouch")
	await _frames(10)
	_expect(_player.is_crouched(), "SEGURAR: agachado com CTRL pressionado")
	Input.action_release("move_crouch")
	await _frames(14)
	_expect(not _player.is_crouched(), "SEGURAR: levanta ao soltar CTRL")


func _test_pause_stamina_mode() -> void:
	print("[19] Pausa, stamina e troca de modo em partida")
	await _set_crouch_mode("hold")
	await _place(Vector3(0, 0.05, 0), 0.0)
	_player.set_stamina(80.0)
	_player.set_look(0.6, 0.2)
	Input.action_press("move_forward")
	Input.action_press("move_sprint")
	await _frames(30)
	_expect_state(PlayerController.MovementState.RUNNING, "correndo antes da pausa")
	var stamina_before: float = _player.get_stamina()
	var position_before: Vector3 = _player.global_position
	var yaw_before: float = _player.get_yaw()
	var pitch_before: float = _player.get_pitch()
	var eye_before: float = _player.get_eye_height()
	_expect(stamina_before < 80.0, "corrida consumiu stamina (%.1f)" % stamina_before)

	_scene.pause_session()
	await _frames(40)
	_expect(
		is_equal_approx(_player.get_stamina(), stamina_before),
		"pausa não consome nem recupera stamina (%.1f)" % _player.get_stamina()
	)
	_expect(_player.global_position.distance_to(position_before) < 0.02, "posição preservada na pausa")
	_expect(absf(_player.get_yaw() - yaw_before) < 0.0001, "yaw preservado na pausa")
	_expect(absf(_player.get_pitch() - pitch_before) < 0.0001, "pitch preservado na pausa")
	_expect_state(PlayerController.MovementState.RUNNING, "estado preservado na pausa")

	_scene.open_settings()
	await _frames(8)
	_expect(_scene.is_settings_open(), "CONFIGURAÇÕES abre durante a partida")
	var screen: SettingsScreen = _scene.get_node_or_null(
		"SettingsLayer/SettingsScreen"
	) as SettingsScreen
	_expect(screen != null, "mesma tela de configurações da tela inicial")
	var controls: ControlsSection = null
	if screen != null:
		controls = screen.get_section("controls") as ControlsSection
	_expect(controls != null, "seção CONTROLES disponível na partida")
	if controls != null and screen != null:
		_expect(controls.crouch_mode_id() == "hold", "modo atual exibido: SEGURAR")
		_expect(
			controls.get_crouch_hint_text() == "Segurar para agachar",
			"texto do CTRL em SEGURAR"
		)
		controls.set_crouch_mode_id("toggle")
		_expect(
			controls.get_crouch_hint_text() == "Alternar agachamento",
			"texto do CTRL muda ao escolher ALTERNAR"
		)
		var apply_button: Button = screen.get_node_or_null("%ApplyButton") as Button
		_expect(apply_button != null, "botão APLICAR presente")
		if apply_button != null:
			apply_button.pressed.emit()
			await _frames(4)
			_expect(_player.get_crouch_mode() == "toggle", "modo ALTERNAR chega ao controlador")
			_expect(
				is_equal_approx(_player.get_stamina(), stamina_before),
				"APLICAR não altera a stamina"
			)
			controls = screen.get_section("controls") as ControlsSection
			_expect(
				controls != null and controls.crouch_mode_id() == "toggle",
				"tela reconstrói com o modo salvo"
			)
			if controls != null:
				_expect(
					controls.get_crouch_hint_text() == "Alternar agachamento",
					"texto do CTRL continua dinâmico após aplicar"
				)
		var back_button: Button = screen.get_node_or_null("%BackButton") as Button
		_expect(back_button != null, "botão VOLTAR presente")
		if back_button != null:
			back_button.pressed.emit()
			await _frames(6)

	_expect(not _scene.is_settings_open(), "VOLTAR fecha as configurações")
	_expect(_scene.is_paused(), "VOLTAR retorna ao menu de pausa")
	_expect(absf(_player.get_yaw() - yaw_before) < 0.0001, "yaw mantido ao voltar")
	_expect(absf(_player.get_pitch() - pitch_before) < 0.0001, "pitch mantido ao voltar")
	_expect(
		_player.global_position.distance_to(position_before) < 0.02,
		"posição mantida ao voltar"
	)
	_expect(
		is_equal_approx(_player.get_stamina(), stamina_before),
		"stamina mantida ao voltar"
	)

	var content := "Interface/PauseRoot/Center/Panel/Margin/Content/"
	var continue_button: Button = _scene.get_node_or_null(
		content + "ContinueButton"
	) as Button
	_expect(continue_button != null, "botão CONTINUAR presente")
	if continue_button != null:
		continue_button.pressed.emit()
		await _frames(3)
	_expect(not _scene.is_paused(), "CONTINUAR retoma a partida")
	_expect(_player.movement_enabled, "jogador habilitado de novo")
	_expect(absf(_player.get_yaw() - yaw_before) < 0.0001, "yaw contínuo após CONTINUAR")
	_expect(absf(_player.get_pitch() - pitch_before) < 0.0001, "pitch contínuo após CONTINUAR")
	_expect(
		_player.global_position.distance_to(position_before) < 0.5,
		"posição contínua após CONTINUAR (sem teletransporte)"
	)
	_expect(
		absf(_player.get_eye_height() - eye_before) < 0.05,
		"câmera contínua após CONTINUAR (%.2f m)" % _player.get_eye_height()
	)
	_expect(
		absf(_player.get_stamina() - stamina_before) < 2.0,
		"stamina continua de onde parou (%.1f)" % _player.get_stamina()
	)

	# ALTERNAR em partida: um toque agacha; outro levanta e volta a correr.
	await _tap_crouch()
	await _frames(10)
	_expect(_player.is_crouched(), "toque em CTRL agacha durante a partida")
	_expect_state(PlayerController.MovementState.CROUCHING, "corrida é interrompida ao agachar")
	var crouched_stamina: float = _player.get_stamina()
	await _frames(30)
	# Etapa 6.2: SHIFT ainda pressionado bloqueia a recuperação no agachamento.
	_expect(
		is_equal_approx(_player.get_stamina(), crouched_stamina),
		"agachado com SHIFT pressionado não recupera (%.1f)" % _player.get_stamina()
	)
	Input.action_release("move_sprint")
	await _wait_recovery_delay()
	var crouch_recovering: float = _player.get_stamina()
	await _frames(30)
	_expect(
		_player.get_stamina() > crouch_recovering,
		"agachado recupera stamina depois do atraso"
	)
	var before_shift: float = _player.get_stamina()
	Input.action_press("move_sprint")
	await _frames(10)
	_expect(
		is_equal_approx(_player.get_stamina(), before_shift),
		"SHIFT pressionado volta a bloquear a recuperação"
	)
	await _tap_crouch()
	await _frames(12)
	_expect(not _player.is_crouched(), "segundo toque levanta")
	_expect_state(
		PlayerController.MovementState.RUNNING,
		"com SHIFT pressionado, volta a CORRER ao levantar"
	)

	Input.action_release("move_forward")
	Input.action_release("move_sprint")
	await _frames(6)
	await _set_crouch_mode("hold")
	_player.set_stamina(_player.max_stamina)



# --- HUD (Etapa 6.1) --------------------------------------------------------

func _test_hud() -> void:
	print("[20] HUD de stamina")
	if _scene.is_settings_open():
		_scene.close_settings()
	if _scene.is_paused():
		_scene.resume_session()
	await _place(Vector3(0, 0.05, 0), 0.0)
	_player.set_stamina(_player.max_stamina)

	var hud: PlayerHud = _scene.get_hud()
	_expect(hud != null, "HUD instanciada na partida")
	if hud == null:
		return
	_expect(hud.visible, "HUD visível ao entrar na sala")
	_expect(hud.is_bound(), "HUD ligada ao jogador")
	_expect(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD não captura o mouse")

	var bar: StaminaBar = hud.get_stamina_bar()
	_expect(bar != null, "barra de stamina disponível")
	if bar == null:
		return

	await _frames(2)
	_expect(is_equal_approx(bar.get_ratio(), 1.0), "barra cheia com stamina 100")
	_expect(bar.get_value_text() == "100%", "texto mostra 100%")
	_expect(bar.get_fill_width() > 0.0, "preenchimento visível")

	# Diminui durante a corrida, acompanhando o valor real.
	Input.action_press("move_forward")
	Input.action_press("move_sprint")
	await _frames(60)
	var expected: float = _player.get_stamina() / _player.get_max_stamina()
	Input.action_release("move_forward")
	Input.action_release("move_sprint")
	await _frames(6)
	# Mesma leitura do controlador no mesmo frame: o sinal é síncrono.
	expected = _player.get_stamina() / _player.get_max_stamina()
	var shown: float = bar.get_ratio()
	_expect(shown < 1.0, "barra diminui ao correr (%.0f%%)" % (shown * 100.0))
	_expect(
		absf(shown - expected) < 0.001,
		"barra acompanha a stamina real (%.3f vs %.3f)" % [shown, expected]
	)
	_expect(
		bar.get_value_text() == "%d%%" % roundi(shown * 100.0),
		"texto acompanha o valor (%s)" % bar.get_value_text()
	)

	# Esgotamento: o sinal `stamina_changed` é emitido dentro de `set_stamina`,
	# então a leitura é feita imediatamente, sem deixar a recuperação começar.
	_player.set_stamina(0.0)
	_expect(is_equal_approx(bar.get_ratio(), 0.0), "barra no mínimo com stamina 0")
	_expect(bar.get_fill_width() == 0.0, "sem preenchimento quando esgotada")
	_expect(bar.get_value_text() == "0%", "texto mostra 0%")
	await _wait_recovery_delay()
	await _frames(60)
	_expect(bar.get_ratio() > 0.0, "barra aumenta durante a recuperação")
	_expect(
		absf(bar.get_ratio() - _player.get_stamina() / _player.get_max_stamina()) < 0.001,
		"recuperação sincronizada com o controlador"
	)

	# Pausa: o valor exibido não muda.
	_player.set_stamina(60.0)
	var paused_ratio: float = bar.get_ratio()
	_expect(is_equal_approx(paused_ratio, 0.6), "barra mostra 60% antes da pausa")
	_scene.pause_session()
	await _frames(2)
	await _frames(40)
	_expect(is_equal_approx(bar.get_ratio(), paused_ratio), "barra não muda na pausa")
	_expect(bar.get_value_text() == "60%", "texto estável na pausa")

	# Configurações abertas a partir da pausa: também estável.
	_scene.open_settings()
	await _frames(8)
	await _frames(30)
	_expect(
		is_equal_approx(bar.get_ratio(), paused_ratio),
		"barra não muda com as configurações abertas"
	)
	_expect(bar.get_value_text() == "60%", "texto estável com as configurações abertas")
	_scene.close_settings()
	await _frames(4)
	_expect(_scene.is_paused(), "partida continua pausada ao fechar as configurações")
	_scene.resume_session()
	await _frames(4)
	_expect(not _scene.is_paused(), "partida retomada para os testes seguintes")

	# Posição, tamanho e ausência de texturas (desenho nativo).
	var panel: Control = hud.get_node_or_null("Layout/Stack/Panel") as Control
	_expect(panel != null, "painel discreto da HUD existe")
	if panel != null:
		var viewport: Vector2 = hud.get_viewport_rect().size
		var panel_rect: Rect2 = panel.get_global_rect()
		_expect(
			panel_rect.position.x >= 16.0 and panel_rect.position.y > viewport.y * 0.7,
			"HUD no canto inferior esquerdo (%.0f, %.0f)" % [
				panel_rect.position.x, panel_rect.position.y
			]
		)
		_expect(panel_rect.end.x <= viewport.x * 0.35, "HUD não ocupa a largura da tela")
		_expect(panel_rect.size.y <= 120.0, "HUD compacta (%.0f px de altura)" % panel_rect.size.y)
		_expect(panel_rect.end.y <= viewport.y, "HUD não é cortada na parte inferior")
		_expect(
			panel.get_node_or_null("StaminaBar") != null,
			"barra dentro do painel da HUD"
		)
	_expect(
		hud.find_children("*", "TextureRect", true, false).is_empty(),
		"HUD desenhada sem texturas"
	)

	# Adaptação a resoluções menores (mesmo caminho do redimensionar/F11).
	var original_size: Vector2 = hud.size
	hud.size = Vector2(960.0, 540.0)
	await _frames(4)
	if panel != null:
		var small_rect: Rect2 = panel.get_global_rect()
		_expect(small_rect.end.y <= 540.0, "HUD cabe em 960×540 (fim em %.0f)" % small_rect.end.y)
		_expect(small_rect.position.y > 540.0 * 0.7, "HUD segue no rodapé em 960×540")
		_expect(panel.is_visible_in_tree(), "painel continua visível após redimensionar")
	_expect(bar.get_ratio() > 0.0, "barra continua desenhando após redimensionar")
	_expect(bar.get_value_text() != "", "texto continua após redimensionar")
	hud.size = original_size
	await _frames(4)
	_expect(hud.size.is_equal_approx(original_size), "HUD volta ao tamanho original")

	# Limites diretos da barra, independentes do jogo.
	bar.set_values(-20.0, 100.0)
	_expect(is_equal_approx(bar.get_ratio(), 0.0), "barra limita valores negativos")
	bar.set_values(250.0, 100.0)
	_expect(is_equal_approx(bar.get_ratio(), 1.0), "barra limita acima do máximo")
	bar.set_values(10.0, 0.0)
	_expect(is_equal_approx(bar.get_ratio(), 0.0), "máximo zero não quebra a barra")
	bar.set_values(10.0, 100.0)
	_expect(bar.is_low(), "barra indica estado baixo abaixo do limiar")
	bar.set_values(30.0, 100.0)
	_expect(not bar.is_low(), "barra não alerta acima do limiar")

	_player.set_stamina(_player.max_stamina)
	await _frames(2)
	_expect(bar.get_value_text() == "100%", "barra volta a 100% no fim")

# --- Atraso de recuperação e exaustão (Etapa 6.2) ---------------------------

func _test_recovery_delay() -> void:
	print("[21] Atraso de recuperação e exaustão (Etapa 6.2)")
	await _set_crouch_mode("hold")
	await _place(Vector3(0, 0.05, 0), 0.0)
	await _wait_recovery_delay()
	_player.set_stamina(_player.max_stamina)

	_expect(
		is_equal_approx(_player.stamina_recovery_delay, 1.0),
		"atraso de recuperação = 1,0 s"
	)
	_expect(
		_player.has_method("get_recovery_delay_left") and _player.has_method("is_sprint_held"),
		"controlador expõe get_recovery_delay_left() e is_sprint_held()"
	)
	_expect(
		is_equal_approx(_player.get_stamina(), 100.0),
		"começa com stamina cheia (%.1f)" % _player.get_stamina()
	)

	# [1] Corrida normal: consome 20/s.
	Input.action_press("move_forward")
	Input.action_press("move_sprint")
	await _frames(60)
	_expect_state(PlayerController.MovementState.RUNNING, "[1] corrida com SHIFT")
	var drained: float = 100.0 - _player.get_stamina()
	_expect(
		absf(drained - _player.stamina_drain_rate) < 4.0,
		"[1] 1 s correndo consome ~20 (%.1f)" % drained
	)

	# [2] Soltar SHIFT: 1 s sem recuperar e depois 15/s.
	Input.action_release("move_sprint")
	await _frames(2)
	_expect_state(PlayerController.MovementState.WALKING, "[2] soltar SHIFT → ANDANDO")
	var released_at: float = _player.get_stamina()
	_expect(
		_player.get_recovery_delay_left() > 0.9,
		"[2] atraso começa cheio (%.2f s)" % _player.get_recovery_delay_left()
	)
	await _frames(30)
	_expect(
		absf(_player.get_stamina() - released_at) < 0.01,
		"[2] nada recupera nos primeiros 0,5 s (%.2f)" % _player.get_stamina()
	)
	await _frames(20)
	_expect(
		absf(_player.get_stamina() - released_at) < 0.01,
		"[2] continua parada a ~0,85 s (%.2f)" % _player.get_stamina()
	)
	await _wait_recovery_delay()
	var recovering_from: float = _player.get_stamina()
	await _frames(60)
	var walk_gain: float = _player.get_stamina() - recovering_from
	_expect(
		is_equal_approx(_player.get_recovery_delay_left(), 0.0),
		"[2] atraso termina depois de ~1 s"
	)
	_expect(
		absf(walk_gain - _player.stamina_recovery_rate) < 4.0,
		"[2] recupera ~15/s depois do atraso (%.1f)" % walk_gain
	)

	# [3] Esgotamento com SHIFT pressionado: 0% permanece 0%.
	_player.set_stamina(5.0)
	_player.set_sprint_allowed(true)
	Input.action_press("move_forward")
	Input.action_press("move_sprint")
	var zero_seen: bool = false
	for index: int in 60:
		await get_tree().physics_frame
		if _player.get_stamina() <= 0.0:
			zero_seen = true
			break
	_expect(zero_seen, "[3] stamina chega a 0 correndo")
	_expect(not _player.is_sprint_allowed(), "[3] corrida bloqueada ao esgotar")
	await _frames(180)
	_expect(
		is_equal_approx(_player.get_stamina(), 0.0),
		"[3] 3 s com SHIFT pressionado mantêm 0%% (%.2f)" % _player.get_stamina()
	)
	_expect(
		_player.get_recovery_delay_left() > 0.9,
		"[3] atraso permanece cheio enquanto SHIFT está pressionado"
	)

	# [4] Soltar SHIFT após esgotar: 1 s parado e depois recupera.
	Input.action_release("move_forward")
	Input.action_release("move_sprint")
	await _frames(2)
	_expect(
		is_equal_approx(_player.get_stamina(), 0.0),
		"[4] continua 0 ao soltar SHIFT"
	)
	await _frames(30)
	_expect(
		is_equal_approx(_player.get_stamina(), 0.0),
		"[4] nada recupera nos primeiros 0,5 s"
	)
	await _wait_recovery_delay()
	await _frames(60)
	var recovered: float = _player.get_stamina()
	_expect(recovered > 10.0, "[4] recupera depois do atraso (%.1f)" % recovered)
	_expect(
		absf(recovered - _player.stamina_recovery_rate) < 6.0,
		"[4] recuperação ≈ 15/s (%.1f)" % recovered
	)

	# [5] SHIFT durante o atraso.
	# (a) com stamina suficiente: cancela o atraso e volta a correr.
	await _wait_recovery_delay()
	_player.set_stamina(90.0)
	Input.action_press("move_forward")
	Input.action_press("move_sprint")
	await _frames(20)
	Input.action_release("move_sprint")
	await _frames(6)
	var delay_running: float = _player.get_stamina()
	_expect(_player.get_recovery_delay_left() > 0.5, "[5] atraso em andamento")
	Input.action_press("move_sprint")
	await _frames(10)
	_expect_state(PlayerController.MovementState.RUNNING, "[5] SHIFT no atraso volta a correr")
	_expect(
		_player.get_stamina() < delay_running,
		"[5] corrida consome de novo, sem recuperação escondida"
	)
	# (b) sem stamina suficiente: nada recupera enquanto SHIFT está pressionado.
	Input.action_release("move_forward")
	Input.action_release("move_sprint")
	await _frames(2)
	_player.set_stamina(10.0)
	Input.action_press("move_sprint")
	await _frames(2)
	var blocked_at: float = _player.get_stamina()
	await _frames(60)
	_expect(
		is_equal_approx(_player.get_stamina(), blocked_at),
		"[5] SHIFT no atraso não recupera stamina (%.1f)" % _player.get_stamina()
	)
	_expect_state(PlayerController.MovementState.IDLE, "[5] sem stamina suficiente não corre")
	Input.action_release("move_sprint")
	await _wait_recovery_delay()
	await _frames(30)
	_expect(
		_player.get_stamina() > blocked_at,
		"[5] soltar SHIFT libera a recuperação"
	)

	# [6] Recuperação completa: 0 → 100 sem ultrapassar.
	_player.set_stamina(0.0)
	await _wait_recovery_delay()
	var over_max: bool = false
	for index: int in 420:
		await get_tree().physics_frame
		if _player.get_stamina() > _player.max_stamina + 0.0001:
			over_max = true
	_expect(
		is_equal_approx(_player.get_stamina(), _player.max_stamina),
		"[6] recupera até o máximo (%.1f)" % _player.get_stamina()
	)
	_expect(not over_max, "[6] nunca ultrapassa 100")
	_expect(
		absf(_player.get_stamina_ratio() - 1.0) < 0.0001,
		"[6] razão volta a 1,0"
	)
	_expect(_player.is_sprint_allowed(), "[6] corrida liberada novamente")

	# [7] Pausa e configurações congelam stamina e atraso.
	_player.set_stamina(60.0)
	Input.action_press("move_forward")
	Input.action_press("move_sprint")
	await _frames(12)
	Input.action_release("move_sprint")
	Input.action_release("move_forward")
	await _frames(2)
	var delay_before_pause: float = _player.get_recovery_delay_left()
	var stamina_before_pause: float = _player.get_stamina()
	_expect(delay_before_pause > 0.5, "[7] atraso ativo antes da pausa")
	_scene.pause_session()
	await _frames(4)
	await _frames(120)
	_expect(
		is_equal_approx(_player.get_stamina(), stamina_before_pause),
		"[7] pausa não recupera stamina (%.1f)" % _player.get_stamina()
	)
	_expect(
		absf(_player.get_recovery_delay_left() - delay_before_pause) < 0.0001,
		"[7] pausa não avança o atraso (%.2f s)" % _player.get_recovery_delay_left()
	)
	_scene.open_settings()
	await _frames(120)
	_expect(
		is_equal_approx(_player.get_stamina(), stamina_before_pause),
		"[7] configurações não recuperam stamina"
	)
	_expect(
		absf(_player.get_recovery_delay_left() - delay_before_pause) < 0.0001,
		"[7] configurações não avançam o atraso"
	)
	_scene.close_settings()
	await _frames(6)
	_scene.resume_session()
	await _frames(6)
	_expect(
		absf(_player.get_stamina() - stamina_before_pause) < 1.5,
		"[7] retoma do mesmo valor (%.1f)" % _player.get_stamina()
	)
	_expect(
		_player.get_recovery_delay_left() <= delay_before_pause + 0.2,
		"[7] atraso continua de onde parou (%.2f s)" % _player.get_recovery_delay_left()
	)
	await _wait_recovery_delay()

	# [8] Agachamento: não consome, não recupera com SHIFT, recupera sem ele.
	await _set_crouch_mode("toggle")
	await _place(Vector3(0, 0.05, 0), 0.0)
	await _wait_recovery_delay()
	_player.set_stamina(50.0)
	await _tap_crouch()
	await _frames(10)
	_expect(_player.is_crouched(), "[8] ALTERNAR agacha")
	_expect_state(PlayerController.MovementState.CROUCHING, "[8] estado AGACHADO")
	Input.action_press("move_forward")
	await _frames(6)
	var crouched_value: float = _player.get_stamina()
	Input.action_press("move_sprint")
	await _frames(30)
	_expect(
		is_equal_approx(_player.get_stamina(), crouched_value),
		"[8] agachado não consome e SHIFT não recupera (%.1f)" % _player.get_stamina()
	)
	Input.action_release("move_sprint")
	await _wait_recovery_delay()
	var crouch_from: float = _player.get_stamina()
	await _frames(30)
	_expect(_player.get_stamina() > crouch_from, "[8] agachado recupera depois do atraso")
	Input.action_release("move_forward")
	await _tap_crouch()
	await _frames(10)
	_expect(not _player.is_crouched(), "[8] ALTERNAR levanta")
	await _set_crouch_mode("hold")
	Input.action_press("move_crouch")
	await _frames(10)
	_expect(_player.is_crouched(), "[8] SEGURAR agacha")
	Input.action_release("move_crouch")
	await _frames(10)
	_expect(not _player.is_crouched(), "[8] SEGURAR levanta")
	await _set_crouch_mode("hold")

	# [9] HUD continua refletindo a stamina real.
	await _place(Vector3(0, 0.05, 0), 0.0)
	await _wait_recovery_delay()
	_player.set_stamina(75.0)
	var hud: PlayerHud = _scene.get_hud()
	var bar: StaminaBar = hud.get_stamina_bar() if hud != null else null
	_expect(bar != null, "[9] HUD disponível")
	if bar == null:
		return
	_expect(bar.get_value_text() == "75%", "[9] HUD mostra 75%")
	Input.action_press("move_forward")
	Input.action_press("move_sprint")
	await _frames(60)
	_expect(
		absf(bar.get_ratio() - _player.get_stamina_ratio()) < 0.0001,
		"[9] barra acompanha a corrida"
	)
	Input.action_release("move_sprint")
	await _frames(45)
	_expect(
		absf(bar.get_ratio() - _player.get_stamina_ratio()) < 0.0001,
		"[9] barra parada durante o atraso"
	)
	await _wait_recovery_delay()
	await _frames(30)
	_expect(
		bar.get_ratio() > 0.0 and absf(bar.get_ratio() - _player.get_stamina_ratio()) < 0.0001,
		"[9] barra acompanha a recuperação"
	)
	_expect(bar.get_ratio() <= 1.0, "[9] barra nunca passa de 100%")
	_expect(bar.get_value_text() == "%d%%" % roundi(_player.get_stamina_ratio() * 100.0),
		"[9] texto acompanha a stamina real (%s)" % bar.get_value_text())
	Input.action_release("move_forward")
	Input.action_release("move_sprint")
	await _frames(6)

# --- Interação (Etapa 7) ----------------------------------------------------

const INTERACTION_PANEL_SCENE := "res://maps/scenes/interaction_test_panel.tscn"
const INTERACTION_VIEW := Vector3(1.6, 0.05, 8.2)
const INTERACTION_PITCH := -0.18


func _test_interaction() -> void:
	print("[22] Interação (Etapa 7)")
	if _scene.is_settings_open():
		_scene.close_settings()
	if _scene.is_paused():
		_scene.resume_session()
	await _set_crouch_mode("hold")
	# Estado neutro: em pé e com stamina cheia (parada, sem recuperação
	# escondida) para comparar o valor antes/depois de interagir.
	if _player.is_crouched():
		await _tap_crouch()
		await _frames(10)
	_player.set_stamina(_player.max_stamina)
	await _wait_recovery_delay()

	var detector: InteractionDetector = _player.get_interaction_detector()
	_expect(detector != null, "detector de interação existe na câmera do jogador")
	if detector == null:
		return

	var hud: PlayerHud = _scene.get_hud()
	var prompt: InteractionPrompt = hud.get_interaction_prompt() if hud != null else null
	var panel: InteractionTestPanel = _scene.get_node_or_null(
		"InteractionPanel"
	) as InteractionTestPanel
	_expect(panel != null, "painel de teste presente na cena da partida")
	if panel == null or prompt == null:
		return

	# --- Configuração do sistema -------------------------------------------
	_expect(is_equal_approx(detector.interaction_distance, 2.5), "distância máxima = 2,5 m")
	_expect(
		is_equal_approx(detector.get_interaction_distance(), 2.5),
		"distância exposta por get_interaction_distance()"
	)
	_expect(InputMap.has_action("interact"), "ação interact existe no InputMap")
	var interact_key: int = 0
	for event: InputEvent in InputMap.action_get_events("interact"):
		var key := event as InputEventKey
		if key != null:
			interact_key = key.physical_keycode if key.physical_keycode != 0 else key.keycode
	_expect(interact_key == KEY_E, "E é a tecla padrão de interact")
	var detector_source: String = FileAccess.get_file_as_string(
		"res://players/scripts/interaction/interaction_detector.gd"
	)
	_expect(
		not detector_source.contains("KEY_E") and not detector_source.contains("is_key_pressed"),
		"detector usa a ação do InputMap (nenhuma tecla codificada)"
	)
	_expect(
		detector_source.contains("Interactable"),
		"detector resolve o foco pelo contrato Interactable"
	)
	_expect(
		not detector_source.contains("is Porta") and not detector_source.contains("is Door"),
		"detector não conhece tipos de objeto"
	)

	# --- Detecção -----------------------------------------------------------
	await _place(INTERACTION_VIEW, 0.0)
	_player.set_look(0.0, INTERACTION_PITCH)
	await _frames(6)
	_expect(
		detector.get_current_interactable() == panel,
		"objeto interativo dentro do alcance é detectado"
	)
	_expect(prompt.visible and prompt.is_shown(), "indicação aparece com objeto válido")
	_expect(prompt.get_prompt_text() == "Interagir", "indicação mostra o texto do objeto")
	_expect(prompt.get_key_text() == "E", "indicação mostra a tecla E")
	_expect(prompt.mouse_filter == Control.MOUSE_FILTER_IGNORE, "indicação não captura o mouse")

	# Posição e tamanho da indicação.
	var viewport: Vector2 = hud.get_viewport_rect().size
	var panel_rect: Rect2 = prompt.get_panel_rect()
	_expect(panel_rect.position.y > viewport.y * 0.6, "indicação no terço inferior (%.0f)" % panel_rect.position.y)
	_expect(
		absf(panel_rect.get_center().x - viewport.x * 0.5) < 2.0,
		"indicação centralizada (centro em %.0f de %.0f)" % [panel_rect.get_center().x, viewport.x]
	)
	_expect(
		panel_rect.end.x <= viewport.x and panel_rect.end.y <= viewport.y,
		"indicação dentro da tela"
	)
	_expect(panel_rect.size.x < viewport.x * 0.5, "indicação compacta (%.0f px)" % panel_rect.size.x)
	var prompt_id: int = prompt.get_instance_id()

	# --- Execução -----------------------------------------------------------
	var stamina_before: float = _player.get_stamina()
	var before: int = panel.get_interaction_count()
	Input.action_press("interact")
	await _frames(4)
	Input.action_release("interact")
	await _frames(2)
	_expect(panel.get_interaction_count() == before + 1, "E executa interact() do objeto")
	_expect(panel.is_feedback_visible(), "objeto mostra a confirmação da interação")
	_expect(
		panel.get_feedback_text() == "INTERAÇÃO EXECUTADA",
		"texto de retorno do objeto (%s)" % panel.get_feedback_text()
	)
	_expect(
		is_equal_approx(_player.get_stamina(), stamina_before),
		"interagir não altera a stamina (%.1f)" % _player.get_stamina()
	)
	var bar: StaminaBar = hud.get_stamina_bar()
	_expect(
		bar != null and absf(bar.get_ratio() - _player.get_stamina_ratio()) < 0.001,
		"HUD de stamina continua refletindo o valor real"
	)

	# Teclas que não interagem.
	var count_after_keys: int = panel.get_interaction_count()
	for action: String in ["move_forward", "move_sprint", "move_crouch"]:
		Input.action_press(action)
		await _frames(3)
		Input.action_release(action)
		await _frames(2)
	_expect(
		panel.get_interaction_count() == count_after_keys,
		"outras ações não executam a interação"
	)

	# A indicação não bloqueia o movimento.
	await _place(Vector3(1.6, 0.05, 8.6), 0.0)
	_player.set_look(0.0, -0.19)
	await _frames(6)
	_expect(detector.get_current_interactable() == panel, "focado antes do teste de movimento")
	var move_from: Vector3 = _player.global_position
	Input.action_press("move_forward")
	await _frames(20)
	Input.action_release("move_forward")
	await _frames(4)
	var moved: float = Vector2(
		_player.global_position.x - move_from.x, _player.global_position.z - move_from.z
	).length()
	_expect(moved > 0.3, "indicação não bloqueia o movimento (%.2f m)" % moved)

	# --- Fora do alcance ----------------------------------------------------
	await _place(Vector3(1.6, 0.05, 10.6), 0.0)
	_player.set_look(0.0, -0.14)
	await _frames(6)
	_expect(detector.get_current_interactable() == null, "objeto fora do alcance não é detectado")
	_expect(not prompt.visible, "indicação desaparece fora do alcance")
	var count_out: int = panel.get_interaction_count()
	_expect(not detector.try_interact(), "try_interact() falha sem alvo no alcance")
	await _frames(2)
	_expect(panel.get_interaction_count() == count_out, "interação não acontece fora do alcance")

	# --- Linha de visão bloqueada ------------------------------------------
	await _place(INTERACTION_VIEW, 0.0)
	_player.set_look(0.0, INTERACTION_PITCH)
	await _frames(6)
	_expect(
		detector.get_current_interactable() == panel,
		"volta a detectar ao voltar ao alcance"
	)

	var wall := StaticBody3D.new()
	wall.name = "TestInteractionWall"
	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(2.0, 2.0, 0.2)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	_scene.add_child(wall)
	wall.global_position = Vector3(1.6, 1.4, 7.2)
	await _frames(6)
	_expect(detector.get_current_interactable() == null, "parede bloqueia a linha de visão")
	_expect(not prompt.visible, "indicação desaparece com obstáculo")
	Input.action_press("interact")
	await _frames(4)
	Input.action_release("interact")
	await _frames(2)
	_expect(panel.get_interaction_count() == count_out, "interação não acontece através da parede")
	wall.queue_free()
	await _frames(6)
	_expect(detector.get_current_interactable() == panel, "foco volta quando a parede sai")

	# --- Olhar para o vazio e para objeto não interativo --------------------
	_player.set_look(0.0, 0.6)
	await _frames(6)
	_expect(detector.get_current_interactable() == null, "olhar para o vazio remove o foco")
	_expect(not prompt.visible, "indicação desaparece ao olhar para o vazio")

	await _place(Vector3(0, 0.05, -10.0), 0.0)
	_player.set_look(0.0, -0.1)
	await _frames(6)
	_expect(
		detector.get_current_interactable() == null,
		"objeto não interativo (parede) não vira foco"
	)

	# --- Outro objeto e texto dinâmico --------------------------------------
	var panel_scene: PackedScene = load(INTERACTION_PANEL_SCENE) as PackedScene
	var second: InteractionTestPanel = panel_scene.instantiate() as InteractionTestPanel
	_expect(second != null, "painel de teste é reutilizável (segunda instância)")
	if second != null:
		second.interaction_text = "Examinar"
		_scene.add_child(second)
		second.global_position = Vector3(4.5, 0.0, 6.2)
		await _frames(4)
		await _place(Vector3(4.5, 0.05, 8.2), 0.0)
		_player.set_look(0.0, INTERACTION_PITCH)
		await _frames(6)
		_expect(detector.get_current_interactable() == second, "olhar para outro objeto muda o foco")
		_expect(prompt.get_prompt_text() == "Examinar", "texto acompanha o objeto focado")
		_expect(
			prompt.get_instance_id() == prompt_id,
			"indicação é o mesmo nó (nada instanciado por frame)"
		)
		var prompt_count: int = 0
		for child: Node in hud.find_children("*", "Control", true, false):
			if child is InteractionPrompt:
				prompt_count += 1
		_expect(prompt_count == 1, "existe uma única indicação na HUD (%d)" % prompt_count)

		second.set_interaction_enabled(false)
		await _frames(6)
		_expect(
			detector.get_current_interactable() == null,
			"objeto desativado deixa de ser interativo"
		)
		_expect(not prompt.visible, "indicação some quando o objeto deixa de ser interativo")
		second.set_interaction_enabled(true)
		await _frames(6)
		_expect(detector.get_current_interactable() == second, "objeto reativado volta a ser focado")
		await _place(Vector3(0, 0.05, 0), 0.0)
		_player.set_look(0.0, 0.0)
		await _frames(4)
		second.queue_free()
		await _frames(6)
	_expect(not prompt.visible, "indicação some ao remover o objeto")

	# --- Pausa --------------------------------------------------------------
	await _place(INTERACTION_VIEW, 0.0)
	_player.set_look(0.0, INTERACTION_PITCH)
	await _frames(6)
	_expect(detector.get_current_interactable() == panel, "focado antes da pausa")
	var count_pause: int = panel.get_interaction_count()
	_scene.pause_session()
	await _frames(6)
	_expect(not prompt.visible, "indicação fica oculta na pausa")
	_expect(
		detector.get_current_interactable() == panel,
		"foco preservado durante a pausa"
	)
	Input.action_press("interact")
	await _frames(6)
	Input.action_release("interact")
	await _frames(2)
	_expect(panel.get_interaction_count() == count_pause, "E não interage durante a pausa")
	_expect(not detector.try_interact(), "try_interact() bloqueado na pausa")

	_scene.open_settings()
	await _frames(6)
	_scene.close_settings()
	await _frames(4)
	_expect(panel.get_interaction_count() == count_pause, "configurações não executam interação")

	_scene.resume_session()
	await _frames(8)
	_expect(prompt.visible, "indicação volta após CONTINUAR")
	Input.action_press("interact")
	await _frames(4)
	Input.action_release("interact")
	await _frames(2)
	_expect(
		panel.get_interaction_count() == count_pause + 1,
		"interação funciona de novo após CONTINUAR"
	)

	# --- Ancoragem (independe da resolução) --------------------------------
	var panel_node: PanelContainer = prompt.get_node_or_null("Panel") as PanelContainer
	_expect(panel_node != null, "indicação tem painel próprio")
	if panel_node != null:
		_expect(
			is_equal_approx(panel_node.anchor_left, 0.5)
				and is_equal_approx(panel_node.anchor_right, 0.5),
			"indicação ancorada no centro horizontal"
		)
		_expect(
			is_equal_approx(panel_node.anchor_top, 1.0)
				and is_equal_approx(panel_node.anchor_bottom, 1.0),
			"indicação ancorada no rodapé (acima da stamina)"
		)
		_expect(
			panel_node.offset_top < 0.0 and absf(panel_node.offset_top) < viewport.y * 0.25,
			"indicação fica a %.0f px do rodapé" % absf(panel_node.offset_top)
		)
	_expect(
		is_equal_approx(hud.anchor_right, 1.0) and is_equal_approx(hud.anchor_bottom, 1.0),
		"HUD ocupa a tela inteira (indicação acompanha a resolução)"
	)
	_expect(
		prompt.get_panel_rect().size.y < viewport.y * 0.2,
		"indicação compacta (altura %.0f px)" % prompt.get_panel_rect().size.y
	)

	# --- Estado final limpo -------------------------------------------------
	Input.action_release("interact")
	await _place(Vector3(0, 0.05, 0), 0.0)
	_player.set_look(0.0, 0.0)
	await _frames(4)
	_player.set_stamina(_player.max_stamina)
	await _frames(2)

# --- Inventário (Etapa 8) ---------------------------------------------------

const INVENTORY_TEST_ITEM_SCENE := "res://items/scenes/inventory_test_item.tscn"
const ITEM_PITCH := -0.34

## De onde olhar para cada item de teste (mesmo x, 1,6 m ao sul do item).
const ITEM_VIEWS := {
	"TestItemA": Vector3(-1.7, 0.05, 7.7),
	"TestItemB": Vector3(-3.1, 0.05, 6.9),
	"TestItemC": Vector3(-4.2, 0.05, 5.9),
	"TestItemD": Vector3(-1.3, 0.05, 5.5),
}


func _test_inventory() -> void:
	print("[23] Inventário (Etapa 8)")
	if _scene.is_settings_open():
		_scene.close_settings()
	if _scene.is_paused():
		_scene.resume_session()
	await _set_crouch_mode("hold")
	if _player.is_crouched():
		await _tap_crouch()
		await _frames(10)

	# --- Ações do InputMap --------------------------------------------------
	var expected_actions := {
		"inventory_slot_1": KEY_1,
		"inventory_slot_2": KEY_2,
		"inventory_slot_3": KEY_3,
		"inventory_remove": KEY_R,
	}
	for action: String in expected_actions:
		_expect(InputMap.has_action(action), "ação '%s' existe" % action)
		var found: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key == null:
				continue
			var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
			if code == expected_actions[action]:
				found = true
		_expect(
			found,
			"ação '%s' usa %s" % [action, OS.get_keycode_string(expected_actions[action])]
		)
	_expect(
		InventoryInput.ACTION_SELECT_SLOTS.size() == Inventory.SLOT_COUNT,
		"uma ação de seleção por slot (%d)" % InventoryInput.ACTION_SELECT_SLOTS.size()
	)
	var inventory_source: String = FileAccess.get_file_as_string(
		"res://players/scripts/inventory/inventory_input.gd"
	)
	_expect(
		not inventory_source.contains("is_key_pressed") and not inventory_source.contains("KEY_1"),
		"entrada do inventário usa o InputMap (nenhuma tecla codificada)"
	)

	# --- API do inventário (isolado da cena) --------------------------------
	_expect(Inventory.SLOT_COUNT == 3, "inventário tem exatamente 3 slots (constante)")
	var inventory: Inventory = Inventory.new()
	add_child(inventory)
	await _frames(2)
	_expect(inventory.get_slot_count() == 3, "três slots criados (%d)" % inventory.get_slot_count())
	_expect(inventory.get_selected_slot() == 0, "slot 1 selecionado ao começar")
	_expect(inventory.get_selected_item() == null, "slot selecionado começa vazio")
	_expect(inventory.has_free_slot(), "inventário começa com slot livre")
	_expect(inventory.get_used_slot_count() == 0, "inventário começa vazio")
	_expect(not inventory.is_processing(), "inventário não processa nada por frame")

	var counts := {"added": 0, "removed": 0, "replaced": 0, "rejected": 0, "changed": 0}
	inventory.item_added.connect(func(_i: int, _it: ItemDefinition) -> void: counts.added += 1)
	inventory.item_removed.connect(func(_i: int, _it: ItemDefinition) -> void: counts.removed += 1)
	inventory.item_replaced.connect(
		func(_i: int, _p: ItemDefinition, _c: ItemDefinition) -> void: counts.replaced += 1
	)
	inventory.item_rejected.connect(func(_it: ItemDefinition) -> void: counts.rejected += 1)
	inventory.inventory_changed.connect(func() -> void: counts.changed += 1)

	var item_a := ItemDefinition.new(&"item_a", "ITEM A")
	var item_b := ItemDefinition.new(&"item_b", "ITEM B")
	var item_c := ItemDefinition.new(&"item_c", "ITEM C")
	var item_d := ItemDefinition.new(&"item_d", "ITEM D")
	_expect(item_a.get_display_name() == "ITEM A", "item tem nome de exibição")
	_expect(item_a.is_valid() and not ItemDefinition.new().is_valid(), "item sem id é inválido")
	_expect(not inventory.add_item(null), "item nulo é recusado")

	_expect(inventory.add_item(item_a), "adiciona o item A")
	_expect(inventory.get_item(0) == item_a, "A vai para o primeiro slot")
	_expect(inventory.find_first_free_slot() == 1, "primeiro slot livre passa a ser o 2")
	_expect(inventory.add_item(item_b), "adiciona o item B")
	_expect(inventory.get_item(1) == item_b, "B vai para o segundo slot")
	_expect(inventory.add_item(item_c), "adiciona o item C")
	_expect(inventory.get_item(2) == item_c, "C vai para o terceiro slot")
	_expect(not inventory.has_free_slot(), "sem slot livre com os três ocupados")
	_expect(counts.added == 3 and counts.changed == 3, "sinais de adição emitidos (%d)" % counts.added)

	var before_full: Array = [inventory.get_item(0), inventory.get_item(1), inventory.get_item(2)]
	_expect(not inventory.add_item(item_d), "inventário cheio recusa o item D")
	_expect(counts.rejected == 1, "sinal item_rejected emitido")
	_expect(
		inventory.get_item(0) == before_full[0]
			and inventory.get_item(1) == before_full[1]
			and inventory.get_item(2) == before_full[2],
		"inventário cheio não altera nem substitui nenhum item"
	)

	_expect(inventory.select_slot(1), "seleciona o slot 2")
	_expect(inventory.get_selected_slot() == 1, "slot 2 é o selecionado")
	_expect(inventory.get_selected_item() == item_b, "item selecionado é o B")
	_expect(not inventory.select_slot(3), "índice fora da faixa é recusado")
	_expect(not inventory.select_slot(-1), "índice negativo é recusado")
	_expect(inventory.get_selected_slot() == 1, "seleção inválida não muda o slot")

	_expect(inventory.remove_item(1), "remove o item do slot 2")
	_expect(inventory.is_slot_empty(1), "slot removido fica vazio")
	_expect(inventory.get_item(1) == null, "slot removido devolve null")
	_expect(not inventory.remove_item(1), "remover slot já vazio devolve false")
	_expect(inventory.get_used_slot_count() == 2, "dois slots ocupados após a remoção")
	_expect(counts.removed == 1, "sinal item_removed emitido")
	_expect(inventory.select_slot(1), "seleciona um slot vazio")
	_expect(inventory.get_selected_item() == null, "slot vazio selecionado devolve null")

	_expect(inventory.replace_item(0, item_d), "substitui o item do slot 1")
	_expect(inventory.get_item(0) == item_d, "slot 1 passa a ter o item D")
	var still_has_a: bool = false
	for index: int in inventory.get_slot_count():
		if inventory.get_item(index) == item_a:
			still_has_a = true
	_expect(not still_has_a, "item substituído não fica em outro slot")
	_expect(not inventory.replace_item(0, null), "substituir por null é recusado")
	_expect(inventory.get_item(0) == item_d, "slot preservado após substituição inválida")
	_expect(counts.replaced == 1, "sinal item_replaced emitido")

	var slot_one: InventorySlot = inventory.get_slot(0)
	_expect(slot_one != null and slot_one.get_item() == item_d, "get_slot() expõe o slot")
	_expect(slot_one.get_display_name() == "ITEM D", "slot informa o nome do item")
	inventory.clear()
	_expect(inventory.get_used_slot_count() == 0, "clear() esvazia todos os slots")
	remove_child(inventory)
	inventory.free()

	# --- Objetos de teste na cena ------------------------------------------
	var hud: PlayerHud = _scene.get_hud()
	var player_inventory: Inventory = _player.get_inventory()
	_expect(player_inventory != null, "jogador tem inventário")
	_expect(
		hud != null and hud.get_inventory_bar() != null,
		"HUD tem a barra de slots"
	)
	_expect(hud != null and hud.is_inventory_bound(), "HUD ligada ao inventário")
	var bar: InventoryBar = hud.get_inventory_bar() if hud != null else null
	var prompt: InteractionPrompt = hud.get_interaction_prompt() if hud != null else null
	if player_inventory == null or bar == null or prompt == null:
		return

	_expect(bar.get_slot_count() == 3, "HUD desenha exatamente 3 slots (%d)" % bar.get_slot_count())
	_expect(
		bar.get_number_text(0) == "1" and bar.get_number_text(1) == "2" and bar.get_number_text(2) == "3",
		"slots numerados 1, 2 e 3"
	)
	_expect(bar.get_slot_text(0) == "VAZIO", "slot vazio mostra VAZIO")
	_expect(bar.is_slot_selected(0), "slot 1 começa selecionado")

	var item_scene: PackedScene = load(INVENTORY_TEST_ITEM_SCENE) as PackedScene
	_expect(item_scene != null, "cena do item de teste carrega")
	var items := {
		"TestItemA": _scene.get_node_or_null("TestItemA") as InventoryTestItem,
		"TestItemB": _scene.get_node_or_null("TestItemB") as InventoryTestItem,
		"TestItemC": _scene.get_node_or_null("TestItemC") as InventoryTestItem,
		"TestItemD": _scene.get_node_or_null("TestItemD") as InventoryTestItem,
	}
	for item_name: String in items:
		var test_item: InventoryTestItem = items[item_name]
		_expect(test_item != null, "%s presente na cena" % item_name)
		if test_item != null:
			_expect(test_item.get_item() != null, "%s tem definição de item" % item_name)
			_expect(not test_item.is_collected(), "%s começa disponível" % item_name)
			_expect(
				test_item.interaction_text == "Pegar",
				"%s pede [E] Pegar" % item_name
			)

	# --- Posição da HUD -----------------------------------------------------
	var viewport: Vector2 = hud.get_viewport_rect().size
	var bar_rect: Rect2 = bar.get_global_rect()
	_expect(
		bar_rect.position.x > viewport.x * 0.5,
		"slots no canto inferior direito (x=%.0f de %.0f)" % [bar_rect.position.x, viewport.x]
	)
	_expect(bar_rect.position.y > viewport.y * 0.6, "slots na parte inferior da tela")
	_expect(
		bar_rect.end.x <= viewport.x and bar_rect.end.y <= viewport.y,
		"slots dentro da tela"
	)
	var stamina_rect: Rect2 = hud.get_stamina_bar().get_global_rect()
	_expect(
		bar_rect.position.x >= stamina_rect.end.x,
		"slots não se sobrepõem à stamina (%.0f ≥ %.0f)" % [bar_rect.position.x, stamina_rect.end.x]
	)
	var prompt_rect: Rect2 = prompt.get_panel_rect()
	_expect(
		not bar_rect.intersects(prompt_rect),
		"slots não se sobrepõem à indicação de interação"
	)

	# --- Coleta do item A ---------------------------------------------------
	await _place(ITEM_VIEWS["TestItemA"], 0.0)
	_player.set_look(0.0, ITEM_PITCH)
	await _frames(8)
	var item_a_node: InventoryTestItem = items["TestItemA"]
	_expect(
		_player.get_interaction_detector().get_current_interactable() == item_a_node,
		"item A é detectado pelo olhar"
	)
	_expect(prompt.visible and prompt.get_prompt_text() == "Pegar", "indicação mostra Pegar")

	var stamina_before: float = _player.get_stamina()
	await _tap_action("interact")
	_expect(item_a_node.is_collected(), "E coleta o item A")
	_expect(not item_a_node.visible, "item coletado desaparece da cena")
	_expect(player_inventory.get_item(0) == item_a_node.get_item(), "item A vai para o slot 1")
	_expect(
		bar.get_slot_text(0) == "ITEM A",
		"slot 1 mostra ITEM A (%s)" % bar.get_slot_text(0)
	)
	_expect(
		_player.get_interaction_detector().get_current_interactable() == null,
		"item coletado deixa de ser foco"
	)
	_expect(not prompt.visible, "indicação some depois da coleta")
	_expect(
		is_equal_approx(_player.get_stamina(), stamina_before),
		"coletar não altera a stamina (%.1f)" % _player.get_stamina()
	)
	await _tap_action("interact")
	_expect(player_inventory.get_used_slot_count() == 1, "E de novo não duplica o item")

	# --- Demais itens -------------------------------------------------------
	await _place(ITEM_VIEWS["TestItemB"], 0.0)
	_player.set_look(0.0, ITEM_PITCH)
	await _frames(8)
	await _tap_action("interact")
	_expect(items["TestItemB"].is_collected(), "coleta o item B")
	_expect(player_inventory.get_item(1) != null, "item B vai para o slot 2")

	await _place(ITEM_VIEWS["TestItemC"], 0.0)
	_player.set_look(0.0, ITEM_PITCH)
	await _frames(8)
	await _tap_action("interact")
	_expect(items["TestItemC"].is_collected(), "coleta o item C")
	_expect(player_inventory.get_item(2) != null, "item C vai para o slot 3")
	_expect(not player_inventory.has_free_slot(), "os três slots ficam ocupados")
	_expect(
		bar.get_slot_text(2) == "ITEM C",
		"slot 3 mostra ITEM C (%s)" % bar.get_slot_text(2)
	)

	# --- Alcance e linha de visão (o item D ainda está livre) --------------
	var item_d_node: InventoryTestItem = items["TestItemD"]
	await _place(Vector3(-1.3, 0.05, 6.6), 0.0)
	_player.set_look(0.0, -0.2)
	await _frames(8)
	_expect(
		_player.get_interaction_detector().get_current_interactable() == null,
		"item fora do alcance não é detectado"
	)

	var wall := StaticBody3D.new()
	wall.name = "TestInventoryWall"
	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(2.0, 2.0, 0.2)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	_scene.add_child(wall)
	wall.global_position = Vector3(-1.3, 1.4, 4.9)
	await _place(ITEM_VIEWS["TestItemD"], 0.0)
	_player.set_look(0.0, ITEM_PITCH)
	await _frames(8)
	_expect(
		_player.get_interaction_detector().get_current_interactable() == null,
		"parede bloqueia a coleta"
	)
	wall.queue_free()
	await _frames(6)

	# --- Inventário cheio ---------------------------------------------------
	await _place(ITEM_VIEWS["TestItemD"], 0.0)
	_player.set_look(0.0, ITEM_PITCH)
	await _frames(8)
	_expect(
		_player.get_interaction_detector().get_current_interactable() == item_d_node,
		"item D é detectado mesmo com o inventário cheio"
	)
	await _tap_action("interact")
	_expect(not item_d_node.is_collected(), "item D não é coletado com o inventário cheio")
	_expect(item_d_node.visible, "item D continua na cena")
	_expect(item_d_node.get_attempts() == 1, "a tentativa foi registrada")
	_expect(player_inventory.get_used_slot_count() == 3, "os três itens continuam guardados")
	_expect(hud.is_full_message_visible(), "HUD avisa INVENTÁRIO CHEIO")
	_expect(
		hud.get_full_message_text() == "INVENTÁRIO CHEIO",
		"texto do aviso: %s" % hud.get_full_message_text()
	)
	_expect(
		bar.get_slot_text(0) == "ITEM A" and bar.get_slot_text(1) == "ITEM B",
		"itens existentes continuam visíveis na HUD"
	)
	_expect(not player_inventory.has_free_slot(), "inventário continua cheio")

	# --- Seleção ------------------------------------------------------------
	await _tap_action("inventory_slot_2")
	_expect(player_inventory.get_selected_slot() == 1, "tecla 2 seleciona o slot 2")
	_expect(bar.is_slot_selected(1), "HUD realça o slot 2")
	_expect(
		bar.get_slot_panel(1).get_theme_stylebox("panel") != bar.get_slot_panel(0).get_theme_stylebox("panel"),
		"slot selecionado tem estilo próprio"
	)
	await _tap_action("inventory_slot_3")
	_expect(player_inventory.get_selected_slot() == 2, "tecla 3 seleciona o slot 3")
	await _tap_action("inventory_slot_1")
	_expect(player_inventory.get_selected_slot() == 0, "tecla 1 volta ao slot 1")
	_expect(
		player_inventory.get_selected_item() != null
			and player_inventory.get_selected_item() == player_inventory.get_item(0),
		"get_selected_item() acompanha a seleção"
	)
	_expect(bar.get_selected_index() == 0, "barra acompanha a seleção")
	await _frames(150)
	_expect(not hud.is_full_message_visible(), "aviso de inventário cheio desaparece sozinho")

	# --- Pausa (ainda com o item D na mira) --------------------------------
	await _place(ITEM_VIEWS["TestItemD"], 0.0)
	_player.set_look(0.0, ITEM_PITCH)
	await _frames(8)
	_expect(
		_player.get_interaction_detector().get_current_interactable() == item_d_node,
		"item D em foco antes da pausa"
	)
	var used_before_pause: int = player_inventory.get_used_slot_count()
	var selected_before_pause: int = player_inventory.get_selected_slot()

	_scene.pause_session()
	await _frames(6)
	await _tap_action("inventory_slot_3")
	_expect(
		player_inventory.get_selected_slot() == selected_before_pause,
		"teclas 1/2/3 não mudam a seleção na pausa"
	)
	await _tap_action("inventory_remove")
	_expect(
		player_inventory.get_used_slot_count() == used_before_pause,
		"R não remove item na pausa"
	)
	_expect(
		_player.get_interaction_detector().get_current_interactable() == item_d_node,
		"foco preservado na pausa"
	)
	await _tap_action("interact")
	_expect(item_d_node.get_attempts() == 1, "E não coleta durante a pausa")
	_expect(not item_d_node.is_collected(), "item D continua na cena após a pausa")

	_scene.open_settings()
	await _frames(6)
	await _tap_action("inventory_slot_2")
	_expect(
		player_inventory.get_selected_slot() == selected_before_pause,
		"configurações também bloqueiam a seleção"
	)
	_scene.close_settings()
	await _frames(4)
	_scene.resume_session()
	await _frames(8)
	await _tap_action("inventory_slot_2")
	_expect(player_inventory.get_selected_slot() == 1, "seleção volta a funcionar após CONTINUAR")

	# --- Remoção (R provisória) --------------------------------------------
	_expect(player_inventory.is_slot_empty(1) == false, "slot 2 ocupado antes da remoção")
	await _tap_action("inventory_remove")
	_expect(player_inventory.is_slot_empty(1), "R remove o item do slot selecionado")
	_expect(bar.get_slot_text(1) == "VAZIO", "slot removido volta a VAZIO na HUD")
	_expect(
		player_inventory.get_selected_slot() == 1,
		"remoção não muda a seleção (slot vazio continua selecionado)"
	)
	await _tap_action("inventory_remove")
	_expect(player_inventory.get_used_slot_count() == 2, "R em slot vazio não remove nada")

	# --- Substituição -------------------------------------------------------
	var replacement := ItemDefinition.new(&"item_d", "ITEM D")
	_expect(player_inventory.replace_item(0, replacement), "substitui o item do slot 1")
	_expect(
		bar.get_slot_text(0) == "ITEM D",
		"slot 1 mostra o item substituto (%s)" % bar.get_slot_text(0)
	)
	_expect(player_inventory.get_used_slot_count() == 2, "substituição não muda a quantidade")

	# --- Coleta do item D depois de liberar um slot ------------------------
	await _place(ITEM_VIEWS["TestItemD"], 0.0)
	_player.set_look(0.0, ITEM_PITCH)
	await _frames(8)
	await _tap_action("interact")
	_expect(item_d_node.is_collected(), "item D é coletado com slot livre")
	_expect(player_inventory.get_used_slot_count() == 3, "slot livre recebeu o item D")
	_expect(
		bar.get_slot_text(1) == "ITEM D",
		"slot 2 mostra o item D (%s)" % bar.get_slot_text(1)
	)
	_expect(
		bar.is_slot_selected(1),
		"slot preenchido continua selecionado"
	)

	# --- Regressão de HUD e movimento --------------------------------------
	_expect(
		absf(hud.get_stamina_bar().get_ratio() - _player.get_stamina_ratio()) < 0.001,
		"HUD de stamina continua coerente"
	)
	var move_from: Vector3 = _player.global_position
	Input.action_press("move_forward")
	await _frames(20)
	Input.action_release("move_forward")
	await _frames(4)
	_expect(
		_player.global_position.distance_to(move_from) > 0.3,
		"movimento continua funcionando"
	)

	# --- Estado final limpo -------------------------------------------------
	player_inventory.clear()
	await _frames(3)
	_expect(bar.get_slot_text(0) == "VAZIO", "HUD volta a VAZIO ao limpar")
	Input.action_release("inventory_remove")
	await _place(Vector3(0, 0.05, 0), 0.0)
	_player.set_look(0.0, 0.0)
	_player.set_stamina(_player.max_stamina)
	await _frames(4)

# --- Soltar itens no ambiente (Etapa 9) -------------------------------------

const WORLD_ITEM_SCENE := "res://items/scenes/world_item.tscn"
## Pontos de drop usados pelos testes (área aberta ao sul da sala).
const DROP_VIEW_A := Vector3(-2.4, 0.05, 9.2)
const DROP_VIEW_B := Vector3(0.0, 0.05, 9.2)
const DROP_VIEW_C := Vector3(2.4, 0.05, 9.2)
const DROP_VIEW_D := Vector3(4.6, 0.05, 9.2)


func _test_drop() -> void:
	print("[24] Soltar itens no ambiente (Etapa 9)")
	_touch("[24] inventário/drop")
	if _scene.is_settings_open():
		_scene.close_settings()
	if _scene.is_paused():
		_scene.resume_session()
	await _set_crouch_mode("hold")
	if _player.is_crouched():
		await _tap_crouch()
		await _frames(10)

	# --- Ação do InputMap ---------------------------------------------------
	_expect(InputMap.has_action("inventory_drop"), "ação 'inventory_drop' existe")
	var drop_is_g: bool = false
	for event: InputEvent in InputMap.action_get_events("inventory_drop"):
		var key := event as InputEventKey
		if key == null:
			continue
		var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
		if code == KEY_G:
			drop_is_g = true
	_expect(drop_is_g, "ação 'inventory_drop' usa G")
	var remove_is_r: bool = false
	for event: InputEvent in InputMap.action_get_events("inventory_remove"):
		var key := event as InputEventKey
		if key == null:
			continue
		var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
		if code == KEY_R:
			remove_is_r = true
	_expect(remove_is_r, "remoção de teste continua em R (não reutilizada)")
	_expect(
		KEY_G != KEY_R and InputMap.action_get_events("inventory_drop").size() > 0,
		"G e R são ações distintas"
	)

	var input_source: String = FileAccess.get_file_as_string(
		"res://players/scripts/inventory/inventory_input.gd"
	)
	var dropper_source: String = FileAccess.get_file_as_string(
		"res://players/scripts/inventory/item_dropper.gd"
	)
	_expect(
		not input_source.contains("is_key_pressed") and not dropper_source.contains("is_key_pressed"),
		"entrada e drop não leem teclas diretamente"
	)
	_expect(
		not input_source.contains("KEY_G") and not dropper_source.contains("KEY_G"),
		"nenhuma tecla codificada no código do drop"
	)

	# --- Componentes --------------------------------------------------------
	_touch("[24] componentes")
	var dropper: ItemDropper = _player.get_item_dropper()
	var hud: PlayerHud = _scene.get_hud()
	var bar: InventoryBar = hud.get_inventory_bar() if hud != null else null
	var inventory: Inventory = _player.get_inventory()
	_expect(dropper != null, "jogador tem o componente que solta itens")
	_expect(_scene.get_item_dropper() == dropper, "a sessão expõe o mesmo componente")
	_expect(hud != null and hud.is_drop_bound(), "HUD ligada ao aviso do drop")
	_expect(load(WORLD_ITEM_SCENE) != null, "cena reutilizável do item no mundo carrega")
	if dropper == null or hud == null or bar == null or inventory == null:
		return
	_expect(dropper.world_item_scene != null, "componente com a cena do item configurada")
	_expect(not dropper.is_processing(), "drop não processa nada por frame")
	var scene_item: WorldItem = load(WORLD_ITEM_SCENE).instantiate() as WorldItem
	_expect(scene_item is Interactable, "item no mundo usa o contrato da Etapa 7")
	_expect(scene_item != null and scene_item.get_node_or_null("Body") is RigidBody3D,
		"item no mundo tem corpo físico")
	_expect(
		scene_item != null and scene_item.get_node_or_null("Body/NameLabel") is Label3D,
		"item no mundo mostra o nome"
	)
	if scene_item != null:
		scene_item.free()

	inventory.clear()
	await _clear_world_items()
	bar.clear_slots()
	await _frames(4)

	# --- Drop do slot 1 -----------------------------------------------------
	_touch("[24] drop do slot 1")
	var item_a := ItemDefinition.new(&"drop_a", "ITEM A")
	var item_b := ItemDefinition.new(&"drop_b", "ITEM B")
	var item_c := ItemDefinition.new(&"drop_c", "ITEM C")
	_expect(inventory.add_item(item_a), "item A no inventário")
	_expect(inventory.add_item(item_b), "item B no inventário")
	_expect(inventory.add_item(item_c), "item C no inventário")
	inventory.select_slot(0)
	await _place(DROP_VIEW_A, 0.0)
	var drops_before: int = dropper.get_drop_count()
	await _tap_action("inventory_drop")
	_expect(dropper.get_drop_count() == drops_before + 1, "G solta o item do slot 1")
	_expect(inventory.is_slot_empty(0), "slot 1 fica vazio")
	_expect(not inventory.is_slot_empty(1) and not inventory.is_slot_empty(2),
		"slots não selecionados continuam intactos")
	_expect(bar.get_slot_text(0) == "VAZIO", "HUD mostra VAZIO no slot 1 na hora")
	_expect(bar.get_slot_text(1) == "ITEM B" and bar.get_slot_text(2) == "ITEM C",
		"HUD preserva os outros slots")
	var world_items: Array = _world_items()
	_expect(world_items.size() == 1, "um item no mundo (%d)" % world_items.size())
	var dropped_a: WorldItem = world_items[0] if world_items.size() == 1 else null
	if dropped_a != null:
		_expect(dropped_a.get_item() == item_a, "o item no mundo é o mesmo que saiu do slot")
		_expect(dropped_a.get_node("Body/NameLabel").text == "ITEM A", "item no mundo mostra ITEM A")
		var spot: Vector3 = dropped_a.global_position
		var to_item: Vector3 = spot - _player.global_position
		to_item.y = 0.0
		_expect(to_item.length() > 0.55, "não nasce dentro da cápsula do jogador (%.2f m)" % to_item.length())
		_expect(to_item.length() < 2.0, "nasce perto do jogador (%.2f m)" % to_item.length())
		_expect(to_item.normalized().dot(Vector3(0, 0, -1)) > 0.5, "nasce à frente da câmera")
		await _frames(40)
		var body: RigidBody3D = dropped_a.get_node("Body")
		_expect(absf(body.global_position.y) < 0.08, "item assenta no chão (y=%.3f)" % body.global_position.y)
		_expect(body.linear_velocity.length() < 0.6, "item não é arremessado")

	# --- Drops dos slots 2 e 3 ---------------------------------------------
	_touch("[24] drops dos slots 2 e 3")
	inventory.select_slot(1)
	await _place(DROP_VIEW_B, 0.0)
	await _tap_action("inventory_drop")
	_expect(inventory.is_slot_empty(1), "G solta o item do slot 2")
	_expect(inventory.is_slot_empty(0), "slot 1 continua vazio")
	_expect(_world_items().size() == 2, "dois itens no mundo")
	inventory.select_slot(2)
	await _place(DROP_VIEW_C, 0.0)
	await _tap_action("inventory_drop")
	_expect(inventory.is_slot_empty(2), "G solta o item do slot 3")
	_expect(inventory.get_used_slot_count() == 0, "inventário vazio depois dos três drops")
	_expect(_world_items().size() == 3, "três itens no mundo (%d)" % _world_items().size())
	var total_items: int = inventory.get_used_slot_count() + _world_items().size()
	_expect(total_items == 3, "nada foi duplicado nem perdido (%d itens)" % total_items)

	# --- Slot vazio não cria nada ------------------------------------------
	_touch("[24] slot vazio")
	inventory.select_slot(1)
	var world_before_empty: int = _world_items().size()
	await _tap_action("inventory_drop")
	_expect(_world_items().size() == world_before_empty, "G em slot vazio não cria item")
	_expect(inventory.get_used_slot_count() == 0, "G em slot vazio não altera o inventário")
	_expect(hud.is_full_message_visible(), "HUD indica SLOT VAZIO")
	_expect(hud.get_full_message_text() == "SLOT VAZIO",
		"texto do aviso: %s" % hud.get_full_message_text())
	await _frames(150)

	# --- Segurar G não repete o drop ---------------------------------------
	_touch("[24] segurar G")
	var item_hold := ItemDefinition.new(&"drop_hold", "ITEM HOLD")
	inventory.add_item(item_hold)
	inventory.select_slot(0)
	await _place(DROP_VIEW_D, 0.0)
	world_before_empty = _world_items().size()
	Input.action_press("inventory_drop")
	await _frames(40)
	Input.action_release("inventory_drop")
	await _frames(4)
	_expect(_world_items().size() == world_before_empty + 1,
		"segurar G solta uma única vez (%d)" % (_world_items().size() - world_before_empty))
	_expect(inventory.get_used_slot_count() == 0, "o item segurado saiu do inventário uma vez")

	# --- Recolher com E -----------------------------------------------------
	_touch("[24] recolher com E")
	var last_item: WorldItem = _find_world_item(&"drop_hold")
	_expect(last_item != null, "o item segurado existe no mundo")
	if last_item == null:
		return
	await _look_at_world_item(last_item)
	_expect(
		_player.get_interaction_detector().get_current_interactable() == last_item,
		"item solto é detectado pelo olhar"
	)
	_expect(
		hud.get_interaction_prompt().is_shown()
			and hud.get_interaction_prompt().get_prompt_text() == "Pegar",
		"indicação mostra Pegar"
	)
	var world_before_pickup: int = _world_items().size()
	await _tap_action("interact")
	_expect(not is_instance_valid(last_item) or last_item.is_queued_for_deletion(),
		"objeto do mundo desaparece depois da coleta")
	_expect(_world_items().size() == world_before_pickup - 1, "um item a menos no mundo")
	_expect(inventory.get_used_slot_count() == 1, "item voltou ao inventário")
	_expect(inventory.get_item(0) == item_hold, "item voltou ao primeiro slot vazio")
	_expect(bar.get_slot_text(0) == "ITEM HOLD", "HUD mostra o item recolhido")

	# --- Inventário cheio impede a coleta -----------------------------------
	_touch("[24] inventário cheio")
	inventory.add_item(ItemDefinition.new(&"fill_1", "ITEM F1"))
	inventory.add_item(ItemDefinition.new(&"fill_2", "ITEM F2"))
	_expect(inventory.get_used_slot_count() == 3, "inventário cheio de novo")
	if _world_items().is_empty():
		_expect(false, "há item solto para testar o inventário cheio")
		return
	var target: WorldItem = _world_items()[0]
	await _stand_near_world_item(target)
	var world_before_full: int = _world_items().size()
	await _tap_action("interact")
	_expect(not target.is_collected(), "inventário cheio não recolhe")
	_expect(_world_items().size() == world_before_full, "objeto continua no mundo")
	_expect(inventory.get_used_slot_count() == 3, "nenhum item do inventário foi removido")
	_expect(hud.is_full_message_visible(), "HUD avisa INVENTÁRIO CHEIO")
	_expect(hud.get_full_message_text() == "INVENTÁRIO CHEIO",
		"texto do aviso cheio: %s" % hud.get_full_message_text())
	await _frames(150)

	# Abrir espaço e tentar de novo.
	var selected_for_remove: int = inventory.get_selected_slot()
	await _tap_action("inventory_remove")
	_expect(inventory.get_used_slot_count() == 2, "R libera um slot (remoção de teste preservada)")
	_expect(selected_for_remove == inventory.get_selected_slot(), "R não muda a seleção")
	await _look_at_world_item(target)
	await _tap_action("interact")
	_expect(not is_instance_valid(target) or target.is_queued_for_deletion(),
		"nova tentativa recolhe depois de abrir espaço")
	_expect(inventory.get_used_slot_count() == 3, "inventário volta a ficar cheio")
	_expect(_world_items().size() == world_before_full - 1, "sem coleta duplicada")

	# --- Posição inválida cancela sem perder o item ------------------------
	_touch("[24] posição inválida")
	var wall := StaticBody3D.new()
	wall.name = "TestDropWall"
	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(2.0, 2.4, 0.2)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	_scene.add_child(wall)
	var used_before_wall: int = inventory.get_used_slot_count()
	var world_before_wall: int = _world_items().size()
	await _place(Vector3(6.0, 0.05, 9.0), 0.0)
	wall.global_position = _player.global_position + Vector3(0.0, 1.2, -0.55)
	await _frames(6)
	await _tap_action("inventory_drop")
	_expect(inventory.get_used_slot_count() == used_before_wall, "drop sem espaço mantém o item")
	_expect(_world_items().size() == world_before_wall, "drop sem espaço não cria objeto")
	_expect(hud.is_full_message_visible(), "HUD avisa SEM ESPAÇO PARA SOLTAR")
	_expect(hud.get_full_message_text() == "SEM ESPAÇO PARA SOLTAR",
		"texto do aviso: %s" % hud.get_full_message_text())
	wall.queue_free()
	await _frames(6)

	# --- Falha de instanciação mantém o item -------------------------------
	_touch("[24] falha de instanciação")
	await _frames(150)
	var scene_backup: PackedScene = dropper.world_item_scene
	dropper.world_item_scene = null
	var drops_before_fail: int = dropper.get_drop_count()
	await _tap_action("inventory_drop")
	_expect(dropper.get_drop_count() == drops_before_fail, "falha de instanciação não conta drop")
	_expect(inventory.get_used_slot_count() == used_before_wall, "falha de instanciação mantém o item")
	_expect(hud.get_full_message_text() == "NÃO FOI POSSÍVEL SOLTAR",
		"texto do aviso de falha: %s" % hud.get_full_message_text())
	_expect(_world_items().size() == world_before_wall, "falha de instanciação não cria objeto")
	dropper.world_item_scene = scene_backup
	await _frames(150)

	# --- Pausa bloqueia G, E, 1/2/3 e R ------------------------------------
	_touch("[24] pausa")
	if _world_items().is_empty():
		_expect(false, "há item solto para testar a pausa")
		return
	var pause_target: WorldItem = _world_items()[0]
	await _stand_near_world_item(pause_target)
	_expect(
		_player.get_interaction_detector().get_current_interactable() == pause_target,
		"item solto em foco antes da pausa"
	)
	var used_before_pause: int = inventory.get_used_slot_count()
	var world_before_pause: int = _world_items().size()
	inventory.select_slot(0)
	var selected_before_pause: int = inventory.get_selected_slot()
	_scene.pause_session()
	await _frames(6)
	await _tap_action("inventory_drop")
	_expect(_world_items().size() == world_before_pause, "G não solta item na pausa")
	_expect(inventory.get_used_slot_count() == used_before_pause, "pausa não mexe no inventário")
	await _tap_action("inventory_slot_3")
	_expect(inventory.get_selected_slot() == selected_before_pause, "1/2/3 bloqueados na pausa")
	await _tap_action("inventory_remove")
	_expect(inventory.get_used_slot_count() == used_before_pause, "R bloqueado na pausa")
	await _tap_action("interact")
	_expect(not pause_target.is_collected(), "E não recolhe na pausa")
	_expect(_world_items().size() == world_before_pause, "nada muda no mundo durante a pausa")
	_scene.resume_session()
	await _frames(8)

	# --- Estado final limpo -------------------------------------------------
	_touch("[24] limpeza final")
	await _clear_world_items()
	inventory.clear()
	bar.clear_slots()
	await _place(Vector3(0, 0.05, 0), 0.0)
	_player.set_look(0.0, 0.0)
	_player.set_stamina(_player.max_stamina)
	await _frames(4)
	_expect(_world_items().is_empty(), "mundo sem itens soltos ao final")
	_expect(load(WORLD_ITEM_SCENE) != null, "cena do item continua carregando após os testes")
	_drop_completed = true


## Itens soltos atualmente na cena (grupo `world_items`).
func _world_items() -> Array:
	var found: Array = []
	for node: Node in get_tree().get_nodes_in_group(WorldItem.WORLD_GROUP):
		if node is WorldItem and is_instance_valid(node) and not node.is_queued_for_deletion():
			found.append(node)
	return found


## Remove os itens soltos da cena (limpeza entre testes).
func _clear_world_items() -> void:
	for node: Node in get_tree().get_nodes_in_group(WorldItem.WORLD_GROUP):
		if is_instance_valid(node):
			node.queue_free()
	await _frames(4)


## Primeiro item solto com o `id` indicado (null se não existir).
func _find_world_item(item_id: StringName) -> WorldItem:
	for node: Node in _world_items():
		var world_item: WorldItem = node as WorldItem
		if world_item != null and world_item.get_item() != null and world_item.get_item().id == item_id:
			return world_item
	return null


## Fica a 1,6 m ao sul do item solto e aponta a câmera para ele.
func _stand_near_world_item(world_item: WorldItem) -> void:
	if world_item == null or not is_instance_valid(world_item):
		return
	var spot: Vector3 = world_item.global_position
	await _place(Vector3(spot.x, 0.05, spot.z + 1.6), 0.0)
	await _look_at_world_item(world_item)


## Aponta a câmera para um item solto e espera o detector atualizar.
func _look_at_world_item(world_item: WorldItem) -> void:
	if world_item == null or not is_instance_valid(world_item):
		return
	var body: Node3D = world_item.get_node_or_null("Body") as Node3D
	var target: Vector3 = body.global_position if body != null else world_item.global_position
	target.y += 0.18
	var camera: Camera3D = _player.get_node_or_null("Head/Camera") as Camera3D
	var eye: Vector3 = camera.global_position if camera != null else _player.global_position
	var delta: Vector3 = target - eye
	var horizontal: float = Vector2(delta.x, delta.z).length()
	_player.set_look(atan2(-delta.x, -delta.z), atan2(delta.y, maxf(horizontal, 0.001)))
	await _frames(10)


## Pressiona e solta uma ação em dois frames (borda lida pelo componente).
func _tap_action(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(3)


# --- Utilidades -------------------------------------------------------------

func _set_crouch_mode(mode: String) -> void:
	if _settings == null:
		return
	var values: Dictionary = _settings.current()
	values[SettingsSchema.SECTION_CONTROLS]["crouch_mode"] = mode
	_settings.apply(values)
	await _frames(3)


## Pressiona e solta CTRL em dois frames (borda detectada pelo controlador).
func _tap_crouch() -> void:
	Input.action_press("move_crouch")
	await _frames(2)
	Input.action_release("move_crouch")
	await _frames(2)


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


## Avança a física até o atraso de recuperação zerar (Shift precisa estar solto).
func _wait_recovery_delay() -> void:
	for index: int in 180:
		if _player.get_recovery_delay_left() <= 0.0:
			return
		await get_tree().physics_frame


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().physics_frame
		# Enquanto os frames andam, o teste está vivo: reinicia o watchdog.
		_touch()


func _expect(condition: bool, description: String) -> void:
	_touch(description)
	_checks += 1
	if condition:
		print("  ✓ " + description)
	else:
		_failures.append(description)
		printerr("  ✗ " + description)


func _test_sprint_release() -> void:
	print("[25] Soltura do SHIFT e corrida presa (revisão da Etapa 11)")
	await _set_crouch_mode("hold")
	await _place(Vector3(0, 0.05, 0), 0.0)
	await _wait_recovery_delay()
	_player.set_stamina(_player.max_stamina)
	_player.reset_sprint_state()
	Input.action_release("move_sprint")

	# [1] Corrida normal com as ações simuladas (caminho dos outros grupos).
	Input.action_press("move_forward")
	Input.action_press("move_sprint")
	await _frames(30)
	_expect_state(PlayerController.MovementState.RUNNING, "[1] SHIFT pressionado corre")
	_expect(_player.is_sprint_held(), "[1] is_sprint_held() verdadeiro")

	# [2] O motor deixa a ação presa, mas chega um evento REAL de soltura:
	#     a corrida precisa desligar na hora. Este é o bug relatado.
	var release := InputEventKey.new()
	release.keycode = KEY_SHIFT
	release.physical_keycode = KEY_SHIFT
	release.pressed = false
	_player._input(release)
	await _frames(4)
	_expect(not _player.is_sprint_held(), "[2] evento de soltura desliga a corrida")
	_expect_state(PlayerController.MovementState.WALKING, "[2] ação presa não mantém RUNNING")
	_expect(
		Input.is_action_pressed("move_sprint"),
		"[2] o teste manteve a ação presa de propósito"
	)
	# Solta de verdade para os próximos passos.
	Input.action_release("move_sprint")
	_player.reset_sprint_state()
	await _frames(3)

	# [3] Caminho real de teclado pelo viewport: pressionar e soltar.
	var press := InputEventKey.new()
	press.keycode = KEY_SHIFT
	press.physical_keycode = KEY_SHIFT
	press.pressed = true
	get_tree().root.push_input(press)
	await _frames(20)
	_expect(_player.is_sprint_held(), "[3] tecla SHIFT pressionada corre")
	_expect_state(PlayerController.MovementState.RUNNING, "[3] estado RUNNING")
	var release_real := InputEventKey.new()
	release_real.keycode = KEY_SHIFT
	release_real.physical_keycode = KEY_SHIFT
	release_real.pressed = false
	get_tree().root.push_input(release_real)
	await _frames(20)
	_expect(not _player.is_sprint_held(), "[3] soltar SHIFT pelo teclado desliga a corrida")
	_expect_state(PlayerController.MovementState.WALKING, "[3] volta a ANDANDO")

	# [4] Pausa: Shift pressionado, menu aberto e a tecla solta com o jogo
	#     parado. Ao retomar, nada de corrida herdada.
	Input.action_press("move_sprint")
	var pause_press := InputEventKey.new()
	pause_press.keycode = KEY_SHIFT
	pause_press.physical_keycode = KEY_SHIFT
	pause_press.pressed = true
	_player._input(pause_press)
	await _frames(10)
	_expect(_player.is_sprint_held(), "[4] corrida ativa antes da pausa")
	_player.movement_enabled = false
	await _frames(6)
	_player._input(release)
	Input.action_release("move_sprint")
	await _frames(6)
	_player.movement_enabled = true
	await _frames(10)
	_expect(not _player.is_sprint_held(), "[4] retomar não herda corrida da pausa")
	_expect_state(PlayerController.MovementState.WALKING, "[4] estado WALKING ao retomar")
	Input.action_release("move_forward")
	_player.reset_sprint_state()
	await _frames(4)


func _finish() -> void:
	_finished = true
	_touch("fim")
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
