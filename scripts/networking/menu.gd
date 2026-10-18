extends Control
var status_label: Label
var address: LineEdit
var port: SpinBox


func _ready() -> void:
	_build_ui()
	Net.status_changed.connect(_set_status)
	_set_status(Net.status)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0b1115")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(430, 0)
	panel.add_theme_constant_override("separation", 13)
	center.add_child(panel)
	var title := Label.new()
	title.text = "B L A C K S I T E"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	panel.add_child(title)
	var sub := Label.new()
	sub.text = "SETOR DE CONTENÇÃO  ·  PROTÓTIPO 0.1"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color("9ba6a8"))
	panel.add_child(sub)
	address = LineEdit.new()
	address.placeholder_text = "Endereço do servidor (127.0.0.1)"
	address.text = "127.0.0.1"
	panel.add_child(address)
	port = SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = Net.PORT_DEFAULT
	port.prefix = "UDP: "
	panel.add_child(port)
	var host_btn := Button.new()
	host_btn.text = "HOSPEDAR PARTIDA"
	host_btn.pressed.connect(func(): Net.host(int(port.value)))
	panel.add_child(host_btn)
	var join_btn := Button.new()
	join_btn.text = "ENTRAR NA PARTIDA"
	join_btn.pressed.connect(func(): Net.join(address.text, int(port.value)))
	panel.add_child(join_btn)
	var quit_btn := Button.new()
	quit_btn.text = "ENCERRAR SESSÃO"
	quit_btn.pressed.connect(Net.leave)
	panel.add_child(quit_btn)
	status_label = Label.new()
	status_label.text = "Offline"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status_label)
	var note := Label.new()
	note.text = "WASD mover · Shift correr · Mouse olhar · Esc soltar mouse"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color("7d888c"))
	panel.add_child(note)


func _set_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message
