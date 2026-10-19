class_name VideoApplier
extends RefCounted
## Aplica as opções de vídeo ao `DisplayServer`.
##
## Segurança contra "tela presa":
## - a resolução é sempre limitada ao **tamanho útil da tela atual** e a um
##   tamanho mínimo legível (1024×576) — nunca força algo maior que o monitor;
## - o modo de janela é reaplicado do zero a cada chamada, então sempre é
##   possível voltar para janela;
## - a proporção da imagem é preservada pelo stretch `canvas_items` + aspecto
##   `keep` configurado no projeto (sem deformar a interface);
## - em modo headless (CI/testes) nada é aplicado.

## Tamanho mínimo legível da janela (espelha o esquema).
static func minimum_size() -> Vector2i:
	return Vector2i(SettingsSchema.MIN_WINDOW_WIDTH, SettingsSchema.MIN_WINDOW_HEIGHT)


## True quando rodando sem servidor gráfico (CI, `--headless`).
static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Tamanho útil do monitor atual, já descontando barra de tarefas.
static func screen_usable_size() -> Vector2i:
	if is_headless():
		return minimum_size()
	var screen: int = DisplayServer.window_get_current_screen()
	var rect: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	if rect.size.x <= 0 or rect.size.y <= 0:
		rect = Rect2i(Vector2i.ZERO, DisplayServer.screen_get_size(screen))
	if rect.size.x <= 0 or rect.size.y <= 0:
		return minimum_size()
	return rect.size


## Resoluções oferecidas na interface, filtradas pelo que cabe na tela.
static func available_resolutions() -> Array:
	var usable: Vector2i = screen_usable_size()
	var result: Array = []
	for candidate: Vector2i in SettingsSchema.RESOLUTION_CANDIDATES:
		if is_headless() or candidate.x <= usable.x and candidate.y <= usable.y:
			result.append(candidate)
	if result.is_empty():
		result.append(clamp_resolution(Vector2i(
			SettingsSchema.DEFAULT_RESOLUTION_X, SettingsSchema.DEFAULT_RESOLUTION_Y
		)))
	return result


## Limita uma resolução ao intervalo seguro para o monitor atual.
static func clamp_resolution(resolution: Vector2i) -> Vector2i:
	var usable: Vector2i = screen_usable_size()
	var max_x: int = maxi(usable.x, 1)
	var max_y: int = maxi(usable.y, 1)
	var min_x: int = mini(minimum_size().x, max_x)
	var min_y: int = mini(minimum_size().y, max_y)
	return Vector2i(
		clampi(resolution.x, min_x, max_x),
		clampi(resolution.y, min_y, max_y)
	)


## Aplica modo de janela, resolução e VSync.
static func apply(values: Dictionary) -> void:
	if is_headless():
		return

	var video: Dictionary = values.get(SettingsSchema.SECTION_VIDEO, {})
	var mode: int = int(video.get("window_mode", SettingsSchema.WindowMode.WINDOWED))
	var resolution := clamp_resolution(Vector2i(
		int(video.get("resolution_x", SettingsSchema.DEFAULT_RESOLUTION_X)),
		int(video.get("resolution_y", SettingsSchema.DEFAULT_RESOLUTION_Y))
	))
	var vsync_enabled: bool = bool(video.get("vsync", SettingsSchema.DEFAULT_VSYNC))

	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)

	match mode:
		SettingsSchema.WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		SettingsSchema.WindowMode.MAXIMIZED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		_:
			# Sair de fullscreen/maximizado antes de redimensionar.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(resolution)
			_center_window(resolution)


## Resolução efetivamente aplicada (útil para diagnóstico).
static func current_resolution() -> Vector2i:
	if is_headless():
		return Vector2i.ZERO
	return DisplayServer.window_get_size()


static func current_mode() -> int:
	if is_headless():
		return SettingsSchema.WindowMode.WINDOWED
	match DisplayServer.window_get_mode():
		DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			return SettingsSchema.WindowMode.FULLSCREEN
		DisplayServer.WINDOW_MODE_MAXIMIZED:
			return SettingsSchema.WindowMode.MAXIMIZED
		_:
			return SettingsSchema.WindowMode.WINDOWED


static func _center_window(resolution: Vector2i) -> void:
	var screen: int = DisplayServer.window_get_current_screen()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return
	var centered := usable.position + (usable.size - resolution) / 2
	DisplayServer.window_set_position(centered)
