extends Node
## Autoload `GameSettings` — persistência e aplicação das configurações (Etapa 3).
##
## Responsabilidades:
## - carregar/salvar `user://settings.cfg` (nunca na pasta de instalação);
## - cair nos padrões quando o arquivo não existe ou está corrompido;
## - validar tudo com `SettingsSchema.sanitize()` antes de aplicar;
## - aplicar áudio (`AudioApplier`) e vídeo (`VideoApplier`);
## - avisar a interface pelo sinal `applied`.
##
## A interface (tela de configurações) monta uma cópia de trabalho e chama
## `apply()` somente quando o usuário confirma.

signal applied(values: Dictionary)

## Caminho do arquivo. `user://` resolve para o diretório de usuário da
## aplicação (`%APPDATA%/BlackSight` no Windows) — nunca para a pasta do jogo.
## Exposto como variável para os testes usarem um arquivo temporário.
var config_path: String = "user://settings.cfg"

var _values: Dictionary = SettingsSchema.defaults()
var _last_error: String = ""


func _ready() -> void:
	_values = load_settings()
	AudioApplier.apply(_values)
	VideoApplier.apply(_values)
	_save_if_missing()
	_log("Configurações carregadas")


## Última mensagem de erro de leitura/gravação (vazia quando tudo correu bem).
func last_error() -> String:
	return _last_error


## Cópia dos valores em uso (nunca exponha o dicionário interno).
func current() -> Dictionary:
	return _values.duplicate(true)


## Lê o arquivo do disco e devolve valores saneados.
## Arquivo ausente ou inválido → padrões (sem travar o jogo).
func load_settings() -> Dictionary:
	if not FileAccess.file_exists(config_path):
		_last_error = ""
		return SettingsSchema.defaults()

	var config := ConfigFile.new()
	var error: Error = config.load(config_path)
	if error != OK:
		_last_error = "Falha ao ler %s (erro %d); usando padrões." % [config_path, error]
		push_warning("[Black Sight] " + _last_error)
		return SettingsSchema.defaults()

	var raw: Dictionary = {}
	for section: String in [SettingsSchema.SECTION_CONTROLS, SettingsSchema.SECTION_AUDIO,
			SettingsSchema.SECTION_VIDEO]:
		if config.has_section(section):
			raw[section] = _read_section(config, section)

	_last_error = ""
	return SettingsSchema.sanitize(raw)


## Grava os valores saneados. Retorna false em caso de erro de escrita, mas o
## jogo continua funcionando com os valores em memória.
func save(values: Dictionary) -> bool:
	var sanitized: Dictionary = SettingsSchema.sanitize(values)
	var config := ConfigFile.new()
	config.set_value(SettingsSchema.SECTION_META, "version", SettingsSchema.CONFIG_VERSION)
	config.set_value(SettingsSchema.SECTION_META, "game", "Black Sight")
	for section: String in [SettingsSchema.SECTION_CONTROLS, SettingsSchema.SECTION_AUDIO,
			SettingsSchema.SECTION_VIDEO]:
		var data: Dictionary = sanitized.get(section, {})
		for key: String in data:
			config.set_value(section, key, data[key])

	var error: Error = config.save(config_path)
	if error != OK:
		_last_error = "Falha ao gravar %s (erro %d)." % [config_path, error]
		push_warning("[Black Sight] " + _last_error)
		return false

	_last_error = ""
	return true


## Valida, aplica em memória, aplica no motor e salva.
## Retorna false apenas se a gravação falhar (a aplicação em memória ocorre de todo modo).
func apply(values: Dictionary) -> bool:
	var sanitized: Dictionary = SettingsSchema.sanitize(values)
	_values = sanitized
	AudioApplier.apply(_values)
	VideoApplier.apply(_values)
	var saved: bool = save(_values)
	_log("Configurações aplicadas")
	applied.emit(current())
	return saved


## Aplica apenas o áudio, sem salvar (pré-visualização dos sliders).
func preview_audio(values: Dictionary) -> void:
	AudioApplier.apply(SettingsSchema.sanitize(values))


## Volta aos padrões de fábrica, aplicando e salvando.
func restore_defaults() -> bool:
	return apply(SettingsSchema.defaults())


## Alterna janela ↔ tela cheia (usado pelo atalho F11), preservando o resto.
func toggle_fullscreen() -> void:
	var video: Dictionary = _values.get(SettingsSchema.SECTION_VIDEO, {}).duplicate()
	var is_fullscreen: bool = int(video.get("window_mode", 0)) == SettingsSchema.WindowMode.FULLSCREEN
	video["window_mode"] = (
		SettingsSchema.WindowMode.WINDOWED if is_fullscreen else SettingsSchema.WindowMode.FULLSCREEN
	)
	var values: Dictionary = _values.duplicate(true)
	values[SettingsSchema.SECTION_VIDEO] = video
	apply(values)


## Resumo em uma linha — usado nos logs de inicialização e nos testes do CI.
func summary_line() -> String:
	return SettingsSchema.describe(_values)


func _read_section(config: ConfigFile, section: String) -> Dictionary:
	var result: Dictionary = {}
	for key: String in config.get_section_keys(section):
		result[key] = config.get_value(section, key)
	return result


## Primeira execução: cria o arquivo com os padrões para o usuário poder
## inspecioná-lo (e para o CI comprovar que o build exportado grava em user://).
func _save_if_missing() -> void:
	if FileAccess.file_exists(config_path):
		return
	if not save(_values):
		return
	_log("Arquivo de configurações criado com os valores padrão")


func _log(prefix: String) -> void:
	print("[Black Sight] %s: %s" % [prefix, summary_line()])
