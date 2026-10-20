class_name ItemDropper
extends Node3D
## Soltar o item do slot selecionado no ambiente (Etapa 9).
##
## Componente da câmera do jogador (mesmo lugar do `InteractionDetector`).
## Fluxo:
##   1. lê o slot selecionado e o item nele (`get_selected_slot` /
##      `get_item(slot)` do inventário — nunca o array interno);
##   2. pede ao `SpaceProbe` (shared/) um ponto seguro à frente da câmera,
##      validando piso, espaço livre e linha de visão;
##   3. instancia a cena reutilizável de item no mundo (`items/`, via `@export`);
##   4. **só depois** de a instância estar na árvore e configurada chama
##      `remove_item(slot)`. Se qualquer passo falhar, o item continua no
##      inventário — nunca existe item no chão sem ter saído do slot, nem item
##      apagado do inventário sem existir no mundo.
##
## Sem arremesso: a instância nasce parada, sobre o piso, e apenas assenta.
## Sem segunda cópia do inventário: este componente não guarda itens.

## Um item saiu do inventário e existe no mundo.
signal item_dropped(item: ItemDefinition, world_item: Node)
## O drop não aconteceu. `reason` é o texto discreto que a HUD pode mostrar.
signal drop_blocked(reason: String)

## Mensagens curtas (a HUD só exibe; a decisão é daqui).
const REASON_EMPTY := "SLOT VAZIO"
const REASON_NO_SPACE := "SEM ESPAÇO PARA SOLTAR"
const REASON_SPAWN := "NÃO FOI POSSÍVEL SOLTAR"

## Cena do item solto (definida na cena do jogador).
@export var world_item_scene: PackedScene = null
## Pegada usada quando a cena do item não informa a sua (`get_footprint`).
@export var default_footprint: Vector3 = Vector3(0.42, 0.32, 0.42)
## Distância preferida à frente da câmera, em metros.
@export var drop_distance: float = 1.15
## Camada de física usada nas consultas (a mesma do mundo e da interação).
@export_flags_3d_physics var collision_mask: int = 1

var _actor: Node = null
var _camera: Camera3D = null
var _drops: int = 0


func _ready() -> void:
	_camera = get_parent() as Camera3D
	if _camera == null:
		_camera = get_viewport().get_camera_3d() if is_inside_tree() else null
	_actor = _find_actor()
	# Não processa nada por frame: responde à ação `inventory_drop`.
	set_process(false)
	set_physics_process(false)


## Solta o item do slot selecionado. Devolve true só quando o item saiu do
## inventário e está no mundo.
func drop_selected_item() -> bool:
	if is_blocked():
		return false
	var inventory: Node = get_inventory()
	if inventory == null:
		return false

	var slot: int = int(inventory.call("get_selected_slot"))
	var item: ItemDefinition = inventory.call("get_item", slot)
	if item == null or not item.is_valid():
		drop_blocked.emit(REASON_EMPTY)
		return false

	# A instância é preparada fora da árvore: a pegada real vem do próprio item
	# (por contrato), então `players/` não precisa conhecer `items/`.
	var world_item: Node = _create_world_item(item)
	if world_item == null:
		drop_blocked.emit(REASON_SPAWN)
		return false

	var spot: Dictionary = SpaceProbe.find_drop_position(
		get_world_3d() if is_inside_tree() else null,
		_camera_position(),
		_camera_forward(),
		_actor_position(),
		_footprint_of(world_item),
		_exclude_rids(),
		collision_mask,
		drop_distance
	)
	if not bool(spot.get("valid", false)):
		push_warning("ItemDropper: sem posição segura (%s)" % str(spot.get("reason", "")))
		world_item.free()
		drop_blocked.emit(REASON_NO_SPACE)
		return false

	if not _attach_world_item(world_item, spot["position"]):
		drop_blocked.emit(REASON_SPAWN)
		return false

	# Instância já está na árvore e configurada: agora sim o slot pode esvaziar.
	if not bool(inventory.call("remove_item", slot)):
		world_item.queue_free()
		return false

	_drops += 1
	item_dropped.emit(item, world_item)
	return true


## Inventário do jogador (por contrato, sem guardar cópia).
func get_inventory() -> Node:
	if _actor == null or not is_instance_valid(_actor):
		return null
	if not _actor.has_method("get_inventory"):
		return null
	var inventory: Variant = _actor.call("get_inventory")
	return inventory as Node


## Quantos drops concluídos (leitura para testes/HUD).
func get_drop_count() -> int:
	return _drops


## Bloqueado na pausa e nas configurações (mesma flag do resto do jogador).
func is_blocked() -> bool:
	if _actor != null and is_instance_valid(_actor):
		var movement: Variant = _actor.get("movement_enabled")
		if movement is bool and not movement:
			return true
	return false


## Instancia e configura a cena do item **fora** da árvore.
func _create_world_item(item: ItemDefinition) -> Node:
	if world_item_scene == null:
		push_error("ItemDropper: world_item_scene não configurada")
		return null
	var instance: Node = world_item_scene.instantiate()
	if instance == null:
		push_error("ItemDropper: falha ao instanciar a cena do item")
		return null
	if not instance.has_method("configure_item") or not bool(instance.call("configure_item", item)):
		push_error("ItemDropper: item inválido para a cena do mundo")
		instance.free()
		return null
	return instance


## Coloca a instância na cena atual, na posição já validada.
func _attach_world_item(instance: Node, position: Vector3) -> bool:
	var parent: Node = _world_root()
	if parent == null:
		push_error("ItemDropper: cena atual indisponível")
		instance.free()
		return false
	parent.add_child(instance)
	if instance.get_parent() != parent:
		push_error("ItemDropper: a instância não entrou na cena")
		instance.free()
		return false
	instance.global_position = position
	return true


## Caixa do item, informada pela própria cena (contrato `get_footprint`).
func _footprint_of(instance: Node) -> Vector3:
	var size: Vector3 = default_footprint
	if instance != null and instance.has_method("get_footprint"):
		var informed: Variant = instance.call("get_footprint")
		if informed is Vector3 and (informed as Vector3).length_squared() > 0.0001:
			size = informed
	return size


## Onde o item vive: a cena atual (nunca dentro do jogador).
func _world_root() -> Node:
	if not is_inside_tree():
		return null
	var tree: SceneTree = get_tree()
	if tree.current_scene != null:
		return tree.current_scene
	return tree.root


func _camera_position() -> Vector3:
	return _camera.global_position if _camera != null else global_position


func _camera_forward() -> Vector3:
	if _camera != null:
		return -_camera.global_transform.basis.z
	return -global_transform.basis.z


func _actor_position() -> Vector3:
	return _actor.global_position if _actor != null and is_instance_valid(_actor) else global_position


## O próprio jogador não entra nas consultas de física.
func _exclude_rids() -> Array[RID]:
	var exclude: Array[RID] = []
	if _actor is CollisionObject3D:
		exclude.append((_actor as CollisionObject3D).get_rid())
	return exclude


## O jogador é o primeiro ancestral com inventário (a câmera fica sob a cabeça).
func _find_actor() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("get_inventory") and node.get("movement_enabled") is bool:
			return node
		node = node.get_parent()
	return null
