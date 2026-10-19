extends Node
## Teste automatizado de fumaça do Black Sight (executado pelo CI e localmente).
##
## Uso:
##     godot --headless --path . res://tools/ci/smoke_test.tscn
##
## Roda como cena (e não como `--script`) para que os autoloads
## (`AppInfo`, `GameSettings`, `UiAudio`) existam de verdade — é assim que a
## persistência e a tela de configurações podem ser testadas de ponta a ponta.
##
## Sai com código 0 em caso de sucesso e 1 em caso de falha.

const EXPECTED_PROJECT_NAME := "Black Sight"
const EXPECTED_RENDERER := "gl_compatibility"
const EXPECTED_VIEWPORT := Vector2i(1920, 1080)
const EXPECTED_MAIN_SCENE := "res://ui/scenes/title_screen.tscn"
const SETTINGS_SCENE := "res://ui/scenes/settings_screen.tscn"
const TEST_CONFIG_PATH := "user://test_smoke_settings.cfg"

# Caminhos relativos à raiz da cena.
const EXPECTED_NODES := [
	"Background",
	"Dust",
	"Vignette",
	"Content",
	"Content/Emblem",
	"Content/TitleLabel",
	"Content/Buttons/StartButton",
	"Content/Buttons/TestMovementButton",
	"Content/Buttons/SettingsButton",
	"Content/Buttons/QuitButton",
	"Content/BuildLabel",
	"Fade",
]

const EXPECTED_TEXTURES := [
	"res://shared/textures/ui/background.png",
	"res://shared/textures/ui/vignette.png",
	"res://shared/textures/branding/emblem.png",
	"res://shared/textures/branding/icon_1024.png",
	"res://shared/textures/branding/boot_splash.png",
	"res://shared/textures/fx/dust.png",
]

const EXPECTED_MODULES := [
	"players",
	"creatures",
	"maps",
	"items",
	"objectives",
	"ui",
	"audio",
	"match",
	"shared",
]

const LEGACY_PATHS := [
	"res://scenes/boot/title_screen.tscn",
	"res://scripts/ui/title_screen.gd",
	"res://scripts/autoload/app_info.gd",
	"res://assets/themes/black_sight.tres",
	"res://assets/fonts/cinzel/Cinzel-Regular.ttf",
	"res://shared/textures/branding/icon_1024.png.old",
]

const EXPECTED_BUSES := ["Master", "Music", "SFX", "Ambience", "Voice"]

var _checks: int = 0
var _failures: PackedStringArray = PackedStringArray()
var _original_config_path: String = ""
var _original_settings: Dictionary = {}


func _ready() -> void:
	print("=== Black Sight · teste de fumaça ===")
	print("Godot: %s" % Engine.get_version_info().get("string", "?"))

	var settings = get_node_or_null("/root/GameSettings")
	if settings != null:
		_original_config_path = settings.config_path
		_original_settings = settings.current()
		settings.config_path = TEST_CONFIG_PATH
		_remove_test_file()

	_check_project_settings()
	_check_autoloads()
	_check_theme()
	_check_fonts()
	_check_textures()
	_check_modules()
	_check_main_scene()
	_check_export_preset()
	_check_settings_core()
	_check_audio_buses()
	_check_video_safety()
	_check_settings_screen()
	_check_fps_controller()

	if settings != null:
		settings.config_path = _original_config_path
		settings.apply(_original_settings)
		_remove_test_file()

	# Dá um frame para os nós enfileirados (queue_free) serem liberados antes da saída.
	await get_tree().process_frame

	print("")
	if _failures.is_empty():
		print("SMOKE TEST OK — %d verificações aprovadas" % _checks)
		get_tree().quit(0)
		return

	printerr("SMOKE TEST FALHOU — %d de %d verificações falharam" % [_failures.size(), _checks])
	for failure: String in _failures:
		printerr("  ✗ " + failure)
	get_tree().quit(1)


# ---------------------------------------------------------------------------


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ " + description)
	else:
		_failures.append(description)
		printerr("  ✗ " + description)


func _remove_test_file() -> void:
	if FileAccess.file_exists(TEST_CONFIG_PATH):
		DirAccess.remove_absolute(TEST_CONFIG_PATH)


func _check_project_settings() -> void:
	print("[1] Configuração do projeto")
	var project_name: String = str(ProjectSettings.get_setting("application/config/name", ""))
	_expect(project_name == EXPECTED_PROJECT_NAME, "nome do projeto é '%s'" % EXPECTED_PROJECT_NAME)

	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	_expect(not version.is_empty(), "versão do projeto definida ('%s')" % version)

	var renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	_expect(renderer == EXPECTED_RENDERER, "renderizador é '%s'" % EXPECTED_RENDERER)

	var mobile_renderer: String = str(
		ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "")
	)
	_expect(mobile_renderer == EXPECTED_RENDERER, "renderizador mobile é '%s'" % EXPECTED_RENDERER)

	var width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	var height: int = int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	_expect(
		Vector2i(width, height) == EXPECTED_VIEWPORT,
		"resolução lógica é %s" % str(EXPECTED_VIEWPORT)
	)

	var stretch_mode: String = str(ProjectSettings.get_setting("display/window/stretch/mode", ""))
	_expect(stretch_mode == "canvas_items", "stretch mode é 'canvas_items'")

	var stretch_aspect: String = str(ProjectSettings.get_setting("display/window/stretch/aspect", ""))
	_expect(stretch_aspect == "keep", "stretch aspect é 'keep' (sem deformar a interface)")

	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_expect(main_scene == EXPECTED_MAIN_SCENE, "cena principal é '%s'" % EXPECTED_MAIN_SCENE)
	_expect(FileAccess.file_exists(EXPECTED_MAIN_SCENE), "arquivo da cena principal existe")

	var icon: String = str(ProjectSettings.get_setting("application/config/icon", ""))
	_expect(not icon.is_empty(), "ícone do projeto configurado")

	var splash: String = str(ProjectSettings.get_setting("application/boot_splash/image", ""))
	_expect(not splash.is_empty(), "imagem de boot splash configurada")

	var layout: String = str(ProjectSettings.get_setting("audio/buses/default_bus_layout", ""))
	_expect(layout.ends_with("audio/default_bus_layout.tres"), "layout de buses configurado (%s)" % layout)


func _check_autoloads() -> void:
	print("[2] Autoloads")
	var settings_entry: String = str(ProjectSettings.get_setting("autoload/GameSettings", ""))
	_expect(not settings_entry.is_empty(), "autoload GameSettings registrado")

	var audio_entry: String = str(ProjectSettings.get_setting("autoload/UiAudio", ""))
	_expect(not audio_entry.is_empty(), "autoload UiAudio registrado")

	_expect(get_node_or_null("/root/AppInfo") != null, "AppInfo disponível na árvore")
	_expect(get_node_or_null("/root/GameSettings") != null, "GameSettings disponível na árvore")
	_expect(get_node_or_null("/root/UiAudio") != null, "UiAudio disponível na árvore")

	var app_info = get_node_or_null("/root/AppInfo")
	if app_info != null:
		_expect(
			str(app_info.version_label()).begins_with("v"),
			"AppInfo expõe versão (%s)" % str(app_info.version_label())
		)


func _check_theme() -> void:
	print("[3] Tema e fonte")
	var theme_path: String = str(ProjectSettings.get_setting("gui/theme/custom", ""))
	_expect(not theme_path.is_empty(), "tema customizado configurado")
	_expect(ResourceLoader.exists(theme_path), "tema pode ser carregado")

	var theme: Theme = load(theme_path) as Theme
	_expect(theme != null, "tema é do tipo Theme")
	if theme == null:
		return
	_expect(theme.default_font != null, "tema define uma fonte padrão")
	if theme.default_font != null:
		var size: Vector2 = theme.default_font.get_string_size(
			"Black Sight", HORIZONTAL_ALIGNMENT_LEFT, -1, 20
		)
		_expect(size.x > 10.0 and size.y > 10.0, "fonte padrão mede texto corretamente")
	_expect(theme.has_stylebox("normal", "Button"), "tema define estilo do botão (normal)")


func _check_fonts() -> void:
	print("[4] Arquivos de fonte")
	for font_path: String in [
		"res://shared/fonts/cinzel/Cinzel-Regular.ttf",
		"res://shared/fonts/cinzel/Cinzel-SemiBold.ttf",
	]:
		_expect(FileAccess.file_exists(font_path), "fonte presente: %s" % font_path)
		var font: Font = load(font_path) as Font
		_expect(font != null, "fonte carrega: %s" % font_path)
		if font != null:
			var width: float = font.get_string_size(
				"BLACK SIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 48
			).x
			_expect(width > 50.0, "fonte renderiza texto: %s" % font_path)


func _check_textures() -> void:
	print("[5] Texturas importadas")
	for asset_path: String in EXPECTED_TEXTURES:
		_expect(ResourceLoader.exists(asset_path), "recurso importado: %s" % asset_path)
		var texture: Texture2D = load(asset_path) as Texture2D
		_expect(texture != null, "textura carrega: %s" % asset_path)

	for sound_path: String in [
		"res://audio/assets/sfx/ui_click.wav",
		"res://audio/assets/sfx/ui_confirm.wav",
	]:
		_expect(FileAccess.file_exists(sound_path), "som de interface presente: %s" % sound_path)
		_expect(ResourceLoader.exists(sound_path), "som de interface importado: %s" % sound_path)


func _check_modules() -> void:
	print("[6] Módulos da arquitetura")
	for module: String in EXPECTED_MODULES:
		var dir_path := "res://%s" % module
		_expect(DirAccess.dir_exists_absolute(dir_path), "módulo existe: %s/" % module)
		_expect(
			FileAccess.file_exists("%s/README.md" % dir_path),
			"módulo documentado: %s/README.md" % module
		)

	_expect(
		FileAccess.file_exists("res://docs/ARQUITETURA.md"),
		"documento de arquitetura presente (docs/ARQUITETURA.md)"
	)
	_expect(
		FileAccess.file_exists("res://docs/CONFIGURACOES.md"),
		"documentação das configurações presente (docs/CONFIGURACOES.md)"
	)

	for legacy: String in LEGACY_PATHS:
		if legacy.ends_with(".old"):
			continue
		_expect(not FileAccess.file_exists(legacy), "caminho antigo removido: %s" % legacy)

	_expect(
		FileAccess.file_exists("res://ui/scenes/title_screen.tscn"),
		"tela inicial está no módulo ui/"
	)
	_expect(
		FileAccess.file_exists("res://shared/settings/game_settings.gd"),
		"gerenciador de configurações está em shared/settings/"
	)
	_expect(
		FileAccess.file_exists("res://audio/default_bus_layout.tres"),
		"layout de áudio está no módulo audio/"
	)

	# Módulos que ainda são apenas estrutura não podem ter código de gameplay.
	for pending_module: String in ["creatures", "items", "objectives"]:
		var files := _list_gdscript_files("res://%s" % pending_module)
		_expect(
			files.is_empty(),
			"módulo %s ainda não tem scripts (estrutura preparatória)" % pending_module
		)


func _list_gdscript_files(path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := path.path_join(entry)
		if dir.current_is_dir():
			found.append_array(_list_gdscript_files(full))
		elif entry.ends_with(".gd"):
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found


func _check_main_scene() -> void:
	print("[7] Cena inicial")
	var packed: PackedScene = load(EXPECTED_MAIN_SCENE) as PackedScene
	_expect(packed != null, "cena inicial é um PackedScene")
	if packed == null:
		return

	var instance: Node = packed.instantiate()
	_expect(instance != null, "cena inicial pode ser instanciada")
	if instance == null:
		return

	_expect(instance.name == "TitleScreen", "raiz da cena é 'TitleScreen'")
	for expected: String in EXPECTED_NODES:
		_expect(instance.get_node_or_null(expected) != null, "nó presente na cena: %s" % expected)

	var root_script: Script = instance.get_script() as Script
	_expect(root_script != null, "cena raiz tem script anexado")

	var start_button: Button = instance.get_node_or_null("Content/Buttons/StartButton") as Button
	_expect(start_button != null and start_button.disabled, "botão JOGAR segue desabilitado")

	instance.free()


func _check_export_preset() -> void:
	print("[8] Preset de exportação")
	var preset_path := "res://export_presets.cfg"
	_expect(FileAccess.file_exists(preset_path), "export_presets.cfg existe")
	if not FileAccess.file_exists(preset_path):
		return
	var content := FileAccess.get_file_as_string(preset_path)
	_expect(content.contains('name="Windows Desktop"'), "preset 'Windows Desktop' presente")
	_expect(content.contains('platform="Windows Desktop"'), "plataforma Windows Desktop configurada")
	_expect(
		content.contains("res://shared/textures/branding/icon.ico"),
		"ícone do executável configurado no preset"
	)


# --- Etapa 3: configurações --------------------------------------------------

func _check_settings_core() -> void:
	print("[9] Configurações — esquema e persistência")
	var defaults: Dictionary = SettingsSchema.defaults()
	_expect(
		defaults.has(SettingsSchema.SECTION_CONTROLS)
		and defaults.has(SettingsSchema.SECTION_AUDIO)
		and defaults.has(SettingsSchema.SECTION_VIDEO),
		"esquema tem as três seções (controles, áudio, vídeo)"
	)

	# valores inválidos precisam ser corrigidos, não aceitos
	var raw := {
		"controls": {"mouse_sensitivity_x": -3.0, "mouse_sensitivity_y": 999.0, "invert_y": "sim"},
		"audio": {"master_volume": 500, "sfx_volume": -40, "ambience_volume": "x", "music_volume": 55},
		"video": {"window_mode": 99, "resolution_x": 10, "resolution_y": 10, "vsync": "não"},
	}
	var sane: Dictionary = SettingsSchema.sanitize(raw)
	_expect(
		float(sane.controls.mouse_sensitivity_x) >= SettingsSchema.MOUSE_SENSITIVITY_MIN,
		"sensibilidade negativa é limitada ao mínimo"
	)
	_expect(
		float(sane.controls.mouse_sensitivity_y) <= SettingsSchema.MOUSE_SENSITIVITY_MAX,
		"sensibilidade excessiva é limitada ao máximo"
	)
	_expect(int(sane.audio.master_volume) == 100, "volume acima de 100 é limitado a 100")
	_expect(int(sane.audio.sfx_volume) == 0, "volume negativo é limitado a 0")
	_expect(
		int(sane.audio.music_volume) == 55, "volume válido é preservado (music=55)"
	)
	_expect(int(sane.audio.ambience_volume) == 70, "volume inválido cai no padrão")
	_expect(
		int(sane.video.window_mode) == SettingsSchema.WindowMode.WINDOWED,
		"modo de janela inválido cai no padrão"
	)
	_expect(
		int(sane.video.resolution_x) >= SettingsSchema.MIN_WINDOW_WIDTH,
		"resolução pequena demais é limitada"
	)

	var settings = get_node_or_null("/root/GameSettings")
	_expect(settings != null, "autoload GameSettings disponível para os testes")
	if settings == null:
		return

	# gravação + releitura
	var custom: Dictionary = SettingsSchema.defaults()
	custom[SettingsSchema.SECTION_AUDIO]["master_volume"] = 42
	custom[SettingsSchema.SECTION_CONTROLS]["invert_y"] = true
	custom[SettingsSchema.SECTION_VIDEO]["vsync"] = false
	var saved: bool = settings.apply(custom)
	_expect(saved, "apply() grava o arquivo de configurações")
	_expect(FileAccess.file_exists(TEST_CONFIG_PATH), "arquivo de configurações criado em user://")

	var reread: Dictionary = settings.load_settings()
	_expect(int(reread.audio.master_volume) == 42, "volume gravado é lido de volta (42)")
	_expect(bool(reread.controls.invert_y) == true, "inverter eixo gravado é lido de volta")
	_expect(bool(reread.video.vsync) == false, "vsync gravado é lido de volta")

	# simula reinício: outra instância lendo o mesmo arquivo
	var settings_script: Script = load("res://shared/settings/game_settings.gd") as Script
	var fresh = settings_script.new()
	fresh.config_path = TEST_CONFIG_PATH
	var from_disk: Dictionary = fresh.load_settings()
	fresh.free()
	_expect(
		int(from_disk.audio.master_volume) == 42,
		"configuração sobrevive a um 'reinício' (nova instância lê 42)"
	)

	# arquivo corrompido não pode impedir o jogo de abrir
	var file := FileAccess.open(TEST_CONFIG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("isto nao e um configfile valido [[[")
		file.close()
	var fallback: Dictionary = settings.load_settings()
	_expect(
		int(fallback.audio.master_volume) == SettingsSchema.DEFAULT_MASTER_VOLUME,
		"arquivo corrompido cai nos valores padrão"
	)

	# restaurar padrões
	var restored: bool = settings.restore_defaults()
	_expect(restored, "restaurar padrões grava o arquivo")
	var after_reset: Dictionary = settings.current()
	_expect(
		int(after_reset.audio.master_volume) == SettingsSchema.DEFAULT_MASTER_VOLUME,
		"restaurar padrões devolve o volume padrão"
	)
	var disk_after_reset: Dictionary = settings.load_settings()
	_expect(
		int(disk_after_reset.audio.master_volume) == SettingsSchema.DEFAULT_MASTER_VOLUME,
		"padrões restaurados ficam persistidos no disco"
	)


func _check_audio_buses() -> void:
	print("[10] Áudio — buses e aplicação de volume")
	for bus_name: String in EXPECTED_BUSES:
		_expect(
			AudioServer.get_bus_index(bus_name) >= 0,
			"bus de áudio existe: %s" % bus_name
		)

	var values: Dictionary = SettingsSchema.defaults()
	values[SettingsSchema.SECTION_AUDIO]["master_volume"] = 100
	values[SettingsSchema.SECTION_AUDIO]["sfx_volume"] = 25
	values[SettingsSchema.SECTION_AUDIO]["music_volume"] = 0
	AudioApplier.apply(values)

	_expect(
		absi(AudioApplier.get_bus_percent("SFX") - 25) <= 1,
		"volume de SFX aplicado ao bus (25%%) — obtido %d%%" % AudioApplier.get_bus_percent("SFX")
	)
	_expect(
		absi(AudioApplier.get_bus_percent("Master") - 100) <= 1,
		"volume geral aplicado ao bus Master"
	)
	var music_index: int = AudioServer.get_bus_index("Music")
	_expect(
		music_index >= 0 and AudioServer.is_bus_mute(music_index),
		"volume 0%% silencia o bus de música"
	)

	AudioApplier.apply(SettingsSchema.defaults())
	_expect(
		not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),
		"voltar ao padrão reativa o bus de música"
	)


func _check_video_safety() -> void:
	print("[11] Vídeo — limites de segurança")
	var huge := VideoApplier.clamp_resolution(Vector2i(99999, 99999))
	var usable: Vector2i = VideoApplier.screen_usable_size()
	_expect(
		huge.x <= maxi(usable.x, SettingsSchema.MIN_WINDOW_WIDTH)
		and huge.y <= maxi(usable.y, SettingsSchema.MIN_WINDOW_HEIGHT),
		"resolução absurda é limitada ao tamanho da tela"
	)
	var tiny := VideoApplier.clamp_resolution(Vector2i(10, 10))
	_expect(
		tiny.x >= SettingsSchema.MIN_WINDOW_WIDTH and tiny.y >= SettingsSchema.MIN_WINDOW_HEIGHT,
		"resolução minúscula sobe para o tamanho mínimo legível"
	)
	var options: Array = VideoApplier.available_resolutions()
	_expect(options.size() >= 1, "há ao menos uma resolução disponível (%d)" % options.size())
	var all_16_9 := true
	for candidate: Vector2i in options:
		if not (candidate.x > 0 and candidate.y > 0):
			all_16_9 = false
	_expect(all_16_9, "resoluções oferecidas são válidas")

	_expect(
		SettingsSchema.window_mode_label(SettingsSchema.WindowMode.FULLSCREEN) == "Tela cheia",
		"modos de janela têm rótulos em português"
	)


func _check_settings_screen() -> void:
	print("[12] Tela de configurações — interface")
	var packed: PackedScene = load(SETTINGS_SCENE) as PackedScene
	_expect(packed != null, "cena de configurações é um PackedScene")
	if packed == null:
		return

	var screen: Control = packed.instantiate() as Control
	_expect(screen != null, "cena de configurações instancia")
	if screen == null:
		return

	add_child(screen)

	var sidebar := "Margin/Layout/Body/Sidebar"
	var footer := "Margin/Layout/Footer"
	var host_path := "Margin/Layout/Body/Panel/PanelMargin/Scroll/SectionHost"

	var host: Node = screen.get_node_or_null(host_path)
	_expect(host != null, "área de seções existe")
	_expect(screen.get_node_or_null(sidebar + "/TabControls") != null, "aba CONTROLES existe")
	_expect(screen.get_node_or_null(sidebar + "/TabAudio") != null, "aba ÁUDIO existe")
	_expect(screen.get_node_or_null(sidebar + "/TabVideo") != null, "aba VÍDEO existe")

	var apply_button: Button = screen.get_node_or_null(footer + "/ApplyButton") as Button
	var defaults_button: Button = screen.get_node_or_null(footer + "/DefaultsButton") as Button
	var back_button: Button = screen.get_node_or_null(footer + "/BackButton") as Button
	_expect(apply_button != null, "botão APLICAR existe")
	_expect(defaults_button != null, "botão RESTAURAR PADRÕES existe")
	_expect(back_button != null, "botão VOLTAR existe")
	if apply_button == null or defaults_button == null or back_button == null or host == null:
		remove_child(screen)
		screen.free()
		return

	_expect(back_button.pressed.get_connections().size() > 0, "botão VOLTAR está conectado")

	_expect(host.get_child_count() == 3, "três seções montadas (controles, áudio, vídeo)")

	var visible_count := 0
	for child: Node in host.get_children():
		if child is Control and (child as Control).visible:
			visible_count += 1
	_expect(visible_count == 1, "apenas uma seção visível por vez")

	# troca de abas
	var tab_audio: Button = screen.get_node(sidebar + "/TabAudio") as Button
	tab_audio.pressed.emit()
	visible_count = 0
	var audio_section: Node = null
	for child: Node in host.get_children():
		if child is AudioSection and (child as Control).visible:
			visible_count += 1
			audio_section = child
	_expect(visible_count == 1 and audio_section != null, "aba ÁUDIO mostra a seção de áudio")

	if audio_section != null:
		var sliders: Array = audio_section.find_children("*", "HSlider", true, false)
		_expect(sliders.size() == 4, "quatro sliders de volume na seção de áudio")
		if sliders.size() == 4:
			(sliders[0] as HSlider).value = 33.0
			apply_button.pressed.emit()
			var settings = get_node_or_null("/root/GameSettings")
			if settings != null:
				_expect(
					int(settings.current().audio.master_volume) == 33,
					"APLICAR grava o valor do slider (volume geral = 33)"
				)

	# restaurar padrões + aplicar
	defaults_button.pressed.emit()
	apply_button.pressed.emit()
	var settings_node = get_node_or_null("/root/GameSettings")
	if settings_node != null:
		_expect(
			int(settings_node.current().audio.master_volume) == SettingsSchema.DEFAULT_MASTER_VOLUME,
			"RESTAURAR PADRÕES devolve o volume padrão após aplicar"
		)

	# a seção de vídeo oferece resoluções e modos reais
	var tab_video: Button = screen.get_node(sidebar + "/TabVideo") as Button
	tab_video.pressed.emit()
	var video_section: Node = null
	for child: Node in host.get_children():
		if child is VideoSection and (child as Control).visible:
			video_section = child
	_expect(video_section != null, "aba VÍDEO mostra a seção de vídeo")
	if video_section != null:
		var options: Array = video_section.find_children("*", "OptionButton", true, false)
		_expect(options.size() == 2, "seção de vídeo tem resolução e modo de janela")
		if options.size() == 2:
			_expect((options[0] as OptionButton).item_count >= 1, "lista de resoluções preenchida")
			_expect((options[1] as OptionButton).item_count == 3, "três modos de janela")

	remove_child(screen)
	screen.free()

	# tela inicial: botão CONFIGURAÇÕES conectado
	var title_packed: PackedScene = load(EXPECTED_MAIN_SCENE) as PackedScene
	if title_packed != null:
		var title: Node = title_packed.instantiate()
		add_child(title)
		var settings_button: Button = title.get_node_or_null(
			"Content/Buttons/SettingsButton"
		) as Button
		var quit_button: Button = title.get_node_or_null("Content/Buttons/QuitButton") as Button
		_expect(settings_button != null, "botão CONFIGURAÇÕES presente na tela inicial")
		if settings_button != null:
			_expect(
				settings_button.pressed.get_connections().size() > 0,
				"botão CONFIGURAÇÕES está conectado à navegação"
			)
		_expect(quit_button != null, "botão SAIR DO JOGO continua presente")
		if quit_button != null:
			_expect(
				quit_button.pressed.get_connections().size() > 0,
				"botão SAIR DO JOGO continua conectado"
			)
		var test_button: Button = title.get_node_or_null(
			"Content/Buttons/TestMovementButton"
		) as Button
		_expect(test_button != null, "botão TESTAR MOVIMENTAÇÃO presente na tela inicial")
		if test_button != null:
			_expect(
				test_button.pressed.get_connections().size() > 0,
				"botão TESTAR MOVIMENTAÇÃO está conectado"
			)
		remove_child(title)
		title.free()


func _check_fps_controller() -> void:
	print("[13] Controlador FPS e cena de teste")
	var player_packed: PackedScene = load("res://players/scenes/player.tscn") as PackedScene
	_expect(player_packed != null, "cena do jogador carrega")
	if player_packed != null:
		var player: Node = player_packed.instantiate()
		_expect(player is CharacterBody3D, "jogador é um CharacterBody3D")
		_expect(player.get_node_or_null("Collision") != null, "jogador tem forma de colisão")
		var head := player.get_node_or_null("Head") as Node3D
		_expect(head != null, "jogador tem nó Head")
		if head != null:
			_expect(
				absf(head.position.y - 1.62) < 0.01,
				"câmera na altura dos olhos (%.2f m)" % head.position.y
			)
		_expect(player.get_node_or_null("Head/Camera") is Camera3D, "câmera 3D presente")
		player.free()

	_expect(
		load("res://maps/scenes/test_room.tscn") is PackedScene,
		"sala de teste carrega (maps/scenes/test_room.tscn)"
	)

	var movement_packed: PackedScene = load("res://match/scenes/movement_test.tscn") as PackedScene
	_expect(movement_packed != null, "cena de teste carrega (match/scenes/movement_test.tscn)")
	if movement_packed != null:
		var movement: Node = movement_packed.instantiate()
		_expect(movement.get_node_or_null("Player") != null, "cena de teste contém o jogador")
		_expect(
			movement.get_node_or_null("TestRoom/Spawn") != null,
			"cena de teste tem ponto de nascimento"
		)
		_expect(
			movement.get_node_or_null("Interface/PauseRoot") != null,
			"cena de teste tem camada de pausa"
		)
		movement.free()

	for action: String in [
		"move_forward", "move_back", "move_left", "move_right", "release_mouse"
	]:
		_expect(InputMap.has_action(action), "ação de entrada '%s' configurada" % action)

	_expect(
		FileAccess.file_exists("res://docs/ETAPA-4.md"),
		"documentação da Etapa 4 presente (docs/ETAPA-4.md)"
	)
