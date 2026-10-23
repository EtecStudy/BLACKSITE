class_name StaminaBar
extends VBoxContainer
## Rótulo + valor + trilho da stamina.
##
## Recebe os valores do controlador por `set_values()` e repassa na hora ao
## desenho — não guarda stamina própria. O valor em texto é limitado a 0–100% e
## acompanha exatamente a razão atual/máxima.

const LABEL_COLOR := Color(0.56, 0.53, 0.47, 1.0)
const VALUE_COLOR := Color(0.92, 0.89, 0.82, 1.0)
const LABEL_SIZE := 14

@onready var _title: Label = %Title
@onready var _value: Label = %Value
@onready var _fill: StaminaFill = %Track

@export var label_text: String = "STAMINA"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.text = label_text
	_title.add_theme_color_override("font_color", LABEL_COLOR)
	_title.add_theme_font_size_override("font_size", LABEL_SIZE)
	_value.add_theme_color_override("font_color", VALUE_COLOR)
	_value.add_theme_font_size_override("font_size", LABEL_SIZE)
	set_values(100.0, 100.0)


## Atualiza a barra a partir dos valores absolutos do controlador.
func set_values(current: float, maximum: float) -> void:
	if not is_node_ready():
		return
	var ratio: float = _ratio_from_values(current, maximum)
	_fill.set_ratio(ratio)
	_value.text = "%d%%" % roundi(ratio * 100.0)


func get_ratio() -> float:
	return _fill.get_ratio() if is_node_ready() else 1.0


func get_value_text() -> String:
	return _value.text if is_node_ready() else ""


func get_fill_width() -> float:
	return _fill.get_fill_width() if is_node_ready() else 0.0


func is_low() -> bool:
	return is_node_ready() and _fill.get_ratio() < _fill.low_threshold


func _ratio_from_values(current: float, maximum: float) -> float:
	if maximum <= 0.0:
		return 0.0
	return clampf(current / maximum, 0.0, 1.0)
