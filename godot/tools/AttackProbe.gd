extends Node
# 새 공격 방식(선회/유성)이 실제로 동작하는지 확인하는 진단 도구.
#   godot --path godot res://tools/AttackProbe.tscn
# 창 모드 권장 — PNG 캡처(`frame_post_draw`)만 창이 필요하다.
# ⚠️ **판정 자체(유성·선회가 실제로 발생하는가)는 headless 로도 된다.** 실측 2026-10-03:
#    유성이 `frame=293` 에 생성됐다. 예전 주석 "headless 에서는 프레임 루프가
#    안 돈다" 는 틀렸다 — 그 주석 때문에 이 프로브가 검증에서 통째로 빠져 있었다.

## ⚠️ **`AttackStyle.EXACT` 가 먼저 본다** — 카테고리(`magic`→meteor · `summon`→orbit)만
##    믿고 단어를 고르면 `EXACT` 에 덮여 **조용히 죽는다**. 실측(2026-10-03): 예전 목록
##    `[굿, 개구리, 검]` 은 `EXACT` 에서 굿·개구리가 **bounce** 라
##    `bounce · bounce · sniper` 가 나왔고 유성·선회를 **한 번도 못 만들었다**
##    → 창 모드에서도 `meteors > 0 and orbit_ticks > 0` 이 항상 거짓이라 **영구 rc=1**.
##    `성`→meteor · `책`→orbit · `검`→sniper 는 `EXACT` 기준이다.
const WORDS := ["성", "책", "검"]


func _ready() -> void:
	var main = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var field = main.find_child("DefenseField", true, false)
	var layer = field.projectiles_layer
	for i in range(6):
		await get_tree().process_frame
	var parsed: Array = []
	for w in WORDS:
		parsed.append({"syllable": w, "word_data": WordDatabase.get_word_data(w)})
	field.unlocked_slot_count = maxi(field.unlocked_slot_count, parsed.size())
	field.update_towers_from_parsed_list(parsed)
	await get_tree().process_frame

	print("=== 타워 특성 ===")
	for t in field.active_towers:
		var orbit = t.get_node_or_null("Orbit")
		print("  %-6s cat=%-8s trait=%-16s range=%5.1f orbit=%s(orb %s)" % [
			t.syllable, t.word_data.get("category", "?"), t.trait_id, t.attack_range,
			"O" if orbit else "-", orbit.orb_count if orbit else 0])
	# ⚠️ **먼저 프로브가 계약을 재고 있는지 확인한다.** 이게 없으면 타워가 안 만들어졌을 때
	#    1200프레임을 헛돌고 "유성 0 / 선회 0" 이라는 **거짓 진단**만 남기고 rc=1 을 낸다.
	var have_meteor := false
	var have_orbit := false
	for t in field.active_towers:
		if t.trait_id == "meteor": have_meteor = true
		if t.trait_id == "orbit": have_orbit = true
	if not (have_meteor and have_orbit):
		print("!! 이 프로브는 유성/선회 타워를 못 만들었다 — WORDS 를 확인하라.")
		print("!!   구성: %s" % str(WORDS))
		print("!!   위의 trait 들을 보라. AttackStyle.EXACT 가")
		print("!!   CATEGORY_FALLBACK 보다 먼저 본다는 것을 잊지 말자.")
		get_tree().quit(2)
		return

	var seen := {}
	var meteors := 0
	var orbit_ticks := 0
	var shots := 0
	for f in range(1200):
		await get_tree().process_frame
		for c in layer.get_children():
			if not (c is Meteor):
				continue
			if not seen.has(c.get_instance_id()):
				seen[c.get_instance_id()] = true
				meteors += 1
				print("  유성! frame=%d pos=(%.0f,%.0f)" % [f, c.global_position.x, c.global_position.y])
			# 낙하 중(예고 원 + 꼬리가 보이는 순간)을 캡처한다.
			elif shots < 2 and c.progress() > 0.45 and c.progress() < 0.95:
				# ⚠️ **headless 에서는 `frame_post_draw` 가 오지 않는다** — 여기서 멈춘다(실측).
				#    판정은 headless 로도 되므로 **캡처만** 건너뛴다.
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					var img := get_viewport().get_texture().get_image()
					var path := "E:/project/word_card/_meteor_fall_%d.png" % shots
					img.save_png(path)
					print("  유성 낙하 캡처: %s (progress=%.2f)" % [path, c.progress()])
					shots += 1
		for t in field.active_towers:
			var orbit = t.get_node_or_null("Orbit")
			if orbit and orbit._hit_flash.size() > 0:
				orbit_ticks += 1

	print("=== 결과 ===")
	print("  유성 생성 횟수: %d / 낙하 캡처 %d장" % [meteors, shots])
	print("  선회 타격이 일어난 프레임 수: %d" % orbit_ticks)
	print("  현재 골드: %d / 남은 적: %d / 기지 HP: %d" % [field.gold, field.get_enemies().size(), field.base_hp])
	var ok := meteors > 0 and orbit_ticks > 0
	if ok:
		print("ATTACK_PROBE_OK")
	get_tree().quit(0 if ok else 1)
