class_name AudioSection
extends SettingsSection
## Seção ÁUDIO — volumes por categoria.
##
## Cada slider ajusta um bus real do layout em `audio/default_bus_layout.tres`.
## Os valores são pré-visualizados ao vivo (o jogador ouve o clique da interface
## mudar de volume) e só são gravados quando a tela chama `GameSettings.apply()`.
##
## Música, ambiente e voz ainda não têm sons associados: os buses existem e o
## volume fica salvo, mas só será percebido quando essas categorias forem usadas.

var _master: HSlider
var _sfx: HSlider
var _ambience: HSlider
var _music: HSlider


func setup(values: Dictionary) -> void:
	var audio: Dictionary = values.get(SettingsSchema.SECTION_AUDIO, {})

	add_section_title("VOLUMES")
	_master = add_slider_row(
		"Volume geral",
		float(SettingsSchema.VOLUME_MIN),
		float(SettingsSchema.VOLUME_MAX),
		1.0,
		float(audio.get("master_volume", SettingsSchema.DEFAULT_MASTER_VOLUME)),
		_format_percent,
		"Afeta todas as categorias de áudio."
	)
	_sfx = add_slider_row(
		"Efeitos sonoros",
		float(SettingsSchema.VOLUME_MIN),
		float(SettingsSchema.VOLUME_MAX),
		1.0,
		float(audio.get("sfx_volume", SettingsSchema.DEFAULT_SFX_VOLUME)),
		_format_percent,
		"Inclui os cliques e a confirmação desta interface."
	)
	_ambience = add_slider_row(
		"Áudio ambiente",
		float(SettingsSchema.VOLUME_MIN),
		float(SettingsSchema.VOLUME_MAX),
		1.0,
		float(audio.get("ambience_volume", SettingsSchema.DEFAULT_AMBIENCE_VOLUME)),
		_format_percent,
		"Categoria preparada; será audível quando o jogo tiver sons de ambiente."
	)
	_music = add_slider_row(
		"Volume da música",
		float(SettingsSchema.VOLUME_MIN),
		float(SettingsSchema.VOLUME_MAX),
		1.0,
		float(audio.get("music_volume", SettingsSchema.DEFAULT_MUSIC_VOLUME)),
		_format_percent,
		"Categoria preparada; o jogo ainda não tem trilha sonora."
	)

	add_divider()
	add_note(
		"Os volumes são aplicados aos buses Master, SFX, Ambience e Music "
		+ "assim que você move o controle (pré-visualização). Clique em APLICAR "
		+ "para gravar. O bus Voice já existe para as etapas de comunicação por voz."
	)


func read_values() -> Dictionary:
	if _master == null:
		return {}
	return {
		SettingsSchema.SECTION_AUDIO: {
			"master_volume": int(round(_master.value)),
			"sfx_volume": int(round(_sfx.value)),
			"ambience_volume": int(round(_ambience.value)),
			"music_volume": int(round(_music.value)),
		}
	}


func _format_percent(value: float) -> String:
	return "%d%%" % int(round(value))
