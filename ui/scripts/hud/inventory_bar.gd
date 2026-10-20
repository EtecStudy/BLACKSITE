class_name InventoryBar
extends HBoxContainer
## Barra dos três slots do inventário na HUD (Etapa 8).
##
## Só desenha: recebe o estado pronto (`set_slot` / `set_selected`) e não
## conhece o inventário, o jogador nem o InputMap. A HUD (`PlayerHud`) faz a
## ponte e escuta os sinais — **nada é consultado por frame**.
##
## Visual: mesmos tokens da HUD de stamina e das configurações — painel escuro
## translúcido, borda de 1 px, raio 2, pergaminho no texto e a mesma fonte do
## tema. O slot selecionado usa o realce já existente nos botões (fundo um pouco
## mais claro + borda mais forte), sem inventar cor nova.

const EMPTY_TEXT := "VAZIO"
const NUMBER_COLOR := Color(0.56, 0.53, 0.47, 1.0)
const NUMBER_SELECTED_COLOR := Color(0.93, 0.9, 0.83, 1.0)
const ITEM_COLOR := Color(0.9, 0.87, 0.8, 1.0)
const ITEM_EMPTY_COLOR := Color(0.42, 0.4, 0.36, 1.0)

## Estilo de um slot comum (definido na cena).
@export var normal_style: StyleBoxFlat = null
## Estilo do slot selecionado (definido na cena).
@export var selected_style: StyleBoxFlat = null

var _panels: Array[PanelContainer] = []
var _numbers: Array[Label] = []
var _items: Array[Label] = []
var _selected_index: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collect_slots()
	set_selected(0)


func _collect_slots() -> void:
	_panels.clear()
	_numbers.clear()
	_items.clear()
	for child: Node in get_children():
		var panel := child as PanelContainer
		if panel == null:
			continue
		var number := panel.find_child("Number", true, false) as Label
		var item := panel.find_child("Item", true, false) as Label
		if number == null or item == null:
			continue
		_panels.append(panel)
		_numbers.append(number)
		_items.append(item)


func get_slot_count() -> int:
	return _panels.size()


func get_slot_panel(index: int) -> PanelContainer:
	return _panels[index] if _is_valid(index) else null


func get_slot_text(index: int) -> String:
	return _items[index].text if _is_valid(index) else ""


func get_number_text(index: int) -> String:
	return _numbers[index].text if _is_valid(index) else ""


func get_selected_index() -> int:
	return _selected_index


func is_slot_selected(index: int) -> bool:
	return index == _selected_index


## Atualiza um slot: texto do item e estado vazio/ocupado.
func set_slot(index: int, item_text: String, empty: bool) -> void:
	if not _is_valid(index):
		return
	_items[index].text = EMPTY_TEXT if empty else item_text
	_items[index].add_theme_color_override(
		"font_color", ITEM_EMPTY_COLOR if empty else ITEM_COLOR
	)


## Esvazia todos os slots (sem mexer na seleção).
func clear_slots() -> void:
	for index: int in get_slot_count():
		set_slot(index, "", true)


## Move o realce para o slot indicado.
func set_selected(index: int) -> void:
	if not _is_valid(index):
		return
	_selected_index = index
	for slot_index: int in get_slot_count():
		var selected: bool = slot_index == index
		if _panels[slot_index] != null:
			var style: StyleBoxFlat = selected_style if selected else normal_style
			if style != null:
				_panels[slot_index].add_theme_stylebox_override("panel", style)
		_numbers[slot_index].add_theme_color_override(
			"font_color", NUMBER_SELECTED_COLOR if selected else NUMBER_COLOR
		)


func _is_valid(index: int) -> bool:
	return index >= 0 and index < _panels.size()
