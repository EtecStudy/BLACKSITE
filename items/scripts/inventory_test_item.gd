class_name InventoryTestItem
extends Interactable
## Objeto de teste do inventário (Etapa 8): um item pegável.
##
## Usa o **mesmo** sistema de interação da Etapa 7 — herda de `Interactable`, é
## detectado pelo `InteractionDetector` pelo raio da câmera e mostra
## `[E] Pegar` quando está na mira. Ao pressionar E, o **próprio objeto** pede
## ao inventário do ator para guardar o seu item e, se conseguiu, desaparece.
##
## Regras da etapa:
## - sem drop, sem uso, sem pilha: o item só entra no inventário;
## - inventário cheio → nada é coletado e o objeto continua no lugar (o
##   inventário emite `item_rejected` e a HUD mostra "INVENTÁRIO CHEIO");
## - `can_interact()` continua true com o inventário cheio, senão o jogador não
##   receberia a indicação nem o aviso.
##
## O objeto não importa `players/`: pega o inventário pelo ator
## (`actor.get_inventory()`), por contrato — `items/` continua dependendo só de
## `shared/`.

## Identificador do item criado por esta instância.
@export var item_id: StringName = &"item_a"

## Nome exibido na etiqueta 3D e na HUD.
@export var item_name: String = "ITEM A"

@onready var _body: StaticBody3D = %Body
@onready var _name_label: Label3D = %NameLabel

var _item: ItemDefinition = null
var _collected: bool = false
var _attempts: int = 0


func _ready() -> void:
	_item = ItemDefinition.new(item_id, item_name)
	_name_label.text = _item.get_display_name()
	_apply_enabled_state()


## Só pode ser pego enquanto não foi coletado e o ator tem inventário.
func can_interact(actor: Node = null) -> bool:
	return (
		interaction_enabled
		and not _collected
		and _find_inventory(actor) != null
	)


## Ação do objeto: guardar o item no inventário de quem interagiu.
func _on_interact(actor: Node) -> void:
	_attempts += 1
	var inventory: Object = _find_inventory(actor)
	if inventory == null:
		return
	if bool(inventory.call("add_item", _item)):
		_collect()


## Item criado por esta instância (para HUD/testes).
func get_item() -> ItemDefinition:
	return _item


func is_collected() -> bool:
	return _collected


## Quantas vezes o objeto tentou ser pego (inclui tentativas com inventário cheio).
func get_attempts() -> int:
	return _attempts


func _collect() -> void:
	_collected = true
	interaction_enabled = false
	# Some da cena e deixa de ser atingido pelo raio do detector.
	visible = false
	if _body != null:
		_body.collision_layer = 0
		_body.collision_mask = 0


func _apply_enabled_state() -> void:
	if _body != null and _collected:
		_body.collision_layer = 0


## Inventário do ator, por contrato — sem importar `players/`.
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
