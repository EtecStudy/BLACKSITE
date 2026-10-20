extends Node
## Verificação **com imagem** do inventário (Etapa 8).
##
## Uso (CI, com janela virtual e captura de frames):
##     xvfb-run -a godot --path . res://tools/ci/inventory_visual.tscn \
##         --rendering-driver opengl3 --fixed-fps 30 --write-movie frames/frame.png
##
## Diferente dos testes headless, este roteiro roda a **cena real** renderizada:
## instancia `match/scenes/movement_test.tscn`, posiciona o jogador diante do
## item A, coleta com a ação `interact`, seleciona o slot 3 (vazio) e segura o
## estado por alguns frames para que o último frame capturado mostre a HUD com
## um slot preenchido e outro selecionado.
##
## Sai com 0 e imprime `INVENTORY VISUAL OK` quando o estado esperado é
## confirmado; o CI guarda o frame em `ci-logs/inventory_hud.png`.

const MOVEMENT_SCENE := "res://match/scenes/movement_test.tscn"
const ITEM_VIEW := Vector3(-1.7, 0.05, 7.7)
const ITEM_PITCH := -0.34
## Frames parados no estado final (garante que o frame capturado seja o final).
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

	var detector: Node = player.get_interaction_detector()
	if detector == null or detector.get_current_interactable() != item:
		_fail("o item A não está na mira")
		return

	await _tap("interact")
	await _frames(6)
	if not item.is_collected():
		_fail("E não coletou o item A")
		return

	var inventory: Node = player.get_inventory()
	if inventory == null or inventory.get_item(0) == null:
		_fail("o item A não entrou no slot 1")
		return

	await _tap("inventory_slot_3")
	await _frames(2)

	var bar: InventoryBar = hud.get_inventory_bar()
	if bar == null:
		_fail("HUD sem a barra de slots")
		return
	if not bar.is_slot_selected(2):
		_fail("o slot 3 não ficou selecionado")
		return
	if bar.get_slot_text(0) != "ITEM A":
		_fail("slot 1 não mostra ITEM A (%s)" % bar.get_slot_text(0))
		return

	print(
		"[visual] slot1=%s slot2=%s slot3=%s selecionado=%d"
		% [
			bar.get_slot_text(0),
			bar.get_slot_text(1),
			bar.get_slot_text(2),
			bar.get_selected_index(),
		]
	)

	# Estado final estável por alguns frames antes de encerrar a captura.
	await _frames(HOLD_FRAMES)
	print("INVENTORY VISUAL OK")
	get_tree().quit(0)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().process_frame


func _fail(reason: String) -> void:
	printerr("INVENTORY VISUAL FALHOU — " + reason)
	get_tree().quit(1)
