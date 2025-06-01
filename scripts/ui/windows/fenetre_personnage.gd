extends PanelContainer

var close_button: Button
var title_label: Label
var content_container: VBoxContainer

var classe_label: Label
var niveau_label: Label
var equipement_label: Label

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(600, 400)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	
	_setup_header(vbox)
	_setup_content(vbox)
	
	hide()

func _setup_header(parent: VBoxContainer):
	var header = HBoxContainer.new()
	parent.add_child(header)
	
	title_label = Label.new()
	title_label.text = "Informations du Personnage"
	title_label.add_theme_font_size_override("font_size", 20)
	header.add_child(title_label)
	
	header.add_spacer(false)
	
	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

func _setup_content(parent: VBoxContainer):
	content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 15)
	parent.add_child(content_container)
	
	var info_panel = PanelContainer.new()
	content_container.add_child(info_panel)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 10)
	info_panel.add_child(info_vbox)
	
	classe_label = Label.new()
	classe_label.text = "Classe: Guerrier"
	classe_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(classe_label)
	
	niveau_label = Label.new()
	niveau_label.text = "Niveau: 60"
	niveau_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(niveau_label)
	
	equipement_label = Label.new()
	equipement_label.text = "Niveau d'équipement: 150"
	equipement_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(equipement_label)

func _on_close_pressed():
	hide()

func update_character_info(classe: String, niveau: int, equipement: int):
	classe_label.text = "Classe: " + classe
	niveau_label.text = "Niveau: " + str(niveau)
	equipement_label.text = "Niveau d'équipement: " + str(equipement)