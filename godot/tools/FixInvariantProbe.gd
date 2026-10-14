# FixInvariantProbe.gd — 감사에서 ✅ 로 닫혔지만 **어떤 프로브도 지키지 않던** 고침의 회귀 가드.
#
#   godot --headless --path . res://tools/FixInvariantProbe.tscn
#
# 왜 필요한가: 감사 절 49개 중 프로브/도구를 댄 것은 41개다. 나머지 8개 중 넷은 `####` 하위
# 절이라 **부모 절의 프로브**가 지킨다 —
#   배속 키 목록 → TooltipTruthProbe · §2.19-2 → CounterThresholdProbe ·
#   §2.21-5 → CritSignalProbe · 결정 당시의 선택지 → BaseHitSignalProbe.
# **정말 아무도 안 지키는 것은 넷뿐**이다:
#
#   §2.1  사장 필드 `is_aoe`/`aoe_radius` 제거
#   §2.3  HP 바가 `Juice.approach` 를 지난다(즉시 대입이 아니다)
#   §6.6  적 사망 연출 — 죽는 **그 프레임에** 사라지지 않는다
#   §6.7  bounce 회전이 실제로 돈다 · 명중에 섬광이 생긴다
#
# 이 넷은 **한 번 재고 끝났다** — §6.6·§6.7 은 픽셀 캡처(`FrameStrip`), §2.1·§2.3 은 grep.
# 캡처 도구는 판정(`quit(실패수)`)을 안 하고, grep 은 다시 안 돌린다. 그래서 **되돌려도
# 아무도 모른다.** 이 프로브가 그 자리를 막는다.
#
# ⚠️ 소스를 읽는 절(S1·S2a·S2b)에도 **양성 대조**를 둔다 — 스캐너가 안 돌면 "0건" 이 공허해진다.
# ⚠️ S2c·S3·S4 는 소스를 안 읽고 **행동을 잰다**(바를 감쇠시키고, 적을 죽이고, 투사체를 돌린다).
#
# 주의: `tools/` 아래라 `SaveManager._is_test_run()` 이 자동으로 참이다(`SaveManager.gd:26`).
extends Node2D

const WordTowerScene = preload("res://scenes/tower/WordTower.tscn")
const EnemyUnitScene = preload("res://scenes/tower/EnemyUnit.tscn")
const ProjectileScene = preload("res://scenes/tower/Projectile.tscn")

## §2.3c — 감쇠가 '따라가는가' 를 재는 값. `rate=16` · 한 스텝 0.016초.
const APPROACH_STEP := 0.016
## 감쇠가 '안 움직임' 도 '점프' 도 아님을 가르는 경계(0 < v < 100).
const BAR_START := 100.0

## 소스 스캔 **비공허성 하한** — `res://scripts` 의 `.gd` 는 30개다(2026-10-04 실측).
## ⚠️ 이 수는 센서스가 아니라 **스캐너가 실제로 돌았는지** 를 보는 하한이다.
##    (첫 판에서 40 으로 잡았다가 30 개를 보고 거짓 빨강이 났다 — 하한은 실측에서 와야 한다.)
const MIN_SOURCE_FILES := 25

var _failures := 0
var _sources: Dictionary = {}   # "res://scripts/…" → 파일 전문


class StubField extends Node:
	var relic_ids: Array = []
	var enemies: Array = []

	func has_relic(id: String) -> bool:
		return relic_ids.has(id)

	func get_enemies() -> Array:
		return enemies

	func record_tower_damage(_tower_name: String, _amount: float) -> void:
		pass


## 실패하면 세고, 이유를 콘솔에 찍는다. (push_error 는 'ERROR:' 로 찍힌다 — 정상이다)
func check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


## `res://scripts` 의 모든 `.gd` 를 메모리에 올린다(한 번만).
func _load_sources() -> void:
	_sources.clear()
	var stack: Array = ["res://scripts"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		var da := DirAccess.open(d)
		if da == null:
			continue
		da.list_dir_begin()
		var fname := da.get_next()
		while fname != "":
			if fname != "." and fname != "..":
				var full := d.path_join(fname)
				if da.current_is_dir():
					stack.append(full)
				elif fname.ends_with(".gd"):
					var f := FileAccess.open(full, FileAccess.READ)
					if f != null:
						_sources[full] = f.get_as_text()
						f.close()
			fname = da.get_next()
		da.list_dir_end()


## 부분문자열이 나오는 **파일 목록**.
## ⚠️ 파일명을 키로 세면 '횟수' 가 아니라 '파일 수' 가 나온다 — 둘을 섞지 마라.
func _files_with(sub: String) -> Array:
	var out: Array = []
	for path in _sources.keys():
		if (_sources[path] as String).count(sub) > 0:
			out.append(path)
	return out


## 정규식에 맞는 줄이 있는 **파일 → 매치 수**.
func _regex_hits(pattern: String) -> Dictionary:
	var re := RegEx.new()
	re.compile(pattern)
	var out := {}
	for path in _sources.keys():
		var n := re.search_all(_sources[path] as String).size()
		if n > 0:
			out[path] = n
	return out


func _short(paths) -> String:
	var names: Array = []
	for p in paths:
		names.append((p as String).get_file())
	names.sort()
	return ", ".join(names)


func _ready() -> void:
	_load_sources()
	print("")
	print("=== 고침 불변식 — 프로브가 아무도 안 지키던 ✅ 넷 ===")
	print("소스 스캔: `res://scripts` 의 .gd %d개" % _sources.size())
	check(_sources.size() >= MIN_SOURCE_FILES, "S0 — 스캔한 파일이 %d개뿐이다(스캐너가 안 돌았다)" % _sources.size())

	_s1_dead_fields()
	_s2_approach()
	_s3_death()
	_s4_bounce()

	print("")
	if _failures == 0:
		print("FIX_INVARIANT_PROBE_OK")
	else:
		print("FIX_INVARIANT_PROBE_FAIL %d" % _failures)
	get_tree().quit(_failures)


## §2.1 — 사장 필드(`is_aoe`/`aoe_radius`)가 돌아오지 않았는가.
func _s1_dead_fields() -> void:
	print("")
	print("── S1 (§2.1) 사장 필드 ──")
	# 양성 대조: `func ` 는 모든 .gd 에 있다 — 스캐너가 살아 있음을 증명한다.
	var control := _files_with("func ")
	print("   대조(`func `): %d개 파일" % control.size())
	check(control.size() >= MIN_SOURCE_FILES, "S1 — 대조군이 %d개뿐이다(스캐너가 안 돌았다)" % control.size())
	for needle in ["is_aoe", "aoe_radius"]:
		var hits := _files_with(needle)
		print("   `%s`: %d개 파일" % [needle, hits.size()])
		check(hits.is_empty(), "S1 — §2.1 에서 지운 `%s` 가 다시 있다: %s" % [needle, _short(hits)])


## §2.3 — HP 바가 지수 감쇠(`Juice.approach`)를 지나는가. 즉시 대입이 돌아오지 않았는가.
func _s2_approach() -> void:
	print("")
	print("── S2 (§2.3) HP 바 감쇠 ──")
	# (a) 소스: 세 바가 같은 헬퍼를 부른다.
	var callers := _files_with("Juice.approach(")
	print("   `Juice.approach(` 호출 파일: %s" % _short(callers))
	check(callers.size() >= 3,
		"S2 — `Juice.approach(` 를 부르는 파일이 %d개다(적·보스·기지 셋이어야 한다)" % callers.size())
	var short_callers := _short(callers)
	for name in ["EnemyUnit.gd", "DefenseField.gd", "TowerDefenseMain.gd"]:
		check(short_callers.contains(name), "S2 — %s 가 `Juice.approach` 를 안 부른다" % name)
	# (b) 소스: Range.value 를 **트윈**으로 따라가게 하는 코드가 없다.
	#     트윈은 `Engine.time_scale` 을 타므로 배속마다 따라붙는 속도가 달라진다(§2.11 사고와 같은 뿌리).
	var control := _files_with("tween_property(")
	print("   대조(`tween_property(`): %d개 파일" % control.size())
	check(control.size() >= 1, "S2 — 대조군이 0개다(정규식이 안 돌았다)")
	var tweened := _regex_hits("tween_property\\s*\\([^\\n]*\"value\"")
	print("   `tween_property(…\"value\"…)`: %d개 파일" % tweened.size())
	check(tweened.is_empty(),
		"S2 — Range.value 를 트윈으로 따라가게 한다: %s (배속마다 속도가 달라진다)" % _short(tweened.keys()))
	# (c) 런타임: 감쇠가 '따라가는가' — 한 스텝에 목표로 점프하지 않는다.
	var bar := ProgressBar.new()
	bar.max_value = BAR_START
	bar.value = BAR_START
	add_child(bar)
	Juice.approach(bar, 0.0, APPROACH_STEP)
	var after_one: float = bar.value
	check(after_one > 0.0 and after_one < BAR_START,
		"S2 — 한 스텝에 %.1f 로 갔다(따라가지 않고 점프한다)" % after_one)
	for i in 200:
		Juice.approach(bar, 0.0, APPROACH_STEP)
	print("   런타임: %.0f → %.1f (한 스텝) → %.2f (200스텝)" % [BAR_START, after_one, bar.value])
	check(absf(bar.value) < 0.5, "S2 — 200스텝 뒤에도 %.2f 로 수렴하지 않았다" % bar.value)


## §6.6 — 적이 죽는 **그 프레임에** 사라지지 않고 지연 연출을 거치는가.
func _s3_death() -> void:
	print("")
	print("── S3 (§6.6) 적 사망 연출 ──")
	var const_hit := _files_with("DEATH_DURATION")
	print("   `DEATH_DURATION`: %s" % _short(const_hit))
	check(const_hit.size() >= 1, "S3 — `DEATH_DURATION` 이 사라졌다(즉시 `queue_free` 로 되돌아갔다)")

	var enemy = EnemyUnitScene.instantiate()
	add_child(enemy)
	enemy.init_enemy("probe", 10.0, 0.0, 0, "")
	var bar_before: bool = enemy.hp_bar.visible
	check(bar_before, "S3 — 대조: 살아 있는 적의 HP 바가 안 보인다(측정이 성립하지 않는다)")
	enemy.take_damage(999.0, false)
	print("   치명 피해 뒤: is_dead=%s · 큐 삭제=%s · hp_bar.visible=%s" % [
		enemy.is_dead, enemy.is_queued_for_deletion(), enemy.hp_bar.visible])
	check(enemy.is_dead, "S3 — 치명 피해인데 is_dead 가 아니다(측정이 성립하지 않는다)")
	check(not enemy.is_queued_for_deletion(),
		"S3 — 죽는 그 프레임에 사라졌다. 지연 연출(0.17초)이 되돌려졌다")
	check(not enemy.hp_bar.visible,
		"S3 — 죽은 적에 빈 HP 바가 남았다('0 인데 살아 있는' 것처럼 보인다)")


## §6.7 — bounce 투사체가 실제로 도는가 · 명중에 섬광이 생기는가.
func _s4_bounce() -> void:
	print("")
	print("── S4 (§6.7) bounce 회전 · 명중 섬광 ──")
	var imp := _files_with("_spawn_impact")
	print("   `_spawn_impact`: %s" % _short(imp))
	check(imp.size() >= 1, "S4 — `_spawn_impact` 가 사라졌다(명중 섬광이 없다)")

	var field := StubField.new()
	add_child(field)
	var tower = WordTowerScene.instantiate()
	add_child(tower)
	tower.setup_tower("볼", {"category": "weapon", "damage": 4, "is_unknown": true,
		"desc": "기본 활자 탄환."}, field)

	var target = EnemyUnitScene.instantiate()
	add_child(target)
	target.global_position = Vector2.ZERO
	target.init_enemy("probe", 100000.0, 0.0, 0, "")
	field.enemies.append(target)

	var layer := Node2D.new()
	add_child(layer)

	var proj = ProjectileScene.instantiate()
	layer.add_child(proj)
	proj.setup(target, 10.0, "bounce", "bounce", tower, 1.0)
	proj.global_position = Vector2(500.0, 0.0)

	check(proj.spin_speed != 0.0, "S4 — bounce 인데 spin_speed 가 0 이다")
	# ⚠️ "회전이 변했다" 로는 부족하다 — 진행 방향(`dir.angle()`)도 회전을 **바꾼다**.
	#    첫 판이 그렇게 썼다가 이 프로브 자신의 되돌림(I4)을 **못 잡았다**(회전 0 → π = 3.142).
	#    계약은 "변했다" 가 아니라 **"spin_speed × delta 만큼 돈다"** 다.
	var step := 0.1
	# ⚠️ `proj` 가 Variant 라 추론이 안 된다 — 명시해야 한다(첫 판이 파싱 에러로 스크립이 통째로 안 실렸다).
	var want: float = proj.spin_speed * step
	var r0: float = proj.sprite.rotation
	proj._process(step)
	var r1: float = proj.sprite.rotation
	proj._process(step)
	var r2: float = proj.sprite.rotation
	print("   회전: %.3f → %.3f → %.3f (스텝당 기대 +%.3f)" % [r0, r1, r2, want])
	check(absf((r1 - r0) - want) < 0.01,
		"S4 — 첫 스텝 증가가 %.3f 다(기대 %.3f = spin_speed×delta). 진행 방향이 덮고 있다" % [r1 - r0, want])
	check(absf((r2 - r1) - want) < 0.01,
		"S4 — 둘째 스텝 증가가 %.3f 다(기대 %.3f). 회전이 상수로 덮였다" % [r2 - r1, want])

	var before: int = layer.get_child_count()
	proj.hit_target()
	var after: int = layer.get_child_count()
	print("   명중 섬광: 부모 자식 %d → %d" % [before, after])
	check(after > before, "S4 — 명중했는데 섬광 노드가 안 생겼다")
