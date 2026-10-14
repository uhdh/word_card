extends Node
# 진단 도구: 게임 화면에서 맵 아트가 차지하는 정확한 픽셀 사각형을 출력한다.
#   godot --path godot res://tools/Probe.tscn -- act=3
# 검증 스크립트(tools/mapgen/verify_on_screen.py)가 이 값을 읽어 쓴다.

var _act := 1


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("act="):
			_act = int(a.split("=")[1])
	var main = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var field = main.get_node_or_null("VBox/FieldContainer/DefenseField")
	if field == null:
		field = main.find_child("DefenseField", true, false)
	if field == null:
		print("PROBE no field"); get_tree().quit(); return
	if _act > 1:
		field.set_act(_act)
	for i in range(6):
		await get_tree().process_frame
	var bg: TextureRect = field.background
	print("PROBE viewport=", get_viewport().get_visible_rect().size)
	print("PROBE field_pos=", field.global_position)
	print("PROBE field_size=", field.size)
	print("PROBE bg_pos=", bg.global_position)
	print("PROBE bg_size=", bg.size)
	print("PROBE bg_tex=", bg.texture.get_size())
	print("PROBE fit_scale=", field.map_fit_scale, " fit_offset=", field.map_fit_offset)
	print("PROBE act=", _act)
	get_tree().quit()
