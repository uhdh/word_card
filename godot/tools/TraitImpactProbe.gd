extends Control
# TraitImpactProbe.gd — 특성별 '타격 모양' 을 한 장에 모아 본다.
#
# 왜 FrameStrip 으로는 부족한가: 실제 전투를 찍으면 몹 6마리 · HP바 · 피해 숫자 ·
# 빈 발판이 겹쳐서 '모양' 이 안 보인다. 정작 확인해야 하는 것은 "폭발과 관통의
# 타격이 서로 다르게 보이는가" 인데, 그 차이가 배경 소음에 묻힌다.
#
# 그래서 여기서는 **실제 코드 경로를 그대로 태운다**:
#   Projectile.setup() → hit_target() → _spawn_impact() → Juice.trait_impact()
# 모양 함수(Juice.blast 등)를 직접 부르지 않는 이유는 '배선됐는가' 를 봐야 하기
# 때문이다 — 함수만 예쁘고 아무도 안 부르면 화면에는 아무 일도 안 일어난다.
#
#   godot --path . res://tools/TraitImpactProbe.tscn
#   (인자: out=경로  cols=5  cell=220  progress=0.075)
#
# 주의: --headless 로는 동작하지 않는다 (frame_post_draw 가 오지 않는다).
# 주의: 이 스크립트 이름도 SaveManager._is_test_run() 에 있어야 실제 세이브를 덮지 않는다.

const EnemyUnitScene = preload("res://scenes/tower/EnemyUnit.tscn")
const ProjectileScene = preload("res://scenes/tower/Projectile.tscn")
const MAP_TEXTURE := "res://assets/map/map_act1_garden_td_1024x352.png"
## 게임에서 DefenseField 가 차지하는 영역과 같은 비율(1024:352 = 2.909).
## 이걸 맞춰야 '실제 화면에서 어떻게 보이는가' 가 된다.
const FIELD_SIZE := Vector2(1280, 440)

## trait = 타워 특성, proj = 투사체 텍스처 키.
## 모양을 약속한 6종을 앞에, 약속하지 않은 3종(연사·지속피해·균형)을 뒤에 둔다.
const CASES: Array = [
	{"trait": "splash", "proj": "fire"},
	{"trait": "control", "proj": "ice"},
	{"trait": "pierce", "proj": "arrow"},
	{"trait": "sniper", "proj": "arrow"},
	{"trait": "chain", "proj": "lightning"},
	{"trait": "bounce", "proj": "bullet"},
	{"trait": "rapid", "proj": "slash"},
	{"trait": "damage_over_time", "proj": "fire"},
	{"trait": "balanced", "proj": "bullet"},
]

var _out := "E:/project/word_card/_traitfx/sheet.png"
var _cols := 5
var _cell := 220.0
## 타격 후 **게임 시간** 몇 초 뒤에 찍을지. 트윈이 0.12~0.16초짜리라 0.05면
## 고리·직선·꺾은선과 기존 섬광이 **둘 다** 보이는 지점이다. 프레임 수가 아니라
## 게임 시간으로 세는 이유: PNG 인코딩이 끼면 프레임당 실제 dt 가 24ms~150ms 로
## 요동쳐서, 프레임 수로 세면 어떤 날은 모양이 다 사라진 뒤를 찍는다.
var _progress := 0.05
## 모든 케이스를 이 특성으로 강제한다. `before` 를 찍을 때 쓴다 —
## 예전에는 11종이 전부 impact() 하나를 썼으므로, force=balanced 로 찍은 화면이
## 곧 '이번 작업 전의 화면' 이다(탄 색만 다르고 모양은 같다).
var _force := ""

var _layer: Node2D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.split("=")[1]
		elif a.begins_with("cols="): _cols = int(a.split("=")[1])
		elif a.begins_with("cell="): _cell = float(a.split("=")[1])
		elif a.begins_with("progress="): _progress = float(a.split("=")[1])
		elif a.begins_with("force="): _force = a.split("=")[1]
	await _run()


func _run() -> void:
	# 창은 1280x720 이지만 필드는 그 비율이 아니다(맵 1024:352). 필드 크기만
	# 차지하게 둔다. 씬의 anchors 가 full-rect 면 _ready 뒤에 size 가 창 크기로
	# 되돌아가 버려서(실측: 모양이 전부 y-140 만큼 밀렸다) 씬 쪽을 top-left 로 뒀다.
	position = Vector2.ZERO
	size = FIELD_SIZE
	_make_background()
	_layer = Node2D.new()
	_layer.name = "FxLayer"
	add_child(_layer)
	await get_tree().process_frame

	var rows := int(ceil(float(CASES.size()) / float(_cols)))
	var origin := Vector2(
		(size.x - _cell * float(_cols)) * 0.5,
		(size.y - _cell * float(rows)) * 0.5)

	# 9개를 **같은 프레임에** 만든다. 그래야 모든 모양이 같은 진행도에 놓여
	# 크기 비교가 성립한다(하나씩 만들면 앞의 것은 다 사라진 뒤다).
	for i in range(CASES.size()):
		var col := i % _cols
		var row := i / _cols
		var pos := origin + Vector2((float(col) + 0.5) * _cell, (float(row) + 0.5) * _cell)
		var case: Dictionary = CASES[i]
		if _force != "":
			case = {"trait": _force, "proj": str(CASES[i]["proj"])}
		_fire_one(case, pos)
		print("PROBE cell %d %s at (%.0f,%.0f)" % [i, str(case["trait"]), pos.x, pos.y])
	print("PROBE fired=%d progress=%.3f layer_children=%d" % [CASES.size(), _progress, _layer.get_child_count()])

	# 트윈은 Engine.time_scale 을 따르지 않는다 — 실측: time_scale=0.1 로 묶어도
	# 첫 프레임 한 번에 0.12초짜리 트윈이 끝나버렸다(자식 18 → 0). 그래서 프레임에
	# 맡기지 않고 **직접 멈춰 세운 뒤** 원하는 진행도만큼만 손으로 돌린다.
	# 이래야 "모양이 절반쯤 자란 순간" 을 매번 같은 지점에서 찍을 수 있다.
	var tweens := get_tree().get_processed_tweens()
	for t in tweens:
		t.pause()
	for t in tweens:
		t.custom_step(_progress)
	print("PROBE stepped tweens=%d progress=%.3f" % [tweens.size(), _progress])
	for n in get_tree().get_nodes_in_group("damage_numbers"):
		n.free()
	await RenderingServer.frame_post_draw

	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(_out)
	if err != OK:
		print("PROBE SAVE FAILED err=%d path=%s" % [err, _out])
	else:
		print("PROBE saved %s (%dx%d) progress=%.3f" % [_out, img.get_width(), img.get_height(), _progress])
	# 남은 연출 노드 수 — 여기서 새면 전투 중에도 샌다는 뜻이다.
	var shapes := 0
	var flashes := 0
	for ch in _layer.get_children():
		if ch is Line2D: shapes += 1
		elif ch is Sprite2D: flashes += 1
	print("PROBE LEFTOVER shapes=%d flashes=%d" % [shapes, flashes])
	get_tree().quit()


func _make_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load(MAP_TEXTURE)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 게임의 Background 와 같은 설정이어야 '실제 화면에서 어떻게 보이는가' 가 된다.
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)


## 한 케이스 = 적 하나 + 투사체 하나. 투사체를 적 위에 놓고 즉시 명중시킨다.
## 이러면 이동 시간에 결과가 좌우되지 않고, 진행 방향이 0이라
## 직선/꺾은선의 기준 방향도 케이스마다 같아진다(비교가 성립한다).
func _fire_one(case: Dictionary, pos: Vector2) -> void:
	var enemy = EnemyUnitScene.instantiate()
	add_child(enemy)
	enemy.global_position = pos
	enemy.init_enemy("probe", 99999.0, 0.0, 0, "")
	var proj = ProjectileScene.instantiate()
	_layer.add_child(proj)
	proj.global_position = pos
	proj.setup(enemy, 1.0, str(case["proj"]), str(case["trait"]), null)
	proj.hit_target()
	# 적은 즉시 치운다. 남겨 두면 HP바(가로 초록 막대)가 관통/저격의 '직선' 과
	# 똑같이 생겨서, 정작 확인해야 할 모양을 가린다. 연출 노드는 이미
	# _layer 에 붙었으므로 적을 지워도 살아남는다(그래서 부모를 _layer 로 잡았다).
	enemy.free()
