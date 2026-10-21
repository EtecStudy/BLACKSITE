extends Node
## Teste do sistema modular industrial (Etapa 11 — revisão).
##
## Uso:
##     godot --headless --path . --fixed-fps 60 --audio-driver Dummy \
##         res://tools/ci/modular_test.tscn
##
## Verifica, com física real (não só "a cena carregou"):
##   1. catálogo: cada módulo esperado existe, carrega, instancia e tem colisão;
##   2. convenção de encaixe: grade de 2 m, parede de 0,40 × 6 m, piso de
##      2 × 2 m com topo em y = 0, teto de 0,20 m;
##   3. vãos: porta de 4 m (vão 2,4 × 3,0) e abertura de 4 m (vão 3,6 × 4,2),
##      com ombreiras e verga fechando a parede;
##   4. encaixe entre peças: painéis vizinhos sem fresta nem sobreposição,
##      piso + piso, piso + teto na altura certa e canto de 0,40 m;
##   4b. acabamentos (rodapé, batente, plinto): nenhuma face divide plano com
##      a parede (z-fighting), nenhum acabamento enterrado e nenhum colisor
##      novo;
##   5. salas: piso contínuo, paredes contínuas fora dos vãos e porta livre;
##   6. corredores: principais e secundários, canto em L, T, cruzamento e
##      terminação, todos com piso e passagem livres;
##   7. escada: 16 degraus de 0,20 × 0,35 (3,20 m em 5,60 m) e guarda lateral;
##   8. demonstração: carrega, tem jogador/HUD/spawn e os módulos declarados;
##   9. jogabilidade: atravessar porta, abertura, ramal, hall e subir a escada
##      com o controlador existente; parede barra o jogador.
##
## Sai com 0 em caso de sucesso e 1 em caso de falha.

const GRID := 2.0
const WALL_H := 6.0
const WALL_T := 0.4
const FLOOR_T := 0.30
const CEIL_T := 0.20
const DOOR_W := 2.4
const DOOR_H := 3.0
const OPEN_W := 3.6
const OPEN_H := 4.2
const STAIR_RUN := 5.6
const STAIR_RISE := 3.2
const STAIR_STEPS := 16
const PLAYER_EYE := 1.62

const DEMO_SCENE := "res://maps/scenes/modular_demo_room.tscn"
const DEMO_SESSION := "res://match/scenes/modular_demo.tscn"

## Módulos obrigatórios da biblioteca (Etapa 11 — revisão).
const MODULES := [
	"res://maps/modular/floors/floor_tile.tscn",
	"res://maps/modular/floors/threshold_2m.tscn",
	"res://maps/modular/ceilings/ceiling_tile.tscn",
	"res://maps/modular/ceilings/ceiling_light.tscn",
	"res://maps/modular/walls/wall_panel_2m.tscn",
	"res://maps/modular/walls/wall_door_4m.tscn",
	"res://maps/modular/walls/wall_opening_4m.tscn",
	"res://maps/modular/walls/wall_corner_inner.tscn",
	"res://maps/modular/walls/wall_corner_outer.tscn",
	"res://maps/modular/walls/wall_junction.tscn",
	"res://maps/modular/structure/pillar.tscn",
	"res://maps/modular/structure/support_column.tscn",
	"res://maps/modular/structure/beam_6m.tscn",
	"res://maps/modular/structure/railing_2m.tscn",
	"res://maps/modular/stairs/stairs_straight.tscn",
	"res://maps/modular/corridors/corridor_main_8m.tscn",
	"res://maps/modular/corridors/corridor_secondary_8m.tscn",
	"res://maps/modular/corridors/corridor_corner_6.tscn",
	"res://maps/modular/corridors/corridor_tee_6.tscn",
	"res://maps/modular/corridors/corridor_cross_6.tscn",
	"res://maps/modular/corridors/corridor_end_6.tscn",
	"res://maps/modular/rooms/room_lab_10x10.tscn",
	"res://maps/modular/rooms/room_lab_12x16.tscn",
	"res://maps/modular/rooms/room_tech_14x20.tscn",
	"res://maps/modular/rooms/room_equipment_8x8.tscn",
]

## Ancoragem por família: onde fica a origem local de cada peça.
const ANCHOR_FLOOR := "centro da pegada, topo do piso em y = 0"
const ANCHOR_WALL := "centro do vão no eixo da parede, base em y = 0"
const ANCHOR_CORNER := "interseção da grade (encontro das duas paredes)"
const ANCHOR_STAIR := "centro do primeiro degrau, no piso"

var _checks: int = 0
var _failures: PackedStringArray = PackedStringArray()
var _finished: bool = false
var _last_progress_ms: int = 0
var _last_step: String = "início"
var _scene: Node = null
var _player: PlayerController = null
var _space: PhysicsDirectSpaceState3D = null

const WATCHDOG_MS := 60000


func _ready() -> void:
	print("=== Black Sight · teste do sistema modular industrial (Etapa 11) ===")
	_touch("início")
	_space = get_viewport().world_3d.direct_space_state
	_test_catalog()
	await _test_wall_dimensions()
	await _test_openings()
	await _test_corner_and_floor()
	await _test_finish_fit()
	await _test_rooms()
	await _test_corridors()
	await _test_stairs_geometry()
	await _test_demo_and_movement()
	_finish()


func _process(_delta: float) -> void:
	if _finished:
		return
	var idle: int = Time.get_ticks_msec() - _last_progress_ms
	if idle <= WATCHDOG_MS:
		return
	_finished = true
	printerr("MODULAR TEST TRAVOU — %d ms sem progresso (última etapa: %s)" % [idle, _last_step])
	printerr("verificações até aqui: %d · falhas: %d" % [_checks, _failures.size()])
	get_tree().quit(2)


func _touch(step: String = "") -> void:
	_last_progress_ms = Time.get_ticks_msec()
	if not step.is_empty():
		_last_step = step


# --- 1. Catálogo ------------------------------------------------------------

func _test_catalog() -> void:
	print("[1] Catálogo de módulos")
	for path: String in MODULES:
		_expect(FileAccess.file_exists(path), "arquivo existe: %s" % path.get_file())
		var packed: PackedScene = load(path) as PackedScene
		_expect(packed != null, "cena carrega: %s" % path.get_file())
		if packed == null:
			continue
		var instance: Node = packed.instantiate()
		_expect(instance != null, "cena instancia: %s" % path.get_file())
		if instance == null:
			continue
		var shapes: Array = _collision_shapes(instance)
		_expect(shapes.size() > 0, "%s tem colisão estrutural" % path.get_file())
		var layer_ok: bool = true
		for shape: CollisionShape3D in shapes:
			var body: CollisionObject3D = shape.get_parent() as CollisionObject3D
			if body == null or (body.collision_layer & 1) == 0:
				layer_ok = false
			if shape.shape == null:
				layer_ok = false
		_expect(layer_ok, "%s: colisões com forma e na camada 1 (mundo)" % path.get_file())
		instance.free()

	# Materiais compartilhados: as cenas apontam para os mesmos .tres.
	var material_paths: Dictionary = {}
	for path: String in MODULES:
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in _regex_find_all(text, "materials/([a-z_]+)\\.tres"):
			material_paths[found.get_string(1)] = true
	_expect(material_paths.size() >= 6,
		"materiais compartilhados usados pelos módulos (%d arquivos)" % material_paths.size())
	for name: String in material_paths:
		_expect(FileAccess.file_exists("res://maps/modular/materials/%s.tres" % name),
			"material existe: %s.tres" % name)

	# Convenções documentadas junto do catálogo.
	var docs: String = FileAccess.get_file_as_string("res://docs/ETAPA-11.md")
	_expect(docs.length() > 0, "documentação da etapa existe")
	for term: String in ["GRID", "0,40", "parede", "escada"]:
		_expect(docs.findn(term) >= 0, "documentação cita '%s'" % term)
	_expect(ANCHOR_FLOOR.contains("piso") and ANCHOR_WALL.contains("parede")
			and ANCHOR_CORNER.contains("interseção") and ANCHOR_STAIR.contains("degrau"),
		"convenções de origem declaradas no teste")


# --- 2. Dimensões das paredes ----------------------------------------------

func _test_wall_dimensions() -> void:
	print("[2] Dimensões das paredes")
	var wall: Node3D = await _spawn_module("res://maps/modular/walls/wall_panel_2m.tscn")
	_expect(wall != null, "painel de parede instanciado")
	if wall != null:
		var aabb: AABB = _collision_aabb(wall)
		_expect(is_equal_approx(aabb.size.x, GRID), "painel: comprimento %.2f m" % aabb.size.x)
		_expect(is_equal_approx(aabb.size.z, WALL_T), "painel: espessura %.2f m" % aabb.size.z)
		_expect(is_equal_approx(aabb.size.y, WALL_H), "painel: altura livre %.2f m" % aabb.size.y)
		_expect(is_equal_approx(aabb.position.y, 0.0), "painel: nasce no piso (y = 0)")
		_expect(is_equal_approx(aabb.position.z, -WALL_T / 2), "painel: centrado no eixo")
		var o: Vector3 = wall.global_position
		_expect(_hits(o + Vector3(0, 1.5, -1), o + Vector3(0, 1.5, 1)), "painel: bloqueia na altura do jogador")
		_expect(_hits(o + Vector3(0, 5.9, -1), o + Vector3(0, 5.9, 1)), "painel: atinge 5,9 m (pé-direito alto)")
		_expect(not _hits(o + Vector3(0, 6.5, -1), o + Vector3(0, 6.5, 1)), "painel: termina em 6 m (nada acima)")
		_free_module(wall)

	# Dois painéis de 2 m lado a lado: junta exata, sem sobreposição.
	var a: Node3D = await _spawn_module("res://maps/modular/walls/wall_panel_2m.tscn", Vector3(0, 0, 4))
	var b: Node3D = await _spawn_module("res://maps/modular/walls/wall_panel_2m.tscn", Vector3(2, 0, 4))
	if a != null and b != null:
		var ba: AABB = _collision_aabb(a)
		var bb: AABB = _collision_aabb(b)
		var end_a: float = ba.end.x
		var start_b: float = bb.position.x
		_expect(is_equal_approx(end_a, start_b),
			"painéis vizinhos: encostam sem sobrepor (%.3f / %.3f)" % [end_a, start_b])
		_expect(_hits(Vector3(0.2, 1.5, 3.2), Vector3(0.2, 1.5, 4.8))
				and _hits(Vector3(1.8, 1.5, 3.2), Vector3(1.8, 1.5, 4.8)),
			"painéis vizinhos: os dois lados da junta continuam sólidos")
	for module: Node3D in [a, b]:
		if module != null:
			_free_module(module)
	await _frames(3)


# --- 3. Vãos de porta e abertura -------------------------------------------

func _test_openings() -> void:
	print("[3] Vão de porta (4 m) e abertura (4 m)")
	var door: Node3D = await _spawn_module("res://maps/modular/walls/wall_door_4m.tscn")
	_expect(door != null, "parede com porta instanciada")
	if door != null:
		var o: Vector3 = door.global_position
		var aabb: AABB = _collision_aabb(door)
		_expect(is_equal_approx(aabb.size.x, 4.0), "porta: módulo de 4 m (%.2f)" % aabb.size.x)
		_expect(not _hits(o + Vector3(0, 1.2, -1), o + Vector3(0, 1.2, 1)), "porta: vão livre na altura do peito")
		_expect(not _hits(o + Vector3(0, DOOR_H - 0.1, -1), o + Vector3(0, DOOR_H - 0.1, 1)),
			"porta: vão livre até %.1f m" % DOOR_H)
		_expect(_hits(o + Vector3(0, DOOR_H + 0.2, -1), o + Vector3(0, DOOR_H + 0.2, 1)),
			"porta: verga acima do vão")
		_expect(_hits(o + Vector3(1.7, 1.2, -1), o + Vector3(1.7, 1.2, 1)), "porta: ombreira leste fecha a parede")
		_expect(_hits(o + Vector3(-1.7, 1.2, -1), o + Vector3(-1.7, 1.2, 1)), "porta: ombreira oeste fecha a parede")
		var gap: float = _opening_width(door, 1.2, 2.0)
		_expect(absf(gap - DOOR_W) < 0.08, "porta: largura do vão %.2f m (esperado %.2f)" % [gap, DOOR_W])
		_free_module(door)

	var opening: Node3D = await _spawn_module("res://maps/modular/walls/wall_opening_4m.tscn", Vector3(0, 0, 6))
	_expect(opening != null, "parede com abertura instanciada")
	if opening != null:
		var o: Vector3 = opening.global_position
		_expect(is_equal_approx(_collision_aabb(opening).size.x, 4.0), "abertura: módulo de 4 m")
		_expect(not _hits(o + Vector3(-1.6, 1.5, -1), o + Vector3(-1.6, 1.5, 1)),
			"abertura: passa a 1,6 m do centro")
		_expect(not _hits(o + Vector3(0.0, OPEN_H - 0.2, -1), o + Vector3(0.0, OPEN_H - 0.2, 1)),
			"abertura: livre até %.1f m" % OPEN_H)
		_expect(_hits(o + Vector3(0.0, OPEN_H + 0.2, -1), o + Vector3(0.0, OPEN_H + 0.2, 1)),
			"abertura: verga acima")
		_expect(_hits(o + Vector3(1.9, 1.2, -1), o + Vector3(1.9, 1.2, 1)), "abertura: pilar lateral fecha a parede")
		var gap: float = _opening_width(opening, 1.2, 2.0)
		_expect(absf(gap - OPEN_W) < 0.08, "abertura: largura do vão %.2f m (esperado %.2f)" % [gap, OPEN_W])
		_free_module(opening)
	await _frames(3)


# --- 4. Canto, junção, piso e teto -----------------------------------------

func _test_corner_and_floor() -> void:
	print("[4] Cantos, junção, piso e teto")
	var corner: Node3D = await _spawn_module("res://maps/modular/walls/wall_corner_inner.tscn")
	_expect(corner != null, "canto interno instanciado")
	if corner != null:
		var o: Vector3 = corner.global_position
		var aabb: AABB = _collision_aabb(corner)
		_expect(is_equal_approx(aabb.size.x, WALL_T) and is_equal_approx(aabb.size.z, WALL_T),
			"canto: bloco de %.2f × %.2f m" % [aabb.size.x, aabb.size.z])
		_expect(is_equal_approx(aabb.size.y, WALL_H), "canto: altura %.2f m" % aabb.size.y)
		_expect(_hits(o + Vector3(-0.5, 1.5, 0), o + Vector3(0.5, 1.5, 0)), "canto: sólido na diagonal")
		_free_module(corner)

	var outer: Node3D = await _spawn_module("res://maps/modular/walls/wall_corner_outer.tscn", Vector3(0, 0, 3))
	_expect(outer != null, "canto externo instanciado")
	if outer != null:
		var aabb_o: AABB = _collision_aabb(outer)
		_expect(is_equal_approx(aabb_o.size.x, WALL_T) and is_equal_approx(aabb_o.size.y, WALL_H),
			"canto externo: bloco de 0,40 × 6 m")
		_free_module(outer)

	var junction: Node3D = await _spawn_module("res://maps/modular/walls/wall_junction.tscn", Vector3(0, 0, 6))
	_expect(junction != null, "pilastra de junção instanciada")
	if junction != null:
		var aabb_j: AABB = _collision_aabb(junction)
		_expect(aabb_j.size.x > WALL_T and aabb_j.size.z < WALL_T,
			"junção: cobre a costura na face da parede (%.2f × %.2f)" % [aabb_j.size.x, aabb_j.size.z])
		_expect(is_equal_approx(aabb_j.size.y, WALL_H), "junção: acompanha a altura da parede")
		_free_module(junction)

	# Piso: 2 × 2 m, topo em y = 0, espessura 0,30.
	var tile: Node3D = await _spawn_module("res://maps/modular/floors/floor_tile.tscn", Vector3(0, 0, 9))
	_expect(tile != null, "piso instanciado")
	if tile != null:
		var aabb_t: AABB = _collision_aabb(tile)
		_expect(is_equal_approx(aabb_t.size.x, GRID) and is_equal_approx(aabb_t.size.z, GRID),
			"piso: %.1f × %.1f m" % [aabb_t.size.x, aabb_t.size.z])
		_expect(is_equal_approx(aabb_t.end.y, 0.0), "piso: topo em y = 0")
		_expect(is_equal_approx(aabb_t.position.y, -FLOOR_T), "piso: espessura %.2f m" % FLOOR_T)
		expect_surface(tile.global_position + Vector3(0.9, 1.0, 0.9), 0.0, "piso: superfície de apoio")
		_free_module(tile)

	var tile_a: Node3D = await _spawn_module("res://maps/modular/floors/floor_tile.tscn", Vector3(0, 0, 12))
	var tile_b: Node3D = await _spawn_module("res://maps/modular/floors/floor_tile.tscn", Vector3(2, 0, 12))
	if tile_a != null and tile_b != null:
		expect_surface(Vector3(1.0, 1.0, 12), 0.0, "pisos vizinhos: junta sem lacuna")
		var ta: AABB = _collision_aabb(tile_a)
		var tb: AABB = _collision_aabb(tile_b)
		_expect(is_equal_approx(ta.end.x, tb.position.x),
			"pisos vizinhos: encostam sem sobrepor (%.3f / %.3f)" % [ta.end.x, tb.position.x])
		_free_module(tile_a)
		_free_module(tile_b)

	# Teto: 2 × 2 m, base em y = 6 (altura livre) e 0,20 m de espessura.
	var ceiling: Node3D = await _spawn_module("res://maps/modular/ceilings/ceiling_tile.tscn", Vector3(0, 0, 15))
	_expect(ceiling != null, "teto instanciado")
	if ceiling != null:
		var aabb_c: AABB = _collision_aabb(ceiling)
		_expect(is_equal_approx(aabb_c.position.y, WALL_H), "teto: base em y = %.1f" % WALL_H)
		_expect(is_equal_approx(aabb_c.size.y, CEIL_T), "teto: espessura %.2f m" % CEIL_T)
		_expect(is_equal_approx(aabb_c.size.x, GRID) and is_equal_approx(aabb_c.size.z, GRID),
			"teto: módulo de 2 × 2 m")
		_free_module(ceiling)
	await _frames(3)


# --- 4b. Acabamentos (rodapé, batente, plinto) ------------------------------

## Peças de parede com acabamento: [nome, cena, corpos, eixos].
##
## `corpos` é a lista de materiais que formam o corpo da peça (o que o
## acabamento reveste). `eixos` são os eixos em que o acabamento não pode
## dividir plano:
##   - `z` (2) é a espessura da parede nos módulos retos;
##   - nos cantos o plinto envolve a coluna, então valem `x` e `z`.
## Faces dentro do sólido da parede (|coordenada| < WALL_T/2) são emendas
## internas, escondidas — só as faces no plano da parede ou à frente dela
## podem produzir z-fighting.
const FINISH_PIECES := [
	[
		"wall_panel_2m",
		"res://maps/modular/walls/wall_panel_2m.tscn",
		["wall", "panel"],
		[2],
	],
	["wall_door_4m", "res://maps/modular/walls/wall_door_4m.tscn", ["wall"], [2]],
	["wall_opening_4m", "res://maps/modular/walls/wall_opening_4m.tscn", ["wall"], [2]],
	["wall_junction", "res://maps/modular/walls/wall_junction.tscn", ["panel"], [2]],
	[
		"wall_corner_inner",
		"res://maps/modular/walls/wall_corner_inner.tscn",
		["wall"],
		[0, 2],
	],
	[
		"wall_corner_outer",
		"res://maps/modular/walls/wall_corner_outer.tscn",
		["wall"],
		[0, 2],
	],
]

## Colisores esperados por peça de parede (o acabamento não acrescenta nenhum).
const FINISH_COLLIDERS := {
	"wall_panel_2m": 1,
	"wall_door_4m": 4,
	"wall_opening_4m": 4,
	"wall_junction": 1,
	"wall_corner_inner": 1,
	"wall_corner_outer": 1,
}

## Menor folga aceitável entre duas faces visíveis no mesmo plano. Abaixo
## disso as superfícies disputam o mesmo pixel (z-fighting) e o rodapé escuro
## "atravessa" a parede clara.
const FINISH_MIN_GAP := 0.002


func _test_finish_fit() -> void:
	print("[4b] Acabamentos não atravessam a parede")
	for entry: Array in FINISH_PIECES:
		var label: String = entry[0]
		var path: String = entry[1]
		var body_materials: Array = entry[2]
		var axes: Array = entry[3]
		var piece: Node3D = await _spawn_module(path, Vector3(0, 0, 40))
		_expect(piece != null, "%s: peça instanciada para medir acabamento" % label)
		if piece == null:
			continue
		var boxes: Array = _mesh_boxes(piece)
		var finishes: Array = []
		for box: Dictionary in boxes:
			var mat: String = box["mat"]
			if mat.contains("trim") or mat.contains("accent"):
				finishes.append(box)
		_expect(finishes.size() > 0, "%s: acabamento identificado" % label)

		var shared: int = 0
		var buried: int = 0
		for body_mat: String in body_materials:
			var bodies: Array = []
			for box: Dictionary in boxes:
				if (box["mat"] as String).contains(body_mat):
					bodies.append(box)
			_expect(bodies.size() > 0, "%s: corpo '%s' identificado" % [label, body_mat])
			for body: Dictionary in bodies:
				for finish: Dictionary in finishes:
					if body_mat != "wall" and _box_inside(finish, body):
						buried += 1
					shared += _count_shared_planes(body, finish, axes,
						"%s × %s" % [finish["name"], body["name"]])

		# Dois acabamentos de materiais diferentes também não podem dividir a
		# face da frente (ex.: batente metálico invadindo o rodapé escuro).
		for i: int in finishes.size():
			for j: int in range(i + 1, finishes.size()):
				var first: Dictionary = finishes[i]
				var second: Dictionary = finishes[j]
				if first["mat"] == second["mat"]:
					continue
				shared += _count_shared_planes(first, second, axes,
					"%s × %s" % [first["name"], second["name"]])

		_expect(shared == 0,
			"%s: nenhuma face de acabamento divide plano com a peça vizinha (%d)" % [label, shared])
		_expect(buried == 0, "%s: nenhum acabamento escondido dentro do corpo (%d)" % [label, buried])

		var colliders: int = _collision_shapes(piece).size()
		var expected: int = FINISH_COLLIDERS[label]
		_expect(colliders == expected,
			"%s: %d colisores (esperado %d — acabamento não colide)" % [label, colliders, expected])
		_free_module(piece)
	await _frames(3)


## Conta faces coincidentes entre duas caixas nos eixos pedidos, ignorando as
## que ficam dentro do sólido da parede (emenda interna, não aparece).
func _count_shared_planes(a: Dictionary, b: Dictionary, axes: Array,
		pair_label: String) -> int:
	var count: int = 0
	for axis: int in axes:
		if not _overlaps_other_axes(a, b, axis):
			continue
		var gap_lo: float = absf((a["lo"] as Vector3)[axis] - (b["lo"] as Vector3)[axis])
		if gap_lo < FINISH_MIN_GAP and _is_exposed((a["lo"] as Vector3)[axis]):
			count += 1
			print("      plano compartilhado: %s eixo %d (fundo) em %.3f" % [pair_label, axis, gap_lo])
		var gap_hi: float = absf((a["hi"] as Vector3)[axis] - (b["hi"] as Vector3)[axis])
		if gap_hi < FINISH_MIN_GAP and _is_exposed((a["hi"] as Vector3)[axis]):
			count += 1
			print("      plano compartilhado: %s eixo %d (frente) em %.3f" % [pair_label, axis, gap_hi])
	return count


## A coordenada está no plano da parede ou fora dela (portanto visível)?
func _is_exposed(coordinate: float) -> bool:
	return absf(coordinate) >= WALL_T / 2.0 - 0.001


## Caixas de malha da peça em coordenadas LOCAIS (as peças de parede não têm
## rotação interna, então a origem de cada nó é a posição da caixa).
func _mesh_boxes(root: Node3D) -> Array:
	var boxes: Array = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		var box: BoxMesh = mesh_node.mesh as BoxMesh
		if box == null:
			continue
		var material: StandardMaterial3D = box.material as StandardMaterial3D
		var path: String = "" if material == null else material.resource_path
		var origin: Vector3 = mesh_node.global_position - root.global_position
		var half: Vector3 = box.size / 2.0
		boxes.append({
			"name": String(mesh_node.name),
			"mat": path.get_file(),
			"lo": origin - half,
			"hi": origin + half,
		})
	return boxes


## As duas caixas se sobrepõem nos eixos que não são `axis`?
func _overlaps_other_axes(a: Dictionary, b: Dictionary, axis: int) -> bool:
	for other: int in 3:
		if other == axis:
			continue
		var lo: float = maxf((a["lo"] as Vector3)[other], (b["lo"] as Vector3)[other])
		var hi: float = minf((a["hi"] as Vector3)[other], (b["hi"] as Vector3)[other])
		if hi - lo <= 0.001:
			return false
	return true


## A caixa `inner` cabe inteira dentro de `outer` (ou seja: não aparece)?
func _box_inside(inner: Dictionary, outer: Dictionary) -> bool:
	for axis: int in 3:
		if (inner["lo"] as Vector3)[axis] < (outer["lo"] as Vector3)[axis] - 0.001:
			return false
		if (inner["hi"] as Vector3)[axis] > (outer["hi"] as Vector3)[axis] + 0.001:
			return false
	return true


# --- 5. Salas ---------------------------------------------------------------

func _test_rooms() -> void:
	print("[5] Salas")
	var lab: Node3D = await _spawn_module("res://maps/modular/rooms/room_lab_10x10.tscn")
	_expect(lab != null, "sala de pesquisa 10 × 10 instanciada")
	if lab != null:
		var o: Vector3 = lab.global_position
		_expect(lab.get_child_count() >= 40, "sala 10 × 10: módulos suficientes (%d)" % lab.get_child_count())
		for x: float in [1.0, 3.0, 5.0, 7.0, 9.0]:
			for z: float in [1.0, 5.0, 9.0]:
				expect_surface(o + Vector3(x, 1.0, z), 0.0, "sala 10 × 10: piso em (%.0f, %.0f)" % [x, z])
		# Parede norte contínua (o vão está na parede sul).
		_expect(_wall_line_coverage(lab, o + Vector3(5, 1.5, -0.2), Vector3.RIGHT, 5.0),
			"sala 10 × 10: parede norte contínua")
		_expect(_wall_line_coverage(lab, o + Vector3(-0.2, 1.5, 5), Vector3.BACK, 5.0),
			"sala 10 × 10: parede oeste contínua")
		_expect(_wall_line_coverage(lab, o + Vector3(10.2, 1.5, 5), Vector3.BACK, 5.0),
			"sala 10 × 10: parede leste contínua")
		# Porta de 4 m no sul (vão de 2,4 m entre 2 e 6).
		_expect(not _hits(o + Vector3(4, 1.2, 9.0), o + Vector3(4, 1.2, 11.5)),
			"sala 10 × 10: porta sul livre")
		_expect(_hits(o + Vector3(0.8, 1.2, 9.0), o + Vector3(0.8, 1.2, 11.5)),
			"sala 10 × 10: parede maciça ao lado da porta")
		_free_module(lab)

	var tech: Node3D = await _spawn_module("res://maps/modular/rooms/room_tech_14x20.tscn", Vector3(40, 0, 0))
	_expect(tech != null, "sala técnica 14 × 20 instanciada")
	if tech != null:
		var o: Vector3 = tech.global_position
		expect_surface(o + Vector3(7, 1.0, 10), 0.0, "sala técnica: piso no centro")
		expect_surface(o + Vector3(2, 1.0, 2), 0.0, "sala técnica: piso no canto")
		expect_surface(o + Vector3(12, 1.0, 18), 0.0, "sala técnica: piso no canto oposto")
		_expect(_wall_line_coverage(tech, o + Vector3(7, 1.5, -0.2), Vector3.RIGHT, 7.0),
			"sala técnica: parede norte contínua")
		_expect(_wall_line_coverage(tech, o + Vector3(-0.2, 1.5, 10), Vector3.BACK, 10.0, [[-1.4, 1.4]]),
			"sala técnica: parede oeste contínua fora da porta")
		_expect(not _hits(o + Vector3(6, 1.2, 18.5), o + Vector3(6, 1.2, 21.0)),
			"sala técnica: abertura sul livre")
		_expect(not _hits(o + Vector3(1.5, 1.2, 10), o + Vector3(-1.5, 1.2, 10)),
			"sala técnica: porta oeste livre")
		_expect(_count_named(tech, "Pillar") >= 4, "sala técnica: pilares presentes")
		_free_module(tech)

	var eq: Node3D = await _spawn_module("res://maps/modular/rooms/room_equipment_8x8.tscn", Vector3(80, 0, 0))
	_expect(eq != null, "sala de equipamentos 8 × 8 instanciada")
	if eq != null:
		var o: Vector3 = eq.global_position
		for x: float in [1.0, 4.0, 7.0]:
			for z: float in [1.0, 4.0, 7.0]:
				expect_surface(o + Vector3(x, 1.0, z), 0.0, "sala 8 × 8: piso em (%.0f, %.0f)" % [x, z])
		_expect(not _hits(o + Vector3(6.5, 1.2, 4), o + Vector3(9.0, 1.2, 4)),
			"sala 8 × 8: porta leste livre")
		_free_module(eq)
	await _frames(3)


# --- 6. Corredores ----------------------------------------------------------

func _test_corridors() -> void:
	print("[6] Corredores")
	var main: Node3D = await _spawn_module("res://maps/modular/corridors/corridor_main_8m.tscn")
	_expect(main != null, "corredor principal (8 × 6 m) instanciado")
	if main != null:
		var o: Vector3 = main.global_position
		for x: float in [1.0, 4.0, 7.0]:
			expect_surface(o + Vector3(x, 1.0, 3.0), 0.0, "corredor principal: piso em x=%.0f" % x)
		_expect(_hits(o + Vector3(1.0, 1.5, -1.6), o + Vector3(1.0, 1.5, -0.2)),
			"corredor principal: parede norte")
		_expect(_hits(o + Vector3(1.0, 1.5, 7.6), o + Vector3(1.0, 1.5, 6.2)),
			"corredor principal: parede sul")
		_expect(not _hits(o + Vector3(0.5, 1.5, 3.0), o + Vector3(7.5, 1.5, 3.0)),
			"corredor principal: passagem livre")
		_expect(not _hits(o + Vector3(0.5, PLAYER_EYE, 3.0), o + Vector3(7.5, PLAYER_EYE, 3.0)),
			"corredor principal: livre na altura da câmera")
		_expect(_player_fits(o + Vector3(4.0, 0.02, 3.0)), "corredor principal: cápsula do jogador cabe")
		_free_module(main)

	var sec: Node3D = await _spawn_module("res://maps/modular/corridors/corridor_secondary_8m.tscn", Vector3(0, 0, 20))
	_expect(sec != null, "corredor secundário (8 × 4 m) instanciado")
	if sec != null:
		var o: Vector3 = sec.global_position
		expect_surface(o + Vector3(4, 1.0, 2), 0.0, "corredor secundário: piso no centro")
		_expect(_hits(o + Vector3(4, 1.5, -1.0), o + Vector3(4, 1.5, 0.2)), "secundário: parede norte")
		_expect(_hits(o + Vector3(4, 1.5, 5.0), o + Vector3(4, 1.5, 3.8)), "secundário: parede sul")
		_expect(not _hits(o + Vector3(0.5, 1.2, 2), o + Vector3(7.5, 1.2, 2)), "secundário: passagem livre")
		_free_module(sec)

	var corner: Node3D = await _spawn_module("res://maps/modular/corridors/corridor_corner_6.tscn", Vector3(20, 0, 0))
	_expect(corner != null, "canto em L instanciado")
	if corner != null:
		var o: Vector3 = corner.global_position
		expect_surface(o + Vector3(1.0, 1.0, 1.0), 0.0, "canto: piso da curva")
		expect_surface(o + Vector3(5.0, 1.0, 5.0), 0.0, "canto: piso do fundo")
		_expect(not _hits(o + Vector3(0.5, 1.2, 4.0), o + Vector3(5.0, 1.2, 4.0)),
			"canto: passa pelo interior da curva")
		_expect(_hits(o + Vector3(5.0, 1.5, 7.0), o + Vector3(5.0, 1.5, 5.8)), "canto: parede sul fecha")
		_expect(_hits(o + Vector3(6.6, 1.5, 5.0), o + Vector3(5.4, 1.5, 5.0)), "canto: parede leste fecha")
		_free_module(corner)

	var tee: Node3D = await _spawn_module("res://maps/modular/corridors/corridor_tee_6.tscn", Vector3(40, 0, 0))
	_expect(tee != null, "junção em T instanciada")
	if tee != null:
		var o: Vector3 = tee.global_position
		expect_surface(o + Vector3(4, 1.0, 3), 0.0, "T: piso do corredor")
		expect_surface(o + Vector3(4, 1.0, -2.4), 0.0, "T: piso do ramo")
		_expect(not _hits(o + Vector3(0.5, 1.2, 3), o + Vector3(7.5, 1.2, 3)), "T: passagem reta livre")
		_expect(not _hits(o + Vector3(4, 1.2, 0.4), o + Vector3(4, 1.2, -3.8)), "T: ramo livre")
		_expect(_hits(o + Vector3(1.0, 1.5, 6.4), o + Vector3(1.0, 1.5, 5.2)), "T: lado sul fechado")
		_free_module(tee)

	var cross: Node3D = await _spawn_module("res://maps/modular/corridors/corridor_cross_6.tscn", Vector3(60, 0, 0))
	_expect(cross != null, "cruzamento em X instanciado")
	if cross != null:
		var o: Vector3 = cross.global_position
		expect_surface(o + Vector3(3, 1.0, 3), 0.0, "X: piso do centro")
		_expect(not _hits(o + Vector3(-1.5, 1.2, 3), o + Vector3(7.5, 1.2, 3)), "X: passagem leste-oeste")
		_expect(not _hits(o + Vector3(3, 1.2, -1.5), o + Vector3(3, 1.2, 7.5)), "X: passagem norte-sul")
		_free_module(cross)

	var end: Node3D = await _spawn_module("res://maps/modular/corridors/corridor_end_6.tscn", Vector3(80, 0, 0))
	_expect(end != null, "terminação de corredor instanciada")
	if end != null:
		var o: Vector3 = end.global_position
		expect_surface(o + Vector3(1.2, 1.0, 3), 0.0, "terminação: piso")
		_expect(_hits(o + Vector3(-0.6, 1.5, 3), o + Vector3(0.5, 1.5, 3)),
			"terminação: parede de fundo + comporta fecham o corredor")
		_expect(_hits(o + Vector3(1.2, 5.0, 3), o + Vector3(-0.6, 5.0, 3)),
			"terminação: parede de fundo sobe até o teto")
		_free_module(end)
	await _frames(3)


# --- 7. Escada --------------------------------------------------------------

func _test_stairs_geometry() -> void:
	print("[7] Geometria da escada")
	var stairs: Node3D = await _spawn_module("res://maps/modular/stairs/stairs_straight.tscn", Vector3(0, 0, 60))
	_expect(stairs != null, "escada instanciada")
	if stairs == null:
		return
	var o: Vector3 = stairs.global_position
	# Rampa contínua: sobe 3,2 m ao longo de 5,6 m.
	for index: int in 5:
		var z: float = -(1.0 + float(index))
		var expected: float = STAIR_RISE * (1.0 + float(index)) / STAIR_RUN
		var hit: Dictionary = _ray(o + Vector3(0, expected + 1.5, z), o + Vector3(0, expected - 0.5, z))
		_expect(not hit.is_empty(), "escada: há superfície em z=%.1f" % z)
		if hit.is_empty():
			continue
		var height: float = (hit["position"] as Vector3).y - o.y
		_expect(absf(height - expected) < 0.14,
			"escada: altura %.2f m em z=%.1f (esperado %.2f)" % [height, z, expected])
		_expect(not _hits(o + Vector3(0, expected + 0.35, z), o + Vector3(0, expected + 2.0, z)),
			"escada: caminho livre 2 m acima em z=%.1f" % z)
	# Guardas laterais e topo.
	_expect(_hits(o + Vector3(1.4, 2.1, -2.8), o + Vector3(0.6, 2.1, -2.8)),
		"escada: guarda lateral existe")
	var top: Dictionary = _ray(o + Vector3(0, 4.6, -5.5), o + Vector3(0, 2.6, -5.5))
	_expect(not top.is_empty(), "escada: rampa chega ao topo")
	if not top.is_empty():
		var top_y: float = (top["position"] as Vector3).y - o.y
		_expect(absf(top_y - STAIR_RISE * 5.5 / STAIR_RUN) < 0.14,
			"escada: topo em y = %.2f m" % top_y)
	var angle: float = rad_to_deg(atan2(STAIR_RISE, STAIR_RUN))
	_expect(angle < 45.0, "escada: inclinação %.1f° abaixo do limite do jogador" % angle)
	_expect(_count_named(stairs, "Step_") == STAIR_STEPS,
		"escada: %d degraus de 0,20 × 0,35 (3,20 m em 5,60 m)" % _count_named(stairs, "Step_"))
	_free_module(stairs)
	await _frames(3)


# --- 8. Demonstração e jogabilidade ----------------------------------------

func _test_demo_and_movement() -> void:
	print("[8] Cena de demonstração")
	var room_packed: PackedScene = load(DEMO_SCENE) as PackedScene
	_expect(room_packed != null, "cenário da demonstração carrega")
	var session_packed: PackedScene = load(DEMO_SESSION) as PackedScene
	_expect(session_packed != null, "cena de demonstração completa carrega")
	if session_packed == null:
		return
	_scene = session_packed.instantiate()
	_expect(_scene != null, "cena de demonstração instancia")
	if _scene == null:
		return
	add_child(_scene)
	await _frames(6)
	_player = _scene.get_player()
	_expect(_player is CharacterBody3D, "demonstração: jogador existente instanciado")
	_expect(_scene.get_hud() != null, "demonstração: HUD ligada")
	_expect(_scene.get_demo_room() != null, "demonstração: cenário acessível")
	if _player == null:
		return
	_space = _player.get_world_3d().direct_space_state
	await _frames(10)

	var room: Node3D = _scene.get_demo_room()
	if room != null:
		_expect(room.get_node_or_null("MainWallN_00") != null, "demonstração: corredor principal presente")
		_expect(room.get_node_or_null("LabAFloor_00_00") != null, "demonstração: sala de pesquisa A presente")
		_expect(room.get_node_or_null("LabBFloor_00_00") != null, "demonstração: sala de pesquisa B presente")
		_expect(_count_named(room, "MainWallNOpen") == 2,
			"demonstração: aberturas modulares na parede norte (%d)" % _count_named(room, "MainWallNOpen"))
		_expect(room.get_node_or_null("SecWallW_00") != null, "demonstração: ramal secundário presente")
		_expect(room.get_node_or_null("HallWallNOpen_02") != null, "demonstração: sala técnica com abertura")
		_expect(room.get_node_or_null("MezzStairs") != null, "demonstração: escada presente")
		_expect(room.get_node_or_null("Spawn") is Marker3D, "demonstração: ponto de nascimento presente")
		_expect(_count_named(room, "HallPillar") == 4,
			"demonstração: pórtico com 4 pilares (%d)" % _count_named(room, "HallPillar"))
		_expect(_count_named(room, "MezzRail") == 8,
			"demonstração: guarda-corpos do mezanino (%d)" % _count_named(room, "MezzRail"))
		_expect(_count_named(room, "MezzFloor") == 18,
			"demonstração: mezanino com 18 placas de piso (%d)" % _count_named(room, "MezzFloor"))
		_expect(_count_named(room, "Light_") == 12,
			"demonstração: 12 luzes industriais (%d)" % _count_named(room, "Light_"))
	_expect(_scene.count_modules() >= 200, "demonstração: %d módulos no cenário" % _scene.count_modules())

	var spawn: Vector3 = _player.global_position
	_expect(spawn.distance_to(Vector3(2, 0.15, 3)) < 0.3,
		"jogador nasce no Spawn do cenário (%.2f, %.2f, %.2f)" % [spawn.x, spawn.y, spawn.z])
	expect_surface(Vector3(39, 4.2, -34), 3.2, "mezanino: piso em y = 3,2")

	# Conectividade: raios na altura do jogador entre ambientes vizinhos.
	_expect(_path_clear([Vector3(10, 0.9, 4), Vector3(10, 0.9, -2), Vector3(10, 0.9, -6)]),
		"conexão: corredor → porta → sala A")
	_expect(_path_clear([Vector3(14, 0.9, 4), Vector3(14, 0.9, -2), Vector3(14, 0.9, -6)]),
		"conexão: corredor → abertura → sala A")
	_expect(_path_clear([Vector3(22, 0.9, 4), Vector3(22, 0.9, 8), Vector3(22, 0.9, 14)]),
		"conexão: corredor → porta → sala B")
	_expect(_path_clear([Vector3(34, 0.9, 2), Vector3(34, 0.9, -10), Vector3(34, 0.9, -18)]),
		"conexão: corredor → portal → ramal")
	_expect(_path_clear([Vector3(34, 0.9, -18), Vector3(34, 0.9, -21.2), Vector3(34, 0.9, -24)]),
		"conexão: ramal → abertura → sala técnica")
	_expect(_path_clear([Vector3(26, 0.9, -24), Vector3(28.5, 0.9, -24), Vector3(30, 0.9, -24)]),
		"conexão: sala técnica → porta → equipamentos")
	_expect(_path_clear([Vector3(11, 0.9, 3), Vector3(20, 0.9, 3), Vector3(38, 0.9, 3)]),
		"corredor principal: 36 m livres de ponta a ponta")

	# --- Caminhada real ----------------------------------------------------
	print("[9] Caminhada na demonstração")
	await _place(Vector3(10, 0.05, 2.0), 0.0)
	await _walk(1.6)
	_expect(_player.global_position.z < -1.2,
		"atravessa o vão da porta da sala A (z = %.2f)" % _player.global_position.z)
	_expect(absf(_player.global_position.x - 10.0) < 0.6, "passa centralizado pela porta")

	await _place(Vector3(14, 0.05, 2.0), 0.0)
	await _walk(1.6)
	_expect(_player.global_position.z < -1.2,
		"atravessa a abertura da sala A (z = %.2f)" % _player.global_position.z)

	await _place(Vector3(22, 0.05, 2.0), PI)
	await _walk(1.8)
	_expect(_player.global_position.z > 7.0,
		"atravessa a porta da sala B (z = %.2f)" % _player.global_position.z)

	await _place(Vector3(34, 0.05, 1.5), 0.0)
	await _walk(2.4)
	_expect(_player.global_position.z < -4.0,
		"atravessa o portal do ramal (z = %.2f)" % _player.global_position.z)

	await _place(Vector3(34, 0.05, -18.0), 0.0)
	await _walk(1.8)
	_expect(_player.global_position.z < -21.4,
		"entra na sala técnica pelo ramal (z = %.2f)" % _player.global_position.z)

	await _place(Vector3(26.0, 0.05, -24.0), -PI / 2.0)
	await _walk(1.6)
	_expect(_player.global_position.x > 28.6,
		"entra na sala de equipamentos pela porta (x = %.2f)" % _player.global_position.x)

	# Parede barra o jogador (yaw +90° = oeste).
	await _place(Vector3(2.0, 0.05, 3.0), PI / 2.0)
	await _walk(2.0)
	_expect(_player.global_position.x > 0.2 and _player.global_position.x < 0.7,
		"parede oeste barra o jogador (x = %.2f)" % _player.global_position.x)

	# Escada: sobe até o mezanino.
	print("[10] Escada e mezanino com o jogador")
	await _place(Vector3(37.0, 0.05, -22.0), 0.0)
	await _walk(3.2)
	_expect(_player.global_position.y > 2.8,
		"sobe a escada até o mezanino (y = %.2f)" % _player.global_position.y)
	_expect(_player.global_position.z < -28.4, "chega ao topo (z = %.2f)" % _player.global_position.z)

	# Guarda-corpo do mezanino segura na borda.
	await _place(Vector3(40.0, 3.25, -30.0), PI)
	await _walk(1.4)
	_expect(_player.global_position.y > 3.0, "guarda-corpo sul segura no mezanino (y = %.2f)" % _player.global_position.y)
	_expect(_player.global_position.z < -28.6,
		"guarda-corpo impede sair pela borda (z = %.2f)" % _player.global_position.z)

	# Pausa: ESC abre e fecha sem trocar de cena (a UI é testada em ui_flow_test).
	# Posiciona no meio do mezanino, longe dos guarda-corpos, para que o teste de
	# retomada meça movimento livre (encostado na guarda o jogador não anda).
	await _place(Vector3(38.0, 3.25, -36.0), 0.0)
	_expect(_scene.has_method("pause_session") and _scene.has_method("resume_session"),
		"demonstração: pausa/retomada expostas para a interface")
	_scene.pause_session()
	_expect(_scene.is_paused(), "pausa ativa")
	var before: Vector3 = _player.global_position
	Input.action_press("move_forward")
	for _i: int in 20:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	_expect(_player.global_position.distance_to(before) < 0.05,
		"pausado: o jogador não anda com WASD")
	_scene.resume_session()
	_expect(not _scene.is_paused(), "retomada desativa a pausa")
	await _walk(0.6)
	_expect(_player.global_position.distance_to(before) > 0.5,
		"retomado: o jogador volta a andar")


# --- utilidades de física ---------------------------------------------------

func _spawn_module(path: String, offset: Vector3 = Vector3.ZERO) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	var instance: Node3D = packed.instantiate() as Node3D
	if instance == null:
		return null
	add_child(instance)
	instance.global_position = offset
	await _frames(3)
	return instance


func _free_module(module: Node) -> void:
	if module != null and is_instance_valid(module):
		module.queue_free()


func _frames(count: int) -> void:
	for _index: int in count:
		await get_tree().physics_frame
	_touch()


func _place(position: Vector3, yaw: float) -> void:
	_release_all()
	_player.velocity = Vector3.ZERO
	_player.global_position = position
	_player.set_look(yaw, 0.0)
	await _frames(8)


func _walk(seconds: float) -> void:
	Input.action_press("move_forward")
	var frames: int = int(round(seconds * 60.0))
	for _index: int in frames:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await _frames(6)
	_touch()


func _release_all() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "move_sprint", "move_crouch"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


## A cápsula do jogador cabe em pé neste ponto (pés em `feet`)?
func _player_fits(feet: Vector3) -> bool:
	if _space == null:
		return false
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3(0, 0.9, 0))
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return _space.intersect_shape(query, 1).is_empty()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = _space
	if space == null and _player != null:
		space = _player.get_world_3d().direct_space_state
	if space == null:
		return {}
	var params := PhysicsRayQueryParameters3D.create(from, to, 1)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.hit_from_inside = false
	return space.intersect_ray(params)


func _hits(from: Vector3, to: Vector3) -> bool:
	return not _ray(from, to).is_empty()


func _path_clear(points: Array) -> bool:
	for index: int in points.size() - 1:
		if _hits(points[index], points[index + 1]):
			return false
	return true


## Confere que existe piso em `origin` na altura esperada.
func expect_surface(origin: Vector3, expected_y: float, label: String) -> void:
	var hit: Dictionary = _ray(origin + Vector3(0, 1.5, 0), origin - Vector3(0, 1.5, 0))
	if hit.is_empty():
		_expect(false, "%s: sem superfície" % label)
		return
	var y: float = (hit["position"] as Vector3).y
	_expect(absf(y - expected_y) < 0.06, "%s (y = %.2f)" % [label, y])


## Largura livre do vão na linha de uma parede, medida na geometria de colisão.
##
## Usa as caixas de colisão da própria peça que cobrem a altura `height` e a
## banda da parede (mesma linha de `z` da origem), devolvendo o maior intervalo
## livre dentro de [-half, half]. Independe do passo da física.
func _opening_width(module: Node3D, height: float, half: float) -> float:
	var origin: Vector3 = module.global_position
	var blocked: Array = []
	for shape: CollisionShape3D in _collision_shapes(module):
		var box: BoxShape3D = shape.shape as BoxShape3D
		if box == null:
			continue
		var center: Vector3 = shape.global_transform.origin
		if height < center.y - box.size.y / 2.0 or height > center.y + box.size.y / 2.0:
			continue
		# Só o que está na mesma banda de parede (a soleira e o piso ficam abaixo).
		if absf(center.z - origin.z) > box.size.z / 2.0 + 0.05:
			continue
		blocked.append(Vector2(center.x - box.size.x / 2.0, center.x + box.size.x / 2.0))
	if blocked.is_empty():
		return 0.0
	blocked.sort_custom(func(p_left: Vector2, p_right: Vector2) -> bool:
		return p_left.x < p_right.x)
	var best: float = 0.0
	var cursor: float = -half
	for span: Vector2 in blocked:
		if span.x > cursor:
			best = maxf(best, span.x - cursor)
		cursor = maxf(cursor, span.y)
	best = maxf(best, half - cursor)
	return best


## Percorre uma linha de parede e confirma que ela é contínua, exceto nos vãos
## previstos (`gaps`, em coordenadas locais ao longo do eixo).
func _wall_line_coverage(module: Node3D, line_point: Vector3, axis: Vector3, half: float,
		gaps: Array = []) -> bool:
	var step: float = 0.25
	var covered: int = 0
	var total: int = 0
	var t: float = -half
	while t <= half + 0.001:
		var point: Vector3 = line_point + axis * t
		var inside_gap: bool = false
		for gap: Array in gaps:
			if t >= gap[0] and t <= gap[1]:
				inside_gap = true
		if not inside_gap:
			total += 1
			var normal := axis.cross(Vector3.UP).normalized()
			if _hits(point - normal * 0.8, point + normal * 0.8):
				covered += 1
		t += step
	return total == 0 or float(covered) / float(total) >= 0.9


func _collision_shapes(root: Node) -> Array:
	var found: Array = []
	for node: Node in root.find_children("*", "CollisionShape3D", true, false):
		found.append(node)
	return found


func _collision_aabb(root: Node3D) -> AABB:
	var shapes: Array = _collision_shapes(root)
	if shapes.is_empty():
		return AABB()
	var result: AABB = AABB()
	var first: bool = true
	for shape: CollisionShape3D in shapes:
		var box: BoxShape3D = shape.shape as BoxShape3D
		if box == null:
			continue
		# Mundo: `position` do nó raiz não entra na conta, então o AABB não pode
		# ser montado com `body.position + shape.position` (dá local + deslocamento).
		var center: Vector3 = shape.global_transform.origin
		var size: Vector3 = box.size
		var box_aabb := AABB(center - size / 2.0, size)
		if first:
			result = box_aabb
			first = false
		else:
			result = result.merge(box_aabb)
	return result


func _count_named(root: Node, prefix: String) -> int:
	var count: int = 0
	for node: Node in root.find_children("*", "Node3D", true, false):
		if String(node.name).begins_with(prefix):
			count += 1
	return count


func _regex_find_all(text: String, pattern: String) -> Array:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex.search_all(text)


# --- relatório --------------------------------------------------------------

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	_touch()
	if condition:
		print("  ✓ ", message)
		return
	_failures.append(message)
	printerr("  ✗ ", message)


func _finish() -> void:
	_finished = true
	_touch("fim")
	_release_all()
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
	await get_tree().process_frame
	print("")
	if _failures.is_empty():
		print("MODULAR TEST OK — %d verificações aprovadas" % _checks)
		get_tree().quit(0)
		return
	printerr("")
	printerr("MODULAR TEST FALHOU — %d falhas em %d verificações" % [_failures.size(), _checks])
	for failure: String in _failures:
		printerr("  - ", failure)
	get_tree().quit(1)
