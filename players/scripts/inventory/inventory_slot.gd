class_name InventorySlot
extends RefCounted
## Um slot do inventário do jogador (Etapa 8).
##
## Guarda **no máximo um item** — sem pilha, sem quantidade. A classe existe
## para que o slot tenha identidade e API própria (`is_empty()`, `clear()`), em
## vez de o inventário espalhar verificações de `null` pelo código.

## Índice fixo do slot (0, 1 ou 2). Definido pelo inventário ao criar o slot.
var index: int = -1

## Item guardado (null quando o slot está vazio).
var item: ItemDefinition = null


func _init(slot_index: int = -1) -> void:
	index = slot_index


func is_empty() -> bool:
	return item == null


func has_item() -> bool:
	return item != null


func get_item() -> ItemDefinition:
	return item


func set_item(value: ItemDefinition) -> void:
	item = value


## Esvazia o slot e devolve o item que estava nele (null se já estava vazio).
func clear() -> ItemDefinition:
	var previous: ItemDefinition = item
	item = null
	return previous


## Nome do item para a HUD ("" quando vazio).
func get_display_name() -> String:
	return item.get_display_name() if item != null else ""


func _to_string() -> String:
	return "InventorySlot(%d, %s)" % [index, get_display_name() if has_item() else "vazio"]
