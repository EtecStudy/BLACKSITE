extends Node3D
## Captura o primeiro andar do laboratório (Etapa 12A) para revisão humana.
##
## Uso (precisa de renderização real — janela ou Xvfb + OpenGL):
##     godot --path . --fixed-fps 60 res://tools/ci/first_floor_visual_check.tscn
##
## Gera uma imagem por ponto de referência em `res://ci-logs/visual-12a/`:
## entrada, recepção, segurança, controle, corredor principal nos dois
## sentidos, cruzamento central, pesquisa, análises, observação, escritórios,
## logística, setor técnico, escada sul e uma planta baixa ortográfica.
##
## Não é teste de aprovação: é evidência visual. Falha (código 1) apenas se
## não conseguir salvar as imagens.

const FLOOR_SCENE := "res://maps/scenes/laboratory_first_floor.tscn"
const OUT_DIR := "res://ci-logs/visual-12a"
const FOV := 68.0

const SHOTS: Array = [
	{
		"name": "01_entrada",
		"from": Vector3(-44.0, 1.75, 5.5),
		"to": Vector3(-30.0, 1.2, 0.0),
		"note": "vestíbulo de entrada visto de dentro",
	},
	{
		"name": "02_recepcao",
		"from": Vector3(-37.0, 2.2, -8.0),
		"to": Vector3(-12.0, 1.0, 6.0),
		"note": "recepção com pé-direito duplo e pilares",
	},
	{
		"name": "03_seguranca",
		"from": Vector3(-37.0, 1.8, -28.0),
		"to": Vector3(-6.0, 1.0, -16.0),
		"note": "sala de segurança e divisória interna",
	},
	{
		"name": "04_controle",
		"from": Vector3(-13.0, 1.8, 7.0),
		"to": Vector3(10.0, 1.0, -8.0),
		"note": "posto de controle junto ao eixo principal",
	},
	{
		"name": "05_corredor_principal_oeste",
		"from": Vector3(-14.0, 1.8, 0.0),
		"to": Vector3(22.0, 1.4, 0.0),
		"note": "corredor principal de 5,6 m livres, vigas e lumárias",
	},
	{
		"name": "06_corredor_principal_leste",
		"from": Vector3(30.0, 1.8, 0.0),
		"to": Vector3(74.0, 1.4, 0.0),
		"note": "continuação do eixo até a ligação sul",
	},
	{
		"name": "07_cruzamento_central",
		"from": Vector3(15.0, 2.0, -9.0),
		"to": Vector3(34.0, 1.0, 9.0),
		"note": "grande cruzamento central com 21,6 m e pé-direito duplo",
	},
	{
		"name": "08_pesquisa",
		"from": Vector3(15.0, 1.8, -12.0),
		"to": Vector3(33.0, 1.0, -26.0),
		"note": "pesquisa A: dois vãos para o cruzamento e pilares",
	},
	{
		"name": "09_analises",
		"from": Vector3(36.0, 1.8, -4.0),
		"to": Vector3(57.0, 1.2, -26.0),
		"note": "análises com divisória interna e parede de observação",
	},
	{
		"name": "10_observacao",
		"from": Vector3(59.0, 1.8, -4.0),
		"to": Vector3(71.0, 2.2, -26.0),
		"note": "observação com pé-direito duplo e dois vãos para análises",
	},
	{
		"name": "11_escritorios",
		"from": Vector3(36.0, 1.8, 4.0),
		"to": Vector3(71.0, 1.2, 21.0),
		"note": "escritórios e arquivo com divisórias",
	},
	{
		"name": "12_logistica",
		"from": Vector3(14.0, 1.8, 28.0),
		"to": Vector3(35.0, 1.0, 45.0),
		"note": "apoio logístico e circulação do setor técnico",
	},
	{
		"name": "13_escada_sul",
		"from": Vector3(65.5, 1.8, 28.0),
		"to": Vector3(69.0, -1.5, 45.0),
		"note": "escada sul descendo para o subsolo",
	},
	{
		"name": "14_planta_baixa",
		"from": Vector3(17.0, 120.0, 0.0),
		"to": Vector3(17.0, 0.0, 0.0),
		"ortho": 132.0,
		"note": "planta baixa ortográfica do andar inteiro",
	},
]

var _saved: int = 0
var _failed: int = 0


func _ready() -> void:
	var packed: PackedScene = load(FLOOR_SCENE) as PackedScene
	if packed == null:
		push_error("Não foi possível carregar %s" % FLOOR_SCENE)
		get_tree().quit(1)
		return
	var floor_node: Node3D = packed.instantiate() as Node3D
	if floor_node == null:
		push_error("A planta não instanciou")
		get_tree().quit(1)
		return
	add_child(floor_node)

	var camera := Camera3D.new()
	camera.name = "CaptureCamera"
	camera.fov = FOV
	camera.near = 0.05
	camera.far = 400.0
	add_child(camera)
	camera.current = true

	var dir: String = ProjectSettings.globalize_path(OUT_DIR)
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		push_error("Não foi possível criar %s" % dir)
		get_tree().quit(1)
		return

	await _warm_up()
	for shot: Dictionary in SHOTS:
		await _capture(camera, shot, dir)

	print("[visual 12A] %d capturas, %d falhas em %s" % [_saved, _failed, dir])
	if _failed > 0 or _saved == 0:
		get_tree().quit(1)
		return
	print("VISUAL 12A OK — %d capturas do primeiro andar" % _saved)
	get_tree().quit(0)


func _warm_up() -> void:
	for _index: int in 10:
		await get_tree().process_frame


func _capture(camera: Camera3D, shot: Dictionary, dir: String) -> void:
	if shot.has("ortho"):
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = float(shot["ortho"])
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.global_position = shot["from"]
	camera.look_at(shot["to"], Vector3.UP)
	for _index: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("[visual 12A] captura vazia: %s" % shot["name"])
		_failed += 1
		return
	var path: String = dir.path_join("%s.png" % shot["name"])
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("[visual 12A] falha ao salvar %s (erro %d)" % [path, error])
		_failed += 1
		return
	_saved += 1
	print("[visual 12A] %-30s %dx%d  %s" % [shot["name"], image.get_width(),
		image.get_height(), shot["note"]])
