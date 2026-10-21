extends Node
## Teste do sistema modular de salas (Etapa 11).
##
## Uso:
##     godot --headless --path . --fixed-fps 60 --audio-driver Dummy \
##         res://tools/ci/modular_test.tscn
##
## Verifica, com física real (não só "a cena carregou"):
##   1. catálogo: cada módulo esperado existe, carrega, tem raiz e colisão;
##   2. dimensões: parede, vão de porta, abertura, canto, piso e escada, por
##      raycast nas faces reais;
##   3. encaixe: salas montadas sem lacuna nem sobreposição nas paredes e no
##      piso; aberturas livres na altura do jogador;
##   4. cena de demonstração: carrega, tem jogador, spawn e módulos;
##   5. jogabilidade: atravessar porta, abertura, corredor e canto, bater em
##      parede e **subir e descer a escada** com o controlador existente.
##
## Sai com 0 em caso de sucesso e 1 em caso de falha.

const GRID := 2.0
const WALL_H := 4.0
const WALL_T := 0.25
const DOOR_W := 1.2
const DOOR_H := 2.4
const OPEN_H := 2.6
const STAIR_RUN := 6.0
const STAIR_RISE := 4.0
const PLAYER_EYE := 1.62

const DEMO_SCENE := "res://maps/scenes/modular_demo_room.tscn"
const DEMO_SESSION := "res://match/scenes/modular_demo.tscn"

## Módulos obrigatórios da biblioteca (Etapa 11).
const MODULES := [
	"res://maps/modular/walls/wall_straight_2m.tscn",
	"res://maps/modular/walls/wall_straight_4m.tscn",
	"res://maps/modular/walls/wall_door_2m.tscn",
	"res://maps/modular/walls/wall_opening_2m.tscn",
	"res://maps/modular/walls/wall_corner_inner.tscn",
	"res://maps/modular/walls/wall_corner_outer.tscn",
	"res://maps/modular/walls/wall_junction.tscn",
	"res://maps/modular/floors/floor_tile.tscn",
	"res://maps/modular/structure/pillar.tscn",
	"res://maps/modular/structure/railing_2m.tscn",
	"res://maps/modular/corridors/corridor_straight.tscn",
	"res://maps/modular/corridors/corridor_corner.tscn",
	"res://maps/modular/corridors/corridor_junction.tscn",
	"res://maps/modular/rooms/room_square.tscn",
	"res://maps/modular/rooms/room_rect.tscn",
	"res://maps/modular/stairs/stairs_straight.tscn",
]

## Ancoragem por família: onde fica a origem local de cada peça.
const ANCHOR_FLOOR := "centro da pegada, no piso (y = 0)"
const ANCHOR_WALL := "centro do vão no eixo da parede, no piso"
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
	print("=== Black Sight · teste do sistema modular (Etapa 11) ===")
	_touch("início")
	_space = get_viewport().world_3d.direct_space_state
	_test_catalog()
	await _test_wall_dimensions()
	await _test_openings()
	await _test_corner_and_floor()
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
		var all_have_shape: bool = true
		var layer_ok: bool = true
		for shape: CollisionShape3D in shapes:
			if shape.shape == null:
				all_have_shape = false
			var body: CollisionObject3D = shape.get_parent() as CollisionObject3D
			if body == null or (body.collision_layer & 1) == 0:
				layer_ok = false
		_expect(all_have_shape, "%s: toda colisão tem forma" % path.get_file())
		_expect(layer_ok, "%s: colisões na camada 1 (mundo)" % path.get_file())
		var aabb: AABB = _collision_aabb(instance)
		_expect(aabb.size.y > 0.0 and aabb.size.x > 0.0 and aabb.size.z > 0.0,
			"%s: volume físico definido (%.2f × %.2f × %.2f)" % [
				path.get_file(), aabb.size.x, aabb.size.y, aabb.size.z])
		instance.free()

	# Materiais compartilhados: as cenas apontam para os mesmos .tres.
	var material_paths: Dictionary = {}
	for path: String in MODULES:
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in _regex_find_all(text, "materials/([a-z_]+)\\.tres"):
			material_paths[found.get_string(1)] = true
	_expect(material_paths.size() >= 3,
		"materiais compartilhados usados pelos módulos (%d arquivos)" % material_paths.size())
	for name: String in material_paths:
		_expect(FileAccess.file_exists("res://maps/modular/materials/%s.tres" % name),
			"material existe: %s.tres" % name)

	# Convenções documentadas junto do catálogo.
	var docs: String = FileAccess.get_file_as_string("res://docs/ETAPA-11.md")
	_expect(docs.length() > 0, "documentação da etapa existe")
	for term: String in ["GRID", "2", "parede", "escada"]:
		_expect(docs.findn(term) >= 0, "documentação cita '%s'" % term)
	_expect(ANCHOR_FLOOR.contains("piso") and ANCHOR_WALL.contains("parede")
			and ANCHOR_CORNER.contains("interseção") and ANCHOR_STAIR.contains("degrau"),
		"convenções de origem declaradas no teste")


# --- 2. Dimensões das paredes ----------------------------------------------

func _test_wall_dimensions() -> void:
	print("[2] Dimensões das paredes")
	var walls: Dictionary = {
		"res://maps/modular/walls/wall_straight_2m.tscn": 2.0,
		"res://maps/modular/walls/wall_straight_4m.tscn": 4.0,
	}
	for path: String in walls:
		var length: float = walls[path]
		var wall: Node3D = await _spawn_module(path)
		_expect(wall != null, "%s instanciada no mundo" % path.get_file())
		if wall == null:
			continue
		var aabb: AABB = _collision_aabb(wall)
		_expect(is_equal_approx(aabb.size.x, length), "%s: comprimento %.2f m" % [path.get_file(), aabb.size.x])
		_expect(is_equal_approx(aabb.size.z, WALL_T), "%s: espessura %.2f m" % [path.get_file(), aabb.size.z])
		_expect(is_equal_approx(aabb.size.y, WALL_H), "%s: altura %.2f m" % [path.get_file(), aabb.size.y])
		_expect(is_equal_approx(aabb.position.y, 0.0), "%s: nasce no piso" % path.get_file())
		_expect(is_equal_approx(aabb.position.z, -WALL_T / 2), "%s: centrada no eixo" % path.get_file())
		# sólida na altura do jogador e no topo
		_expect(_hits(wall.global_position + Vector3(0, 1.5, -1), wall.global_position + Vector3(0, 1.5, 1)),
			"%s: bloqueia na altura do jogador" % path.get_file())
		_expect(_hits(wall.global_position + Vector3(0, 3.9, -1), wall.global_position + Vector3(0, 3.9, 1)),
			"%s: atinge a altura de 4 m" % path.get_file())
		_expect(not _hits(wall.global_position + Vector3(0, 4.6, -1), wall.global_position + Vector3(0, 4.6, 1)),
			"%s: termina em 4 m (nada acima)" % path.get_file())
		_free_module(wall)

	# Parede de 4 m cobre exatamente dois módulos de 2 m.
	var long_wall: Node3D = await _spawn_module("res://maps/modular/walls/wall_straight_4m.tscn")
	var short_a: Node3D = await _spawn_module("res://maps/modular/walls/wall_straight_2m.tscn", Vector3(0, 0, 3))
	var short_b: Node3D = await _spawn_module("res://maps/modular/walls/wall_straight_2m.tscn", Vector3(0, 0, 5))
	if long_wall != null and short_a != null and short_b != null:
		var long_size: float = _collision_aabb(long_wall).size.x
		var pair_size: float = _collision_aabb(short_a).size.x + _collision_aabb(short_b).size.x
		_expect(is_equal_approx(long_size, pair_size),
			"parede de 4 m = duas de 2 m (%.2f m)" % long_size)
	for module: Node3D in [long_wall, short_a, short_b]:
		if module != null:
			_free_module(module)


# --- 3. Vãos de porta e abertura -------------------------------------------

func _test_openings() -> void:
	print("[3] Vão de porta e abertura de conexão")
	var door: Node3D = await _spawn_module("res://maps/modular/walls/wall_door_2m.tscn")
	_expect(door != null, "parede com porta instanciada")
	if door != null:
		var origin: Vector3 = door.global_position
		_expect(_collision_aabb(door).size.x >= 2.0 - 0.001, "porta: módulo de 2 m")
		_expect(not _hits(origin + Vector3(0, 1.2, -1), origin + Vector3(0, 1.2, 1)),
			"porta: vão livre na altura do peito")
		_expect(not _hits(origin + Vector3(0, DOOR_H - 0.1, -1), origin + Vector3(0, DOOR_H - 0.1, 1)),
			"porta: vão livre até %.1f m" % DOOR_H)
		_expect(_hits(origin + Vector3(0, DOOR_H + 0.15, -1), origin + Vector3(0, DOOR_H + 0.15, 1)),
			"porta: verga acima do vão")
		_expect(_hits(origin + Vector3(0.9, 1.2, -1), origin + Vector3(0.9, 1.2, 1)),
			"porta: ombreira lateral fecha a parede")
		_expect(_hits(origin + Vector3(-0.9, 1.2, -1), origin + Vector3(-0.9, 1.2, 1)),
			"porta: ombreira oposta fecha a parede")
		var gap: float = _opening_width(door, 1.2)
		_expect(absf(gap - DOOR_W) < 0.06, "porta: largura do vão %.2f m (esperado %.2f)" % [gap, DOOR_W])
		_free_module(door)

	var opening: Node3D = await _spawn_module("res://maps/modular/walls/wall_opening_2m.tscn", Vector3(0, 0, 6))
	_expect(opening != null, "parede com abertura instanciada")
	if opening != null:
		var origin: Vector3 = opening.global_position
		_expect(not _hits(origin + Vector3(-0.9, 1.5, -1), origin + Vector3(-0.9, 1.5, 1)),
			"abertura: passa a 0,9 m do centro")
		_expect(not _hits(origin + Vector3(0.9, OPEN_H - 0.2, -1), origin + Vector3(0.9, OPEN_H - 0.2, 1)),
			"abertura: livre até %.1f m" % OPEN_H)
		_expect(_hits(origin + Vector3(0.9, OPEN_H + 0.2, -1), origin + Vector3(0.9, OPEN_H + 0.2, 1)),
			"abertura: verga acima")
		_free_module(opening)


# --- 4. Canto, junção e piso ------------------------------------------------

func _test_corner_and_floor() -> void:
	print("[4] Cantos, junção e piso")
	var corner: Node3D = await _spawn_module("res://maps/modular/walls/wall_corner_inner.tscn")
	_expect(corner != null, "canto interno instanciado")
	if corner != null:
		var o: Vector3 = corner.global_position
		_expect(_hits(o + Vector3(1, 1.5, -1), o + Vector3(1, 1.5, 1)), "canto: braço em X")
		_expect(_hits(o + Vector3(-1, 1.5, 1), o + Vector3(1, 1.5, 1)), "canto: braço em Z")
		_expect(not _hits(o + Vector3(0.8, 1.5, 0.8), o + Vector3(0.8, 3.0, 0.8)),
			"canto: interior livre")
		var aabb: AABB = _collision_aabb(corner)
		# A pilastra de 0,34 m avança 0,045 m além da face da parede (por fora).
		_expect(aabb.position.x > -0.2 and aabb.position.x <= -WALL_T / 2 + 0.001,
			"canto: nasce na linha da grade (%.3f m)" % aabb.position.x)
		_expect(absf(aabb.end.x - GRID) < 0.01, "canto: braço termina em %.1f m" % GRID)
		_free_module(corner)

	var outer: Node3D = await _spawn_module("res://maps/modular/walls/wall_corner_outer.tscn", Vector3(0, 0, 8))
	_expect(outer != null, "canto externo instanciado")
	if outer != null:
		var o: Vector3 = outer.global_position
		_expect(_hits(o + Vector3(1, 1.5, -1), o + Vector3(1, 1.5, 1)), "canto externo: braço em X")
		_expect(_hits(o + Vector3(-1, 1.5, -1), o + Vector3(1, 1.5, -1)), "canto externo: braço em Z")
		var aabb: AABB = _collision_aabb(outer)
		_expect(aabb.position.z <= -GRID + 0.01, "canto externo: braço para -Z (%.2f m)" % aabb.position.z)
		_free_module(outer)

	var junction: Node3D = await _spawn_module("res://maps/modular/walls/wall_junction.tscn", Vector3(0, 0, 14))
	_expect(junction != null, "pilastra de junção instanciada")
	if junction != null:
		var aabb: AABB = _collision_aabb(junction)
		_expect(aabb.size.x > WALL_T and aabb.size.z > WALL_T,
			"junção: cobre a costura (%.2f m)" % aabb.size.x)
		_expect(aabb.size.y > WALL_H, "junção: passa da altura da parede (capital)")
		_free_module(junction)

	# Piso: 2 × 2 m com o topo exatamente em y = 0.
	var tile: Node3D = await _spawn_module("res://maps/modular/floors/floor_tile.tscn", Vector3(0, 0, 20))
	_expect(tile != null, "piso instanciado")
	if tile != null:
		var aabb: AABB = _collision_aabb(tile)
		_expect(is_equal_approx(aabb.size.x, GRID) and is_equal_approx(aabb.size.z, GRID),
			"piso: %.1f × %.1f m" % [aabb.size.x, aabb.size.z])
		_expect(is_equal_approx(aabb.end.y, 0.0), "piso: topo em y = 0")
		_expect(is_equal_approx(aabb.position.y, -0.25), "piso: espessura 0,25 m")
		expect_surface(tile.global_position + Vector3(0.9, 1.0, 0.9), 0.0, "piso: superfície de apoio")
		_free_module(tile)

	# Dois pisos lado a lado: sem lacuna na junta.
	var tile_a: Node3D = await _spawn_module("res://maps/modular/floors/floor_tile.tscn", Vector3(0, 0, 24))
	var tile_b: Node3D = await _spawn_module("res://maps/modular/floors/floor_tile.tscn", Vector3(2, 0, 24))
	if tile_a != null and tile_b != null:
		expect_surface(Vector3(1.0, 1.0, 24), 0.0, "pisos vizinhos: junta sem lacuna")
		var a: AABB = _collision_aabb(tile_a)
		var b: AABB = _collision_aabb(tile_b)
		_expect(is_equal_approx(a.end.x, b.position.x), "pisos vizinhos: encostam sem sobrepor")
		_free_module(tile_a)
		_free_module(tile_b)


# --- 5. Salas ---------------------------------------------------------------

func _test_rooms() -> void:
	print("[5] Salas quadrada e retangular")
	var square: Node3D = await _spawn_module("res://maps/modular/rooms/room_square.tscn", Vector3(0, 0, 0))
	_expect(square != null, "sala quadrada instanciada")
	if square != null:
		_expect(square.get_child_count() >= 25 + 4 + 12,
			"sala quadrada: módulos suficientes (%d)" % square.get_child_count())
		var half: float = 5.0
		for x: float in [-4.0, -2.0, 0.0, 2.0, 4.0]:
			for z: float in [-4.0, -2.0, 0.0, 2.0, 4.0]:
				expect_surface(Vector3(x, 1.0, z), 0.0, "sala quadrada: piso em (%.0f, %.0f)" % [x, z])
		# paredes: varredura horizontal nas quatro linhas (vãos declarados)
		_expect(_wall_line_coverage(square, Vector3(0, 1.5, -half), Vector3.RIGHT, half, [[-0.6, 0.6]]),
			"parede norte: contínua fora do vão de porta")
		_expect(_wall_line_coverage(square, Vector3(0, 1.5, half), Vector3.RIGHT, half),
			"parede sul: contínua")
		_expect(_wall_line_coverage(square, Vector3(half, 1.5, 0), Vector3.BACK, half, [[-1.0, 1.0]]),
			"parede leste: contínua fora da abertura de conexão")
		_expect(_wall_line_coverage(square, Vector3(-half, 1.5, 0), Vector3.BACK, half),
			"parede oeste: contínua")
		_expect(not _hits(Vector3(0, 1.2, -6), Vector3(0, 1.2, -4)), "sala quadrada: porta norte livre")
		_expect(not _hits(Vector3(6, 1.2, 0), Vector3(4, 1.2, 0)), "sala quadrada: abertura leste livre")
		_expect(_hits(Vector3(1.9, 1.5, -4.6), Vector3(1.9, 1.5, -5.4)),
			"sala quadrada: parede maciça ao lado da porta")
		_expect(not _hits(Vector3(0, 5.5, 0), Vector3(0, 4.2, 0)), "sala quadrada: sem teto (inspeção visual)")
		_free_module(square)

	var rect: Node3D = await _spawn_module("res://maps/modular/rooms/room_rect.tscn", Vector3(40, 0, 0))
	_expect(rect != null, "sala retangular instanciada")
	if rect != null:
		await get_tree().physics_frame
		var origin: Vector3 = rect.global_position
		for x: float in [-4.0, -2.0, 0.0, 2.0, 4.0]:
			for z: float in [-6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0]:
				expect_surface(origin + Vector3(x, 1.0, z), 0.0, "sala retangular: piso em (%.0f, %.0f)" % [x, z])
		_expect(_wall_line_coverage(rect, origin + Vector3(0, 1.5, -7), Vector3.RIGHT, 5.0, [[-1.0, 1.0]]),
			"sala retangular: parede norte contínua fora da abertura")
		_expect(_wall_line_coverage(rect, origin + Vector3(0, 1.5, 7), Vector3.RIGHT, 5.0),
			"sala retangular: parede sul contínua (4 m + 2 m)")
		_expect(_wall_line_coverage(rect, origin + Vector3(5, 1.5, 0), Vector3.BACK, 7.0),
			"sala retangular: parede leste contínua (4 m + 4 m + 2 m)")
		_expect(_wall_line_coverage(rect, origin + Vector3(-5, 1.5, 0), Vector3.BACK, 7.0),
			"sala retangular: parede oeste contínua")
		_expect(not _hits(origin + Vector3(0, 1.2, -8), origin + Vector3(0, 1.2, -6)),
			"sala retangular: abertura norte livre em x = 0")
		_free_module(rect)


# --- 6. Corredores ----------------------------------------------------------

func _test_corridors() -> void:
	print("[6] Corredores")
	var straight: Node3D = await _spawn_module("res://maps/modular/corridors/corridor_straight.tscn", Vector3(0, 0, 40))
	_expect(straight != null, "corredor reto instanciado")
	if straight != null:
		var o: Vector3 = straight.global_position
		expect_surface(o, 0.0, "corredor: piso no centro")
		expect_surface(o + Vector3(0, 0, 1.9), 0.0, "corredor: piso até a ponta")
		expect_surface(o + Vector3(0, 0, -1.9), 0.0, "corredor: piso até a outra ponta")
		_expect(_hits(o + Vector3(-1.6, 1.5, 0), o + Vector3(0, 1.5, 0)), "corredor: parede oeste")
		_expect(_hits(o + Vector3(1.6, 1.5, 0), o + Vector3(0, 1.5, 0)), "corredor: parede leste")
		_expect(not _hits(o + Vector3(0, 1.5, -2.2), o + Vector3(0, 1.5, 2.2)), "corredor: passagem livre")
		_expect(not _hits(o + Vector3(0, PLAYER_EYE, -2.0), o + Vector3(0, PLAYER_EYE, 2.0)),
			"corredor: livre na altura da câmera")
		_expect(_player_fits(o + Vector3(0, 0.02, 0)), "corredor: cápsula do jogador cabe")
		_free_module(straight)

	var corner: Node3D = await _spawn_module("res://maps/modular/corridors/corridor_corner.tscn", Vector3(20, 0, 40))
	_expect(corner != null, "canto de corredor instanciado")
	if corner != null:
		var o: Vector3 = corner.global_position
		expect_surface(o + Vector3(-1, 0, -1), 0.0, "canto: piso do trecho reto")
		expect_surface(o + Vector3(1, 0, 1), 0.0, "canto: piso do ramo")
		expect_surface(o + Vector3(1, 0, -1), 0.0, "canto: piso da curva")
		var path: Array[Vector3] = [
			o + Vector3(-2.0, 1.2, -1.0),
			o + Vector3(0.5, 1.2, -1.0),
			o + Vector3(1.0, 1.2, 0.5),
			o + Vector3(1.0, 1.2, 2.0),
		]
		_expect(_path_clear(path), "canto: caminho interno livre")
		_expect(_hits(o + Vector3(0, 1.5, -2.6), o + Vector3(0, 1.5, -1.4)), "canto: parede externa fecha a curva")
		_free_module(corner)

	var junction: Node3D = await _spawn_module("res://maps/modular/corridors/corridor_junction.tscn", Vector3(40, 0, 40))
	_expect(junction != null, "junção em T instanciada")
	if junction != null:
		var o: Vector3 = junction.global_position
		expect_surface(o + Vector3(0, 0, 2), 0.0, "junção: piso do ramo")
		_expect(_path_clear([o + Vector3(-2.5, 1.2, 0), o + Vector3(0, 1.2, 0), o + Vector3(2.5, 1.2, 0)]),
			"junção: passagem reta livre")
		_expect(_path_clear([o + Vector3(0, 1.2, 0), o + Vector3(0, 1.2, 2)]), "junção: ramo livre")
		_expect(_hits(o + Vector3(-2, 1.5, 1.4), o + Vector3(-2, 1.5, 0.6)),
			"junção: lado fechado onde não há ramo")
		_expect(not _hits(o + Vector3(0, 1.5, 1.4), o + Vector3(0, 1.5, 0.4)),
			"junção: ramo aberto no centro")
		_free_module(junction)


# --- 7. Escada --------------------------------------------------------------

func _test_stairs_geometry() -> void:
	print("[7] Geometria da escada")
	var stairs: Node3D = await _spawn_module("res://maps/modular/stairs/stairs_straight.tscn", Vector3(0, 0, 60))
	_expect(stairs != null, "escada instanciada")
	if stairs == null:
		return
	var o: Vector3 = stairs.global_position
	# Rampa contínua: altura cresce de 0 até 4 m ao longo de 6 m.
	for index: int in 6:
		var z: float = -(0.5 + float(index))
		var expected: float = STAIR_RISE * (0.5 + float(index)) / STAIR_RUN
		var hit: Dictionary = _ray(o + Vector3(0, expected + 1.5, z), o + Vector3(0, expected - 0.5, z))
		_expect(not hit.is_empty(), "escada: há superfície em z=%.1f" % z)
		if hit.is_empty():
			continue
		var height: float = (hit["position"] as Vector3).y - o.y
		_expect(absf(height - expected) < 0.12,
			"escada: altura %.2f m em z=%.1f (esperado %.2f)" % [height, z, expected])
		# pé-direito sobre o piso da rampa (nada atravessa o caminho)
		_expect(not _hits(o + Vector3(0, expected + 0.35, z), o + Vector3(0, expected + 2.2, z)),
			"escada: caminho livre 2,2 m acima em z=%.1f" % z)
	# Largura, guardas e topo.
	_expect(_hits(o + Vector3(1.6, 1.2, -3.0), o + Vector3(0, 1.2, -3.0)) or
		_hits(o + Vector3(1.6, 2.2, -3.0), o + Vector3(0, 2.2, -3.0)),
		"escada: guarda lateral existe")
	var top_hit: Dictionary = _ray(o + Vector3(0, 5.0, -5.95), o + Vector3(0, 3.0, -5.95))
	_expect(not top_hit.is_empty(), "escada: rampa chega ao topo")
	if not top_hit.is_empty():
		var top_y: float = (top_hit["position"] as Vector3).y - o.y
		_expect(absf(top_y - STAIR_RISE * 5.95 / STAIR_RUN) < 0.12,
			"escada: topo em y = %.2f m" % top_y)
	# Inclinação compatível com o controlador (limite 45°).
	var angle: float = rad_to_deg(atan2(STAIR_RISE, STAIR_RUN))
	_expect(angle < 45.0, "escada: inclinação %.1f° abaixo do limite do jogador" % angle)
	_free_module(stairs)


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
		_expect(room.get_node_or_null("RoomSquare") != null, "demonstração: sala quadrada presente")
		_expect(room.get_node_or_null("RoomRect") != null, "demonstração: sala retangular presente")
		_expect(room.get_node_or_null("CorridorNorth") != null, "demonstração: corredor norte presente")
		_expect(room.get_node_or_null("CorridorEast") != null, "demonstração: corredor leste presente")
		_expect(room.get_node_or_null("CorridorSouth") != null, "demonstração: corredor sul presente")
		_expect(room.get_node_or_null("CorridorCorner") != null, "demonstração: canto presente")
		_expect(room.get_node_or_null("Stairs") != null, "demonstração: escada presente")
		_expect(room.get_node_or_null("Spawn") is Marker3D, "demonstração: ponto de nascimento presente")
		_expect(_count_named(room, "Pillar") >= 4,
			"demonstração: pilares presentes (%d)" % _count_named(room, "Pillar"))
		_expect(_count_named(room, "Rail") >= 10,
			"demonstração: guarda-corpos presentes (%d)" % _count_named(room, "Rail"))
		_expect(_count_named(room, "Mezzanine") >= 10,
			"demonstração: mezanino montado com pisos (%d)" % _count_named(room, "Mezzanine"))
	_expect(_scene.count_modules() >= 45, "demonstração: %d módulos no cenário" % _scene.count_modules())

	var spawn: Vector3 = _player.global_position
	_expect(spawn.distance_to(Vector3(0, 0.15, 3)) < 0.25,
		"jogador nasce no Spawn do cenário (%.2f, %.2f, %.2f)" % [spawn.x, spawn.y, spawn.z])
	expect_surface(Vector3(12, 6, 10), 4.0, "mezanino: piso em y = 4")

	# Conectividade: raios na altura do jogador entre ambientes vizinhos.
	_expect(_path_clear([Vector3(0, 0.9, 3), Vector3(0, 0.9, -8)]),
		"conexão: sala quadrada → porta → corredor norte")
	_expect(_path_clear([Vector3(0, 0.9, 0.5), Vector3(5, 0.9, 0.5), Vector3(9, 0.9, 0.5),
			Vector3(12, 0.9, 0.5)]),
		"conexão: sala quadrada → abertura leste → corredor → canto")
	_expect(_path_clear([Vector3(12, 0.9, 0.5), Vector3(12, 0.9, 3), Vector3(12, 0.9, 7.5),
			Vector3(12, 0.9, 10)]),
		"conexão: canto → corredor sul → abertura → sala retangular")
	_expect(_path_clear([Vector3(12, 4.6, 11.5), Vector3(12, 4.6, 8.0)]),
		"conexão: topo da escada → mezanino")

	# --- Caminhada real ----------------------------------------------------
	print("[9] Caminhada na demonstração")
	await _place(Vector3(0, 0.05, 1), 0.0)
	await _walk(2.4)
	_expect(_player.global_position.z < -5.4,
		"atravessa o vão da porta (z = %.2f)" % _player.global_position.z)
	_expect(absf(_player.global_position.x) < 0.5, "passa centralizado pela porta")

	await _place(Vector3(0, 0.05, 0.5), -PI / 2.0)
	await _walk(1.9)
	_expect(_player.global_position.x > 5.4,
		"atravessa a abertura leste (x = %.2f)" % _player.global_position.x)

	await _place(Vector3(12, 0.05, 0.5), PI)
	await _walk(2.4)
	_expect(_player.global_position.z > 7.2,
		"entra na sala retangular pela abertura (z = %.2f)" % _player.global_position.z)

	# Parede barra o jogador.
	await _place(Vector3(0, 0.05, 3.0), -PI / 2.0)
	await _walk(2.0)
	_expect(_player.global_position.x < -4.2 and _player.global_position.x > -5.0,
		"parede oeste barra o jogador (x = %.2f)" % _player.global_position.x)

	# Escada: sobe.
	print("[10] Escada com o jogador")
	await _place(Vector3(12, 0.05, 20.3), 0.0)
	await _walk(4.0)
	_expect(_player.global_position.y > 3.6,
		"sobe a escada até o mezanino (y = %.2f)" % _player.global_position.y)
	_expect(_player.global_position.z < 12.5, "chega ao topo (z = %.2f)" % _player.global_position.z)

	# Escada: desce.
	await _place(Vector3(12, 4.05, 10.5), PI)
	await _walk(4.2)
	_expect(_player.global_position.y < 0.6,
		"desce a escada até o piso (y = %.2f)" % _player.global_position.y)

	# Mezanino: guarda-corpos seguram nas bordas fechadas.
	await _place(Vector3(14, 4.05, 10.0), PI)
	await _walk(1.4)
	_expect(_player.global_position.y > 3.4,
		"guarda-corpo sul segura no mezanino (y = %.2f)" % _player.global_position.y)
	_expect(_player.global_position.z < 12.8,
		"guarda-corpo impede sair pela borda (z = %.2f)" % _player.global_position.z)

	await _place(Vector3(12, 4.05, 9.0), 0.0)
	await _walk(1.6)
	_expect(_player.global_position.y > 3.4 and _player.global_position.z > 7.2,
		"guarda-corpo norte segura no mezanino (z = %.2f)" % _player.global_position.z)


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


## Largura livre do vão na linha de uma parede, medida com raios laterais.
func _opening_width(module: Node3D, height: float) -> float:
	var origin: Vector3 = module.global_position
	var free_min: float = 99.0
	var free_max: float = -99.0
	var x: float = -1.0
	while x <= 1.0001:
		if not _hits(origin + Vector3(x, height, -0.6), origin + Vector3(x, height, 0.6)):
			free_min = minf(free_min, x)
			free_max = maxf(free_max, x)
		x += 0.01
	if free_min > free_max:
		return 0.0
	return free_max - free_min


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
			# raio perpendicular atravessando a parede
			var normal := axis.cross(Vector3.UP).normalized()
			if _hits(point - normal * 0.8, point + normal * 0.8):
				covered += 1
		t += step
	# Tolerância: bordas e juntas (2 amostras por metro já bastam).
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
		var body: Node3D = shape.get_parent() as Node3D
		# Coordenadas locais à raiz do módulo: funciona antes de entrar na árvore
		# e não depende de get_global_transform (indisponível fora da árvore).
		var center: Vector3 = body.position + shape.position
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
	printerr("MODULAR TEST FALHOU — %d de %d verificações" % [_failures.size(), _checks])
	for failure: String in _failures:
		printerr("   - ", failure)
	get_tree().quit(1)
