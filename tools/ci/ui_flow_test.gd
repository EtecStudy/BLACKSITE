extends Node
## Teste de navegação real da interface (Etapa 3).
##
## Diferente do teste de fumaça (que instancia as telas isoladamente), este teste
## percorre o fluxo de verdade, com troca de cenas:
##
##   tela inicial → CONFIGURAÇÕES → abas → alterar volume → APLICAR →
##   RESTAURAR PADRÕES → VÍDEO (tela cheia) → VOLTAR → tela inicial →
##   reabrir CONFIGURAÇÕES (valor mantido) → VOLTAR → F11
##
## Uso:
##     godot --headless --path . --fixed-fps 60 res://tools/ci/ui_flow_test.tscn
##
## Sai com 0 em caso de sucesso e 1 em caso de falha.

const TITLE_SCENE := "res://ui/scenes/title_screen.tscn"
const SETTINGS_SCENE := "res://ui/scenes/settings_screen.tscn"
const FLOW_CONFIG := "user://test_ui_flow_settings.cfg"

const SIDEBAR := "Margin/Layout/Body/Sidebar"
const FOOTER := "Margin/Layout/Footer"
const HOST := "Margin/Layout/Body/Panel/PanelMargin/Scroll/SectionHost"

const TIMEOUT_SECONDS := 120.0


func _ready() -> void:
	var driver := FlowDriver.new()
	driver.name = "FlowDriver"
	get_tree().root.add_child.call_deferred(driver)


class FlowDriver:
	extends Node

	var checks: int = 0
	var failures: PackedStringArray = PackedStringArray()
	var settings
	var original_path: String = ""
	var original_values: Dictionary = {}
	var finished: bool = false


	func _ready() -> void:
		_start()


	func _start() -> void:
		var timeout: SceneTreeTimer = get_tree().create_timer(TIMEOUT_SECONDS)
		timeout.timeout.connect(_on_timeout)
		_run()


	func _on_timeout() -> void:
		if finished:
			return
		printerr("UI FLOW FALHOU — tempo esgotado")
		get_tree().quit(1)


	func _run() -> void:
		print("=== Black Sight · fluxo de interface ===")
		settings = get_node_or_null("/root/GameSettings")
		if settings == null:
			_abort("autoload GameSettings ausente")
			return

		original_path = settings.config_path
		original_values = settings.current()
		settings.config_path = FLOW_CONFIG
		_remove_file(FLOW_CONFIG)
		settings.apply(SettingsSchema.defaults())

		# 1. tela inicial
		get_tree().change_scene_to_file(TITLE_SCENE)
		var title: Node = await _wait_for_scene("TitleScreen")
		_expect(title != null, "tela inicial abre")
		if title == null:
			_finish()
			return

		# identidade visual preservada
		_expect(title.get_node_or_null("Content/Emblem") != null, "emblema continua presente")
		_expect(
			title.get_node_or_null("Content/TitleLabel") != null,
			"título continua presente"
		)
		var build_label: Label = title.get_node_or_null("Content/BuildLabel") as Label
		_expect(
			build_label != null and build_label.text.contains("F11"),
			"rodapé continua indicando o atalho F11"
		)
		var quit_button: Button = title.get_node_or_null("Content/Buttons/QuitButton") as Button
		_expect(
			quit_button != null and quit_button.pressed.get_connections().size() > 0,
			"botão SAIR DO JOGO continua funcional"
		)

		# 2. abrir configurações
		var settings_button: Button = title.get_node_or_null(
			"Content/Buttons/SettingsButton"
		) as Button
		_expect(settings_button != null, "botão CONFIGURAÇÕES existe na tela inicial")
		if settings_button == null:
			_finish()
			return
		settings_button.pressed.emit()

		var screen: Node = await _wait_for_scene("SettingsScreen")
		_expect(screen != null, "botão CONFIGURAÇÕES abre a tela de configurações")
		if screen == null:
			_finish()
			return

		# 3. abas
		var tab_controls: Button = screen.get_node_or_null(SIDEBAR + "/TabControls") as Button
		var tab_audio: Button = screen.get_node_or_null(SIDEBAR + "/TabAudio") as Button
		var tab_video: Button = screen.get_node_or_null(SIDEBAR + "/TabVideo") as Button
		_expect(
			tab_controls != null and tab_audio != null and tab_video != null,
			"as três abas estão presentes"
		)
		if tab_controls == null or tab_audio == null or tab_video == null:
			_finish()
			return

		var apply_button: Button = screen.get_node_or_null(FOOTER + "/ApplyButton") as Button
		var defaults_button: Button = screen.get_node_or_null(FOOTER + "/DefaultsButton") as Button
		var back_button: Button = screen.get_node_or_null(FOOTER + "/BackButton") as Button
		_expect(
			apply_button != null and defaults_button != null and back_button != null,
			"botões APLICAR, RESTAURAR PADRÕES e VOLTAR presentes"
		)
		if apply_button == null or defaults_button == null or back_button == null:
			_finish()
			return

		var controls_section: Node = _visible_section(screen)
		_expect(controls_section is ControlsSection, "seção CONTROLES aberta por padrão")

		# 4. aba de áudio
		tab_audio.pressed.emit()
		await _frames(2)
		var audio_section: Node = _visible_section(screen)
		_expect(audio_section is AudioSection, "aba ÁUDIO acessível")

		var sliders: Array = []
		if audio_section != null:
			sliders = audio_section.find_children("*", "HSlider", true, false)
		_expect(sliders.size() == 4, "quatro controles de volume (geral, efeitos, ambiente, música)")

		if sliders.size() == 4:
			(sliders[0] as HSlider).value = 37.0
			await _frames(1)
			apply_button.pressed.emit()
			await _frames(3)
			_expect(
				int(settings.current().audio.master_volume) == 37,
				"APLICAR guarda o volume alterado (37%%)"
			)
			_expect(
				_read_config_int("audio", "master_volume") == 37,
				"volume alterado foi gravado no arquivo"
			)

		# 5. restaurar padrões
		defaults_button.pressed.emit()
		await _frames(2)
		apply_button.pressed.emit()
		await _frames(3)
		_expect(
			int(settings.current().audio.master_volume) == SettingsSchema.DEFAULT_MASTER_VOLUME,
			"RESTAURAR PADRÕES devolve o volume padrão na sessão"
		)
		_expect(
			_read_config_int("audio", "master_volume") == SettingsSchema.DEFAULT_MASTER_VOLUME,
			"RESTAURAR PADRÕES + APLICAR grava o padrão no arquivo"
		)

		# 6. aba de vídeo
		tab_video.pressed.emit()
		await _frames(2)
		var video_section: Node = _visible_section(screen)
		_expect(video_section is VideoSection, "aba VÍDEO acessível")

		var options: Array = []
		if video_section != null:
			options = video_section.find_children("*", "OptionButton", true, false)
		_expect(options.size() == 2, "vídeo oferece resolução e modo de janela")
		var mode_option: OptionButton = null
		if options.size() == 2:
			_expect((options[0] as OptionButton).item_count >= 1, "lista de resoluções preenchida")
			mode_option = options[1] as OptionButton
			_expect(mode_option.item_count == 3, "janela, maximizada e tela cheia disponíveis")

		if mode_option != null:
			mode_option.select(SettingsSchema.WindowMode.FULLSCREEN)
			mode_option.item_selected.emit(SettingsSchema.WindowMode.FULLSCREEN)
			await _frames(1)
			apply_button.pressed.emit()
			await _frames(3)
			_expect(
				int(settings.current().video.window_mode) == SettingsSchema.WindowMode.FULLSCREEN,
				"modo tela cheia é aplicado e guardado"
			)
			_expect(
				_read_config_int("video", "window_mode") == SettingsSchema.WindowMode.FULLSCREEN,
				"modo tela cheia foi gravado no arquivo"
			)

		# 7. voltar ao menu
		back_button.pressed.emit()
		var title_again: Node = await _wait_for_scene("TitleScreen", 900)
		_expect(title_again != null, "VOLTAR retorna à tela inicial")
		if title_again == null:
			_finish()
			return

		# 8. reabrir e conferir valor mantido
		var settings_button_again: Button = title_again.get_node_or_null(
			"Content/Buttons/SettingsButton"
		) as Button
		if settings_button_again != null:
			settings_button_again.pressed.emit()
			var screen_again: Node = await _wait_for_scene("SettingsScreen")
			_expect(screen_again != null, "tela de configurações reabre")
			if screen_again != null:
				(screen_again.get_node(SIDEBAR + "/TabVideo") as Button).pressed.emit()
				await _frames(2)
				var reopened_video: Node = _visible_section(screen_again)
				var reopened_options: Array = []
				if reopened_video != null:
					reopened_options = reopened_video.find_children("*", "OptionButton", true, false)
				_expect(
					reopened_options.size() == 2
					and (reopened_options[1] as OptionButton).selected
						== SettingsSchema.WindowMode.FULLSCREEN,
					"ao reabrir, a tela mostra o modo de janela salvo"
				)
				(screen_again.get_node(FOOTER + "/BackButton") as Button).pressed.emit()
				title_again = await _wait_for_scene("TitleScreen", 900)

		# 9. F11 continua funcionando e é persistido
		if title_again != null:
			var before: int = int(settings.current().video.window_mode)
			_send_f11(title_again)
			await _frames(3)
			var after: int = int(settings.current().video.window_mode)
			_expect(
				after != before,
				"F11 alterna o modo de janela (%s → %s)" % [before, after]
			)
			_send_f11(title_again)
			await _frames(3)
			_expect(
				int(settings.current().video.window_mode) == before,
				"F11 alterna de volta ao modo anterior"
			)
		else:
			_expect(false, "tela inicial disponível para testar o F11")

		# 10. cena de teste da movimentação (Etapas 4–5)
		if title_again != null:
			var test_button: Button = title_again.get_node_or_null(
				"Content/Buttons/TestMovementButton"
			) as Button
			_expect(test_button != null, "botão TESTAR MOVIMENTAÇÃO presente")
			if test_button != null:
				test_button.pressed.emit()
				var game: Node = await _wait_for_scene("MovementTest", 1200)
				_expect(game != null, "TESTAR MOVIMENTAÇÃO abre a cena de teste")
				if game != null:
					_expect(
						game.get_node_or_null("Player") != null,
						"jogador presente na cena de teste"
					)
					var camera := game.get_node_or_null("Player/Head/Camera") as Camera3D
					_expect(
						camera != null and camera.current,
						"câmera em primeira pessoa ativa"
					)
					# Etapa 5: pausa → CONFIGURAÇÕES → voltar à pausa → CONTINUAR.
					var pause_flow_ok: bool = await _exercise_pause_menu(game)
					_expect(pause_flow_ok, "fluxo de pausa com configurações funciona")
					var menu_button: Button = game.get_node_or_null(
						"Interface/PauseRoot/Center/Panel/Margin/Content/MenuButton"
					) as Button
					_expect(menu_button != null, "botão VOLTAR AO MENU presente")
					if menu_button != null:
						game.pause_session()
						await _frames(3)
						menu_button.pressed.emit()
						title_again = await _wait_for_scene("TitleScreen", 1200)
						_expect(title_again != null, "VOLTAR AO MENU retorna à tela inicial")

		_finish()


	# --- Pausa + configurações (Etapa 5) ------------------------------------

	func _exercise_pause_menu(game: Node) -> bool:
		var content := "Interface/PauseRoot/Center/Panel/Margin/Content/"
		game.pause_session()
		await _frames(3)
		var pause_root: Control = game.get_node_or_null("Interface/PauseRoot") as Control
		if pause_root == null or not pause_root.visible:
			_expect(false, "menu de pausa abre")
			return false

		var settings_button: Button = game.get_node_or_null(
			content + "SettingsButton"
		) as Button
		_expect(settings_button != null, "menu de pausa tem CONFIGURAÇÕES")
		if settings_button == null:
			return false

		settings_button.pressed.emit()
		await _frames(6)
		var screen: SettingsScreen = game.get_node_or_null(
			"SettingsLayer/SettingsScreen"
		) as SettingsScreen
		_expect(screen != null, "CONFIGURAÇÕES abre durante a partida (mesma tela)")
		if screen == null:
			return false
		_expect(not pause_root.visible, "configurações escondem o menu de pausa")

		# Etapas 6–7: modo de agachamento e lista real (agora com E — Interagir).
		var controls: ControlsSection = screen.get_section("controls") as ControlsSection
		_expect(controls != null, "seção CONTROLES disponível na partida")
		if controls != null:
			var rows: Array = controls.get_key_hint_rows()
			var keys: Array = []
			var labels: String = ""
			for row: Array in rows:
				keys.append(str(row[0]))
				labels += "%s %s " % [str(row[0]), str(row[1])]
			_expect(keys.size() == 7, "lista real de controles durante a partida (%d)" % keys.size())
			_expect(keys.has("E"), "lista inclui E — Interagir (Etapa 7)")
			_expect(
				labels.to_lower().contains("interagir")
					and not labels.to_lower().contains("lanterna")
					and not labels.to_lower().contains("pular"),
				"lista mostra só ações implementadas"
			)
			controls.set_crouch_mode_id("hold")
			_expect(
				controls.get_crouch_hint_text() == "Segurar para agachar",
				"texto do Ctrl muda para o modo SEGURAR"
			)
			var apply_button_game: Button = screen.get_node_or_null("%ApplyButton") as Button
			_expect(apply_button_game != null, "APLICAR disponível na partida")
			if apply_button_game != null:
				apply_button_game.pressed.emit()
				await _frames(4)
				_expect(
					str(settings.current().controls.crouch_mode) == "hold",
					"modo SEGURAR é aplicado durante a partida"
				)
				controls = screen.get_section("controls") as ControlsSection
				_expect(
					controls != null and controls.crouch_mode_id() == "hold",
					"tela mantém o modo SEGURAR depois de aplicar"
				)
				if controls != null:
					_expect(
						controls.get_crouch_hint_text() == "Segurar para agachar",
						"texto do Ctrl continua em SEGURAR"
					)

		var back_button: Button = screen.get_node_or_null("%BackButton") as Button
		_expect(back_button != null, "configurações têm VOLTAR")
		if back_button == null:
			return false
		back_button.pressed.emit()
		await _frames(6)
		var back_to_pause: bool = (
			not game.is_settings_open() and game.is_paused() and pause_root.visible
		)
		_expect(back_to_pause, "VOLTAR nas configurações retorna ao menu de pausa")

		var continue_button: Button = game.get_node_or_null(
			content + "ContinueButton"
		) as Button
		if continue_button == null:
			return false
		continue_button.pressed.emit()
		await _frames(3)
		var resumed: bool = not game.is_paused() and not pause_root.visible
		_expect(resumed, "CONTINUAR retoma a partida")
		var player := game.get_node_or_null("Player")
		if player != null:
			_expect(player.movement_enabled, "jogador habilitado após CONTINUAR")
		# Volta ao padrão do jogo (ALTERNAR) para não deixar efeito colateral.
		settings.apply(SettingsSchema.defaults())
		return back_to_pause and resumed


	# --- Utilidades ---------------------------------------------------------

	func _send_f11(scene: Node) -> void:
		var event := InputEventKey.new()
		event.keycode = KEY_F11
		event.pressed = true
		scene._unhandled_input(event)


	func _visible_section(screen: Node) -> Node:
		var host: Node = screen.get_node_or_null(HOST)
		if host == null:
			return null
		for child: Node in host.get_children():
			if child is Control and (child as Control).visible:
				return child
		return null


	func _read_config_int(section: String, key: String) -> int:
		var config := ConfigFile.new()
		if config.load(FLOW_CONFIG) != OK:
			return -9999
		return int(config.get_value(section, key, -9999))


	func _wait_for_scene(scene_name: String, max_frames: int = 600) -> Node:
		for index: int in max_frames:
			await get_tree().process_frame
			var scene: Node = get_tree().current_scene
			if scene != null and scene.name == scene_name:
				await get_tree().process_frame
				return scene
		return null


	func _frames(count: int) -> void:
		for index: int in count:
			await get_tree().process_frame


	func _expect(condition: bool, description: String) -> void:
		checks += 1
		if condition:
			print("  ✓ " + description)
		else:
			failures.append(description)
			printerr("  ✗ " + description)


	func _abort(reason: String) -> void:
		failures.append(reason)
		printerr("  ✗ " + reason)
		_finish()


	func _finish() -> void:
		if finished:
			return
		finished = true

		if settings != null:
			settings.config_path = original_path
			settings.apply(original_values)
		_remove_file(FLOW_CONFIG)

		print("")
		if failures.is_empty():
			print("UI FLOW OK — %d verificações aprovadas" % checks)
			get_tree().quit(0)
			return
		printerr("UI FLOW FALHOU — %d de %d verificações" % [failures.size(), checks])
		get_tree().quit(1)


	func _remove_file(path: String) -> void:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
