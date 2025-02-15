extends Panel

# This script is minimal as most functionality is handled by the Inventory script
func _ready():
	# Make sure the slot can receive input
	mouse_filter = Control.MOUSE_FILTER_PASS 