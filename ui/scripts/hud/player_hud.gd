class_name PlayerHud
extends Control
## HUD da partida — por enquanto, a barra de stamina.
##
## Integração sem acoplamento: `bind_player()` aceita qualquer `Node` com o
## sinal `stamina_changed(current, maximum)` e os métodos `get_stamina()` /
## `get_max_stamina()`. A HUD não importa o controlador (ui/ continua dependendo
## apenas de shared/) e não guarda uma segunda stamina.
##
## Estrutura preparada para crescer: novos componentes entram no `Stack` do
## canto inferior esquerdo, acima da barra, sem reconstruir a HUD.

@onready var _stamina_bar: StaminaBar = %StaminaBar

var _player: Node = null


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
