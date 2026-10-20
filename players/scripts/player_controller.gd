class_name PlayerController
extends CharacterBody3D
## Controlador em primeira pessoa do Black Sight (Etapa 4 → Etapa 5).
##
## Escopo atual: **andar** (WASD), **correr** (Shift), **agachar** (Ctrl),
## **olhar** com o mouse, **gravidade** e **colisão**. Pulo não existe.
## Stamina, interação e inventário pertencem às próximas etapas — os pontos de
## extensão estão indicados abaixo, mas nada disso está implementado aqui.
##
## Estados (`MovementState`):
##   IDLE      — parado (sem direção pressionada);
##   WALKING   — andando;
##   RUNNING   — andando com Shift (nunca agachado);
##   CROUCHING — agachado (Ctrl), com prioridade sobre Shift.
##
## Integração com a Etapa 3 (fonte única de verdade):
## - sensibilidade horizontal/vertical e inversão do eixo vertical vêm de
##   `GameSettings` (`user://settings.cfg`, via `SettingsSchema`);
## - os valores são lidos ao entrar na cena e reaplicados quando o gerenciador
##   emite `applied`;
## - sem `GameSettings` (teste isolado), usa `SettingsSchema.defaults()`.
##
## O movimento é relativo à orientação horizontal do corpo (`rotation.y`), que é
## girado pelo mouse. A câmera fica no nó `Head` e recebe a inclinação vertical
## (pitch) e a altura dos olhos (que desce ao agachar).

## Estado de movimento. Não há estado de pulo nem de combate.
enum MovementState {
	IDLE,
	WALKING,
	RUNNING,
	CROUCHING,
}

const STATE_NAMES: Dictionary = {
	MovementState.IDLE: "IDLE",
	MovementState.WALKING: "WALKING",
	MovementState.RUNNING: "RUNNING",
	MovementState.CROUCHING: "CROUCHING",
}

const ACTION_FORWARD := "move_forward"
const ACTION_BACK := "move_back"
const ACTION_LEFT := "move_left"
const ACTION_RIGHT := "move_right"
const ACTION_SPRINT := "move_sprint"
const ACTION_CROUCH := "move_crouch"

## Velocidades em metros por segundo. Corrida > caminhada > agachado.
@export var walk_speed: float = 3.2
@export var run_speed: float = 5.6
@export var crouch_speed: float = 1.6

## Quão rápido a velocidade se aproxima da desejada (1/s). Também é a
## desaceleração usada quando não há entrada.
@export var acceleration: float = 22.0

## Radianos por pixel de mouse com multiplicador 1.0 (ajustável por configuração).
@export var mouse_sensitivity_scale: float = 0.0022
## Limite do olhar vertical, em graus (evita a câmera dar uma volta completa).
@export var max_pitch_degrees: float = 89.0

## Altura da cápsula em pé e agachado (metros, com os pés na origem).
@export var standing_height: float = 1.8
@export var crouched_height: float = 1.2
## Altura dos olhos (câmera) em pé e agachado.
@export var standing_eye_height: float = 1.62
@export var crouched_eye_height: float = 1.02
## Quão rápido a câmera acompanha a mudança de altura (1/s).
@export var crouch_blend_speed: float = 12.0

## Quando false, o jogador não responde a WASD, Shift, Ctrl nem ao mouse.
## Usado pela pausa e pelas configurações abertas durante a partida.
var movement_enabled: bool = true

## Ponto de extensão da Etapa 6: com a stamina esgotada, a Etapa 6 poderá
## chamar `set_sprint_allowed(false)`. Nada consome stamina nesta etapa.
var sprint_allowed: bool = true

## Emitido quando o estado muda (para HUD/sons futuros).
signal state_changed(previous: int, current: int)

var _state: MovementState = MovementState.IDLE
var _is_crouched: bool = false

var _gravity: float = 9.8
var _sensitivity_x: float = 1.0
var _sensitivity_y: float = 1.0
var _invert_y: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
var _skip_next_motion: bool = false
var _settings
var _capsule: CapsuleShape3D


@onready var _head: Node3D = $Head
@onready var _collision: CollisionShape3D = $Collision


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_yaw = rotation.y
	_settings = get_node_or_null("/root/GameSettings")
	# A cápsula é duplicada para que mudar a altura não afete outras instâncias.
	if _collision != null and _collision.shape is CapsuleShape3D:
		_capsule = (_collision.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		_collision.shape = _capsule
		_collision.position.y = _capsule.height * 0.5
	reload_settings()
	if _settings != null and _settings.has_signal("applied"):
		_settings.applied.connect(_on_settings_applied)
	if _head != null:
		_head.rotation.x = _pitch
		_head.position.y = standing_eye_height


## Relê sensibilidade e inversão do gerenciador de configurações.
func reload_settings() -> void:
	var values: Dictionary = SettingsSchema.defaults()
	if _settings != null:
		values = _settings.current()
	var controls: Dictionary = values.get(SettingsSchema.SECTION_CONTROLS, {})
	_sensitivity_x = clampf(
		float(controls.get("mouse_sensitivity_x", SettingsSchema.DEFAULT_MOUSE_SENSITIVITY_X)),
		SettingsSchema.MOUSE_SENSITIVITY_MIN,
		SettingsSchema.MOUSE_SENSITIVITY_MAX
	)
	_sensitivity_y = clampf(
		float(controls.get("mouse_sensitivity_y", SettingsSchema.DEFAULT_MOUSE_SENSITIVITY_Y)),
		SettingsSchema.MOUSE_SENSITIVITY_MIN,
		SettingsSchema.MOUSE_SENSITIVITY_MAX
	)
	_invert_y = bool(controls.get("invert_y", SettingsSchema.DEFAULT_INVERT_Y))


func _on_settings_applied(_values: Dictionary) -> void:
	reload_settings()


func _physics_process(delta: float) -> void:
	var desired: Vector3 = Vector3.ZERO
	var input_dir: Vector2 = Vector2.ZERO

	if movement_enabled:
		input_dir = Input.get_vector(
			ACTION_LEFT, ACTION_RIGHT, ACTION_FORWARD, ACTION_BACK
		)

		# Ctrl tem prioridade sobre Shift: agachado nunca corre.
		var wants_crouch: bool = Input.is_action_pressed(ACTION_CROUCH)
		if wants_crouch and not _is_crouched:
			_set_crouched(true)
		elif not wants_crouch and _is_crouched and _can_stand():
			_set_crouched(false)

		_update_state(input_dir)

		if input_dir.length_squared() > 0.0:
			# Relativo à orientação horizontal do corpo (girada pelo mouse).
			var direction: Vector3 = (transform.basis * Vector3(
				input_dir.x, 0.0, input_dir.y
			)).normalized()
			desired = direction * speed_for_state(_state)

	# Aceleração/desaceleração independente da taxa de quadros.
	var weight: float = 1.0 - exp(-acceleration * delta)
	velocity.x = lerpf(velocity.x, desired.x, weight)
	velocity.z = lerpf(velocity.z, desired.z, weight)

	_blend_eye_height(delta)
	_apply_gravity(delta)
	move_and_slide()


## Calcula o estado a partir do que está sendo pressionado. Enquanto a pausa
## está ativa (`movement_enabled == false`) o estado é preservado.
func _update_state(input_dir: Vector2) -> void:
	var moving: bool = input_dir.length_squared() > 0.0
	var sprinting: bool = (
		moving
		and sprint_allowed
		and not _is_crouched
		and Input.is_action_pressed(ACTION_SPRINT)
	)
	var next: MovementState
	if _is_crouched:
		next = MovementState.CROUCHING
	elif moving:
		next = MovementState.RUNNING if sprinting else MovementState.WALKING
	else:
		next = MovementState.IDLE
	_set_state(next)


func _set_state(next: MovementState) -> void:
	if next == _state:
		return
	var previous: MovementState = _state
	_state = next
	state_changed.emit(previous, next)


## Velocidade correspondente ao estado (m/s).
func speed_for_state(state: MovementState) -> float:
	match state:
		MovementState.WALKING:
			return walk_speed
		MovementState.RUNNING:
			return run_speed
		MovementState.CROUCHING:
			return crouch_speed
		_:
			return 0.0


func _set_crouched(crouched: bool) -> void:
	if _is_crouched == crouched:
		return
	_is_crouched = crouched
	if _capsule != null:
		# A cápsula encolhe a partir do topo: os pés continuam na origem, então
		# agachar nunca empurra o corpo para dentro do chão ou de um obstáculo.
		_capsule.height = crouched_height if crouched else standing_height
		_collision.position.y = _capsule.height * 0.5


## Verifica se há espaço para voltar à altura normal (teto/objetos acima).
## Consulta simples de forma — a Etapa 6+ pode refinar se precisar.
func _can_stand() -> bool:
	if not is_inside_tree():
		return true
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space == null:
		return true
	var probe := CapsuleShape3D.new()
	probe.radius = (_capsule.radius if _capsule != null else 0.35)
	probe.height = standing_height
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = probe
	params.collision_mask = collision_mask
	var excluded: Array[RID] = [get_rid()]
	params.exclude = excluded
	params.margin = 0.01
	# Começa 2 cm acima dos pés para não encostar no próprio piso.
	params.transform = Transform3D(
		Basis(),
		global_position + Vector3(0.0, standing_height * 0.5 + 0.02, 0.0)
	)
	return space.intersect_shape(params, 1).is_empty()


func _blend_eye_height(delta: float) -> void:
	if _head == null:
		return
	var target: float = crouched_eye_height if _is_crouched else standing_eye_height
	var weight: float = 1.0 - exp(-crouch_blend_speed * delta)
	_head.position.y = lerpf(_head.position.y, target, weight)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		return
	velocity.y -= _gravity * delta


## Descarta o próximo evento de mouse. Chamado ao recapturar o cursor, para
## que o salto do ponteiro ao centro não gire a câmera.
func reset_look_input() -> void:
	_skip_next_motion = true


## Aplica um deslocamento do mouse (em pixels). Público para os testes.
## Não depende da taxa de quadros: o delta vem do evento, não do frame.
func apply_look(relative: Vector2) -> void:
	var yaw_delta: float = -relative.x * mouse_sensitivity_scale * _sensitivity_x
	var pitch_delta: float = -relative.y * mouse_sensitivity_scale * _sensitivity_y
	if _invert_y:
		pitch_delta = -pitch_delta

	_yaw += yaw_delta
	var limit: float = deg_to_rad(max_pitch_degrees)
	_pitch = clampf(_pitch + pitch_delta, -limit, limit)

	rotation.y = _yaw
	if _head != null:
		_head.rotation.x = _pitch


## Define a orientação atual (usada no spawn e nos testes).
func set_look(yaw_radians: float, pitch_radians: float) -> void:
	var limit: float = deg_to_rad(max_pitch_degrees)
	_yaw = yaw_radians
	_pitch = clampf(pitch_radians, -limit, limit)
	rotation.y = _yaw
	if _head != null:
		_head.rotation.x = _pitch


## Alias mantido para leitura no spawn (só a direção horizontal).
func set_yaw(yaw_radians: float) -> void:
	set_look(yaw_radians, _pitch)


func get_yaw() -> float:
	return _yaw


func get_pitch() -> float:
	return _pitch


func get_state() -> MovementState:
	return _state


func get_state_name() -> String:
	return str(STATE_NAMES.get(_state, "IDLE"))


func is_crouched() -> bool:
	return _is_crouched


## Altura atual dos olhos (m). Usada pelos testes e por HUDs futuros.
func get_eye_height() -> float:
	return _head.position.y if _head != null else standing_eye_height


## Etapa 6 (stamina) chamará isto; nesta etapa permanece sempre true.
func set_sprint_allowed(value: bool) -> void:
	sprint_allowed = value


func get_sensitivity() -> Vector2:
	return Vector2(_sensitivity_x, _sensitivity_y)


func is_invert_y() -> bool:
	return _invert_y


func _unhandled_input(event: InputEvent) -> void:
	if not movement_enabled:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	if _skip_next_motion:
		_skip_next_motion = false
		return
	apply_look(motion.relative)
