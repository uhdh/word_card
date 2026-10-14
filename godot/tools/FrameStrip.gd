extends Node
# FrameStrip.gd — 짧은 순간을 **연속 프레임으로** 캡처해 연출의 '과정'을 검증한다.
#
# Shot.tscn 은 한 장만 찍는다. 그래서 "적이 죽는 과정이 있는가", "투사체가 맞는 순간
# 무슨 일이 일어나는가", "HP 바가 즉시 튀는가 따라오는가" 같은 **동적** 질문을
# 검증할 수 없다. 이 도구는 그 빈틈을 채운다.
#
#   godot --path . res://tools/FrameStrip.tscn -- \
#     act=1 towers=개구리,검 monsters=4 frames=36 every=1 \
#     crop=0,60,900,300 scale=1 out=E:/project/word_card/_strip/run1
#
# 인자
#   act      캡처할 막 (기본 1)
#   towers   세울 타워 음절 (쉼표) — 비우면 안 세운다
#   monsters 세울 잡몹 수 (0이면 없음)
#   boss     1이면 보스도 세운다
#   warmup   캡처 전 대기 프레임 (기본 30). 공격 타이머가 돌아가게 한다.
#   frames   캡처할 프레임 수 (기본 24)
#   every    몇 프레임마다 찍을지 (기본 1 = 매 프레임)
#   crop     x,y,w,h — 원본 해상도 기준. 비우면 전체 화면
#   follow   1이면 crop 을 **첫 번째 적 중심**으로 매 프레임 다시 잡는다.
#            적은 경로를 따라 움직이므로, 고정 crop 으로는 한 마리의 생애를 못 담는다.
#            (사망 순간을 보려면 이 옵션이 사실상 필수다)
#   follow_size 따라갈 창의 크기 (기본 260 = 260x260)
#   scale    crop 후 확대 배율 (정수, 기본 1)
#   out      출력 접두. `<out>_000.png` … 로 저장. 기본 E:/project/word_card/_strip/f
#   slowmo   Engine.time_scale (1.0 미만 = 느리게). 짧은 연출을 여러 프레임에 담을 때 필수.
#   diag     1이면 타워 사거리/적 위치와 프레임별 투사체 위치·회전각을 숫자로 찍는다.
#            "타워가 왜 안 쏘는가", "회전 연출이 살아 있는가" 는 이미지로 판정이 안 된다.
#   fireat   이 캡처 프레임에서 모든 타워를 강제 발사. attack_interval 에 맡기면
#            발사 시점이 운이 되고, slowmo 를 걸면 첫 발까지 수백 프레임이 걸린다.
#   killat   이 캡처 프레임에서 첫 번째 적을 처치 (사망 연출 검증용)
#   hitat    이 캡처 프레임에서 첫 번째 적에게 hitdamage 만큼 피해 (HP 바 검증용)
#   hitcrit  hitat 이 줄 피해를 **치명타로** 표시할지 (1/0, 기본 0). §2.21 의 치명타
#            숫자 색을 눈으로 확인하는 유일한 경로다 — 굴림에 맡기면 운이 된다.
#   at       적을 경로의 몇 % 지점에 세울지 (기본 0.30). 타워 사거리 안인지 diag 로 확인할 것.
#   reset    1이면 매 프레임 적 progress 를 되돌려 '같은 순간'을 반복 관찰한다
#            (투사체 명중처럼 매번 다른 위치에서 일어나는 사건을 잡을 때)
#
# 주의: --headless 로는 동작하지 않는다 (frame_post_draw 가 오지 않는다).
# 주의: 이 스크립트 이름을 SaveManager._is_test_run() 에 넣어야 실제 세이브를 덮지 않는다.
#       (Shot 과 같은 이유 — 지금은 fresh 를 쓰지 않으므로 읽기만 한다)

var _act := 1
var _towers := ""
var _monsters := 0
var _boss := false
var _warmup := 30
var _frames := 24
var _every := 1
var _crop := ""
var _scale := 1
var _follow := false
var _follow_size := 260
## 1이면 적의 speed 를 0 으로 묶는다.
## follow 로 적을 따라가면 배경까지 함께 움직여서 프레임간 변화량이 전부 커진다 —
## "적이 죽는 순간 화면에 무엇이 바뀌는가" 를 분리해 보려면 적이 정지해 있어야 한다.
## 정지시킨 적은 타워 사거리 안에 두면 계속 맞아서 결국 죽는다.
var _freeze := false
## 캡처 전에 게임 이벤트를 하나 강제로 발생시킨다. 연출이 '과정'을 갖는지 보려면
## 실제로 그 사건을 일으켜야 한다 (승리/패배/막 클리어/단어 완성).
##   victory / defeat / actclear / wordcomplete
var _event := ""
## 1이면 시작 시 뜬 모달/코치마크를 걷어내지 않는다.
var _keep_ui := false
## Engine.time_scale. 1.0 미만이면 게임이 느리게 돌아 짧은 연출을 여러 프레임에 담을 수 있다.
## 캡처 루프는 PNG 인코딩 때문에 프레임당 수백 ms 가 걸리므로, 0.2초짜리 애니메이션은
## 실시간으로는 두 프레임 사이에 통째로 들어가 버린다 — 그러면 "즉시 사라짐"과 구분이 안 된다.
var _slowmo := 1.0
## 이 캡처 프레임 번호에서 첫 번째 적을 처치한다. -1 이면 안 죽인다.
## 이벤트로 미리 죽이면 follow 크롭이 위치를 못 잡으므로, 앞 프레임에서 적을
## 따라가며 위치를 확보한 뒤 죽이는 방식이 필요하다.
var _killat := -1
## 지정 프레임에 첫 번째 적에게 줄 피해량. 0 이면 안 준다.
## 타워 사거리에 의존하면 지형 운에 따라 "피해가 아예 안 들어가는" 일이 생긴다
## (실제로 그렇게 두 번 헛돌았다). 피해량을 직접 주면 재현이 완전히 결정적이다.
var _hitat := -1
var _hitdamage := 0.0
## hitat 이 줄 피해에 적용할 '속성 배율'. 1.0 이 아니면 적이 그 타격을
## 약점/내성으로 분류해 피해 숫자에 이름을 붙인다 (EnemyUnit._hit_kind).
## 배율을 직접 주는 이유는 hitdamage 와 같다 — 타워 특성에 맡기면
## "그 타워가 그 적을 때렸는가" 가 지형·타이밍 운에 좌우된다.
var _hitmult := 1.0
## hitat 이 때릴 적의 번호. 0 = 첫 번째.
## act1 명단은 [슬라임 normal, 박쥐 swift, 멧돼지 armored, 고블린 swarm, 덩굴 regen]
## 순서라, 번호만 바꾸면 상성 케이스를 전부 짚을 수 있다.
var _hitidx := 0
## hitat 이 줄 피해를 **치명타로** 표시할지. `take_damage` 의 `is_crit` 로 들어간다.
## 굴림(`attack_target`)에 맡기면 "이 프레임에 치명타가 났는가" 가 운이 되므로 직접 준다.
var _hitcrit := false
## 이 프레임에 _slowidx 번 적에게 감속을 건다. -1 이면 안 건다.
var _slowat := -1
var _slowidx := 0
## 적을 경로의 몇 % 지점에 세울지 (0.0 ~ 1.0). 기본 0.30.
## 타워 발판은 경로 앞쪽에 몰려 있어서, 0.30 은 사거리 밖인 경우가 많다.
## 타워가 실제로 쏘게 하려면 이 값을 낮춰야 한다.
var _at := 0.30
## 1이면 캡처 전에 "타워가 적을 사거리에 두고 있는가"를 숫자로 찍는다.
## 타워가 안 쏘는 이유는 대개 (a) 사거리 밖 (b) trait 이 orbit 이라 타워가 안 쏨
## (c) 타워가 아예 안 세워짐 셋 중 하나인데, 화면만 봐서는 구분이 안 된다.
var _diag := false
## 이 캡처 프레임에서 모든 타워를 강제로 발사시킨다. -1 이면 안 쏜다.
##
## 타워의 attack_interval(0.8초)에 맡기면 "발사가 캡처 창 안에 걸리는가"가
## 순전히 운이 된다. 특히 slowmo 를 걸면 게임 시간이 느려져서 첫 발까지
## 수백 프레임이 걸린다. 발사 시점을 직접 정하면 재현이 완전히 결정적이다.
var _fireat := -1
## follow 모드에서 적이 죽어도 마지막 위치를 유지한다 (사망 순간을 놓치지 않으려고).
var _last_follow := Vector2(-1.0, -1.0)
var _out := "E:/project/word_card/_strip/f"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("act="): _act = int(a.split("=")[1])
		elif a.begins_with("towers="): _towers = a.split("=")[1]
		elif a.begins_with("monsters="): _monsters = int(a.split("=")[1])
		elif a.begins_with("boss="): _boss = int(a.split("=")[1]) != 0
		elif a.begins_with("warmup="): _warmup = int(a.split("=")[1])
		elif a.begins_with("frames="): _frames = int(a.split("=")[1])
		elif a.begins_with("every="): _every = int(a.split("=")[1])
		elif a.begins_with("crop="): _crop = a.split("=")[1]
		elif a.begins_with("follow="): _follow = int(a.split("=")[1]) != 0
		elif a.begins_with("freeze="): _freeze = int(a.split("=")[1]) != 0
		elif a.begins_with("event="): _event = a.split("=")[1]
		elif a.begins_with("keepui="): _keep_ui = int(a.split("=")[1]) != 0
		elif a.begins_with("diag="): _diag = int(a.split("=")[1]) != 0
		elif a.begins_with("fireat="): _fireat = int(a.split("=")[1])
		elif a.begins_with("slowmo="): _slowmo = float(a.split("=")[1])
		elif a.begins_with("killat="): _killat = int(a.split("=")[1])
		elif a.begins_with("hitat="): _hitat = int(a.split("=")[1])
		elif a.begins_with("hitdamage="): _hitdamage = float(a.split("=")[1])
		elif a.begins_with("hitmult="): _hitmult = float(a.split("=")[1])
		elif a.begins_with("hitidx="): _hitidx = int(a.split("=")[1])
		elif a.begins_with("hitcrit="): _hitcrit = int(a.split("=")[1]) != 0
		elif a.begins_with("slowat="): _slowat = int(a.split("=")[1])
		elif a.begins_with("slowidx="): _slowidx = int(a.split("=")[1])
		elif a.begins_with("at="): _at = float(a.split("=")[1])
		elif a.begins_with("follow_size="): _follow_size = int(a.split("=")[1])
		elif a.begins_with("scale="): _scale = int(a.split("=")[1])
		elif a.begins_with("out="): _out = a.split("=")[1]

	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())

	var main = load("res://scenes/TowerDefenseMain.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var field = main.get_node_or_null("VBox/FieldContainer/DefenseField")
	if field == null:
		field = main.find_child("DefenseField", true, false)

	# 모달/코치마크를 걷어내고 게임 화면만 남긴다.
	# keepui=1 이면 걷어내지 않는다 — 시작 시 뜨는 코치마크처럼 '게임이 스스로 띄운'
	# UI 를 검증할 때 필요하다.
	for i in range(6):
		await get_tree().process_frame
	var layer = main.get_node_or_null("ModalLayer")
	if layer and not _keep_ui:
		for child in layer.get_children():
			layer.remove_child(child)
			child.queue_free()

	if field:
		field.set_act(_act)
		main._update_topbar_wave_label(_act, field.current_wave)
		main._update_next_round_preview()

	if _towers != "" and field:
		var parsed: Array = []
		for c in _towers.split(","):
			parsed.append({"syllable": c, "word_data": WordDatabase.get_word_data(c)})
		# 발판은 MAX_UNLOCKED_SLOTS 개뿐이다. 넘겨서 넘기면
		# update_towers_from_parsed_list 가 tower_positions 밖을 인덱싱해
		# "Out of bounds get index" 로 죽는다(그러면 타워가 하나도 안 세워진 채
		# 도구가 계속 돌아서, 원인 모를 '아무 일도 안 일어남' 으로 보인다).
		if parsed.size() > field.MAX_UNLOCKED_SLOTS:
			print("!! towers 를 %d개 요청했지만 발판은 %d개뿐 — 앞의 %d개만 세운다" % [
				parsed.size(), field.MAX_UNLOCKED_SLOTS, field.MAX_UNLOCKED_SLOTS])
			parsed = parsed.slice(0, field.MAX_UNLOCKED_SLOTS)
		field.unlocked_slot_count = maxi(field.unlocked_slot_count, parsed.size())
		field.update_towers_from_parsed_list(parsed)

	if field and (_boss or _monsters > 0):
		field.spawn_queue.clear()
		field.is_wave_running = true
		var act_scale: float = 1.0 + (_act - 1) * 0.5
		# field 는 untyped Node → 동적 호출 결과가 Variant. `:=` 로 받으면 추론 실패.
		var base_hp: float = (10.0 + _act * 4.0) * field.hp_compensation_for(_act, 5)
		for i in range(_monsters):
			field._spawn_enemy(MonsterRoster.regular_entry(_act, i, base_hp, 1.0, act_scale))
		if _boss:
			field._spawn_enemy(MonsterRoster.boss_entry(_act, 5, base_hp, 1.0, act_scale, 5))
		var curve = field.path_2d.curve if field.path_2d else null
		var curve_len: float = curve.get_baked_length() if curve != null else 0.0
		var enemies: Array = field.get_enemies()
		for i in range(enemies.size()):
			# 적을 사거리 안쪽 좁은 구간에 모아 둔다 — 타워가 곧바로 때리기 시작한다.
			enemies[i].progress = curve_len * (_at + 0.10 * float(i) / maxf(1.0, float(enemies.size() - 1)))
			if _freeze:
				enemies[i].speed = 0.0

	if _event != "":
		match _event:
			"victory": main._on_game_over(true)
			"defeat": main._on_game_over(false)
			"actclear": main._on_act_cleared(_act, 25)
			"tiledraft": main._show_tile_draft(false)
			"shop":
				main._open_relic_shop()
				# 상점은 이제 유물만 판다. 자모 진열대/덱 압축 칸은 씬에서 `visible = false`
				# 로 시작해 어느 코드도 켜지 않았고, 아무도 못 보는 위젯을 매 갱신마다
				# 만들고 있었다 — 완전히 지웠다. 여기서는 남은 칸이 실제로 보이는지만 본다.
				if _diag:
					_dump_shop(main)
			"towerinfo":
				# 타워 정보 모달을 연다. '활성 시너지' 줄이 제대로 그려지는지 확인하는
				# 경로다. 첫 번째 살아 있는 타워를 쓰므로 towers= 로 순서를 정해야 한다.
				#
				# 참고: neodgm.ttf 자체에는 ⚡💥🔗 같은 글리프가 없다(실측 — 1F300~1FAFF
				# 구간 0개). 그런데도 화면에는 나온다. Godot 이 OS 폰트(Windows: Segoe UI
				# Emoji)로 대체해 주기 때문이다. PIL 로 같은 문자열을 그리면 두부가 나오는데,
				# 그건 PIL 에 대체 폰트가 없어서지 Godot 의 문제가 아니다.
				var tw: Array = field.active_towers if field else []
				if tw.size() > 0 and is_instance_valid(tw[0]):
					main._on_tower_info_requested(tw[0])
				else:
					print("!! towerinfo: 살아 있는 타워가 없다 — towers= 로 먼저 세워라")
			"lore": main._on_lore_pressed()
			"volume": main._show_volume_settings()
			"coach":
				# 앵커 모드 코치마크. 저장 파일이 있으면 자동으로는 안 뜨므로 강제로 띄운다.
				var belt2 = main.find_child("JamoBelt", true, false)
				main._run_coachmark([{
					"title": "1 / 3  ·  활자를 모으세요",
					"body": "벨트의 [자음 구매] / [모음 구매]로 활자를 얻어\n아래 3개 슬롯 중 한 곳에 끌어다 놓습니다.",
					"anchor": belt2,
				}], 0)
			"wordcomplete":
				var belt = main.find_child("JamoBelt", true, false)
				# _celebrate_new_words 는 Array[String] 을 받는다. 무타입 배열을 넘기면
				# "does not have the same element type" 로 죽는다.
				var words: Array[String] = ["개구리"]
				if belt: belt._celebrate_new_words(words)
			"kill":
				# 첫 번째 적을 확실히 처치한다. 타워 사거리에 의존하지 않으므로
				# 사망 연출 검증이 지형 운에 좌우되지 않는다.
				var es: Array = field.get_enemies() if field else []
				if es.size() > 0 and is_instance_valid(es[0]):
					es[0].take_damage(99999.0, false)
					print("KILL 발동 — hp=", es[0].hp, " dead=", es[0].is_dead)

	# 모달의 **실제 사각형**을 숫자로 찍는다. 픽셀 눈대중보다 훨씬 정확하고,
	# "중앙 정렬됐는가"를 (1280-w)/2 와 직접 비교할 수 있다.
	_dump_modals("직후", layer)
	print("time_scale=", Engine.time_scale)

	if _diag:
		_dump_combat(field)

	# 슬로모는 이벤트 발생 **뒤**에 건다. 이벤트 자체(모달 등장 트윈)도 느려져야
	# 등장 과정을 프레임에 담을 수 있기 때문이다.
	if _slowmo != 1.0:
		Engine.time_scale = _slowmo
		print("SLOWMO time_scale=", _slowmo)

	print("STRIP_READY enemies=", field.get_enemies().size() if field else -1)

	for i in range(_warmup):
		await get_tree().process_frame

	_dump_modals("warmup 후", layer)

	var _t_prev := Time.get_ticks_msec()
	for n in range(_frames):
		for k in range(_every):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		# 캡처 루프가 실제로 몇 ms 걸리는지 남긴다. 이 값이 연출 길이보다 크면
		# 그 연출은 프레임 사이에 통째로 숨어서 "즉시 사라짐"과 구분되지 않는다.
		var _t_now := Time.get_ticks_msec()
		var _dt_ms := _t_now - _t_prev
		_t_prev = _t_now
		var img := get_viewport().get_texture().get_image()

		# 지정 프레임에서 적을 처치한다.
		# 주의: 위의 get_image() 는 **이미 그려진** 프레임을 읽으므로, 여기서 죽이면
		# 효과는 다음 캡처 프레임(n+1)부터 찍힌다. 그래서 killat 은 "마지막 생존 프레임"
		# 번호라고 생각하는 게 맞다.
		if _killat >= 0 and n == _killat and field:
			var victims: Array = field.get_enemies()
			if victims.size() > 0 and is_instance_valid(victims[0]):
				victims[0].take_damage(99999.0, false)
				print("KILL@F%03d 발동 dead=%s" % [n, str(victims[0].is_dead)])

		# 투사체의 위치와 회전각을 숫자로 찍는다.
		# "회전 연출이 살아 있는가"는 이미지로는 판정이 거의 불가능하다 — 32px 스프라이트가
		# 프레임마다 30도씩 돌아도 정지 이미지 여러 장에서는 "그냥 동그란 것"으로 보인다.
		# rotation 값의 단조 증가를 보면 한 줄로 끝난다.
		if _diag and field and field.projectiles_layer:
			for pr in field.projectiles_layer.get_children():
				if pr is Projectile:
					print("F%03d PROJ pos=%s rot=%.3f spin=%.1f scale=%s" % [
						n, str(pr.global_position), pr.sprite.rotation if pr.sprite else -99.0,
						pr.spin_speed, str(pr.sprite.scale if pr.sprite else Vector2.ZERO)])

		# 지정 프레임에 강제 발사. attack_interval 에 맡기면 발사 시점이 운이 된다.
		if _fireat >= 0 and n == _fireat and field:
			var fired := 0
			for t in field.active_towers:
				if not is_instance_valid(t):
					continue
				var tg = t.find_target()
				if tg != null:
					t.attack_target(tg)
					fired += 1
			print("FIRE@F%03d 발사한 타워=%d" % [n, fired])

		# 지정 프레임에 정해진 피해. HP 바가 즉시 튀는지 따라가는지 재는 데 쓴다.
		# hitmult 를 주면 그 배율이 그대로 적에게 전달되어 피해 숫자에
		# '약점'/'내성' 이 붙는다 — 상성 표현을 눈이 아니라 숫자로 확인하는 경로다.
		if _hitat >= 0 and n == _hitat and _hitdamage > 0.0 and field:
			var tars: Array = field.get_enemies()
			if tars.size() > _hitidx and is_instance_valid(tars[_hitidx]):
				var victim = tars[_hitidx]
				var dealt: float = victim.take_damage(_hitdamage, false, _hitmult, false, _hitcrit)
				print("HIT@F%03d idx=%d name=%s mult=%.2f crit=%s kind=%s dealt=%.1f hp=%.1f" % [
					n, _hitidx, victim.enemy_name, _hitmult, str(_hitcrit),
					victim._hit_kind(dealt, _hitmult, _hitcrit), dealt, victim.hp])

		# 지정 프레임에 감속. 제어 타워를 세우지 않고도 감속 표현(파란 기운 + ❄ 배지)을
		# 확인한다 — 타워에 맡기면 "그 타워가 그 적을 때렸는가" 가 운에 좌우된다.
		if _slowat >= 0 and n == _slowat and field:
			var sars: Array = field.get_enemies()
			if sars.size() > _slowidx and is_instance_valid(sars[_slowidx]):
				var sv = sars[_slowidx]
				sv.apply_slow(0.5, 3.0)
				print("SLOW@F%03d idx=%d name=%s attrs=%s immune=%s factor=%.2f modulate=%s badge=%s" % [
					n, _slowidx, sv.enemy_name, str(sv.attrs), str(sv.slow_immune),
					sv.slow_factor, str(sv.sprite.modulate if sv.sprite else Color.WHITE),
					str(sv._slow_badge.text) if sv._slow_badge else "-"])

		# crop 사각형을 정한다. follow=1 이면 매 프레임 적을 다시 조준한다.
		var cx := -1
		var cy := -1
		var cw := 0
		var ch := 0
		if _follow:
			var es: Array = field.get_enemies() if field else []
			if es.size() > 0 and is_instance_valid(es[0]):
				# 캔버스 변환까지 반영된 좌표여야 뷰포트 픽셀과 맞는다.
				var c: Vector2 = es[0].get_global_transform_with_canvas().origin
				_last_follow = c
			if _last_follow.x >= 0.0:
				var half: int = _follow_size / 2
				cw = _follow_size
				ch = _follow_size
				cx = clampi(int(_last_follow.x) - half, 0, maxi(0, img.get_width() - cw))
				cy = clampi(int(_last_follow.y) - half, 0, maxi(0, img.get_height() - ch))
		elif _crop != "":
			var parts := _crop.split(",")
			if parts.size() == 4:
				cx = int(parts[0]); cy = int(parts[1])
				cw = int(parts[2]); ch = int(parts[3])

		if cx >= 0 and cw > 0 and ch > 0:
			# 뷰포트 크기와 다를 수 있으므로 실제 이미지 기준으로 클램프한다.
			cw = mini(cw, img.get_width() - cx)
			ch = mini(ch, img.get_height() - cy)
			if cw > 0 and ch > 0:
				img = img.get_region(Rect2i(cx, cy, cw, ch))
				if _scale > 1:
					img.resize(img.get_width() * _scale, img.get_height() * _scale,
						Image.INTERPOLATE_LANCZOS)
		var path := "%s_%03d.png" % [_out, n]
		img.save_png(path)
		# 적 상태를 함께 찍는다 — 이미지만 보면 "안 맞고 있는 것"과 "맞는데 안 죽는 것"을
		# 구분할 수 없다. HP/실드/사망여부를 프레임마다 남겨 두면 원인이 바로 보인다.
		if field:
			var cur: Array = field.get_enemies()
			if cur.size() > 0 and is_instance_valid(cur[0]):
				var e = cur[0]
				print("F%03d dt=%dms hp=%.1f/%.1f shield=%.1f bar=%.1f dead=%s scale=%s alpha=%.2f pos=%s speed=%.1f prog=%.1f" % [
					n, _dt_ms, e.hp, e.max_hp, e.shield,
					(e.hp_bar.value if e.hp_bar else -1.0), str(e.is_dead),
					str(e.sprite.scale if e.sprite else Vector2.ZERO),
					(e.sprite.modulate.a if e.sprite else -1.0),
					str(e.global_position), e.speed, e.progress])
			else:
				print("F%03d dt=%dms <적 없음>" % [n, _dt_ms])
		# 진행 상황을 파일로 남긴다 — 파이프로 tail 하면 프로세스가 끝날 때까지 안 보인다.
		if n == 0 or n == _frames - 1:
			print("STRIP ", n + 1, "/", _frames, " -> ", path)
	print("STRIP_DONE ", _frames, " frames")
	# 마지막 프레임 시점의 적 상태. 감속 만료나 배지 숨김처럼 "시간이 지나야
	# 일어나는 일" 은 캡처 직전 숫자로만 확인할 수 있다.
	if _diag and field:
		_dump_enemies("END", field)
	# 레이어에 무엇이 남았는지 센다. 매 타격마다 임팩트 노드를 만들므로,
	# 해제가 새면 여기서 수백 개로 불어난다 — 프레임만 봐서는 안 보인다.
	# Line2D 를 따로 세는 이유: 특성별 타격(blast/streak/ricochet)은 전부 Line2D 다.
	# 예전에는 Sprite2D 만 세어서 이것들이 전부 other 로 뭉뚱그려졌고,
	# '모양 효과가 새는지' 를 이 카운터로는 증명할 수 없었다.
	if field and field.projectiles_layer:
		var proj_n := 0
		var fx_n := 0
		var shape_n := 0
		var other_n := 0
		for ch in field.projectiles_layer.get_children():
			if ch is Projectile:
				proj_n += 1
			elif ch is Line2D:
				shape_n += 1
			elif ch is Sprite2D:
				fx_n += 1
			else:
				other_n += 1
		print("LEFTOVER projectiles=%d impacts=%d shapes=%d other=%d" % [proj_n, fx_n, shape_n, other_n])
	get_tree().quit()


## "왜 타워가 안 쏘는가" 를 숫자로 좁힌다.
## 화면만 보면 ① 타워가 안 세워짐 ② 사거리 밖 ③ orbit 이라 타워가 안 쏨
## ④ 투사체가 빗나감 이 전부 "아무 일도 안 일어남" 으로 똑같이 보인다.
func _dump_combat(field) -> void:
	if field == null:
		print("DIAG field=NULL")
		return
	var towers: Array = field.active_towers if "active_towers" in field else []
	print("DIAG 타워 %d개" % towers.size())
	var enemies: Array = field.get_enemies()
	for t in towers:
		if not is_instance_valid(t):
			continue
		var near := -1.0
		for e in enemies:
			if is_instance_valid(e) and not e.is_dead:
				var d: float = t.global_position.distance_to(e.global_position)
				if near < 0.0 or d < near:
					near = d
		print("DIAG tower syl=%s trait=%s pos=%s range=%.1f interval=%.2f proj=%s | 최근접 적 dist=%.1f 사거리내=%s" % [
			t.syllable, t.trait_id, str(t.global_position), t.attack_range, t.attack_interval,
			t.attack_proj_type, near, str(near >= 0.0 and near <= t.attack_range)])
	for e in enemies:
		if is_instance_valid(e):
			print("DIAG enemy hp=%.1f pos=%s progress=%.1f speed=%.1f" % [
				e.hp, str(e.global_position), e.progress, e.speed])
	_dump_enemies("START", field)


## 적 하나하나의 attrs/감속/배지 상태를 찍는다.
## 감속은 '속도가 조용히 바뀌는' 변화라 이미지 한 장으로는 "느려졌는가" 를 판정할 수
## 없다 — modulate 와 배지 문자열이 유일한 판정 근거다.
func _dump_enemies(tag: String, field) -> void:
	if field == null:
		return
	var enemies: Array = field.get_enemies()
	print("ENEMIES[%s] %d마리" % [tag, enemies.size()])
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var badge := "-"
		if e._slow_badge != null:
			badge = "%s%s" % [e._slow_badge.text, "(보임)" if e._slow_badge.visible else "(숨김)"]
		# 감속은 sprite.modulate 가 아니라 전용 셰이더의 status_amount 로 표현된다
		# (modulate 는 채널을 깎을 뿐이라 초록 적을 파랗게 못 만든다).
		var veil := "-"
		if e._slow_material != null:
			veil = "%.2f" % float(e._slow_material.get_shader_parameter("status_amount"))
		print("  ENEMY[%s] name=%s attrs=%s slow=%.2f/t%.2f veil=%s badge=%s" % [
			tag, e.enemy_name, str(e.attrs), e.slow_factor, e.slow_timer, veil, badge])


## 상점 모달이 '약속한 3칸'을 실제로 보여주는지 숫자로 찍는다.
## 섹션이 꺼져 있으면 화면에는 그냥 빈 공간이라 눈으로는 판정할 수 없다.
func _dump_shop(main: Node) -> void:
	var sm = main.get("shop_modal")
	if sm == null or not is_instance_valid(sm):
		print("SHOP 모달 없음")
		return
	for sec in ["SectionRelics"]:
		var n: Node = sm.find_child(sec, true, false)
		if n == null:
			print("SHOP %-14s 없음" % sec)
			continue
		# 섹션 = [제목 Label, 그리드] 순서. 그리드 자식 수가 곧 '만들어졌지만 보이는가'의 답.
		var grid: Node = n.get_child(1) if n.get_child_count() > 1 else null
		print("SHOP %-14s visible=%s rect=%s grid자식=%d" % [
			sec, str(n.visible), str(n.get_global_rect().size),
			grid.get_child_count() if grid != null else -1])


## ModalLayer 자식들의 사각형·스케일·알파를 숫자로 찍는다.
## 픽셀 눈대중보다 훨씬 정확하고, "중앙 정렬됐는가"를 (1280-w)/2 와 직접 비교할 수 있다.
func _dump_modals(tag: String, layer: Node) -> void:
	if layer == null:
		return
	for c in layer.get_children():
		if c is Control:
			var r: Rect2 = c.get_global_rect()
			# rect_size(스케일 반영)와 local_size(미반영)를 따로 찍는다. 둘을 헷갈리면
			# "트윈이 안 끝났다"고 오진하게 된다.
			print("MODAL[%s] name=%s pos=%s rect_size=%s local_size=%s scale=%s alpha=%.2f center=%s pivot=%s" % [
				tag, c.name, str(r.position), str(r.size), str(c.size), str(c.scale),
				c.modulate.a, str(r.get_center()), str(c.pivot_offset)])
