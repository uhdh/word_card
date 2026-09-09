extends Node

const Intro = preload("res://scripts/ui/IntroOverlay.gd")

func _ready() -> void:
	assert(Intro.frame_count() == 11, "Intro must include every supplied frame")
	for path in Intro.FRAME_PATHS:
		assert(ResourceLoader.exists(path), "Intro frame is missing: %s" % path)
	assert(Intro.frame_index_for(0.0) == 0, "Intro starts at the first frame")
	assert(Intro.frame_index_for(Intro.FRAME_DURATION * 2.1) == 2, "Intro frame timing must advance deterministically")
	assert(Intro.frame_index_for(Intro.FRAME_DURATION * 99.0) == 10, "Intro timing must clamp at the final frame")
	var overlay = load("res://scenes/IntroOverlay.tscn").instantiate()
	add_child(overlay)
	overlay.skip()
	assert(overlay._finished, "Intro skip must finish immediately")
	print("[Intro] frame sequence checks passed")
	get_tree().quit(0)
