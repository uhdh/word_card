extends Node

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")


func _ready() -> void:
	var game = MainScene.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.start_new_game()
	game.jamo_belt.slot_assignments.assign([0, 0, 0])
	game.jamo_belt.render_belt()
	game.set_speed_scale(4.0)
	game.defense_field.wave_cleared.connect(func(_act, _wave, _gold):
		var hp: int = game.defense_field.base_hp
		print("early wave playtest: base HP %d/20" % hp)
		Engine.time_scale = 1.0
		get_tree().quit(0 if hp >= 15 else 1)
	)
	game.defense_field.game_over.connect(func(_victory):
		Engine.time_scale = 1.0
		get_tree().quit(1)
	)
	game._on_start_wave_pressed()
	get_tree().create_timer(60.0).timeout.connect(func():
		print("early wave timeout: base HP %d/20, queued %d, alive %d" % [game.defense_field.base_hp, game.defense_field.spawn_queue.size(), game.defense_field.get_enemies().size()])
		Engine.time_scale = 1.0
		get_tree().quit(1)
	)
