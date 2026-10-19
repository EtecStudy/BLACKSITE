extends SceneTree
## Teste automatizado de fumaça da Etapa 1 (executado pelo CI e localmente).
##
## Uso:
##     godot --headless --path . --script tools/ci/smoke_test.gd
##
## Verifica projeto, tema, autoload, cena inicial, recursos importados e
## configuração de exportação. Sai com código 0 em caso de sucesso e 1 em
## caso de falha.

const EXPECTED_PROJECT_NAME := "Black Sight"
const EXPECTED_RENDERER := "gl_compatibility"
const EXPECTED_VIEWPORT := Vector2i(1920, 1080)
const EXPECTED_MAIN_SCENE := "res://scenes/boot/title_screen.tscn"

# Caminhos relativos à raiz da cena (".").
const EXPECTED_NODES := [
	".",
	"Background",
	"Dust",
	"Vignette",
	"Content",
	"Content/Emblem",
	"Content/TitleLabel",
	"Content/Buttons/StartButton",
	"Content/Buttons/QuitButton",
	"Content/BuildLabel",
	"Fade",
]

const EXPECTED_TEXTURES := [
	"res://assets/textures/ui/background.png",
	"res://assets/textures/ui/vignette.png",
	"res://assets/textures/branding/emblem.png",
	"res://assets/textures/branding/icon_1024.png",
	"res://assets/textures/branding/boot_splash.png",
	"res://assets/textures/fx/dust.png",
]

var _checks: int = 0
var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	print("=== Black Sight · teste de fumaça da Etapa 1 ===")
	_check_project_settings()
	_check_autoload()
	_check_theme()
	_check_fonts()
	_check_textures()
	_check_main_scene()
	_check_export_preset()

	print("")
	if _failures.is_empty():
		print("SMOKE TEST OK — %d verificações aprovadas" % _checks)
		quit(0)
		return

	printerr("SMOKE TEST FALHOU — %d de %d verificações falharam" % [_failures.size(), _checks])
	for failure: String in _failures:
		printerr("  ✗ " + failure)
	quit(1)


# ---------------------------------------------------------------------------


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ " + description)
	else:
		_failures.append(description)
		printerr("  ✗ " + description)


func _check_project_settings() -> void:
	print("[1] Configuração do projeto")
	var name: String = str(ProjectSettings.get_setting("application/config/name", ""))
	_expect(name == EXPECTED_PROJECT_NAME, "nome do projeto é '%s' (obtido: '%s')" % [EXPECTED_PROJECT_NAME, name])

	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	_expect(not version.is_empty(), "versão do projeto definida ('%s')" % version)

	var renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	_expect(renderer == EXPECTED_RENDERER, "renderizador é '%s' (obtido: '%s')" % [EXPECTED_RENDERER, renderer])

	var mobile_renderer: String = str(
		ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "")
	)
	_expect(
		mobile_renderer == EXPECTED_RENDERER,
		"renderizador mobile é '%s' (obtido: '%s')" % [EXPECTED_RENDERER, mobile_renderer]
	)

	var width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	var height: int = int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	_expect(
		Vector2i(width, height) == EXPECTED_VIEWPORT,
		"resolução lógica é %s (obtida: %s)" % [str(EXPECTED_VIEWPORT), str(Vector2i(width, height))]
	)

	var stretch_mode: String = str(ProjectSettings.get_setting("display/window/stretch/mode", ""))
	_expect(stretch_mode == "canvas_items", "stretch mode é 'canvas_items' (obtido: '%s')" % stretch_mode)

	var stretch_aspect: String = str(ProjectSettings.get_setting("display/window/stretch/aspect", ""))
	_expect(stretch_aspect == "keep", "stretch aspect é 'keep' (obtido: '%s')" % stretch_aspect)

	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_expect(main_scene == EXPECTED_MAIN_SCENE, "cena principal é '%s' (obtida: '%s')" % [EXPECTED_MAIN_SCENE, main_scene])
	_expect(FileAccess.file_exists(EXPECTED_MAIN_SCENE), "arquivo da cena principal existe no disco")

	var icon: String = str(ProjectSettings.get_setting("application/config/icon", ""))
	_expect(not icon.is_empty(), "ícone do projeto configurado ('%s')" % icon)

	var splash: String = str(ProjectSettings.get_setting("application/boot_splash/image", ""))
	_expect(not splash.is_empty(), "imagem de boot splash configurada ('%s')" % splash)


func _check_autoload() -> void:
	print("[2] Autoload")
	var autoloads: Dictionary = {}
	for property: Dictionary in ProjectSettings.get_property_list():
		if str(property.get("name", "")).begins_with("autoload/"):
			autoloads[str(property["name"])] = str(ProjectSettings.get_setting(str(property["name"]), ""))
	_expect(
		autoloads.has("autoload/AppInfo"),
		"autoload 'AppInfo' registrado (%d autoloads)" % autoloads.size()
	)
	_expect(
		FileAccess.file_exists("res://scripts/autoload/app_info.gd"),
		"script do autoload AppInfo existe"
	)


func _check_theme() -> void:
	print("[3] Tema e fonte")
	var theme_path: String = str(ProjectSettings.get_setting("gui/theme/custom", ""))
	_expect(not theme_path.is_empty(), "tema customizado configurado ('%s')" % theme_path)
	_expect(ResourceLoader.exists(theme_path), "tema pode ser carregado")

	var theme: Theme = load(theme_path) as Theme
	_expect(theme != null, "tema é do tipo Theme")
	if theme == null:
		return
	_expect(theme.default_font != null, "tema define uma fonte padrão")
	if theme.default_font != null:
		var size: Vector2 = theme.default_font.get_string_size("Black Sight", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		_expect(size.x > 10.0 and size.y > 10.0, "fonte padrão mede texto corretamente (%s)" % str(size))
	_expect(theme.has_stylebox("normal", "Button"), "tema define estilo do botão (normal)")


func _check_fonts() -> void:
	print("[4] Arquivos de fonte")
	for font_path: String in [
		"res://assets/fonts/cinzel/Cinzel-Regular.ttf",
		"res://assets/fonts/cinzel/Cinzel-SemiBold.ttf",
	]:
		_expect(FileAccess.file_exists(font_path), "fonte presente: %s" % font_path)
		var font: Font = load(font_path) as Font
		_expect(font != null, "fonte carrega: %s" % font_path)
		if font != null:
			var width: float = font.get_string_size("BLACK SIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x
			_expect(width > 50.0, "fonte renderiza texto: %s (%.1f px)" % [font_path, width])


func _check_textures() -> void:
	print("[5] Texturas importadas")
	for asset_path: String in EXPECTED_TEXTURES:
		_expect(ResourceLoader.exists(asset_path), "recurso importado: %s" % asset_path)
		var texture: Texture2D = load(asset_path) as Texture2D
		_expect(texture != null, "textura carrega: %s" % asset_path)
		if texture != null:
			_expect(
				texture.get_width() > 0 and texture.get_height() > 0,
				"textura tem dimensões válidas: %s (%dx%d)" % [
					asset_path, texture.get_width(), texture.get_height()
				]
			)


func _check_main_scene() -> void:
	print("[6] Cena inicial")
	_expect(ResourceLoader.exists(EXPECTED_MAIN_SCENE), "cena inicial pode ser carregada")
	var packed: PackedScene = load(EXPECTED_MAIN_SCENE) as PackedScene
	_expect(packed != null, "cena inicial é um PackedScene")
	if packed == null:
		return

	var state: SceneState = packed.get_state()
	var node_paths: Array[String] = []
	for index: int in state.get_node_count():
		node_paths.append(str(state.get_node_path(index)))
	print("      nós na cena: %s" % ", ".join(node_paths))
	_expect(state.get_node_name(0) == "TitleScreen", "raiz da cena é 'TitleScreen'")
	for expected: String in EXPECTED_NODES:
		_expect(node_paths.has(expected), "nó presente na cena: %s" % expected)

	var root_script: Script = state.get_node_script(0) as Script
	_expect(root_script != null, "cena raiz tem script anexado")
	if root_script != null:
		_expect(
			root_script.resource_path.ends_with("scripts/ui/title_screen.gd"),
			"script da raiz é title_screen.gd (obtido: %s)" % root_script.resource_path
		)


func _check_export_preset() -> void:
	print("[7] Preset de exportação")
	var preset_path := "res://export_presets.cfg"
	_expect(FileAccess.file_exists(preset_path), "export_presets.cfg existe")
	if not FileAccess.file_exists(preset_path):
		return
	var content := FileAccess.get_file_as_string(preset_path)
	_expect(content.contains('name="Windows Desktop"'), "preset 'Windows Desktop' presente")
	_expect(content.contains('platform="Windows Desktop"'), "plataforma Windows Desktop configurada")
	_expect(
		content.contains("res://assets/textures/branding/icon.ico"),
		"ícone do executável configurado no preset"
	)
