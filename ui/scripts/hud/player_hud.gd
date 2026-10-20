class_name PlayerHud
extends Control
## HUD da partida — por enquanto, a barra de stamina.
##
## Integração sem acoplamento: `bind_player()` aceita qualquer `Node` com o
## sinal `stamina_changed(current, maximum)` e os métodos `get_stamina()` /
## `get_max_stamina()`. A HUD não importa o controlador (ui/ continua dependendo
## apenas de shared/) e não guarda uma segunda stamina.
##
## Etapa 7: `bind_interaction(detector)` liga a indicação "[E] Interagir" ao
## `InteractionDetector` do jogador — de novo por sinal, sem importar
## `players/`. A indicação é um nó único: só o texto e a visibilidade mudam.
##
## Estrutura preparada para crescer: novos componentes entram no `Stack` do
## canto inferior esquerdo, acima da barra, sem reconstruir a HUD.

@onready var _stamina_bar: StaminaBar = %StaminaBar
@onready var _interaction_prompt: InteractionPrompt = %InteractionPrompt

var _player: Node = null
var _interaction_detector: Node = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_from_player()


## Liga a HUD ao jogador. Pode ser chamado antes ou depois do `_ready`.
func bind_player(player: Node) -> void:
	if _player != null and _player.has_signal("stamina_changed"):
		var callback := Callable(self, "_on_stamina_changed")
		if _player.is_connected("stamina_changed", callback):
			_player.disconnect("stamina_changed", callback)
	_player = player
	if _player != null and _player.has_signal("stamina_changed"):
		var callback_new := Callable(self, "_on_stamina_changed")
		if not _player.is_connected("stamina_changed", callback_new):
			_player.connect("stamina_changed", callback_new)
	_sync_from_player()


func get_stamina_bar() -> StaminaBar:
	return _stamina_bar


## Liga a indicação de interação ao detector do jogador (Etapa 7).
## O detector só precisa ter os sinais `focus_changed` e `focus_text_changed` e
## o método `get_current_interactable()` — a HUD não importa `players/`.
func bind_interaction(detector: Node) -> void:
	if _interaction_detector != null:
		var old_focus := Callable(self, "_on_interaction_focus_changed")
		var old_text := Callable(self, "_on_interaction_text_changed")
		if _interaction_detector.is_connected("focus_changed", old_focus):
			_interaction_detector.disconnect("focus_changed", old_focus)
		if _interaction_detector.is_connected("focus_text_changed", old_text):
			_interaction_detector.disconnect("focus_text_changed", old_text)
	_interaction_detector = detector
	if _interaction_prompt != null:
		_interaction_prompt.hide_prompt()
	if _interaction_detector == null:
		return
	if not _interaction_detector.has_signal("focus_changed"):
		return
	_interaction_detector.connect("focus_changed", _on_interaction_focus_changed)
	_interaction_detector.connect("focus_text_changed", _on_interaction_text_changed)
	_on_interaction_focus_changed(_interaction_detector.get_current_interactable())


func get_interaction_prompt() -> InteractionPrompt:
	return _interaction_prompt


func is_interaction_bound() -> bool:
	return _interaction_detector != null


func _on_interaction_focus_changed(interactable: Node) -> void:
	if _interaction_prompt == null:
		return
	if interactable == null:
		_interaction_prompt.hide_prompt()
		return
	_interaction_prompt.show_prompt(str(interactable.get_interaction_text()))


func _on_interaction_text_changed(text: String) -> void:
	if _interaction_prompt == null or not _interaction_prompt.is_shown():
		return
	_interaction_prompt.show_prompt(text)


func is_bound() -> bool:
	return _player != null


func _sync_from_player() -> void:
	if _stamina_bar == null or _player == null:
		return
	if _player.has_method("get_stamina") and _player.has_method("get_max_stamina"):
		_stamina_bar.set_values(
			float(_player.call("get_stamina")),
			float(_player.call("get_max_stamina"))
		)


func _on_stamina_changed(current: float, maximum: float) -> void:
	if _stamina_bar != null:
		_stamina_bar.set_values(current, maximum)
