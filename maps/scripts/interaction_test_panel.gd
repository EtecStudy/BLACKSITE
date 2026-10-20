class_name InteractionTestPanel
extends Interactable
## Objeto de teste do sistema de interação (Etapa 7).
##
## Propositalmente genérico: um painel com base, tela iluminada e colisão. Serve
## só para provar que o detector do jogador encontra o objeto pelo raio e que o
## **próprio objeto** executa sua ação — não é uma porta, item ou mecânica
## definitiva.
##
## Ao interagir, o painel conta a interação, acende a tela por um instante e
## mostra "INTERAÇÃO EXECUTADA" (Label3D) por `feedback_duration` segundos,
## sumindo com um fade curto. Nenhuma imagem é usada.

const DEFAULT_FEEDBACK_DURATION := 1.8

## Tempo (s) que a confirmação "INTERAÇÃO EXECUTADA" fica visível.
@export var feedback_duration: float = DEFAULT_FEEDBACK_DURATION

@onready var _status: Label3D = %Status
@onready var _face: MeshInstance3D = %ScreenFace

var _count: int = 0
var _feedback_left: float = 0.0
var _face_material: StandardMaterial3D = null
var _base_emission: float = 0.0


func _ready() -> void:
	_status.visible = false
	_status.modulate.a = 1.0
	set_process(false)
	# Material próprio por instância: dois painéis não compartilham o brilho.
	var material := _face.get_active_material(0) as StandardMaterial3D
	if material != null:
		_face_material = material.duplicate() as StandardMaterial3D
		_face.material_override = _face_material
		_base_emission = _face_material.emission_energy_multiplier


## Ação do objeto: só ela sabe o que "interagir" significa aqui.
func _on_interact(_actor: Node) -> void:
	_count += 1
	_feedback_left = feedback_duration
	_status.visible = true
	_status.modulate.a = 1.0
	if _face_material != null:
		_face_material.emission_energy_multiplier = _base_emission + 1.6
	set_process(true)


func _process(delta: float) -> void:
	_feedback_left = maxf(0.0, _feedback_left - delta)
	if _feedback_left <= 0.6:
		_status.modulate.a = clampf(_feedback_left / 0.6, 0.0, 1.0)
	if _feedback_left <= 0.0:
		_status.visible = false
		if _face_material != null:
			_face_material.emission_energy_multiplier = _base_emission
		set_process(false)


## Quantas vezes este painel foi interagido (usado pelos testes).
func get_interaction_count() -> int:
	return _count


func is_feedback_visible() -> bool:
	return _status != null and _status.visible


func get_feedback_text() -> String:
	return _status.text if _status != null else ""
