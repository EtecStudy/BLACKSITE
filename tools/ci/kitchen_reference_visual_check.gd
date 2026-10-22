extends Node3D
## Verificação visual da reconstrução 3D da imagem de referência.
##
## Carrega `maps/reference/kitchen_reference.tscn`, valida a estrutura
## (nós, materiais, correntes, colisores, luzes) e captura 5 ângulos —
## incluindo a câmera equivalente à da imagem de referência — para
## comparação lado a lado no log de diagnósticos. Não modula gameplay:
## é uma ferramenta de CI/desenvolvimento.

const SCENE_PATH: String = "res://maps/reference/kitchen_reference.tscn"
const OUTPUT_NAMES: Array[String] = [
	"kitchen_01_referencia.png",
	"kitchen_02_porta.png",
	"kitchen_03_cozinha.png",
	"kitchen_04_ilha.png",
	"kitchen_05_inversa.png",
]

@onready var _camera: Camera3D = $Camera3D

var _passes: int = 0
var _failures: int = 0
var _output_dir: String = ""


func _ready() -> void:
	print("KITCHEN REFERENCE CHECK: início")
	_parse_args()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await _run()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("KITCHEN-OK: ", label)
	else:
		_failures += 1
		push_error("KITCHEN-FALHOU: " + label)
		print("KITCHEN-FALHOU: ", label)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):
			_output_dir = arg.trim_prefix("--output-dir=")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "cena da cozinha carrega")
	if packed == null:
		_finish()
		return
	var room: Node3D = packed.instantiate() as Node3D
	add_child(room)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	_check(room.get_node_or_null("Architecture") != null, "grupo Architecture existe")
	_check(room.get_node_or_null("Kitchen") != null, "grupo Kitchen existe")
	_check(room.get_node_or_null("Island") != null, "grupo Island existe")
	_check(room.get_node_or_null("Spawn") is Marker3D, "Spawn Marker3D existe")

	var meshes := 0
	var stack: Array[Node] = [room]
	var positions: Array[Vector3] = []
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			meshes += 1
			positions.append((node as MeshInstance3D).global_position)
		for child in node.get_children():
			stack.append(child)
	_check(meshes >= 300, "pelo menos 300 MeshInstance3D (real: %d)" % meshes)

	var links := 0
	var chain_parent := room.get_node_or_null("Architecture/ChainedDoor")
	if chain_parent != null:
		for child in chain_parent.get_children():
			if child.name.begins_with("ChainLink"):
				links += 1
	_check(links >= 80, "corrente com pelo menos 80 elos (real: %d)" % links)

	var bodies := room.find_children("*", "StaticBody3D", true, false)
	_check(bodies.size() >= 1, "StaticBody3D presente")
	var shapes := room.find_children("*", "CollisionShape3D", true, false)
	_check(shapes.size() >= 10, "pelo menos 10 CollisionShape3D (real: %d)" % shapes)
	var omnis := room.find_children("*", "OmniLight3D", true, false)
	var spots := room.find_children("*", "SpotLight3D", true, false)
	_check(omnis.size() >= 2, "pelo menos 2 OmniLight3D (real: %d)" % omnis.size())
	_check(spots.size() >= 2, "pelo menos 2 SpotLight3D (real: %d)" % spots.size())

	var camera_positions: Array[Vector3] = [
		Vector3(3.02, 1.63, 2.82),
		Vector3(-1.55, 1.50, 0.75),
		Vector3(0.35, 1.55, 0.55),
		Vector3(2.85, 1.45, 2.55),
		Vector3(-2.55, 1.62, -1.55),
	]
	var camera_targets: Array[Vector3] = [
		Vector3(-1.75, 0.88, -2.05),
		Vector3(-3.55, 1.12, -0.80),
		Vector3(0.60, 0.95, -3.20),
		Vector3(0.30, 0.50, 1.15),
		Vector3(2.30, 0.95, 2.60),
	]
	_check(OUTPUT_NAMES.size() == camera_positions.size(), "5 câmeras pareadas com 5 nomes")

	var captured := 0
	for i in OUTPUT_NAMES.size():
		_camera.global_position = camera_positions[i]
		_camera.look_at(camera_targets[i], Vector3.UP)
		_camera.fov = 63.0
		_camera.current = true
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if await _capture(OUTPUT_NAMES[i]):
			captured += 1
	_check(captured == OUTPUT_NAMES.size(), "capturou as 5 imagens (real: %d)" % captured)
	_finish()


func _capture(file_name: String) -> bool:
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("KITCHEN-FALHOU: viewport vazia para " + file_name)
		return false
	if _output_dir.is_empty():
		return true
	DirAccess.make_dir_recursive_absolute(_output_dir)
	var err: Error = image.save_png(_output_dir.path_join(file_name))
	if err != OK:
		push_error("KITCHEN-FALHOU: erro %d ao salvar %s" % [err, file_name])
		return false
	return true


func _finish() -> void:
	print("KITCHEN REFERENCE CHECK: %d ok / %d falhas" % [_passes, _failures])
	var code: int = 0 if _failures == 0 else 1
	print("KITCHEN REFERENCE CHECK: concluído com código ", code)
	await get_tree().create_timer(0.25).timeout
	get_tree().quit(code)
