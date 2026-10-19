class_name PlayerController
extends CharacterBody3D
## Controlador em primeira pessoa do Black Sight (Etapa 4).
##
## Escopo desta etapa: **andar** (WASD), **olhar** com o mouse, **gravidade** e
## **colisão**. Corrida, agachamento, stamina e interação pertencem às próximas
## etapas — os pontos de extensão estão indicados abaixo, mas nada disso está
## implementado aqui.
##
## Integração com a Etapa 3 (fonte única de verdade):
## - sensibilidade horizontal/vertical e inversão do eixo vertical vêm de
##   `GameSettings` (`user://settings.cfg`, via `SettingsSchema`);
## - os valores são lidos ao entrar na cena e reaplicados quando o gerenciador
##   emite `applied`;
## - sem `GameSettings` (teste isolado), usa `SettingsSchema.defaults()`.
##
## O movimento é relativo à orientação horizontal do corpo (`rotation.y`), que é
## girado pelo mouse. A câmera fica no nó `Head` e só recebe a inclinação
## vertical (pitch) — não há tremor nem herança de aceleração.

const ACTION_FORWARD := "move_forward"
const ACTION_BACK := "move_back"
const ACTION_LEFT := "move_left"
const ACTION_RIGHT := "move_right"

## Velocidade de caminhada em metros por segundo. Corrida (Shift) entra na Etapa 5.
@export var walk_speed: float = 3.2
## Quão rápido a velocidade se aproxima da desejada (1/s). Também é a
## desaceleração usada quando não há entrada.
@export var acceleration: float = 22.0
## Radianos por pixel de mouse com multiplicador 1.0 (ajustável por configuração).
@export var mouse_sensitivity_scale: float = 0.0022
## Limite do olhar vertical, em graus (evita a câmera dar uma volta completa).
@export var max_pitch_degrees: float = 89.0

## Quando false, o jogador não responde a WASD nem ao mouse (usado pela pausa).
var movement_enabled: bool = true

var _gravity: float = 9.8
var _sensitivity_x: float = 1.0
var _sensitivity_y: float = 1.0
var _invert_y: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
var _settings


@onready var _head: Node3D = $Head


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_yaw = rotation.y
	_settings = get_node_or_null("/root/GameSettings")
	reload_settings()
	if _settings != null and _settings.has_signal("applied"):
		_settings.applied.connect(_on_settings_applied)
	if _head != null:
		_head.rotation.x = _pitch


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
	if movement_enabled:
		# get_vector já normaliza a diagonal: andar em diagonal não é mais rápido.
		var input_dir: Vector2 = Input.get_vector(
			ACTION_LEFT, ACTION_RIGHT, ACTION_FORWARD, ACTION_BACK
		)
		if input_dir.length_squared() > 0.0:
			# Relativo à orientação horizontal do corpo (girada pelo mouse).
			var direction: Vector3 = (transform.basis * Vector3(
				input_dir.x, 0.0, input_dir.y
			)).normalized()
			desired = direction * walk_speed

	# Aceleração/desaceleração independente da taxa de quadros.
	var weight: float = 1.0 - exp(-acceleration * delta)
	velocity.x = lerpf(velocity.x, desired.x, weight)
	velocity.z = lerpf(velocity.z, desired.z, weight)

	_apply_gravity(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		return
	velocity.y -= _gravity * delta


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
	apply_look(motion.relative)
