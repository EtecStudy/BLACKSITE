extends "res://match/scripts/modular_demo.gd"
## Sessão da Sala-Piloto Visual.
##
## Reutiliza integralmente a sessão já aprovada: mesmo jogador, mesma HUD,
## mesma pausa com ESC, mesmas configurações e retorno ao menu. Apenas troca
## o cenário e o ponto de nascimento. Nenhum controlador novo é criado.

func _ready() -> void:
	super._ready()
	print("[Black Sight] Sala-piloto visual carregada — %d nós no cenário" % count_instances())


## Na sala-piloto, a leitura útil é a árvore completa (arquitetura, móveis,
## equipamentos, detalhes e luzes), não apenas os grupos de primeiro nível.
func count_modules() -> int:
	return count_instances()
