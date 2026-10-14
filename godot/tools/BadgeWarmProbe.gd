# BadgeWarmProbe.gd
# **수정안 검증**: 그리기 전에 텍스처를 미리 로드해 두면 흰 사각형이 사라지는가?
#
# 배경 (BadgeLazyProbe 실측):
#   · `_draw()` 안에서 처음 `load()` 한 텍스처 → **순백 (1,1,1,1)**
#   · `_ready()` 에서 미리 `load()` 한 텍스처   → 정상
#   · `null` 텍스처 → 아무것도 안 그림 (흰색 아님)
#   · `queue_redraw()` 로 다시 그려도 순백 그대로 → **영구적**
#   게다가 BadgeRealPathProbe 에서 타워를 그린 **뒤에** `load()` 해도 순백이 유지됐다
#   → 첫 그리기 시점의 상태가 굳는다.
#
# 그래서 가설은: **타워가 처음 그려지기 전에** 배지 텍스처를 로드해 두면 고쳐진다.
# 이 프로브는 실제 게임 경로(TowerDefenseMain + DefenseField)에서 그것을 잰다.
#   W1 — 워밍업 **없이** 타워를 세운다  (대조군, 흰 사각형이 나와야 한다)
#   W2 — 워밍업 **뒤** 타워를 세운다    (실험군)
# 두 씬을 각각 새로 띄워 서로 오염시키지 않는다.
#
# 보고 전용. 판정하지 않는다.
extends Node

const OUT_PATH := "E:/project/word_card/tmp/badgewarm_out.txt"
const TRAITS := ["balanced", "sniper", "damage_over_time", "splash", "rapid", "pierce",
	"control", "chain", "bounce", "orbit", "meteor"]
var _lines: PackedStringArray = []
var _words := ["냉기", "빙마", "섬광"]

func _emit(s: String) -> void:
	_lines.append(s)
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines) + "\n")
		f.flush()
		f = null

func _watchdog() -> void:
	for i in 1200:
		await get_tree().process_frame
	_emit("WATCHDOG")
	get_tree().quit(2)

## ⚠️ 워밍업은 **참조를 붙잡아야** 의미가 있다.
## W2(1차) 실측: `load(p)` 만 하고 반환값을 버리면 리소스가 해제되어 아무 효과가 없었다(3/3 순백).
## ResourceLoader 캐시는 약참조라, 아무도 안 잡고 있으면 다음 `load()` 가 다시 로드한다.
var _held: Array = []

## 배지 11종 + 마법진을 미리 로드하고 **참조를 유지**한다. **그리기 전에** 부른다.
func _warm() -> int:
	var n := 0
	for t in TRAITS:
		var p := "res://assets/fx/badge_%s.png" % t
		if ResourceLoader.exists(p):
			_held.append(load(p))
			n += 1
	_held.append(load("res://assets/fx/fx_magic_circle_128px.png"))
	return n

func _scenario(tag: String, warm: bool) -> void:
	var n := _warm() if warm else 0
	_emit("── %s: 워밍업 %s (배지 %d개 + 마법진) ──" % [tag, "함" if warm else "안 함", n])
	var main = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var field = main.find_child("DefenseField", true, false)
	field.set_act(2)
	var parsed: Array = []
	for c in _words:
		parsed.append({"syllable": c, "word_data": WordDatabase.get_word_data(c)})
	field.update_towers_from_parsed_list(parsed)
	for i in 120:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("E:/project/word_card/tmp/badgewarm_%s.png" % tag)
	var whites := 0
	for t in field.active_towers:
		if t == null:
			continue
		var base: Vector2 = t.get_global_transform_with_canvas().origin
		var c: Vector2 = base + Vector2(38.0 * 0.53, -38.0 * 0.53)
		var px: Color = img.get_pixelv(Vector2i(int(c.x), int(c.y)))
		var isw: bool = px.r > 0.99 and px.g > 0.99 and px.b > 0.99
		if isw:
			whites += 1
		_emit("   %s trait=%-18s 배지중심=%s = %s %s" % [str(t.syllable), str(t.trait_id),
			Vector2i(int(c.x), int(c.y)), px, "★순백" if isw else ""])
	_emit("   ⇒ 순백 %d / %d" % [whites, field.active_towers.size()])
	main.queue_free()
	for i in 20:
		await get_tree().process_frame

func _ready() -> void:
	_watchdog()
	_emit("BADGEWARM_START")
	await _scenario("W1_워밍업없음", false)
	await _scenario("W2_워밍업함", true)
	_emit("BADGEWARM_DONE")
	get_tree().quit(0)
