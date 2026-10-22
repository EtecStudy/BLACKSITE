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
	_check_movement_states()
	_check_stage6()
	_check_stage8()
	_check_stage9()

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
	# `items/` saiu desta lista na Etapa 8: passou a ter o item de teste pegável.
	for pending_module: String in ["creatures", "objectives"]:
		var files := _list_gdscript_files("res://%s" % pending_module)
		_expect(
			files.is_empty(),
			"módulo %s ainda não tem scripts (estrutura preparatória)" % pending_module
		)

	# `items/` tem só as duas representações de item: o item de teste da
	# Etapa 8 e o item solto da Etapa 9. Inventário é estado do jogador
	# (`players/`); uso, pilha e crafting continuam fora do projeto.
	var item_scripts := _list_gdscript_files("res://items")
	item_scripts.sort()
	_expect(
		item_scripts.size() == 2
			and str(item_scripts[0]).ends_with("items/scripts/inventory_test_item.gd")
			and str(item_scripts[1]).ends_with("items/scripts/world_item.gd"),
		"items/ tem apenas o item de teste e o item solto (%s)" % str(item_scripts)
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
		var detector := player.get_node_or_null("Head/Camera/InteractionDetector")
		_expect(detector != null, "detector de interação na câmera do jogador")
		if detector != null:
			_expect(
				is_equal_approx(float(detector.get("interaction_distance")), 2.5),
				"alcance de interação = 2,5 m"
			)
		player.free()

	_expect(
		load("res://maps/scenes/test_room.tscn") is PackedScene,
		"sala de teste carrega (maps/scenes/test_room.tscn)"
	)
	_expect(
		load("res://maps/scenes/interaction_test_panel.tscn") is PackedScene,
		"painel de teste de interação carrega"
	)
	_expect(
		load("res://ui/scenes/hud/interaction_prompt.tscn") is PackedScene,
		"indicação de interação carrega"
	)
	_expect(
		load("res://shared/interaction/interactable.gd") is GDScript,
		"contrato Interactable carrega (shared/interaction)"
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
		_expect(
			movement.get_node_or_null("InteractionPanel") != null,
			"cena de teste tem o painel de interação"
		)
		movement.free()

	for action: String in [
		"move_forward", "move_back", "move_left", "move_right",
		"move_sprint", "move_crouch", "release_mouse", "interact"
	]:
		_expect(InputMap.has_action(action), "ação de entrada '%s' configurada" % action)

	# Etapa 7: E é a tecla física padrão de `interact`.
	var interact_key: int = 0
	for event: InputEvent in InputMap.action_get_events("interact"):
		var key := event as InputEventKey
		if key != null:
			interact_key = key.physical_keycode if key.physical_keycode != 0 else key.keycode
	_expect(interact_key == KEY_E, "interact usa E como tecla padrão")

	_expect(
		FileAccess.file_exists("res://docs/ETAPA-4.md"),
		"documentação da Etapa 4 presente (docs/ETAPA-4.md)"
	)

func _check_movement_states() -> void:
	print("[14] Estados de movimento (Etapa 5)")
	var player_script: GDScript = load(
		"res://players/scripts/player_controller.gd"
	) as GDScript
	_expect(player_script != null, "script do controlador carrega")
	if player_script != null:
		var constants: Dictionary = player_script.get_script_constant_map()
		_expect(constants.has("MovementState"), "enum MovementState declarado")
		var states: Dictionary = constants.get("MovementState", {})
		for state_name: String in ["IDLE", "WALKING", "RUNNING", "CROUCHING"]:
			_expect(states.has(state_name), "estado '%s' definido" % state_name)
		_expect(
			not states.has("JUMPING") and not states.has("FALLING"),
			"não existe estado de pulo"
		)
		_expect(constants.has("STATE_NAMES"), "nomes dos estados disponíveis")

	var player_packed: PackedScene = load("res://players/scenes/player.tscn") as PackedScene
	if player_packed != null:
		var player: Node = player_packed.instantiate()
		var walk: float = float(player.get("walk_speed"))
		var run: float = float(player.get("run_speed"))
		var crouch: float = float(player.get("crouch_speed"))
		_expect(run > walk, "corrida (%.2f m/s) mais rápida que caminhada (%.2f m/s)" % [run, walk])
		_expect(crouch < walk, "agachado (%.2f m/s) mais lento que caminhada (%.2f m/s)" % [crouch, walk])
		_expect(player.has_method("get_state"), "controlador expõe get_state()")
		_expect(player.has_method("is_crouched"), "controlador expõe is_crouched()")
		_expect(
			player.has_method("set_sprint_allowed"),
			"ponto de extensão para a stamina (set_sprint_allowed) presente"
		)
		player.free()

	var movement_packed: PackedScene = load(
		"res://match/scenes/movement_test.tscn"
	) as PackedScene
	if movement_packed != null:
		var movement: Node = movement_packed.instantiate()
		var settings_button: Button = movement.get_node_or_null(
			"Interface/PauseRoot/Center/Panel/Margin/Content/SettingsButton"
		) as Button
		_expect(settings_button != null, "menu de pausa tem CONFIGURAÇÕES")
		if settings_button != null:
			_expect(settings_button.text == "CONFIGURAÇÕES", "botão rotulado CONFIGURAÇÕES")
		_expect(
			movement.get_node_or_null("SettingsLayer") != null,
			"camada para abrir as configurações durante a partida"
		)
		movement.free()

	var settings_script: GDScript = load("res://ui/scripts/settings_screen.gd") as GDScript
	if settings_script != null:
		var has_embedded: bool = false
		for method: Dictionary in settings_script.get_script_method_list():
			if str(method.get("name", "")) == "set_embedded":
				has_embedded = true
		_expect(has_embedded, "tela de configurações aceita modo embutido")

	_expect(
		FileAccess.file_exists("res://docs/ETAPA-5.md"),
		"documentação da Etapa 5 presente (docs/ETAPA-5.md)"
	)


func _check_stage6() -> void:
	print("[15] Stamina, agachamento e controles reais (Etapas 6.2–7)")

	# --- Esquema -------------------------------------------------------------
	var defaults: Dictionary = SettingsSchema.defaults()
	var controls_defaults: Dictionary = defaults.get(SettingsSchema.SECTION_CONTROLS, {})
	_expect(
		str(controls_defaults.get("crouch_mode", "")) == "toggle",
		"modo de agachamento padrão é ALTERNAR"
	)
	_expect(
		SettingsSchema.normalize_crouch_mode("valor-invalido")
			== SettingsSchema.DEFAULT_CROUCH_MODE,
		"modo inválido cai no padrão ALTERNAR"
	)
	_expect(
		SettingsSchema.normalize_crouch_mode("HOLD") == "hold",
		"normalização do modo aceita maiúsculas"
	)
	_expect(SettingsSchema.crouch_mode_label("hold") == "Segurar", "rótulo do modo SEGURAR")
	_expect(SettingsSchema.crouch_mode_label("toggle") == "Alternar", "rótulo do modo ALTERNAR")

	# --- Controlador ---------------------------------------------------------
	var player_packed: PackedScene = load("res://players/scenes/player.tscn") as PackedScene
	if player_packed != null:
		var player: Node = player_packed.instantiate()
		_expect(is_equal_approx(float(player.get("max_stamina")), 100.0), "stamina máxima = 100")
		_expect(
			is_equal_approx(float(player.get("stamina_drain_rate")), 20.0),
			"consumo de stamina = 20/s"
		)
		_expect(
			is_equal_approx(float(player.get("stamina_recovery_rate")), 15.0),
			"recuperação de stamina = 15/s"
		)
		_expect(
			is_equal_approx(float(player.get("stamina_recovery_delay")), 1.0),
			"atraso de recuperação = 1,0 s (Etapa 6.2)"
		)
		var threshold: float = float(player.get("sprint_resume_threshold"))
		_expect(
			threshold > 0.0 and threshold < float(player.get("max_stamina")),
			"limiar de retorno entre 0 e o máximo (%.0f)" % threshold
		)
		for method: String in [
			"get_stamina", "get_max_stamina", "get_stamina_ratio", "set_stamina",
			"get_crouch_mode", "is_sprint_allowed", "set_sprint_allowed",
			"get_recovery_delay_left", "is_sprint_held",
		]:
			_expect(player.has_method(method), "controlador expõe %s()" % method)
		_expect(player.has_signal("stamina_changed"), "sinal stamina_changed preparado para a HUD")
		var hud_scene: PackedScene = load("res://ui/scenes/hud/player_hud.tscn") as PackedScene
		_expect(hud_scene != null, "HUD da Etapa 6.1 continua presente e carrega")
		var source: String = FileAccess.get_file_as_string(
			"res://players/scripts/player_controller.gd"
		).to_lower()
		_expect(not source.contains("jump"), "controlador não tem código de pulo")
		_expect(not source.contains("velocity.y +="), "não há impulso vertical positivo")
		player.free()

	_expect(not InputMap.has_action("jump"), "não existe ação de pulo")
	_expect(not InputMap.has_action("move_jump"), "não existe ação move_jump")
	var jump_actions: Array = []
	for action: String in InputMap.get_actions():
		if action.to_lower().contains("jump") or action.to_lower().contains("pular"):
			jump_actions.append(action)
	_expect(jump_actions.is_empty(), "nenhuma ação de pulo no Input Map")

	# --- Persistência do modo de agachamento --------------------------------
	var settings = get_node_or_null("/root/GameSettings")
	if settings != null:
		var values: Dictionary = settings.current()
		values[SettingsSchema.SECTION_CONTROLS]["crouch_mode"] = "hold"
		settings.apply(values)
		_expect(
			str(settings.current().controls.crouch_mode) == "hold",
			"modo SEGURAR aplicado em memória"
		)
		var config := ConfigFile.new()
		var loaded: bool = config.load(settings.config_path) == OK
		_expect(
			loaded and str(config.get_value("controls", "crouch_mode", "")) == "hold",
			"modo gravado em settings.cfg"
		)
		settings.apply(SettingsSchema.defaults())
		_expect(
			str(settings.current().controls.crouch_mode) == "toggle",
			"RESTAURAR PADRÕES volta ao modo ALTERNAR"
		)

	# --- Lista real de controles --------------------------------------------
	var section := ControlsSection.new()
	add_child(section)
	section.setup(SettingsSchema.defaults())
	var rows: Array = section.get_key_hint_rows()
	var keys: Array = []
	var joined: String = ""
	for row: Array in rows:
		keys.append(str(row[0]))
		joined += "%s %s " % [str(row[0]), str(row[1])]
	var lowered: String = joined.to_lower()
	# Etapa 9: entrou "G — Soltar item no chão" (ação implementada de verdade),
	# por isso a lista passa de oito para nove linhas. R continua fora: é a
	# remoção provisória de teste da Etapa 8.
	_expect(rows.size() == 9, "lista tem exatamente nove controles (%d)" % rows.size())
	_expect(
		keys == ["W A S D", "Shift", "Ctrl", "E", "1 2 3", "G", "Mouse", "Esc", "F11"],
		"teclas reais na ordem esperada: %s" % str(keys)
	)
	_expect(lowered.contains("mover"), "WASD descreve mover")
	_expect(lowered.contains("correr"), "SHIFT descreve correr")
	_expect(lowered.contains("olhar"), "mouse descreve olhar")
	_expect(lowered.contains("pausar"), "Esc descreve pausar")
	_expect(lowered.contains("tela cheia"), "F11 descreve tela cheia")
	_expect(lowered.contains("interagir"), "E descreve interagir (Etapa 7)")
	_expect(lowered.contains("slot"), "1 2 3 descreve selecionar slot (Etapa 8)")
	_expect(lowered.contains("soltar"), "G descreve soltar item (Etapa 9)")
	_expect(not keys.has("R"), "R (remoção provisória) continua fora da lista")
	_expect(not lowered.contains("lanterna"), "não lista F/Lanterna")
	_expect(not lowered.contains("pular") and not lowered.contains("pulo"), "não lista pulo")
	_expect(not lowered.contains("usar item") and not lowered.contains("equipar"),
		"não lista uso nem equipamento de item")
	_expect(not lowered.contains(" dropar") and not lowered.contains("descarte"),
		"não lista descarte de item")
	_expect(not lowered.contains("ataque"), "não lista ataque")
	_expect(keys.has("E") and not keys.has("F"), "lista E (implementada) e não F")
	_expect(not keys.has("Space") and not lowered.contains("espaço"), "não lista a barra de espaço")

	section.set_crouch_mode_id("hold")
	_expect(
		section.get_crouch_hint_text() == "Segurar para agachar",
		"Ctrl em SEGURAR: 'Segurar para agachar'"
	)
	section.set_crouch_mode_id("toggle")
	_expect(
		section.get_crouch_hint_text() == "Alternar agachamento",
		"Ctrl em ALTERNAR: 'Alternar agachamento'"
	)
	var read: Dictionary = section.read_values().get(SettingsSchema.SECTION_CONTROLS, {})
	_expect(str(read.get("crouch_mode", "")) == "toggle", "read_values() inclui crouch_mode")
	remove_child(section)
	section.free()

	_expect(
		FileAccess.file_exists("res://docs/ETAPA-6.md"),
		"documentação da Etapa 6 presente (docs/ETAPA-6.md)"
	)
	_expect(
		FileAccess.file_exists("res://docs/ETAPA-7.md"),
		"documentação da Etapa 7 presente (docs/ETAPA-7.md)"
	)


func _check_stage8() -> void:
	print("[16] Inventário de três slots (Etapa 8)")

	# --- Versão -------------------------------------------------------------
	# A versão pertence ao build, não à etapa: ela avança a cada release
	# (0.9.0 na Etapa 9). O que este grupo garante é que o inventário da Etapa 8
	# continua presente nessa versão — verificado logo abaixo.
	_expect(
		str(ProjectSettings.get_setting("application/config/version", "")) == "0.13.2",
		"versão do projeto é 0.13.2"
	)
	var app_info = get_node_or_null("/root/AppInfo")
	if app_info != null:
		_expect(
			str(app_info.stage_label()).contains("Limpeza"),
			"AppInfo anuncia a etapa atual (%s)" % str(app_info.stage_label())
		)

	# --- InputMap -----------------------------------------------------------
	var expected_actions := {
		"inventory_slot_1": KEY_1,
		"inventory_slot_2": KEY_2,
		"inventory_slot_3": KEY_3,
		"inventory_remove": KEY_R,
	}
	for action: String in expected_actions:
		_expect(InputMap.has_action(action), "ação '%s' configurada" % action)
		var found: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key == null:
				continue
			var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
			if code == expected_actions[action]:
				found = true
		_expect(
			found,
			"ação '%s' usa %s" % [action, OS.get_keycode_string(expected_actions[action])]
		)
	# A Etapa 9 acrescentou `inventory_drop` (G) de propósito. O que a Etapa 8
	# garante continua valendo: não existem slots extras nem ações de inventário
	# fora do conjunto previsto (3 slots + remoção de teste + drop).
	var inventory_actions: Array = []
	for action: String in InputMap.get_actions():
		if action.begins_with("inventory_"):
			inventory_actions.append(action)
	inventory_actions.sort()
	_expect(
		inventory_actions == [
			"inventory_drop",
			"inventory_remove",
			"inventory_slot_1",
			"inventory_slot_2",
			"inventory_slot_3",
		],
		"ações de inventário são exatamente as previstas: %s" % str(inventory_actions)
	)

	# --- Arquivos -----------------------------------------------------------
	for path: String in [
		"res://shared/items/item_definition.gd",
		"res://players/scripts/inventory/inventory.gd",
		"res://players/scripts/inventory/inventory_slot.gd",
		"res://players/scripts/inventory/inventory_input.gd",
		"res://items/scripts/inventory_test_item.gd",
		"res://items/scenes/inventory_test_item.tscn",
		"res://ui/scripts/hud/inventory_bar.gd",
		"res://ui/scenes/hud/inventory_bar.tscn",
		"res://docs/ETAPA-8.md",
	]:
		_expect(FileAccess.file_exists(path), "arquivo da Etapa 8 presente (%s)" % path)

	var item_packed: PackedScene = load("res://items/scenes/inventory_test_item.tscn") as PackedScene
	_expect(item_packed != null, "cena do item de teste carrega")
	var bar_packed: PackedScene = load("res://ui/scenes/hud/inventory_bar.tscn") as PackedScene
	_expect(bar_packed != null, "cena da barra de slots carrega")

	# --- Inventário isolado -------------------------------------------------
	_expect(Inventory.SLOT_COUNT == 3, "Inventory.SLOT_COUNT = 3")
	var inventory: Inventory = Inventory.new()
	add_child(inventory)
	_expect(inventory.get_slot_count() == 3, "inventário começa com três slots")
	_expect(inventory.get_used_slot_count() == 0, "inventário começa vazio")
	_expect(inventory.get_selected_slot() == 0, "slot 1 selecionado por padrão")

	var first := ItemDefinition.new(&"smoke_a", "ITEM A")
	var second := ItemDefinition.new(&"smoke_b", "ITEM B")
	var third := ItemDefinition.new(&"smoke_c", "ITEM C")
	var fourth := ItemDefinition.new(&"smoke_d", "ITEM D")
	_expect(inventory.add_item(first), "adiciona item no inventário")
	_expect(inventory.add_item(second) and inventory.add_item(third), "adiciona até encher")
	_expect(not inventory.has_free_slot(), "inventário cheio após três itens")
	_expect(not inventory.add_item(fourth), "inventário cheio recusa o quarto item")
	_expect(inventory.get_item(0) == first, "item recusado não substitui o primeiro")
	_expect(inventory.select_slot(2), "seleciona o slot 3")
	_expect(inventory.get_selected_item() == third, "item selecionado é o do slot 3")
	_expect(inventory.remove_item(1), "remove o item do slot 2")
	_expect(inventory.is_slot_empty(1), "slot fica vazio depois da remoção")
	_expect(inventory.replace_item(0, fourth), "substitui o item do slot 1")
	_expect(inventory.get_item(0) == fourth, "slot 1 recebe o substituto")
	_expect(inventory.add_item(second), "slot livre volta a aceitar item")
	remove_child(inventory)
	inventory.free()

	# --- Cena do jogador ----------------------------------------------------
	var player_packed: PackedScene = load("res://players/scenes/player.tscn") as PackedScene
	if player_packed != null:
		var player: Node = player_packed.instantiate()
		_expect(
			player.get_node_or_null("Inventory") is Inventory,
			"cena do jogador tem o nó Inventory"
		)
		_expect(
			player.get_node_or_null("InventoryInput") != null,
			"cena do jogador tem a entrada do inventário"
		)
		_expect(player.get_inventory() != null, "controlador expõe get_inventory()")
		_expect(player.get_inventory_input() != null, "controlador expõe get_inventory_input()")
		player.free()

	# --- HUD ----------------------------------------------------------------
	var hud_packed: PackedScene = load("res://ui/scenes/hud/player_hud.tscn") as PackedScene
	_expect(hud_packed != null, "HUD carrega com a barra de slots")
	if hud_packed != null:
		var hud: PlayerHud = hud_packed.instantiate() as PlayerHud
		add_child(hud)
		var bar: InventoryBar = hud.get_inventory_bar()
		_expect(bar != null, "HUD expõe a barra de slots")
		if bar != null:
			_expect(bar.get_slot_count() == 3, "HUD desenha 3 slots")
			_expect(bar.get_slot_text(0) == "VAZIO", "slot começa VAZIO")
			_expect(
				hud.get_node_or_null("InventoryArea/Column/FullMessage") != null,
				"HUD tem o aviso de inventário cheio"
			)
			var probe: Inventory = Inventory.new()
			add_child(probe)
			probe.add_item(ItemDefinition.new(&"smoke_hud", "ITEM HUD"))
			hud.bind_inventory(probe)
			_expect(
				bar.get_slot_text(0) == "ITEM HUD",
				"HUD mostra o item do slot 1 (%s)" % bar.get_slot_text(0)
			)
			probe.select_slot(1)
			_expect(bar.is_slot_selected(1), "HUD acompanha a seleção")
			probe.add_item(ItemDefinition.new(&"smoke_hud_2", "ITEM 2"))
			probe.add_item(ItemDefinition.new(&"smoke_hud_3", "ITEM 3"))
			probe.add_item(ItemDefinition.new(&"smoke_hud_4", "ITEM 4"))
			_expect(hud.is_full_message_visible(), "HUD avisa quando o inventário enche")
			remove_child(probe)
			probe.free()
		remove_child(hud)
		hud.free()

	# --- Cena de teste ------------------------------------------------------
	var movement_packed: PackedScene = load("res://match/scenes/movement_test.tscn") as PackedScene
	if movement_packed != null:
		var movement: Node = movement_packed.instantiate()
		for item_name: String in ["TestItemA", "TestItemB", "TestItemC", "TestItemD"]:
			var test_item: Node = movement.get_node_or_null(item_name)
			_expect(test_item is InventoryTestItem, "%s na cena de teste" % item_name)
		movement.free()

	_expect(
		not FileAccess.get_file_as_string("res://players/scripts/inventory/inventory.gd")
			.contains("is_key_pressed"),
		"inventário não lê teclas diretamente"
	)


func _check_stage9() -> void:
	print("[17] Soltar itens no ambiente (Etapa 9)")

	# --- Versão -------------------------------------------------------------
	_expect(
		str(ProjectSettings.get_setting("application/config/version", "")) == "0.13.2",
		"versão do projeto é 0.13.2"
	)
	var app_info = get_node_or_null("/root/AppInfo")
	if app_info != null:
		_expect(
			str(app_info.stage_label()).contains("Limpeza"),
			"AppInfo anuncia a Etapa 11 (%s)" % str(app_info.stage_label())
		)

	# --- InputMap -----------------------------------------------------------
	_expect(InputMap.has_action("inventory_drop"), "ação 'inventory_drop' configurada")
	var drop_uses_g: bool = false
	for event: InputEvent in InputMap.action_get_events("inventory_drop"):
		var key := event as InputEventKey
		if key == null:
			continue
		var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
		if code == KEY_G:
			drop_uses_g = true
	_expect(drop_uses_g, "ação 'inventory_drop' usa G")
	_expect(InputMap.has_action("inventory_remove"), "remoção de teste continua existindo")
	_expect(not InputMap.has_action("inventory_throw"), "não existe ação de arremesso")

	# --- Arquivos -----------------------------------------------------------
	for path: String in [
		"res://items/scripts/world_item.gd",
		"res://items/scenes/world_item.tscn",
		"res://players/scripts/inventory/item_dropper.gd",
		"res://shared/mapping/space_probe.gd",
		"res://docs/ETAPA-9.md",
	]:
		_expect(FileAccess.file_exists(path), "arquivo da Etapa 9 presente (%s)" % path)

	# --- Item no mundo ------------------------------------------------------
	var world_packed: PackedScene = load("res://items/scenes/world_item.tscn") as PackedScene
	_expect(world_packed != null, "cena do item solto carrega")
	if world_packed != null:
		var world_item: WorldItem = world_packed.instantiate() as WorldItem
		_expect(world_item != null, "cena do item solto tem o script WorldItem")
		if world_item != null:
			_expect(world_item is Interactable, "item solto usa o contrato Interactable")
			_expect(
				world_item.get_node_or_null("Body") is RigidBody3D,
				"item solto tem corpo físico (RigidBody3D)"
			)
			_expect(
				world_item.get_node_or_null("Body/Collision") is CollisionShape3D,
				"item solto tem colisão"
			)
			var label := world_item.get_node_or_null("Body/NameLabel") as Label3D
			_expect(label != null, "item solto tem etiqueta 3D")
			_expect(not world_item.can_interact(null), "item solto sem ator não é interativo")
			_expect(world_item.configure_item(null) == false, "item inválido é recusado")
			var smoke_item := ItemDefinition.new(&"smoke_world", "ITEM MUNDO")
			_expect(world_item.configure_item(smoke_item), "item válido é aceito")
			add_child(world_item)
			_expect(world_item.is_in_group(WorldItem.WORLD_GROUP), "item solto entra no grupo de mundo")
			_expect(label != null and label.text == "ITEM MUNDO", "etiqueta mostra o nome do item")
			_expect(world_item.get_item() == smoke_item, "item solto guarda a definição")
			_expect(world_item.get_display_name() == "ITEM MUNDO", "nome para exibição")
			remove_child(world_item)
			world_item.free()

	# --- Componente de drop no jogador -------------------------------------
	var player_packed: PackedScene = load("res://players/scenes/player.tscn") as PackedScene
	if player_packed != null:
		var player: Node = player_packed.instantiate()
		var dropper := player.get_node_or_null("Head/Camera/ItemDropper")
		_expect(dropper is ItemDropper, "jogador tem ItemDropper na câmera")
		_expect(player.get_item_dropper() == dropper, "controlador expõe get_item_dropper()")
		if dropper != null:
			_expect(dropper.world_item_scene != null, "drop aponta para a cena do item")
			_expect(not dropper.is_processing(), "drop não processa por frame")
			_expect(dropper.get_drop_count() == 0, "contador de drops começa em zero")
		player.free()
	_expect(
		not FileAccess.get_file_as_string("res://players/scripts/inventory/item_dropper.gd")
			.contains("is_key_pressed"),
		"componente do drop não lê teclas diretamente"
	)

	# --- HUD reaproveitada --------------------------------------------------
	var hud_packed: PackedScene = load("res://ui/scenes/hud/player_hud.tscn") as PackedScene
	if hud_packed != null:
		var hud: PlayerHud = hud_packed.instantiate() as PlayerHud
		add_child(hud)
		_expect(hud.has_method("bind_drop_input"), "HUD aceita a ligação com o drop")
		_expect(hud.has_method("show_message"), "HUD reutiliza o painel de aviso")
		var probe := ItemDropper.new()
		add_child(probe)
		hud.bind_drop_input(probe)
		_expect(hud.is_drop_bound(), "HUD ligada ao componente de drop")
		probe.drop_blocked.emit("SLOT VAZIO")
		_expect(
			hud.get_full_message_text() == "SLOT VAZIO" and hud.is_full_message_visible(),
			"aviso do drop usa o mesmo painel da HUD (%s)" % hud.get_full_message_text()
		)
		_expect(hud.get_inventory_bar() != null and hud.get_inventory_bar().get_slot_count() == 3,
			"barra de inventário continua única, com 3 slots")
		remove_child(probe)
		probe.free()
		remove_child(hud)
		hud.free()

	# --- Cena de teste ------------------------------------------------------
	var movement_packed: PackedScene = load("res://match/scenes/movement_test.tscn") as PackedScene
	if movement_packed != null:
		var movement: Node = movement_packed.instantiate()
		var hint := movement.get_node_or_null("Interface/HintLabel") as Label
		var text: String = hint.text if hint != null else ""
		_expect(text.contains("G SOLTAR"), "cena de teste ensina G SOLTAR (%s)" % text)
		_expect(text.contains("R REMOVER TESTE"), "cena de teste marca R como teste")
		var pause_controls := movement.get_node_or_null("Interface/PauseRoot/Center/Panel/Margin/Content/PauseControls") as Label
		_expect(
			pause_controls != null and pause_controls.text.contains("G soltar"),
			"pausa lista G soltar"
		)
		movement.free()

	# --- Correção do drop (bug dos itens presos) ----------------------------
	# O bug do teste manual: item apoiado só numa quina de caixa/pilar podia
	# tombar, entrar no objeto ou "desaparecer". A correção precisa continuar
	# no código: apoio completo da pegada + confirmação depois de instanciar.
	for path: String in [
		"res://docs/ETAPA-9-CORRECAO.md",
		"res://tools/ci/drop_obstacle_test.gd",
		"res://tools/ci/drop_obstacle_test.tscn",
	]:
		_expect(FileAccess.file_exists(path), "arquivo da correção presente (%s)" % path)

	var probe_source: String = FileAccess.get_file_as_string("res://shared/mapping/space_probe.gd")
	_expect(probe_source.contains("_support_ok"), "SpaceProbe confere o apoio da pegada")
	_expect(probe_source.contains("confirm_placement"), "SpaceProbe confirma a posição real do item")
	_expect(
		probe_source.contains("SUPPORT_GRID") and probe_source.contains("NO_SURFACE"),
		"SpaceProbe usa a grade de apoio e a superfície encontrada"
	)
	var dropper_source: String = FileAccess.get_file_as_string("res://players/scripts/inventory/item_dropper.gd")
	_expect(
		dropper_source.contains("SpaceProbe.confirm_placement"),
		"drop confirma a posição depois de instanciar o item"
	)
	var world_source: String = FileAccess.get_file_as_string("res://items/scenes/world_item.tscn")
	_expect(
		world_source.contains("axis_lock_angular_x = true"),
		"item solto não tomba ao assentar (rotação travada)"
	)
