# SyncTestScene.tscn 용 스크립트.
# 본편 씬을 복제해 자동 테스트 씬을 생성한다.
# `--script` 모드에서는 오토로드(SoundEngine 등)를 못 쓰므로 씬으로 실행한다.
# ⚠️ 형제 파일 `tools/sync_test_scene.gd`(`--script` 판)는 **깨져 있다** — 2026-10-04 실측
#    (script 바인딩 0줄 · 8,940 B 를 쓰고도 RC=0 + `✅ 동기화 완료`). 그쪽 헤더를 보라. 이 파일을 써라.
extends Node

func _ready() -> void:
	var src := "res://scenes/TowerDefenseMain.tscn"
	var out_path := "res://scenes/tower/AutoPlayTDTest.tscn"
	var bot_script := "res://scripts/test/AutoPlayTowerDefense.gd"

	var packed: PackedScene = load(src)
	if packed == null:
		printerr("본편 씬 로드 실패")
		get_tree().quit(1)
		return

	var root := packed.instantiate()
	var bot := Node.new()
	bot.name = "AutoPlayBot"
	bot.set_script(load(bot_script))
	root.add_child(bot)
	bot.owner = root

	var out_scene := PackedScene.new()
	var err := out_scene.pack(root)
	if err != OK:
		printerr("pack 실패: ", err)
		get_tree().quit(1)
		return
	err = ResourceSaver.save(out_scene, out_path)
	if err != OK:
		printerr("저장 실패: ", err)
		get_tree().quit(1)
		return

	# ⚠️ 저장만으로는 부족하다 — '복제' 가 스크립트 바인딩을 실제로 옮겼는지 **센다.**
	# 2026-10-04: `tools/sync_test_scene.gd`(`--script` 판)는 오토로드가 없어 바인딩을
	# 전부 잃은 씬(script= 0줄 · 8,940 B)을 쓰고도 `✅ 동기화 완료` + RC=0 을 찍었다.
	# 성공 문구는 증거가 아니다 — 여기서 수를 세어야 한다.
	var src_bind := _count_script_bindings(src)
	var out_bind := _count_script_bindings(out_path)
	if out_bind < src_bind:
		printerr("검증 실패 — script 바인딩 %d줄 < 원본 %d줄: 복제가 스크립트를 잃었다" % [out_bind, src_bind])
		get_tree().quit(1)
		return

	print("✅ 테스트 씬 동기화 완료: ", out_path)
	print("   script 바인딩 ", out_bind, "줄 (원본 ", src_bind, "줄) — 검증 통과")
	get_tree().quit(0)


func _count_script_bindings(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var n := 0
	while not f.eof_reached():
		if f.get_line().strip_edges().begins_with("script = ExtResource"):
			n += 1
	return n
