class_name ControlsSection
extends SettingsSection
## Seção CONTROLES — teclado e mouse.
##
## Guarda apenas as preferências que o futuro controlador do jogador vai ler.
## Nenhuma movimentação é implementada nesta etapa.

const DEFAULT_CONTROLS := [
	["W A S D", "Mover"],
	["Mouse", "Olhar"],
	["Shift", "Correr"],
	["E", "Interagir"],
	["F", "Lanterna"],
	["Esc", "Pausar"],
]

var _sensitivity_x: HSlider
var _sensitivity_y: HSlider
var _invert_y: CheckButton


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
	add_section_title("CONTROLES PADRÃO PREVISTOS")
	add_note("Referência para o controlador do jogador das próximas etapas. Ainda não implementados.")
	for entry: Array in DEFAULT_CONTROLS:
		add_key_hint_row(str(entry[0]), str(entry[1]))

	add_divider()
	add_note(
		"Os valores de sensibilidade ficam salvos e serão lidos pelo controlador "
		+ "quando ele existir. Nesta etapa nenhum movimento é aplicado."
	)


func read_values() -> Dictionary:
	if _sensitivity_x == null:
		return {}
	return {
		SettingsSchema.SECTION_CONTROLS: {
			"mouse_sensitivity_x": snappedf(float(_sensitivity_x.value), 0.01),
			"mouse_sensitivity_y": snappedf(float(_sensitivity_y.value), 0.01),
			"invert_y": _invert_y.button_pressed,
		}
	}


func _format_multiplier(value: float) -> String:
	return "%.2f×" % value
