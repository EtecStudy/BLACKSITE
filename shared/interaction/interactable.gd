class_name Interactable
extends Node3D
## Contrato genérico de objeto interativo (Etapa 7).
##
## Qualquer nó que **herde de `Interactable`** — ou que implemente os três
## métodos do contrato (`can_interact`, `get_interaction_text`, `interact`) —
## pode ser detectado pelo `InteractionDetector` do jogador sem que o detector
## conheça o tipo concreto do objeto. O detector só descobre *o que* está na
## mira e dispara a ação; **quem decide o efeito é o próprio objeto**.
##
## Estrutura típica de um objeto interativo:
##
##     Interactable            ← raiz (este script, ou uma subclasse)
##     ├── StaticBody3D        ← colisão que o raio do jogador atinge
##     │   └── CollisionShape3D
##     ├── MeshInstance3D
##     └── Label3D
##
## O `CollisionObject3D` precisa estar em uma camada que o detector consulte
## (por padrão, a camada 1). Basta que ele seja filho — em qualquer nível — do
## nó `Interactable`: o detector sobe a árvore a partir do corpo atingido.
##
## Exemplos de uso futuro (não implementados nesta etapa): porta que abre,
## item que é pego, painel que liga. Todos herdam de `Interactable`, sobrescrevem
## `_on_interact()` e, se precisarem, `can_interact()` / `get_interaction_text()`.

## Emitido depois de uma interação aceita (a ação do objeto já rodou).
signal interaction_performed(actor: Node)

## Texto exibido na indicação (ex.: "Interagir", "Abrir", "Pegar").
## A tecla mostrada ao lado do texto vem do InputMap (`interact`), não daqui.
@export var interaction_text: String = "Interagir"

## Permite desligar a interação sem remover a colisão do objeto do mundo.
@export var interaction_enabled: bool = true


## O objeto pode ser interagido agora? Subclasses podem refinar
## (ex.: porta trancada, objeto ocupado). `actor` é quem está interagindo.
func can_interact(_actor: Node = null) -> bool:
	return interaction_enabled


## Texto/indicação da interação. Subclasses podem variar conforme o estado.
func get_interaction_text(_actor: Node = null) -> String:
	return interaction_text


## Executa a ação do objeto. Devolve `false` quando a interação não aconteceu.
## Subclasses implementam `_on_interact()`, não este método.
func interact(actor: Node = null) -> bool:
	if not can_interact(actor):
		return false
	_on_interact(actor)
	interaction_performed.emit(actor)
	return true


## Gancho das subclasses: aqui mora o efeito da interação.
func _on_interact(_actor: Node) -> void:
	pass


## Liga/desliga a interação (usado por testes e por estados futuros).
func set_interaction_enabled(value: bool) -> void:
	interaction_enabled = value
