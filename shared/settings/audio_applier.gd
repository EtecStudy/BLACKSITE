class_name AudioApplier
extends RefCounted
## Aplica os volumes das configurações aos buses de áudio da Godot.
##
## O layout dos buses fica em `res://audio/default_bus_layout.tres`:
##   Master
##     ├── Music
##     ├── SFX
##     ├── Ambience
##     └── Voice
##
## O volume é guardado em percentual (0-100) e convertido para decibéis com
## `linear_to_db`. Em 0% o bus é silenciado para evitar `-inf` dB.

const BUS_BY_SETTING := {
	"master_volume": "Master",
	"sfx_volume": "SFX",
	"ambience_volume": "Ambience",
	"music_volume": "Music",
	"voice_volume": "Voice",
}


## Aplica os volumes de um dicionário de configurações (seção `audio`).
static func apply(values: Dictionary) -> void:
	var audio: Dictionary = values.get(SettingsSchema.SECTION_AUDIO, {})
	for key: String in BUS_BY_SETTING:
		if not audio.has(key):
			continue
		set_bus_volume(BUS_BY_SETTING[key], float(audio[key]))


## Ajusta um bus específico. Ignora buses inexistentes sem falhar.
static func set_bus_volume(bus_name: String, percent: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return

	var clamped: float = clampf(percent, float(SettingsSchema.VOLUME_MIN), float(SettingsSchema.VOLUME_MAX))
	AudioServer.set_bus_mute(index, clamped <= 0.0)
	if clamped <= 0.0:
		AudioServer.set_bus_volume_db(index, -80.0)
	else:
		AudioServer.set_bus_volume_db(index, linear_to_db(clamped / 100.0))


## Volume atual de um bus, em percentual (para diagnóstico e testes).
static func get_bus_percent(bus_name: String) -> int:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return -1
	if AudioServer.is_bus_mute(index):
		return 0
	return int(round(db_to_linear(AudioServer.get_bus_volume_db(index)) * 100.0))
