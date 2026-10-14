extends Node
# 봇의 **성공 문구가 검증하지 않은 것을 검증했다고 말하지 않는가** (감사 §2.16 신설, 2026-09-24)
#
# 왜 문제인가 — 이 문구는 그냥 로그가 아니다. `tests/run_all.sh` 의 `RESULT_RE` 가
#   `ALL TESTS PASSED` 에 걸려서 이 테스트를 **통과로 센다.** 즉 문구가 곧 **합격 도장**이다.
#   그래서 "검사하지 않은 것" 을 주장하면 스위트 전체가 **거짓 초록**을 낸다.
#
# 실측으로 찾은 것 (2026-09-24, 고치기 전):
#   `scripts/test/AutoPlayTowerDefense.gd:151` 이
#     "🎉 [ALL TESTS PASSED] 도감, 조합 없는 단어 큰 텍스트, 단축키, 세이브/로드 완벽 검증 성공!"
#   이라고 말했는데, 그 파일(182줄)에는 `InputEventKey`·`keycode`·`_unhandled_input` 이 **0건**,
#   `font_size` 도 **0건**이었다 — 주장 4개 중 **2개가 허위**다.
#   같은 파일 `:65` 는 "초희귀(황금 앰버), 희귀(딥 바이올렛), 일반(다크 슬레이트) 확인 완료!" 라
#   했지만 `HangulEngine.get_rarity_bg_color()` 는 등급과 무관하게 **한 색**을 돌려준다.
#
# ⚠️ 재는 방법 — **주장마다 "그것을 재는 코드가 파일에 있는가" 를 센다.**
#   주장 낱말을 표(`CLAIM_MECHANISMS`)로 메커니즘에 묶고, 파일에서 **주석을 걷어낸 뒤** 그
#   메커니즘이 실제로 있는지 본다. 주석에만 있는 것은 검사가 아니다.
#
# ⚠️ 합격 문구를 `,`·`/` 로 나눈 **구절마다** 표에 있는 낱말을 **하나라도** 포함해야 한다 —
#   아니면 실패다(§1b). 검증할 방법이 없는 주장을 문구에 남겨 두면 이 도구가 조용히 공허해진다.
#   표에 메커니즘을 추가하거나 문구에서 빼라.
#   ⚠️ **이 문장은 2026-10-01 까지 거짓이었다** — 규칙만 적혀 있고 구현이 없었으며, 문구에 새
#      주장을 넣어도 `_claims_in()` 이 못 보고 넘어갔다.
#
# ⚠️ **범위는 합격 문구 한 줄이다.** 중간 단계의 `print` 들(`:39`·`:43`·`:65`·`:76` 등)도
#   과장이 있을 수 있지만 여기서는 단언하지 않는다 — 그 줄들은 합격 여부를 좌우하지 않고,
#   낱말만 보고 판정하면 "배경색은 등급과 무관하게 한 색" 같은 **정정 문장**까지 뒤집어 읽는다.
#   §3 이 그 줄들을 **보고만** 한다.
#
# 재는 것:
#   §0 전제 — 봇 파일을 읽을 수 있고 합격 토큰이 살아 있는가
#   §1 합격 문구의 **모든 주장**에 대응하는 메커니즘이 (주석 아닌) 코드에 있는가
#   §1b 합격 문구의 **모든 구절**이 표에 있는 낱말을 하나라도 포함하는가
#   §2 보고 — 주장 목록과 매칭된 메커니즘
#   §3 보고 — `검증` 을 주장하는 다른 줄들과 그 줄이 쓰는 낱말
#
# ⚠️ 2026-10-01 — 이 프로브가 **두 번** 낡아 있었다 (RC=1). 둘 다 이 창에서 발견했다.
#   ① `"세이브"` 의 메커니즘 목록이 낡았다 — §2.16 **2차 정정**이 명시적 `save_game_state()`
#      호출을 **일부러 지우고** 자동 저장 경로(`tower_positions_changed` → `has_save_file`)로
#      바꿨는데, 표는 옛 심볼만 물었다 → **거짓 빨강**. 봇 문구는 **참**이다
#      (Step 8 이 파일을 지운 뒤 `has_save_file()` 을 단언한다).
#   ② 헤더의 *"표에 없는 주장은 실패로 친다"* 가 **구현되지 않았다** — `_claims_in()` 은 표에
#      **있는** 낱말만 돌려주므로, 문구에 새 주장을 넣으면 **조용히 통과**한다. 실측: 2차 정정이
#      `타워 클릭 팝업`·`자동 저장` 을 문구에 **넣었는데 이 프로브가 못 봤다**. → §1b 신설 +
#      표에 둘 추가.
#      ⚠️ **주석이 코드보다 강한 검사를 주장하면 그 주석은 거짓말이다** — §2.16 이 봇 문구에서
#      잡은 것과 **같은 부류**가 이 프로브 자신의 헤더에 있었다.
#
# 실행: godot --headless --path . res://tools/BotClaimProbe.tscn

const BOT_SCRIPT := "res://scripts/test/AutoPlayTowerDefense.gd"
## 합격 토큰. 이 문자열이 사라지면 `run_all.sh` 가 이 테스트를 '결과 줄 없음' 으로 실패 처리한다.
const PASS_TOKEN := "ALL TESTS PASSED"

## 주장 낱말 → 그 주장을 실제로 재는 코드 심볼. **하나라도** 있으면 통과.
## ⚠️ 문구에 새 주장을 쓰려면 여기에 **메커니즘을 함께** 적어야 한다(안 적으면 §1 이 실패시킨다).
const CLAIM_MECHANISMS := {
	"단축키": ["InputEventKey", "keycode", "_unhandled_input"],
	"툴팁": ["tooltip"],
	"폰트": ["font_size", "add_theme_font_size_override"],
	"큰 텍스트": ["font_size", "add_theme_font_size_override"],
	"도감": ["is_word_discovered", "discover_word"],
	# ⚠️ `has_save_file` 만으로는 **부족하다** — 그 심볼은 Step 8 의 *전제*(`not …`)에도 쓰이므로
	#    단언을 지워도 남는다. 그래서 **단언 형태**를 요구한다(2026-10-01).
	"세이브": ["assert(SaveManager.has_save_file", "save_game_state", "_on_save_pressed"],
	"로드": ["_on_load_pressed"],
	# ⚠️ 2026-10-01 신설 — 2차 정정이 문구에 넣었는데 표에 없어서 **아무도 안 봤던** 주장 둘.
	"타워 클릭 팝업": ["TowerInfoModal", "tower_info_requested", "tower_clicked"],
	"자동 저장": ["tower_positions_changed", "has_save_file"],
	"불러오기": ["_on_load_pressed"],
	"유물": ["apply_relic_effect", "has_relic"],
	"조합": ["parse_jamo_stream"],
	"등급": ["get_rarity"],
	"배경색": ["get_rarity_bg_color"],
}

var failures := 0
## 어느 절에서 실패했는지 기계가 읽게 남긴다(하네스가 한국어를 파싱하지 않도록).
var _section := "S0"

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("BOT_CLAIM FAIL_SECTION %s" % _section)
		push_error(message)

## 주석을 걷어낸 코드만 남긴다.
## ⚠️ `#` 앞의 따옴표가 홀수 개면 문자열 리터럴 **안** 의 `#` 이므로 자르지 않는다
##   (자르면 그 줄의 진짜 코드가 사라져 검사가 조용히 공허해진다).
func _strip_comments(text: String) -> String:
	var out := ""
	for line in text.split("\n"):
		var cut := -1
		var quotes := 0
		for i in range(line.length()):
			var ch := line[i]
			if ch == "\"":
				quotes += 1
			elif ch == "#" and quotes % 2 == 0:
				cut = i
				break
		out += (line if cut < 0 else line.substr(0, cut)) + "\n"
	return out

## 합격 문구를 **구절 목록**으로 나눈다 — 접두 토큰(`ALL TESTS PASSED`)과 장식(`🎉`, `[`, `]`),
## 꼬리말 `검증`·`성공` 을 뗀 뒤 `,`·`/` 로 자른다.
## ⚠️ 이 함수가 §1b 의 **유일한 근거**다 — 여기서 구절을 못 읽으면 §1b 는 **공허**해지므로,
##   호출부가 구절 수를 단언한다(프로브가 공짜로 통과하지 않게).
func _claim_phrases(message: String) -> Array:
	var idx := message.find(PASS_TOKEN)
	var tail := message if idx < 0 else message.substr(idx + PASS_TOKEN.length())
	for junk in ["🎉", "[", "]", "검증", "성공", "!", "\"", ")", "(", ";"]:
		tail = tail.replace(junk, " ")
	var phrases: Array = []
	for part in tail.replace("/", ",").split(","):
		var p := part.strip_edges()
		if p != "":
			phrases.append(p)
	return phrases

## 한 줄이 주장하는 낱말들(표에 있는 것만).
func _claims_in(line: String) -> Array:
	var found: Array = []
	for claim in CLAIM_MECHANISMS.keys():
		if line.contains(claim):
			found.append(claim)
	return found

func _ready() -> void:
	# ── §0 전제 ────────────────────────────────────────────────────────────
	var f := FileAccess.open(BOT_SCRIPT, FileAccess.READ)
	check(f != null, "봇 파일을 못 읽었다: %s" % BOT_SCRIPT)
	if f == null:
		get_tree().quit(failures + 1)
		return
	var raw := f.get_as_text()
	f.close()

	# 합격 문구 줄을 찾는다 — 이 줄이 스위트의 합격 도장이다.
	var message := ""
	for line in raw.split("\n"):
		if line.contains(PASS_TOKEN):
			message = line.strip_edges()
			break
	check(message != "",
		"합격 문구('%s')를 가진 줄이 없다 — `run_all.sh` 가 이 테스트를 실패로 처리한다" % PASS_TOKEN)
	if message == "":
		get_tree().quit(failures + 1)
		return
	print("BOT_CLAIM message=%s" % JSON.stringify(message))

	var code := _strip_comments(raw)

	# ── §1 합격 문구의 모든 주장에 메커니즘이 있는가 ────────────────────────
	_section = "S1"
	var verified := 0
	var unverifiable: Array = []
	for claim in _claims_in(message):
		var mechs: Array = CLAIM_MECHANISMS[claim]
		var hit := ""
		for m in mechs:
			if code.contains(m):
				hit = m
				break
		if hit == "":
			unverifiable.append(claim)
			check(false,
				"합격 문구가 '%s' 를 검증했다고 주장하는데 그걸 재는 코드(%s)가 파일에 **없다** — 거짓 합격 도장이다"
					% [claim, str(mechs)])
		else:
			verified += 1
			print("BOT_CLAIM claim '%s' -> mechanism '%s'" % [claim, hit])
	# ⚠️ 비공허성: 아는 주장을 하나도 못 읽으면 이 검사는 아무것도 안 잰다.
	check(verified + unverifiable.size() >= 1,
		"합격 문구에서 아는 주장을 하나도 못 읽었다 — 이 검사가 공허하다(문구: %s)"
			% JSON.stringify(message))

	# ── §1b 합격 문구에 **표에 없는 주장**이 있는가 ────────────────────────────
	# ⚠️ 헤더가 *"표에 없는 주장은 실패로 친다"* 고 적어 두었는데 **구현이 없었다**(2026-10-01).
	#   `_claims_in()` 은 표에 **있는** 낱말만 돌려주므로 새 주장은 조용히 통과한다 —
	#   §2.16 2차 정정이 `타워 클릭 팝업`·`자동 저장` 을 문구에 넣었는데 이 절이 없어서 못 봤다.
	_section = "S1b"
	var phrases := _claim_phrases(message)
	# ⚠️ 비공허성: 구절을 못 읽으면 §1b 는 아무것도 안 잰다.
	check(phrases.size() >= 1,
		"합격 문구에서 구절을 하나도 못 읽었다 — §1b 가 공허하다(문구: %s)" % JSON.stringify(message))
	var unlisted: Array = []
	for phrase in phrases:
		if _claims_in(phrase).is_empty():
			unlisted.append(phrase)
			check(false,
				"합격 문구의 '%s' 에 대응하는 낱말이 표(CLAIM_MECHANISMS)에 **없다** — 검사할 방법이 없는 주장을 문구에 남기면 이 도구가 조용히 공허해진다(표에 추가하거나 문구에서 빼라)" % phrase)
	print("BOT_CLAIM phrases=%s unlisted=%s" % [str(phrases), str(unlisted)])

	# ── §2 보고 ────────────────────────────────────────────────────────────
	print("BOT_CLAIM verified=%d unverifiable=%d %s"
		% [verified, unverifiable.size(), str(unverifiable)])

	# ── §3 보고 — `검증` 을 주장하는 다른 **로그 줄**들(단언하지 않는다) ──────
	# ⚠️ 주석은 뺀다 — 주석은 '무엇을 하려는가' 이지 합격 판정이 아니다. 대신 파일 머리말이
	#   기능을 나열하며 과장하는지는 **사람이 볼 몫**으로 남긴다(감사 §2.16 참고).
	for line in raw.split("\n"):
		if not line.contains("print(") or not line.contains("검증"):
			continue
		if line.contains(PASS_TOKEN):
			continue
		var claims := _claims_in(line)
		print("BOT_CLAIM other_claim_line %s claims=%s"
			% [JSON.stringify(line.strip_edges()), str(claims)])

	if failures == 0:
		print("BOT_CLAIM_PROBE_OK")
	get_tree().quit(failures)
