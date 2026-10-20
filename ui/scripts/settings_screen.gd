class_name SettingsScreen
extends Control
## Tela de configurações (Etapa 3 → Etapa 5).
##
## Orquestra as seções (Controles, Áudio, Vídeo) e o ciclo de vida dos valores:
## - mantém uma **cópia de trabalho** (`_staged`) separada do que está salvo;
## - pré-visualiza o áudio ao mover os sliders (feedback imediato);
## - aplica e salva somente no botão APLICAR;
## - VOLTAR descarta o que não foi aplicado, inclusive a pré-visualização.
##
## A persistência e a aplicação real ficam no autoload `GameSettings`.
##
## A mesma tela serve dois fluxos (Etapa 5):
## - **sozinha** na árvore (tela inicial → CONFIGURAÇÕES): VOLTAR/Esc retornam
##   à tela inicial trocando de cena;
## - **embutida** (`set_embedded(true)`) por cima de uma partida pausada:
##   VOLTAR/Esc apenas emitem `back_requested`, sem trocar de cena — o
##   `match/` decide o que fazer (voltar ao menu de pausa).

signal back_requested

const TITLE_SCENE: String = "res://ui/scenes/title_screen.tscn"
const FADE_IN_DURATION: float = 0.45
const FADE_OUT_DURATION: float = 0.3
const TABS: Array = ["controls", "audio", "video"]

const STATUS_COLOR_NEUTRAL := Color(0.5, 0.47, 0.42, 1.0)
const STATUS_COLOR_PENDING := Color(0.8, 0.67, 0.42, 1.0)
const STATUS_COLOR_OK := Color(0.62, 0.72, 0.6, 1.0)

@onready var _fade: ColorRect = %Fade
@onready var _section_host: VBoxContainer = %SectionHost
@onready var _scroll: ScrollContainer = %Scroll
@onready var _status_label: Label = %StatusLabel
@onready var _apply_button: Button = %ApplyButton
@onready var _defaults_button: Button = %DefaultsButton
@onready var _back_button: Button = %BackButton
@onready var _back_hint: Label = %BackHint
@onready var _tab_buttons: Array = [%TabControls, %TabAudio, %TabVideo]

var _settings
var _ui_audio
var _staged: Dictionary = {}
var _sections: Dictionary = {}
var _active_tab: String = "controls"
var _leaving: bool = false
var _embedded: bool = false


## Define o modo embutido **antes** de entrar na árvore. Embutida, a tela não
## troca de cena ao voltar: emite `back_requested`.
func set_embedded(value: bool) -> void:
	_embedded = value


func is_embedded() -> bool:
	return _embedded


func _ready() -> void:
	_settings = get_node_or_null("/root/GameSettings")
	_ui_audio = get_node_or_null("/root/UiAudio")

	_staged = (
		_settings.current() if _settings != null else SettingsSchema.defaults()
	)

	if _embedded and _back_hint != null:
		_back_hint.text = "Esc volta à pausa."
	_build_sections()
	_connect_buttons()
	_select_tab("controls")
	_set_status("Configurações atuais carregadas.", STATUS_COLOR_NEUTRAL)
	_play_intro()


# --- Construção --------------------------------------------------------------

func _build_sections() -> void:
	for child: Node in _section_host.get_children():
		_section_host.remove_child(child)
		child.queue_free()

	_sections = {
		"controls": ControlsSection.new(),
		"audio": AudioSection.new(),
		"video": VideoSection.new(),
	}

	for key: String in TABS:
		var section: SettingsSection = _sections[key]
		section.visible = false
		_section_host.add_child(section)
		section.setup(_staged)
		section.values_changed.connect(_on_values_changed)


func _connect_buttons() -> void:
	for index: int in TABS.size():
		var button: Button = _tab_buttons[index]
		button.pressed.connect(_on_tab_pressed.bind(TABS[index]))
	_apply_button.pressed.connect(_on_apply_pressed)
	_defaults_button.pressed.connect(_on_defaults_pressed)
	_back_button.pressed.connect(_on_back_pressed)


func _play_intro() -> void:
	_fade.color.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 0.0, FADE_IN_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- Abas --------------------------------------------------------------------

func _on_tab_pressed(tab_key: String) -> void:
	_play_click()
	_select_tab(tab_key)


func _select_tab(tab_key: String) -> void:
	if not TABS.has(tab_key):
		return
	_active_tab = tab_key
	for index: int in TABS.size():
		var section: SettingsSection = _sections.get(TABS[index])
		if section != null:
			section.visible = TABS[index] == tab_key
		var button: Button = _tab_buttons[index]
		button.button_pressed = TABS[index] == tab_key
	if _scroll != null:
		_scroll.scroll_vertical = 0


# --- Valores -----------------------------------------------------------------

func _on_values_changed() -> void:
	_collect_staged()
	if _settings != null:
		_settings.preview_audio(_staged)
	_set_status(
		"Alterações pendentes — clique em APLICAR para salvar.", STATUS_COLOR_PENDING
	)


func _collect_staged() -> void:
	for key: String in _sections:
		var section: SettingsSection = _sections[key]
		var fragment: Dictionary = section.read_values()
		for section_name: String in fragment:
			_staged[section_name] = fragment[section_name]


func _on_apply_pressed() -> void:
	_collect_staged()
	var saved: bool = true
	if _settings != null:
		saved = _settings.apply(_staged)
		_staged = _settings.current()
	else:
		_staged = SettingsSchema.sanitize(_staged)

	# Reconstrói para refletir valores saneados (ex.: resolução limitada).
	_build_sections()
	_select_tab(_active_tab)

	if saved:
		_set_status("Configurações aplicadas e salvas.", STATUS_COLOR_OK)
		_play_confirm()
	else:
		_set_status(
			"Aplicado nesta sessão, mas não foi possível gravar o arquivo.", STATUS_COLOR_PENDING
		)


func _on_defaults_pressed() -> void:
	_staged = SettingsSchema.defaults()
	_build_sections()
	_select_tab(_active_tab)
	if _settings != null:
		_settings.preview_audio(_staged)
	_set_status(
		"Padrões restaurados na tela — clique em APLICAR para salvar.", STATUS_COLOR_PENDING
	)
	_play_click()


func _on_back_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	_play_click()
	if _settings != null:
		# Descarta pré-visualizações não aplicadas.
		_settings.preview_audio(_settings.current())

	if _embedded:
		# Volta ao menu de pausa; quem instanciou decide o que fazer.
		back_requested.emit()
		return

	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_OUT_DURATION)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))


func _set_status(text: String, color: Color) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


# --- Entrada -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_ESCAPE:
			_on_back_pressed()
			get_viewport().set_input_as_handled()
		KEY_F11:
			# F11 continua funcionando em qualquer tela (Etapa 1 → Etapa 3).
			get_viewport().set_input_as_handled()
			_toggle_fullscreen()


## F11 na tela de configurações: alterna a tela cheia, grava e atualiza a aba.
func _toggle_fullscreen() -> void:
	if _settings == null:
		return
	_settings.toggle_fullscreen()
	_staged = _settings.current()
	var tab_before: String = _active_tab
	_build_sections()
	_select_tab(tab_before)
	_set_status(
		"Modo de janela alterado pelo F11 e salvo.",
		STATUS_COLOR_OK
	)
	_play_click()


func _play_click() -> void:
	if _ui_audio != null:
		_ui_audio.play_click()


func _play_confirm() -> void:
	if _ui_audio != null:
		_ui_audio.play_confirm()
