extends SceneTree

func _initialize() -> void:
	var scene = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	assert(Engine.max_fps == 60, "Game must cap rendering at 60 FPS")
	assert(OS.low_processor_usage_mode, "Idle game must use low processor mode")
	assert(scene.relic_items.get_child_count() == scene.owned_relics.size() + 1, "Relic bar must show every owned relic")
	var tower = load("res://scenes/tower/WordTower.tscn").instantiate()
	assert(tower.get_node("BasePanel").custom_minimum_size == Vector2(88, 96), "Tower card must use the enlarged size")
	assert(tower.get_node("IconContainer/IconSprite").custom_minimum_size == Vector2(56, 56), "Tower art must be 56px")
	tower.free()
	var layer = scene.get_node("ModalLayer")
	for child in layer.get_children(): child.queue_free()
	await process_frame
	scene._on_lore_pressed()
	scene._on_lore_pressed()
	await process_frame
	assert(layer.get_child_count() == 1, "Lore button must not stack duplicate modals")
	var modal = layer.get_node("LoreModal")
	var close_button = modal.get_child(0).get_child(-1)
	assert(root.get_visible_rect().encloses(modal.get_global_rect()), "Lore modal must fit inside the viewport")
	assert(root.get_visible_rect().encloses(close_button.get_global_rect()), "Lore close button must stay visible")
	close_button.pressed.emit()
	await process_frame
	assert(layer.get_child_count() == 0, "Lore close button must dismiss the modal")
	var belt = scene.get_node("VBox/JamoBelt")
	assert(belt.tiles_container.get_child_count() > 0, "Belt must render grouped tower trays")
	belt.set_relics(["relic_initial_compass"])
	belt._show_hint()
	assert(belt.parsed_preview_label.text.begins_with("💡 힌트:"), "Hint must use the flexible preview area instead of overflowing the header")
	scene.queue_free()
	await process_frame
	quit()
