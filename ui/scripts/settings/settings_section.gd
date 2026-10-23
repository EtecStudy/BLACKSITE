class_name SettingsSection
extends VBoxContainer
## Base das seções da tela de configurações.
##
## Cada seção constrói seus próprios controles, expõe `read_values()` com o
## fragmento de configuração correspondente e emite `values_changed` quando algo
## muda. A tela apenas orquestra (montar, aplicar, restaurar, voltar).

signal values_changed

const TITLE_COLOR := Color(0.8, 0.76, 0.68, 1.0)
const TITLE_SIZE := 18
const HINT_COLOR := Color(0.56, 0.53, 0.47, 1.0)
const HINT_SIZE := 15
const BODY_SIZE := 17
const KEY_COLOR := Color(0.92, 0.89, 0.82, 1.0)


func _init() -> void:
	add_theme_constant_override("separation", 16)


## Preenche a seção a partir de um dicionário de configurações completo.
func setup(_values: Dictionary) -> void:
	pass


## Devolve o fragmento de configuração desta seção.
func read_values() -> Dictionary:
	return {}


# --- Helpers de construção ---------------------------------------------------

func add_section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", TITLE_COLOR)
	label.add_theme_font_size_override("font_size", TITLE_SIZE)
	add_child(label)
	return label


func make_hint(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", HINT_COLOR)
	label.add_theme_font_size_override("font_size", HINT_SIZE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func add_note(text: String) -> Label:
	var label := make_hint(text)
	add_child(label)
	return label


func add_divider() -> void:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = Color(0.62, 0.58, 0.51, 0.18)
	add_child(line)


func add_slider_row(title: String, min_value: float, max_value: float, step: float,
		value: float, formatter: Callable, hint: String = "") -> HSlider:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)

	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", BODY_SIZE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(300, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(slider)

	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", BODY_SIZE)
	value_label.custom_minimum_size = Vector2(88, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = str(formatter.call(slider.value))
	line.add_child(value_label)

	row.add_child(line)
	if not hint.is_empty():
		row.add_child(make_hint(hint))
	add_child(row)

	slider.value_changed.connect(func(new_value: float) -> void:
		value_label.text = str(formatter.call(new_value))
		values_changed.emit()
	)
	return slider


func add_check_row(title: String, pressed: bool, hint: String = "") -> CheckButton:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var check := CheckButton.new()
	check.text = title
	check.add_theme_font_size_override("font_size", BODY_SIZE)
	check.button_pressed = pressed
	row.add_child(check)

	if not hint.is_empty():
		row.add_child(make_hint(hint))
	add_child(row)

	check.toggled.connect(func(_toggled_on: bool) -> void: values_changed.emit())
	return check


func add_option_row(title: String, options: Array, selected_index: int,
		hint: String = "") -> OptionButton:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)

	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", BODY_SIZE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)

	var option := OptionButton.new()
	option.add_theme_font_size_override("font_size", BODY_SIZE)
	option.custom_minimum_size = Vector2(300, 0)
	for index: int in options.size():
		option.add_item(str(options[index]), index)
	if options.size() > 0:
		option.select(clampi(selected_index, 0, options.size() - 1))
	line.add_child(option)

	row.add_child(line)
	if not hint.is_empty():
		row.add_child(make_hint(hint))
	add_child(row)

	option.item_selected.connect(func(_index: int) -> void: values_changed.emit())
	return option


func add_key_hint_row(key_text: String, description: String) -> Label:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)

	var key_label := Label.new()
	key_label.text = key_text
	key_label.add_theme_font_size_override("font_size", BODY_SIZE)
	key_label.custom_minimum_size = Vector2(120, 0)
	key_label.add_theme_color_override("font_color", KEY_COLOR)
	line.add_child(key_label)

	var description_label := Label.new()
	description_label.text = description
	description_label.add_theme_font_size_override("font_size", BODY_SIZE)
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(description_label)

	add_child(line)
	return description_label
