extends Node
# 같은 소리가 **한 프레임에 여러 번** 요청될 때 겹쳐 커지는지 잰다 (§5.1 항목 5, 2026-09-23).
#
# 왜 문제인가:
# `SoundEngine._get_player()` 는 **재생 중이 아닌** 플레이어를 준다. 그래서 같은 소리를 한
# 프레임에 5번 부르면 **5개 플레이어가 같은 파형을 동시에** 재생한다 — 파형이 같으므로 위상까지
# 맞아 **단순 합산**되고, `20*log10(5)` = **+14 dB** 가 된다. 저작된 음량이 아니라 "그 순간 몇
# 마리를 맞혔는가" 가 음량을 정하게 된다.
#
# 실재하는 경로 (추론이 아니라 코드로 확인):
#   `Meteor._impact()` 가 폭발 반경 안의 **모든 적**을 순회하며
#   `enemy.take_damage(damage * mult, true, mult)` 를 부른다 — 두 번째 인자가 소리 켬이다.
#   적 5마리를 맞히면 한 프레임에 `SoundEngine.play_hit()` 이 5번이다.
#   (`Projectile` 의 광역은 `false` 로 꺼 두었으므로 그쪽은 해당 없다)
#
# ⚠️ 이 도구가 **반드시** 재야 하는 것 셋 (한쪽만 재면 반쪽짜리 검사다):
#   · 겹칠 때 **하나로 접히는가** (§1 직접, §2 실제 메테오 경로)
#   · 접기가 **정상 반복까지 죽이지는 않는가** (§3 시간차 반복은 둘 다 살아야 한다,
#     §4 서로 다른 소리는 서로를 막지 않아야 한다)
#   · **피치 지터가 실제로 걸리는가** (§5) — 이게 없으면 `pitch_scale` 한 줄을 지워도
#     검사가 통과한다. 계약은 두 줄인데 검사가 한 줄만 지키면 반쪽이다.
#   §3·§4 가 없으면 "소리를 통째로 끄는" 고침도 통과한다.
#   §5 가 없으면 "스로틀만 넣고 지터는 안 넣은" 고침도 통과한다.
#
# 실행: godot --headless --path . res://tools/SfxStackProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")
const WordTowerScene = preload("res://scenes/tower/WordTower.tscn")

const HIT := "hit"
const ATTACK := "attack"

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

## 특정 스트림을 **지금 재생 중인** 플레이어 수. 겹침의 직접 증거다.
func _playing(stream_name: String) -> int:
	var s = SoundEngine._cached_streams.get(stream_name)
	if s == null:
		return 0
	var n := 0
	for p in SoundEngine._players:
		if p.playing and p.stream == s:
			n += 1
	return n

## 모든 플레이어가 재생을 마칠 때까지 기다린다.
## 다음 절이 **앞 절의 소리를 세지 않도록** 매 절 앞에서 부른다(기준선 고정).
func _drain() -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		var busy := false
		for p in SoundEngine._players:
			if p.playing:
				busy = true
				break
		if not busy:
			return
		await get_tree().process_frame

## 특정 스트림을 재생 중인 플레이어의 `pitch_scale`. 없으면 -1.
## **재생 중인 플레이어에서 읽는다** — 스로틀·지터가 "어느 플레이어에 걸렸는가" 와
## 무관하게 실제로 소리에 반영됐는지를 재야 하기 때문이다.
func _pitch_of(stream_name: String) -> float:
	var s = SoundEngine._cached_streams.get(stream_name)
	if s == null:
		return -1.0
	for p in SoundEngine._players:
		if p.playing and p.stream == s:
			return p.pitch_scale
	return -1.0

## 잠금 창보다 확실히 긴 시간을 번다. `_drain()` 도 보통은 창을 넘기지만(소리 길이만큼
## 기다리므로), 그건 **소리 길이에 기대는** 우연이다 — 길이가 짧아지면 조용히 깨진다.
## 여기서는 명시적으로 번다.
func _past_throttle_window() -> void:
	await get_tree().create_timer(0.08).timeout

func _ready() -> void:
	# ⚠️ 플레이어 설정이 `muted` 면 소리는 합성조차 되지 않아 아무것도 재지 못한다.
	# 필드 직접 대입이라 `_save_config()` 를 지나지 않는다 — 설정 파일은 안전하다.
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
	check(not field.is_wave_running, "기준선 잡기 실패 — 이미 웨이브가 돌고 있다")

	# ── 0. 기준선 ────────────────────────────────────────────────────────────
	await _drain()
	print("SFX_PROBE baseline hit=%d attack=%d" % [_playing(HIT), _playing(ATTACK)])
	check(_playing(HIT) == 0, "기준선에 이미 hit 이 재생 중이다")

	# ── 1. 직접: 한 프레임에 같은 소리를 5번 ─────────────────────────────────
	await _drain()
	for i in range(5):
		SoundEngine.play_hit()
	await get_tree().process_frame
	var stacked := _playing(HIT)
	print("SFX_PROBE direct_5x playing=%d" % stacked)
	check(stacked == 1,
		"같은 소리를 한 프레임에 5번 부르니 %d개 플레이어가 동시에 재생한다 (1이어야 한다) — 합산되어 +%.1f dB" % [
			stacked, 20.0 * log(maxf(1.0, float(stacked))) / log(10.0)])

	# ── 2. 실제 경로: 메테오가 여러 적을 한 번에 맞힌다 ──────────────────────
	await _drain()
	var spawned := 0
	for i in range(5):
		field._spawn_enemy(MonsterRoster.regular_entry(1, i, 10.0, 1.0, 1.0))
		spawned += 1
	await get_tree().process_frame
	await get_tree().process_frame
	# ⚠️ `field` 는 무타입(`main.defense_field`)이라 `get_enemies()` 의 반환형을 추론할 수 없다 —
	# `:=` 를 쓰면 "Cannot infer the type" 파싱 오류로 **스크립트가 통째로 로드되지 않는다**.
	var enemies: Array = field.get_enemies()
	check(enemies.size() >= 2,
		"적이 %d마리뿐이다 — 한 프레임 다중 타격을 재려면 2마리 이상 필요하다" % enemies.size())

	# 타워는 **씬에서** 만든다. `WordTower.new()` 는 자식 노드가 없어 `_ready()` 의
	# `@onready` 6개가 실패한다(`tests/test_wave_balance.gd:1806` 의 교훈).
	var tower: WordTower = WordTowerScene.instantiate()
	tower.setup_tower("가", {"category": "magic", "damage": 4, "is_unknown": true}, field)

	var meteor: Meteor = Meteor.new()
	# 반경을 크게 잡아 **모든** 적이 범위에 들어오게 한다 — 그래야 다중 타격이 확실하다.
	meteor.setup(1.0, 4000.0, tower)
	meteor.global_position = enemies[0].global_position
	field.add_child(meteor)
	await get_tree().process_frame
	meteor._impact()
	await get_tree().process_frame
	var meteor_players := _playing(HIT)
	print("SFX_PROBE meteor enemies=%d playing=%d" % [enemies.size(), meteor_players])
	check(meteor_players == 1,
		"메테오가 적 %d마리를 한 프레임에 맞히며 hit 을 %d번 재생했다 (1이어야 한다)" % [
			enemies.size(), meteor_players])

	meteor.queue_free()
	tower.free()
	field.reset_combat_state()
	await get_tree().process_frame

	# ── 3. 정상 반복은 죽이면 안 된다 (양방향 검사의 뒤쪽) ───────────────────
	# 잠금 창(50ms)보다 **긴** 간격의 반복은 둘 다 살아야 한다.
	await _drain()
	SoundEngine.play_hit()
	await _past_throttle_window()
	SoundEngine.play_hit()
	await get_tree().process_frame
	var spaced := _playing(HIT)
	print("SFX_PROBE spaced_80ms playing=%d" % spaced)
	check(spaced == 2,
		"80ms 간격의 정상 반복이 %d개만 재생됐다 (2개여야 한다) — 잠금이 너무 넓다" % spaced)

	# ── 4. 서로 다른 소리는 서로를 막으면 안 된다 ────────────────────────────
	await _drain()
	SoundEngine.play_hit()
	SoundEngine.play_attack()
	await get_tree().process_frame
	var h := _playing(HIT)
	var a := _playing(ATTACK)
	print("SFX_PROBE distinct hit=%d attack=%d" % [h, a])
	check(h == 1 and a == 1,
		"서로 다른 소리가 서로를 막았다 (hit=%d attack=%d, 각각 1이어야 한다)" % [h, a])

	# ── 5. 피치 지터가 실제로 걸리는가 ───────────────────────────────────────
	# 계약은 **두 줄**이다(최소 간격 + 피치 지터). 스로틀만 재면 `pitch_scale` 을 지워도
	# 통과한다 — 반쪽 검사다. 여기서 실제 재생된 플레이어의 `pitch_scale` 을 읽는다.
	#
	# ⚠️ "다르면 통과" 만으로는 부족하다. 지터가 **범위를 벗어나게** 커지면(예: ±40%)
	# 그건 소리가 아니라 변조다. 그래서 범위(0.96~1.04)와 변화를 **둘 다** 잰다.
	const PITCH_LO := 0.96
	const PITCH_HI := 1.04
	var samples: Array[float] = []
	for i in range(4):
		await _drain()
		await _past_throttle_window()
		SoundEngine.play_hit()
		await get_tree().process_frame
		var pitch := _pitch_of(HIT)
		samples.append(pitch)
		check(pitch >= PITCH_LO - 0.0001 and pitch <= PITCH_HI + 0.0001,
			"재생된 hit 의 pitch_scale 이 %.4f 다 — 지터 범위 %.2f~%.2f 를 벗어났다" % [
				pitch, PITCH_LO, PITCH_HI])

	var lo := samples[0]
	var hi := samples[0]
	for v in samples:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	print("SFX_PROBE pitch samples=%s lo=%.4f hi=%.4f" % [str(samples), lo, hi])
	check(hi - lo > 0.0005,
		"hit 을 4번 재생했는데 pitch_scale 이 전부 %.4f 로 같다 — 피치 지터가 없다" % lo)

	if failures == 0:
		print("SFX_STACK_PROBE_OK")
	get_tree().quit(failures)
