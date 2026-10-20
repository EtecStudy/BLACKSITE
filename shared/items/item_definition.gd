class_name ItemDefinition
extends Resource
## Representação genérica de um item (Etapa 8).
##
## Um item é **dado**, não comportamento: identificador estável (`id`) e nome
## legível (`display_name`). Nada de peso, pilha, ícone, uso ou durabilidade —
## esses campos entram quando o sistema que os consome existir.
##
## O recurso é compartilhado por `players/` (o inventário guarda itens),
## `items/` (objetos coletáveis criam itens) e `ui/` (a HUD mostra o nome). Por
## isso vive em `shared/`, do mesmo jeito que o contrato `Interactable`: é o
## **tipo comum** entre módulos que não podem se importar.
##
## Uso:
##
##     var item := ItemDefinition.new(&"lanterna", "Lanterna")
##     inventory.add_item(item)
##
## Arquivos `.tres` de item podem ser criados depois sem tocar no inventário,
## porque o inventário só conhece este contrato.

## Identificador estável do item (ex.: `&"item_a"`). Não muda com tradução.
@export var id: StringName = &""

## Nome exibido na HUD e na indicação de interação (ex.: "ITEM A").
@export var display_name: String = ""


func _init(item_id: StringName = &"", item_label: String = "") -> void:
	id = item_id
	display_name = item_label if not item_label.is_empty() else String(item_id)
	if not display_name.is_empty():
		resource_name = display_name


## Um item só entra no inventário se tiver identificador.
func is_valid() -> bool:
	return not String(id).is_empty()


## Nome para exibição, com recuo para o identificador quando não há nome.
func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	return String(id)


func matches(other: ItemDefinition) -> bool:
	return other != null and other.id == id


func _to_string() -> String:
	return "ItemDefinition(%s, %s)" % [String(id), get_display_name()]
