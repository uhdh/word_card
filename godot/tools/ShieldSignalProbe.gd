extends Node
# "방어도가 이 타격을 **전부** 먹었다" 는 사건이 **플레이어에게 어떻게 도달하는가** (§2.20, 2026-09-26 신규).
#
# ── 왜 이 사건인가 ──────────────────────────────────────────────────────────
# `EnemyUnit._damage_kind()` 는 세 번째 종류를 판정한다: 약점·내성 말고 **`shield`** —
# 방어도가 피해를 전부 삼켜 **HP 가 한 대도 안 깎인** 타격. 코드 주석이 그 이유를 적는다:
#
#   > '30' 이라고 떴는데 HP 는 그대로다. 실제로 HP 30 을 깎은 타격과 **완전히 똑같이**
#   > 보였다. 플레이어는 자기 타워가 잘 하고 있다고 읽는다.
#   > 'armored' 적은 방어도가 base_hp 의 0.8배, HP 가 1.5배다 — 바 전체의 약 35% 가
#   > 방어도다. 그래서 이 오해가 드문 일이 아니다.
#
# 즉 프로젝트가 **스스로 "흔들고 오해를 부르는 사건" 이라고 판정**한 자리다. 그래서
# 시각 채널이 붙었다(`Juice.damage_style("shield")` → `Palette.SHIELD` · 17px).
#
# ── 이 프로브가 재는 것 ─────────────────────────────────────────────────────
# 그런데 **이 사건을 위해 쓰인 소리가 있다** — `SoundEngine.play_shield()`.
# 예전에는 0.16초 · 180→340Hz **상승**음이었고, 게임 코드에서 **호출처가 0건**이었다.
#
#   S1  로직   — `_damage_kind` 가 'shield' 를 정확히 언제 돌려주는가 (실제 `take_damage` 경로)
#   S2  시각   — 화면에 실제로 만들어진 라벨이 'shield' 임을 **구별할 수 있는가**
#   S3  오디오 — 막은 타격이 **실제로 어떤 소리를 내는가** (런타임) + 그 소리가 연결됐는가 (정적)
#   S4  순서   — `hit` 와 `shield` 파형의 **길이·높낮이** (이 프로젝트의 '길이=강도' 규칙에 비추어)
#   S5  비공허성
#
# ## ✅ 고침 — 감독 선택 (B) 교체 → (C) 파형 재작성 (2026-10-01, §5.2 32)
#
# `EnemyUnit.take_damage()` 가 **막은 타격에 `hit` 대신 `shield` 를 낸다.**
# **새 소리 0 · 새 효과 0** — `play_shield` 는 이미 있던 파형이고, 그냥 주인을 얻었을 뿐이다.
#
#   ⚠️ **얹는 것이 아니라 교체다.** 스로틀이 **이름별**이라 `hit` 과 `shield` 는 서로를 막지
#      않고 풀 12개에서 **겹쳐 난다**(주입 J1 실측 `blocked_hit_plays=["hit","shield"]`).
#      그러면 막은 타격이 전투에서 가장 큰 소리가 된다.
#   ⚠️ **'맞았다' 는 접촉 정보가 사라진다** — 그래도 소리 자체는 나므로 "무음" 은 아니다.
#
# ## ✅ (C) — 파형을 **짧고 낮게** 다시 썼다 (2026-10-01)
#
# (B) 는 **겹침**만 없앴고 **길이 순서**는 그대로였다 — `shield`(0.16s)가 `hit`(0.12s)보다
# **길어서**, '길이=강도' 로 읽으면 *아무 일도 안 일어난 타격이 맞은 타격보다 세게* 들렸다.
# 감독이 (C) 를 골라 **0.09초 · 200→100Hz 하강**(사인)으로 다시 썼다. S4 가 이제 그 순서를
# **지킨다**(예전에는 반대를 단언하며 결함을 *기록*했다).
#
# ⚠️ **남은 것 — 접두어 없음.** 약점/내성은 피해 숫자에 단어가 붙는데 `shield` 는 색뿐이다
#    (S2 가 기록). 이건 별개 결정이다.
#
# 실행: godot --headless --path . res://tools/ShieldSignalProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")
const SOURCE_ROOT := "res://scripts"

var failures := 0

## 절 태그를 함께 찍는다 — 주입 표의 "걸린 절" 이 기계로 구분되어야 한다(§2.17).
func check(condition: bool, message: String, tag: String = "") -> void:
	if not condition:
		failures += 1
		print("FAIL_SECTION %s" % tag)
		push_error(message)

# ── 화면에 실제로 만들어진 피해 숫자를 읽는다 ────────────────────────────────
# `_damage_kind` 를 직접 부르지 않는다 — **플레이어가 보는 것**을 재야 하므로
# `take_damage()` 를 태우고 그 결과 라벨의 색·크기·글자를 읽는다.
func _number_ids() -> Dictionary:
	var out := {}
	for n in get_tree().get_nodes_in_group("damage_numbers"):
		out[n.get_instance_id()] = true
	return out

func _added_numbers(before: Dictionary) -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("damage_numbers"):
		if not before.has(n.get_instance_id()):
			out.append(n)
	return out

## 한 대 때리고, 그때 화면에 뜬 숫자 라벨을 돌려준다.
## `pool_numbers = false` 라 **동기적으로** 라벨이 만들어진다(프레임을 넘기지 않는다).
func _hit(e: EnemyUnit, shield: float, hp: float, amount: float, mult: float = 1.0) -> Dictionary:
	e.shield = shield
	e.hp = hp
	e.is_dead = false
	var before := _number_ids()
	e.take_damage(amount, false, mult)
	var added := _added_numbers(before)
	var style := {}
	if not added.is_empty():
		var lb: Label = added[added.size() - 1]
		style = {
			"text": lb.text,
			"size": lb.get_theme_font_size("font_size"),
			"color": lb.get_theme_color("font_color"),
		}
	return {"labels": added.size(), "style": style}

## `AudioStreamWAV` 의 부호 변화 횟수 — 파형이 '어두운지 밝은지' 를 한 수로 만든다.
## `tools/RerollSoundProbe.gd` 와 같은 방식이다(청취 수단이 없다 — 파형 데이터뿐).
func _zcr(w: AudioStreamWAV) -> int:
	if w == null:
		return 0
	var d := w.data
	var n := 0
	for i in range(1, d.size()):
		var a := int(d[i - 1]) - 128
		var b := int(d[i]) - 128
		if (a < 0 and b >= 0) or (a >= 0 and b < 0):
			n += 1
	return n

## `res://scripts` 를 재귀적으로 훑어 `needle` 이 나오는 **파일별** 횟수를 센다.
## 소스 텍스트를 읽는 이유: 호출처 0건을 **런타임 호출로 재면 이 프로브 자신이 호출처가 된다.**
func _scan_source(dir_path: String, needle: String, hits: Dictionary, skip_file: String = "") -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			_scan_source(full, needle, hits, skip_file)
		elif name.ends_with(".gd") and name != skip_file:
			var f := FileAccess.open(full, FileAccess.READ)
			if f != null:
				var text := f.get_as_text()
				f.close()
				# ⚠️ **주석을 먼저 뺀다**(2026-10-01) — 안 빼면 고침과 함께 단 *설명*
				#    (`play_shield` 를 쓴다 …)이 **호출로 세어져** 이 절이 거짓으로 초록이 된다.
				#    실측: §2.20 (B) 직후 `play_shield_calls=2` 였다 — 실제 호출은 1건이다.
				var n := 0
				for ln in text.split("\n"):
					n += _code_part(str(ln)).count(needle)
				if n > 0:
					hits[full] = n
		name = dir.get_next()
	dir.list_dir_end()

## 줄에서 **문자열 밖의** `#` 이후를 잘라낸다.
##
## ⚠️ `begins_with("#")` 만으로는 부족하다 — 그건 *줄 전체가 주석인 줄*만 거른다.
##    코드 줄 **끝**에 붙은 주석은 그대로 남아 호출로 세어진다.
## ⚠️ 문자열 안의 `#`(`"#A6B8F2"`)은 살려야 한다 — 무조건 자르면 진짜 호출을 놓친다.
func _code_part(line: String) -> String:
	var in_str := false
	var quote := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if in_str:
			if c == "\\":
				i += 2
				continue
			if c == quote:
				in_str = false
		else:
			if c == "\"" or c == "'":
				in_str = true
				quote = c
			elif c == "#":
				return line.substr(0, i)
		i += 1
	return line


func _ready() -> void:
	SoundEngine.muted = true
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
	check(not field.is_wave_running, "기준선 잡기 실패 — 이미 웨이브가 돌고 있다", "S0")

	# ── S0 기준선 — 이 사건이 실제로 어떤 수치를 갖는가 ──────────────────────
	# ⚠️ `regular_entry()` 는 **명단 항목의 type 으로** shield 를 계산한다. 그래서 반환된
	#    dict 의 `type` 을 나중에 덮어쓰면 **방어도가 0 인 중갑**이 나온다(첫 판이 그랬다).
	#    명단에서 `armored` 의 **색인**을 찾아 그 색인으로 뽑아야 한다.
	var armored_index := -1
	var roster: Array = MonsterRoster.entries_for(1)
	for i in range(roster.size()):
		if str(roster[i].get("type", "")) == "armored":
			armored_index = i
			break
	check(armored_index >= 0, "1막 명단에 중갑이 없다 — 이 프로브는 아무것도 재지 않는다", "S0")
	if armored_index < 0:
		get_tree().quit(failures)
		return

	var hp_scale: float = field.hp_compensation_for(1, 1)
	var base_hp := (10.0 + 1.0 * 4.0) * hp_scale
	var sample: Dictionary = MonsterRoster.regular_entry(1, armored_index, base_hp, 1.0, 1.0)
	field._spawn_enemy(sample)
	await get_tree().process_frame

	var e: EnemyUnit = null
	var enemies: Array = field.get_enemies()
	if not enemies.is_empty():
		e = enemies[enemies.size() - 1]
	check(e != null, "표본 중갑이 스폰되지 않았다 — 이 프로브는 아무것도 재지 않는다", "S0")
	if e == null:
		get_tree().quit(failures)
		return

	var real_shield: float = e.shield
	var real_hp: float = e.hp
	var bar := real_shield + real_hp
	print("SHIELD_SIGNAL baseline armored shield=%.1f hp=%.1f bar=%.1f shield_share=%.3f" % [
		real_shield, real_hp, bar, real_shield / maxf(0.01, bar)])
	check(real_shield > 0.0, "중갑인데 방어도가 0 이다 — 이 사건이 존재할 수 없다", "S0")
	# 코드 주석이 주장하는 비율("바 전체의 약 35%")을 **실제 수치로** 확인한다.
	check(absf(real_shield / maxf(0.01, bar) - 0.8 / 2.3) < 0.01,
		"방어도 비율이 주석의 0.8/2.3 과 다르다 (%.3f)" % (real_shield / maxf(0.01, bar)), "S0")

	# ── S1 로직 — 'shield' 는 정확히 언제인가 ────────────────────────────────
	# 경계가 계약이다: `absorbed >= amount` 이므로 **정확히 같을 때도** shield 다.
	var full := _hit(e, 30.0, 100.0, 12.0)      # 전부 흡수
	var exact := _hit(e, 30.0, 100.0, 30.0)     # 정확히 소진
	var over := _hit(e, 30.0, 100.0, 45.0)      # 부분 흡수(15 가 HP 로)
	var none := _hit(e, 0.0, 100.0, 12.0)       # 방어도 없음
	var zero := _hit(e, 30.0, 100.0, 0.0)       # 0 피해
	var weak := _hit(e, 30.0, 100.0, 12.0, 1.5) # 약점 배율이어도 전부 흡수면 shield
	print("SHIELD_SIGNAL logic full=%s exact=%s over=%s none=%s zero_labels=%d weak=%s" % [
		str(full["style"].get("color")), str(exact["style"].get("color")),
		str(over["style"].get("color")), str(none["style"].get("color")),
		int(zero["labels"]), str(weak["style"].get("color"))])

	var shield_color: Color = Juice.damage_style(1.0, "shield")["color"]
	check(full["style"].get("color") == shield_color, "전부 흡수인데 'shield' 색이 아니다", "S1")
	check(exact["style"].get("color") == shield_color, "정확히 소진인데 'shield' 색이 아니다", "S1")
	check(over["style"].get("color") != shield_color,
		"부분 흡수인데 'shield' 로 찍혔다 — HP 가 실제로 깎였으므로 거짓말이다", "S1")
	check(none["style"].get("color") != shield_color, "방어도 0 인데 'shield' 로 찍혔다", "S1")
	check(int(zero["labels"]) == 0, "0 피해인데 숫자가 떴다", "S1")
	check(weak["style"].get("color") == shield_color,
		"약점 타격이 전부 흡수됐는데 'shield' 가 아니다 — 주석의 계약과 다르다", "S1")

	# ── S2 시각 채널 — 라벨만 보고 'shield' 임을 알 수 있는가 ────────────────
	var normal_style: Dictionary = Juice.damage_style(12.0, "normal")
	var weak_style: Dictionary = Juice.damage_style(12.0, "weak")
	var resist_style: Dictionary = Juice.damage_style(12.0, "resist")
	var shield_style: Dictionary = Juice.damage_style(1.0, "shield")
	print("SHIELD_SIGNAL visual shield=%s size=%d prefix=\"%s\" text=\"%s\"" % [
		str(shield_color), int(shield_style["size"]), str(shield_style["prefix"]),
		str(full["style"].get("text"))])
	print("SHIELD_SIGNAL visual normal=%s size=%d · weak prefix=\"%s\" · resist prefix=\"%s\"" % [
		str(normal_style["color"]), int(normal_style["size"]),
		str(weak_style["prefix"]), str(resist_style["prefix"])])
	var dist := absf(shield_color.r - normal_style["color"].r) \
		+ absf(shield_color.g - normal_style["color"].g) \
		+ absf(shield_color.b - normal_style["color"].b)
	print("SHIELD_SIGNAL visual color_distance=%.3f size_delta=%d" % [
		dist, int(shield_style["size"]) - int(normal_style["size"])])
	check(dist > 0.05, "shield 색이 평범한 숫자와 구별되지 않는다 (거리 %.3f)" % dist, "S2")
	# ⚠️ 색이 **유일한** 단어 없는 채널이다 — 약점/내성은 접두어를 갖는다.
	check(str(weak_style["prefix"]) != "" and str(resist_style["prefix"]) != "",
		"약점/내성에 접두어가 없다 — 이 비교의 전제가 무너진다", "S2")
	# ⚠️ `shield` 의 접두어 없음은 **미완이 아니라 규칙**이다(`Juice.damage_style` 독스트링 —
	#   *"두 종류(약점/내성)만 이름과 색을 갖는다"*: **접두어 = 관계, 색·크기 = 사건**).
	#   감사가 이걸 *잔여* 로 적어 둔 것을 2026-10-03 에 정정했다 — 프로브가 옳았다.
	check(str(shield_style["prefix"]) == "",
		"shield 에 접두어가 생겼다 — 규칙(접두어 = 관계)을 바꾼 것이라면 감사의 잔여 목록도 함께 갱신하라", "S2")

	# ── S3 오디오 — 막은 타격이 실제로 어떤 소리를 내는가 ────────────────────
	# 런타임 측정: 게임의 **기본 경로**(`show_hit_sound = true`)로 한 대 때리고,
	# 실제로 재생이 **허용된** 소리 이름을 읽는다. `_last_played_msec` 을 비우면
	# 50ms 스로틀도 함께 초기화되므로 "이 타격이 낸 소리" 만 남는다.
	SoundEngine.muted = false
	SoundEngine._last_played_msec.clear()
	e.shield = 30.0
	e.hp = 100.0
	e.is_dead = false
	e.take_damage(12.0, true, 1.0)
	var played: Array = SoundEngine._last_played_msec.keys()
	played.sort()
	print("SHIELD_SIGNAL runtime blocked_hit_plays=%s" % str(played))
	# ✅ §2.20 (B) 고침(2026-10-01) — 막은 타격은 이제 `shield` **만** 낸다.
	check(played == ["shield"], "막은 타격은 `shield` 만 낸다 (실측 %s)" % str(played), "S3")
	check(not played.has("hit"),
		"⚠️ 막은 타격이 `hit` 도 낸다 — 스로틀이 이름별이라 둘이 겹친다(§2.20 J1)", "S3")

	# ⚠️ **`hit` 파형도 캐시에 올려야 한다**(2026-10-01) — 막은 타격은 이제 `hit` 을 내지
	#    않으므로, 위 한 대만으로는 `_cached_streams["hit"]` 이 **없고** S4 의 길이 비교가
	#    `0.00s` 로 **공허**해진다(실측: 그렇게 처음에 걸렸다). **막히지 않은** 타격을 한 번 더 태운다.
	SoundEngine._last_played_msec.clear()
	e.shield = 0.0
	e.hp = 100.0
	e.is_dead = false
	e.take_damage(12.0, true, 1.0)
	var unblocked: Array = SoundEngine._last_played_msec.keys()
	unblocked.sort()
	print("SHIELD_SIGNAL runtime unblocked_hit_plays=%s" % str(unblocked))
	check(unblocked == ["hit"], "막히지 않은 타격은 `hit` 을 낸다 (실측 %s)" % str(unblocked), "S3")

	# 파형 자체는 존재하는가
	SoundEngine._last_played_msec.clear()
	SoundEngine.play_shield()
	await get_tree().process_frame
	var hit_wav: AudioStreamWAV = SoundEngine._cached_streams.get("hit", null)
	var shield_wav: AudioStreamWAV = SoundEngine._cached_streams.get("shield", null)
	check(hit_wav != null, "`hit` 파형이 만들어지지 않았다", "S3")
	check(shield_wav != null, "`shield` 파형이 만들어지지 않았다", "S3")

	# 정적 측정: 게임 코드 안에서 `play_shield` 를 부르는 곳이 있는가.
	var live: Dictionary = {}
	_scan_source(SOURCE_ROOT, "play_shield", live, "SoundEngine.gd")
	var live_calls := 0
	for k in live:
		live_calls += int(live[k])
	print("SHIELD_SIGNAL static play_shield_calls=%d %s" % [live_calls, str(live.keys())])
	# ⚠️ **정확히 1건이다** — `>= 1` 로 두면 **주석에 적힌 이름**이 호출로 세어져도 통과한다.
	#    `_scan_source` 가 `_code_part()` 로 주석을 빼는지가 이 수 하나에 걸려 있다(실측: 안 빼면 2).
	check(live_calls == 1,
		"게임 코드가 `play_shield` 를 **정확히 1곳**에서 부른다 (측정 %d) — 주석을 세고 있거나, 연결이 끊겼다"
			% live_calls, "S3")

	# 같은 스캔으로 **게임 코드 안의 고아 소리 전체**를 센다.
	var se_text := ""
	var se_file := FileAccess.open("res://scripts/core/SoundEngine.gd", FileAccess.READ)
	if se_file != null:
		se_text = se_file.get_as_text()
		se_file.close()
	var all_play: Array = []
	var re := RegEx.new()
	re.compile("^func\\s+(play_[A-Za-z0-9_]+)\\s*\\(")
	for line in se_text.split("\n"):
		var m := re.search(line)
		if m != null:
			all_play.append(m.get_string(1))
	var orphans: Array = []
	for fn in all_play:
		var hits: Dictionary = {}
		_scan_source(SOURCE_ROOT, str(fn), hits, "SoundEngine.gd")
		var total := 0
		for k in hits:
			total += int(hits[k])
		if total == 0:
			orphans.append(str(fn))
	print("SHIELD_SIGNAL inventory play_funcs=%d orphans_in_game=%s" % [all_play.size(), str(orphans)])
	check(all_play.size() >= 15,
		"`play_*` 를 %d개만 찾았다 — 정규식이 소스를 못 읽고 있다" % all_play.size(), "S5")
	check(not orphans.has("play_shield"),
		"⚠️ `play_shield` 가 다시 고아다 — §2.20 (B) 의 연결이 끊겼다 (고아 %s)" % str(orphans), "S3")

	# ── S4 순서 — 파형의 길이·높낮이가 사건의 강도와 맞는가 ──────────────────
	if hit_wav != null and shield_wav != null:
		print("SHIELD_SIGNAL wave hit=%.3fs zcr=%d | shield=%.3fs zcr=%d" % [
			hit_wav.get_length(), _zcr(hit_wav),
			shield_wav.get_length(), _zcr(shield_wav)])
		check(shield_wav.get_length() > 0.0, "`shield` 파형 길이가 0 이다", "S4")
		# ⚠️ 이 프로젝트의 규칙은 **"길이 순서 = 강도 순서"** 다(§오디오 불변식).
		#    `hit` 는 **맞은** 타격, `shield` 는 **아무 일도 안 일어난** 타격이다.
		# ✅ **§5.2 32 (C) 고침 (2026-10-01)** — 예전에는 이 단언이 **반대**(`shield > hit`)였고
		#    그것이 결함의 *기록* 이었다. 감독이 (C) 를 골라 파형을 0.09초로 다시 썼으므로,
		#    이제는 **고침을 지키는** 단언이다. 되돌리면(0.16초로) 빨개진다.
		check(shield_wav.get_length() < hit_wav.get_length(),
			"`shield`(%.3fs)가 `hit`(%.3fs)보다 **짧다** — 막은 타격이 맞은 타격보다 약하게 들린다(§5.2 32 (C))" % [
				shield_wav.get_length(), hit_wav.get_length()], "S4")
		# ⚠️ 길이만으로는 부족하다 — *"짧고 **낮게**"* 이므로 밝기도 함께 못 박는다.
		#    예전 파형(180→340Hz **상승**)의 zcr 은 **108** 이었다. 지금은 18 이다.
		#    천장을 `hit × 3`(=48)로 둔다 — **0.16초 전체 되돌림**(108)도 걸리고,
		#    **길이만 0.09초로 두고 주파수만 상승으로 되돌린 것**(61)도 걸린다.
		#    (첫 판은 `× 4`=64 였는데 **61 이 빠져나갔다** — 주입 K2 로 확인하고 조였다.)
		#    ⚠️ `hit`(16)과의 대소를 재는 것이 **아니다** — `hit` 은 40Hz 까지 내려가는 스윕이라
		#       평균 피치가 더 낮다. 여기서 재는 것은 *"다시 밝아지지 않았는가"* 하나다.
		check(_zcr(shield_wav) < _zcr(hit_wav) * 3,
			"`shield`(zcr %d)가 다시 밝아졌다 — 예전 상승 파형은 108 이었고 천장은 %d 다(§5.2 32 (C))" % [
				_zcr(shield_wav), _zcr(hit_wav) * 3], "S4")

	# ── S5 빈도 — 실제 수치로 몇 대가 'shield' 로 뜨는가 ─────────────────────
	# 한 대 피해 = `BASE_DAMAGE_BY_LENGTH` × 1.25(알려진 단어 보정). 모양·유물 배수는 뺀다
	# (그것들은 배수를 **키우므로** 여기 수는 보수적 상한이다).
	#
	# ⚠️ **`ceil` 이 아니라 `floor` 다.** i번째 타격 직전의 방어도는 `S - (i-1)*dmg` 이고,
	#    그 타격이 'shield' 인 조건은 `S - (i-1)*dmg >= dmg` ⇔ `i <= S/dmg` 다.
	#    그래서 개수는 `floor(S/dmg)` — **마지막 한 대는 부분 흡수라 'shield' 가 아니다.**
	#    (첫 판이 `ceil` 로 세어 2대라고 보고했다. 실제로는 1대다.)
	var run: Array = []
	for i in range(WordTower.BASE_DAMAGE_BY_LENGTH.size()):
		var dmg: float = float(WordTower.BASE_DAMAGE_BY_LENGTH[i]) * 1.25
		var shield_hits := int(floor(real_shield / dmg))
		run.append("%d음절 %.1f피해 → %d대" % [i + 1, dmg, shield_hits])
	print("SHIELD_SIGNAL frequency shield=%.1f :: %s" % [real_shield, " · ".join(run)])
	check(real_shield > 0.0, "S5 가 공허하다 — 방어도가 0 이다", "S5")
	check(not all_play.is_empty(), "`play_*` 목록이 비었다", "S5")
	check(WordTower.BASE_DAMAGE_BY_LENGTH.size() > 0, "길이별 피해 표가 비었다", "S5")

	# ── 결론 ─────────────────────────────────────────────────────────────────
	# ✅ §2.20 (B) 고침 (2026-10-01) — `play_shield` 가 주인을 얻었고, 겹치지 않는다.
	var hl2 := hit_wav.get_length() if hit_wav != null else 0.0
	var sl2 := shield_wav.get_length() if shield_wav != null else 0.0
	print("SHIELD_SIGNAL RESOLVED 막은 타격은 `shield` 만 낸다 — 겹침 0 · 새 소리 0 "
		+ "(hit %.3fs / shield %.3fs · §2.20 (B) + §5.2 32 (C), 2026-10-01)" % [hl2, sl2])
	# ✅ **길이 순서도 닫혔다** — `shield` 가 이제 `hit` 보다 **짧고 낮다**(§5.2 32 (C)).
	# ⚠️ **남은 것** — `shield` 에 접두어가 없다는 점은 그대로다(색뿐). 별개 결정이다.

	if failures == 0:
		print("SHIELD_SIGNAL_PROBE_OK")
	get_tree().quit(failures)
