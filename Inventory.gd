extends CanvasLayer

@export var max_slots = 20
@export var columns = 5

var inventory = []
var is_open = false

# Reference to UI elements
@onready var inventory_panel = $InventoryPanel
@onready var grid_container = $InventoryPanel/MarginContainer/GridContainer
@onready var item_label = $InventoryPanel/ItemLabel

# Item slot scene - you'll need to create this
const ItemSlot = preload("res://ItemSlot.tscn")

class InventoryItem:
	var name: String
	var description: String
	var quantity: int
	var icon: Texture2D
	
	func _init(p_name: String, p_description: String, p_quantity: int, p_icon: Texture2D):
		name = p_name
		description = p_description
		quantity = p_quantity
		icon = p_icon

func _ready():
	# Initialize inventory panel
	inventory_panel.hide()
	setup_grid()
	
	# Initialize empty inventory
	for i in max_slots:
		inventory.append(null)

func _input(event):
	if event.is_action_pressed("gamepad_inventory"):
		toggle_inventory()

func toggle_inventory():
	is_open = !is_open
	if is_open:
		inventory_panel.show()
		get_tree().paused = true  # Pause the game while inventory is open
	else:
		inventory_panel.hide()
		get_tree().paused = false

func setup_grid():
	# Set the columns for the grid
	grid_container.columns = columns
	
	# Create slots
	for i in max_slots:
		var slot = ItemSlot.instantiate()
		grid_container.add_child(slot)
		# Connect slot signals
		slot.mouse_entered.connect(_on_slot_mouse_entered.bind(i))
		slot.mouse_exited.connect(_on_slot_mouse_exited)
		slot.gui_input.connect(_on_slot_gui_input.bind(i))

func add_item(item_name: String, item_description: String, quantity: int = 1, icon: Texture2D = null) -> bool:
	# First try to stack with existing item
	for i in range(inventory.size()):
		if inventory[i] and inventory[i].name == item_name:
			inventory[i].quantity += quantity
			update_slot_display(i)
			return true
	
	# If we couldn't stack, find an empty slot
	for i in range(inventory.size()):
		if inventory[i] == null:
			inventory[i] = InventoryItem.new(item_name, item_description, quantity, icon)
			update_slot_display(i)
			return true
	
	return false  # Inventory is full

func remove_item(slot_index: int, quantity: int = 1) -> bool:
	if slot_index < 0 or slot_index >= inventory.size():
		return false
	
	var item = inventory[slot_index]
	if item == null:
		return false
	
	item.quantity -= quantity
	if item.quantity <= 0:
		inventory[slot_index] = null
	
	update_slot_display(slot_index)
	return true

func update_slot_display(slot_index: int):
	var slot = grid_container.get_child(slot_index)
	var item = inventory[slot_index]
	
	if item:
		slot.get_node("Icon").texture = item.icon
		slot.get_node("Quantity").text = str(item.quantity) if item.quantity > 1 else ""
		slot.get_node("Icon").show()
		slot.get_node("Quantity").show()
	else:
		slot.get_node("Icon").hide()
		slot.get_node("Quantity").hide()

func _on_slot_mouse_entered(slot_index: int):
	var item = inventory[slot_index]
	if item:
		item_label.text = "%s\n%s" % [item.name, item.description]
		item_label.show()

func _on_slot_mouse_exited():
	item_label.hide()

func _on_slot_gui_input(event: InputEvent, slot_index: int):
	if event.is_action_pressed("gamepad_use_item"):
		use_item(slot_index)

func use_item(slot_index: int):
	var item = inventory[slot_index]
	if item:
		# Implement item use effects here
		print("Using item: ", item.name)
		remove_item(slot_index)

# Example function to add test items
func add_test_items():
	add_item("Health Potion", "Restores 50 HP", 1, preload("res://assets/items/health_potion.png"))
	add_item("Magic Potion", "Restores 50 MP", 1, preload("res://assets/items/magic_potion.png"))
	add_item("Sword", "A basic sword", 1, preload("res://assets/items/sword.png")) 
