# TowerInfoModal.gd
# 필드 상의 타워 클릭 시 팝업되는 타워 상세 스펙 및 특수 효과 인스펙터 모달
class_name TowerInfoModal
extends Control

const Palette = preload("res://scripts/ui/Palette.gd")
const NumText = preload("res://scripts/ui/NumText.gd")
## 특성 이름·색의 단일 출처. 타워 배지와 같은 표를 쓴다.
const TraitStyle = preload("res://scripts/tower/TraitStyle.gd")
## 유물 아이콘의 **유일한 출처**. 여기에 아이콘 경로를 손으로 다시 적으면 상점과
## 반드시 갈라진다 — 이 프로젝트가 "채널이 하나면 작성자도 하나" 로 반복해 당한 실수다.
const ShopModal = preload("res://scripts/ui/ShopModal.gd")
## 조준 아이콘의 **유일한 출처**. 이름·설명은 WordTower.gd 에 있으므로 여기서 다시
## 적지 않는다 — 이 파일은 `id → 아이콘·색` 만 담는다.
const TargetingStyle = preload("res://scripts/tower/TargetingStyle.gd")
## 특성 배지 아이콘의 **유일한 출처**. 예전에는 이 파일 안에 `TraitIconControl` 로
## 들어 있었는데, 상점 유물 카드도 같은 배지가 필요해지면서 사본이 될 뻔했다 —
## `TraitStyle` 이 "같은 정보가 세 곳에 흩어져 어긋났다" 를 고치려고 만들어진 파일이므로
## 아이콘 위젯을 네 번째 사본으로 늘리지 않는다(2026-10-05).
const TraitIcon = preload("res://scripts/ui/TraitIcon.gd")

## 유물 칩의 글자색. `결:`(단어 모양) 칩의 청록(`#8de1c8`)과 갈라 놓는다 —
## 색이 같으면 아이콘을 붙여도 "산 것" 과 "원래 그런 것" 을 구분할 수 없다.
const RELIC_COLOR := "#f5c451"

## 이름 → 유물 항목(상점 표의 원본 딕셔너리). 이름은 앞 이모지를 뗀 한글만 남긴다.
static var _relic_by_name: Dictionary = {}

static func _relic_catalog() -> Dictionary:
	if _relic_by_name.is_empty():
		for r in ShopModal.ALL_RELIC_POOL:
			var core := _relic_core_name(str(r.get("name", "")))
			if core != "":
				_relic_by_name[core] = r
	return _relic_by_name

## `"⏱️ 신속의 나침반"` → `"신속의 나침반"`. 라벨은 이모지 없이 만들어지므로
## ("신속의 나침반 (+20% 속도)") 이 정규화가 없으면 절반의 유물이 안 잡힌다.
static func _relic_core_name(raw_name: String) -> String:
	var i := 0
	while i < raw_name.length() and not _is_hangul(raw_name.unicode_at(i)):
		i += 1
	return raw_name.substr(i).strip_edges()

static func _is_hangul(cp: int) -> bool:
	return cp >= 0xAC00 and cp <= 0xD7A3

## 조준 아이콘 — 특성 배지(`TraitIcon`)와 **같은 방식으로 직접 그린다**.
## `mode` 를 들고 있으므로 `전환` 을 누르면 아이콘도 같이 바뀐다. 아이콘이 글자와
## 다른 모드를 가리키면 그 순간 화면이 거짓말을 한다.
class TargetingIconControl extends Control:
	var mode: String = "first"

	func _init(p_mode: String) -> void:
		mode = p_mode
		# 16px — 특성 배지(14px)보다 조금 크다. 이 아이콘은 🎯 이모지 캡션 **옆**에 놓여서,
		# 14px 로 두면 캡션 잉크(≈15px)보다 작아 위계가 어긋난다(스크린샷 실측).
		custom_minimum_size = Vector2(16, 16)
		size = Vector2(16, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_mode(p_mode: String) -> void:
		if mode == p_mode:
			return
		mode = p_mode
		queue_redraw()

	func _draw() -> void:
		TargetingStyle.draw_icon(self, size * 0.5, size.x * 0.45, mode, TargetingStyle.color_for(mode))

@onready var icon_rect: TextureRect = $Panel/VBox/Header/IconContainer/IconRect
@onready var title_label: Label = $Panel/VBox/Header/VBoxTitle/TitleLabel
@onready var tier_label: Label = $Panel/VBox/Header/VBoxTitle/TierLabel
@onready var stats_label: Label = $Panel/VBox/StatsContainer/StatsLabel
@onready var desc_label: RichTextLabel = $Panel/VBox/DescContainer/DescLabel
@onready var synergy_row: HFlowContainer = $Panel/VBox/SynergyRow
@onready var btn_close: Button = $Panel/VBox/BtnClose
@onready var dim_rect: ColorRect = $Dim

func _ready() -> void:
	if btn_close:
		btn_close.pressed.connect(func(): queue_free())
	if dim_rect:
		dim_rect.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed:
				queue_free()
		)
	SoundEngine.play_tile_click()

func setup(data: Dictionary, word_str: String, p_range: float, p_interval: float, synergies: Array = [], p_damage: float = -1.0, p_hint: String = "", p_crit: float = -1.0, p_share: Dictionary = {}, p_tower: WordTower = null) -> void:
	var word_len = word_str.length()
	var tier_name = "◆ 1글자 기본 타워"
	if word_len == 2: tier_name = "◆◆ 2글자 상위 타워"
	elif word_len >= 3: tier_name = "◆◆◆ 3글자 신화 타워"

	title_label.text = "%s 타워" % word_str
	tier_label.text = "%s (%s)" % [tier_name, data.get("name", "")]

	var rarity_id := "common"
	if word_len >= 3: rarity_id = "super_rare"
	elif word_len == 2: rarity_id = "rare"
	var accent: Color = Palette.rarity_color(rarity_id)
	title_label.add_theme_color_override("font_color", accent)
	tier_label.add_theme_color_override("font_color", Palette.TX_SECONDARY)

	if ResourceLoader.exists(data.get("icon", "")) and icon_rect:
		icon_rect.texture = load(data["icon"])

	# Stats
	var dmg: float = p_damage if p_damage > 0.0 else float(WordTower.preview_stats(word_str, data)["per_hit"])
	var preview_info := WordTower.preview_stats(word_str, data)
	var volley: int = int(preview_info.get("volley", 1))
	var total_hit_dmg := dmg * float(volley)
	var dps: float = total_hit_dmg / p_interval if p_interval > 0.0 else total_hit_dmg

	var dmg_text := "공격 %.1f" % dmg
	if volley > 1:
		dmg_text = "공격 %.1f × %d연발 (1회 %.1f)" % [dmg, volley, total_hit_dmg]
	var crit_line := ""
	if p_crit > 0.0:
		crit_line = "   치명타 %.0f%%" % (p_crit * 100.0)

	stats_label.text = "%s (DPS %.1f)   사거리 %dpx   간격 %.2f초%s%s" % [
		dmg_text, dps, int(p_range), p_interval, crit_line, _share_line(p_share)
	]

	# Description
	var raw_desc: String = data.get("desc", "기본 활자 탄환을 발사합니다.")
	raw_desc = raw_desc.replace(r"\[2글자 상위 타워\]", "").replace(r"\[3글자 신화 타워\]", "")
	raw_desc = raw_desc.replace("[2글자 상위 타워]", "").replace("[3글자 신화 타워]", "").strip_edges()
	if p_hint != "":
		raw_desc += "\n\n%s" % p_hint
	var cur_trait := _trait_id_from_synergies(synergies)
	desc_label.text = TraitStyle.enrich_text_with_hints(raw_desc, cur_trait)

	# Synergy Badges UI
	_render_synergy_badges(synergies)

	# 조준 우선순위 — 툴팁은 '무엇으로 바꿀 수 있는지' 를 말하지만, 정보창은
	# '지금 무엇을 노리는지' 를 설명과 함께 보여 주고 여기서 바로 바꿀 수 있어야 한다.
	_build_targeting_row(p_tower)

## 조준 우선순위 행. 툴팁이 이름만 알려 주는 것과 달리, 여기서는 **설명** 까지 보여 준다.
## 왼쪽의 아이콘은 `TargetingStyle` 이 그린다 — 유물 칩과 같은 이유로, 네 모드를
## 문장을 읽지 않고도 구별할 수 있어야 한다.
##
## 선회 타워에는 조준이 없으므로(오브가 스스로 때린다) 행 자체를 만들지 않는다 —
## 눌러도 아무 일이 없는 버튼을 두면 거짓말이 된다.
func _build_targeting_row(tower: WordTower) -> void:
	if tower == null or tower.trait_id == "orbit":
		return
	var vbox := $Panel/VBox as VBoxContainer
	if vbox == null:
		return

	var row := HBoxContainer.new()
	row.name = "TargetingRow"
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)
	# BtnClose 바로 위에 놓는다 — 닫기 버튼 아래로 밀리면 찾기 어렵다.
	vbox.move_child(row, vbox.get_child_count() - 2)

	var caption := Label.new()
	caption.text = "조준"
	caption.add_theme_font_size_override("font_size", 13)
	row.add_child(caption)

	# 아이콘은 **이름 앞**에 둔다 — 조준 모드가 바뀌면 이 아이콘이 먼저 바뀐다.
	var icon := TargetingIconControl.new(tower.targeting_mode)
	icon.name = "TargetingIcon"
	# 세로로 **위**에 붙인다 — 설명이 두 줄로 접히면 행이 높아지는데, 가운데 정렬이면
	# 아이콘이 두 줄 **사이**에 떠서 한 줄짜리 캡션(🎯 조준)과 어긋난다(스크린샷 실측).
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)

	var text := Label.new()
	text.name = "TargetingText"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 12)
	row.add_child(text)

	var btn := Button.new()
	btn.text = "전환"
	btn.pressed.connect(func():
		tower.cycle_targeting_mode()
		_refresh_targeting_row(text, icon, tower)
	)
	row.add_child(btn)

	_refresh_targeting_row(text, icon, tower)


## 아이콘과 글자를 **같은 호출에서** 갱신한다 — 따로 갱신하면 한쪽만 바뀌어 화면이
## 서로 다른 모드를 말하게 된다(그게 곧 거짓말이다).
func _refresh_targeting_row(text: Label, icon: TargetingIconControl, tower: WordTower) -> void:
	icon.set_mode(tower.targeting_mode)
	text.text = "%s — %s" % [tower.targeting_label(), tower.targeting_desc()]


func _share_line(share: Dictionary) -> String:
	if share.is_empty():
		return ""
	var dealt := float(share.get("damage", 0.0))
	var total := float(share.get("total", 0.0))
	if dealt <= 0.0:
		return "\n누적 피해 없음"
	if total <= 0.0:
		return "\n누적 피해 %s" % NumText.comma(dealt)
	var line := "\n누적 피해 %s (전체의 %.0f%%)" % [NumText.comma(dealt), dealt / total * 100.0]
	if int(share.get("count", 0)) > 1:
		line += "  ·  %d위" % int(share.get("rank", 1))
	return line

## 시너지 목록을 정갈한 배지 컨트롤들로 생성하여 SynergyRow 에 배치
##
## ⚠️ §2.38 (2026-10-06) — 예전에는 **같은 목록을 두 표면에** 그렸다: 배지(`SynergyRow`)와
##    BBCode 텍스트(`SynergyLabel`)다. 그런데 씬에서 `SynergyLabel.visible = false` 였고
##    `visible = true` 대입이 `godot/` 전체에 **0건**이라 텍스트 표면은 **영영 안 보였다.**
##    그런데도 매번 문구를 만들었고(실측 149자), **테스트가 그 내용을 단언**했다
##    (`tests/test_tower_traits.gd`) — *"테스트가 초록이니 이 코드는 살아 있다"* 로 읽히지만
##    실제로는 **아무도 안 보는 것을 지키는 초록**이었고, 정당한 정리를 회귀로 보이게 했다.
##    그래서 텍스트 표면과 그 글리프 표를 **지웠다.** 표시 문구는 **0자 변경**이다 —
##    배지가 같은 정보를 나르고 있었다(같은 것끼리 맞댄 실측).
##    ⚠️ 켜는 쪽(대안 B)을 고르지 않은 이유: 배지와 **중복**되고, 그 표면은 이모지로
##       그려져 벡터 배지 바로 아래에 **OS 폴백 이모지 목록**이 겹친다(§2.30-4 의 불일치).
func _render_synergy_badges(synergies: Array) -> void:
	if synergy_row == null:
		return
	for c in synergy_row.get_children():
		c.queue_free()

	var count := 0

	for synergy in synergies:
		var label := str(synergy)
		# ⚠️ 길이 상한을 **없앴다**(2026-10-05). 예전에는 `label.length() > 22` 면 여기서
		# `continue` 해서 그 유물의 효과가 정보창에서 **통째로 사라졌다** — 23자 라벨 3종
		# (`폭발의 뇌관` · `연쇄의 베틀` · `관통 송곳`)이 그래서 안 보였다. 칩 행을
		# `HFlowContainer` 로 바꿔 넘치면 **접히게** 했으므로 버릴 이유가 없다.
		# 조용히 버리는 것보다 두 줄이 되는 게 낫다 — 버려진 라벨은 아무도 못 본다.
		if label.begins_with("형태: ") or label.begins_with("뜻: "):
			continue

		if label.begins_with("특성: "):
			var trait_name := label.trim_prefix("특성: ")
			var trait_id := _trait_id_from_name(trait_name)
			var badge := _make_trait_badge(trait_id, trait_name)
			synergy_row.add_child(badge)
			count += 1
		else:
			var badge := _make_synergy_badge(label)
			synergy_row.add_child(badge)
			count += 1

	synergy_row.visible = count > 0

func _make_trait_badge(trait_id: String, trait_name: String) -> Control:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	var col := TraitStyle.color_for(trait_id)
	badge.tooltip_text = MonsterRoster.trait_full_desc(trait_id)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.14, 0.95)
	sb.border_color = col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 7.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	badge.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 4)
	badge.add_child(hbox)

	var icon_ctrl := TraitIcon.new(trait_id, col)
	hbox.add_child(icon_ctrl)

	var lbl := Label.new()
	lbl.text = trait_name
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", col)
	hbox.add_child(lbl)

	return badge

func _make_synergy_badge(label: String) -> Control:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := _synergy_style(label)
	var col := Color(style.color)
	# 유물 칩은 **상점 설명을 그대로** 툴팁에 단다 — 칩에는 요약("+20% 피해")만 들어가고,
	# 그 유물이 정확히 무엇을 하는지는 산 사람이 읽은 그 문장이 계약이다.
	var tip := str(style.get("tooltip", ""))
	if tip != "":
		badge.tooltip_text = tip

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.10, 0.85)
	sb.border_color = Color(col.r, col.g, col.b, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	badge.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 3)
	badge.add_child(hbox)

	var icon_str := str(style.icon)
	var tex_path := str(style.get("texture", ""))
	if tex_path != "" and ResourceLoader.exists(tex_path):
		# 상점 카드와 **같은 PNG**. 크기만 칩에 맞춰 14px 로 줄인다(특성 배지 아이콘과 같다).
		var tex_rect := TextureRect.new()
		tex_rect.texture = load(tex_path)
		tex_rect.custom_minimum_size = Vector2(14, 14)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(tex_rect)
	elif icon_str != "":
		var icon_lbl := Label.new()
		icon_lbl.text = icon_str
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_lbl.add_theme_font_size_override("font_size", 11)
		hbox.add_child(icon_lbl)

	var lbl := Label.new()
	lbl.text = label
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", col)
	hbox.add_child(lbl)

	return badge

## 라벨 하나를 칩 스타일로 바꾼다. 키는 `icon`(글리프) · `texture`(유물 PNG) ·
## `display` · `color` · `tooltip`.
##
## ⚠️ **전체 문자열이 아니라 접두어로 찾는다.** 라벨은 괄호로 수치를 덧붙이기 때문이다
## ("활자의 정수 (+20% 피해)"). 전체 일치로 찾던 동안에는 수치가 붙은 유물이 **전부**
## 기본값(아이콘 없음·흰 글씨)으로 떨어졌다 — 위에 남아 있던 옛 주석이 그 사실을
## "아이콘을 주려면 접두어로 찾도록 고쳐야 한다" 고 이미 적어 두고 있었다(2026-10-05 이행).
func _synergy_style(label: String) -> Dictionary:
	# `결: ` 는 **단어 자체의 모양**에서 온 효과다(유물이 아니다). 색이 유물과 같으면
	# 플레이어는 이것이 산 것인지 원래 그런 것인지 구분할 수 없다 — 그래서 먼저 잡는다.
	if label.begins_with("결: "):
		return {"icon": "◈", "display": label, "color": "#8de1c8"}
	# 유물 — 아이콘은 **상점과 같은 PNG** 다. 예전에는 이름을 손으로 적은 표에서 이모지
	# 글리프를 골랐고, 그래서 같은 유물이 상점과 정보창에서 다른 그림으로 보였다.
	var relic := _match_relic(label)
	if not relic.is_empty():
		return {
			"icon": "", "texture": str(relic.get("icon", "")), "display": label,
			"color": RELIC_COLOR, "tooltip": str(relic.get("desc", "")),
		}
	# 유물이 아닌 것 중 글리프가 있는 것 = **타워 인접 시너지**(원소 공명·전술 연계·
	# 수호의 순환). 상점 아이콘이 없는 규칙이므로 글리프가 맞다.
	var styles := {
		"원소 공명": ["◇", "#ffcc80"], "전술 연계": ["◆", "#90caf9"],
		"수호의 순환": ["□", "#9fa8da"],
	}
	var style: Array = styles.get(label, ["", "#ffffff"])
	return {"icon": str(style[0]), "display": label, "color": str(style[1])}

## 라벨이 어떤 유물에서 왔는지 접두어로 찾는다. 못 찾으면 빈 딕셔너리.
## 상점 표의 이름 중 서로가 서로의 접두어인 경우가 없어 순서는 결과를 바꾸지 않는다.
func _match_relic(label: String) -> Dictionary:
	var catalog := _relic_catalog()
	for core in catalog:
		if label.begins_with(core):
			return catalog[core]
	return {}

func _trait_id_from_name(trait_name: String) -> String:
	for id in TraitStyle.NAMES:
		if str(TraitStyle.NAMES[id]) == trait_name:
			return str(id)
	return trait_name

func _trait_id_from_synergies(synergies: Array) -> String:
	for s in synergies:
		var str_s := str(s)
		if str_s.begins_with("특성: "):
			return _trait_id_from_name(str_s.trim_prefix("특성: "))
	return ""
