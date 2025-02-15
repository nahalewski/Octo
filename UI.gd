extends CanvasLayer

@onready var health_bar = $MarginContainer/HBoxContainer/HealthBar
@onready var magic_bar = $MarginContainer/HBoxContainer/MagicBar
@onready var health_label = $MarginContainer/HBoxContainer/HealthBar/Label
@onready var magic_label = $MarginContainer/HBoxContainer/MagicBar/Label

func _ready():
	# Connect to knight signals
	var knight = get_tree().get_first_node_in_group("knight")
	if knight:
		knight.health_changed.connect(_on_knight_health_changed)
		knight.magic_changed.connect(_on_knight_magic_changed)
		
		# Initialize bars
		health_bar.max_value = knight.max_health
		health_bar.value = knight.current_health
		magic_bar.max_value = knight.max_magic
		magic_bar.value = knight.current_magic
		
		# Initialize labels
		_update_health_label(knight.current_health, knight.max_health)
		_update_magic_label(knight.current_magic, knight.max_magic)

func _on_knight_health_changed(new_health):
	health_bar.value = new_health
	_update_health_label(new_health, health_bar.max_value)

func _on_knight_magic_changed(new_magic):
	magic_bar.value = new_magic
	_update_magic_label(new_magic, magic_bar.max_value)

func _update_health_label(current, maximum):
	health_label.text = "HP: %d/%d" % [current, maximum]

func _update_magic_label(current, maximum):
	magic_label.text = "MP: %d/%d" % [current, maximum] 