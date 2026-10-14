# build_theme.gd — 디자인 시스템 테마 리소스를 코드로 생성한다.
# 실행: godot --headless --path godot --script res://tools/build_theme.gd
#
# 왜 코드로 만드는가:
#   .tres 를 손으로 쓰면 오타/UID 문제가 생기고 diff가 지저분하다.
#   이 스크립트가 디자인 토큰의 "실행 가능한 명세" 역할을 한다.
#   팔레트를 바꾸려면 Palette.gd 를 고치고 이 스크립트를 다시 돌린다.
extends SceneTree

const Palette = preload("res://scripts/ui/Palette.gd")

const OUT_PATH := "res://ui/theme/game_theme.tres"
const FONT_PATH := "res://fonts/neodgm.ttf"


func _init() -> void:
	var theme := Theme.new()

	# ── 전역 폰트 ──────────────────────────────────────────
	var font: FontFile = load(FONT_PATH)
	theme.default_font = font
	theme.default_font_size = 14
	theme.default_base_scale = 0.0

	_setup_button(theme, font)
	_setup_panel(theme)
	_setup_label(theme)
	_setup_progress_bar(theme)
	_setup_line_edit(theme)
	_setup_scroll(theme)
	_setup_popup(theme)
	_setup_tooltip(theme)
	_setup_type_variations(theme)

	var err := ResourceSaver.save(theme, OUT_PATH)
	if err != OK:
		printerr("테마 저장 실패: ", err)
		quit(1)
		return
	print("✅ 테마 생성 완료: ", OUT_PATH)
	print("   타입 수: ", theme.get_type_list().size())
	quit()


# ── StyleBox 헬퍼 ──────────────────────────────────────────
func _box(bg: Color, border: Color, width: int, radius: int,
		pad_h: int = 12, pad_v: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


func _flat(bg: Color, radius: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	return sb


func _sb_empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


# ── Button ────────────────────────────────────────────────
func _setup_button(theme: Theme, font: FontFile) -> void:
	theme.set_stylebox("normal",   "Button", _box(Palette.BG_PANEL,    Palette.LINE_NORMAL, 1, 8))
	theme.set_stylebox("hover",    "Button", _box(Palette.BG_PANEL_HI, Palette.LINE_STRONG, 1, 8))
	theme.set_stylebox("pressed",  "Button", _box(Palette.BG_INSET,    Palette.MANA_INK,    2, 8))
	theme.set_stylebox("focus",    "Button", _box(Color(0, 0, 0, 0),  Palette.MANA_INK,    2, 8, 0, 0))
	theme.set_stylebox("disabled", "Button", _box(Palette.BG_PANEL,    Palette.LINE_SUBTLE, 1, 8))
	theme.set_color("font_color",         "Button", Palette.TX_PRIMARY)
	theme.set_color("font_hover_color",   "Button", Palette.TX_ON_DARK)
	theme.set_color("font_pressed_color", "Button", Palette.MANA_INK)
	theme.set_color("font_focus_color",   "Button", Palette.TX_PRIMARY)
	theme.set_color("font_disabled_color","Button", Palette.TX_MUTED)
	theme.set_font_size("font_size", "Button", 14)
	theme.set_constant("h_separation", "Button", 6)

	# MenuButton (설정) — 팝업 화살표가 있는 버튼
	for sb_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := theme.get_stylebox(sb_name, "Button")
		if sb is StyleBoxFlat:
			theme.set_stylebox(sb_name, "MenuButton", sb.duplicate())
	theme.set_color("font_color", "MenuButton", Palette.TX_PRIMARY)
	theme.set_color("font_hover_color", "MenuButton", Palette.TX_ON_DARK)
	theme.set_font_size("font_size", "MenuButton", 14)


# ── Panel / PanelContainer ────────────────────────────────
func _setup_panel(theme: Theme) -> void:
	theme.set_stylebox("panel", "Panel", _box(Palette.BG_PANEL, Palette.LINE_NORMAL, 1, 10, 12, 10))
	theme.set_stylebox("panel", "PanelContainer", _box(Palette.BG_PANEL, Palette.LINE_NORMAL, 1, 10, 12, 10))

	# 모달용 변형
	theme.set_type_variation("ModalPanel", "PanelContainer")
	theme.set_stylebox("panel", "ModalPanel",
		_box(Palette.BG_VOID_98, Palette.LINE_STRONG, 2, 12, 20, 18))

	# 카드용 변형 (상점 아이템 등)
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel",
		_box(Palette.BG_PANEL_HI, Palette.LINE_NORMAL, 1, 8, 12, 10))

	# 함몰 영역 (입력/리스트 배경)
	theme.set_type_variation("InsetPanel", "PanelContainer")
	theme.set_stylebox("panel", "InsetPanel",
		_box(Palette.BG_INSET, Palette.LINE_SUBTLE, 1, 8, 10, 8))

	# 상단바
	theme.set_type_variation("TopBarPanel", "PanelContainer")
	var topbar := StyleBoxFlat.new()
	topbar.bg_color = Palette.BG_VOID_96
	topbar.border_color = Palette.LINE_NORMAL
	topbar.border_width_bottom = 2
	topbar.content_margin_left = 14
	topbar.content_margin_right = 14
	topbar.content_margin_top = 6
	topbar.content_margin_bottom = 6
	theme.set_stylebox("panel", "TopBarPanel", topbar)

	# 예고 바 (얇은 가로 띠 — 세로 패딩 최소)
	theme.set_type_variation("TelegraphPanel", "PanelContainer")
	var tele := StyleBoxFlat.new()
	tele.bg_color = Palette.BG_INSET
	tele.border_color = Palette.LINE_SUBTLE
	tele.set_border_width_all(1)
	tele.set_corner_radius_all(8)
	tele.content_margin_left = 14
	tele.content_margin_right = 14
	tele.content_margin_top = 3
	tele.content_margin_bottom = 3
	theme.set_stylebox("panel", "TelegraphPanel", tele)

	# 자모 벨트 (하단 고정 영역)
	theme.set_type_variation("BeltPanel", "PanelContainer")
	var belt := StyleBoxFlat.new()
	belt.bg_color = Palette.BG_DEEP
	belt.border_color = Palette.LINE_NORMAL
	belt.border_width_top = 2
	belt.set_corner_radius_all(12)
	belt.corner_radius_bottom_left = 0
	belt.corner_radius_bottom_right = 0
	belt.content_margin_left = 14
	belt.content_margin_right = 14
	belt.content_margin_top = 8
	belt.content_margin_bottom = 8
	theme.set_stylebox("panel", "BeltPanel", belt)


# ── Label ─────────────────────────────────────────────────
func _setup_label(theme: Theme) -> void:
	theme.set_color("font_color", "Label", Palette.TX_PRIMARY)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_constant("shadow_outline_size", "Label", 1)
	theme.set_font_size("font_size", "Label", 14)

	theme.set_color("default_color", "RichTextLabel", Palette.TX_PRIMARY)
	theme.set_font_size("normal_font_size", "RichTextLabel", 14)

	# 변형: 제목 / 보조 / 흐림
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font_size("font_size", "TitleLabel", 22)
	theme.set_color("font_color", "TitleLabel", Palette.TX_GOLD)

	theme.set_type_variation("HeadingLabel", "Label")
	theme.set_font_size("font_size", "HeadingLabel", 18)
	theme.set_color("font_color", "HeadingLabel", Palette.TX_PRIMARY)

	theme.set_type_variation("MutedLabel", "Label")
	theme.set_font_size("font_size", "MutedLabel", 12)
	theme.set_color("font_color", "MutedLabel", Palette.TX_SECONDARY)

	theme.set_type_variation("StatLabel", "Label")
	theme.set_font_size("font_size", "StatLabel", 14)
	theme.set_color("font_color", "StatLabel", Palette.TX_GOLD)

	theme.set_type_variation("DangerLabel", "Label")
	theme.set_color("font_color", "DangerLabel", Palette.HP_DANGER)


# ── ProgressBar (적 HP바) ──────────────────────────────────
func _setup_progress_bar(theme: Theme) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.04, 0.08, 0.85)
	bg.set_corner_radius_all(4)
	bg.border_color = Palette.LINE_SUBTLE
	bg.set_border_width_all(1)

	var fg := StyleBoxFlat.new()
	fg.bg_color = Palette.HP_GOOD
	fg.set_corner_radius_all(3)

	theme.set_stylebox("background", "ProgressBar", bg)
	theme.set_stylebox("fill", "ProgressBar", fg)
	theme.set_color("font_color", "ProgressBar", Palette.TX_PRIMARY)
	theme.set_font_size("font_size", "ProgressBar", 12)


# ── LineEdit ──────────────────────────────────────────────
func _setup_line_edit(theme: Theme) -> void:
	theme.set_stylebox("normal", "LineEdit", _box(Palette.BG_INSET, Palette.LINE_NORMAL, 1, 8, 10, 8))
	theme.set_stylebox("focus",  "LineEdit", _box(Palette.BG_INSET, Palette.MANA_INK,   2, 8, 10, 8))
	theme.set_stylebox("read_only", "LineEdit", _box(Palette.BG_VOID, Palette.LINE_SUBTLE, 1, 8, 10, 8))
	theme.set_color("font_color",             "LineEdit", Palette.TX_PRIMARY)
	theme.set_color("font_placeholder_color", "LineEdit", Palette.TX_MUTED)
	theme.set_color("caret_color",            "LineEdit", Palette.MANA_INK)
	theme.set_color("selection_color",        "LineEdit", Palette.with_alpha(Palette.MANA_INK, 0.35))
	theme.set_font_size("font_size", "LineEdit", 14)


# ── ScrollContainer / ScrollBar ───────────────────────────
func _setup_scroll(theme: Theme) -> void:
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Palette.with_alpha(Palette.LINE_STRONG, 0.85)
	grabber.set_corner_radius_all(4)
	grabber.content_margin_left = 4
	grabber.content_margin_right = 4

	var grabber_hl := grabber.duplicate() as StyleBoxFlat
	grabber_hl.bg_color = Palette.MANA_INK

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0)
	track.set_corner_radius_all(4)

	var scroll := StyleBoxEmpty.new()

	for bar in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, track)
		theme.set_stylebox("scroll_focus", bar, track)
		theme.set_stylebox("grabber", bar, grabber)
		theme.set_stylebox("grabber_highlight", bar, grabber_hl)
		theme.set_stylebox("grabber_pressed", bar, grabber)
	theme.set_stylebox("panel", "ScrollContainer", scroll)


# ── PopupMenu / PopupPanel ────────────────────────────────
func _setup_popup(theme: Theme) -> void:
	theme.set_stylebox("panel", "PopupPanel", _box(Palette.BG_VOID_98, Palette.LINE_STRONG, 1, 10, 8, 8))

	var hover := StyleBoxFlat.new()
	hover.bg_color = Palette.BG_PANEL_HI
	hover.set_corner_radius_all(6)
	hover.content_margin_left = 10
	hover.content_margin_right = 10
	hover.content_margin_top = 5
	hover.content_margin_bottom = 5

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0, 0, 0, 0)
	disabled.content_margin_left = 10
	disabled.content_margin_right = 10

	theme.set_stylebox("hover", "PopupMenu", hover)
	theme.set_stylebox("disabled", "PopupMenu", disabled)
	theme.set_stylebox("separator", "PopupMenu", _flat(Palette.LINE_SUBTLE))
	theme.set_color("font_color", "PopupMenu", Palette.TX_PRIMARY)
	theme.set_color("font_hover_color", "PopupMenu", Palette.TX_ON_DARK)
	theme.set_color("font_disabled_color", "PopupMenu", Palette.TX_MUTED)
	theme.set_font_size("font_size", "PopupMenu", 14)
	theme.set_constant("v_separation", "PopupMenu", 4)
	theme.set_constant("item_start_padding", "PopupMenu", 10)
	theme.set_constant("item_end_padding", "PopupMenu", 10)


# ── Tooltip ───────────────────────────────────────────────
func _setup_tooltip(theme: Theme) -> void:
	var t := StyleBoxFlat.new()
	t.bg_color = Palette.BG_VOID_98
	t.border_color = Palette.LINE_STRONG
	t.set_border_width_all(1)
	t.set_corner_radius_all(8)
	t.content_margin_left = 10
	t.content_margin_right = 10
	t.content_margin_top = 7
	t.content_margin_bottom = 7
	theme.set_stylebox("panel", "TooltipPanel", t)
	theme.set_color("font_color", "TooltipLabel", Palette.TX_SECONDARY)
	theme.set_font_size("font_size", "TooltipLabel", 12)
	theme.set_constant("shadow_offset_x", "TooltipLabel", 0)
	theme.set_constant("shadow_offset_y", "TooltipLabel", 1)


# ── 시맨틱 버튼 변형 ──────────────────────────────────────
func _setup_type_variations(theme: Theme) -> void:
	# 주요 액션 (웨이브 시작 등) — 매니컬러 강조
	theme.set_type_variation("PrimaryButton", "Button")
	var pn := _box(Palette.with_alpha(Palette.MANA_INK, 0.25), Palette.MANA_INK, 2, 8)
	var ph := _box(Palette.with_alpha(Palette.MANA_INK, 0.42), Palette.MANA_INK, 2, 8)
	var pp := _box(Palette.with_alpha(Palette.MANA_INK, 0.62), Palette.TX_ON_DARK, 2, 8)
	theme.set_stylebox("normal", "PrimaryButton", pn)
	theme.set_stylebox("hover", "PrimaryButton", ph)
	theme.set_stylebox("pressed", "PrimaryButton", pp)
	theme.set_color("font_color", "PrimaryButton", Palette.TX_ON_DARK)
	theme.set_font_size("font_size", "PrimaryButton", 15)

	# 고스트 버튼 (아이콘 전용 / 보조 액션)
	theme.set_type_variation("GhostButton", "Button")
	theme.set_stylebox("normal", "GhostButton", _box(Color(0, 0, 0, 0), Palette.LINE_SUBTLE, 1, 8, 10, 5))
	theme.set_stylebox("hover", "GhostButton", _box(Palette.BG_PANEL_HI, Palette.LINE_STRONG, 1, 8, 10, 5))
	theme.set_stylebox("pressed", "GhostButton", _box(Palette.BG_INSET, Palette.MANA_INK, 2, 8, 10, 5))
	theme.set_color("font_color", "GhostButton", Palette.TX_SECONDARY)
	theme.set_color("font_hover_color", "GhostButton", Palette.TX_PRIMARY)
	theme.set_font_size("font_size", "GhostButton", 13)

	# 위험 버튼 (새 게임 / 초기화)
	theme.set_type_variation("DangerButton", "Button")
	theme.set_stylebox("normal", "DangerButton", _box(Color(0, 0, 0, 0), Palette.with_alpha(Palette.HP_DANGER, 0.6), 1, 8, 10, 5))
	theme.set_stylebox("hover", "DangerButton", _box(Palette.with_alpha(Palette.HP_DANGER, 0.22), Palette.HP_DANGER, 1, 8, 10, 5))
	theme.set_stylebox("pressed", "DangerButton", _box(Palette.with_alpha(Palette.HP_DANGER, 0.4), Palette.HP_DANGER, 2, 8, 10, 5))
	theme.set_color("font_color", "DangerButton", Palette.HP_DANGER)
	theme.set_color("font_hover_color", "DangerButton", Palette.TX_ON_DARK)
	theme.set_font_size("font_size", "DangerButton", 13)

	# 필터 칩 (도감 탭 등)
	theme.set_type_variation("ChipButton", "Button")
	theme.set_stylebox("normal", "ChipButton", _box(Palette.BG_INSET, Palette.LINE_SUBTLE, 1, 999, 10, 4))
	theme.set_stylebox("hover", "ChipButton", _box(Palette.BG_PANEL_HI, Palette.LINE_STRONG, 1, 999, 10, 4))
	theme.set_stylebox("pressed", "ChipButton", _box(Palette.with_alpha(Palette.MANA_INK, 0.3), Palette.MANA_INK, 1, 999, 10, 4))
	theme.set_color("font_color", "ChipButton", Palette.TX_SECONDARY)
	theme.set_color("font_hover_color", "ChipButton", Palette.TX_PRIMARY)
	theme.set_font_size("font_size", "ChipButton", 12)

	# 등급 카드 변형
	var rarity_map := {
		"Common": "common",
		"Rare": "rare",
		"SuperRare": "super_rare",
	}
	for rarity_key in rarity_map.keys():
		var key: String = "Rarity" + str(rarity_key)
		var col: Color = Palette.rarity_color(str(rarity_map[rarity_key]))
		theme.set_type_variation(key, "PanelContainer")
		theme.set_stylebox("panel", key, _box(Palette.BG_PANEL, col, 2, 8, 12, 10))
