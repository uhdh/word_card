extends Node
# 상단 바 툴팁에 **작성자가 둘**인가 — 씬에 적어 둔 문구가 플레이어에게 도달하는가.
#
# 왜 문제인가: `TowerDefenseMain._ready()` 가 씬의 툴팁을 **덮어쓴다.** 씬에 적어 둔 문구는
# 아무에게도 보이지 않는데 파일에는 그대로 남아 있어, 다음 사람이 그걸 고치고 "왜 안 바뀌지"
# 를 겪는다. 이 프로젝트가 만나는 **세 번째 '작성자 둘'** 이다:
#   · §2.13-1 — 카운트다운 라벨 두 개
#   · §2.14   — `btn_stage.tooltip_text` 를 두 함수가 각자 대입
#   · 여기    — `.tscn` 과 `_ready()` 가 같은 노드의 같은 채널을 각자 대입
#
# ⚠️ 이 프로브의 핵심은 **`add_child` 전후 비교**다. 씬 값은 인스턴스화 시점에 이미 들어 있고
#   `_ready()` 는 트리에 들어갈 때 돈다 — 그래서 두 시점을 재면 "씬 문구가 살아남았는가" 를
#   직접 잴 수 있다. 파일 텍스트를 파싱하지 않는다(그건 메커니즘이 아니다).
#
# 재는 것:
#   §0 전제 — 두 씬이 인스턴스화되고 상단 바 버튼을 찾을 수 있는가
#   §1 **씬이 적어 둔 문구가 살아남는가** — 버려지면 실패
#   §1b **다섯 단축키 버튼에 툴팁이 있는가** — `_ready()` 대입이 사라지면 잡힌다
#   §1c **툴팁이 단축키만 말하지 않는가** — 무엇을 하는 버튼인지가 남아 있어야 한다
#
# ⚠️ 2026-10-06 (§2.27) — 목록에서 `BtnStartWave` 를 **뺐다.** 그 노드는 씬에서 `visible = false`
#   이고 코드에 `.show()` 가 0건이라 **영영 안 보였는데**, 목록에 있어서 이 프로브가
#   *"플레이어가 도달할 수 없는 문자열"* 의 내용을 지키고 있었다. 노드·대입과 함께 지웠고,
#   `[SPACE]` 안내는 막 클리어 모달로 옮겼다 — **그 도달**은 `ActClearModalProbe` §2b 가 잰다.
#   §2 보고 — 버려진 문구의 내용 (씬 값 → 실제 값)
#   §3 두 씬(본편·봇)이 같은 버튼에 **같은 문구**를 적었는가
#   §4 보고 — 씬이 유일 작성자인 버튼 (코드가 안 건드린다 = 씬을 고치면 바뀐다)
#   §5 보고 — 상단 바에서 툴팁이 **비어 있는** 버튼
#
# ⚠️ §1c 가 왜 필요한가: §2.17 에서 씬의 중복 사본을 지웠더니 그 사본이 갖고 있던 *기능 설명*
#   까지 함께 사라졌다 — `BtnMute` 는 `단축키: [M]` 만 말해서 **"소리를 끄는 버튼" 이라는 말이
#   어디에도 없었다**(버튼이 아이콘이라 더 나빴다). 툴팁은 이 게임에서 조작을 배우는 유일한
#   통로이므로(튜토리얼·도움말 0건), **키만 나열하는 툴팁은 안내가 아니다.**
#
# ⚠️ 봇 씬(`scenes/tower/AutoPlayTDTest.tscn`)은 **트리에 넣지 않는다** — 넣으면 봇이 돌아
#   측정이 오염된다. 씬 값만 읽으면 되므로 인스턴스화만 하고 버린다.
#
# 실행: godot --headless --path . res://tools/TooltipAuthorProbe.tscn

const MAIN_SCENE := "res://scenes/TowerDefenseMain.tscn"
const BOT_SCENE := "res://scenes/tower/AutoPlayTDTest.tscn"

## `_ready()` 가 툴팁을 쓰는 버튼 — 하나라도 비면 안내가 통째로 사라진다.
const SHORTCUT_BUTTONS := [
	"TopBar/VBoxTop/Row/Actions/BtnSave",
	"TopBar/VBoxTop/Row/Actions/BtnLoad",
	"TopBar/VBoxTop/Row/Actions/BtnSpeed",
	"TopBar/VBoxTop/Row/Actions/BtnLexicon",
	"TopBar/VBoxTop/Row/Actions/BtnMute",
]

var failures := 0
## 어느 절에서 실패했는지 기계가 읽게 남긴다 — 하네스가 한국어를 파싱하지 않아도 되도록.
var _section := "S0"

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("TOOLTIP_AUTHOR FAIL_SECTION %s" % _section)
		push_error(message)

## 인스턴스 안에서 **비어 있지 않은** 툴팁을 경로별로 모은다.
## 경로는 인스턴스 루트 기준이라 두 씬을 같은 키로 비교할 수 있다.
func _collect_tooltips(inst_root: Node, node: Node, out: Dictionary) -> void:
	if node is Control and (node as Control).tooltip_text != "":
		out[String(inst_root.get_path_to(node))] = (node as Control).tooltip_text
	for c in node.get_children():
		_collect_tooltips(inst_root, c, out)

## 툴팁 유무와 무관하게 **모든 Control 의 경로**를 모은다. 두 씬의 노드 구성이 같은지
## 판단해야 하기 때문이다 — 한쪽에만 있는 노드(`BtnAbility`)를 '불일치' 로 세면 안 된다.
func _collect_paths(inst_root: Node, node: Node, out: Array) -> void:
	if node is Control:
		out.append(String(inst_root.get_path_to(node)))
	for c in node.get_children():
		_collect_paths(inst_root, c, out)

## 툴팁에서 `[X]` 토큰과 안내용 꼬리표를 걷어낸 **나머지**. 남는 것이 없으면 그 툴팁은
## **단축키만 말한다**(§1c). 판정은 **문구에서** 한다 — "단축키" 라는 낱말이 사라지면
## 이 함수가 조용히 공허해지므로 §1c 가 비공허성도 함께 잰다.
const SHORTCUT_FILLER := ["단축키", "일시정지", "또는", ":"]
const SEPARATORS := [" ", "—", "-", "/", ",", "·", "(", ")", "\n", "\t"]

func _prose_rest(text: String) -> String:
	var s := text
	# `[...]` 토큰을 전부 제거한다(`[Ctrl + S]` 처럼 내부에 기호가 있어도 통째로).
	while true:
		var i := s.find("[")
		if i < 0:
			break
		var j := s.find("]", i)
		if j < 0:
			break
		s = s.substr(0, i) + s.substr(j + 1)
	for w in SHORTCUT_FILLER:
		s = s.replace(w, "")
	for ch in SEPARATORS:
		s = s.replace(ch, "")
	return s

func _ready() -> void:
	# ── §0 전제 ────────────────────────────────────────────────────────────
	var main_scene: PackedScene = load(MAIN_SCENE)
	var bot_scene: PackedScene = load(BOT_SCENE)
	check(main_scene != null, "본편 씬을 못 읽었다: %s" % MAIN_SCENE)
	check(bot_scene != null, "봇 씬을 못 읽었다: %s" % BOT_SCENE)
	if main_scene == null or bot_scene == null:
		get_tree().quit(failures + 1)
		return

	# ── 씬 값 — 아직 트리에 안 넣었으므로 `_ready()` 가 안 돌았다 ─────────────
	var main_inst: Node = main_scene.instantiate()
	var scene_main: Dictionary = {}
	var paths_main: Array = []
	_collect_tooltips(main_inst, main_inst, scene_main)
	_collect_paths(main_inst, main_inst, paths_main)

	var bot_inst: Node = bot_scene.instantiate()
	var scene_bot: Dictionary = {}
	var paths_bot: Array = []
	_collect_tooltips(bot_inst, bot_inst, scene_bot)
	_collect_paths(bot_inst, bot_inst, paths_bot)
	bot_inst.free()          # 봇은 돌리지 않는다 — 씬 값만 필요하다

	check(not scene_main.is_empty(), "본편 씬에 툴팁이 하나도 없다 — 전제가 틀렸다")
	check(not scene_bot.is_empty(), "봇 씬에 툴팁이 하나도 없다 — 두 씬 비교가 공허하다")

	# ── 트리에 넣고 `_ready()` 를 태운다 ────────────────────────────────────
	add_child(main_inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var live_main: Dictionary = {}
	_collect_tooltips(main_inst, main_inst, live_main)

	print("TOOLTIP_AUTHOR scene_tooltips=%d live_tooltips=%d" % [scene_main.size(), live_main.size()])

	# ── §1 씬 문구가 살아남았는가 ───────────────────────────────────────────
	_section = "S1"
	var discarded: Array = []
	for path in scene_main.keys():
		var before: String = scene_main[path]
		var after: String = live_main.get(path, "")
		if after != before:
			discarded.append([path, before, after])
		# 씬이 문구를 적어 뒀으면, 최종 상태에도 문구가 있어야 한다(지워지는 것도 결함).
		check(after != "",
			"'%s' 은 씬에 툴팁을 적어 뒀는데 런타임에는 **비어 있다** — 안내가 통째로 사라진다" % path)
	check(discarded.is_empty(),
		"씬에 적어 둔 툴팁 %d개가 `_ready()` 에게 **버려진다** — 씬을 고쳐도 플레이어에게 안 간다 (%s)"
			% [discarded.size(), str(discarded.map(func(d): return d[0].get_file()))])

	# ── §1b 단축키 버튼에 툴팁이 있는가 ─────────────────────────────────────
	# §1 은 **씬에 문구가 있는** 경로만 본다 — 그래서 `_ready()` 의 대입이 통째로 사라지면
	# 아무것도 못 잡는다. 이 절이 그 구멍을 막는다(작성자가 사라진 것도 결함이다).
	#
	# ⚠️ 2026-09-24: 이 절에는 **태그가 없었다.** 그래서 `_ready()` 의 대입을 지워도 실패가
	#   `FAIL_SECTION S1` 로 찍혀 §1 과 **구별되지 않았다** — 하네스의 K3 가 `MISSED` 로
	#   잡아 주지 않았으면 "§1b 가 지킨다" 고 잘못 적을 뻔했다. **절을 만들면 태그도 만들라**;
	#   주석의 목록과 태그의 목록이 어긋나면 그 절은 없는 것과 같다.
	_section = "S1b"
	var missing: Array = []
	for p in SHORTCUT_BUTTONS:
		if String(live_main.get(p, "")) == "":
			missing.append(p)
	check(missing.is_empty(),
		"단축키 버튼 %d개에 툴팁이 **없다** — 조작을 알려 주는 문구가 사라졌다 (%s)"
			% [missing.size(), str(missing)])

	# ── §1c 상단 바 툴팁은 **단축키만** 말하지 않는가 ───────────────────────
	# §1b 는 "비어 있지 않은가" 만 잰다 — `단축키: [M]` 도 통과한다. 그런데 그건 안내가 아니다.
	# §2.17 의 고침이 씬 사본과 함께 *기능 설명* 을 지웠기 때문에 이 절이 필요하다(헤더 참고).
	_section = "S1c"
	var shortcut_only: Array = []
	var prose_seen := 0
	for p in SHORTCUT_BUTTONS:
		var tip := String(live_main.get(p, ""))
		if tip == "":
			continue          # §1b 가 잡는다 — 여기서 이중으로 세지 않는다
		if _prose_rest(tip) == "":
			shortcut_only.append([p.get_file(), tip])
		else:
			prose_seen += 1
	# ⚠️ 비공허성: 다섯 중 하나라도 "무엇을 하는가" 를 말해야 이 절이 의미를 갖는다.
	check(prose_seen >= 1,
		"상단 바 툴팁 다섯 개 중 **하나도** 기능 설명을 갖지 않는다 — §1c 가 공허하다")
	check(shortcut_only.is_empty(),
		"상단 바 툴팁 %d개가 **단축키만** 말한다 — 그 버튼이 무엇을 하는지 알 길이 없다 (%s)"
			% [shortcut_only.size(), str(shortcut_only)])
	print("TOOLTIP_AUTHOR SHORTCUT_ONLY %d개 %s / 기능설명있음 %d개"
		% [shortcut_only.size(), str(shortcut_only), prose_seen])

	# ── §2 보고 — 버려진 문구의 내용 ────────────────────────────────────────
	for d in discarded:
		print("TOOLTIP_AUTHOR DISCARDED %s" % d[0])
		print("TOOLTIP_AUTHOR   scene=%s" % JSON.stringify(d[1]))
		print("TOOLTIP_AUTHOR   live =%s" % JSON.stringify(d[2]))

	# ── §3 두 씬이 같은 문구를 적었는가 ─────────────────────────────────────
	# ⚠️ '한쪽에만 있는 노드' 는 불일치가 아니다 — 봇 씬에는 `BtnAbility` 가 아예 없다.
	#   그래서 노드 구성(`paths_*`)을 먼저 보고, **양쪽에 다 있는 노드**만 비교한다.
	_section = "S3"
	var shared := 0
	var absent := 0
	var mismatch: Array = []
	for path in scene_main.keys():
		if not paths_bot.has(path):
			absent += 1
			continue
		shared += 1
		if String(scene_bot.get(path, "")) != String(scene_main[path]):
			mismatch.append(path)
	for path in scene_bot.keys():
		if not paths_main.has(path):
			absent += 1
			continue
		shared += 1
		if String(scene_main.get(path, "")) != String(scene_bot[path]):
			mismatch.append(path)
	print("TOOLTIP_AUTHOR cross_scene shared=%d absent_in_other=%d mismatch=%d"
		% [shared, absent, mismatch.size()])
	for p in mismatch:
		print("TOOLTIP_AUTHOR   DIFF %s\n    main=%s\n    bot =%s"
			% [p, JSON.stringify(scene_main.get(p, "")), JSON.stringify(scene_bot.get(p, ""))])
	check(shared >= 1, "두 씬에 겹치는 툴팁 경로가 없다 — §3 이 공허하다")
	check(mismatch.is_empty(),
		"두 씬이 같은 버튼에 다른 문구를 적었다 (%d개) — 어느 쪽이 플레이어에게 가는지에 따라 안내가 달라진다" % mismatch.size())

	# ── §4 보고 — 씬이 유일 작성자인 버튼 ───────────────────────────────────
	var scene_only: Array = []
	for path in scene_main.keys():
		if not discarded.any(func(d): return d[0] == path):
			scene_only.append(path)
	print("TOOLTIP_AUTHOR SCENE_ONLY_AUTHOR %d개 — 이 버튼들은 씬을 고치면 플레이어에게 간다" % scene_only.size())
	for p in scene_only:
		print("TOOLTIP_AUTHOR   %s" % p)

	# ── §5 보고 — 상단 바에서 툴팁이 비어 있는 버튼 ─────────────────────────
	var bare: Array = []
	for p in paths_main:
		var n := main_inst.get_node_or_null(NodePath(p))
		if n is Button and not (n as Button).tooltip_text:
			bare.append(p)
	print("TOOLTIP_AUTHOR BARE_BUTTONS %d개 %s" % [bare.size(), str(bare)])

	if failures == 0:
		print("TOOLTIP_AUTHOR_PROBE_OK")
	get_tree().quit(failures)
