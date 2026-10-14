extends Node
# 보스 **처치** 연출이 잡몹 처치와 구별되는가 (§2.4, 2026-09-26 신규).
#
# 왜 이걸 재는가 — §2.4 는 지금까지 전부 **등장 전 / 등장 순간** 이야기였다.
# 등장은 6종 연출(전용음 · 실루엣 1.9배 · 흔들림 2노드 · 붉은 섬광 · 배너 · 전용 HP바)을
# 받는다. 그런데 **처치**는 `_on_enemy_died()` → `_juice_enemy_death()` 하나로, 타입을 보지
# 않고 잡몹과 **같은 길**을 탄다. 보스 분기가 그 두 함수 어디에도 없다.
#
# 계약: `TowerDefenseMain.gd:297` 이 플레이어에게
#   **"5라운드마다 보스 등장 · 처치 시 대보상"**
# 이라 약속한다. 보상의 **양**은 지켜진다(`boss_entry` 의 gold = 6 + act*2 = 8/10/12, 잡몹 1).
# 물음은 **표현**이다 — `+8 G` 가 `+1 G` 와 **같은 폰트·같은 색·같은 상승 거리·같은 시간**으로 뜬다.
#
# ✅ **§5.2 30 (A) 고침 — 감독이 "남은것 모두 수행" 으로 위임했다 (2026-10-01).**
#
# 고친 것: **보스 전용 처치음** `SoundEngine.play_boss_death()` (0.70초). 예전에는 보스도
# 잡몹과 똑같이 `play_coin`(0.20초)을 냈다 — 보상의 양은 8~12배인데 **귀로는 구별되지 않았다.**
# 소리를 골랐다(선택지 A). **화면은 건드리지 않았다** — 골드 텍스트를 키우는 (B)/(C) 는
# 거절했다: 필드에는 이미 피해 숫자(z=21) · 골드(z=100) · 이름판 · 보스 체력바 · 배너가
# 겹쳐 있고, 소리와 달리 **글자는 화면을 가린다**. 그리고 원칙이 *"효과를 많이 넣는 것이
# 목표가 아니다"* 다 → **새 효과 1개**로 끝낸다.
#
# ⚠️ **이 프로브의 §3 은 이제 '다르다' 를 단언한다.** 예전에는 '같다' 를 단언했고 그것이
# 결함의 기록이었다. 되돌리면 빨개진다.
# ⚠️ **표현 서명(시각)은 2026-10-03 부터 '파편 색만 다르다'** — §2.2 의 *적 종류 파편 색*
# 규칙이 보스에도 닿아, 보스 파편이 **빨강**(보스의 타입 색)이 됐다(잡몹은 골드).
# §3 은 그 셋을 **따로** 단언한다: 라벨·폰트·z = 공유 · **파편 색 = 다름** · 소리 = 다름.
# 이 구분이 없으면 "고쳤다" 가 과장이 된다.
# ⚠️ **§6 은 겹침 가드**다 — 웨이브를 끝내는 보스 처치는 `boss_death` 를 **내지 않는다**
# (`_grant_round_reward` 의 `play_victory` 가드와 같은 판단). 안 재면 이 가드가 조용히 죽는다.
#
# ⚠️ **숨기지 말 것.** 보스 처치에 **실제로 다른 것**이 둘 있다 — 골드 숫자(8~12배)와
# 보스 체력바가 사라지는 것. §4 가 그 둘을 **직접 단언**한다. 안 재면 "아무 표현도 없다" 는
# 과장이 된다(§2.4·§2.5·§2.11 의 실패가 전부 그 과장이었다).
#
# ⚠️ **재는 것은 '죽음' 하나다.** `take_damage(dmg, false)` 로 **피격음**을 뺀다 —
# 피격은 별개 사건이고(§2.4 의 `play_hit` 논의와 같은 이유), 두 경우 모두 같아서
# 빼지 않으면 서로를 가린다. 죽음 자체가 내는 소리(`play_coin`)는 그대로 잰다.
#
# 실행: godot --headless --path . res://tools/BossDeathProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")
const BOSS_WAVE := 5          # BOSS_ROUND_INTERVAL = 5
const INTERVAL := 5
const HUGE := 1.0e9

var failures := 0

## 절 태그를 함께 찍는다 — 실패가 어느 절에서 났는지 **기계가** 구별할 수 있어야 한다.
## 안 그러면 주입 표의 "걸린 절" 이 전부 같은 것으로 보인다(§2.17 에서 하네스가 이걸 잡았다).
func check(condition: bool, message: String, tag: String = "") -> void:
	if not condition:
		failures += 1
		print("FAIL_SECTION %s" % tag)
		push_error(message)

## 필드의 **직접 자식** 스냅샷.
## `_juice_enemy_death()` 는 파편과 골드 라벨을 `field.add_child()` 로 붙인다(`:1097`·`:1113`).
## 적 본체와 분열 조각은 `path_2d` 아래라 여기 안 잡힌다 — 죽음 '연출' 만 세기 위한 분리다.
func _child_ids(node: Node) -> Dictionary:
	var ids := {}
	for c in node.get_children():
		ids[c.get_instance_id()] = true
	return ids

## 한 노드를 '표현 서명' 한 조각으로 바꾼다.
## ⚠️ **글자(text)를 넣지 않는다** — 골드 숫자는 보스와 잡몹이 **달라야 정상**이고,
##    그 차이는 §4 가 따로 잰다. 여기서 재는 것은 **모양**이다.
func _describe(node: Node) -> String:
	var cls := node.get_class()
	var col := "-"
	var fs := "-"
	if node is ColorRect:
		col = str(node.color)
	elif node is Label:
		col = str(node.get_theme_color("font_color"))
		fs = str(node.get_theme_font_size("font_size"))
	return "%s|%s|fs=%s|z=%d" % [cls, col, fs, node.z_index]

## 죽음 하나가 만들어 낸 표현의 **집합**. 순서 무관 · 중복 제거(파편 6개 → 1조각).
func _signature(field: Node, before: Dictionary) -> Array:
	var seen := {}
	for c in field.get_children():
		if not before.has(c.get_instance_id()):
			seen[_describe(c)] = true
	var keys := seen.keys()
	keys.sort()
	return keys

## 서명에서 **파편 색만** 지운 사본 — 나머지(클래스·폰트·z)가 공유되는지 재기 위해서다.
##
## ⚠️ 왜 필요한가: §2.2(2026-10-03)가 파편 색을 적 종류에 묶은 뒤로, 보스와 잡몹의 서명은
##    **색 때문에** 항상 다르다. 그 하나의 차이를 지우고 나머지를 맞대어야
##    *"색 말고 다른 게 또 달라졌는가"* 를 잴 수 있다(전에는 통째로 `==` 였다).
## ⚠️ `ColorRect|(r,g,b,a)|fs=-|z=99` 의 **가운데 칸만** `*` 로 바꾼다 — 라벨의 폰트 색은
##    건드리지 않는다(그건 시각 채널의 다른 부분이고, 지금 공유돼야 하는 쪽이다).
func _sig_without_debris_color(sig: Array) -> Array:
	var out: Array = []
	for e in sig:
		var s := str(e)
		if s.begins_with("ColorRect|"):
			var parts := s.split("|")
			if parts.size() >= 3:
				parts[1] = "*"
				s = "|".join(parts)
		out.append(s)
	return out

## 그 차집합 안의 Label 글자들 — §4 에서 '골드 숫자가 실제로 다른가' 를 확인한다.
func _added_label_texts(field: Node, before: Dictionary) -> Array:
	var out := []
	for c in field.get_children():
		if before.has(c.get_instance_id()):
			continue
		if c is Label:
			out.append(str(c.text))
	out.sort()
	return out

func _first_boss(field) -> Node:
	for e in field.get_enemies():
		if not e.is_dead and e.enemy_type == "boss":
			return e
	return null

func _count_named(node: Node, target: String) -> int:
	var n := 0
	for c in node.get_children():
		if c.name == target:
			n += 1
	return n

func _ready() -> void:
	# 플레이어 설정이 `muted` 면 소리는 **합성조차** 안 된다(`_play_synth_stream` 첫 줄).
	SoundEngine.muted = false

	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	main._is_loading_state = true
	main.start_new_game()
	await get_tree().process_frame
	await get_tree().process_frame
	main._is_loading_state = true
	main.defense_field.reset_combat_state()
	await get_tree().process_frame
	if main.defense_field.is_wave_running:
		main.defense_field.reset_combat_state()
		await get_tree().process_frame

	var field = main.defense_field
	check(field.current_act == 1, "기준선이 1막이 아니다 (제 %d막)" % field.current_act, "S0")
	check(not field.is_wave_running, "기준선 잡기 실패 — 이미 웨이브가 돌고 있다", "S0")

	# ── §1 계약과 무게 ───────────────────────────────────────────────────────
	# 계약 문구를 **소스에서 읽는다**. 상수 목록처럼 조용히 공허해지지 않게 하려면
	# 검사 대상도 문구에서 읽어야 한다(§2.15·§2.16 이 그 규칙의 근거다).
	var src := FileAccess.get_file_as_string("res://scripts/ui/TowerDefenseMain.gd")
	check(not src.is_empty(), "`TowerDefenseMain.gd` 를 못 읽었다 — §1 의 계약 확인이 공허하다", "S1")
	check(src.contains("처치 시 대보상"),
		"계약 문구 '처치 시 대보상' 이 소스에 없다 — 이 프로브의 전제가 바뀌었다", "S1")

	var base_hp := 10.0
	var boss_golds := []
	for act in [1, 2, 3]:
		boss_golds.append(int(MonsterRoster.boss_entry(act, BOSS_WAVE, base_hp, 1.0, 1.0, INTERVAL)["gold"]))
	var mook_gold_data := int(MonsterRoster.regular_entry(1, 0, base_hp, 1.0, 1.0)["gold"])
	var ratio := float(boss_golds[0]) / maxf(1.0, float(mook_gold_data))
	print("BOSS_DEATH stakes boss_gold=%s mook_gold=%d ratio_min=%.1f" % [
		str(boss_golds), mook_gold_data, ratio])
	check(ratio >= 4.0,
		"보스 골드가 잡몹의 %.1f배뿐이다 — '대보상' 이라 부를 무게가 아니다" % ratio, "S1")

	# ── §2 보스 **등장**이 받는 표현 (비교 기준) ─────────────────────────────
	# 실제 경로로 보스 라운드를 연다 — `_start_round()` 를 직접 부르지 않는다.
	SoundEngine._cached_streams.clear()
	field.current_wave = BOSS_WAVE - 1
	field.start_next_wave()
	check(field.current_wave == BOSS_WAVE, "보스 라운드로 못 갔다 (wave=%d)" % field.current_wave, "S2")

	# 대조군 잡몹은 **큐에서 고른다** — 손으로 만든 데이터가 아니라 생성기가 만든 실제 데이터.
	# 분열(`splitter`)은 처치 때 자식을 만들어 스냅샷을 흐리므로 뺀다.
	var mook_data: Dictionary = {}
	for e in field.spawn_queue:
		var entry := e as Dictionary
		var attrs: Array = entry.get("attrs", [])
		if str(entry.get("type", "")) != "boss" and not attrs.has("splitter"):
			mook_data = entry.duplicate()
			break
	check(not mook_data.is_empty(),
		"분열 없는 잡몹 데이터를 큐에서 못 찾았다 — §3 의 대조군이 없다", "S2")

	var deadline := Time.get_ticks_msec() + 3000
	var boss = null
	while boss == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		boss = _first_boss(field)
	check(boss != null, "보스가 스폰되지 않았다", "S2")

	if boss == null:
		print("BOSS_DEATH_PROBE_ABORT 보스를 못 만들어 §3 을 재지 못했다")
		get_tree().quit(maxi(1, failures))
		return

	var banner_n := _count_named(field, "BossBanner")
	var bar_n := _count_named(field, "BossBar")
	var silhouette := Vector2.ZERO
	if boss.sprite:
		silhouette = boss.sprite.scale
	var entrance_sound: bool = SoundEngine._cached_streams.has("boss_entrance")
	var entrance_effects := 0
	if banner_n == 1: entrance_effects += 1
	if bar_n == 1: entrance_effects += 1
	if silhouette == Vector2(EnemyUnit.BOSS_SPRITE_SCALE, EnemyUnit.BOSS_SPRITE_SCALE): entrance_effects += 1
	if entrance_sound: entrance_effects += 1
	print("BOSS_DEATH entrance effects=%d banner=%d bar=%d scale=%s sound=%s" % [
		entrance_effects, banner_n, bar_n, str(silhouette), str(entrance_sound)])
	check(banner_n == 1, "보스 배너가 %d개다 (1개여야 한다)" % banner_n, "S2")
	check(bar_n == 1, "보스 체력바가 %d개다 (1개여야 한다)" % bar_n, "S2")
	check(entrance_sound, "보스 등장음이 합성되지 않았다 — §2 의 기준선이 무너진다", "S2")
	check(entrance_effects >= 4,
		"보스 등장 표현이 %d종뿐이다 — '등장은 화려하다' 는 전제가 약해졌다" % entrance_effects, "S2")

	# ── §3 보스 처치의 표현 서명 ─────────────────────────────────────────────
	# ⚠️ 죽음 처리는 `take_damage()` 안에서 **동기로** 끝난다(`died.emit` → `_on_enemy_died`
	# → `_juice_enemy_death` → 노드 부착 + `play_coin`). 그래서 **프레임을 넘기지 않고**
	# 읽는다 — 넘기면 그 사이 `_process` 가 스폰·기지 피격을 일으켜 차집합이 오염된다.
	# ⚠️ `boss` 는 Variant 다(`var boss = null` 로 받아 루프에서 대입) → `:=` 로 추론할 수 없다.
	# `Cannot infer the type ... because the value doesn't have a set type` 로 **파스가 죽는다**.
	var boss_type: String = boss.enemy_type
	var boss_gold := int(boss.gold_reward)
	var before_boss := _child_ids(field)
	SoundEngine._cached_streams.clear()
	SoundEngine._last_played_msec.clear()
	boss.take_damage(HUGE, false)
	var sig_boss := _signature(field, before_boss)
	var text_boss := _added_label_texts(field, before_boss)
	var snd_boss := SoundEngine._cached_streams.keys()
	snd_boss.sort()
	var enemies_left: int = field.get_enemies().size()
	print("BOSS_DEATH boss type=%s gold=%d texts=%s sig=%s sounds=%s enemies_left=%d" % [
		boss_type, boss_gold, str(text_boss), str(sig_boss), str(snd_boss), enemies_left])

	# ── §3 대조군 — 잡몹 처치 ────────────────────────────────────────────────
	field._spawn_enemy(mook_data)
	await get_tree().process_frame
	var mook = null
	for e in field.get_enemies():
		if not e.is_dead and e.enemy_type != "boss" and e.enemy_name == str(mook_data.get("name", "")):
			mook = e
			break
	check(mook != null, "대조군 잡몹을 못 찾았다 (%s)" % str(mook_data.get("name", "?")), "S3")

	var sig_mook := []
	var snd_mook := []
	var text_mook := []
	var mook_type := ""
	var mook_gold := 0
	if mook != null:
		mook_type = mook.enemy_type
		mook_gold = int(mook.gold_reward)
		var before_mook := _child_ids(field)
		SoundEngine._cached_streams.clear()
		SoundEngine._last_played_msec.clear()
		mook.take_damage(HUGE, false)
		sig_mook = _signature(field, before_mook)
		text_mook = _added_label_texts(field, before_mook)
		snd_mook = SoundEngine._cached_streams.keys()
		snd_mook.sort()
		print("BOSS_DEATH mook type=%s gold=%d texts=%s sig=%s sounds=%s" % [
			mook_type, mook_gold, str(text_mook), str(sig_mook), str(snd_mook)])

	# ── §5 비공허성 — 재기 전에 '재고 있는가' 부터 단언한다 ──────────────────
	check(boss_type == "boss", "죽인 것이 보스가 아니다 (%s)" % boss_type, "S5")
	check(mook_type != "" and mook_type != "boss", "대조군이 잡몹이 아니다 (%s)" % mook_type, "S5")
	check(not sig_boss.is_empty(), "보스 처치가 아무 표현도 만들지 않았다 — §3 이 공허하다", "S5")
	check(not sig_mook.is_empty(), "잡몹 처치가 아무 표현도 만들지 않았다 — §3 이 공허하다", "S5")
	check(not snd_boss.is_empty(), "보스 처치가 아무 소리도 내지 않았다 — §3 의 소리 비교가 공허하다", "S5")
	check(not snd_mook.is_empty(), "잡몹 처치가 아무 소리도 내지 않았다 — §3 의 소리 비교가 공허하다", "S5")
	check(not text_boss.is_empty(), "보스 처치에 골드 텍스트가 없다 — §4 의 비교가 공허하다", "S5")

	# ── §3 본 단언 ───────────────────────────────────────────────────────────
	# ⚠️ **시각과 소리를 따로 단언한다.** §5.2 30 (A) 는 **소리만** 바꿨고, 그 뒤
	#    **§2.2(2026-10-03)가 파편 색을 적 종류에 묶어** 보스 파편을 빨강으로 만들었다.
	#    그래서 지금의 계약은 **셋**이다 — 라벨·폰트·z = **공유**, 파편 색 = **다름**, 소리 = **다름**.
	#    하나로 묶어 '다르다' 를 주장하면 과장이고, 하나로 묶어 '같다' 를 주장하면 고침을 못 본다.
	#
	#   ⚠️ 2026-10-03 이전에는 `sig_boss == sig_mook` 이었다 — 그 단언은 *"보스 처치의 시각
	#      서명이 잡몹과 같다"* 는 **당시의 한계**를 못 박은 것이었고, §2.2 가 그 한계를
	#      **부분적으로 없앴다**(§2.4 문제점 6 의 *"시각 서명은 여전히 같다"* 가 이제 거짓).
	#      한계가 사라졌으니 단언을 **한계 쪽으로** 다시 쓴다 — 느슨하게 푸는 게 아니다.
	check(_sig_without_debris_color(sig_boss) == _sig_without_debris_color(sig_mook),
		"파편 색 **말고** 다른 시각 차이가 생겼다 — 색은 §2.2 규칙이 만든 것이고 나머지는 공유돼야 한다.\n  boss=%s\n  mook=%s"
			% [str(_sig_without_debris_color(sig_boss)), str(_sig_without_debris_color(sig_mook))], "S3")
	check(sig_boss != sig_mook,
		"보스 처치의 시각 서명이 잡몹과 **완전히 같다** — §2.2 의 적 종류 파편 색이 보스에 닿지 않았다.\n  boss=%s\n  mook=%s"
			% [str(sig_boss), str(sig_mook)], "S3")
	# ✅ **§5.2 30 (A) 고침 (2026-10-01)** — 예전 이 단언은 `snd_boss == snd_mook` 이었고
	#    그것이 결함의 기록이었다(*"보스 처치가 잡몹과 같은 소리를 낸다"*). 뒤집는다.
	check(snd_boss != snd_mook,
		"보스 처치음이 잡몹과 **같다**(%s) — §5.2 30 (A) 의 전용 처치음이 죽었다.\n  boss=%s\n  mook=%s" % [
			str(snd_boss), str(snd_boss), str(snd_mook)], "S3")
	# ⚠️ '다르다' 만으로는 부족하다 — **어떤** 소리인지까지 못 박는다. 둘 다 바뀌면
	#    '다르다' 는 여전히 참이라 위 단언이 통과해 버린다(§2.21 K13 의 *개수 vs 내용*).
	check(snd_boss == ["boss_death"],
		"보스 처치음이 `boss_death` 가 아니다 (%s)" % str(snd_boss), "S3")
	check(snd_mook == ["coin"],
		"잡몹 처치음이 `coin` 이 아니다 (%s) — 보스만 바뀌어야 한다" % str(snd_mook), "S3")

	# ── §4 **실제로 다른 것** — 숨기지 않는다 ────────────────────────────────
	check(boss_gold > mook_gold,
		"보스 골드(%d)가 잡몹(%d)보다 크지 않다 — 보상의 양 자체가 무너졌다" % [boss_gold, mook_gold], "S4")
	print("BOSS_DEATH differs gold %d vs %d (x%.1f) · text %s vs %s" % [
		boss_gold, mook_gold, float(boss_gold) / maxf(1.0, float(mook_gold)),
		str(text_boss), str(text_mook)])

	# 보스 체력바는 처치 후 사라진다 — 이것도 **표현**이다. `queue_free()` 는 지연이라
	# 두 프레임을 기다린 뒤 센다(`_update_boss_bar` 가 죽은 보스를 보고 치운다).
	await get_tree().process_frame
	await get_tree().process_frame
	var bar_after := _count_named(field, "BossBar")
	print("BOSS_DEATH bar_after_kill=%d" % bar_after)
	check(bar_after == 0, "보스 처치 후에도 체력바가 %d개 남아 있다" % bar_after, "S4")

	# ── §6 겹침 가드 — 웨이브를 끝내는 보스 처치는 제 소리를 내지 않는다 ─────────
	# `_death_clears_wave()` 가 참이면 `_on_wave_cleared()` → `_grant_round_reward()` 가
	# 곧 **막 클리어 팡파르**(`play_victory` · 3막이면 런 승리음)를 **같은 순간에** 낸다.
	# 여기서 `boss_death`(0.70초)까지 내면 이름이 달라 스로틀을 통과해 **합산**되고
	# (그래서 `_last_played_msec` 로는 못 막는다) 팡파르가 뭉개진다 —
	# `_grant_round_reward` 가 `play_victory` 를 끄는 것과 **같은 판단**이다.
	#
	# ⚠️ **실제 상태로 잰다** — 헬퍼를 직접 부르지 않고 `current_wave` 를 마지막 웨이브로
	#    올린 뒤 보스를 **실제로 죽인다**. 그래야 `_on_enemy_died` 의 분기를 지난다.
	#    (헬퍼만 부르면 *"가드가 맞게 계산되는가"* 만 재고 *"분기가 그걸 쓰는가"* 는 못 잰다.)
	var boss_data: Dictionary = MonsterRoster.boss_entry(1, BOSS_WAVE, base_hp, 1.0, 1.0, INTERVAL)
	field.current_wave = DefenseField.MAX_WAVES_PER_ACT
	field.spawn_queue.clear()
	for leftover in field.get_enemies():
		leftover.take_damage(HUGE, false)     # '마지막 적' 조건을 만든다
	await get_tree().process_frame
	field._spawn_enemy(boss_data)
	await get_tree().process_frame
	var guard_boss = _first_boss(field)
	check(guard_boss != null, "§6 용 보스를 못 만들었다 — 겹침 가드를 못 잰다", "S6")
	if guard_boss != null:
		SoundEngine._cached_streams.clear()
		SoundEngine._last_played_msec.clear()
		guard_boss.take_damage(HUGE, false)
		var snd_guard := SoundEngine._cached_streams.keys()
		snd_guard.sort()
		# ⚠️ **죽인 뒤에 묻는다.** `get_enemies()` 는 `is_dead` 를 빼므로, 죽기 전에 물으면
		#    죽는 적 **자신이 목록에 남아** 거짓이 나온다 — 그건 `_on_enemy_died` 가 본 값이
		#    아니다. 첫 판이 정확히 이걸로 빨개졌다(`clears=false` 인데 `sounds=[]` 라는
		#    모순 — 가드는 작동했는데 전제 검사만 틀린 자리에서 물었다).
		#    → **전제를 물을 때는 코드가 묻는 시점과 같은 시점에 물어라.**
		var guard_clears: bool = bool(field._death_clears_wave())
		print("BOSS_DEATH guard wave=%d clears=%s sounds=%s enemies_left=%d" % [
			field.current_wave, str(guard_clears), str(snd_guard), field.get_enemies().size()])
		# 전제 — 정말 '웨이브를 끝내는' 상태였는가. 아니면 이 절은 **공허**하다.
		check(guard_clears,
			"`_death_clears_wave()` 가 거짓이다(wave=%d) — §6 의 전제가 안 만들어졌다" % field.current_wave, "S6")
		check(not snd_guard.has("boss_death"),
			"웨이브를 끝내는 보스 처치가 `boss_death` 를 냈다(%s) — 팡파르와 합산된다" % str(snd_guard), "S6")
		# ⚠️ **양성 대조는 §3 이 한다** — 같은 보스를 wave 5 에서 죽이면 `boss_death` 가 난다.
		#    그래서 이 절은 '아무 소리도 안 났다' 로 통과해도 공허하지 않다.
		check(snd_guard.is_empty(),
			"웨이브를 끝내는 보스 처치가 다른 소리까지 냈다(%s)" % str(snd_guard), "S6")

	if failures == 0:
		print("BOSS_DEATH_FIXED 보스 처치음이 잡몹과 구별된다(`boss_death`) — §5.2 30 (A) · 시각은 **파편 색만** 다르다(§2.2, 2026-10-03)")
		print("BOSS_DEATH_PROBE_OK")
	get_tree().quit(failures)
