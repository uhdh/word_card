# sync_test_scene.gd — ⛔ **쓰지 마라. `tools/SyncTestScene.tscn` 을 써라.**
#
# ⚠️ 2026-10-04 실측 — 이 파일은 **깨진 씬을 만들면서 성공을 보고한다.**
#    `--script` 모드는 오토로드(`SoundEngine`·`HangulEngine`)를 등록하지 않아
#    `_init()` 의 `load(SRC)` 시점에 스크립트 14개가 컴파일 실패하고, `pack()` 이
#    노드의 `script` 바인딩을 **전부 잃는다**:
#      · 정상(`SyncTestScene.tscn`) — 노드 44 · `ext_resource` 6 · `script = ExtResource` **4줄** · 9,399 B
#      · 이 파일               — 노드 44 · `ext_resource` **2** · `script = ExtResource` **0줄** · 8,940 B
#    그런데 `quit()` 는 **RC=0** 이고 `✅ 테스트 씬 동기화 완료` 를 **찍는다.**
#    → 실행하면 `scenes/tower/AutoPlayTDTest.tscn`(= `run_all.sh` 가 돌리는 씬)이 **조용히 망가진다.**
#      **성공 문구를 믿지 마라.**
#
# 대체: `godot --headless --path godot res://tools/SyncTestScene.tscn`
#       (씬 모드라 오토로드가 산다 — 실측 RC=0 · 컴파일 오류 0 · `script=` 4줄 · 정상 재생성)
#
# 배경: AutoPlayTDTest.tscn 이 본편과 다른 TopBar 트리를 갖고 있어서
#       "Node not found" 에러가 계속 났다. 수동 동기화는 반드시 다시 어긋난다.
#       그래서 테스트 씬을 본편에서 생성한다.
#
# 생성 결과는 본편 트리 + AutoPlayBot 노드. TowerDefenseMain 스크립트가
# 그대로 붙으므로 진짜 회귀 테스트가 된다.
extends SceneTree

const SRC := "res://scenes/TowerDefenseMain.tscn"
const OUT := "res://scenes/tower/AutoPlayTDTest.tscn"
const BOT_SCRIPT := "res://scripts/test/AutoPlayTowerDefense.gd"
const TEST_UID := "uid://td_auto_test_001"


func _init() -> void:
	# Godot 는 이미 로드된 PackedScene 을 저장할 때 서브리소스를 유지한다.
	var packed: PackedScene = load(SRC)
	if packed == null:
		printerr("본편 씬을 불러올 수 없습니다: ", SRC)
		quit(1)
		return

	var root := packed.instantiate()
	# 자동 테스트용 봇을 루트에 붙인다.
	var bot := Node.new()
	bot.name = "AutoPlayBot"
	bot.set_script(load(BOT_SCRIPT))
	root.add_child(bot)
	bot.owner = root

	# 복제본을 새 PackedScene 으로 패킹
	var out_scene := PackedScene.new()
	var err := out_scene.pack(root)
	if err != OK:
		printerr("pack 실패: ", err)
		quit(1)
		return

	# 테스트 전용 UID 로 저장 (본편 UID 와 충돌 방지)
	out_scene.resource_path = OUT
	err = ResourceSaver.save(out_scene, OUT)
	if err != OK:
		printerr("저장 실패: ", err)
		quit(1)
		return

	print("✅ 테스트 씬 동기화 완료: ", OUT)
	quit()
