class_name SpaceProbe
extends RefCounted
## Consultas de física para achar um ponto livre **e apoiado** no chão (Etapa 9).
##
## Vive em `shared/` porque é **geometria de física pura**: não conhece item,
## inventário, jogador, HUD nem cena. Quem solta o item (`players/`) passa a
## caixa do objeto e recebe de volta um ponto validado ou a recusa.
##
## A validação de um ponto candidato tem quatro passos:
##   1. **chão**: um raio para baixo precisa achar uma superfície com normal
##      para cima (piso ou topo de caixa), dentro da coluna do ponto. Tetos e
##      faces inferiores são pulados, e o raio continua abaixo deles;
##   2. **espaço**: uma consulta de forma (caixa do item) na altura de repouso
##      precisa estar vazia — paredes, pilares, caixas e o próprio jogador
##      reprovam o ponto;
##   3. **apoio**: a pegada inteira do item precisa repousar **na mesma
##      superfície** (grade de raios curtos sob a caixa). Uma quina de caixa ou
##      um topo fino apoia só um canto: o item tombaria e cairia depois do
##      drop, e é exatamente isso que este passo impede;
##   4. **linha de visão**: o olho do jogador precisa enxergar o ponto, para o
##      item não nascer atrás de uma parede por causa de uma quina.
##
## Quando a coluna tem o **topo de um objeto** (caixa, pilar) mas o ponto
## direto não tem apoio completo, a busca desliza sobre esse mesmo topo até
## achar uma área apoiada — assim soltar "sobre o cubo" funciona sem exigir que
## o jogador acerte o centro no pixel certo, e sem transformar a área em
## proibida.
##
## Nada é instanciado aqui: a rotina só responde "dá ou não dá", com o motivo.
## `confirm_placement()` repete as checagens de espaço e apoio **depois** que a
## instância entrou na cena, sobre a posição real do nó.

## Normal mínima do piso (1 = piso perfeito). Superfícies mais inclinadas que
## ~45° são tratadas como parede/rampa e reprovadas.
const FLOOR_MIN_NORMAL_DOT := 0.7
## Folga acima do piso ao validar a caixa (evita falso contato com o chão).
const SHAPE_LIFT := 0.02
## Altura da folga final do item sobre o piso.
const REST_LIFT := 0.02
## Metade da largura da cápsula do jogador (o mesmo valor da cena do jogador).
const PLAYER_HALF_WIDTH := 0.35
## Folga extra entre o jogador e o ponto de drop.
const PLAYER_MARGIN := 0.08
## Quanto o raio sobe/desce ao procurar o piso, a partir dos pés do jogador.
const CEILING_PROBE := 2.0
const FLOOR_PROBE := 2.0
## Frações da distância preferida testadas em ordem (frente → mais perto).
const DISTANCE_FACTORS := [1.0, 0.82, 0.64]

## Apoio: grade de raios sobre a pegada. Todos os pontos precisam cair na
## **mesma** superfície (diferença máxima de `SUPPORT_TOLERANCE`).
const SUPPORT_GRID := 3
const SUPPORT_TOLERANCE := 0.03
## Raio da busca que desliza sobre o topo de um objeto (fração da pegada).
const SURFACE_SEARCH_RADIUS := 0.4
const SURFACE_SEARCH_RINGS := 4
const SURFACE_DIRECTIONS := 8
## Distância mínima do ponto à frente do jogador, em cosseno do ângulo.
const SURFACE_SEARCH_MIN_FORWARD_DOT := 0.25

## Resultado com motivo (para o chamador escolher a mensagem).
const REASON_WORLD := "sem mundo físico"
const REASON_DIRECTION := "direção inválida"
const REASON_NO_SPACE := "sem ponto livre"

## Sem superfície encontrada (valor que nunca passa nas comparações de altura).
const NO_SURFACE := -1.0e30


## Procura um ponto seguro na frente do jogador.
##
## `eye` é a posição da câmera (origem da linha de visão); `actor_position` é a
## base do jogador (pés), usada para as distâncias horizontais; `box_size` é a
## caixa do objeto que será colocado; `exclude` são os RIDs ignorados nas
## consultas (o próprio jogador). Devolve um dicionário com `valid`, `position`
## (base do objeto, já no piso), `surface_y` (altura da superfície encontrada,
## `NO_SURFACE` quando não há) e `reason`.
static func find_drop_position(
	world: World3D,
	eye: Vector3,
	forward: Vector3,
	actor_position: Vector3,
	box_size: Vector3,
	exclude: Array[RID],
	collision_mask: int,
	preferred_distance: float
) -> Dictionary:
	if world == null:
		return _failure(REASON_WORLD)
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	if space == null:
		return _failure(REASON_WORLD)

	var direction := Vector3(forward.x, 0.0, forward.z)
	if direction.length_squared() < 0.0001:
		return _failure(REASON_DIRECTION)
	direction = direction.normalized()

	var min_distance: float = PLAYER_HALF_WIDTH + box_size.x * 0.5 + PLAYER_MARGIN
	var last_reason: String = REASON_NO_SPACE
	for factor: float in DISTANCE_FACTORS:
		var distance: float = preferred_distance * factor
		if distance < min_distance:
			continue
		var candidate := Vector3(
			actor_position.x + direction.x * distance,
			actor_position.y,
			actor_position.z + direction.z * distance
		)
		var spot: Dictionary = _probe_column(space, eye, candidate, box_size, exclude, collision_mask)
		if bool(spot.get("valid", false)):
			return spot
		last_reason = str(spot.get("reason", REASON_NO_SPACE))

		# A coluna tem o topo de um objeto (caixa/pilar), mas a pegada não está
		# inteiramente apoiada ali. Desliza sobre esse topo antes de desistir.
		var surface_y: float = float(spot.get("surface_y", NO_SURFACE))
		if surface_y > actor_position.y + 0.1:
			var slid: Dictionary = _search_over_surface(
				space, eye, candidate, direction, actor_position, surface_y,
				box_size, exclude, collision_mask, min_distance
			)
			if bool(slid.get("valid", false)):
				return slid
	return _failure(last_reason)


## Confirma, **já com o item na cena**, que a posição real é segura: a caixa do
## item não toca em nada (fora o próprio item e o jogador) e a pegada está
## inteiramente apoiada na superfície sob ele. `base` é a base do nó do item.
static func confirm_placement(
	world: World3D,
	base: Vector3,
	box_size: Vector3,
	exclude: Array[RID],
	collision_mask: int
) -> bool:
	if world == null:
		return false
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	if space == null:
		return false
	var center := base + Vector3(0.0, box_size.y * 0.5 + SHAPE_LIFT, 0.0)
	if not _is_free(space, center, box_size, exclude, collision_mask):
		return false
	return _support_ok(space, base.x, base.z, base.y, box_size, collision_mask, exclude)


## Valida uma coluna vertical: piso + espaço livre + apoio + linha de visão.
static func _probe_column(
	space: PhysicsDirectSpaceState3D,
	eye: Vector3,
	candidate: Vector3,
	box_size: Vector3,
	exclude: Array[RID],
	collision_mask: int
) -> Dictionary:
	var floor_y: float = _floor_height(space, candidate, collision_mask, exclude)
	if floor_y == NO_SURFACE:
		return _failure(REASON_NO_SPACE)

	var center := Vector3(candidate.x, floor_y + box_size.y * 0.5 + SHAPE_LIFT, candidate.z)
	if not _is_free(space, center, box_size, exclude, collision_mask):
		return _blocked(floor_y, "espaço ocupado")
	# Sem apoio completo o item tomba/cai depois do drop: não é posição segura.
	if not _support_ok(space, candidate.x, candidate.z, floor_y, box_size, collision_mask, exclude):
		return _blocked(floor_y, "pegada sem apoio")
	# O olho precisa enxergar o ponto (não soltar atravessando uma parede).
	if not _visible(space, eye, center, collision_mask, exclude):
		return _blocked(floor_y, "sem linha de visão")

	return {
		"valid": true,
		"position": Vector3(candidate.x, floor_y + REST_LIFT, candidate.z),
		"surface_y": floor_y,
		"reason": "",
	}


## Superfície (com normal para cima) mais alta abaixo da coluna.
## Tetos e faces inferiores não contam: o raio recomeça logo abaixo deles.
static func _floor_height(
	space: PhysicsDirectSpaceState3D,
	candidate: Vector3,
	collision_mask: int,
	exclude: Array[RID]
) -> float:
	var top: float = candidate.y + CEILING_PROBE
	var bottom: float = candidate.y - FLOOR_PROBE
	for _attempt: int in 4:
		if top <= bottom:
			break
		var hit: Dictionary = _ray(
			space,
			Vector3(candidate.x, top, candidate.z),
			Vector3(candidate.x, bottom, candidate.z),
			collision_mask,
			exclude
		)
		if hit.is_empty():
			break
		var normal: Vector3 = hit.get("normal", Vector3.UP)
		var height: float = (hit["position"] as Vector3).y
		if normal.dot(Vector3.UP) >= FLOOR_MIN_NORMAL_DOT:
			return height
		top = height - 0.01
	return NO_SURFACE


## A pegada inteira repousa na mesma superfície?
## Uma quina de caixa ou um topo fino reprovam (o item não ficaria estável).
static func _support_ok(
	space: PhysicsDirectSpaceState3D,
	x: float,
	z: float,
	floor_y: float,
	box_size: Vector3,
	collision_mask: int,
	exclude: Array[RID]
) -> bool:
	var half_x: float = box_size.x * 0.5
	var half_z: float = box_size.z * 0.5
	var from_y: float = floor_y + box_size.y + SHAPE_LIFT
	var to_y: float = floor_y - 0.1
	for ix: int in SUPPORT_GRID:
		for iz: int in SUPPORT_GRID:
			var tx: float = 0.5 if SUPPORT_GRID < 2 else float(ix) / float(SUPPORT_GRID - 1)
			var tz: float = 0.5 if SUPPORT_GRID < 2 else float(iz) / float(SUPPORT_GRID - 1)
			var px: float = x - half_x + 2.0 * half_x * tx
			var pz: float = z - half_z + 2.0 * half_z * tz
			var hit: Dictionary = _ray(
				space,
				Vector3(px, from_y, pz),
				Vector3(px, to_y, pz),
				collision_mask,
				exclude
			)
			if hit.is_empty():
				return false
			if absf((hit["position"] as Vector3).y - floor_y) > SUPPORT_TOLERANCE:
				return false
			var normal: Vector3 = hit.get("normal", Vector3.UP)
			if normal.dot(Vector3.UP) < FLOOR_MIN_NORMAL_DOT:
				return false
	return true


## Procura, sobre o topo de um objeto, uma área com apoio completo para a
## pegada. Só aceita pontos à frente do jogador e fora da cápsula.
static func _search_over_surface(
	space: PhysicsDirectSpaceState3D,
	eye: Vector3,
	candidate: Vector3,
	direction: Vector3,
	actor_position: Vector3,
	surface_y: float,
	box_size: Vector3,
	exclude: Array[RID],
	collision_mask: int,
	min_distance: float
) -> Dictionary:
	var right := Vector3(-direction.z, 0.0, direction.x)
	var step: float = SURFACE_SEARCH_RADIUS / float(SURFACE_SEARCH_RINGS)
	for ring: int in range(1, SURFACE_SEARCH_RINGS + 1):
		var radius: float = step * float(ring)
		for index: int in SURFACE_DIRECTIONS:
			var angle: float = TAU * float(index) / float(SURFACE_DIRECTIONS)
			var offset: Vector3 = (direction * cos(angle) + right * sin(angle)) * radius
			var point: Vector3 = candidate + offset
			var flat := Vector3(point.x - actor_position.x, 0.0, point.z - actor_position.z)
			var length: float = flat.length()
			if length < min_distance:
				continue
			# Não escolhe ponto atrás do jogador (nem muito de lado).
			if (flat / length).dot(direction) < SURFACE_SEARCH_MIN_FORWARD_DOT:
				continue
			var spot: Dictionary = _probe_column(space, eye, point, box_size, exclude, collision_mask)
			if not bool(spot.get("valid", false)):
				continue
			if absf(float(spot.get("surface_y", NO_SURFACE)) - surface_y) > SUPPORT_TOLERANCE:
				continue
			return spot
	return _failure(REASON_NO_SPACE)


## A caixa do item cabe nesse ponto sem tocar em nada?
static func _is_free(
	space: PhysicsDirectSpaceState3D,
	center: Vector3,
	box_size: Vector3,
	exclude: Array[RID],
	collision_mask: int
) -> bool:
	var shape := BoxShape3D.new()
	shape.size = box_size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = collision_mask
	query.exclude = exclude
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_shape(query, 1).is_empty()


## O olho enxerga o centro do item (nada bloqueia antes do ponto)?
static func _visible(
	space: PhysicsDirectSpaceState3D,
	eye: Vector3,
	center: Vector3,
	collision_mask: int,
	exclude: Array[RID]
) -> bool:
	var hit: Dictionary = _ray(space, eye, center, collision_mask, exclude)
	if hit.is_empty():
		return true
	return (hit["position"] as Vector3).distance_to(center) <= 0.15


static func _ray(
	space: PhysicsDirectSpaceState3D,
	from: Vector3,
	to: Vector3,
	collision_mask: int,
	exclude: Array[RID]
) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(from, to, collision_mask, exclude)
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.hit_from_inside = false
	return space.intersect_ray(params)


static func _failure(reason: String) -> Dictionary:
	return {"valid": false, "position": Vector3.ZERO, "surface_y": NO_SURFACE, "reason": reason}


## Recusa que **conhece a superfície** encontrada (para tentar deslizar sobre ela).
static func _blocked(surface_y: float, reason: String) -> Dictionary:
	return {"valid": false, "position": Vector3.ZERO, "surface_y": surface_y, "reason": reason}
