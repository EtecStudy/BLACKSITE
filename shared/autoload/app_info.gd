extends Node
## Informações globais de identificação do projeto (autoload `AppInfo`).
##
## Esta camada existe apenas para centralizar dados de build/versão usados
## pela interface. Nenhum estado de jogo é mantido aqui.

const GAME_NAME: String = "Black Sight"
const VERSION: String = "0.11.2"
const STAGE: int = 11
const STAGE_LABEL: String = "Etapa 11 · Sistema modular de salas"


## Ex.: "v0.1.0"
func version_label() -> String:
	return "v%s" % VERSION


## Ex.: "Etapa 1 · Fundação"
func stage_label() -> String:
	return STAGE_LABEL


## Ex.: "Godot 4.7.2-stable · gl_compatibility"
func engine_label() -> String:
	var info: Dictionary = Engine.get_version_info()
	var renderer: String = str(
		ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility")
	)
	return "Godot %s · %s" % [str(info.get("string", "?")), renderer]
