class_name VideoSection
extends SettingsSection
## Seção VÍDEO — janela, resolução e VSync.
##
## A lista de resoluções é filtrada por `VideoApplier.available_resolutions()`,
## então nunca aparece uma opção maior que o monitor atual.
## Nada é aplicado ao mover os controles: a tela chama `GameSettings.apply()`
## no botão APLICAR, o que permite desistir sem mudar a janela.

var _resolutions: Array = []
var _resolution_option: OptionButton
var _mode_option: OptionButton
var _vsync_check: CheckButton


func setup(values: Dictionary) -> void:
	var video: Dictionary = values.get(SettingsSchema.SECTION_VIDEO, {})

	add_section_title("JANELA")
	_resolutions = VideoApplier.available_resolutions()

	var resolution_labels: Array = []
	for resolution: Vector2i in _resolutions:
		resolution_labels.append("%d × %d" % [resolution.x, resolution.y])

	_resolution_option = add_option_row(
		"Resolução da janela",
		resolution_labels,
		_find_resolution_index(
			int(video.get("resolution_x", SettingsSchema.DEFAULT_RESOLUTION_X)),
			int(video.get("resolution_y", SettingsSchema.DEFAULT_RESOLUTION_Y))
		),
		"Somente resoluções compatíveis com o monitor atual."
	)

	_mode_option = add_option_row(
		"Modo de janela",
		[
			SettingsSchema.window_mode_label(SettingsSchema.WindowMode.WINDOWED),
			SettingsSchema.window_mode_label(SettingsSchema.WindowMode.MAXIMIZED),
			SettingsSchema.window_mode_label(SettingsSchema.WindowMode.FULLSCREEN),
		],
		int(video.get("window_mode", SettingsSchema.DEFAULT_WINDOW_MODE)),
		"Tela cheia usa a resolução do monitor; a proporção da imagem é preservada."
	)

	_vsync_check = add_check_row(
		"Sincronização vertical (VSync)",
		bool(video.get("vsync", SettingsSchema.DEFAULT_VSYNC)),
		"Evita rasgos de imagem. Alguns drivers de vídeo podem ignorar esta opção."
	)

	add_divider()
	add_note(
		"As alterações de vídeo são aplicadas ao clicar em APLICAR. "
		+ "Se a janela ficar em um estado inesperado, use RESTAURAR PADRÕES "
		+ "ou o atalho F11 na tela inicial para alternar a tela cheia."
	)
	add_note(
		"A resolução é sempre limitada ao tamanho útil do monitor atual, "
		+ "para que o jogo nunca fique inacessível."
	)


func read_values() -> Dictionary:
	if _resolution_option == null:
		return {}
	var resolution := Vector2i(
		SettingsSchema.DEFAULT_RESOLUTION_X, SettingsSchema.DEFAULT_RESOLUTION_Y
	)
	var index: int = _resolution_option.selected
	if index >= 0 and index < _resolutions.size():
		resolution = _resolutions[index]
	return {
		SettingsSchema.SECTION_VIDEO: {
			"window_mode": _mode_option.selected,
			"resolution_x": resolution.x,
			"resolution_y": resolution.y,
			"vsync": _vsync_check.button_pressed,
		}
	}


## Seleciona a resolução da lista mais próxima da configuração atual.
func _find_resolution_index(width: int, height: int) -> int:
	var best_index := 0
	var best_distance := 1 << 30
	for index: int in _resolutions.size():
		var candidate: Vector2i = _resolutions[index]
		var distance: int = absi(candidate.x - width) + absi(candidate.y - height)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index
