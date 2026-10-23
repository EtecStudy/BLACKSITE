class_name Inventory
extends Node
## Inventário do jogador — **exatamente três slots** (Etapa 8).
##
## Responsabilidades (e só elas):
## - guardar os itens nos slots;
## - adicionar no primeiro slot livre (sem substituir nada quando está cheio);
## - remover e substituir o item de um slot;
## - selecionar um slot (inclusive vazio);
## - informar qual item está selecionado;
## - emitir sinais quando o estado muda — a HUD **não** consulta por frame.
##
## O inventário **não** conhece a HUD, o jogador, a cena nem a câmera: é um nó
## de dados com API pública. Quem decide quando adicionar é o objeto interativo
## (`items/`), quem desenha é a HUD (`ui/`), quem liga os dois é `match/`.
##
## Sem drop, sem transferência, sem pilha, sem peso, sem uso de item nesta etapa.
## A remoção existe para validar o sistema e será revista quando houver descarte.

## Número de slots. Centralizado aqui: o resto do projeto lê este valor.
const SLOT_COUNT := 3

## Índice do slot selecionado ao começar (slot 1).
const FIRST_SLOT := 0

## Conteúdo de algum slot mudou (adicionar, remover, substituir, limpar).
signal inventory_changed
## O slot selecionado mudou (índice e item atual, que pode ser null).
signal selection_changed(slot_index: int, item: ItemDefinition)
## Um item entrou em um slot (emitido depois de `inventory_changed`).
signal item_added(slot_index: int, item: ItemDefinition)
## Um item saiu de um slot.
signal item_removed(slot_index: int, item: ItemDefinition)
## O item de um slot foi trocado (`previous` pode ser null em slot vazio).
signal item_replaced(slot_index: int, previous: ItemDefinition, current: ItemDefinition)
## Tentativa de adicionar com o inventário cheio — nada foi alterado.
signal item_rejected(item: ItemDefinition)

var _slots: Array[InventorySlot] = []
var _selected_index: int = FIRST_SLOT


func _init() -> void:
	for index: int in SLOT_COUNT:
		_slots.append(InventorySlot.new(index))


func _ready() -> void:
	# Inventário é estado, não animação: nada roda por frame.
	set_process(false)
	set_physics_process(false)


# --- Leitura ----------------------------------------------------------------

func get_slot_count() -> int:
	return _slots.size()


func is_valid_index(index: int) -> bool:
	return index >= 0 and index < _slots.size()


func get_slot(index: int) -> InventorySlot:
	if not is_valid_index(index):
		return null
	return _slots[index]


func get_item(index: int) -> ItemDefinition:
	var slot: InventorySlot = get_slot(index)
	return slot.get_item() if slot != null else null


func is_slot_empty(index: int) -> bool:
	var slot: InventorySlot = get_slot(index)
	return slot == null or slot.is_empty()


func get_used_slot_count() -> int:
	var used: int = 0
	for slot: InventorySlot in _slots:
		if slot.has_item():
			used += 1
	return used


func has_free_slot() -> bool:
	return find_first_free_slot() >= 0


## Primeiro slot livre, ou -1 quando os três estão ocupados.
func find_first_free_slot() -> int:
	for slot: InventorySlot in _slots:
		if slot.is_empty():
			return slot.index
	return -1


func get_selected_slot() -> int:
	return _selected_index


func get_selected_slot_object() -> InventorySlot:
	return get_slot(_selected_index)


## Item do slot selecionado — null quando o slot está vazio.
func get_selected_item() -> ItemDefinition:
	return get_item(_selected_index)


func is_slot_selected(index: int) -> bool:
	return index == _selected_index


# --- Alterações --------------------------------------------------------------

## Coloca o item no primeiro slot livre. Devolve false (sem alterar nada) quando
## o inventário está cheio ou o item é inválido.
func add_item(item: ItemDefinition) -> bool:
	if not _is_valid_item(item):
		return false
	var index: int = find_first_free_slot()
	if index < 0:
		# Cheio: nenhum item existente é apagado ou substituído.
		item_rejected.emit(item)
		return false
	_slots[index].set_item(item)
	item_added.emit(index, item)
	inventory_changed.emit()
	return true


## Remove o item do slot. Devolve false quando o índice é inválido ou o slot já
## está vazio. Não cria drop: o item simplesmente deixa o inventário.
func remove_item(index: int) -> bool:
	if not is_valid_index(index) or _slots[index].is_empty():
		return false
	var removed: ItemDefinition = _slots[index].clear()
	item_removed.emit(index, removed)
	inventory_changed.emit()
	return true


## Troca o item do slot. Devolve false quando o índice é inválido ou o item é
## inválido. O item anterior **não** vai para outro slot nem para o chão.
func replace_item(index: int, item: ItemDefinition) -> bool:
	if not is_valid_index(index) or not _is_valid_item(item):
		return false
	var previous: ItemDefinition = _slots[index].get_item()
	_slots[index].set_item(item)
	item_replaced.emit(index, previous, item)
	inventory_changed.emit()
	return true


## Seleciona um slot (vazio ou não). Devolve false apenas para índice inválido.
func select_slot(index: int) -> bool:
	if not is_valid_index(index):
		return false
	if index == _selected_index:
		return true
	_selected_index = index
	selection_changed.emit(index, get_item(index))
	return true


## Esvazia todos os slots (mantém a seleção). Usado por testes e por reinícios.
func clear() -> void:
	var changed: bool = false
	for slot: InventorySlot in _slots:
		if slot.has_item():
			slot.clear()
			changed = true
	if changed:
		inventory_changed.emit()


func _is_valid_item(item: ItemDefinition) -> bool:
	return item != null and item.is_valid()
