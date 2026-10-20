class_name InteractionPrompt
extends Control
## Indicação discreta de interação — "[E] Interagir" (Etapa 7).
##
## Mesma linguagem visual do painel de stamina e das configurações: painel
## escuro translúcido, borda de 1 px, raio 2, Cinzel do tema e as cores de
## pergaminho da interface. Nada de texturas, ícones ou cores novas.
##
## Fica no rodapé, centralizada, acima da barra de stamina. O texto vem do
## objeto interativo; a **tecla** vem do InputMap (`interact`), então um futuro
## remapeamento atualiza a indicação sem tocar neste script.
##
## A indicação é um nó único, criado com a HUD: mostrar/esconder só troca
## `visible` e o texto — nada é instanciado por frame.

const DEFAULT_ACTION := "interact"
const FADE_IN_DURATION := 0.12
const ACTION_TEXT_COLOR := Color(0.83, 0.8, 0.73, 1.0)
const KEY_TEXT_COLOR := Color(0.92, 0.89, 0.82, 1.0)
const ACTION_TEXT_SIZE := 15
const KEY_TEXT_SIZE := 14

## Ação do InputMap cuja tecla é exibida na indicação.
@export var action_name: String = DEFAULT_ACTION

@onready var _panel: PanelContainer = %Panel
@onready var _key_label: Label = %KeyLabel
@onready var _text_label: Label = %TextLabel

var _shown: bool = false
var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_style()
	visible = false
	modulate.a = 1.0
	if _panel != null:
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_label.text = _action_key_text()
	_text_label.text = ""


## Mostra a indicação com o texto fornecido pelo objeto.
func show_prompt(text: String) -> void:
	if _panel == null:
		return
	_key_label.text = _action_key_text()
	_text_label.text = text
	if _shown:
		return
	_shown = true
	visible = true
	modulate.a = 0.0
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)


## Esconde a indicação (sem animação, para nunca mostrar um alvo já inválido).
func hide_prompt() -> void:
	_kill_tween()
	_shown = false
	visible = false
	modulate.a = 1.0
	if _text_label != null:
		_text_label.text = ""


func is_shown() -> bool:
	return _shown and visible


func get_prompt_text() -> String:
	return _text_label.text if _text_label != null else ""


func get_key_text() -> String:
	return _key_label.text if _key_label != null else ""


## Retângulo do painel visível (usado pelos testes de posicionamento).
func get_panel_rect() -> Rect2:
	return _panel.get_global_rect() if _panel != null else Rect2()


func _action_style() -> void:
	if _text_label != null:
		_text_label.add_theme_color_override("font_color", ACTION_TEXT_COLOR)
		_text_label.add_theme_font_size_override("font_size", ACTION_TEXT_SIZE)
	if _key_label != null:
		_key_label.add_theme_color_override("font_color", KEY_TEXT_COLOR)
		_key_label.add_theme_font_size_override("font_size", KEY_TEXT_SIZE)


## Tecla atual da ação (lida do InputMap; "E" como último recurso).
func _action_key_text() -> String:
	if not InputMap.has_action(action_name):
		return "E"
	for event: InputEvent in InputMap.action_get_events(action_name):
		var key := event as InputEventKey
		if key == null:
			continue
		var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
		if code != 0:
			return OS.get_keycode_string(code).to_upper()
	return "E"


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
