class_name WorldItem
extends Interactable
## Item solto no ambiente 3D (Etapa 9).
##
## É a **representação física** de um `ItemDefinition` que saiu do inventário.
## Usa o mesmo contrato da Etapa 7 (`Interactable`): aparece na mira como
## `[E] Pegar` e, ao ser acionado, devolve o item ao inventário de quem
## interagiu — pelo `add_item()` existente.
##
## Regras:
## - o item do mundo é a **fonte de verdade** enquanto está no chão;
## - a coleta só apaga o objeto **depois** de o inventário aceitar o item;
## - inventário cheio → o objeto continua no chão, disponível para nova
##   tentativa (o aviso "INVENTÁRIO CHEIO" é da HUD, ao receber `item_rejected`);
## - recolhimento único: depois de aceito, o objeto sai da árvore no mesmo
##   frame, então não existe segunda coleta nem duplicação.
##
## Visual provisório, nativo do Godot: base metálica baixa + cubo levemente
## emissivo + etiqueta 3D com o nome. A silhueta é baixa e estável (não tomba,
## não rola e não bloqueia corredores), pronta para ser trocada por um modelo
## definitivo em etapas futuras — só a cena muda; o script e o contrato ficam.

## Grupo usado pelos testes e pela limpeza da cena de teste.
const WORLD_GROUP := &"world_items"

## Caixa da colisão/base (x, y, z). É a mesma caixa validada antes do drop,
## consultada por contrato (`get_footprint()`), sem `players/` importar `items/`.
const SIZE := Vector3(0.42, 0.32, 0.42)
## Altura do centro da colisão a partir da base.
const CENTER_HEIGHT := 0.16

@onready var _body: RigidBody3D = %Body
@onready var _name_label: Label3D = %NameLabel

var _item: ItemDefinition = null
var _collected: bool = false


func _ready() -> void:
	add_to_group(WORLD_GROUP)
	# O objeto nasce já no chão (posição validada) e apenas assenta com a física.
	if _body != null:
		_body.linear_velocity = Vector3.ZERO
		_body.angular_velocity = Vector3.ZERO
	_apply_item()


## Define o item antes (ou depois) de entrar na árvore. Devolve false para um
## item inválido, sem alterar nada.
func configure_item(item: ItemDefinition) -> bool:
	if item == null or not item.is_valid():
		return false
	_item = item
	if is_inside_tree():
		_apply_item()
	return true


## Item representado (a mesma instância que saiu do inventário).
func get_item() -> ItemDefinition:
	return _item


func get_display_name() -> String:
	return _item.get_display_name() if _item != null else ""


## Caixa ocupada pelo objeto no mundo (usada por quem solta o item).
func get_footprint() -> Vector3:
	return SIZE


func is_collected() -> bool:
	return _collected


## Continua interativo com o inventário cheio: é assim que o jogador recebe a
## indicação e o aviso de inventário cheio (mesma regra do item da Etapa 8).
func can_interact(actor: Node = null) -> bool:
	return (
		interaction_enabled
		and not _collected
		and _find_inventory(actor) != null
	)


func _on_interact(actor: Node) -> void:
	if _collected:
		return
	var inventory: Object = _find_inventory(actor)
	if inventory == null:
		return
	# Só some depois que o inventário confirmou a entrada do item.
	if bool(inventory.call("add_item", _item)):
		_collect()


func _collect() -> void:
	_collected = true
	interaction_enabled = false
	visible = false
	remove_from_group(WORLD_GROUP)
	if _body != null:
		_body.freeze = true
		_body.collision_layer = 0
		_body.collision_mask = 0
	# Libera o nó no fim do frame (a interação atual ainda pode estar no ar).
	queue_free()


func _apply_item() -> void:
	if _item == null:
		return
	if _name_label != null:
		_name_label.text = _item.get_display_name()


## Inventário do ator, por contrato — `items/` não importa `players/`.
func _find_inventory(actor: Node) -> Object:
	if actor == null or not is_instance_valid(actor):
		return null
	if not actor.has_method("get_inventory"):
		return null
	var inventory: Variant = actor.call("get_inventory")
	if inventory == null or not (inventory is Object):
		return null
	if not inventory.has_method("add_item"):
		return null
	return inventory
