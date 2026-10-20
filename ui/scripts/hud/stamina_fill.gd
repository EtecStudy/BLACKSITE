class_name StaminaFill
extends Control
## Desenho nativo da barra de stamina (sem texturas).
##
## A barra é composta por um trilho escuro com contorno de 1 px (mesma
## linguagem dos painéis das configurações), um preenchimento em tom pergaminho
## e um pequeno marcador no limiar de retomada da corrida. Quando o valor fica
## abaixo do limiar, o preenchimento usa o vermelho discreto já presente no
## tema (estado pressionado dos botões) — nenhuma cor é inventada.

const TRACK_COLOR := Color(0.02, 0.02, 0.023, 0.9)
const BORDER_COLOR := Color(0.62, 0.58, 0.51, 0.32)
const FILL_COLOR := Color(0.8, 0.76, 0.68, 0.95)
const LOW_COLOR := Color(0.55, 0.16, 0.16, 0.95)
const HALO_COLOR := Color(0.62, 0.58, 0.51, 0.55)

## Abaixo desta fração o preenchimento muda para o tom de alerta.
@export_range(0.0, 1.0, 0.01) var low_threshold: float = 0.2

var _ratio: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


## Define a fração exibida (0..1). O valor é fixado imediatamente no desenho.
func set_ratio(value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, _ratio):
		return
	_ratio = clamped
	queue_redraw()


func get_ratio() -> float:
	return _ratio


## Largura útil preenchida, em pixels (usada pelos testes).
func get_fill_width() -> float:
	return _inner_rect().size.x * _ratio


func _inner_rect() -> Rect2:
	var inner: Vector2 = Vector2(maxf(size.x - 2.0, 0.0), maxf(size.y - 2.0, 0.0))
	return Rect2(Vector2(1.0, 1.0), inner)


func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	draw_rect(outer, TRACK_COLOR, true)
	draw_rect(outer, BORDER_COLOR, false, 1.0)

	var inner: Rect2 = _inner_rect()
	if _ratio > 0.0 and inner.size.x > 0.0:
		var fill := Rect2(
			inner.position,
			Vector2(inner.size.x * _ratio, inner.size.y)
		)
		draw_rect(fill, LOW_COLOR if _ratio < low_threshold else FILL_COLOR, true)

	# Marcador do limiar de retomada da corrida (20%).
	var x: float = inner.position.x + inner.size.x * low_threshold
	if x > inner.position.x and x < inner.end.x:
		draw_line(
			Vector2(x, outer.position.y + 1.0),
			Vector2(x, outer.end.y - 1.0),
			HALO_COLOR,
			1.0
		)
