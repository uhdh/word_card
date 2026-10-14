# NextWaveIcons.gd
# 상단 예고 바(`TelegraphBar`)의 **그림 채널** — 다음 웨이브에 오는 몬스터를 아이콘으로 세운다.
#
# 왜 필요한가: 예고는 문장 하나뿐이었다(`다음 1막 3R: 낱자 슬라임·그늘 박쥐·…`).
# 이름 다섯을 끝까지 읽어야 '무엇이 오는가' 가 보이고, **몇 마리 오는지는 어디에도 없었다** —
# 그런데 그 수는 `enemy_count_for()` 가 이미 정확히 계산하고 있다(1막 3R = 6+1 = 7마리 →
# 슬라임2·박쥐2·멧돼지1·고블린1·덩굴1). 로직은 있는데 표현이 없던 사건이다.
#
# ⚠️ **문장을 지우지 않는다.** 상성 절(`중갑→관통·유성`)은 문장에만 있고, 그 문장의 소유자는
#    여전히 `TowerDefenseMain._update_next_round_preview()` 하나다. 이 파일은 **텍스트를
#    한 글자도 만지지 않는다** — 같은 일을 두 곳에서 하면 한쪽이 조용히 다른 쪽을 지운다(§2.13-1).
#
# ⚠️ **동결 파일(`TowerDefenseMain.gd`·`DefenseField.gd`)을 한 줄도 안 고친다.**
#    대가로 '다음 라운드가 몇 막 몇 R 인가' 를 판정하는 3줄이 두 곳에 생긴다
#    (`_next_round()` 와 `next_round_preview()`). 그 드리프트는 눈으로 못 잡으므로
#    `tools/NextWaveIconProbe` 가 **실제 `spawn_queue` 와 맞대서** 잡는다 —
#    아이콘이 약속한 구성과 실제로 스폰되는 구성이 다르면 그 프로브가 빨개진다.
extends HBoxContainer

const MonsterRoster = preload("res://scripts/tower/MonsterRoster.gd")

## 아이콘 한 칸의 크기. 바의 최소 높이가 34px 이고 `TelegraphPanel` 의 상하 여백이
## 3px 씩이라 콘텐츠 높이는 28px 다 — 24px 이면 4px 여유가 남아 바가 **자라지 않는다**
## (실측: 20px·24px 둘 다 바 높이 34.0 불변 · `NextWaveIconProbe` S5).
## 24px 인 이유는 **원본이 32px 스프라이트**라서다 — 20px 로 줄이면 박쥐 날개·멧돼지 엄니
## 같은 실루엣이 뭉개져 다섯 종류가 색 점으로만 남는다(스크린샷 대조).
const ICON_PX := 24
const COUNT_FONT_PX := 12
const ENTRY_SEPARATION_PX := 2

## 마릿수 글자색. 아이콘 위에 얹히지 않고 **옆에** 서므로 배경은 바와 같다.
const COUNT_COLOR := Color("#cbd6ea")
const COUNT_SHADOW := Color(0, 0, 0, 0.8)

## 이 노드가 읽을 `DefenseField`. 씬에서 명시적으로 지정한다(경로가 바뀌면 씬이 알려 준다).
@export var defense_field_path: NodePath = ^"../../../FieldContainer/DefenseField"

var _defense_field: Node = null


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_defense_field = get_node_or_null(defense_field_path)
	if _defense_field == null:
		push_warning("NextWaveIcons: DefenseField 를 찾지 못했다 — %s" % str(defense_field_path))
		return
	# 예고 문장과 **같은 순간**에 다시 그린다 — 신호를 따로 만들면 두 채널의 시점이 갈라진다.
	if _defense_field.has_signal("wave_status_changed"):
		_defense_field.wave_status_changed.connect(_on_wave_status_changed)
	_rebuild()
	# 자식의 `_ready()` 는 부모보다 **먼저** 돈다. 그래서 이 시점의 `current_wave` 는 아직
	# 런 시작 전 값일 수 있다(웨이브 1 은 부모의 `_ready()` 가 시작한다). 한 프레임 뒤에
	# 한 번 더 그려 실제 상태와 맞춘다.
	call_deferred("_rebuild")


func _on_wave_status_changed(_act: int, _max_act: int, _wave: int, _max_wave: int, _is_running: bool) -> void:
	_rebuild()


## 지금 아이콘이 가리키는 라운드. `(act, wave)`.
##
## ⚠️ `DefenseField.next_round_preview()` 와 **같은 규칙**이어야 한다. 저 함수는 문자열을
##    돌려주므로 구성만 따로 받을 수 없다 — 그래서 여기 3줄이 복제된다(위 헤더의 경고).
func _next_round() -> Vector2i:
	var act: int = int(_defense_field.next_round_act())
	var wave: int = int(_defense_field.current_wave) + 1
	if act != int(_defense_field.current_act):
		wave = 1
	return Vector2i(act, mini(wave, int(_defense_field.MAX_WAVES_PER_ACT)))


## 다음 라운드에 **실제로 오는** 몬스터를 종류별로 묶어 돌려준다.
##
## `_build_wave_monsters()` 와 같은 규칙이다 — `i % roster.size()` 로 명단을 돌리고
## (그래서 등장 순서 = 명단 순서), 보스 라운드면 맨 앞에 보스가 한 마리 더 붙는다.
## 마릿수는 `enemy_count_for()` 하나에서 온다(여기서 세지 않는다).
##
## 반환: `[{icon, count, name, type, attrs}, …]`
func composition_for(act: int, wave: int) -> Array:
	var roster: Array = MonsterRoster.entries_for(act)
	if roster.is_empty():
		return []
	var out: Array = []
	if wave % int(_defense_field.BOSS_ROUND_INTERVAL) == 0:
		out.append({
			"icon": MonsterRoster.icon_path(str(MonsterRoster.BOSS_ICONS.get(act, MonsterRoster.BOSS_ICONS[1]))),
			"count": 1,
			"name": str(MonsterRoster.BOSS_TITLES.get(act, "")),
			"type": "boss",
			"attrs": [],
		})
	var count: int = int(_defense_field.enemy_count_for(act, wave))
	var tally: Dictionary = {}
	var order: Array = []
	for i in range(count):
		var idx := i % roster.size()
		if not tally.has(idx):
			tally[idx] = 0
			order.append(idx)
		tally[idx] += 1
	for idx in order:
		var entry: Dictionary = roster[idx]
		out.append({
			"icon": MonsterRoster.icon_path(str(entry["icon"])),
			"count": int(tally[idx]),
			"name": str(entry["name"]),
			"type": str(entry["type"]),
			"attrs": entry.get("attrs", []),
		})
	return out


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if _defense_field == null:
		return
	var round := _next_round()
	for entry in composition_for(round.x, round.y):
		add_child(_build_entry(entry))


## 아이콘 한 칸 = 스프라이트 + (2마리 이상일 때만) 마릿수.
##
## ⚠️ 마릿수를 **항상** 적지 않는다 — 1막 3R 은 다섯 종류 중 넷이 1마리라 `×1` 넷은
##    정보가 아니라 소음이다. 여러 마리 오는 종류만 숫자를 달면 '무엇이 물량인가' 가 바로 보인다.
func _build_entry(entry: Dictionary) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", ENTRY_SEPARATION_PX)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.tooltip_text = _tooltip_for(entry)

	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ⚠️ `load()` 는 여기서 부른다 — `_draw()` 안에서 처음 부르면 GPU RID 가 준비되기 전이라
	#    **흰 사각형으로 굳는다**(§2.25). 이 노드는 `_draw()` 를 아예 안 쓴다.
	var path := str(entry.get("icon", ""))
	if ResourceLoader.exists(path):
		tex.texture = load(path)
	box.add_child(tex)

	var count := int(entry.get("count", 1))
	if count > 1:
		var label := Label.new()
		label.text = "×%d" % count
		label.add_theme_font_size_override("font_size", COUNT_FONT_PX)
		label.add_theme_color_override("font_color", COUNT_COLOR)
		label.add_theme_color_override("font_shadow_color", COUNT_SHADOW)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
	return box


## 아이콘의 툴팁. **새 문구를 지어내지 않는다** — `MonsterRoster` 의 표에서만 만든다.
##
## 적 머리 위 배지와 달리 여기는 **멈춰 있는 표면**이라 호버가 신뢰할 수 있다
## (§2.19-3 이 움직이는 10px 배지를 두 번 기각한 이유와 같은 기준).
func _tooltip_for(entry: Dictionary) -> String:
	var parts: Array = []
	var type_label := MonsterRoster.type_label(str(entry.get("type", "")))
	if type_label != "":
		parts.append(type_label)
	for attr in entry.get("attrs", []):
		parts.append(MonsterRoster.attr_label(str(attr)))
	var head := str(entry.get("name", ""))
	if not parts.is_empty():
		head = "%s (%s)" % [head, "·".join(parts)]
	var count := int(entry.get("count", 1))
	if count > 1:
		head = "%s ×%d" % [head, count]
	return head
