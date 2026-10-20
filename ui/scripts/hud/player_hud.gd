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
## Etapa 8: `bind_inventory(inventory)` mostra os três slots no canto inferior
## direito e reage a `inventory_changed`, `selection_changed` e `item_rejected`.
## A HUD **não** consulta o inventário por frame e não guarda uma cópia do
## estado: ela só redesenha quando o inventário avisa.
##
## Estrutura preparada para crescer: novos componentes entram no `Stack` do
## canto inferior esquerdo, acima da barra, sem reconstruir a HUD.

const FULL_MESSAGE_HOLD := 1.6
const FULL_MESSAGE_FADE := 0.3

@onready var _stamina_bar: StaminaBar = %StaminaBar
@onready var _interaction_prompt: InteractionPrompt = %InteractionPrompt
@onready var _inventory_bar: InventoryBar = %InventoryBar
@onready var _full_message: PanelContainer = %FullMessage
@onready var _message_label: Label = %MessageLabel

var _player: Node = null
var _interaction_detector: Node = null
var _inventory: Node = null
var _message_tween: Tween = null


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


## Liga a barra de slots ao inventário do jogador (Etapa 8).
## O inventário só precisa dos sinais `inventory_changed`, `selection_changed`
## e `item_rejected` e dos métodos `get_slot_count()`, `get_item(i)`,
## `get_selected_slot()` — a HUD não importa `players/`.
func bind_inventory(inventory: Node) -> void:
	if _inventory != null:
		var old_changed := Callable(self, "_refresh_inventory")
		var old_selection := Callable(self, "_on_inventory_selection_changed")
		var old_rejected := Callable(self, "_on_inventory_item_rejected")
		if _inventory.is_connected("inventory_changed", old_changed):
			_inventory.disconnect("inventory_changed", old_changed)
		if _inventory.is_connected("selection_changed", old_selection):
			_inventory.disconnect("selection_changed", old_selection)
		if _inventory.is_connected("item_rejected", old_rejected):
			_inventory.disconnect("item_rejected", old_rejected)
	_inventory = inventory
	_hide_full_message()
	if _inventory == null:
		if _inventory_bar != null:
			_inventory_bar.clear_slots()
			_inventory_bar.set_selected(0)
		return
	if _inventory.has_signal("inventory_changed"):
		_inventory.connect("inventory_changed", _refresh_inventory)
	if _inventory.has_signal("selection_changed"):
		_inventory.connect("selection_changed", _on_inventory_selection_changed)
	if _inventory.has_signal("item_rejected"):
		_inventory.connect("item_rejected", _on_inventory_item_rejected)
	_refresh_inventory()


func get_inventory_bar() -> InventoryBar:
	return _inventory_bar


func is_inventory_bound() -> bool:
	return _inventory != null


## Redesenha os três slots com o estado atual do inventário.
func _refresh_inventory() -> void:
	if _inventory_bar == null:
		return
	if _inventory == null:
		_inventory_bar.clear_slots()
		return
	var slot_count: int = int(_inventory.call("get_slot_count"))
	for index: int in slot_count:
		var item: Variant = _inventory.call("get_item", index)
		var empty: bool = item == null
		_inventory_bar.set_slot(index, _item_label(item), empty)
	_inventory_bar.set_selected(int(_inventory.call("get_selected_slot")))


func _on_inventory_selection_changed(slot_index: int, _item: ItemDefinition) -> void:
	if _inventory_bar != null:
		_inventory_bar.set_selected(slot_index)


## Inventário cheio: mensagem discreta que some sozinha.
func _on_inventory_item_rejected(_item: ItemDefinition) -> void:
	show_full_message()


func show_full_message() -> void:
	if _full_message == null:
		return
	_full_message.visible = true
	_full_message.modulate.a = 1.0
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(FULL_MESSAGE_HOLD)
	_message_tween.tween_property(_full_message, "modulate:a", 0.0, FULL_MESSAGE_FADE)
	# Callback próprio: não mata o tween de dentro dele mesmo.
	_message_tween.tween_callback(_on_full_message_finished)


func is_full_message_visible() -> bool:
	return _full_message != null and _full_message.visible and _full_message.modulate.a > 0.01


func get_full_message_text() -> String:
	return _message_label.text if _message_label != null else ""


## Fim natural do aviso (chamado pelo próprio tween).
func _on_full_message_finished() -> void:
	_message_tween = null
	if _full_message != null:
		_full_message.visible = false
		_full_message.modulate.a = 1.0


## Esconde o aviso na hora (troca de ligação, pausa de teste, novo aviso).
func _hide_full_message() -> void:
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()
	_message_tween = null
	if _full_message != null:
		_full_message.visible = false
		_full_message.modulate.a = 1.0


## Nome do item para a HUD, por contrato (`get_display_name`), sem importar
## `items/` nem `shared/items`.
func _item_label(item: Variant) -> String:
	if item == null:
		return ""
	if item is Object and item.has_method("get_display_name"):
		return str(item.call("get_display_name"))
	return str(item)


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
