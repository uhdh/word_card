extends Node

const SaveManager = preload("res://scripts/core/SaveManager.gd")
const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

func _ready() -> void:
	SaveManager.delete_save_file()
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(main.intro_overlay != null, "A fresh TowerDefenseMain run must show the intro")
	main.intro_overlay.skip()
	await get_tree().process_frame
	assert(main.intro_overlay == null, "Skipping the intro must return to the game")
	SaveManager.delete_save_file()
	print("[Intro] TowerDefenseMain entry checks passed")
	get_tree().quit(0)
