extends Control
class_name IntroOverlay

signal finished

const FRAME_DURATION := 0.48
const FRAME_PATHS := [
	"res://assets/intro/ref_brush_1_bieup.png",
	"res://assets/intro/ref_brush_2_bieup_ueo.png",
	"res://assets/intro/ref_brush_3_bul_written.png",
	"res://assets/intro/ref_brush_4_fire.png",
	"res://assets/intro/ref_hangul_jamo_start.png",
	"res://assets/intro/ref_hangul_jamo_geom.png",
	"res://assets/intro/ref_hangul_jamo_end.png",
	"res://assets/intro/ref_tower_bul_start.png",
	"res://assets/intro/ref_tower_bul_end.png",
	"res://assets/intro/ref_tower_beol_end.png",
	"res://assets/intro/ref_tower_bal_end.png",
	]

@onready var frame_view: TextureRect = $Frame
@onready var frame_label: Label = $FrameLabel
@onready var skip_button: Button = $SkipButton

var frame_index := 0
var frame_elapsed := 0.0
var _finished := false

static func frame_count() -> int:
	return FRAME_PATHS.size()

static func frame_index_for(elapsed: float) -> int:
	if elapsed <= 0.0:
		return 0
	return mini(int(elapsed / FRAME_DURATION), FRAME_PATHS.size() - 1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	skip_button.pressed.connect(skip)
	_show_frame(0)

func _process(delta: float) -> void:
	frame_elapsed += delta
	var next_index := frame_index_for(frame_elapsed)
	if next_index != frame_index:
		_show_frame(next_index)
	if frame_elapsed >= FRAME_DURATION * FRAME_PATHS.size():
		finish()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]:
			skip()
			get_viewport().set_input_as_handled()

func _show_frame(index: int) -> void:
	frame_index = clampi(index, 0, FRAME_PATHS.size() - 1)
	var path: String = FRAME_PATHS[frame_index]
	if ResourceLoader.exists(path):
		frame_view.texture = load(path)
	frame_label.text = "%02d / %02d" % [frame_index + 1, FRAME_PATHS.size()]

func skip() -> void:
	finish()

func finish() -> void:
	if _finished:
		return
	_finished = true
	finished.emit()
	queue_free()
