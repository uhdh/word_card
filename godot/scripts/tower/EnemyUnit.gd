# EnemyUnit.gd
# 타워 디펜스 경로(PathFollow2D)를 따라 이동하는 적 유닛
class_name EnemyUnit
extends PathFollow2D

const Palette = preload("res://scripts/ui/Palette.gd")
const Juice = preload("res://scripts/ui/Juice.gd")

signal died(enemy: EnemyUnit)
signal reached_base(enemy: EnemyUnit, damage: int)

## 처치 사망 연출 길이. 이 시간 동안 노드를 살려 둔 뒤 지운다.
const DEATH_DURATION: float = 0.17
## 사망 시 납작해지는 비율(가로로 퍼지고 세로로 눌린다).
const DEATH_SQUASH: Vector2 = Vector2(1.32, 0.62)

## ── 표시 크기 ────────────────────────────────────────────────────────────────
## 적이 타워(76px) 옆에서 절반 크기로 보인다는 지적을 받아 키웠다.
##
## 스프라이트 상자 한 변은 **씬(EnemyUnit.tscn)이 소유**한다 — 에디터에서 눈으로 보이는
## 값이어야 하기 때문이다. 이 파일은 그 값에서 **장식 위치를 파생**시킨다.
##
## 왜 파생시키는가: 체력바·속성 배지·상태 칩은 전부 스프라이트 **바깥**에 있어야 하는데,
## 예전에는 36px 상자를 전제로 한 좌표가 씬과 이 파일에 각각 박혀 있었다. 그래서 상자만
## 키우면 체력바가 몸통에 파묻히고 상태 칩이 발밑에 붙는다 — 크기를 바꾸는 순간 장식이
## 조용히 망가지고, 그 사실은 화면을 봐야만 알 수 있다.
##
## 아래 값들은 "그림 끝에서 얼마나 떨어지는가" 라는 **관계**만 말한다.
## 절대 좌표는 `_apply_visual_layout()` 이 한 곳에서 계산한다.
##
## 틈은 **배율과 무관한 고정 픽셀**이다. 체력바가 머리에서 5px 위에 있으면 그건 적이
## 크든 작든 똑같이 보여야 한다 — 배율을 곱하면 보스에서만 틈이 2배로 벌어진다.
const HP_BAR_HEIGHT := 6.0
## 보이는 그림의 위끝과 체력바 아래끝 사이의 틈.
const HP_BAR_GAP := 5.0
## 배지 줄의 높이. `_setup_badges` 와 배지 하나가 같은 값을 써야 줄이 정확히 맞는다.
const BADGE_ROW_HEIGHT := 15.0
## 체력바 위끝과 배지 줄 아래끝 사이의 틈.
const BADGE_GAP := 3.0
## 보이는 그림의 아래끝과 상태 칩 줄 사이의 틈.
const STATE_GAP := 1.0
## 보스 실루엣 배율. 잡몹과 크기가 비슷하면 "보스가 등장했다" 는 느낌이 안 난다.
##
## 크기를 바꿀 때는 반드시 `set_sprite_scale()` 을 지나야 한다 — `sprite.scale` 을
## 직접 만지면 장식이 커진 몸통 안쪽에 그대로 남는다.
const BOSS_SPRITE_SCALE: float = 1.9

## 텍스처 경로 → 그림의 실제 세로 범위(Vector2(위, 아래), 0..1).
##
## 이 게임 아트는 캔버스를 다 채우지 않는다. 32px 기준으로 **위쪽 4~7px 이 비어 있고**
## (실측: 고블린 4, 정령 5, 슬라임·보스 6~7), 걸음 프레임은 **아래로 1~3px 더 뻗는다**
## (보스 27 → 30). 그래서 캔버스 끝을 기준으로 장식을 붙이면 그림과 장식 사이가 벌어지고,
## 보스처럼 배율이 크면 그 틈도 배율만큼 벌어진다(실측: 보스 체력바가 머리 위 25px 에 떴다).
##
## 주의: idle 아트는 임포트된 512x512 텍스처고 걸음 프레임은 임포트되지 않은 32x32 파일이라
## (`_load_tex` 가 파일에서 직접 읽는다) 픽셀 크기가 서로 다르다. 비율로 재므로 문제없지만,
## 걸음 프레임을 `load()` 로 읽으려 하면 null 이 온다 — 반드시 `_load_tex` 를 지나야 한다.
##
## 텍스처마다 한 번만 재고 재사용한다.
static var _ART_BOUNDS: Dictionary = {}

## ── 속성 상성 표시 임계값 ────────────────────────────────────────────────────
## damage_multiplier_for 의 결과가 이 범위를 벗어날 때만 피해 숫자에 이름이 붙는다.
##   ≥ 1.25 : 약점   (예: 중갑+관통 1.6, 군집+폭발 1.5, 중갑+유성 1.25)
##   ≤ 0.75 : 내성   (예: 중갑+연사 0.65, 재생+지속피해 0.55, 질주+제어 0.5)
## 사이(1.0 근처)는 아무 표시도 하지 않는다 — 매 타격마다 글자가 뜨면 소음이다.
##
## ⚠️ 2026-09-26 까지 여기는 1.35 / 0.72 였고, `MonsterRoster.COUNTER_*`(1.25 / 0.75)와
## **두 벌로 갈려 있었다**(§2.19). 그래서 표 22쌍 중 8쌍이 틈에 걸려 *예고는 "약함" 인데
## 숫자는 흰색* 이었다. 경계를 하나로 맞췄다 — 이 값들은 **표시 전용**이라(`_damage_kind`
## 의 결과는 `_show_damage_number` 로만 간다) **밸런스는 변하지 않는다**.
## ⚠️ 두 파일이 같은 수를 각자 갖는 구조는 그대로다(추출하지 않는다 — §2.16 규칙).
##    대신 `tools/CounterThresholdProbe` 가 **두 값이 같은지**를 잰다.
const WEAK_MULT: float = 1.25
const RESIST_MULT: float = 0.75

## 이 피해량 이상이면 '큰 한 방' 으로 표시한다(`Juice` 의 `big`).
##
## ⚠️ 2026-10-01 이전에는 이 임계가 **'치명타' 라는 이름**을 달고 있었다(§2.21). 그래서
##    한 이름이 두 사건을 가리켰다: 진짜 치명타(굴림)와 그냥 큰 피해(임계). 이제 분리한다 —
##    임계는 `big`, 굴림은 `crit` 이며 **둘 다 화면에 나온다**(§5.2 33 (A)).
const BIG_HIT_THRESHOLD: float = 60.0

## 감속에 걸린 적을 물들이는 색과 세기.
## 제어 타워의 존재 이유가 '적이 느려지는 것' 인데, 예전에는 속도만 조용히 바뀌어서
## 화면에서는 아무 일도 안 일어난 것처럼 보였다(제어 타워의 정체성이 통째로 비가시).
##
## 곱셈(modulate)으로는 초록 적이 파래지지 않는다 — 채널을 깎을 뿐이다.
## 색을 섞는 전용 셰이더(shaders/status_tint.gdshader)를 sprite.material 에 물린다.
const SLOW_TINT: Color = Color(0.45, 0.78, 1.0)
## 상태 색이 사라질 때까지의 기본 세기. 0.55 는 "확실히 다르지만 형태는 남는" 지점.
const SLOW_TINT_STRENGTH: float = 0.55
## '면역' 배지가 화면에 남는 시간(초).
const IMMUNE_BADGE_TIME: float = 0.7
## 화상 칩의 색. 불꽃 주황 — 초원 배경에서도, 어두운 바탕 위에서도 읽힌다.
const BURN_BADGE_COLOR: Color = Color(1.0, 0.62, 0.22)
## 상태 칩 줄의 폭. 스프라이트 **아래**에 둔다.
## 위쪽은 HP 바와 속성 배지가 이미 쓰고 있다.
##
## y 위치는 여기 없다 — 스프라이트 크기에서 파생된다(`_apply_visual_layout`).
const STATE_ROW_WIDTH: float = 84.0
const STATE_CHIP_SIZE: Vector2 = Vector2(30, 13)
## 상태 표시 셰이더. 나중에 화상·중독 같은 상태도 같은 셰이더로 색만 바꿔 쓸 수 있다.
const STATUS_TINT_SHADER = preload("res://shaders/status_tint.gdshader")

@export var max_hp: float = 20.0
var hp: float = 20.0
var shield: float = 0.0
var max_shield: float = 0.0
@export var speed: float = 80.0
@export var gold_reward: int = 5
@export var enemy_name: String = "낱자 슬라임"
## 이 적이 쓴 아트 경로. 분열로 태어난 자식이 부모와 같은 모습을 유지하게 한다.
var icon_path: String = ""
@export var base_damage: int = 1
var enemy_type := "normal"
var weakness_trait := ""
## 이 적의 '속성' (MonsterRoster.ATTR_INFO 의 키, 결계는 "warded:특성").
## 타입(중갑/군집/질풍) 위에 얹혀 '무엇으로 때려야 하는지' 를 한 겹 더 만든다.
var attrs: Array = []
## 초당 재생량. 최대 체력 대비 비율로 정해진다 (MonsterRoster.REGEN_RATIO).
var regen_per_sec: float = 0.0
## 죽을 때 갈라지는 마릿수. 0 이면 분열하지 않는다.
var split_into: int = 0
## 감속 면역 — apply_slow 를 통째로 무시한다.
var slow_immune: bool = false

var slow_factor: float = 1.0
var slow_timer: float = 0.0
var burn_effects: Array[Dictionary] = []
var is_dead: bool = false
## 적 머리 위 배지 줄(타입 + 속성). 붙일 것이 없으면 아예 만들지 않는다.
var _badge_row: Control = null
## '면역' 표시(Label). 감속이 질주에게 거부됐을 때만 잠깐 뜬다.
## 감속이 '걸린' 경우는 셰이더 색으로 보이므로 배지가 필요 없다 —
## 매 타격마다 배지가 붙으면 화면이 글자로 덮인다.
var _slow_badge: Label = null
## 화상(burn) 칩. 지속 피해 타워가 일하고 있다는 유일한 지속 표시다.
##
## 화상은 매 프레임 피해를 넣고 있었지만 화면에는 **합산된 피해 숫자**만 떴다.
## 숫자는 순간이고, 화상은 몇 초간 이어지는 상태다 — "지금도 타고 있다" 를
## 보여 주는 것이 없어서, 지속 피해 타워를 사 둔 플레이어는 그 타워가
## 계속 일하고 있는지 알 수 없었다(제어 타워가 겪었던 것과 같은 비가시성).
var _burn_badge: Label = null
## 상태 칩(면역·화상)을 담는 줄. 스프라이트 **아래**에 붙는다.
##
## 칩마다 위치를 손으로 잡으면 둘이 동시에 뜰 때 겹친다 — 질주하는 적이
## 제어 타워와 지속 피해 타워 사거리에 함께 들어가면 실제로 겹친다.
## 컨테이너에 넣어 두면 몇 개가 뜨든 가운데 정렬로 나란히 선다.
var _state_row: HBoxContainer = null
## 상태 칩 줄을 담는 껍데기. **위치는 이쪽이 들고 있다** — 줄 자신은 PRESET_FULL_RECT
## 라서 position 이 항상 (0,0) 이다. 크기를 바꿀 때 자리를 옮겨야 하는 건 이 껍데기다.
var _state_wrapper: Control = null
## 감속 색을 입히는 셰이더 머티리얼(sprite 에 물린다). 한 번만 만든다.
var _slow_material: ShaderMaterial = null
## '면역' 표시가 남아 있는 시간. 거부될 때마다 계속 뜨면 소음이라 수명을 둔다.
var _slow_badge_timer := 0.0
var _bob_time := 0.0
var _pending_dot_damage := 0.0
var _damage_number_timer := 0.0
var _walk_frames: Array[Texture2D] = []
var _walk_time := 0.0
var _last_x := 0.0
const WALK_FPS := 8.0
## 피격 섬광 트윈. 사망할 때 반드시 kill 해야 한다 — 살아 있으면 매 프레임
## modulate **전체**를 흰색으로 되돌려서 사망 페이드(alpha)를 취소한다.
var _flash_tween: Tween = null

@onready var sprite: TextureRect = $Sprite
@onready var hp_bar: ProgressBar = $HpBar
## 지금 그림이 캔버스 안에서 차지하는 세로 범위(0..1). `_set_art_bounds()` 가 채운다.
## 텍스처가 없으면 캔버스 전체(0..1) — 그때는 상자 끝이 곧 그림 끝이다.
var _art_top_ratio := 0.0
var _art_bottom_ratio := 1.0

func _ready() -> void:
	hp = max_hp
	# 경로 끝 = 기지. loop = true 로 두면 적이 기지에 닿는 순간 처음으로 되돌아가
	# 영원히 돌아다닌다 → 기지 피해가 한 번도 안 들어가고, 죽지도 않아 계속 쌓이다가
	# MAX_ENEMIES(50) 를 넘겨 '즉시 패배' 로 끝난다. 기지 HP 가 사실상 장식이 된다.
	# (실측: 타워 3개로 3막 완주 — 기지 HP 20/20, 잃은 HP 0)
	loop = false
	rotates = false
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	_refresh_hp_bar_color()
	if sprite:
		# 스프라이트 상자·장식 위치를 지금 배율에 맞춰 한 번에 잡는다.
		_apply_visual_layout()


## 이 적의 실루엣 배율. 잡몹은 1.0, 보스는 1.0 보다 크다.
##
## `sprite.scale` 을 직접 대입하지 말고 이 함수를 쓴다 — 장식 위치가 배율에서
## 파생되므로, 배율만 바꾸고 레이아웃을 안 잡으면 체력바와 배지가 커진 몸통
## 안쪽에 남는다(보스만 체력바가 몸에 파묻히는 이유).
func set_sprite_scale(p_scale: float) -> void:
	if sprite == null:
		return
	sprite.scale = Vector2(p_scale, p_scale)
	_apply_visual_layout()


## 지금 크기에 맞춰 스프라이트 상자와 장식(체력바·배지·상태 칩) 위치를 다시 잡는다.
##
## 장식이 **보이는 그림** 바깥에 남도록 하는 계산이 이 한 곳에만 있다. 크기를 키우거나
## 보스 배율을 바꾸면 여기가 유일한 수정 지점이다.
##
## 기준은 상자(캔버스) 끝이 아니라 그림의 실제 위끝·아래끝이다. 아트가 캔버스를 다
## 채우지 않기 때문이다 — 캔버스 끝을 기준으로 잡으면 체력바가 머리 위로 떠오르고,
## 배율이 큰 보스에서 그 틈이 가장 크게 벌어진다.
func _apply_visual_layout() -> void:
	if sprite == null:
		return
	var half: float = sprite.custom_minimum_size.x * 0.5
	# 스프라이트는 중심(pivot) 기준으로 커진다.
	var scale: float = absf(sprite.scale.y)
	sprite.pivot_offset = Vector2(half, half)
	sprite.offset_left = -half
	sprite.offset_top = -half
	sprite.offset_right = half
	sprite.offset_bottom = half
	# 캔버스가 차지하는 범위(중심 기준). 그림은 그 안에서 이 비율만큼만 차지한다.
	var canvas_half: float = half * scale
	var art_top: float = -canvas_half + _art_top_ratio * canvas_half * 2.0
	var art_bottom: float = -canvas_half + _art_bottom_ratio * canvas_half * 2.0
	# 체력바는 그림 위끝에, 배지 줄은 그 체력바 **위에** 쌓는다. 배지를 그림 위끝
	# 기준으로 잡으면 체력바 높이를 바꿀 때마다 두 줄이 조용히 겹치기 시작한다.
	var bar_top: float = art_top - HP_BAR_GAP - HP_BAR_HEIGHT
	if hp_bar:
		hp_bar.offset_left = -half
		hp_bar.offset_right = half
		hp_bar.offset_top = bar_top
		hp_bar.offset_bottom = art_top - HP_BAR_GAP
	if _badge_row:
		_badge_row.position = Vector2(-BADGE_ROW_WIDTH * 0.5, bar_top - BADGE_ROW_HEIGHT - BADGE_GAP)
	if _state_wrapper:
		_state_wrapper.position = Vector2(-STATE_ROW_WIDTH * 0.5, art_bottom + STATE_GAP)


## 이 적이 그리는 **모든** 그림(idle + 걸음 4장)의 세로 범위를 합쳐서 잡는다.
##
## 걸음 프레임은 idle 보다 아래로 더 뻗는다(실측: 골렘 보스 +3px, 슬라임 +2, 고블린 +1,
## 용 +2). idle 만 재면 **정지 화면에서는 멀쩡하고 걸을 때만** 상태 칩이 발을 밟는다 —
## 스크린샷 한 장으로는 안 보이고, 걷는 동안에만 어긋나므로 눈으로 잡기 어렵다.
func _set_art_bounds(idle: Texture2D) -> void:
	var top := 1.0
	var bottom := 0.0
	var measured := false
	var frames: Array = [idle]
	frames.append_array(_walk_frames)
	for tex in frames:
		var r := _measure_art(tex)
		if r.x < 0.0:
			continue
		top = minf(top, r.x)
		bottom = maxf(bottom, r.y)
		measured = true
	_art_top_ratio = top if measured else 0.0
	_art_bottom_ratio = bottom if measured else 1.0


## 텍스처 하나의 세로 범위(위·아래, 0..1). 잴 수 없으면 (-1, -1).
##
## 32x32 라 비용은 무시할 수 있고, 경로별로 한 번만 계산해 둔다.
static func _measure_art(tex: Texture2D) -> Vector2:
	if tex == null:
		return Vector2(-1.0, -1.0)
	var key: String = tex.resource_path
	if key != "" and _ART_BOUNDS.has(key):
		return _ART_BOUNDS[key]
	var result := Vector2(-1.0, -1.0)
	var img: Image = tex.get_image()
	if img != null and img.get_height() > 0:
		var used: Rect2i = img.get_used_rect()
		if used.size.y > 0:
			var h := float(img.get_height())
			result = Vector2(float(used.position.y) / h, float(used.position.y + used.size.y) / h)
	if key != "":
		_ART_BOUNDS[key] = result
	return result

## 주의: 다섯 번째 인자 이름을 p_icon_path 로 둔 것은 icon_path 멤버를 가리지 않기 위해서다.
## (파라미터가 멤버와 같은 이름이면 대입이 자기 자신에게 가서 조용히 무시된다)
func init_enemy(p_name: String, p_hp: float, p_speed: float, p_gold: int, p_icon_path: String, p_shield: float = 0.0) -> void:
	enemy_name = p_name
	max_hp = p_hp
	hp = p_hp
	speed = p_speed
	gold_reward = p_gold
	shield = p_shield
	max_shield = p_shield
	if p_icon_path != "":
		icon_path = p_icon_path
	if sprite != null:
		var idle := _load_tex(icon_path)
		if idle:
			sprite.texture = idle
	# 걸음 프레임을 **먼저** 읽는다 — 그림 범위는 걸음 프레임까지 합쳐서 재야 한다.
	_load_walk_frames()
	if sprite != null:
		# `_ready` 는 아직 텍스처가 없을 때 돌았다(그때는 상자 끝 = 그림 끝으로 계산한다).
		# 실제 그림을 읽은 지금 장식 위치를 다시 잡는다.
		_set_art_bounds(sprite.texture)
		_apply_visual_layout()
	if hp_bar:
		hp_bar.max_value = max_hp + max_shield
		hp_bar.value = hp + shield
	_refresh_hp_bar_color()


func _load_walk_frames() -> void:
	_walk_frames.clear()
	if icon_path == "":
		return
	var stem := icon_path.get_file().replace("_32px_pastel.png", "")
	var dir := icon_path.get_base_dir()
	for i in 4:
		var path := "%s/%s_walk_%d.png" % [dir, stem, i]
		var tex := _load_tex(path)
		if tex:
			_walk_frames.append(tex)


func _load_tex(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex:
			return tex
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(path) == OK:
			return ImageTexture.create_from_image(img)
	return null


func _update_walk(delta: float) -> void:
	if sprite == null:
		return
	var dx := global_position.x - _last_x
	if absf(dx) > 0.04:
		var mag := absf(sprite.scale.y)
		if mag < 0.01:
			mag = 1.0
		sprite.scale.x = (-1.0 if dx < 0.0 else 1.0) * mag
	_last_x = global_position.x
	if _walk_frames.size() < 2:
		return
	_walk_time += delta * WALK_FPS * maxf(slow_factor, 0.25)
	sprite.texture = _walk_frames[int(_walk_time) % _walk_frames.size()]

## 속성(attrs)을 적용한다. MonsterRoster 가 정의한 의미를 여기서 실제 동작으로 바꾼다.
func apply_attrs(p_attrs: Array) -> void:
	attrs = p_attrs.duplicate()
	regen_per_sec = max_hp * MonsterRoster.REGEN_RATIO if attrs.has("regen") else 0.0
	split_into = MonsterRoster.SPLIT_COUNT if attrs.has("splitter") else 0
	slow_immune = attrs.has("swift")
	_setup_badges()


## 배지 줄의 폭. 폭을 고정해야 가운데 정렬이 첫 프레임부터 맞는다 —
## 라벨 폭은 폰트에 따라 달라지므로 '크기를 재고 나서 위치를 정하는' 방식은 어긋난다.
##
## y 위치는 여기 없다 — 스프라이트 크기에서 파생된다(`_apply_visual_layout`).
const BADGE_ROW_WIDTH := 150.0
## 속성 배지의 바탕색. 타입 배지는 색으로 꽉 채우고, 속성 배지는 어두운 바탕에
## 테두리만 색으로 두른다.
##
## 왜 형태를 나누는가: 질풍(타입)과 질주(속성)는 표에서 같은 주황이라, 둘 다 칠하면
## 똑같은 주황 블록 두 개가 나란히 뜬다. 그러면 '타입 상성' 과 '속성 상성' 이라는
## 두 축이 화면에서 하나로 뭉개진다 — 정작 무엇으로 때려야 하는지가 다시 안 보인다.
const BADGE_ATTR_BG := Color(0.05, 0.06, 0.10, 0.88)

## 적 머리 위 배지 줄. 타입(중갑/군집/질풍)과 속성(재생/분열/결계/질주)을 함께 보여준다.
##
## 예전에는 속성 첫 번째 것만 배지로 떴고(루프가 첫 일치에서 return), 정작 그 적을
## 무엇으로 때려야 하는지를 정하는 타입은 아예 안 보였다. 상성표는 코드에 다 있었지만
## 화면에는 없어서, 플레이어는 맞아 본 뒤에야 알 수 있었다.
func _setup_badges() -> void:
	if _badge_row != null:
		return
	var specs := badge_specs()
	if specs.is_empty():
		return
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.custom_minimum_size = Vector2(BADGE_ROW_WIDTH, BADGE_ROW_HEIGHT)
	add_child(wrapper)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	wrapper.add_child(row)
	# add_child 뒤에 preset 을 잡는다 — 순서를 뒤집으면 첫 프레임에 크기가 0 으로 굳는다.
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for spec in specs:
		var trait_key := str(spec[3]) if spec.size() > 3 else ""
		row.add_child(_make_badge(str(spec[0]), spec[1], bool(spec[2]), trait_key))
	_badge_row = wrapper
	# 방금 만든 줄을 현재 크기에 맞춰 자리잡게 한다 — 좌표를 여기서 손으로 잡으면
	# `_apply_visual_layout` 과 두 곳에서 계산하게 되고, 상자를 키울 때 한쪽만 고쳐진다.
	_apply_visual_layout()


## 배지로 띄울 것들. [문구, 색, 타입인가] 목록. 일반 타입이고 속성도 없으면 빈 목록이다.
func badge_specs() -> Array:
	var out: Array = []
	var type_text := MonsterRoster.type_label(enemy_type)
	if type_text != "":
		out.append([type_text, MonsterRoster.type_color(enemy_type), true, enemy_type])
	for attr in attrs:
		var text := str(attr)
		out.append([MonsterRoster.attr_label(text), MonsterRoster.attr_color(text), false, text])
	return out


class MonsterTraitIcon extends Control:
	var trait_key: String = ""
	var icon_color: Color = Color.WHITE

	func _init(p_key: String, p_color: Color) -> void:
		trait_key = p_key
		icon_color = p_color
		custom_minimum_size = Vector2(9, 9)
		size = Vector2(9, 9)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		MonsterRoster.draw_icon(self, size * 0.5, size.x * 0.45, trait_key, icon_color)


## filled = true 면 색으로 꽉 채운 타입 배지, false 면 테두리만 두른 속성 배지.
## trait_key 가 있으면 해당 특성의 벡터 아이콘을 라벨 앞에 그린다.
func _make_badge(label_text: String, bg_color: Color, filled: bool, trait_key: String = "") -> Label:
	var badge := Label.new()
	badge.text = label_text
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_font_size_override("font_size", 10)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(0, BADGE_ROW_HEIGHT)

	var bg := StyleBoxFlat.new()
	bg.set_corner_radius_all(3)
	bg.content_margin_top = 1.0
	bg.content_margin_bottom = 1.0
	if trait_key != "":
		bg.content_margin_left = 15.0
		bg.content_margin_right = 5.0
	else:
		bg.content_margin_left = 5.0
		bg.content_margin_right = 5.0

	var fg_col: Color
	if filled:
		bg.bg_color = bg_color
		fg_col = Color(1, 1, 1)
	else:
		bg.bg_color = BADGE_ATTR_BG
		bg.border_color = bg_color
		bg.set_border_width_all(1)
		fg_col = bg_color.lightened(0.3)

	badge.add_theme_color_override("font_color", fg_col)
	badge.add_theme_stylebox_override("normal", bg)

	if trait_key != "":
		var icon_ctrl := MonsterTraitIcon.new(trait_key, fg_col)
		icon_ctrl.position = Vector2(3, 3)
		badge.add_child(icon_ctrl)

	return badge


## 지금 걸린 속성들을 사람이 읽는 문자열로 (툴팁/디버그용).
func attrs_label() -> String:
	var parts: Array = []
	for attr in attrs:
		parts.append(MonsterRoster.attr_label(str(attr)))
	return ", ".join(parts)


## 현재 체력 비율에 따라 HP 바 채우기 색상을 갱신한다.
## (테마 StyleBox 는 공유 자원이므로 반드시 duplicate() 후 수정)
##
## **방어도가 남아 있는 동안은 바를 방어도 색으로 칠한다.** 이게 거짓말이 되지 않는
## 이유: 방어도가 먼저 전부 먹으므로 `shield > 0` 이면 HP 는 **한 번도 안 깎였다**
## (`hp == max_hp`). 즉 그 순간 HP 심각도 축(초록/노랑/빨강)은 퇴화해 있어, 같은
## 통로를 방어도가 써도 축이 충돌하지 않는다. 방어도가 깨지는 순간 색이 HP 색으로
## 넘어가므로, 플레이어는 '방어도가 벗겨졌다' 를 색 변화로 본다.
##
## 예전에는 1px 테두리(Palette.MANA_INK)뿐이었다 — 36x6 px 바에서 채움은 4px 이라
## 사실상 보이지 않았고, 방어도가 35% 인 적도 그냥 길쭉한 초록 바였다.
##
## 위 불변식(`shield > 0` 이면 `hp == max_hp`)은 테스트가 잠근다. 나중에 방어도 재생
## 같은 것을 넣어 불변식이 깨지면 그 테스트가 먼저 실패한다 — 그때는 색이 아니라
## '방어도 구간' 을 따로 그려야 한다.
func _refresh_hp_bar_color() -> void:
	if hp_bar == null:
		return
	var total: float = max_hp + max_shield
	var ratio: float = 1.0 if total <= 0.0 else clampf((hp + shield) / total, 0.0, 1.0)
	var fill_color: Color = Palette.SHIELD if shield > 0.0 else Palette.hp_color(ratio)
	var sb := hp_bar.get_theme_stylebox("fill")
	if sb is StyleBoxFlat:
		var flat: StyleBoxFlat = sb.duplicate()
		flat.bg_color = fill_color
		# 방어도가 남아 있으면 테두리도 같은 색으로 둘러 '이건 방어도' 임을 한 번 더 말한다.
		flat.border_color = Palette.SHIELD
		flat.set_border_width_all(1 if shield > 0.0 else 0)
		hp_bar.add_theme_stylebox_override("fill", flat)
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = fill_color
		flat.set_corner_radius_all(3)
		hp_bar.add_theme_stylebox_override("fill", flat)

func _process(delta: float) -> void:
	if is_dead:
		return
	# HP 바가 즉시 튀지 않게 따라가게 한다. 여기 한 곳에서만 갱신하므로
	# take_damage / _tick_regen / 화상 어디서 hp 가 바뀌어도 전부 적용된다.
	# (36x6px 라 트레일 바를 겹칠 자리가 없다 — 부드러운 감쇠가 맞다)
	if hp_bar:
		Juice.approach(hp_bar, hp + shield, delta)
	if _damage_number_timer > 0.0:
		_damage_number_timer -= delta
		if _damage_number_timer <= 0.0 and _pending_dot_damage > 0.0:
			_show_damage_number(_pending_dot_damage, Color(1.0, 0.65, 0.25), "dot")
			_pending_dot_damage = 0.0

	# 감속이 풀리면 색을 원래대로 되돌린다.
	# (여기 한 곳에서만 되돌리므로 apply_slow 쪽은 '걸릴 때' 만 신경 쓰면 된다)
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0
			_refresh_slow_tint()
	# '면역' 배지는 자기 수명을 따로 가진다 — 감속 지속시간과 무관하다.
	if _slow_badge_timer > 0.0:
		_slow_badge_timer -= delta
		if _slow_badge_timer <= 0.0:
			_hide_immune_badge()

	_tick_burn(delta)
	if is_dead:
		return
	_tick_regen(delta)
	if is_dead:
		return
	_bob_time += delta
	if sprite and _walk_frames.size() < 2:
		sprite.position.y = sin(_bob_time * 7.0) * 1.5

	# Move along path
	var current_speed = speed * slow_factor
	progress += current_speed * delta
	_update_walk(delta)
	# loop = false 라서 경로 끝에서 progress 가 멈춘다. 도달 판정은 progress_ratio 로 한다.
	if progress_ratio >= 1.0:
		_arrive_at_base()


## 기지 도달. 피해를 주고 사라진다. 처치(died)와 달리 골드는 주지 않는다.
func _arrive_at_base() -> void:
	if is_dead:
		return
	# DefenseField._on_enemy_reached_base 가 get_enemies() 로 수를 세므로,
	# 먼저 is_dead 를 세워 두어야 방금 도착한 개체가 카운트에 남지 않는다.
	is_dead = true
	reached_base.emit(self, base_damage)
	queue_free()

## 피해를 적용한다.
##
## mult 는 '이 타격에 적용된 속성 배율' 이다. 배율 자체는 Projectile/Meteor/TowerOrbit
## 이 damage_multiplier_for() 로 구해 **피해에 미리 곱해서** 넘긴다. 그래서 예전에는
## 1.6배 관통타와 0.65배 연사탄이 똑같이 흰 숫자로 보였고, 상성표는 화면 밖에만 있었다.
## 이제 배율을 함께 받아 숫자에 '약점'/'내성' 을 붙인다.
##
## 기본값 1.0 이라 배율 개념이 없는 호출(화상 틱, 테스트, 도구)은 그대로 동작한다.
## pool_numbers: 화상 틱처럼 초당 수십 번 들어오는 피해를 하나로 묶어 띄울지.
##   예전에는 이 결정이 '소리 끄기(show_hit_sound=false)' 에 묶여 있었다. 그래서
##   소리만 끄려던 선회(orbit) 타워의 타격까지 지속피해 숫자로 묶여 **주황색**으로
##   나왔다 — 선회는 지속피해가 아닌데도 화면에서는 같은 색이었다. 이제 분리한다.
##
## 기본값(1.0 / false) 덕분에 배율·묶기 개념이 없는 호출(테스트, 도구)은 그대로 동작한다.
## is_crit: 이 타격이 **치명타 굴림을 통과했는가**. 피해에는 이미 배수가 곱해져 있으므로
##   (`WordTower.attack_target`) 이 인자는 **표시 전용**이다 — 피해 숫자를 전용 색으로 띄운다.
##   기본값 false 라 굴림 개념이 없는 호출(화상 틱, 테스트, 도구)은 그대로 동작한다.
func take_damage(amount: float, show_hit_sound: bool = true, mult: float = 1.0, pool_numbers: bool = false, is_crit: bool = false) -> float:
	if is_dead:
		return 0.0

	var health_before := hp + shield
	var absorbed = minf(shield, amount)
	shield -= absorbed
	hp = maxf(0.0, hp - (amount - absorbed))
	# 값 대입은 _process 의 Juice.approach 가 담당한다. 여기서 직접 대입하면
	# 감쇠가 무의미해진다(한 프레임에 튀고, 그 값에서 다시 따라가기 시작한다).
	if hp_bar:
		_refresh_hp_bar_color()

	var dealt := health_before - (hp + shield)
	# 방어도가 이 타격을 **전부** 먹었으면 HP 는 한 대도 안 깎였다. 그런데 지금까지는
	# 그 타격도 흰 숫자로 '30' 이라고 떴다 — 실제로 HP 30 을 깎은 타격과 **완전히
	# 똑같이** 보였다. 플레이어는 자기 타워가 잘 하고 있다고 읽는다.
	#
	# 'armored' 적은 방어도가 base_hp 의 0.8배, HP 가 1.5배다 — 바 전체(base 2.3)의
	# 약 35% 가 방어도다. 그래서 이 오해가 드문 일이 아니다. (Juice 에 'shield' 종류는
	# 예전부터 정의돼 있었지만 아무도 돌려주지 않아 화면에 나온 적이 없었다 —
	# 이제 그 분기가 살아난다)
	var kind := _damage_kind(absorbed, amount, dealt, mult, is_crit)
	# §2.20 (B) — 방어도가 **전부** 먹은 타격은 `hit` 대신 `shield` 를 낸다(2026-10-01, §5.2 32).
	#   전에는 이 타격도 `hit` 을 냈다 — 색은 'shield' 인데 소리는 '맞았다' 였다.
	#   ⚠️ **둘 다 내면 안 된다** — 스로틀이 이름별이라 `hit`·`shield` 가 서로를 막지 않고
	#      풀 12개에서 겹쳐 난다(실측 `blocked_hit_plays=["hit","shield"]`). 그래서 **교체**다.
	#   ⚠️ **새 소리 0** — `play_shield` 는 이미 있던 파형이고 지금까지 호출처가 0건이었다.
	#   ✅ **길이 순서도 닫혔다**(§5.2 32 (C), 2026-10-01) — `shield` 는 이제 **0.09초 ·
	#      200→100Hz 하강**이라 `hit`(0.12초)보다 **짧고 낮다**(밝기 108 → 18).
	#   ✅ **접두어 없음은 미완이 아니라 규칙이다**(2026-10-03 정정) — `Juice.damage_style`
	#      독스트링이 *"두 종류(약점/내성)만 이름과 색을 갖는다"* 고 선언한다: **접두어 = 관계,
	#      색·크기 = 사건**. `shield` 는 *"이 타격이 방어도에 먹혔다"* 는 **사건**이라 단어가 없다.
	#      `ShieldSignalProbe` S2 가 `prefix == ""` 를 단언한다.
	if show_hit_sound:
		if kind == "shield":
			SoundEngine.play_shield()
		else:
			SoundEngine.play_hit()
	if pool_numbers:
		_pending_dot_damage += dealt
		if _damage_number_timer <= 0.0:
			_damage_number_timer = 0.25
	else:
		_show_damage_number(dealt, Color.WHITE, kind)

	# Visual flash
	if sprite:
		sprite.modulate = Color(1.5, 0.4, 0.4)
		_flash_tween = create_tween()
		# 흰색으로 되돌리면 안 된다 — 감속 중이면 파란 기운이 섬광 때마다 지워져
		# "느려졌다 안 느려졌다" 로 깜빡인다. 원래 색으로 되돌린다.
		_flash_tween.tween_property(sprite, "modulate", _base_modulate(), 0.1)

	if hp <= 0.0:
		_die()
	return dealt


## 이번 타격이 화면에 어떤 종류로 뜨는가.
##
## **방어도가 전부 먹었으면(HP 가 한 대도 안 깎였으면) 'shield' 다.** 그 순간 숫자가
## 말하는 것과 실제로 일어난 일이 정반대이기 때문이다 — '30' 이라고 떴는데 HP 는
## 그대로다. 색을 바꿔 "그 30 은 방어도로 갔다" 를 알린다.
##
## 일부만 먹었으면 HP 가 실제로 줄었으므로 기존 분류(약점/내성/치명타)를 그대로 둔다.
## 그때의 상성은 **실제로 들어간 피해**에 대한 정직한 정보이고, 플레이어의 다음 결정
## (타워를 바꿀까)을 정한다. 방어도에 자리를 내주면 더 중요한 신호가 가려진다.
##
## 상성(약점)이 정답인 타격이라도 **전부** 먹혔으면 'shield' 다 — HP 에 닿지 않은
## 피해에 '약점' 이라는 품질을 붙이면 그것도 거짓말이다. 방어도는 몇 대 맞으면
## 벗겨지므로 상성 교훈은 곧 다시 온다.
##
## 순수 함수다 — 테스트가 실제 값으로 직접 부를 수 있다.
func _damage_kind(absorbed: float, amount: float, dealt: float, mult: float, is_crit: bool = false) -> String:
	if amount > 0.0 and absorbed >= amount:
		return "shield"
	return _hit_kind(dealt, mult, is_crit)


## 이번 타격이 화면에 어떤 종류로 뜨는가. **우선순위가 있다.**
##
##   1. 약점(mult >= 1.25) · 2. 내성(mult <= 0.75) — **상성은 사건보다 먼저다**
##   3. 치명타(is_crit) · 4. 큰 한 방(dealt >= 60) · 5. 보통
##
## ⚠️ 상성이 치명타를 **이긴다**. 상성은 '다음에 무엇을 놓을까' 를 정하는 **결정 신호**고,
##    치명타는 굴림이 낸 **사건**이다. 사건이 결정 신호를 가리면 플레이어는 상성표를
##    영영 배우지 못한다. 대신 피해 숫자 자체는 정직하다 — `dealt` 에는 두 배수가
##    모두 들어 있으므로 '약점 60' 은 실제로 60 이다(§2.21 결정 1).
##
## ⚠️ 2026-10-01 이전에는 3번 자리에 **임계가** 있었다(`"crit" if dealt >= 60.0`). 그래서
##    이름은 '치명타' 인데 사건은 '큰 피해' 였고, 진짜 치명타는 약한 타워에서 안 보였다.
##    이제 임계는 `big`, 굴림은 `crit` 이다(§5.2 33 (A)).
##
## 순수 함수다 — 테스트가 실제 값으로 직접 부를 수 있다.
func _hit_kind(dealt: float, mult: float, is_crit: bool = false) -> String:
	if mult >= WEAK_MULT:
		return "weak"
	if mult <= RESIST_MULT:
		return "resist"
	if is_crit:
		return "crit"
	return "big" if dealt >= BIG_HIT_THRESHOLD else "normal"


## 감속/섬광을 뺀 '원래' 색. 감속은 오버레이가 맡으므로 여기는 항상 흰색이다.
func _base_modulate() -> Color:
	return Color(1, 1, 1)


## 감속 상태를 스프라이트 색에 반영한다.
##
## 셰이더는 sprite 에만 물리므로 HP 바·배지는 영향받지 않는다. 피격 섬광은
## sprite.modulate 로 들어오는데, Godot 은 셰이더 결과 **뒤에** modulate 를 곱하므로
## 둘이 서로를 덮어쓰지 않는다(예전에 modulate 로 감속을 칠하려다 부딪혔던 지점).
func _refresh_slow_tint() -> void:
	if sprite == null:
		return
	var mat := _ensure_slow_material()
	if mat == null:
		return
	mat.set_shader_parameter("status_amount", SLOW_TINT_STRENGTH if slow_factor < 1.0 else 0.0)


## 감속용 셰이더 머티리얼을 sprite 에 물린다(한 번만).
func _ensure_slow_material() -> ShaderMaterial:
	if sprite == null:
		return null
	if _slow_material == null:
		_slow_material = ShaderMaterial.new()
		_slow_material.shader = STATUS_TINT_SHADER
		_slow_material.set_shader_parameter("status_tint", SLOW_TINT)
		_slow_material.set_shader_parameter("status_amount", 0.0)
		sprite.material = _slow_material
	return _slow_material


## 처치 사망. 예전에는 여기서 곧바로 queue_free() 를 불렀는데, 그러면 적이
## "죽는" 게 아니라 "그냥 없어진다". 15fps 실측에서 hp 가 0 이 된 다음 프레임에
## 노드가 통째로 사라졌고, sprite.scale 은 사망 내내 (1.0, 1.0) 에 고정돼 있었다
## (스쿼시·페이드·시체 전부 없음). 피격 순간을 놓치면 처치했는지조차 알 수 없다.
##
## 이제 DEATH_DURATION 동안 납작해지며 사라진 뒤 노드를 지운다.
## 이 시간 동안에도 DefenseField.get_enemies() 는 is_dead 를 걸러내므로
## 타워는 이미 다른 적을 노리고 있고, is_dead 가드 덕분에 추가 피해도 안 들어간다.
func _die() -> void:
	if is_dead:
		return
	is_dead = true
	if _pending_dot_damage > 0.0:
		_show_damage_number(_pending_dot_damage, Color(1.0, 0.65, 0.25), "dot")
		_pending_dot_damage = 0.0
	# 섬광 트윈을 먼저 죽인다. 안 그러면 이 트윈이 매 프레임 modulate 전체를
	# (1,1,1,1) 로 되돌려서 아래 페이드가 매 프레임 취소된다.
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	# 시체가 남는 동안 빈 HP 바와 속성 배지가 붙어 있으면 "HP 0 인데 살아 있는" 것처럼 보인다.
	if hp_bar:
		hp_bar.visible = false
	if _badge_row:
		_badge_row.visible = false
	if _state_row:
		_state_row.visible = false
	if _slow_badge:
		_slow_badge.visible = false
	# 골드·파편·분열은 전부 여기서 처리된다(DefenseField 가 died 를 받는다).
	died.emit(self)
	if sprite == null:
		queue_free()
		return
	# TextureRect 는 기본 피벗이 (0,0) 이라, 그대로 두면 제자리에서 납작해지는 게 아니라
	# 우하단으로 퍼지며 커진다. 중심을 잡아 준다.
	sprite.pivot_offset = sprite.size * 0.5
	# 보스는 sprite.scale 이 BOSS_SPRITE_SCALE 로 바뀌어 있다. Vector2.ONE 을 기준으로
	# 잡으면 보스가 죽는 순간 원래 크기로 줄어든다. **현재 스케일**을 기준으로 삼는다.
	var base: Vector2 = sprite.scale
	var squash: Vector2 = Vector2(base.x * DEATH_SQUASH.x, base.y * DEATH_SQUASH.y)
	var tw := create_tween()
	tw.set_parallel(true)
	var tw_squash := tw.tween_property(sprite, "scale", squash, 0.07)
	tw_squash.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 페이드는 조금 늦게 시작해 납작해지는 것과 겹친다(총 길이 = DEATH_DURATION).
	var tw_fade := tw.tween_property(sprite, "modulate:a", 0.0, 0.12)
	tw_fade.set_delay(DEATH_DURATION - 0.12)
	tw_fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)

func _show_damage_number(amount: float, color: Color, kind: String = "normal") -> void:
	if amount <= 0.0 or not is_inside_tree():
		return
	var style := Juice.damage_style(amount, kind)
	var label := Label.new()
	label.add_to_group("damage_numbers")
	# 치명타는 강조 접두 기호를 붙인다
	label.text = style["prefix"] + str(roundi(amount))
	label.position = global_position + Vector2(-18.0, -42.0)
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", style["size"])
	label.add_theme_color_override("font_color", color if kind == "dot" else style["color"])
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.12))
	label.add_theme_constant_override("outline_size", 4)
	get_tree().current_scene.add_child(label)
	var tw := label.create_tween()
	tw.set_parallel(true)
	# 약간의 좌우 흩어짐으로 연속 타격 시 숫자가 겹치지 않게
	var drift := randf_range(-10.0, 10.0)
	tw.tween_property(label, "position:x", label.position.x + drift, 0.65)
	tw.tween_property(label, "position:y", label.position.y - 30.0, 0.65)
	tw.tween_property(label, "modulate:a", 0.0, 0.65)
	# 등장 스케일 펀치 (큰 숫자일수록 더 크게)
	var pop := 1.25 if style["size"] >= 22 else 1.0
	if pop > 1.0:
		label.scale = Vector2(pop, pop)
		label.pivot_offset = label.size * 0.5
		tw.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	tw.chain().tween_callback(label.queue_free)

## 재생 속성: 초당 regen_per_sec 만큼 체력을 되돌린다.
## 지속 피해(burn)가 매 프레임 깎는 것과 정확히 반대 방향이라, DoT 만으로는 잡히지 않는다.
func _tick_regen(delta: float) -> void:
	if regen_per_sec <= 0.0 or hp >= max_hp:
		return
	hp = minf(max_hp, hp + regen_per_sec * delta)
	# 값 대입은 _process 의 Juice.approach 담당 (재생도 즉시 튀지 않게).
	if hp_bar:
		_refresh_hp_bar_color()


## 제어 타워의 감속을 건다.
##
## 예전에는 slow_factor 만 조용히 바뀌었다. 속도 변화는 32px 스프라이트가 경로를
## 지나는 모습으로만 드러나서, 플레이 중에는 "제어 타워가 일하고 있다" 는 사실이
## 사실상 보이지 않았다. 제어(control) 특성의 정체성이 통째로 비가시였던 셈이다.
##
## 이제 적 자체가 차가운 파랑으로 물든다 — 멀리서도, 여러 마리 중에서도 보인다.
## 배지는 붙이지 않는다. 걸릴 때마다 배지가 생기면 화면이 글자로 덮인다.
func apply_slow(factor: float, duration: float) -> void:
	# 질주(swift): 감속을 통째로 무시한다 — 제어 타워가 이 적에게는 헛방이 된다.
	# 이 '거부' 는 색으로 표현할 수 없다(아무 일도 안 일어나니까). 그래서 여기만
	# 배지로 알린다. 안 그러면 플레이어는 제어 타워가 고장난 줄 안다.
	if slow_immune:
		_show_immune_badge()
		return
	slow_factor = minf(slow_factor, factor)
	slow_timer = maxf(slow_timer, duration)
	_refresh_slow_tint()


func _hide_immune_badge() -> void:
	if _slow_badge != null:
		_slow_badge.visible = false

## 감속이 거부됐다는 표시. '면역' 을 잠깐 띄운다.
## 거부는 매 공격마다 일어나므로(제어 타워 간격 ~1.5초) 수명을 두고,
## 그 사이에 다시 거부되면 수명만 갱신한다 — 연속으로 깜빡이지 않는다.
func _show_immune_badge() -> void:
	_ensure_slow_badge()
	if _slow_badge == null:
		return
	_slow_badge.text = "면역"
	_slow_badge.visible = true
	_slow_badge_timer = IMMUNE_BADGE_TIME

func _ensure_slow_badge() -> void:
	_ensure_state_row()


## 화상 칩을 갱신한다. 겹수(중첩)를 함께 보여준다 —
## 같은 적에게 두 번 들어가면 피해가 두 배가 되는데, 숫자 피해만으로는 구분되지 않는다.
func _refresh_burn_badge() -> void:
	var stacks := burn_effects.size()
	if stacks <= 0:
		if _burn_badge != null:
			_burn_badge.visible = false
		return
	_ensure_state_row()
	if _burn_badge == null:
		return
	_burn_badge.text = "화상" if stacks == 1 else "화상 ×%d" % stacks
	_burn_badge.visible = true


## 상태 칩(면역·화상)을 담는 줄을 한 번만 만든다. 칩 둘을 함께 만들어 순서를 고정한다 —
## 상태가 생긴 순서에 따라 '면역 화상' 과 '화상 면역' 이 번갈아 나오면 읽는 사람이 헷갈린다.
##
## 칩마다 위치를 손으로 잡던 예전 방식은 둘이 동시에 뜰 때 겹쳤다 — 질주하는 적이
## 제어 타워와 지속 피해 타워 사거리에 함께 들어가면 실제로 겹친다.
## 컨테이너에 넣어 두면 몇 개가 뜨든 가운데 정렬로 나란히 선다.
func _ensure_state_row() -> void:
	if _state_row != null or not is_inside_tree():
		return
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.custom_minimum_size = Vector2(STATE_ROW_WIDTH, STATE_CHIP_SIZE.y)
	add_child(wrapper)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	wrapper.add_child(row)
	# add_child 뒤에 preset 을 잡는다 — 순서를 뒤집으면 첫 프레임에 크기가 0 으로 굳는다.
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_state_row = row
	_state_wrapper = wrapper
	_slow_badge = _make_state_chip(Color(0.85, 0.88, 0.95))
	_slow_badge.visible = false
	row.add_child(_slow_badge)
	_burn_badge = _make_state_chip(BURN_BADGE_COLOR)
	_burn_badge.visible = false
	row.add_child(_burn_badge)
	# 자리는 껍데기가 들고 있다 — 현재 크기에 맞춰 잡아 준다.
	_apply_visual_layout()


## 상태 칩 하나. 어두운 바탕 + 색 글자 — 적의 몸통을 가리지 않으면서 색으로 상태를 말한다.
func _make_state_chip(font_color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = ""
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", font_color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.custom_minimum_size = STATE_CHIP_SIZE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.07, 0.14, 0.86)
	bg.set_corner_radius_all(3)
	lbl.add_theme_stylebox_override("normal", bg)
	return lbl

func apply_burn(dps: float, duration: float, source_tower: WordTower = null) -> void:
	burn_effects.append({"dps": dps, "remaining": duration, "source": source_tower})
	# 상태가 '생겼다' 는 순간에만 칩을 갱신한다. 매 프레임 다시 그리면
	# 같은 글자를 계속 다시 쓰게 된다(만료는 _tick_burn 이 처리한다).
	_refresh_burn_badge()

## 특성 하나가 이 적에게 들어가는 피해 배율.
##
## 두 축을 곱한다:
##   (1) 타입 배율 — 중갑/군집/질풍 같은 '실루엣' 상성 (MonsterRoster.TYPE_MULTIPLIERS)
##   (2) 속성 배율 — 재생/분열/질주 같은 '행동' 상성 (MonsterRoster.ATTR_MULTIPLIERS)
## 그리고 결계(warded:특성)는 그 특성을 거의 막는다.
##
## 보스 약점(weakness_trait)은 두 축을 덮어쓰고 1.5 로 고정한다 —
## "보스는 약점을 찔러야 한다" 는 규칙이 다른 배율에 흔들리면 안 되기 때문이다.
##
## 타입 배율은 표에서 읽는다. 예전에는 여기 match 문에만 값이 있어서, 화면에
## '중갑은 관통에 약하다' 를 쓰려면 같은 표를 한 번 더 적어야 했다.
func damage_multiplier_for(trait_id: String) -> float:
	if weakness_trait == trait_id:
		return 1.5
	var multiplier := 1.0
	var type_table: Dictionary = MonsterRoster.TYPE_MULTIPLIERS.get(enemy_type, {})
	multiplier *= float(type_table.get(trait_id, 1.0))
	# 보스는 약점을 찌르지 않으면 어느 특성으로도 잘 박히지 않는다.
	# 궤도 오브는 갑옷에 튕기고, 유성은 무게로 찍어 누른다 — 그 값은 표에 있다.
	if enemy_type == "boss" and trait_id != weakness_trait:
		multiplier *= 0.9
	for attr in attrs:
		var text := str(attr)
		if text.begins_with(MonsterRoster.WARD_PREFIX):
			if text.substr(MonsterRoster.WARD_PREFIX.length()) == trait_id:
				multiplier *= 0.35
			continue
		var table: Dictionary = MonsterRoster.ATTR_MULTIPLIERS.get(text, {})
		multiplier *= float(table.get(trait_id, 1.0))
	# 곱이 극단으로 가면 상성이 '죽은 특성' 이 된다 — 상한/하한을 둔다.
	return clampf(multiplier, 0.3, 1.8)


func _tick_burn(delta: float) -> void:
	for i in range(burn_effects.size() - 1, -1, -1):
		var effect := burn_effects[i]
		var active_time := minf(delta, effect["remaining"])
		var dealt := take_damage(effect["dps"] * active_time, false, 1.0, true)
		if is_instance_valid(effect.source): effect.source.record_damage(dealt)
		effect["remaining"] -= delta
		if effect["remaining"] <= 0.0:
			burn_effects.remove_at(i)
	# 다 타 버렸으면 칩을 내린다. 안 그러면 '불타는 중' 이 영원히 남아
	# 지속 피해 타워가 계속 일하고 있다고 화면이 거짓말한다.
	if burn_effects.is_empty() and _burn_badge != null and _burn_badge.visible:
		_burn_badge.visible = false
