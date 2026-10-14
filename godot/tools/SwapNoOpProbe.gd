extends Node
## §2.24 — 유료 '활자 교체' 가 **아무 일도 안 일으키고** 끝날 수 있다 — **✅ 고침 (§5.2 36 (B), 2026-09-26)**
##
## ## 왜 이 절이 필요한가
##
## `TowerDefenseMain._on_tile_swap_requested()` 는 골드를 받고 타일을 바꾸는 유료 행동이다.
## 그런데 **뽑힌 활자가 원래 활자와 같으면** 이렇게 끝난다:
##
## ```gdscript
## var new_char := HangulEngine.get_weighted_random_jamo(pool)
## if new_char == old_char:
##     return  # 같은 활자가 나오면 돈을 받지 않는다
## ```
##
## 돈을 안 받는 것은 의도다(주석이 그렇게 적었다). 문제는 **그 밖에 아무 일도 안 일어난다**는 것이다:
##
## | 채널 | 성공 | 같은 활자 (고치기 전) |
## |---|---|---|
## | 골드 | −10G | 변동 없음(의도) |
## | 타일 글자 | 바뀐다(`render_belt`) | **그대로** |
## | `swap_mode` | **풀린다**(`swap_jamo` 가 `false` 로) | ⚠️ **켜진 채 남는다** |
## | 소리 | `tile_combine` | **없음** |
## | 문구 | — | **없음** ← 고침 지점 |
##
## 즉 플레이어는 *"바꿀 활자 선택"* 상태에서 타일을 눌렀는데 **화면이 한 픽셀도 안 변했고**,
## 버튼이 고장 난 것과 구별할 방법이 없었다.
##
## ## ✅ 고침 — 감독 선택 **(B) 토스트 한 줄** (2026-09-26)
##
## 무음 분기에 **화면 하단 토스트**를 붙였다. **새 기제 0**(이 프로젝트가 이미 4곳에서 쓰는
## 채널) · **새 소리 0** · **새 연출 0**:
##
## ```gdscript
## if new_char == old_char:
##     _toast("같은 활자가 나왔습니다 · 골드는 그대로입니다")
##     return  # 같은 활자가 나오면 돈을 받지 않는다
## ```
##
## ⚠️ **모드는 일부러 안 푼다.** 문구가 *"같은 활자가 나왔습니다"* 라고 말하는 순간,
## 모드가 켜진 채 남는 것은 **"다시 눌러 다른 활자를 뽑으세요"** 로 읽힌다 —
## 그 전에는 같은 상태가 *"아무 일도 안 일어났는데 왜 아직 선택 중이지"* 였다.
## 즉 이 고침은 **문구 하나로 상태 기계의 뜻을 바꾼다**(상태 자체는 안 건드린다).
##
## ⚠️ **남은 잔여** — 벨트 상태 라벨(`parsed_preview_label`, 14곳)은 **여전히 침묵**한다.
## 토스트는 1.8초 뒤 사라지므로 화면을 안 보고 있던 플레이어는 여전히 놓칠 수 있다.
## 그쪽에까지 쓰려면 **별도 결정**이 필요하다(감사 §2.24-5 (C)).
##
## ## 이 프로브가 지키는 것 (고침 뒤)
##
## 1. 같은 활자가 **실제로 나온다**(S1·S2 비공허성) — 확률을 엔진에서 직접 굴려 잰다.
## 2. 그때 **골드가 안 나간다**(S2·S3).
## 3. 그때 **화면이 말한다** — 분기의 코드 줄이 **정확히 둘**(`_toast` + `return`)이고,
##    소리·골드·글자 변경·디버그 출력은 **끼어들지 않는다**(S4).
## 4. 모드가 켜진 채 남는 것은 **이제 의도**다(S3) — 문구가 그 뜻을 만든다.
## 5. 문구가 **플레이어에게 실제로 간다**(S6 — 주석 제외 스캔).
## 6. 고침에 **새 기제가 필요 없었다**(S5 — `_toast` 4곳 · 벨트 라벨 14곳이 이미 있었다).
##
## ⚠️ **S4 는 주석을 먼저 떼어낸다**(`_code_part`). 안 그러면 위에 새로 단 설명이
## ('`_toast`' 라고 적혀 있다) **호출로 세어져**, 호출을 지워도 초록으로 남는다.
## 이 절의 첫 판이 §2.23 과 **똑같은 함정**을 밟았고, 그 함정은 주입 **N7** 이 지킨다.

const PREFIX := "SWAP_NOOP"
const MainScene = preload("res://scenes/TowerDefenseMain.tscn")
const MAIN_PATH := "res://scripts/ui/TowerDefenseMain.gd"
const BELT_PATH := "res://scripts/ui/JamoBelt.gd"

## 타일 한 종류당 표본 수. 15종 × 이 값 = 전체 호출 수.
const SAMPLE_PER_CHAR := 4000
## 교체 시도 횟수. 가장 낮은 확률(자음 ㄱ·ㄴ, 약 6%)에서도
## 무음 실패를 못 볼 확률이 1e-7 아래가 되도록 잡았다.
const ATTEMPTS := 250

var failures := 0


func check(cond: bool, msg: String, tag: int) -> void:
	if not cond:
		failures += 1
		print("FAIL_SECTION S%d :: %s" % [tag, msg])
		push_error("S%d %s" % [tag, msg])


func _ready() -> void:
	# ⚠️ 첫 줄 — `muted` 면 `_play_synth_stream()` 이 즉시 return 해 소리 측정이 공허해진다.
	#    필드 직접 대입이라 `_save_config()` 를 지나지 않는다(설정 파일 안전).
	SoundEngine.muted = false

	# ── S1. 같은 활자가 나올 확률 — **엔진을 직접 굴려서** 잰다 ────────────────
	#
	#   ⚠️ 가중치를 코드에서 다시 계산하지 않는다. `get_weighted_random_jamo()` 를 그대로
	#      불러 세면 그 함수가 무엇을 하든 측정이 따라간다.
	#   ⚠️ 그리고 `Σ_ch P(roll == ch) = 1` 이라는 **항등식**으로 표본 자체를 검증한다 —
	#      이게 없으면 "확률이 낮다" 는 주장이 표본 오류인지 실제인지 구별되지 않는다.
	var pools := {"모음": HangulEngine.VOWEL_POOL, "자음": HangulEngine.CONSONANT_POOL}
	var p_min := 1.0
	var p_max := 0.0
	var sums := {}
	for key in pools:
		var pool: Array = pools[key]
		var acc := 0.0
		for ch in pool:
			var hit := 0
			for i in range(SAMPLE_PER_CHAR):
				if HangulEngine.get_weighted_random_jamo(pool) == ch:
					hit += 1
			var p := float(hit) / float(SAMPLE_PER_CHAR)
			acc += p
			p_min = minf(p_min, p)
			p_max = maxf(p_max, p)
			print("%s p_same[%s] = %.3f  (%s 풀, n=%d)" % [PREFIX, ch, p, key, SAMPLE_PER_CHAR])
		sums[key] = acc
	print("%s p_min=%.3f p_max=%.3f pool_sums=%s" % [PREFIX, p_min, p_max, str(sums)])
	for key in sums:
		check(absf(float(sums[key]) - 1.0) < 0.05,
			"표본이 정상이다 — %s 풀에서 Σ P(roll == ch) = %.3f (1.0 이어야 한다)"
				% [key, float(sums[key])], 1)
	check(p_min > 0.0,
		"**모든** 타일 종류에서 '같은 활자' 가 가능하다 (최소 %.3f)" % p_min, 1)
	check(p_min >= 0.04,
		"가장 낮은 확률도 %.3f — 드물어서 무시할 수 있는 값이 아니다" % p_min, 1)
	check(p_max <= 0.35,
		"가장 높은 확률 %.3f — 상한도 넘지 않는다" % p_max, 1)

	# ── S2. 런타임 — 무음 실패를 **실제로 관측**한다 ──────────────────────────
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	# ⚠️ 이중 안전장치. `tools/` 경로는 `SaveManager._is_test_run()` 이 이미 테스트 경로로
	#    보내지만(`SaveManager.gd:26`), `save_game_state()` 자체를 막아 두면 확실하다.
	main._is_loading_state = true
	main.start_new_game()
	await get_tree().process_frame
	await get_tree().process_frame

	var belt = main.jamo_belt
	var field = main.defense_field
	check(belt != null and field != null, "벨트/필드를 못 얻었다 — 아래 절이 전부 공허해진다", 2)
	if belt == null or field == null:
		print("%s FAILURES=%d" % [PREFIX, failures])
		get_tree().quit(failures)
		return
	field.gold = 100000                      # 가드(`gold < price`)가 절대 안 걸리게
	check(belt.jamo_list.size() > 0, "벨트에 타일이 있다 (%d장)" % belt.jamo_list.size(), 2)
	if belt.jamo_list.size() == 0:
		print("%s FAILURES=%d" % [PREFIX, failures])
		get_tree().quit(failures)
		return

	var idx := 0
	var price: int = belt.current_swap_price()
	var start_char: String = belt.jamo_list[idx]
	var successes := 0
	var noops := 0
	var heard := 0
	var mismatch := 0
	var noop_mode := true
	var success_mode := true
	var noop_gold_delta := -1
	var success_gold_delta := -1
	var noop_char_after := ""

	for attempt in range(ATTEMPTS):
		var before_char: String = belt.jamo_list[idx]
		var before_gold: int = field.gold
		belt.swap_mode = true                # 플레이어가 교체 모드에 들어간 상태를 재현
		belt._suppress_celebration = true    # 단어 완성 배너가 250개 뜨는 것을 막는다(측정과 무관)
		# ⚠️ 매 시도마다 스로틀을 비운다 — 안 그러면 50 ms 안의 두 번째 `play_tile_combine` 이
		#    막혀 "소리가 안 났다" 가 스로틀 때문인지 호출이 없어서인지 구별되지 않는다.
		SoundEngine._last_played_msec.clear()
		main._on_tile_swap_requested(idx)
		var after_char: String = belt.jamo_list[idx]
		var gold_delta: int = before_gold - field.gold
		var is_noop: bool = (after_char == before_char)
		if is_noop != (gold_delta == 0):
			mismatch += 1
		if SoundEngine._last_played_msec.keys().has("tile_combine"):
			heard += 1
		if is_noop:
			noops += 1
			if noops == 1:
				noop_mode = belt.swap_mode
				noop_gold_delta = gold_delta
				noop_char_after = after_char
		else:
			successes += 1
			if successes == 1:
				success_mode = belt.swap_mode
				success_gold_delta = gold_delta

	var rate := 100.0 * float(noops) / float(ATTEMPTS)
	print("%s start_char=%s price=%d attempts=%d successes=%d noops=%d heard=%d (무음 실패율 %.1f%%)"
		% [PREFIX, start_char, price, ATTEMPTS, successes, noops, heard, rate])
	#   ⚠️ 비공허성 — 무음 실패를 한 번도 못 봤으면 이 절은 아무것도 증명하지 못한다.
	check(noops > 0,
		"⚠️ 무음 실패를 **실제로 관측**했다 — 0건이면 이 절이 통째로 공허하다", 2)
	check(successes > 0,
		"성공도 관측했다 — 대조군이 있어야 '아무 일도 안 일어남' 이 의미를 갖는다", 2)
	check(successes + noops == ATTEMPTS, "모든 시도가 둘 중 하나로 분류됐다", 2)
	check(mismatch == 0,
		"무음 실패는 **골드도 안 나간다** — 글자와 골드가 어긋난 시도 %d건" % mismatch, 2)
	#   ⚠️ 스로틀을 매번 비웠으므로 `play_tile_combine()` 이 불리면 **반드시** 키가 남는다.
	#      따라서 이 등식은 "실패는 소리도 없다" 의 직접 증거다(호출이 있었다면 250 이 된다).
	check(heard == successes,
		"⚠️ 소리는 **성공한 교체 수와 정확히 일치**한다 (%d vs %d) — 같은 활자일 때는 소리도 없다"
			% [heard, successes], 2)

	# ── S3. 상태 차이 — 모드가 안 풀린다 ─────────────────────────────────────
	print("%s noop_mode=%s success_mode=%s noop_gold_delta=%d success_gold_delta=%d noop_char=%s"
		% [PREFIX, str(noop_mode), str(success_mode), noop_gold_delta, success_gold_delta, noop_char_after])
	check(success_mode == false,
		"성공하면 `swap_mode` 가 **풀린다** — 선택 모드가 끝난다", 3)
	check(noop_mode == true,
		"실패하면 `swap_mode` 가 **켜진 채 남는다** — 이제 의도다: 토스트가 '다시 눌러 다른 활자를' 로 읽힌다", 3)
	check(success_gold_delta == price,
		"성공은 %dG 를 낸다 (실측 %d)" % [price, success_gold_delta], 3)
	check(noop_gold_delta == 0,
		"실패는 0G — 주석이 적은 대로 청구되지 않는다", 3)

	# ── S4. 정적 — 이 분기의 코드 줄은 **정확히 둘**(`_toast` + `return`)이다 ────
	#
	#   ⚠️ 주석을 **먼저 떼어낸다**. 안 그러면 바로 위에 새로 단 설명(`_toast` 라고 적혀 있다)이
	#      '채널이 있다' 로 세어져 **호출을 지워도 초록으로 남는다** — §2.23 과 같은 함정이다.
	var main_src := FileAccess.get_file_as_string(MAIN_PATH)
	var branch := _block_after(main_src, "if new_char == old_char:")
	var code_branch: Array = []
	for l in branch:
		var c := _code_part(str(l)).strip_edges()
		if c != "":
			code_branch.append(c)
	print("%s noop_branch=%s" % [PREFIX, str(code_branch)])
	check(not branch.is_empty(),
		"무음 분기를 찾았다 — 못 찾으면 이 절이 공허하다(앵커가 바뀌었다)", 4)
	check(code_branch.size() == 2,
		"분기의 **코드 줄은 정확히 둘**(`_toast` + `return`)이다 (측정 %d) — 늘면 다른 채널이 끼어든 것이다"
			% code_branch.size(), 4)
	#   ⚠️ **빈 배열 가드가 먼저다.** `code_branch[0]` 을 그냥 쓰면, 분기를 못 찾았을 때
	#      (주입 M1 처럼 `if` 자체가 사라졌을 때) **런타임 오류가 `_ready()` 를 중단**시켜
	#      `quit()` 이 안 불리고 **프로세스가 영영 안 끝난다**(RC=124 — '통과' 가 아니다).
	#      `and` 는 단락 평가라 앞이 거짓이면 `[0]` 을 안 건드린다.
	check(not code_branch.is_empty() and str(code_branch[0]).contains("_toast("),
		"⚠️ 분기가 **먼저 말한다** — 토스트가 호출된다(측정 %s)" % str(code_branch), 4)
	#   고침 뒤에도 **없어야 하는** 것 — 소리·청구·글자 변경·디버그 출력이 끼어들면 다른 사건이 된다.
	for ch_name in ["SoundEngine", "gold", "render_belt", "push_warning", "print"]:
		var found := false
		for c in code_branch:
			if str(c).contains(ch_name):
				found = true
		check(not found,
			"분기에 `%s` 가 **없다** — 이 사건은 소리도 청구도 글자 변경도 아니다" % ch_name, 4)

	# ── S5. 고침에 **새 기제가 필요 없다** ────────────────────────────────────
	var toast_calls := _count_lines(main_src, "_toast(")
	var label_writes := _count_lines(FileAccess.get_file_as_string(BELT_PATH),
		"parsed_preview_label.text =")
	print("%s toast_lines=%d label_writes=%d" % [PREFIX, toast_calls, label_writes])
	check(toast_calls >= 3,
		"`_toast` 는 이미 %d줄에서 쓰인다 — 새 기제를 만들 필요가 없다" % toast_calls, 5)
	check(label_writes >= 5,
		"벨트 상태 라벨도 이미 %d곳에서 쓰인다 — 벨트 쪽 채널도 있다" % label_writes, 5)

	# ── S6. 계약 — 이제 **문구가 있다**. 2026-09-26 에 극성이 뒤집혔다 ─────────
	#
	#   고치기 전: `_scan_player_text("같은 활자") == []` — **없는 표현**이었다(주석에만 있었다).
	#   고친 뒤  : 문구가 생겼으므로 *"알려 준다"* 를 재야 한다.
	#   ⚠️ 주석을 세면 안 된다 — 그건 §2.23 이 밟은 함정이고 `_scan_player_text` 가 막는다.
	var rule := _scan_all("조용히 아무 일도 안 일어나면")
	var contract := _scan_player_text("같은 활자가 나왔습니다")
	#   ⚠️ **주석 제거기가 실제로 일하는지도 함께 잰다.** `돈을 받지 않는다` 는 **주석에만**
	#      있는 문장이라, 제거기가 빠지면 '플레이어 문구' 로 세어진다(§2.23 이 밟은 함정).
	var comment_only := _scan_player_text("돈을 받지 않는다")
	print("%s contract rule=%s player_text=%s comment_only=%s"
		% [PREFIX, str(rule), str(contract), str(comment_only)])
	check(rule.size() >= 2,
		"프로젝트가 규칙을 **두 곳**에 적어 두었다(`JamoBelt.gd:479` · `TowerDefenseMain.gd:1136`) — 실측 %d곳"
			% rule.size(), 6)
	check(not contract.is_empty(),
		"⚠️ 이 경우를 알려 주는 **플레이어 문구가 있다**(측정 %s)" % str(contract), 6)
	check(contract.size() == 1 and str(contract[0]).ends_with("TowerDefenseMain.gd"),
		"그 문구는 **한 곳**에만 있다 — 토스트 한 줄", 6)
	check(comment_only.is_empty(),
		"⚠️ 주석에만 있는 문장은 **플레이어 문구로 안 센다** — 주석 제거기가 일하고 있다(측정 %s)"
			% str(comment_only), 6)

	print("%s RESOLVED 같은 활자가 나왔을 때 화면이 말한다 — 토스트 한 줄 · 새 기제 0 (감사 §2.24 · §5.2 36 (B), 2026-09-26)" % PREFIX)

	if failures == 0:
		print("SWAP_NOOP_PROBE_OK")
	else:
		print("%s FAILURES=%d" % [PREFIX, failures])
	get_tree().quit(failures)


## 앵커 줄 **다음**의, 앵커보다 깊게 들여쓰기된 줄들을 모은다(본문 블록).
func _block_after(text: String, anchor: String) -> Array:
	var out: Array = []
	var lines := text.replace("\r\n", "\n").split("\n")
	var found := false
	var base_indent := -1
	for line in lines:
		var s := str(line)
		if not found:
			if s.contains(anchor):
				found = true
				base_indent = _indent_of(s)
			continue
		var stripped := s.strip_edges()
		if stripped == "":
			continue
		if _indent_of(s) <= base_indent:
			break
		out.append(s)
	return out


func _indent_of(s: String) -> int:
	var n := 0
	for i in range(s.length()):
		if s[i] == "\t":
			n += 1
		elif s[i] == " ":
			n += 1
		else:
			break
	return n


func _count_lines(text: String, needle: String) -> int:
	var n := 0
	for line in text.replace("\r\n", "\n").split("\n"):
		if str(line).contains(needle):
			n += 1
	return n


## `res://scripts` 전체에서 문구를 **주석 포함**으로 찾는다(원칙은 주석에 적힌다).
func _scan_all(needle: String) -> Array:
	var hits: Array = []
	_walk("res://scripts", needle, hits, true)
	return hits


## **플레이어에게 나가는** 문구에서만 찾는다 — 주석은 제외한다.
##
## ⚠️ **`s.begins_with("#")` 만으로는 부족하다.** 그건 *줄 전체가 주석인 줄*만 거른다.
##    이 절의 첫 판이 그래서 실패했다 — `같은 활자` 는 이 한 줄에만 있는데
##
## ```gdscript
## 		return  # 같은 활자가 나오면 돈을 받지 않는다
## ```
##
##    코드 줄 **끝**에 붙은 주석이라 그대로 '플레이어 문구' 로 세어졌다. 그래서
##    **문자열 밖의 `#` 이후를 잘라내는** `_code_part()` 를 거쳐서 본다.
func _scan_player_text(needle: String) -> Array:
	var hits: Array = []
	_walk("res://scripts", needle, hits, false)
	return hits


## 줄에서 **문자열 밖의** `#` 이후를 잘라낸다.
##
## ⚠️ 문자열 안의 `#` 은 살려야 한다 — 이 프로젝트는 색을 문자열로 쓴다(`"#A6B8F2"`).
##    무조건 `#` 에서 자르면 그런 줄의 뒷부분이 사라져 **진짜 계약을 놓친다**(반대 방향 오류).
##    그래서 따옴표 상태를 따라가며 자른다.
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


func _walk(dir_path: String, needle: String, hits: Array, include_comments: bool) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var nm := dir.get_next()
	while nm != "":
		var full := dir_path.path_join(nm)
		if dir.current_is_dir():
			_walk(full, needle, hits, include_comments)
		elif nm.ends_with(".gd"):
			var text := FileAccess.get_file_as_string(full)
			if include_comments:
				if text.contains(needle):
					hits.append(full)
			else:
				for line in text.replace("\r\n", "\n").split("\n"):
					var s := _code_part(str(line)).strip_edges()
					if s == "":
						continue                       # 빈 줄 / 주석만 있는 줄
					if s.contains(needle):
						hits.append(full)
						break
		nm = dir.get_next()
	dir.list_dir_end()
