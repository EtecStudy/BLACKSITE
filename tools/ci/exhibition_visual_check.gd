extends Node3D
## Verificação visual da Sala de Exibição do Kit Visual.
##
## Carrega `maps/exhibition/exhibition_room.tscn`, valida a estrutura
## (galeria, piso/parede/teto de teste, luzes e colisões) e captura 4
## ângulos para avaliação dos materiais no log de diagnósticos.
## Ferramenta de CI/desenvolvimento — não altera gameplay.

const SCENE_PATH: String = "res://maps/exhibition/exhibition_room.tscn"
const OUTPUT_NAMES: Array[String] = [
	"exhibition_01_galeria.png",
	"exhibition_02_piso.png",
	"exhibition_03_parede.png",
	"exhibition_04_teto.png",
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

	_check(room.get_node_or_null("Gallery") != null, "grupo Gallery existe")
	_check(room.get_node_or_null("KitFloor") != null, "grupo KitFloor (piso de teste) existe")
	_check(room.get_node_or_null("KitWall") != null, "grupo KitWall (parede de teste) existe")
	_check(room.get_node_or_null("KitCeiling") != null, "grupo KitCeiling (teto de teste) existe")
	_check(room.get_node_or_null("Spawn") is Marker3D, "Spawn Marker3D existe")

	var meshes := 0
	var stack: Array[Node] = [room]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			meshes += 1
		for child in node.get_children():
			stack.append(child)
	_check(meshes >= 120, "pelo menos 120 MeshInstance3D (real: %d)" % meshes)

	var shapes := room.find_children("*", "CollisionShape3D", true, false)
	_check(shapes.size() >= 8, "pelo menos 8 CollisionShape3D (real: %d)" % shapes.size())
	var omnis := room.find_children("*", "OmniLight3D", true, false)
	var spots := room.find_children("*", "SpotLight3D", true, false)
	_check(omnis.size() >= 2, "pelo menos 2 OmniLight3D (real: %d)" % omnis.size())
	_check(spots.size() >= 4, "pelo menos 4 SpotLight3D (real: %d)" % spots.size())

	var camera_positions: Array[Vector3] = [
		Vector3(-13.2, 1.65, 3.4),
		Vector3(-4.6, 1.35, 2.6),
		Vector3(0.0, 1.55, 3.1),
		Vector3(9.6, 1.45, 4.6),
	]
	var camera_targets: Array[Vector3] = [
		Vector3(0.0, 1.10, -0.4),
		Vector3(-9.2, 0.05, -0.3),
		Vector3(0.0, 1.30, -1.2),
		Vector3(9.6, 2.95, -0.3),
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
