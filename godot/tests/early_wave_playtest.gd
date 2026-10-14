extends Node

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")


func _ready() -> void:
	# 이 검사는 실제 MainScene 을 세워 1라운드를 끝까지 돌린다 — 그래서 전투음이 계속 난다.
	# 그 소리가 **아직 재생 중인 채로** `quit()` 이 불리면 `AudioStreamWAV` 와 그
	# `AudioStreamPlaybackWAV` 가 종료 시 ObjectDB 누수로 잡힌다. 재생이 끝나기를 기다리면
	# 안 잡히므로 결과가 **운에 따라 0개였다 4개였다** 한다(실제로 그랬다).
	# 이 검사가 보는 것은 '누출 마릿수' 이지 소리가 아니므로, 도는 동안만 음소거한다.
	# (`SoundEngine._play_synth_stream` 은 muted 면 스트림을 **만들지도 않는다**)
	SoundEngine.muted = true
	var game = MainScene.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.start_new_game()
	game.jamo_belt.slot_assignments.assign([0, 0, 0])
	game.jamo_belt.render_belt()
	game.set_speed_scale(4.0)
	game.defense_field.wave_cleared.connect(func(_act, _wave, _gold):
		var hp: int = game.defense_field.base_hp
		var maximum: int = game.defense_field.max_base_hp
		var leaked: int = maximum - hp
		print("early wave playtest: %d마리 누출 (기지 %d/%d)" % [leaked, hp, maximum])
		Engine.time_scale = 1.0
		# 1라운드는 사실상 무료여야 한다. 기지 최대치가 바뀌어도 기준이 흔들리지 않도록
		# 비율이 아니라 '누출 마릿수' 로 단언한다. (실측: 배치 수정 후 0마리)
		get_tree().quit(0 if leaked <= 2 else 1)
	)
	game.defense_field.game_over.connect(func(_victory):
		Engine.time_scale = 1.0
		get_tree().quit(1)
	)
	game._on_start_wave_pressed()
	get_tree().create_timer(60.0).timeout.connect(func():
		print("early wave timeout: 기지 %d/%d, queued %d, alive %d" % [game.defense_field.base_hp, game.defense_field.max_base_hp, game.defense_field.spawn_queue.size(), game.defense_field.get_enemies().size()])
		Engine.time_scale = 1.0
		get_tree().quit(1)
	)
