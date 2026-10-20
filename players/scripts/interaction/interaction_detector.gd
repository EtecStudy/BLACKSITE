class_name InteractionDetector
extends Node3D
## Detector de interação do jogador (Etapa 7).
##
## Componente da cena do jogador, filho da câmera. A cada frame de física ele:
##   1. lança um raio do centro da visão (`-basis.z` da câmera) com alcance
##      `interaction_distance` (2,5 m por padrão);
##   2. pega o primeiro corpo atingido — paredes, caixas e pilares entram no
##      caminho e bloqueiam a linha de visão naturalmente;
##   3. sobe a árvore a partir desse corpo até achar um `Interactable`
##      (ou um nó que cumpra o contrato);
##   4. pergunta ao objeto `can_interact()` e guarda o foco;
##   5. emite `focus_changed` **somente quando o foco muda**, para a HUD não
##      reconstruir nada por frame.
##
## A ação `interact` (tecla E por padrão) vem do InputMap e é lida com detecção
## de borda própria — igual ao Ctrl da Etapa 5 — para funcionar também nos
## testes com `Input.action_press`. Nenhuma tecla é codificada aqui.
##
## O detector **não** conhece tipos de objeto: não existe `if objeto is porta`.
## Toda a lógica de interação fica em `interact()` do próprio objeto.

const ACTION_INTERACT := "interact"
const DEFAULT_INTERACTION_DISTANCE := 2.5

## Emitido quando o objeto sob a mira muda (null = nenhum objeto válido).
## A HUD usa este sinal para mostrar/esconder a indicação.
signal focus_changed(interactable: Node)
## Emitido quando o texto fornecido pelo objeto focado muda.
signal focus_text_changed(text: String)
## Emitido quando uma interação é efetivamente executada.
signal interaction_triggered(interactable: Node)

## Alcance máximo da interação, em metros (câmera → ponto atingido).
## Centralizado aqui: nenhuma outra parte do projeto repete esse número.
@export var interaction_distance: float = DEFAULT_INTERACTION_DISTANCE

## Camadas de física consultadas pelo raio. A camada 1 é a padrão do mundo
## (paredes, piso, caixas). Objetos em outras camadas exigem ajuste aqui.
@export var collision_mask: int = 1

## Quando false, nada é detectado nem executado (pausa e configurações).
var _enabled: bool = true
## Objeto atualmente sob a mira (preservado durante a pausa).
var _current: Node = null
## Objeto que a HUD está exibindo (fica null enquanto a detecção está suspensa).
var _ui_focus: Node = null
var _last_text: String = ""
var _interact_was_pressed: bool = false
var _actor: Node = null
var _camera: Camera3D = null


func _ready() -> void:
	_camera = get_parent() as Camera3D
	if _camera == null:
		_camera = get_viewport().get_camera_3d()
	_actor = _find_actor()
	_interact_was_pressed = Input.is_action_pressed(ACTION_INTERACT)


func _physics_process(_delta: float) -> void:
	# Pausa, configurações ou detector desligado: não detecta, não interage e
	# esconde a indicação. O foco atual é preservado para a retomada.
	if is_detection_blocked():
		_set_ui_focus(null)
		_interact_was_pressed = Input.is_action_pressed(ACTION_INTERACT)
		return

	_refresh_focus()

	var pressed: bool = Input.is_action_pressed(ACTION_INTERACT)
	if pressed and not _interact_was_pressed:
		try_interact()
	_interact_was_pressed = pressed


## True quando a detecção deve ficar suspensa (pausa, configurações, desligado).
func is_detection_blocked() -> bool:
	if not _enabled:
		return true
	if _actor != null:
		var movement: Variant = _actor.get("movement_enabled")
		if movement is bool and not movement:
			return true
	return false


## Liga/desliga a detecção (chamado pela sessão ao pausar e retomar).
func set_detection_enabled(value: bool) -> void:
	_enabled = value
	_interact_was_pressed = Input.is_action_pressed(ACTION_INTERACT)
	if not _enabled:
		_set_ui_focus(null)


func is_detection_enabled() -> bool:
	return _enabled


## Reavalia a mira imediatamente (usado pelos testes e por eventos pontuais).
func refresh() -> void:
	if is_detection_blocked():
		_set_ui_focus(null)
		return
	_refresh_focus()


## Objeto sob a mira (ou null). Continua válido durante a pausa.
func get_current_interactable() -> Node:
	return _current


## Texto da indicação atual ("" quando não há objeto).
func get_focus_text() -> String:
	if _current == null or not is_instance_valid(_current):
		return ""
	return str(_current.get_interaction_text(_actor))


func has_focus() -> bool:
	return _current != null and is_instance_valid(_current)


## Executa a interação do objeto focado, se houver. Devolve true se rodou.
func try_interact() -> bool:
	if is_detection_blocked():
		return false
	_refresh_focus()
	var target: Node = _current
	if target == null:
		return false
	if not bool(target.can_interact(_actor)):
		return false
	var result: Variant = target.interact(_actor)
	var performed: bool = true if result == null else bool(result)
	if performed:
		interaction_triggered.emit(target)
		# O objeto pode ter mudado de estado (ex.: deixou de ser interativo).
		_refresh_focus()
	return performed


## Alcance configurado (leitura para HUD/testes).
func get_interaction_distance() -> float:
	return interaction_distance


func _refresh_focus() -> void:
	# Objetos podem sair da cena (ou ser liberados por outra ação) enquanto
	# estão focados; nesse caso a referência é descartada antes de qualquer uso.
	if _current != null and not is_instance_valid(_current):
		_current = null
		_last_text = ""
	if _ui_focus != null and not is_instance_valid(_ui_focus):
		_ui_focus = null
		focus_changed.emit(null)

	var target: Node = _find_target()
	if target != null and not bool(target.can_interact(_actor)):
		target = null

	if target != _current:
		_current = target
		_last_text = ""

	_set_ui_focus(_current)

	if _current != null:
		var text: String = get_focus_text()
		if text != _last_text:
			_last_text = text
			focus_text_changed.emit(text)


## Atualiza a HUD somente quando o que ela mostra muda.
func _set_ui_focus(target: Node) -> void:
	if target == _ui_focus:
		return
	_ui_focus = target
	focus_changed.emit(target)


## Corpo atingido → nó interativo (o próprio corpo ou um ancestral).
func _find_target() -> Node:
	var hit: Dictionary = _raycast()
	if hit.is_empty():
		return null

	var collider: Node = hit.get("collider") as Node
	if collider == null:
		return null

	var origin: Vector3 = _ray_origin()
	var position: Vector3 = hit.get("position", origin)
	if origin.distance_to(position) > interaction_distance:
		return null

	return _resolve_interactable(collider)


## Sobe a árvore até achar um `Interactable` (ou um nó que cumpra o contrato).
func _resolve_interactable(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current is Interactable:
			return current
		if (
			current.has_method("can_interact")
			and current.has_method("get_interaction_text")
			and current.has_method("interact")
		):
			return current
		current = current.get_parent()
	return null


func _raycast() -> Dictionary:
	if _camera == null or not _camera.is_inside_tree():
		return {}
	var space: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	if space == null:
		return {}

	var origin: Vector3 = _ray_origin()
	var destination: Vector3 = origin + _ray_direction() * interaction_distance
	var exclude: Array[RID] = []
	if _actor is CollisionObject3D:
		exclude.append((_actor as CollisionObject3D).get_rid())

	var params := PhysicsRayQueryParameters3D.create(
		origin, destination, collision_mask, exclude
	)
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.hit_from_inside = false
	return space.intersect_ray(params)


func _ray_origin() -> Vector3:
	return _camera.global_position if _camera != null else global_position


func _ray_direction() -> Vector3:
	if _camera == null:
		return -global_transform.basis.z
	return -_camera.global_transform.basis.z


## Primeiro `CollisionObject3D` acima na árvore (o jogador), para o raio não
## acertar o próprio corpo.
func _find_actor() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node is CollisionObject3D:
			return node
		node = node.get_parent()
	return null
