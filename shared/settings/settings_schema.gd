class_name SettingsSchema
extends RefCounted
## Esquema central das configurações do Black Sight (Etapa 3).
##
## Este arquivo é a **fonte única da verdade** sobre quais opções existem, seus
## limites e seus valores padrão. Não grava nem aplica nada: apenas descreve e
## valida dados.
##
## Para adicionar uma nova configuração:
##   1. acrescente a chave e o valor padrão em `defaults()`;
##   2. adicione a validação correspondente em `sanitize()`;
##   3. use o valor em `shared/settings/audio_applier.gd`,
##      `shared/settings/video_applier.gd` ou no futuro controlador do jogador;
##   4. exponha o controle na tela `ui/scenes/settings_screen.tscn`.
## Os arquivos já salvos continuam válidos: chaves ausentes caem no padrão.

enum WindowMode {
	WINDOWED = 0,
	MAXIMIZED = 1,
	FULLSCREEN = 2,
}

const CONFIG_VERSION: int = 1

const SECTION_CONTROLS: String = "controls"
const SECTION_AUDIO: String = "audio"
const SECTION_VIDEO: String = "video"
const SECTION_META: String = "meta"

# --- Controles -------------------------------------------------------------
const MOUSE_SENSITIVITY_MIN: float = 0.1
const MOUSE_SENSITIVITY_MAX: float = 5.0
const MOUSE_SENSITIVITY_STEP: float = 0.05
const DEFAULT_MOUSE_SENSITIVITY_X: float = 1.0
const DEFAULT_MOUSE_SENSITIVITY_Y: float = 1.0
const DEFAULT_INVERT_Y: bool = false

# --- Áudio (percentual 0-100) ---------------------------------------------
const VOLUME_MIN: int = 0
const VOLUME_MAX: int = 100
const DEFAULT_MASTER_VOLUME: int = 80
const DEFAULT_SFX_VOLUME: int = 80
const DEFAULT_AMBIENCE_VOLUME: int = 70
const DEFAULT_MUSIC_VOLUME: int = 60

# --- Vídeo -----------------------------------------------------------------
const MIN_WINDOW_WIDTH: int = 1024
const MIN_WINDOW_HEIGHT: int = 576
const MAX_WINDOW_WIDTH: int = 7680
const MAX_WINDOW_HEIGHT: int = 4320
const DEFAULT_RESOLUTION_X: int = 1600
const DEFAULT_RESOLUTION_Y: int = 900
const DEFAULT_WINDOW_MODE: int = WindowMode.WINDOWED
const DEFAULT_VSYNC: bool = true

## Resoluções oferecidas na interface (16:9 e 16:10 comuns).
## A lista final é filtrada pelo tamanho útil da tela em `VideoApplier`.
const RESOLUTION_CANDIDATES := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]


## Estrutura completa com todos os valores padrão.
static func defaults() -> Dictionary:
	return {
		SECTION_CONTROLS: {
			"mouse_sensitivity_x": DEFAULT_MOUSE_SENSITIVITY_X,
			"mouse_sensitivity_y": DEFAULT_MOUSE_SENSITIVITY_Y,
			"invert_y": DEFAULT_INVERT_Y,
		},
		SECTION_AUDIO: {
			"master_volume": DEFAULT_MASTER_VOLUME,
			"sfx_volume": DEFAULT_SFX_VOLUME,
			"ambience_volume": DEFAULT_AMBIENCE_VOLUME,
			"music_volume": DEFAULT_MUSIC_VOLUME,
		},
		SECTION_VIDEO: {
			"window_mode": DEFAULT_WINDOW_MODE,
			"resolution_x": DEFAULT_RESOLUTION_X,
			"resolution_y": DEFAULT_RESOLUTION_Y,
			"vsync": DEFAULT_VSYNC,
		},
	}


## Devolve uma cópia saneada: tipo certo, dentro dos limites, com padrões para
## chaves ausentes. Nunca falha — entrada inválida vira padrão.
static func sanitize(raw: Variant) -> Dictionary:
	var result: Dictionary = defaults()
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	var data: Dictionary = raw

	var controls_in: Variant = data.get(SECTION_CONTROLS, null)
	if typeof(controls_in) == TYPE_DICTIONARY:
		var controls: Dictionary = result[SECTION_CONTROLS]
		controls["mouse_sensitivity_x"] = clampf(
			_to_float(controls_in.get("mouse_sensitivity_x"), DEFAULT_MOUSE_SENSITIVITY_X),
			MOUSE_SENSITIVITY_MIN, MOUSE_SENSITIVITY_MAX
		)
		controls["mouse_sensitivity_y"] = clampf(
			_to_float(controls_in.get("mouse_sensitivity_y"), DEFAULT_MOUSE_SENSITIVITY_Y),
			MOUSE_SENSITIVITY_MIN, MOUSE_SENSITIVITY_MAX
		)
		controls["invert_y"] = _to_bool(controls_in.get("invert_y"), DEFAULT_INVERT_Y)

	var audio_in: Variant = data.get(SECTION_AUDIO, null)
	if typeof(audio_in) == TYPE_DICTIONARY:
		var audio: Dictionary = result[SECTION_AUDIO]
		audio["master_volume"] = _to_volume(audio_in.get("master_volume"), DEFAULT_MASTER_VOLUME)
		audio["sfx_volume"] = _to_volume(audio_in.get("sfx_volume"), DEFAULT_SFX_VOLUME)
		audio["ambience_volume"] = _to_volume(
			audio_in.get("ambience_volume"), DEFAULT_AMBIENCE_VOLUME
		)
		audio["music_volume"] = _to_volume(audio_in.get("music_volume"), DEFAULT_MUSIC_VOLUME)

	var video_in: Variant = data.get(SECTION_VIDEO, null)
	if typeof(video_in) == TYPE_DICTIONARY:
		var video: Dictionary = result[SECTION_VIDEO]
		video["window_mode"] = clampi(
			_to_int(video_in.get("window_mode"), DEFAULT_WINDOW_MODE),
			WindowMode.WINDOWED, WindowMode.FULLSCREEN
		)
		video["resolution_x"] = clampi(
			_to_int(video_in.get("resolution_x"), DEFAULT_RESOLUTION_X),
			MIN_WINDOW_WIDTH, MAX_WINDOW_WIDTH
		)
		video["resolution_y"] = clampi(
			_to_int(video_in.get("resolution_y"), DEFAULT_RESOLUTION_Y),
			MIN_WINDOW_HEIGHT, MAX_WINDOW_HEIGHT
		)
		video["vsync"] = _to_bool(video_in.get("vsync"), DEFAULT_VSYNC)

	return result


## Texto curto usado nos logs e nos testes automatizados.
static func describe(values: Dictionary) -> String:
	var controls: Dictionary = values.get(SECTION_CONTROLS, {})
	var audio: Dictionary = values.get(SECTION_AUDIO, {})
	var video: Dictionary = values.get(SECTION_VIDEO, {})
	return "master=%d sfx=%d ambience=%d music=%d mode=%s resolution=%dx%d vsync=%s sens_x=%.2f sens_y=%.2f invert_y=%s" % [
		int(audio.get("master_volume", 0)),
		int(audio.get("sfx_volume", 0)),
		int(audio.get("ambience_volume", 0)),
		int(audio.get("music_volume", 0)),
		window_mode_name(int(video.get("window_mode", 0))),
		int(video.get("resolution_x", 0)),
		int(video.get("resolution_y", 0)),
		"true" if bool(video.get("vsync", true)) else "false",
		float(controls.get("mouse_sensitivity_x", 1.0)),
		float(controls.get("mouse_sensitivity_y", 1.0)),
		"true" if bool(controls.get("invert_y", false)) else "false",
	]


static func window_mode_name(mode: int) -> String:
	match mode:
		WindowMode.MAXIMIZED:
			return "maximized"
		WindowMode.FULLSCREEN:
			return "fullscreen"
		_:
			return "windowed"


static func window_mode_label(mode: int) -> String:
	match mode:
		WindowMode.MAXIMIZED:
			return "Janela maximizada"
		WindowMode.FULLSCREEN:
			return "Tela cheia"
		_:
			return "Janela"


# --- Conversores defensivos -------------------------------------------------

static func _to_float(value: Variant, fallback: float) -> float:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return float(value)
		TYPE_STRING:
			var text: String = str(value).strip_edges()
			if text.is_valid_float():
				return text.to_float()
	return fallback


static func _to_int(value: Variant, fallback: int) -> int:
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return int(round(float(value)))
		TYPE_STRING:
			var text: String = str(value).strip_edges()
			if text.is_valid_int():
				return text.to_int()
			if text.is_valid_float():
				return int(round(text.to_float()))
	return fallback


static func _to_bool(value: Variant, fallback: bool) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return bool(value)
		TYPE_INT, TYPE_FLOAT:
			return int(value) != 0
		TYPE_STRING:
			var text: String = str(value).strip_edges().to_lower()
			if text in ["true", "1", "yes", "on"]:
				return true
			if text in ["false", "0", "no", "off"]:
				return false
	return fallback


static func _to_volume(value: Variant, fallback: int) -> int:
	return clampi(_to_int(value, fallback), VOLUME_MIN, VOLUME_MAX)
