# MapView.gd
# 맵 뷰 및 노드 선택
extends Control

var map_manager: MapManager
var main_controller: Node
var is_modal: bool = false

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var floors_container: VBoxContainer = $ScrollContainer/FloorsContainer
@onready var btn_close: Button = $BtnClose

func setup(p_map_manager: MapManager, p_main_ctrl: Node, p_is_modal: bool = false) -> void:
	map_manager = p_map_manager
	main_controller = p_main_ctrl
	is_modal = p_is_modal

	btn_close.visible = is_modal
	btn_close.pressed.connect(func(): queue_free())

	render_map()

func render_map() -> void:
	for c in floors_container.get_children():
		c.queue_free()

	var available_nodes = map_manager.get_available_next_nodes()
	var available_ids = []
	for n in available_nodes:
		available_ids.append(n["id"])

	# Reverse to show bottom (floor 1) at bottom or top
	for f_idx in range(map_manager.floors.size() - 1, -1, -1):
		var floor_nodes = map_manager.floors[f_idx]
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var lbl_floor = Label.new()
		lbl_floor.text = "%2d층: " % (f_idx + 1)
		hbox.add_child(lbl_floor)

		for node in floor_nodes:
			var btn = Button.new()
			btn.text = "%s %s" % [node["icon"], node["name"]]
			btn.custom_minimum_size = Vector2(140, 36)

			var is_current = map_manager.current_node_id == node["id"]
			var is_available = available_ids.has(node["id"])

			if is_current:
				btn.modulate = Color(0.4, 1.0, 0.4)
			elif is_available:
				btn.modulate = Color(1.0, 0.9, 0.3)
				if not is_modal:
					btn.pressed.connect(func():
						main_controller.handle_node_select(node)
					)
			else:
				btn.modulate = Color(0.5, 0.5, 0.6)
				btn.disabled = true

			hbox.add_child(btn)

		floors_container.add_child(hbox)
