class_name InventoryInput
extends Node
## Entrada do inventário (Etapa 8).
##
## Lê as ações do **InputMap** e chama o `Inventory`. Nenhuma tecla é codificada
## aqui — igual ao `InteractionDetector` da Etapa 7. As ações lidas são:
##
## - `inventory_slot_1`, `inventory_slot_2`, `inventory_slot_3` → selecionar slot;
## - `inventory_remove` (R) → remover o item do slot selecionado.
##
## **`inventory_remove` é provisória**: existe só para validar remoção nesta
## etapa. Quando houver descarte/uso de item, ela será substituída.
##
## A borda é detectada manualmente (estado anterior + atual), porque os testes
## simulam teclado com `Input.action_press` — o mesmo caminho do teclado real.
##
## Bloqueio: pausa/configurações (`movement_enabled == false` no jogador) ou
## `set_input_enabled(false)` chamado pela sessão. Bloqueado, nada é selecionado
## nem removido, e o estado das teclas é re-sincronizado para não disparar uma
## borda atrasada ao continuar.

const ACTION_REMOVE := "inventory_remove"

## Ações de seleção na ordem dos slots: índice 0 → slot 1, e assim por diante.
const ACTION_SELECT_SLOTS := [
	"inventory_slot_1",
	"inventory_slot_2",
	"inventory_slot_3",
]

var _enabled: bool = true
var _actor: Node = null
var _inventory: Node = null
## Estado anterior de cada ação (para detectar a borda de pressionar).
var _pressed: Dictionary = {}


func _ready() -> void:
	assert(
		ACTION_SELECT_SLOTS.size() == Inventory.SLOT_COUNT,
		"InventoryInput precisa de uma ação por slot do inventário"
	)
	_actor = _find_actor()
	_sync_pressed()


func _physics_process(_delta: float) -> void:
	if is_blocked():
		_sync_pressed()
		return

	for action: String in _read_edges():
		if action == ACTION_REMOVE:
			remove_selected()
			continue
		var slot_index: int = ACTION_SELECT_SLOTS.find(action)
		if slot_index >= 0:
			select_slot(slot_index)


## Inventário operado (o nó `Inventory` do jogador).
func get_inventory() -> Node:
	if _inventory == null or not is_instance_valid(_inventory):
		_inventory = _resolve_inventory()
	return _inventory


func get_slot_action(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= ACTION_SELECT_SLOTS.size():
		return ""
	return str(ACTION_SELECT_SLOTS[slot_index])


## Seleciona um slot pelo índice. Ignorado quando a entrada está bloqueada.
func select_slot(slot_index: int) -> bool:
	if is_blocked():
		return false
	var inventory: Node = get_inventory()
	if inventory == null:
		return false
	return bool(inventory.call("select_slot", slot_index))


## Remove o item do slot selecionado (ação provisória de teste).
func remove_selected() -> bool:
	if is_blocked():
		return false
	var inventory: Node = get_inventory()
	if inventory == null:
		return false
	var selected: int = int(inventory.call("get_selected_slot"))
	return bool(inventory.call("remove_item", selected))


## True quando a pausa (ou o desligamento explícito) impede a entrada.
func is_blocked() -> bool:
	if not _enabled:
		return true
	if _actor != null and is_instance_valid(_actor):
		var movement: Variant = _actor.get("movement_enabled")
		if movement is bool and not movement:
			return true
	return false


func is_input_enabled() -> bool:
	return _enabled


## Liga/desliga a entrada (a sessão chama ao pausar e ao retomar).
func set_input_enabled(value: bool) -> void:
	_enabled = value
	_sync_pressed()


func get_action_names() -> Array[String]:
	var names: Array[String] = []
	for action: String in ACTION_SELECT_SLOTS:
		names.append(action)
	names.append(ACTION_REMOVE)
	return names


func _read_edges() -> Array[String]:
	var edges: Array[String] = []
	for action: String in get_action_names():
		var now: bool = Input.is_action_pressed(action)
		if now and not bool(_pressed.get(action, false)):
			edges.append(action)
		_pressed[action] = now
	return edges


## Marca o estado atual sem gerar bordas (pausa, foco perdido, retomada).
func _sync_pressed() -> void:
	for action: String in get_action_names():
		_pressed[action] = Input.is_action_pressed(action)


func _resolve_inventory() -> Node:
	var parent: Node = get_parent()
	if parent == null:
		return null
	var direct: Node = parent.get_node_or_null("Inventory")
	if direct != null:
		return direct
	if parent.has_method("get_inventory"):
		return parent.call("get_inventory") as Node
	return null


## O jogador é o pai deste componente (a cena do jogador o posiciona ali).
## Só ele é consultado: nada de varrer a árvore atrás de propriedades que outros
## nós não têm.
func _find_actor() -> Node:
	var parent: Node = get_parent()
	if parent == null:
		return null
	var movement: Variant = parent.get("movement_enabled")
	return parent if movement is bool else null
