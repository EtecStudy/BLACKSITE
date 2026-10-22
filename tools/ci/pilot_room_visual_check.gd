extends Node3D
## Captura visual da Sala-Piloto (requer Xvfb/OpenGL, como as outras capturas).
##
## Gera vistas amplas, primeira pessoa, parede/teto, piso/móveis, porta,
## janela de observação, equipamentos e teto técnico. Não substitui a
## avaliação manual em primeira pessoa.

const ROOM_SCENE: String = "res://maps/pilot/pilot_research_room.tscn"
const OUTPUT_DIR: String = "res://ci-logs/visual-pilot"

var _failures: int = 0


func _ready() -> void:
	_run()


func _save_shot(camera: Camera3D, file_name: String) -> void:
	for i in range(18):
		await get_tree().process_frame
	var image: Image = get_tree().root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("[PILOT VISUAL FALHA] Não foi possível capturar %s" % file_name)
		_failures += 1
		return
	var path: String = OUTPUT_DIR.path_join(file_name)
	var error: Error = image.save_png(path)
	if error == OK:
		print("[PILOT VISUAL] Captura salva: %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	else:
		printerr("[PILOT VISUAL FALHA] Erro %d ao salvar %s" % [error, path])
		_failures += 1


func _look(camera: Camera3D, from: Vector3, target: Vector3) -> void:
	camera.global_position = from
	camera.look_at(target, Vector3.UP)


func _report_metrics(context: String) -> void:
	# Contadores por quadro do renderizador (llvmpipe no CI): servem para
	# comparar revisões da mesma cena, não como promessa de desempenho.
	print("[PILOT VISUAL] métricas (%s): draw calls no quadro=%d primitivas=%d memória de texturas=%d bytes memória de vídeo=%d bytes" % [
		context,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),
	])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene: PackedScene = load(ROOM_SCENE) as PackedScene
	if scene == null:
		printerr("[PILOT VISUAL FALHA] A sala-piloto não carregou")
		get_tree().quit(1)
		return
	var room: Node3D = scene.instantiate() as Node3D
	add_child(room)
	await get_tree().process_frame

	var camera := Camera3D.new()
	camera.fov = 68.0
	camera.near = 0.03
	camera.far = 80.0
	add_child(camera)
	camera.current = true

	_look(camera, Vector3(-4.25, 2.35, 5.20), Vector3(1.8, 0.65, -2.4))
	await _save_shot(camera, "01_sala_inteira.png")
	_report_metrics("vista geral")
	_look(camera, Vector3(-2.60, 1.62, 4.35), Vector3(-0.4, 1.05, -1.2))
	await _save_shot(camera, "02_primeira_pessoa_spawn.png")
	_look(camera, Vector3(-4.34, 1.35, -0.20), Vector3(-5.0, 2.6, -1.8))
	await _save_shot(camera, "03_parede_e_teto.png")
	_look(camera, Vector3(2.9, 2.65, 3.9), Vector3(-1.2, 0.15, -1.2))
	await _save_shot(camera, "04_piso_e_moveis.png")
	_look(camera, Vector3(-0.55, 1.60, 3.65), Vector3(-2.2, 1.35, 6.0))
	await _save_shot(camera, "05_porta_principal.png")
	_look(camera, Vector3(2.65, 1.62, -1.0), Vector3(5.0, 1.75, -1.0))
	await _save_shot(camera, "06_janela_observacao.png")
	_look(camera, Vector3(-0.55, 1.52, -2.65), Vector3(-2.3, 1.65, -5.45))
	await _save_shot(camera, "07_capela_e_bancada_norte.png")
	_look(camera, Vector3(0.0, 1.15, 3.65), Vector3(0.2, 3.25, -2.2))
	await _save_shot(camera, "08_teto_tecnico.png")
	_look(camera, Vector3(-3.85, 1.55, -4.15), Vector3(0.5, 1.0, 0.8))
	await _save_shot(camera, "09_bancada_central.png")
	_look(camera, Vector3(-3.35, 1.52, 3.35), Vector3(-5.0, 1.05, 5.95))
	await _save_shot(camera, "10_quina_e_parede.png")
	_look(camera, Vector3(3.05, 1.45, -1.15), Vector3(4.52, 1.05, -2.55))
	await _save_shot(camera, "11_equipamento_detalhe.png")
	_look(camera, Vector3(4.30, 1.52, 4.65), Vector3(-1.2, 2.85, -3.2))
	await _save_shot(camera, "12_iluminacao_e_forro.png")
	# Close-ups de sinalização: legibilidade, orientação e alinhamento às placas.
	_look(camera, Vector3(3.55, 2.30, -1.0), Vector3(4.95, 2.72, -1.0))
	await _save_shot(camera, "13_sinalizacao_janela.png")
	_look(camera, Vector3(-3.55, 1.95, 1.55), Vector3(-4.95, 2.05, 1.55))
	await _save_shot(camera, "14_sinalizacao_epi.png")
	_look(camera, Vector3(-0.72, 1.70, 4.35), Vector3(-0.72, 1.70, 5.95))
	await _save_shot(camera, "15_sinalizacao_porta.png")

	_report_metrics("close final")
	if _failures == 0:
		print("[PILOT VISUAL] CAPTURAS DA SALA-PILOTO PASSARAM")
		get_tree().quit(0)
	else:
		printerr("[PILOT VISUAL] CAPTURAS FALHARAM com %d problema(s)" % _failures)
		get_tree().quit(1)
