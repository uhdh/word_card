# Juice.gd
# 게임 전반의 "손맛(Juice)"을 담당하는 유틸 모음.
# - 화면 흔들림(Camera2D 없이 Control 컨테이너를 직접 흔드는 방식)
# - 데미지 숫자 스타일 (치명타/일반/지속피해 구분)
# - 값이 목표로 따라가는 감쇠 곡선(`approach_value`) — 체력 바와 골드 표시가 함께 쓴다
#
# 사용법:
#   Juice.shake(self, 6.0, 0.25)          # 특정 Control 흔들기
#   Juice.shake_together([                # 한 사건으로 **여러 노드** 흔들기(같은 방향)
#       {"node": field, "intensity": 9.0},
#       {"node": slots, "intensity": 6.0},
#   ], 0.35)
#   Juice.approach(bar, want, delta)      # 매 프레임 — Range 를 목표로 따라가게
#   Juice.approach_value(v, want, delta)  # 같은 곡선을 **숫자**에 쓸 때
#   Juice.flash(screen, Palette.HP_DANGER, 0.18, 0.08, 0.28)  # 화면을 붉게 덮는 섬광 1회
class_name Juice

## 대상 노드(Control 또는 Node2D)를 감쇠 진동으로 흔든다.
## (원래 위치를 기준으로 오프셋만 가하므로 레이아웃에 영향을 주지 않는다)
static func shake(target: Node, intensity: float = 5.0, duration: float = 0.22) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not (target is Control or target is Node2D):
		return
	if not target.is_inside_tree():
		return
	# 이미 흔들리는 중이면 중첩하지 않는다 (누적 폭주 방지)
	if target.has_meta("_juice_shaking"):
		return
	target.set_meta("_juice_shaking", true)

	var base: Vector2 = target.position
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tw := target.create_tween()
	# 약 20스텝으로 나눠 감쇠 진동을 근사
	var steps := 10
	for i in range(steps):
		var progress := float(i) / float(steps)
		var decay := 1.0 - progress
		var offset := Vector2(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)
		) * intensity * decay
		tw.tween_property(target, "position", base + offset, duration / float(steps))
	tw.tween_property(target, "position", base, 0.06)
	_restore_when_done(tw, target, base)

## 여러 노드를 **한 방향으로** 흔든다 — 한 사건이 여러 노드를 흔들 때.
##
## ⚠️ 왜 `shake()` 를 두 번 부르면 **안 되는가**: `shake()` 는 호출마다 자기만의 RNG 를
## 만든다(`rng.randomize()`). 그래서 두 노드가 **서로 무관한 방향**으로 흔들린다 —
## 한 사건인데 화면에서는 두 물체가 따로 떨리는 것으로 읽힌다.
## 실측(`tools/ShakeCoherenceProbe.gd`): 최악 프레임 **89°**, 평균 방향 일치도 **0.57**,
## 판정한 15프레임 중 **2프레임은 정반대** 방향이었다. '충격' 이 아니라 '잡음' 이다.
##
## 게다가 자식 노드를 함께 흔들면 오프셋이 **합성**된다(자식의 화면상 변위 = 부모 + 자기).
## 방향이 다르면 합이 상쇄되거나 어긋나서, 의도한 '더 세게' 가 '더 흐트러지게' 가 된다.
##
## `specs`: `[{"node": Node, "intensity": float}, …]` — **같은 오프셋 열**에 각자의 배율을 곱한다.
## 그래서 모든 노드의 변위가 **평행**하다(각도 0). 배율만 다르므로 '약하게/강하게' 는 그대로 산다.
##
## ⚠️ 길이(`duration`)는 **하나**다. 한 사건은 한 길이여야 한다 — 노드마다 다른 길이를 주면
## 먼저 끝난 노드가 제자리로 돌아가 홀로 멈춰 있는 구간이 생긴다.
static func shake_together(specs: Array, duration: float = 0.22) -> void:
	# 흔들 수 있는 노드만 남긴다 — 조건이 안 맞는 노드는 조용히 빠진다(하나 때문에 전부 막지 않는다).
	var live: Array = []
	for spec in specs:
		var node: Node = spec.get("node")
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Control or node is Node2D):
			continue
		if not node.is_inside_tree():
			continue
		if node.has_meta("_juice_shaking"):
			continue
		live.append({
			"node": node,
			"intensity": float(spec.get("intensity", 5.0)),
			"base": node.position,
		})
	if live.is_empty():
		return
	for entry in live:
		entry["node"].set_meta("_juice_shaking", true)

	# ⚠️ RNG 가 **하나**인 것이 이 함수의 존재 이유다. 여기서 노드마다 RNG 를 만들면
	#    `shake()` 를 두 번 부른 것과 같아진다.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var steps := 10
	var step_time := duration / float(steps)
	var tweens: Array = []
	for entry in live:
		tweens.append(entry["node"].create_tween())
	for i in range(steps):
		var decay := 1.0 - float(i) / float(steps)
		# 스텝마다 **한 번** 뽑아 모든 노드가 같은 방향을 쓴다.
		var unit := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		for j in range(live.size()):
			var entry: Dictionary = live[j]
			(tweens[j] as Tween).tween_property(
				entry["node"], "position", entry["base"] + unit * entry["intensity"] * decay, step_time)
	for j in range(live.size()):
		var entry: Dictionary = live[j]
		(tweens[j] as Tween).tween_property(entry["node"], "position", entry["base"], 0.06)
		_restore_when_done(tweens[j], entry["node"], entry["base"])

## 흔들림이 끝나면 제자리로 되돌리고 `_juice_shaking` 을 푼다.
##
## 주의: 람다가 target 을 직접 캡처하면, 흔들리는 도중 그 노드가 해제될 때
## "Lambda capture at index 0 was freed" 에러가 엔진에서 찍힌다.
## (is_instance_valid 검사는 람다가 '실행'된 뒤라 이미 늦다 — 캡처 바인딩 시점에 터진다)
## weakref 는 RefCounted 라 캡처가 절대 해제되지 않는다.
static func _restore_when_done(tw: Tween, target: Node, base: Vector2) -> void:
	var weak: WeakRef = weakref(target)
	tw.tween_callback(func():
		var node_ref = weak.get_ref()
		if node_ref != null and is_instance_valid(node_ref):
			node_ref.position = base
			node_ref.remove_meta("_juice_shaking")
	)

## 부모(보통 필드)를 잠깐 색으로 덮는 **섬광**.
##
## ⚠️ 왜 함수로 뽑았는가: 같은 8줄이 `DefenseField` 두 곳에 **복사**돼 있었고 숫자만 달랐다
## (보스 등장 / 기지 피격 — 감사 §5.2 15). 복사본이 둘이면 한쪽만 고쳐도 다른 쪽이 옛 모양으로
## 남는다 — 이 프로젝트가 §2.4-a(흔들림)와 §2.10-c(사유 문구)에서 이미 두 번 밟은 함정이다.
##
## 계약(`tools/FlashProbe.tscn` 이 지킨다):
##   · 부모를 **꽉 채운다**(`PRESET_FULL_RECT`) — 부모가 곧 '화면' 이라는 뜻이다
##     ⚠️ 그래서 **화면 크기 노드**를 넘겨야 한다. 필드 같은 부분 노드를 넘기면 섬광이
##     그 노드만 덮는다(§2.11-a 실측: 필드를 넘겨 **화면의 48.3%** 만 덮였다).
##     ⚠️ 컨테이너(`VBoxContainer` 등)를 넘기면 안 된다 — 컨테이너는 자식을 자기 규칙으로
##     배치하므로 `PRESET_FULL_RECT` 가 무시되고 섬광이 한 칸에 끼어 버린다.
##   · 마우스를 **먹지 않는다** — 화면을 덮는 판이 클릭을 가로채면 조작이 죽는다
##   · alpha `0 → peak`(fade_in 초) `→ 0`(fade_out 초), 끝나면 **스스로 사라진다**(누수 없음)
##
## ⚠️ 시작 alpha 는 인자와 무관하게 **0 으로 강제**한다. 트윈은 '지금 값 → 목표' 로 가므로,
##   호출자가 alpha 1 짜리 색을 넘기면 섬광이 **완전히 불투명한 채로 시작**해 버린다.
##   (그래서 색만 받고 불투명도는 `peak` 하나로 다룬다)
static func flash(parent: Control, color: Color, peak: float, fade_in: float, fade_out: float) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if not parent.is_inside_tree():
		return
	var rect := ColorRect.new()
	rect.color = Color(color.r, color.g, color.b, 0.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(rect)
	# 트윈은 노드가 소유한다 — 부모가 먼저 사라져도 트윈이 같이 정리된다.
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", peak, fade_in)
	tw.tween_property(rect, "color:a", 0.0, fade_out)
	tw.tween_callback(rect.queue_free)

## 값 하나를 목표로 지수 감쇠시킨다. `approach()` 의 알맹이를 분리한 것으로,
## **`Range` 가 아닌 값**(골드 표시 숫자 등)에도 같은 곡선을 쓰기 위해 존재한다.
##
## ⚠️ 곡선을 복사하지 말고 이 함수를 부를 것. 바와 숫자가 다른 속도로 따라오면
##    같은 화면 안에서 두 개의 '시간' 이 생긴다.
##
## 트윈을 쓰지 않는 이유가 두 가지 있다.
##  1) 적 HP 바는 초당 수십 번 갱신된다. 그때마다 트윈을 만들면 같은 프로퍼티에
##     트윈이 여러 개 붙어 서로 상쇄된다(이 프로젝트에서 반복적으로 밟은 함정).
##  2) 프레임 독립 지수 감쇠라서 4배속에서도 체감이 같다.
## rate 가 클수록 빨리 따라붙는다. 16 이면 약 0.19초에 95% 도달.
static func approach_value(current: float, want: float, delta: float, rate: float = 16.0) -> float:
	# 아주 가까우면 스냅한다. 안 그러면 0.05 미만의 차이가 영원히 남아 값이
	# 미세하게 떨리거나(바) 목표에 영영 닿지 않는다(정수 표시).
	if absf(current - want) < 0.05:
		return want
	return lerpf(current, want, 1.0 - exp(-rate * delta))

## 체력 바가 목표값으로 즉시 튀지 않고 따라가게 한다. **매 프레임 호출**해야 한다.
static func approach(bar: Range, want: float, delta: float, rate: float = 16.0) -> void:
	if bar == null or not is_instance_valid(bar):
		return
	bar.value = approach_value(bar.value, want, delta, rate)


## 짧은 타격 섬광. 기본 공격은 분당 100회 이상 일어나므로 파티클은 쓸 수 없다 —
## Sprite2D 하나를 빠르게 키우며 지우는 것이 상한이다(총 0.12초).
## parent 는 투사체의 부모처럼 **투사체보다 오래 사는** 노드여야 한다.
##
## ColorRect 가 아니라 Sprite2D 인 이유:
##  · Sprite2D 는 기본이 중심 정렬이라 위치 계산이 틀릴 여지가 없다. ColorRect 는
##    global_position 이 '사각형의 좌상단'이라 size/2 를 빼야 하는데, pivot_offset 과
##    겹치면 어긋난다(실측: 임팩트가 명중 지점에서 우상단으로 밀려났다).
##  · 사각형은 하드엣지라 '타격 섬광'이 아니라 UI 사각형처럼 보인다. 라디얼
##    그라데이션은 가장자리가 부드럽게 사라져서 섬광으로 읽힌다.
##  · 배경이 초원이라 초록 탄의 섬광은 묻힌다. 그래서 색을 흰색 쪽으로 민다(호출부).
static func impact(parent: Node, pos: Vector2, color: Color, radius: float = 12.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if not parent.is_inside_tree():
		return
	var tex := _flash_texture()
	var fx := Sprite2D.new()
	fx.texture = tex
	fx.centered = true
	fx.modulate = color
	fx.z_index = 98
	parent.add_child(fx)
	# 주의: 트리에 들어가기 전에는 global_position 이 안 먹는다. add_child 뒤에 잡는다.
	fx.global_position = pos
	# 텍스처가 64px 이므로 '지름 = radius*2' 가 되게 맞춘 뒤 1.85배까지 키운다.
	# 2.2배까지 키우면 적(36px)보다 훨씬 큰 57px 구름이 되어 '타격'이 아니라
	# '번짐'으로 읽혔다(실측 프레임 비교).
	var s0: float = (radius * 2.0) / float(tex.width)
	fx.scale = Vector2(s0, s0)
	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector2(s0 * 1.85, s0 * 1.85), 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fx, "modulate:a", 0.0, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(fx.queue_free)


## 특성별 타격 모양. 예전에는 11종이 **전부 같은 라디얼 섬광** 하나를 썼다 —
## 탄 색만 달라서 '폭발' 과 '연사' 의 타격이 화면에서 구분되지 않았다.
##
## 모양은 새로 지어낸 것이 아니라 TraitStyle.DESCRIPTIONS 가 **이미 약속한 문장**에서
## 그대로 나온다(설명이 계약이다):
##   폭발 "착탄 지점 주변의 적들" · 둔화 "스플래쉬 냉기"  → 고리(blast)
##   관통 "적을 꿰뚫어" · 저격 "긴 사거리 … 저격"             → 직선(streak)
##   연쇄 "연쇄적으로 튕기며" · 바운스 "최대 3회 튕기며"       → 꺾은선(ricochet)
## 연사·지속피해·균형은 약속한 '모양' 이 없으므로 기존 섬광을 쓴다(모양은 안 지어낸다).
## 다만 크기는 올렸다 — 아래 '크기' 참고.
##
## **타격당 노드 수는 늘리지 않는다** — 모양 하나. 그래서 소음도 비용도 그대로다
## (기본 공격은 분당 100회가 넘는다. 여기서 노드를 하나 더 만들면 그대로 부하가 된다).
##
## 크기: 처음엔 폭발 고리가 지름 70px(적 36px 의 1.9배)였는데 **체감이 약하다**는
## 지적을 받았다. 원인은 크기만이 아니라 **선 굵기**였다 — 2.5px 짜리 가는 고리는
## 0.16초 만에 사라져서 '터졌다' 가 아니라 '스쳤다' 로 읽힌다. 그래서
##   굵기 ×1.8 (2.5→4.5 / 3.0→5.0) · 크기 ×1.65 (피크 지름 70→114px) · 지속 ×1.25
## 로 올렸다. 노드 수는 그대로 1개다 — 크게 만들되 더 만들지는 않는다.
## `antialiased` 를 켠 것도 같은 이유다: 계단 진 가는 선은 크기보다 먼저 눈에 띄게
## '싸구려' 로 읽힌다.
##
## 섬광(모양 없는 5종)은 ×1.33(12→16)만 올렸다. 모양만 커지면 나머지가 더 약해 보이지만,
## 연사는 0.3초 간격(분당 200발)이라 같은 배수로 키우면 화면이 섬광으로 덮인다.
## **같은 지시라도 빈도가 다르면 같은 배수를 쓸 수 없다.**
static func trait_impact(parent: Node, pos: Vector2, color: Color, trait_id: String, angle: float) -> void:
	match trait_id:
		"splash":
			blast(parent, pos, color, 38.0)
			sprite_fx(parent, pos, "res://assets/fx/fx_hit_blast_48px.png", color, 1.2, 0.22)
		"control":
			blast(parent, pos, color, 28.0)
			sprite_fx(parent, pos, "res://assets/fx/fx_hit_frost_48px.png", color, 1.1, 0.22)
		"pierce":
			streak(parent, pos, color, angle, 52.0)
			sprite_fx(parent, pos, "res://assets/fx/fx_hit_pierce_48px.png", color, 1.2, 0.20, angle)
		"sniper":
			streak(parent, pos, color, angle, 70.0)
			sprite_fx(parent, pos, "res://assets/fx/fx_hit_pierce_48px.png", color, 1.35, 0.20, angle)
		"chain":
			ricochet(parent, pos, color, angle, 23.0)
			sprite_fx(parent, pos, "res://assets/fx/fx_hit_spark_48px.png", color, 1.15, 0.20)
		"bounce":
			ricochet(parent, pos, color, angle, 18.0)
			sprite_fx(parent, pos, "res://assets/fx/fx_hit_spark_48px.png", color, 1.0, 0.18)
		"rapid":
			sprite_fx(parent, pos, "res://assets/fx/fx_hit_slash_48px.png", color, 0.9, 0.16, angle)
		_:
			sprite_fx(parent, pos, "res://assets/fx/fx_hit_blast_48px.png", color, 0.9, 0.18)

## 픽셀 아트 스프라이트 기반 고품질 착탄 이펙트
static func sprite_fx(parent: Node, pos: Vector2, tex_path: String, tint: Color, scale_mult := 1.0, duration := 0.2, angle := 0.0) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var spr := Sprite2D.new()
	spr.texture = load(tex_path)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.global_position = pos
	spr.rotation = angle
	spr.z_index = 99
	spr.modulate = Color(tint.r, tint.g, tint.b, 1.0)
	spr.scale = Vector2.ONE * 0.4 * scale_mult
	parent.add_child(spr)
	var tw := spr.create_tween()
	tw.set_parallel(true)
	tw.tween_property(spr, "scale", Vector2.ONE * 1.15 * scale_mult, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(spr.queue_free)


## 폭발·냉기 — 착탄 지점에서 퍼지는 **고리**.
##
## impact() 처럼 채우지 않고 가장자리만 그린다. 폭발에서 정보인 것은 '얼마나 넓게
## 번졌는가' 인데, 가운데를 채우면 그냥 큰 얼룩이 되어 그 크기를 읽을 수 없다.
static func blast(parent: Node, pos: Vector2, color: Color, radius: float = 38.0) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var seg := 24
	var pts := PackedVector2Array()
	for i in seg + 1:
		var a := TAU * float(i) / float(seg)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	var fx := Line2D.new()
	fx.points = pts
	fx.width = 4.5
	fx.antialiased = true
	fx.default_color = color
	fx.z_index = 98
	parent.add_child(fx)
	fx.global_position = pos
	# 작게 시작해 조금 커지며 사라진다 — '터지는' 방향이 바깥이라는 신호.
	fx.scale = Vector2(0.45, 0.45)
	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector2(1.5, 1.5), 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fx, "modulate:a", 0.0, 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(fx.queue_free)


## 관통·저격 — 진행 방향으로 뻗는 **직선**.
##
## '어디서 어디로 꿰뚫었는가' 를 보여준다. 저격은 사거리가 230px 라 탄이 너무 빨라
## (650px/s) 눈으로 따라갈 수 없다 — 이 선이 유일한 흔적이다.
## 선은 노드 회전이 아니라 **점 자체**가 방향을 담는다. 그래야 scale.x 로
## '뻗어 나가는' 연출을 방향 그대로 줄 수 있다.
static func streak(parent: Node, pos: Vector2, color: Color, angle: float, length: float = 52.0) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var dir := Vector2.RIGHT.rotated(angle)
	var fx := Line2D.new()
	fx.points = PackedVector2Array([-dir * length * 0.5, dir * length * 0.5])
	fx.width = 5.0
	fx.antialiased = true
	fx.default_color = color
	fx.z_index = 98
	parent.add_child(fx)
	fx.global_position = pos
	fx.scale = Vector2(0.55, 1.0)
	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector2(1.25, 0.4), 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fx, "modulate:a", 0.0, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(fx.queue_free)


## 연쇄·바운스 — 튕긴 자국을 남기는 **꺾은선**.
##
## 설명이 약속한 "튕기며" 를 보여준다. 연쇄는 전격 색(노랑), 바운스는 초록이라
## 같은 모양이어도 둘이 헷갈리지 않는다.
static func ricochet(parent: Node, pos: Vector2, color: Color, angle: float, size: float = 18.0) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var dir := Vector2.RIGHT.rotated(angle)
	var nrm := dir.orthogonal()
	var fx := Line2D.new()
	fx.points = PackedVector2Array([
		-dir * size * 1.2, nrm * size * 0.55,
		dir * size * 0.15, -nrm * size * 0.5,
		dir * size * 1.3,
	])
	fx.width = 4.0
	fx.antialiased = true
	fx.default_color = color
	fx.z_index = 98
	parent.add_child(fx)
	fx.global_position = pos
	fx.scale = Vector2(0.6, 0.6)
	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector2(1.35, 1.35), 0.19) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fx, "modulate:a", 0.0, 0.19) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(fx.queue_free)


## 타격 섬광용 라디얼 그라데이션. 한 번만 만들어 재사용한다 —
## 기본 공격은 분당 100회가 넘어서 매번 텍스처를 만들면 그 자체가 부하다.
static var _flash_tex: GradientTexture2D = null

static func _flash_texture() -> GradientTexture2D:
	if _flash_tex != null and is_instance_valid(_flash_tex):
		return _flash_tex
	var g := Gradient.new()
	# 가운데는 꽉 차고, 중간부터 빠르게 옅어져 가장자리가 사라진다.
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.55),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_flash_tex = t
	return _flash_tex


## 데미지 수치를 종류별 색/크기로 분류해 돌려준다.
## kind: "normal" | "crit" | "big" | "dot" | "shield" | "weak" | "resist"
##
## ⚠️ `crit` 과 `big` 은 **다른 사건**이다(§2.21). `crit` 은 굴림을 통과한 진짜 치명타,
##    `big` 은 굴림과 무관하게 피해가 60 을 넘은 한 방. 예전에는 둘 다 `crit` 이었고
##    화면에는 후자만 나왔다 — 그래서 색을 **다르게** 둔다. 같으면 두 사건이 다시 뭉친다.
##
## "weak"/"resist" 는 **속성 상성** 전용이다. 피해 배율(EnemyUnit.damage_multiplier_for)
## 은 오래전부터 있었는데, 배율이 투사체 단계에서 피해에 미리 곱해지는 바람에
## 1.6배와 0.65배가 똑같이 흰 숫자로만 보였다 — 표에는 있는데 화면에는 없었다.
## 이제 두 종류만 이름과 색을 갖는다:
##   · 약점 — 금색 + '약점' 접두. "지금 이 특성이 정답" 을 알린다.
##   · 내성 — 차가운 회청색 + '내성' 접두. "이 특성으로는 안 된다" 를 알린다.
## 둘 다 **상성이 실제로 어긋난 타격에만** 붙는다. 정상 배율(1.0)에는 아무것도
## 안 붙으므로, 매 타격마다 글자가 뜨는 소음이 되지 않는다.
##
## "shield" 도 같은 처지였다 — 색과 크기가 여기 정의돼 있었지만 **아무도 이 종류를
## 돌려주지 않아** 화면에 나온 적이 없었다(죽은 분기). 방어도가 타격을 전부 먹은
## 순간 EnemyUnit 이 이제 이 종류를 돌려준다. 색은 Palette.SHIELD 하나를 쓴다 —
## 같은 색이 적 HP 바에도 쓰이기 때문이다.
static func damage_style(_amount: float, kind: String = "normal") -> Dictionary:
	match kind:
		"crit":
			# **진짜 치명타** — 굴림이 낸 사건(§2.21 (A)). 브랜드 보라를 쓴다.
			# ⚠️ 아래 `big`(금색)과 **색이 달라야 한다** — 같으면 §2.19 처럼 두 사건이
			#    다시 한 채널로 뭉친다. 크기(28 vs 26)는 부차적이고 색이 주 채널이다.
			return {"color": Palette.MANA_INK, "size": 28, "prefix": ""}
		"big":
			# 치명타가 **아니어도** 큰 한 방은 크게 보인다. 예전 `crit` 이 하던 일 그대로 —
			# 60 임계는 사건이 아니라 '세기' 라는 다른 축이다.
			return {"color": Color(1.0, 0.85, 0.35), "size": 26, "prefix": ""}
		"dot":
			return {"color": Color(1.0, 0.62, 0.28), "size": 16, "prefix": ""}
		"shield":
			return {"color": Palette.SHIELD, "size": 17, "prefix": ""}
		"weak":
			return {"color": Color(1.0, 0.87, 0.40), "size": 20, "prefix": "약점 "}
		"resist":
			# shield(Palette.SHIELD) 와 헷갈리지 않도록 더 어둡고 덜 푸르게 둔다.
			return {"color": Color(0.52, 0.56, 0.66), "size": 15, "prefix": "내성 "}
		_:
			# ⚠️ 2026-10-01 — 여기 있던 `if amount >= 60.0: size = 22` 를 지웠다.
			#    그 분기는 **도달 불가**였다: `_` 로 오는 `normal` 은 `_hit_kind` 가
			#    이미 `dealt < 60` 을 보장한다(60 이상은 `big` 이 가져간다).
			#    그래서 22px 은 화면에 나온 적이 없었고, `CritSignalProbe` S4 가
			#    그것을 '죽은 분기' 로 잡아 두고 있었다.
			return {"color": Color(0.95, 0.95, 0.98), "size": 18, "prefix": ""}
