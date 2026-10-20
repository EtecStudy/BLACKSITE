class_name SpaceProbe
extends RefCounted
## Consultas de física para achar um ponto livre no chão (Etapa 9).
##
## Vive em `shared/` porque é **geometria de física pura**: não conhece item,
## inventário, jogador, HUD nem cena. Quem solta o item (`players/`) passa a
## caixa do objeto e recebe de volta um ponto validado ou a recusa.
##
## A validação de um ponto candidato tem três passos:
##   1. **chão**: um raio para baixo precisa achar uma superfície com normal
##      para cima (piso), dentro da coluna do ponto;
##   2. **espaço**: uma consulta de forma (caixa do item) na altura de repouso
##      precisa estar vazia — paredes, pilares, caixas e o próprio jogador
##      reprovam o ponto;
##   3. **linha de visão**: o olho do jogador precisa enxergar o ponto, para o
##      item não nascer atrás de uma parede por causa de uma quina.
##
## Nada é instanciado aqui: a rotina só responde "dá ou não dá", com o motivo.

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

## Resultado com motivo (para o chamador escolher a mensagem).
const REASON_WORLD := "sem mundo físico"
const REASON_DIRECTION := "direção inválida"
const REASON_NO_SPACE := "sem ponto livre"


## Procura um ponto seguro na frente do jogador.
##
## `eye` é a posição da câmera (origem da linha de visão); `actor_position` é a
## base do jogador (pés), usada para as distâncias horizontais; `box_size` é a
## caixa do objeto que será colocado; `exclude` são os RIDs ignorados nas
## consultas (o próprio jogador). Devolve um dicionário com `valid`, `position`
## (base do objeto, já no piso) e `reason`.
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
	for factor: float in DISTANCE_FACTORS:
		var distance: float = preferred_distance * factor
		if distance < min_distance:
			continue
		var candidate := Vector3(
			actor_position.x + direction.x * distance,
			actor_position.y,
			actor_position.z + direction.z * distance
		)
		var spot: Dictionary = _validate_column(space, eye, candidate, box_size, exclude, collision_mask)
		if bool(spot.get("valid", false)):
			return spot
	return _failure(REASON_NO_SPACE)


## Valida uma coluna vertical: piso + espaço livre + linha de visão.
static func _validate_column(
	space: PhysicsDirectSpaceState3D,
	eye: Vector3,
	candidate: Vector3,
	box_size: Vector3,
	exclude: Array[RID],
	collision_mask: int
) -> Dictionary:
	var from := Vector3(candidate.x, candidate.y + CEILING_PROBE, candidate.z)
	var to := Vector3(candidate.x, candidate.y - FLOOR_PROBE, candidate.z)
	var floor_hit: Dictionary = _ray(space, from, to, collision_mask, exclude)
	if floor_hit.is_empty():
		return _failure(REASON_NO_SPACE)

	var normal: Vector3 = floor_hit.get("normal", Vector3.UP)
	if normal.dot(Vector3.UP) < FLOOR_MIN_NORMAL_DOT:
		return _failure(REASON_NO_SPACE)

	var floor_y: float = float(floor_hit["position"].y)
	var center := Vector3(candidate.x, floor_y + box_size.y * 0.5 + SHAPE_LIFT, candidate.z)
	if not _is_free(space, center, box_size, exclude, collision_mask):
		return _failure(REASON_NO_SPACE)

	# O olho precisa enxergar o ponto (não soltar atravessando uma parede).
	var look_hit: Dictionary = _ray(space, eye, center, collision_mask, exclude)
	if not look_hit.is_empty():
		var hit_position: Vector3 = look_hit.get("position", eye)
		if hit_position.distance_to(center) > 0.15:
			return _failure(REASON_NO_SPACE)

	return {
		"valid": true,
		"position": Vector3(candidate.x, floor_y + REST_LIFT, candidate.z),
		"reason": "",
	}


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
	return {"valid": false, "position": Vector3.ZERO, "reason": reason}
