extends Node3D
## Captura closes dos encaixes do cenário modular (revisão da Etapa 11).
##
## Uso (precisa de renderização real — com janela ou Xvfb + OpenGL):
##     godot --path . --fixed-fps 60 res://tools/ci/modular_visual_check.tscn
##
## Gera uma imagem por ponto crítico em `res://ci-logs/visual/`:
## parede reta (duas distâncias), canto interno/externo, porta, abertura,
## junção em T do ramal, parede rotacionada 90°, sala e pilar do hall.
##
## Não é um teste com aprovação/reprovação: é evidência visual para revisão
## humana. Falha (código 1) apenas se não conseguir salvar as imagens.

const ROOM_SCENE: String = "res://maps/scenes/modular_demo_room.tscn"
const OUT_DIR: String = "res://ci-logs/visual"
const FOV: float = 62.0

## Ponto crítico → posição da câmera e alvo (coordenadas do mundo da demo).
const SHOTS: Array = [
	{
		"name": "01_parede_reta_corredor",
		"from": Vector3(10.0, 1.30, 2.30),
		"to": Vector3(10.0, 0.22, 0.05),
		"note": "rodapé × parede branca do corredor (parede reta)",
	},
	{
		"name": "02_rodape_rasante",
		"from": Vector3(13.6, 0.42, 1.30),
		"to": Vector3(19.0, 0.24, 0.02),
		"note": "rasante ao longo do rodapé: ângulo onde o z-fighting aparece",
	},
	{
		"name": "03_canto_interno_oeste",
		"from": Vector3(2.60, 1.45, 2.60),
		"to": Vector3(0.05, 0.25, 0.05),
		"note": "canto interno noroeste: plinto × rodapé × parede",
	},
	{
		"name": "04_porta_sala_a",
		"from": Vector3(9.60, 1.45, 2.40),
		"to": Vector3(8.55, 0.30, -0.30),
		"note": "porta da sala A: batente, rodapé e ombreiro",
	},
	{
		"name": "05_abertura_sala_a",
		"from": Vector3(13.20, 1.45, 2.40),
		"to": Vector3(12.15, 0.20, -0.60),
		"note": "abertura da sala A: revestimento do vão e rodapé",
	},
	{
		"name": "06_juncao_ramal",
		"from": Vector3(34.00, 1.45, 2.60),
		"to": Vector3(33.10, 0.22, -0.70),
		"note": "junção em T do ramal com o corredor",
	},
	{
		"name": "07_parede_rotacionada",
		"from": Vector3(2.40, 1.40, 3.00),
		"to": Vector3(0.03, 0.25, 3.00),
		"note": "parede oeste (mesmo módulo rotacionado 90°)",
	},
	{
		"name": "08_sala_b_parede",
		"from": Vector3(26.0, 1.40, 7.80),
		"to": Vector3(26.0, 0.20, 6.45),
		"note": "lado oposto da mesma parede (sala B)",
	},
	{
		"name": "09_hall_pilar",
		"from": Vector3(31.2, 1.40, -26.4),
		"to": Vector3(29.0, 0.30, -25.0),
		"note": "sala técnica: base do pilar do pórtico e rodapé",
	},
	{
		"name": "10_corredor_amplo",
		"from": Vector3(2.20, 1.90, 3.00),
		"to": Vector3(30.0, 0.70, 3.00),
		"note": "corredor inteiro: os dois rodapés em perspectiva",
	},
]

var _saved: int = 0
var _failed: int = 0


func _ready() -> void:
	var packed: PackedScene = load(ROOM_SCENE) as PackedScene
	if packed == null:
		push_error("Não foi possível carregar %s" % ROOM_SCENE)
		get_tree().quit(1)
		return
	var room: Node3D = packed.instantiate() as Node3D
	if room == null:
		push_error("Cena do cenário modular não instanciou")
		get_tree().quit(1)
		return
	add_child(room)

	var camera := Camera3D.new()
	camera.name = "CaptureCamera"
	camera.fov = FOV
	camera.near = 0.03
	camera.far = 120.0
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

	print("[visual] %d capturas salvas, %d falhas em %s" % [_saved, _failed, dir])
	if _failed > 0 or _saved == 0:
		get_tree().quit(1)
		return
	print("VISUAL CHECK OK — %d capturas de encaixe" % _saved)
	get_tree().quit(0)


## Deixa a cena assentar (materiais, sombras e a primeira renderização).
func _warm_up() -> void:
	for _index: int in 8:
		await get_tree().process_frame


func _capture(camera: Camera3D, shot: Dictionary, dir: String) -> void:
	camera.global_position = shot["from"]
	camera.look_at(shot["to"], Vector3.UP)
	# Dois frames: um para a câmera entrar em vigor, outro para o desenho.
	for _index: int in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("[visual] captura vazia: %s" % shot["name"])
		_failed += 1
		return
	var path: String = dir.path_join("%s.png" % shot["name"])
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("[visual] falha ao salvar %s (erro %d)" % [path, error])
		_failed += 1
		return
	_saved += 1
	print("[visual] %-28s %dx%d  %s" % [shot["name"], image.get_width(), image.get_height(), shot["note"]])
