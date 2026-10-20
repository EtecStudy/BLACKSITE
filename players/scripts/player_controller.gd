class_name PlayerController
extends CharacterBody3D
## Controlador em primeira pessoa do Black Sight (Etapa 4 → Etapa 6).
##
## Escopo atual: **andar** (WASD), **correr** (Shift), **agachar** (Ctrl),
## **stamina**, **olhar** com o mouse, **gravidade** e **colisão**.
## Pulo não existe. A interação (Etapa 7) vive em
## `players/scripts/interaction/interaction_detector.gd` e o inventário
## (Etapa 8) em `players/scripts/inventory/` — componentes da cena do jogador.
## O controlador apenas os expõe; nenhuma regra de interação ou de inventário
## mora aqui.
##
## Estados (`MovementState`):
##   IDLE      — parado (sem direção pressionada);
##   WALKING   — andando;
##   RUNNING   — andando com Shift (nunca agachado);
##   CROUCHING — agachado (Ctrl), com prioridade sobre Shift.
##
## Stamina (Etapa 6): consumida apenas no estado RUNNING. A recuperação tem
## **atraso** (Etapa 6.2): só começa depois de `stamina_recovery_delay` segundos
## sem intenção de correr, e **segurar Shift bloqueia a recuperação** — inclusive
## depois de esgotar. Ao esgotar, `sprint_allowed` vira false e a corrida só volta
## depois de recuperar `sprint_resume_threshold`. Enquanto a pausa está aberta
## (`movement_enabled == false`) nada é consumido, recuperado ou contado.
##
## Agachamento (Etapa 6): `crouch_mode` vem de `GameSettings` e aceita
## SEGURAR (`hold`, segura Ctrl) ou ALTERNAR (`toggle`, padrão, Ctrl alterna).
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

# --- Stamina (Etapa 6) ------------------------------------------------------
## Capacidade máxima e taxas em unidades por segundo.
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 20.0
@export var stamina_recovery_rate: float = 15.0
## Etapa 6.2 — atraso (s) sem intenção de correr antes de a stamina recuperar.
## Não é uma configuração do jogador: é regra de balanceamento do controlador.
@export var stamina_recovery_delay: float = 1.0
## Depois de esgotar, a corrida só volta com pelo menos este valor.
@export var sprint_resume_threshold: float = 20.0

## Quando false, o jogador não responde a WASD, Shift, Ctrl nem ao mouse.
## Usado pela pausa e pelas configurações abertas durante a partida.
var movement_enabled: bool = true

## Quando false, a corrida é bloqueada (stamina esgotada). O próprio
## controlador liga/desliga isto em `_update_stamina`; a API segue pública para
## efeitos futuros. A corrida só volta após `sprint_resume_threshold`.
var sprint_allowed: bool = true

## Valor atual de stamina. Começa em `max_stamina` no `_ready` e muda apenas
## em `_physics_process` (ou por `set_stamina`).
var stamina: float = 0.0

## Emitido quando o estado muda (para HUD/sons futuros).
signal state_changed(previous: int, current: int)
## Emitido quando a stamina muda (para a HUD futura).
signal stamina_changed(current: float, maximum: float)

var _state: MovementState = MovementState.IDLE
var _is_crouched: bool = false
var _crouch_mode: String = SettingsSchema.DEFAULT_CROUCH_MODE
var _crouch_toggled: bool = false
var _crouch_action_was_pressed: bool = false
## Tempo restante (s) do atraso de recuperação. Congela quando o jogo pausa,
## porque `_update_stamina()` não roda com `movement_enabled == false`.
var _recovery_delay_left: float = 0.0

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
@onready var _interaction_detector: InteractionDetector = get_node_or_null(
	"Head/Camera/InteractionDetector"
) as InteractionDetector


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_yaw = rotation.y
	_settings = get_node_or_null("/root/GameSettings")
	# A cápsula é duplicada para que mudar a altura não afete outras instâncias.
	if _collision != null and _collision.shape is CapsuleShape3D:
		_capsule = (_collision.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		_collision.shape = _capsule
		_collision.position.y = _capsule.height * 0.5
	stamina = max_stamina
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
	_crouch_mode = SettingsSchema.normalize_crouch_mode(
		controls.get("crouch_mode"), SettingsSchema.DEFAULT_CROUCH_MODE
	)
	# Mantém o interruptor coerente com a postura ao trocar de modo.
	_crouch_toggled = _is_crouched


func _on_settings_applied(_values: Dictionary) -> void:
	reload_settings()


func _physics_process(delta: float) -> void:
	var desired: Vector3 = Vector3.ZERO
	var input_dir: Vector2 = Vector2.ZERO

	# Detecção de borda própria (funciona igual em teste e em jogo).
	var crouch_pressed: bool = Input.is_action_pressed(ACTION_CROUCH)
	var crouch_just_pressed: bool = crouch_pressed and not _crouch_action_was_pressed
	_crouch_action_was_pressed = crouch_pressed

	if movement_enabled:
		input_dir = Input.get_vector(
			ACTION_LEFT, ACTION_RIGHT, ACTION_FORWARD, ACTION_BACK
		)

		# Ctrl tem prioridade sobre Shift: agachado nunca corre.
		var wants_crouch: bool = _wants_crouch(crouch_pressed, crouch_just_pressed)
		if wants_crouch and not _is_crouched:
			_set_crouched(true)
		elif not wants_crouch and _is_crouched and _can_stand():
			_set_crouched(false)

		_update_state(input_dir)
		_update_stamina(delta)

		# Stamina esgotada neste frame: cai para WALKING imediatamente.
		if _state == MovementState.RUNNING and not sprint_allowed:
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


## Interpreta o Ctrl conforme o modo configurado.
## - ALTERNAR: cada aperto liga/desliga o agachamento;
## - SEGURAR: agacha enquanto Ctrl estiver pressionado.
func _wants_crouch(pressed_now: bool, just_pressed: bool) -> bool:
	if _crouch_mode == SettingsSchema.CROUCH_MODE_TOGGLE:
		if just_pressed:
			_crouch_toggled = not _crouch_toggled
		return _crouch_toggled
	_crouch_toggled = pressed_now
	return _crouch_toggled


## Consome stamina correndo e recupera — somente depois do atraso e sem a
## intenção de correr (Shift) ativa.
##
## Regras (Etapa 6.2):
## 1. RUNNING consome `stamina_drain_rate` por segundo e mantém o atraso cheio;
## 2. esgotar zera a stamina, bloqueia a corrida e cai para WALKING no frame;
## 3. **Shift pressionado bloqueia a recuperação** — parado, andando ou agachado;
## 4. soltar Shift inicia `stamina_recovery_delay`; nada recupera durante ele;
## 5. apertar Shift durante o atraso o reinicia (nenhuma recuperação escondida);
## 6. terminado o atraso, recupera `stamina_recovery_rate` por segundo até o
##    máximo, liberando a corrida ao atingir `sprint_resume_threshold`.
func _update_stamina(delta: float) -> void:
	var sprint_held: bool = Input.is_action_pressed(ACTION_SPRINT)

	if _state == MovementState.RUNNING:
		if stamina > 0.0:
			stamina = maxf(0.0, stamina - stamina_drain_rate * delta)
			stamina_changed.emit(stamina, max_stamina)
		# A corrida acabou de acontecer: o atraso começa cheio quando ela parar.
		_recovery_delay_left = stamina_recovery_delay
		if stamina <= 0.0:
			set_sprint_allowed(false)
			_recovery_delay_left = stamina_recovery_delay
		return

	# Intenção de correr ainda ativa (mesmo exausto, agachado ou parado):
	# o jogador está se esforçando, então nada de recuperação.
	if sprint_held:
		_recovery_delay_left = stamina_recovery_delay
		return

	# Atraso após a corrida: stamina parada, tempo correndo normalmente.
	if _recovery_delay_left > 0.0:
		_recovery_delay_left = maxf(0.0, _recovery_delay_left - delta)
		return

	if stamina < max_stamina:
		stamina = minf(max_stamina, stamina + stamina_recovery_rate * delta)
		stamina_changed.emit(stamina, max_stamina)
	if not sprint_allowed and stamina >= sprint_resume_threshold:
		set_sprint_allowed(true)


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


func get_stamina() -> float:
	return stamina


func get_max_stamina() -> float:
	return max_stamina


## Segundos restantes do atraso de recuperação (0 = recuperação liberada).
func get_recovery_delay_left() -> float:
	return _recovery_delay_left


## True enquanto Shift está pressionado (a corrida está sendo tentada).
func is_sprint_held() -> bool:
	return Input.is_action_pressed(ACTION_SPRINT)


## 0.0 a 1.0 — útil para uma barra de stamina futura.
func get_stamina_ratio() -> float:
	return stamina / max_stamina if max_stamina > 0.0 else 0.0


## Define a stamina já limitada a [0, max] e ajusta o bloqueio da corrida.
## Usado por testes e, no futuro, por efeitos de jogo (ex.: adrenalina).
func set_stamina(value: float) -> void:
	stamina = clampf(value, 0.0, max_stamina)
	if stamina <= 0.0:
		set_sprint_allowed(false)
	elif stamina >= sprint_resume_threshold:
		set_sprint_allowed(true)
	stamina_changed.emit(stamina, max_stamina)


func get_crouch_mode() -> String:
	return _crouch_mode


func is_sprint_allowed() -> bool:
	return sprint_allowed


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


## Detector de interação (Etapa 7). É um componente da cena do jogador: o
## controlador só o expõe para a sessão ligar à HUD — nenhuma regra de
## interação mora aqui.
func get_interaction_detector() -> InteractionDetector:
	return _interaction_detector


## Inventário do jogador (Etapa 8). Os três slots e a API ficam em
## `Inventory`; o controlador não guarda itens.
func get_inventory() -> Inventory:
	return get_node_or_null("Inventory") as Inventory


## Entrada do inventário (teclas 1/2/3, G e R provisória). A sessão desliga
## durante a pausa, do mesmo jeito que faz com o detector de interação.
func get_inventory_input() -> InventoryInput:
	return get_node_or_null("InventoryInput") as InventoryInput


## Componente que solta o item do slot selecionado no mundo (Etapa 9). Fica na
## câmera, ao lado do detector de interação; o controlador só o expõe.
func get_item_dropper() -> ItemDropper:
	return get_node_or_null("Head/Camera/ItemDropper") as ItemDropper


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
