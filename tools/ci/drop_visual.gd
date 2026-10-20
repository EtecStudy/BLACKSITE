extends Node
## Verificação **com imagem** do drop (Etapa 9).
##
## Uso (CI, com janela virtual e captura de frames):
##     xvfb-run -a godot --path . res://tools/ci/drop_visual.tscn \
##         --rendering-driver opengl3 --fixed-fps 30 --write-movie frames/frame.png
##
## Roda a **cena real** renderizada: coleta o ITEM A pela interação, solta com a
## ação `inventory_drop` (G), espera o item assentar e mira nele. O último frame
## capturado mostra o item no chão com o nome, a indicação "[E] Pegar" e a HUD
## com o slot 1 em VAZIO.
##
## Sai com 0 e imprime `DROP VISUAL OK` quando o estado esperado é confirmado.

const MOVEMENT_SCENE := "res://match/scenes/movement_test.tscn"
const ITEM_VIEW := Vector3(-1.7, 0.05, 7.7)
const ITEM_PITCH := -0.34
const HOLD_FRAMES := 24


func _ready() -> void:
	var packed: PackedScene = load(MOVEMENT_SCENE) as PackedScene
	if packed == null:
		_fail("não foi possível carregar a cena de teste")
		return
	var scene: Node = packed.instantiate()
	add_child(scene)
	await _frames(4)

	var player: Node = scene.get_node_or_null("Player")
	var item: Node = scene.get_node_or_null("TestItemA")
	var hud: Node = scene.get_node_or_null("Interface/PlayerHud")
	if player == null or item == null or hud == null:
		_fail("cena sem jogador, item A ou HUD")
		return

	player.global_position = ITEM_VIEW
	player.velocity = Vector3.ZERO
	player.set_look(0.0, ITEM_PITCH)
	await _frames(10)
	if player.get_interaction_detector().get_current_interactable() != item:
		_fail("o item A não está na mira")
		return

	await _tap("interact")
	await _frames(6)
	var inventory: Node = player.get_inventory()
	if inventory == null or inventory.get_item(0) == null:
		_fail("o item A não entrou no slot 1")
		return

	await _tap("inventory_drop")
	await _frames(8)
	if not inventory.is_slot_empty(0):
		_fail("G não esvaziou o slot 1")
		return

	var dropped: Node = _find_dropped(scene)
	if dropped == null:
		_fail("nenhum item solto na cena")
		return
	await _frames(30)

	var bar: Node = hud.get_inventory_bar()
	if bar == null or bar.get_slot_text(0) != "VAZIO":
		_fail("HUD não mostra VAZIO no slot 1")
		return

	# Mira no item no chão a partir de 1,6 m.
	var body: Node3D = dropped.get_node_or_null("Body") as Node3D
	var target: Vector3 = body.global_position if body != null else dropped.global_position
	target.y += 0.2
	player.global_position = Vector3(target.x, 0.05, target.z + 1.6)
	player.velocity = Vector3.ZERO
	await _frames(8)
	var camera: Camera3D = player.get_node_or_null("Head/Camera") as Camera3D
	var eye: Vector3 = camera.global_position if camera != null else player.global_position
	var delta: Vector3 = target - eye
	player.set_look(atan2(-delta.x, -delta.z), atan2(delta.y, maxf(Vector2(delta.x, delta.z).length(), 0.001)))
	await _frames(10)

	var detector: Node = player.get_interaction_detector()
	if detector.get_current_interactable() != dropped:
		_fail("o item solto não está na mira")
		return
	if not hud.is_drop_bound():
		_fail("HUD não está ligada ao drop")
		return

	print(
		"[drop-visual] slot1=%s slot2=%s slot3=%s mundo=%s em foco=%s"
		% [
			bar.get_slot_text(0),
			bar.get_slot_text(1),
			bar.get_slot_text(2),
			dropped.get_display_name(),
			detector.get_current_interactable().get_interaction_text(),
		]
	)

	await _frames(HOLD_FRAMES)
	print("DROP VISUAL OK")
	get_tree().quit(0)


func _find_dropped(scene: Node) -> Node:
	for child: Node in scene.get_children():
		if child is WorldItem:
			return child
	return null


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().process_frame


func _fail(reason: String) -> void:
	printerr("DROP VISUAL FALHOU — " + reason)
	get_tree().quit(1)
