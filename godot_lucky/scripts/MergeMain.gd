extends Control
## 『언어의 조각 : 무한 병합』 — 화면과 조작.
##
## 무대 = 참고 영상(그리드 병합 랜덤 디펜스) · 자모→단어 = 기존 게임에서 그대로.
## 규칙·수치는 `MergeRules`, 상태·판정은 `MergeGame`, 그리기는 `MergeBoard` 에 있다.
## 이 파일은 **셋을 잇고 화면 글자를 채우는 일**만 한다.

const FONT := preload("res://fonts/neodgm.ttf")

const SPEEDS := [1.0, 2.0, 4.0]

var _game: MergeGame
var _board: MergeBoard
var _board_wrap: Control

var _speed_idx := 0
var _msg := ""
var _msg_t := 0.0
var _wave_total := 0
var _wave_seen := -1

# 갱신해야 하는 화면 요소
var _lbl_gold: Label
var _lbl_hp: Label
var _lbl_info: Label
var _lbl_monsters: Label
var _lbl_summon: Label
var _lbl_banner: Label
var _bar: ProgressBar
var _lbl_goal1: Label
var _lbl_goal1_sub: Label
var _lbl_goal2: Label
var _lbl_goal2_sub: Label
var _lbl_bottom: Label
var _lbl_keys: Label
var _btn_wave: PanelContainer
var _btn_wave_label: Label
var _btn_speed: Label
var _subs: Dictionary = {}
var _overlay: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = MergePalette.BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_game = MergeGame.new()
	_game.name = "Game"
	add_child(_game)
	_game.changed.connect(_refresh)
	_game.message.connect(_on_message)
	_game.game_over.connect(_on_game_over)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	margin.add_child(main)
	main.add_child(_build_top_bar())
	main.add_child(_build_board_area())
	main.add_child(_build_actions())
	main.add_child(_build_bottom_bar())

	_build_overlay()
	_refresh()


func _process(delta: float) -> void:
	if _game == null:
		return
	_game.tick(delta * SPEEDS[_speed_idx])
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg = ""
	_refresh()
	if _board != null:
		_board.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			_game.start_wave()
		KEY_1:
			_on_action("pull")
		KEY_2:
			_on_action("upgrade")
		KEY_3:
			_on_action("combine")
		KEY_4:
			_on_action("sell")
		KEY_TAB:
			_speed_idx = (_speed_idx + 1) % SPEEDS.size()
		KEY_R:
			_game.reset()


# ══ 상단 ═════════════════════════════════════════════════
func _build_top_bar() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	_lbl_gold = _label("", 22, MergePalette.GOLD)
	row1.add_child(_pill(_hbox([_dot(MergePalette.GOLD, 22), _lbl_gold]),
		MergePalette.PANEL, MergePalette.PANEL_EDGE, 18))
	_btn_speed = _label("▶  ×1", 19, MergePalette.TEXT)
	var speed_pill := _pill(_btn_speed, MergePalette.PANEL, MergePalette.PANEL_EDGE, 18)
	speed_pill.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_speed_idx = (_speed_idx + 1) % SPEEDS.size())
	row1.add_child(speed_pill)
	var restart := _pill(_label("다시 시작", 18, MergePalette.TEXT_DIM),
		MergePalette.PANEL, MergePalette.PANEL_EDGE, 18)
	restart.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_game.reset())
	row1.add_child(restart)
	row1.add_child(_spacer())
	_lbl_hp = _label("", 21, MergePalette.TEXT)
	row1.add_child(_pill(_hbox([_dot(MergePalette.HP_RED, 18), _lbl_hp]),
		MergePalette.PANEL, MergePalette.PANEL_EDGE, 18))
	box.add_child(row1)

	var row2 := HBoxContainer.new()
	row2.add_child(_spacer())
	_lbl_info = _label("", 15, MergePalette.TEXT_MUTE)
	row2.add_child(_lbl_info)
	box.add_child(row2)

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 8)
	_lbl_monsters = _label("", 19, MergePalette.TEXT)
	row3.add_child(_lbl_monsters)
	row3.add_child(_spacer())
	_btn_wave_label = _label("웨이브 시작", 18, MergePalette.TEXT)
	_btn_wave = _pill(_btn_wave_label, MergePalette.BTN_PULL, MergePalette.BTN_PULL_EDGE, 14)
	_btn_wave.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_game.start_wave())
	row3.add_child(_btn_wave)
	row3.add_child(_spacer())
	_lbl_summon = _label("", 17, MergePalette.TEXT_DIM)
	row3.add_child(_lbl_summon)
	box.add_child(row3)

	_lbl_banner = _label("", 18, MergePalette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_lbl_banner)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 12)
	_bar.max_value = 100.0
	_bar.show_percentage = false
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_theme_stylebox_override("background", _sb(Color("0d1730"), 6, 0, Color(0, 0, 0, 0), 0))
	_bar.add_theme_stylebox_override("fill", _sb(Color("57c46a"), 6, 0, Color(0, 0, 0, 0), 0))
	box.add_child(_bar)

	var goals := HBoxContainer.new()
	goals.add_theme_constant_override("separation", 10)
	var g1 := _goal(MergePalette.GOLD)
	_lbl_goal1 = g1[0]
	_lbl_goal1_sub = g1[1]
	goals.add_child(g1[2])
	var g2 := _goal(MergePalette.RING_CYAN)
	_lbl_goal2 = g2[0]
	_lbl_goal2_sub = g2[1]
	goals.add_child(g2[2])
	box.add_child(goals)

	return box


func _goal(accent: Color) -> Array:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	var title := _label("", 17, accent, HORIZONTAL_ALIGNMENT_CENTER)
	var sub := _label("", 14, MergePalette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(title)
	v.add_child(sub)
	var pc := _pill(v, MergePalette.PANEL, MergePalette.PANEL_EDGE, 14)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return [title, sub, pc]


# ══ 보드 ═════════════════════════════════════════════════
func _build_board_area() -> Control:
	_board_wrap = Control.new()
	_board_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_wrap.resized.connect(_fit_board)

	var glow := Panel.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.add_theme_stylebox_override("panel", _sb(MergePalette.BG_MID, 24, 0, Color(0, 0, 0, 0), 0))
	_board_wrap.add_child(glow)

	_board = MergeBoard.new()
	_board.game = _game
	_board_wrap.add_child(_board)
	return _board_wrap


func _fit_board() -> void:
	if _board == null or _board_wrap == null:
		return
	var s := maxf(120.0, minf(_board_wrap.size.x, _board_wrap.size.y))
	_board.size = Vector2(s, s)
	_board.position = (_board_wrap.size - Vector2(s, s)) * 0.5


# ══ 하단 버튼 ════════════════════════════════════════════
func _build_actions() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_action("pull", "뽑기", MergePalette.BTN_PULL, MergePalette.BTN_PULL_EDGE))
	row.add_child(_action("upgrade", "강화", MergePalette.BTN_UPGRADE, MergePalette.BTN_UPGRADE_EDGE))
	row.add_child(_action("combine", "조합", MergePalette.BTN_SLATE, MergePalette.BTN_SLATE_EDGE))
	row.add_child(_action("sell", "판매", MergePalette.BTN_SLATE, MergePalette.BTN_SLATE_EDGE))
	return row


func _action(key: String, title: String, bg: Color, edge: Color) -> Control:
	var wrap := Control.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.custom_minimum_size = Vector2(0, 92)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _sb(bg, 16, 2, edge, 8))
	wrap.add_child(panel)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	v.add_child(_label(title, 22, MergePalette.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var sub := _label("", 14, Color(1, 1, 1, 0.80), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(sub)
	panel.add_child(v)
	_subs[key] = sub

	var btn := Button.new()
	btn.flat = true
	btn.text = ""
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_action.bind(key))
	wrap.add_child(btn)
	return wrap


func _on_action(key: String) -> void:
	var err := ""
	match key:
		"pull":
			err = _game.pull()
		"upgrade":
			err = _game.upgrade()
		"combine":
			err = _game.combine()
		"sell":
			err = _game.sell()
	if err != "":
		_on_message(err)


# ══ 하단 바 ══════════════════════════════════════════════
func _build_bottom_bar() -> Control:
	_lbl_bottom = _label("", 16, MergePalette.TEXT_DIM)
	_lbl_keys = _label("", 15, MergePalette.TEXT_MUTE)
	# ⚠️ 긴 안내문을 **한 Label + 줄바꿈** 으로 두면 안 된다.
	#    줄바꿈 Label 은 아직 폭이 없을 때 **글자마다** 접혀 최소 높이가 928px 로 폭발하고
	#    (LayoutDiag 실측), 그 높이가 VBox → MarginContainer 로 올라가 세로로 136px 넘친다.
	#    짧은 줄 둘로 나눠 쌓으면 그 순환이 아예 없다.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_lbl_bottom)
	col.add_child(_lbl_keys)
	var pc := _pill(_hbox([_dot(MergePalette.GOLD, 16), col]),
		Color("1a2146"), Color("2f3a68"), 14)
	return pc


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	center.add_child(v)
	v.add_child(_label("기지 함락", 34, MergePalette.HP_RED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_label("R 키 또는 아래 버튼으로 다시 시작", 17, MergePalette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var again := _pill(_label("다시 시작", 22, MergePalette.TEXT), MergePalette.BTN_PULL, MergePalette.BTN_PULL_EDGE, 16)
	again.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_game.reset())
	v.add_child(again)


# ══ 갱신 ═════════════════════════════════════════════════
func _refresh() -> void:
	if _game == null:
		return
	_lbl_gold.text = "%d" % _game.gold
	_lbl_hp.text = "%d / %d" % [_game.base_hp, MergeRules.START_HP]
	_btn_speed.text = "▶  ×%d" % int(SPEEDS[_speed_idx])
	_lbl_info.text = "라운드 %d · 보스 %d라운드마다 · 배속 ×%d" % [
		maxi(_game.wave, 1), MergeRules.BOSS_EVERY, int(SPEEDS[_speed_idx])]

	var alive := _game.pending + _game.enemies.size()
	# ⚠️ `maxi` 로 누적하면 **다시 시작한 뒤에도 지난 판의 최대치**가 남아 진행 바가 어긋난다
	#    (7라운드까지 가서 리셋하면 1라운드에서 5/11 로 표시). 라운드가 바뀔 때 다시 센다.
	if _game.wave != _wave_seen:
		_wave_seen = _game.wave
		_wave_total = MergeRules.enemy_count(maxi(_game.wave, 1))
	# 계획 단계에는 아직 몬스터가 없다 — "0 / 5" 는 "0마리 남음" 처럼 읽힌다.
	if _game.phase == "planning":
		_lbl_monsters.text = "대기 중"
	else:
		_lbl_monsters.text = "몬스터 %d / %d" % [alive, _wave_total]
	_lbl_summon.text = "다음 웨이브 %d마리" % MergeRules.enemy_count(_game.wave + 1)

	if _game.phase == "planning":
		_btn_wave_label.text = "웨이브 시작"
		_btn_wave_label.add_theme_color_override("font_color", MergePalette.TEXT)
	elif _game.phase == "wave":
		_btn_wave_label.text = "진행 중…"
		_btn_wave_label.add_theme_color_override("font_color", MergePalette.TEXT_MUTE)
	else:
		_btn_wave_label.text = "끝남"
		_btn_wave_label.add_theme_color_override("font_color", MergePalette.TEXT_MUTE)

	# 계획 단계에서는 아직 아무것도 안 잡았다 — 가득 찬 바는 "다 끝났다" 로 읽힌다.
	_bar.value = 0.0 if (_game.phase == "planning" or _wave_total <= 0) \
		else 100.0 * float(_wave_total - alive) / float(_wave_total)

	_lbl_goal1.text = "◆  자모 타일"
	_lbl_goal1_sub.text = "%d / %d 칸" % [_game.tile_count(), MergeRules.INNER * MergeRules.INNER]
	var known := 0
	for t in _game.towers:
		if bool(t["matched"]):
			known += 1
	_lbl_goal2.text = "◆  단어 타워"
	# ⚠️ `matched` 는 "사전에 있는 단어인가" 가 아니라 **"공격 형태가 단어의 뜻에서 왔는가"**
	#    다 (AttackStyle: exact/rule = 참, category 폴백 = 거짓). 사전에 있어도 분류 폴백으로
	#    떨어지는 단어가 많으므로 '사전' 이라고 쓰면 거짓말이 된다.
	_lbl_goal2_sub.text = "%d개 · 뜻 반영 %d" % [_game.towers.size(), known]

	_lbl_banner.text = _msg

	_subs["pull"].text = "%d G" % MergeRules.pull_cost(_game.pull_count)
	var sel: Dictionary = _game.tiles.get(_game.selected, {})
	if sel.is_empty():
		_subs["upgrade"].text = "타일 선택"
		_subs["combine"].text = "타일 선택"
		_subs["sell"].text = "타일 선택"
	else:
		var tier := int(sel["tier"])
		_subs["upgrade"].text = "%d G" % (tier * MergeRules.UPGRADE_COST_PER_TIER)
		_subs["combine"].text = "%d G" % MergeRules.COMBINE_COST
		_subs["sell"].text = "+%d G" % (tier * MergeRules.SELL_GOLD_PER_TIER)

	var picked := "—"
	if not sel.is_empty():
		picked = "%s  ★%d" % [str(sel["jamo"]), int(sel["tier"])]
	_lbl_bottom.text = "고른 타일: %s   ·   빈 칸을 누르면 옮겨집니다" % picked
	_lbl_keys.text = "[SPACE] 웨이브   [1~4] 버튼   [TAB] 배속   [R] 다시"

	if _overlay != null:
		_overlay.visible = _game.phase == "over"


func _on_message(text: String) -> void:
	_msg = text
	_msg_t = 3.0


func _on_game_over() -> void:
	_on_message("기지가 함락되었습니다 — %d라운드" % _game.wave)


# ══ 잔손질 ═══════════════════════════════════════════════
func _label(text: String, fsize: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _hbox(children: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	for c in children:
		h.add_child(c)
	return h


func _dot(color: Color, d: float) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(d, d)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(d * 0.5))
	p.add_theme_stylebox_override("panel", sb)
	return p


func _pill(child: Control, bg: Color, edge: Color, radius := 16) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _sb(bg, radius, 2, edge, 12))
	pc.add_child(child)
	return pc


func _sb(bg: Color, radius: int, border: int, edge: Color, pad := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = edge
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = maxf(pad * 0.6, 4.0)
	sb.content_margin_bottom = maxf(pad * 0.6, 4.0)
	return sb
