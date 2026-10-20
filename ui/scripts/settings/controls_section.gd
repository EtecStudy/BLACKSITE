class_name ControlsSection
extends SettingsSection
## Seção CONTROLES — sensibilidade do mouse, modo de agachamento e a lista
## **real** dos controles implementados.
##
## A lista descreve apenas o que existe hoje no jogo: mover, correr, agachar,
## interagir, selecionar slot do inventário, olhar, pausar e tela cheia. Pulo,
## lanterna, uso/descarte de item e inventário completo não aparecem porque não
## estão implementados. A tecla R (remoção provisória da Etapa 8) também não é
## listada: é uma ação de teste, que será substituída nas próximas etapas.
##
## A descrição do Ctrl é dinâmica: em ALTERNAR mostra "Alternar agachamento";
## em SEGURAR mostra "Segurar para agachar". A preferência fica em
## `GameSettings` (`crouch_mode`) e é aplicada sem reiniciar o jogo.

## Modos na ordem exibida na interface (espelham `SettingsSchema`).
const CROUCH_MODES := ["hold", "toggle"]

## Linhas fixas da lista. O Ctrl entra na ordem natural com texto dinâmico.
const KEY_ROWS := [
	["W A S D", "Mover"],
	["Shift", "Correr (consome stamina)"],
	["Ctrl", ""],
	["E", "Interagir"],
	["1 2 3", "Selecionar slot"],
	["Mouse", "Olhar"],
	["Esc", "Pausar"],
	["F11", "Tela cheia"],
]

var _sensitivity_x: HSlider
var _sensitivity_y: HSlider
var _invert_y: CheckButton
var _crouch_mode_option: OptionButton
var _crouch_hint: Label


func setup(values: Dictionary) -> void:
	var controls: Dictionary = values.get(SettingsSchema.SECTION_CONTROLS, {})

	add_section_title("SENSIBILIDADE DO MOUSE")
	_sensitivity_x = add_slider_row(
		"Sensibilidade horizontal",
		SettingsSchema.MOUSE_SENSITIVITY_MIN,
		SettingsSchema.MOUSE_SENSITIVITY_MAX,
		SettingsSchema.MOUSE_SENSITIVITY_STEP,
		float(controls.get("mouse_sensitivity_x", SettingsSchema.DEFAULT_MOUSE_SENSITIVITY_X)),
		_format_multiplier,
		"Multiplicador do movimento horizontal da câmera."
	)
	_sensitivity_y = add_slider_row(
		"Sensibilidade vertical",
		SettingsSchema.MOUSE_SENSITIVITY_MIN,
		SettingsSchema.MOUSE_SENSITIVITY_MAX,
		SettingsSchema.MOUSE_SENSITIVITY_STEP,
		float(controls.get("mouse_sensitivity_y", SettingsSchema.DEFAULT_MOUSE_SENSITIVITY_Y)),
		_format_multiplier,
		"Multiplicador do movimento vertical da câmera."
	)
	_invert_y = add_check_row(
		"Inverter eixo vertical",
		bool(controls.get("invert_y", SettingsSchema.DEFAULT_INVERT_Y)),
		"Inverte o olhar para cima/baixo."
	)

	add_divider()
	add_section_title("MODO DE AGACHAMENTO")
	var crouch_mode: String = SettingsSchema.normalize_crouch_mode(
		controls.get("crouch_mode"), SettingsSchema.DEFAULT_CROUCH_MODE
	)
	_crouch_mode_option = add_option_row(
		"Agachar com Ctrl",
		_crouch_mode_labels(),
		maxi(CROUCH_MODES.find(crouch_mode), 0),
		"ALTERNAR: um toque agacha, outro levanta. SEGURAR: mantenha Ctrl pressionado."
	)
	_crouch_mode_option.item_selected.connect(_on_crouch_mode_selected)

	add_divider()
	add_section_title("CONTROLES")
	add_note(
		"Controles implementados nesta versão. A tecla Ctrl se ajusta ao modo "
		+ "de agachamento escolhido acima."
	)
	for entry: Array in KEY_ROWS:
		var key: String = str(entry[0])
		var text: String = _crouch_description() if key == "Ctrl" else str(entry[1])
		var description: Label = add_key_hint_row(key, text)
		if key == "Ctrl":
			_crouch_hint = description

	add_divider()
	add_note(
		"As preferências de controle são salvas em user://settings.cfg e "
		+ "aplicadas imediatamente, inclusive durante a partida."
	)


func read_values() -> Dictionary:
	if _sensitivity_x == null:
		return {}
	return {
		SettingsSchema.SECTION_CONTROLS: {
			"mouse_sensitivity_x": snappedf(float(_sensitivity_x.value), 0.01),
			"mouse_sensitivity_y": snappedf(float(_sensitivity_y.value), 0.01),
			"invert_y": _invert_y.button_pressed,
			"crouch_mode": crouch_mode_id(),
		}
	}


## Modo atualmente selecionado na interface (`hold` ou `toggle`).
func crouch_mode_id() -> String:
	if _crouch_mode_option == null:
		return SettingsSchema.DEFAULT_CROUCH_MODE
	var index: int = _crouch_mode_option.selected
	if index < 0 or index >= CROUCH_MODES.size():
		return SettingsSchema.DEFAULT_CROUCH_MODE
	return str(CROUCH_MODES[index])


## Seleciona um modo programaticamente (usado por testes de interface).
func set_crouch_mode_id(mode: String) -> void:
	if _crouch_mode_option == null:
		return
	var normalized: String = SettingsSchema.normalize_crouch_mode(mode)
	var index: int = maxi(CROUCH_MODES.find(normalized), 0)
	_crouch_mode_option.select(index)
	_update_crouch_hint()


## Texto da linha do Ctrl (muda com o modo).
func get_crouch_hint_text() -> String:
	return _crouch_hint.text if _crouch_hint != null else ""


## Lista exibida no painel, no formato [[tecla, descrição], ...].
func get_key_hint_rows() -> Array:
	var rows: Array = []
	for entry: Array in KEY_ROWS:
		var key: String = str(entry[0])
		rows.append([key, _crouch_description() if key == "Ctrl" else str(entry[1])])
	return rows


func _format_multiplier(value: float) -> String:
	return "%.2f×" % value


func _crouch_mode_labels() -> Array:
	var labels: Array = []
	for mode: String in CROUCH_MODES:
		labels.append(SettingsSchema.crouch_mode_label(mode))
	return labels


func _crouch_description() -> String:
	if crouch_mode_id() == SettingsSchema.CROUCH_MODE_HOLD:
		return "Segurar para agachar"
	return "Alternar agachamento"


func _on_crouch_mode_selected(_index: int) -> void:
	_update_crouch_hint()


func _update_crouch_hint() -> void:
	if _crouch_hint != null:
		_crouch_hint.text = _crouch_description()
