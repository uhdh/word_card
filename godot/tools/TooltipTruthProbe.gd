extends Node
# 플레이어가 읽는 **조작 안내**가 실제 동작과 일치하는가.
# (감사 §2.15 신설, 2026-09-24)
#
# 왜 문제인가 — 안내 문구는 **계약**이다. 플레이어는 그 문구를 믿고 손을 움직인다.
#   게임 안에서 유일한 조작 설명이 툴팁이므로, 툴팁이 틀리면 **배울 방법이 없다.**
#
# 실측으로 찾은 것 둘 (둘 다 2026-09-24 고침):
#
#   1. 회전 툴팁 `"90도 회전 (예: ㅏ → ㅗ, ㄱ → ㄴ)"`
#      실제 `HangulEngine.ROTATABLE_TILES` 는 `"ㅏ": "ㅜ"` 다 — 한 번 누르면 **ㅜ** 가 된다.
#      `ㅗ` 는 **세 번** 눌러야 나온다(ㅏ→ㅜ→ㅓ→ㅗ). 즉 예시가 90도가 아니라 180도다.
#      같은 맵의 `ㄱ → ㄴ` 은 맞다(2순환). 그리고 등급 라벨 `"4변환 만능"`(ㅏ) ·
#      `"2변환"`(ㄱ) 이 맵과 **일치**한다 — 즉 **맵이 맞고 예시가 틀렸다.**
#      → 예시를 `ㅏ → ㅜ` 로 고치고, **각도 주장("90도") 자체를 뺐다.** 순환 길이가 타일마다
#        달라서(4순환 = 한 번에 90도 · 2순환 = 180도) **어떤 한 각도도 전부에 맞지 않는다.**
#        §1c 가 그 계약을 지킨다 — 문구에 각도가 적혀 있으면 **모든** 회전 타일이 그 각도여야 한다.
#
#   2. 배속 툴팁 `"단축키: [1] / [2] / [3] / [4] / [P] 일시정지"`
#      실제 배속은 **셋**이다(1x · 2x · 4x). `_on_speed_pressed()` 도 3단(1→2→4→1),
#      `set_speed_scale()` 의 라벨 분기도 3개다. `[3]` 과 `[4]` 는 **둘 다 4x** 다.
#      → 목록을 `[1] / [2] / [4]` 로 줄였다. **키 바인딩(`KEY_3, KEY_4:`)은 남겼다** —
#        익숙한 사람은 계속 쓸 수 있고, 목록에 없는 키가 동작하는 것은 거짓이 아니다.
#        (3x 를 실제로 추가할지는 여전히 감독 결정 — §4 가 그 수치를 보고한다.)
#
# ⚠️ 이 도구가 재는 것 (한쪽만 재면 반쪽짜리 검사다):
#   §0 전제 — 툴팁을 가진 노드와 회전 맵을 읽을 수 있는가
#   §1 회전 예시의 **각 쌍**이 `rotate()` 한 번의 결과인가 (비공허성: 쌍이 1개 이상)
#   §1c 문구가 주장하는 **회전 각도**가 모든 회전 타일에 맞는가 (순환 길이에서 유도)
#   §2 등급 라벨의 **변환 수**가 실제 순환 길이와 같은가 (`4변환`=4순환 · `2변환`=2순환)
#   §3 툴팁에 적힌 **단축키가 실제로 먹는가** (관측 가능한 상태가 바뀌는가).
#      ⚠️ 누를 키 목록을 **문구에서 읽는다** — 상수로 박으면 문구가 바뀌어도 옛 목록을 계속
#      눌러 '적혀 있는데 안 먹는 키' 를 영원히 못 잡는다(검사가 조용히 공허해진다).
#   §4 보고 — 한 툴팁이 나열한 키들이 **서로 다른 일**을 하는가 (3x 추가 여부 → 감독 결정)
#   §5 보고 — 시뮬레이션하지 않은 키와 그 이유(세이브·런 상태에 의존)
#
# ⚠️ 단언하는 것은 **문구와 메커니즘의 일치**이지 '어떤 속도가 있어야 하는가' 가 아니다.
#   §4 는 수치만 보고한다 — 3x 를 추가할지는 **감독 결정**이다.
#
# 실행: godot --headless --path . res://tools/TooltipTruthProbe.tscn

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

## 예시 문구의 화살표. 회전 툴팁은 `ㅏ → ㅗ` 처럼 적는다.
const ARROW := "▸"
## 배속 툴팁의 키 목록은 **문구에서 읽는다**(`[1]` · `[P]` 표기). 상수로 박아 두면
## 문구가 바뀌어도 옛 목록을 계속 눌러 **검사가 조용히 공허해진다** — 그래서 상수가 아니다.
## 다만 아래 키들은 상태가 단순해 시뮬레이션할 수 있다(세이브·런 상태에 기대지 않는다).
## 이 목록 밖의 키가 문구에 적혀 있으면 §3 이 그것도 눌러 본다 — 그것이 핵심이다.
## 시뮬레이션하지 **않는** 키(§5 에 이유와 함께 보고). 효과가 세이브 파일·런 상태에 달렸다.
const SIMULATE_EXCLUDE := [KEY_SPACE, KEY_S, KEY_L, KEY_TAB, KEY_D]
## 문구의 `[X]` 를 키코드로 되돌릴 때 비교할 후보. `OS.get_keycode_string()` 이 역함수다.
const KEYCODE_CANDIDATES := [
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9,
	KEY_P, KEY_M, KEY_S, KEY_L, KEY_SPACE, KEY_TAB, KEY_D,
]

var failures := 0
## 어느 절에서 실패했는지 **기계가 읽을 수 있게** 남긴다. 주입 하네스가 한국어 문구를
## 파싱하지 않고도 "이 주입이 §2 를 때렸다" 를 확인할 수 있어야 한다(문구를 파싱하면
## 인코딩·문구 변경에 취약해진다). §2.13-1 의 파서 함정을 반복하지 않기 위한 장치다.
var _section := "S0"

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("TOOLTIP_PROBE FAIL_SECTION %s" % _section)
		push_error(message)

## 이름으로 자손을 찾는다(타일은 `render_belt()` 가 매번 새로 만든다 — 경로가 안정적이지 않다).
func _find_all(root: Node, node_name: String, out: Array) -> Array:
	if root.name == node_name:
		out.append(root)
	for c in root.get_children():
		_find_all(c, node_name, out)
	return out

## `A → B` 쌍을 뽑는다. 화살표 기준으로 좌우 한 글자씩.
func _arrow_pairs(text: String) -> Array:
	var pairs: Array = []
	var parts := text.split(",")
	for p in parts:
		var i := p.find(ARROW)
		if i < 0:
			continue
		var left := p.substr(0, i).strip_edges()
		var right := p.substr(i + ARROW.length()).strip_edges()
		if left.is_empty() or right.is_empty():
			continue
		pairs.append([left.substr(left.length() - 1), right.substr(0, 1)])
	return pairs

## `rotate()` 를 반복해 제자리로 돌아오는 데 걸리는 횟수. 1이면 회전 불가.
func _cycle_len(tile: String) -> int:
	var cur := tile
	for i in range(1, 9):
		cur = HangulEngine.rotate(cur)
		if cur == tile:
			return i
	return -1

## 문구에서 첫 숫자를 뽑는다(`"(4변환 만능)"` → 4).
func _first_int(text: String) -> int:
	var digits := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	return int(digits) if digits != "" else -1

## 문구가 주장하는 회전 각도(`"90도"` → 90.0). 각도 주장이 없으면 -1.
##
## ⚠️ `도` 의 **앞** 숫자를 읽는다 — 뒤가 아니다(`"4변환"` 은 `환` 이라 안 걸린다).
##   이 값도 **문구에서 유도**한 것이지 상수가 아니다(문구가 바뀌면 검사도 따라간다).
func _claimed_degrees(text: String) -> float:
	for i in range(text.length()):
		if text[i] != "도":
			continue
		var digits := ""
		var j := i - 1
		while j >= 0 and text[j] >= "0" and text[j] <= "9":
			digits = text[j] + digits
			j -= 1
		if digits != "":
			return float(digits)
	return -1.0

## 문구에서 `[1]` · `[P]` 같은 대괄호 토큰만 뽑는다. **문구가 곧 검사 대상**이라
## 목록을 상수로 두지 않는다(문구가 바뀌면 검사도 같이 따라가야 한다).
func _bracket_tokens(text: String) -> Array:
	var out: Array = []
	var i := 0
	while i < text.length():
		if text[i] == "[":
			var j := text.find("]", i)
			if j < 0:
				break
			var tok := text.substr(i + 1, j - i - 1).strip_edges()
			if not tok.is_empty():
				out.append(tok)
			i = j + 1
		else:
			i += 1
	return out

## `[X]` 토큰을 키코드로. 모르는 토큰이면 -1(§5 에서 보고).
func _keycode_for_token(tok: String) -> int:
	for k in KEYCODE_CANDIDATES:
		if OS.get_keycode_string(k) == tok:
			return k
	return -1

## 키 하나를 실제 핸들러에 넣고, 관측 가능한 상태가 바뀌었는지 본다.
## ⚠️ `_unhandled_input` 을 직접 부른다 — 엔진이 부르는 것과 같은 함수다.
func _press(main, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	ev.echo = false
	main._unhandled_input(ev)

## 시뮬레이션 전후를 비교할 관측 상태. 소리·모달·배속·일시정지.
func _snapshot(main) -> Array:
	return [
		main.current_speed_scale,
		SoundEngine.muted,
		main.modal_layer.get_child_count(),
		main.defense_field.is_wave_running,
	]

func _ready() -> void:
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

	# ── §0 전제 ────────────────────────────────────────────────────────────
	check(main.jamo_belt != null, "jamo_belt 가 없다 — 타일 툴팁을 못 잰다")
	check(main.btn_speed != null, "btn_speed 가 없다 — 배속 툴팁을 못 잰다")
	# 회전 맵이 살아 있는가 — 여기서 죽으면 §1·§2 가 공짜로 통과한다.
	check(HangulEngine.rotate("ㅏ") != "ㅏ", "회전 맵이 비어 있다 — 예시를 잴 수 없다")
	if main.jamo_belt == null:
		get_tree().quit(failures + 1)
		return

	# 회전 가능한 타일이 반드시 하나는 있도록 벨트를 직접 채운다.
	# ⚠️ `jamo_list` 는 `Array[String]` 이다 — 타입 없는 리터럴을 그대로 대입하면
	#   `Invalid assignment of property or key 'jamo_list' ... on a base object of type
	#   'PanelContainer (JamoBelt)'` 로 **런이 통째로 죽는다**(첫 실행에서 이걸로 죽었다).
	var seeds: Array[String] = ["ㅏ", "ㄱ", "ㄷ", "ㅁ"]
	main.jamo_belt.jamo_list = seeds
	main.jamo_belt.render_belt()
	await get_tree().process_frame
	await get_tree().process_frame

	# ── §1 회전 예시가 `rotate()` 한 번의 결과인가 ─────────────────────────
	_section = "S1"
	# ⚠️ 타일은 `render_belt()` 가 매번 새로 만든다 — 경로가 아니라 **이름**으로 찾는다.
	var rot_btns := _find_all(main, "RotateButton", [])
	print("TOOLTIP_PROBE rot_buttons=%d" % rot_btns.size())
	if not rot_btns.is_empty():
		print("TOOLTIP_PROBE rotate_tooltip=%s" % JSON.stringify(rot_btns[0].tooltip_text))
	check(not rot_btns.is_empty(),
		"회전 버튼이 하나도 없다 — 회전 예시 문구를 잴 수 없다(비공허성 실패)")
	var total_pairs := 0
	for b in rot_btns:
		var tip: String = b.tooltip_text
		var pairs := _arrow_pairs(tip)
		total_pairs += pairs.size()
		for pair in pairs:
			var src: String = pair[0]
			var want: String = pair[1]
			var got: String = HangulEngine.rotate(src)
			print("TOOLTIP_PROBE rotate_example %s -> %s (실제 %s) tooltip=%s"
				% [src, want, got, JSON.stringify(tip)])
			check(got == want,
				"회전 툴팁의 예시가 틀렸다: '%s → %s' 라고 적었는데 한 번 누르면 '%s' 다 — 플레이어가 잘못 배운다"
					% [src, want, got])
		# ⚠️ '90도' 라는 **문구 자체**는 여기서 단언하지 않는다 — 각도 주장은 §1c 가
		#   **모든** 회전 타일에 대해 잰다(한 타일만 보고 판정하면 반쪽짜리다).
		#   2026-09-24 이전에는 이 자리가 `OPEN_ITEM` 보고였는데, 각도를 빼는 쪽으로 고친 뒤
		#   **단언으로 승격**했다(§1c).
		for pair in pairs:
			var src: String = pair[0]
			check(_cycle_len(src) > 1,
				"회전 툴팁의 예시 '%s' 는 회전 불가 타일이다 — 예시가 될 수 없다" % src)
	check(total_pairs >= 1,
		"회전 툴팁에서 'A → B' 쌍을 하나도 못 읽었다 — 예시 검사가 공허하다")

	# ── §2 등급 라벨의 변환 수 = 실제 순환 길이 ───────────────────────────
	_section = "S2"
	# 이 절이 §1 의 판정 근거를 **독립적으로** 뒷받침한다: 맵과 라벨이 같은 말을 하는가.
	var tile_btns := _find_all(main, "TileButton", [])
	print("TOOLTIP_PROBE tile_buttons=%d" % tile_btns.size())
	var seen := 0
	for t in tile_btns:
		var tip: String = t.tooltip_text
		var open_i := tip.find("타일:")
		if open_i < 0:
			continue
		# ⚠️ 서식은 `"[초희귀 (4변환 만능) 타일: ㅏ]"` 다 — '타일:' 뒤에 **공백**이 있다.
		#   `substr(open_i + 3, 1)` 로 한 글자를 그냥 읽으면 공백을 타일 문자로 착각한다
		#   (§2.13-1 의 파서 함정과 같은 부류 — 파서가 문구의 구조를 따라가야 한다).
		var after := tip.substr(open_i + 3).strip_edges()
		if after.is_empty():
			continue
		var ch := after.substr(0, 1)
		var cycle := _cycle_len(ch)
		var label_n := _first_int(tip)
		if label_n < 0:
			# 일반 타일은 변환 수를 말하지 않는다 — 회전 불가여야 맞다.
			check(cycle <= 1,
				"툴팁에 변환 수가 없는데 '%s' 는 %d순환이다 — 등급 표시가 빠졌다" % [ch, cycle])
			continue
		seen += 1
		print("TOOLTIP_PROBE rarity '%s' cycle=%d label=%d변환" % [ch, cycle, label_n])
		check(label_n == cycle,
			"'%s' 의 등급 라벨은 %d변환이라는데 실제 순환은 %d 다 — 라벨과 회전 맵이 어긋난다"
				% [ch, label_n, cycle])
	check(seen >= 1,
		"변환 수를 말하는 등급 라벨을 하나도 못 봤다 — §2 가 공허하다(초희귀/희귀 타일이 벨트에 없나?)")

	# ── §1c 문구가 주장하는 회전 각도가 **모든** 회전 타일에 맞는가 ──────────
	# 각도는 **순환 길이에서 유도**된다: 4순환은 한 번에 90도, 2순환은 180도.
	# 그러므로 문구에 한 각도를 적으려면 **모든** 회전 타일의 순환 길이가 같아야 한다.
	# 2026-09-24 이전 문구는 `"90도 회전"` 이었는데 `ㄱ↔ㄴ`(2순환)에서 거짓이었다.
	_section = "S1c"
	var rotatable: Array = HangulEngine.ROTATABLE_TILES.keys()
	check(rotatable.size() >= 2,
		"회전 가능 타일이 %d개뿐이라 각도 주장 검사가 공허하다" % rotatable.size())
	var cycles: Dictionary = {}
	for ch in rotatable:
		cycles[_cycle_len(ch)] = true
	# 검사할 문구 = 회전 배지 + 타일 툴팁 전부(각도 주장이 숨을 수 있는 두 곳).
	var angle_texts: Array = []
	for b in rot_btns:
		angle_texts.append(String(b.tooltip_text))
	for t in tile_btns:
		angle_texts.append(String(t.tooltip_text))
	var claims := 0
	for tip in angle_texts:
		var deg := _claimed_degrees(tip)
		if deg >= 0.0:
			claims += 1
			print("TOOLTIP_PROBE angle_claim %.0f도 tooltip=%s" % [deg, JSON.stringify(tip)])
	if cycles.size() > 1:
		# 각도가 타일마다 다르다 → 문구에 각도를 적으면 **어느 타일에서는 반드시 거짓**이다.
		# ⚠️ 주장이 0개면 위 루프가 한 번도 안 돈다 — 그 '공짜 통과' 를 막는 것이 이 단언이다.
		check(claims == 0,
			"회전 타일의 순환 길이가 %d가지라 한 번에 바뀌는 각도가 타일마다 다르다 — 회전 안내에 각도를 적으면 거짓이 된다(각도 주장 %d개)"
				% [cycles.size(), claims])
	else:
		# 전부 같은 순환이면 각도 주장이 정당하다 — 그때는 그 각도가 실제와 맞아야 한다.
		var only_cycle: int = cycles.keys()[0]
		var actual := 360.0 / float(only_cycle)
		for tip in angle_texts:
			var deg := _claimed_degrees(tip)
			if deg >= 0.0:
				check(is_equal_approx(actual, deg),
					"회전 안내가 '%.0f도' 라 하는데 실제 한 번은 %.0f도다(%d순환) — 문구: %s"
						% [deg, actual, only_cycle, JSON.stringify(tip)])
	print("TOOLTIP_PROBE angle_claims=%d cycle_kinds=%d %s"
		% [claims, cycles.size(), str(cycles.keys())])

	# ── §3 툴팁에 적힌 단축키가 실제로 먹는가 ─────────────────────────────
	_section = "S3"
	# ⚠️ 누를 키를 **문구에서 읽는다.** 상수 목록을 돌리면 문구가 바뀌어도 옛 목록을 계속
	#   눌러 검사가 조용히 공허해진다(그러면 '적혀 있는데 안 먹는 키' 를 영원히 못 잡는다).
	var listed := _bracket_tokens(main.btn_speed.tooltip_text)
	print("TOOLTIP_PROBE speed_listed_keys=%s" % str(listed))
	check(not listed.is_empty(),
		"배속 툴팁에 [키] 표기가 하나도 없다 — 단축키 검사가 공허하다: %s"
			% JSON.stringify(main.btn_speed.tooltip_text))
	var speed_outcomes: Dictionary = {}
	var not_pressed: Array = []
	for tok in listed:
		var kc := _keycode_for_token(tok)
		if kc == -1 or SIMULATE_EXCLUDE.has(kc):
			not_pressed.append(tok)
			continue
		# ⚠️ 배속 키는 **이미 그 배속이면 아무 일도 안 일어난다.** 그대로 재면 '안 먹는다' 와
		#   구별되지 않아 거짓 실패가 된다(첫 설계가 정확히 그랬다). 키가 값을 **옮기는지**를
		#   보려면 전제를 흔들어야 한다 — 대상 배속과 다른 값에서 출발시킨다.
		if kc >= KEY_1 and kc <= KEY_4:
			main.set_speed_scale(2.0 if kc == KEY_1 else 1.0)
			await get_tree().process_frame
		var before := _snapshot(main)
		_press(main, kc)
		await get_tree().process_frame
		var after := _snapshot(main)
		var changed := before != after
		if kc >= KEY_1 and kc <= KEY_4:
			speed_outcomes[kc] = main.current_speed_scale
		print("TOOLTIP_PROBE key %s changed=%s speed=%.1f"
			% [tok, changed, main.current_speed_scale])
		check(changed, "툴팁에 적힌 [%s] 를 눌렀는데 아무 일도 안 일어났다 — 안내가 거짓말이다" % tok)

	# ── §4 보고 — 나열한 키들이 서로 다른 일을 하는가 ─────────────────────
	# ⚠️ 여기는 **단언하지 않는다.** `[3]` 과 `[4]` 가 둘 다 4x 인 것은 사실이지만,
	#   고칠 방향이 둘이다 — (A) 문구를 `[1]/[2]/[4]` 로 줄인다 · (B) 3x 를 추가한다.
	#   (B) 는 새 기능이라 **감독 결정**이다. 그래서 수치만 남긴다.
	var distinct: Dictionary = {}
	for k in speed_outcomes.keys():
		distinct[speed_outcomes[k]] = true
	print("TOOLTIP_PROBE speed_tooltip=%s" % JSON.stringify(main.btn_speed.tooltip_text))
	print("TOOLTIP_PROBE speed_keys listed=%d distinct_outcomes=%d %s"
		% [speed_outcomes.size(), distinct.size(), str(speed_outcomes)])
	if distinct.size() < speed_outcomes.size():
		print("TOOLTIP_PROBE OPEN_ITEM 배속 툴팁이 %d개 배속 키를 나열하는데 실제 배속은 %d개다 — 같은 결과를 내는 키가 있다"
			% [speed_outcomes.size(), distinct.size()])

	# ── §5 보고 — 시뮬레이션하지 않은 키와 그 이유 ────────────────────────
	print("TOOLTIP_PROBE NOT_SIMULATED %s — 세이브 파일·런 상태에 의존해 '안 바뀜' 이 결함인지 아닌지 구분할 수 없다"
		% str(not_pressed))

	if failures == 0:
		print("TOOLTIP_TRUTH_PROBE_OK")
	get_tree().quit(failures)
