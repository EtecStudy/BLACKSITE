extends Node3D
## Verificação visual da Sala de Exibição (espaço aberto do kit visual).
##
## Carrega `maps/exhibition/exhibition_room.tscn`, valida a estrutura
## aberta (plataforma, áreas demarcadas por fita, placas, luzes e
## colisões) e confirma que NÃO existe sala fechada (sem grupos do
## desenho anterior). Captura 4 ângulos para o log de diagnósticos.
## Ferramenta de CI/desenvolvimento — não altera gameplay.

const SCENE_PATH: String = "res://maps/exhibition/exhibition_room.tscn"
const OUTPUT_NAMES: Array[String] = [
	"exhibition_01_aberto.png",
	"exhibition_02_parede.png",
	"exhibition_03_areas.png",
	"exhibition_04_fita.png",
]

@onready var _camera: Camera3D = $Camera3D

var _passes: int = 0
var _failures: int = 0
var _output_dir: String = ""


func _ready() -> void:
	print("EXHIBITION CHECK: início")
	_parse_args()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await _run()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("EXHIBITION-OK: ", label)
	else:
		_failures += 1
		push_error("EXHIBITION-FALHOU: " + label)
		print("EXHIBITION-FALHOU: ", label)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):
			_output_dir = arg.trim_prefix("--output-dir=")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "cena da sala de exibição carrega")
	if packed == null:
		_finish()
		return
	var room: Node3D = packed.instantiate() as Node3D
	add_child(room)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# Espaço aberto: plataforma + áreas demarcadas, sem sala fechada.
	_check(room.get_node_or_null("Platform") != null, "grupo Platform existe")
	_check(room.get_node_or_null("AreaParede") != null, "grupo AreaParede existe")
	_check(room.get_node_or_null("AreaPiso") != null, "grupo AreaPiso existe")
	_check(room.get_node_or_null("AreaTeto") != null, "grupo AreaTeto existe")
	_check(room.get_node_or_null("Gallery") == null, "sem grupo Gallery (sala fechada removida)")
	_check(room.get_node_or_null("KitFloor") == null, "sem KitFloor (desenho anterior removido)")
	_check(room.get_node_or_null("KitWall") == null, "sem KitWall (parede ainda não criada)")
	_check(room.get_node_or_null("KitCeiling") == null, "sem KitCeiling (teto ainda não criado)")
	_check(room.get_node_or_null("Spawn") is Marker3D, "Spawn Marker3D existe")

	var tape := 0
	var signs := 0
	var stack: Array[Node] = [room]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.name.begins_with("Tape"):
			tape += 1
		if node.name.begins_with("SignPanel") and node is MeshInstance3D:
			signs += 1
		for child in node.get_children():
			stack.append(child)
	_check(tape >= 12, "pelo menos 12 peças de fita (real: %d)" % tape)
	_check(signs >= 3, "pelo menos 3 placas de identificação (real: %d)" % signs)

	var shapes := room.find_children("*", "CollisionShape3D", true, false)
	_check(shapes.size() >= 8, "pelo menos 8 CollisionShape3D (real: %d)" % shapes.size())
	var omnis := room.find_children("*", "OmniLight3D", true, false)
	var dirs := room.find_children("*", "DirectionalLight3D", true, false)
	_check(omnis.size() >= 3, "pelo menos 3 OmniLight3D (real: %d)" % omnis.size())
	_check(dirs.size() >= 1, "pelo menos 1 DirectionalLight3D (real: %d)" % dirs.size())

	var camera_positions: Array[Vector3] = [
		Vector3(-17.2, 1.70, 4.6),
		Vector3(-11.5, 1.55, 5.2),
		Vector3(0.0, 1.60, 6.4),
		Vector3(7.6, 0.85, 3.4),
	]
	var camera_targets: Array[Vector3] = [
		Vector3(0.0, 0.60, -0.6),
		Vector3(-11.5, 0.45, -0.4),
		Vector3(0.5, 0.45, -0.8),
		Vector3(11.5, 0.15, -0.6),
	]
	_check(OUTPUT_NAMES.size() == camera_positions.size(), "4 câmeras pareadas com 4 nomes")

	var captured := 0
	for i in OUTPUT_NAMES.size():
		_camera.global_position = camera_positions[i]
		_camera.look_at(camera_targets[i], Vector3.UP)
		_camera.fov = 62.0
		_camera.current = true
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if await _capture(OUTPUT_NAMES[i]):
			captured += 1
	_check(captured == OUTPUT_NAMES.size(), "capturou as 4 imagens (real: %d)" % captured)
	_finish()


func _capture(file_name: String) -> bool:
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("EXHIBITION-FALHOU: viewport vazia para " + file_name)
		return false
	if _output_dir.is_empty():
		return true
	DirAccess.make_dir_recursive_absolute(_output_dir)
	var err: Error = image.save_png(_output_dir.path_join(file_name))
	if err != OK:
		push_error("EXHIBITION-FALHOU: erro %d ao salvar %s" % [err, file_name])
		return false
	return true


func _finish() -> void:
	print("EXHIBITION CHECK: %d ok / %d falhas" % [_passes, _failures])
	var code: int = 0 if _failures == 0 else 1
	print("EXHIBITION CHECK: concluído com código ", code)
	await get_tree().create_timer(0.25).timeout
	get_tree().quit(code)
