extends Node
## §2.21 (§5.2 33 (A)) — '치명타' 가 이제 **한 사건**이다. 이 프로브가 그 계약을 지킨다.
##
## ## 고치기 전 (2026-10-01 이전)
##
## `WordTower.attack_target()` 는 `damage *= CRIT_DAMAGE_MULT` 를 하고 **그 사실을 버렸다**.
## `EnemyUnit._hit_kind()` 는 `dealt >= 60.0` 을 `"crit"` 이라고 불렀다 — 굴림과 무관한 임계다.
## 그래서 한 이름이 **두 사건**을 가리켰고, 화면에는 하나만 나왔다:
##   (A) 진짜 치명타가 안 보인다 — 약한 타워의 치명타는 60 에 못 닿아 평범한 흰 숫자였다.
##   (B) 치명타가 아닌 것이 치명타처럼 보인다 — 60 을 넘으면 무조건 금색 26px 이었다.
## 실측(당시): 33조합 중 **31개**가 (A) 였다.
##
## ## 고친 뒤 — 이 프로브가 지키는 계약
##
##   · `is_crit` 가 `WordTower` → `Projectile` → `take_damage` → `_hit_kind` 로 내려온다
##   · `_hit_kind` 우선순위: **방어도 > 약점 > 내성 > 치명타 > 큰 한 방 > 보통**
##   · `Juice` 에 `crit`(브랜드 보라 28px)과 `big`(금색 26px)이 **다른 색**으로 공존한다
##   · `Juice` 의 `_` 분기에 피해량 임계가 **없다**(옛 60 검사는 도달 불가였다)
##
## ⚠️ **이 파일의 극성을 뒤집었다.** 예전 판은 *고치기 전* 상태를 단언했다
##    (`style_threshold == 60.0`, `invisible > 0`). 고침이 들어왔으므로 이제 반대를 단언한다 —
##    `BossDeathProbe` 와 같은 규약이다. 그래서 K2/K3/K8 주입이 **이전에는 초록이었고
##    지금은 빨강**이다(그게 정상이다).
##
## ## ✅ 유성·선회의 구멍도 닫혔다 (2026-10-01, §2.21-6)
##
## 예전 판은 이 자리에 *"재지 않는 것 — 유성·선회는 여전히 굴림에 도달하지 않는다"* 라고
## 적어 두고, S8 이 `Meteor.gd`·`TowerOrbit.gd` 의 `is_crit` 개수가 **0** 임을 단언했다.
## 그것이 구멍의 기록이었다 — 유물 `예리한 렌즈`(35 G)의 *"타워 공격 시 25% 확률로 2배
## 치명타"* 가 그 두 특성에서 **거짓**이었다.
##
## **감독이 "남은것 모두 수행" 으로 위임했고, 고쳤다.** 굴림을 `WordTower.roll_crit()` 한 곳으로
## 빼서 **세 경로(조준·유성·선회)가 같은 문을 지난다.** 그래서 S8 의 극성이 뒤집혔고
## (§9 의 *"굴리는 곳은 한 곳"* 은 그대로 참이다 — 오히려 그 단언이 이제 **의미를 갖는다**),
## 세 경로 각각이 `roll_crit()` 을 부르는지까지 S8 이 잰다.
##
## ⚠️ **밸런스 변경이 아니다** — 25%·2배의 기대 배수는 `1 + 0.25 × (2−1) = 1.25` 로
## 굴림 횟수와 무관하다. 유성·선회만 이 1.25 배를 못 받고 있었다.
##
## ## 주입으로 반증했다 (2026-10-01)
##
## K1 `_hit_kind` 의 `if is_crit: return "crit"` 삭제            → S1·S3
## K2 `Juice` 의 `crit` 색 → `big` 과 같은 금색                  → S5·S7
## K3 `_hit_kind` 의 `big` 임계 제거(`return "normal"`)          → S1
## K4 상성 분기를 치명타 **뒤로** 옮긴다                          → S1
## K5 `Projectile.hit_target` 이 `is_crit` 을 안 넘긴다           → S8
## K6 `WordTower` 가 `is_crit` 대신 `false` 를 넘긴다             → S8
## K7 `Juice` 의 `crit` 접두어 → `"치명타 "`                      → S5
## K8 `_hit_kind` 의 `big` → `"crit"` (이름 재통합)               → S1
## K9 `Juice` 의 `_` 분기에 60 임계를 되살린다                    → S0
## K10 `take_damage` 가 `is_crit` 을 `_damage_kind` 에 안 넘긴다  → S6

const PREFIX := "CRIT_SIGNAL"

## ⚠️ `EnemyUnit.new()` 로 만들면 `@onready var sprite := $Sprite` 가 **`Node not found` 오류**를
##    낸다(장면 없이 스크립트만 붙이므로 자식이 없다). 순수 함수(`_hit_kind`)만 부를 때는
##    무해하지만, 라벨을 읽으려고 트리에 넣으면 그 오류가 로그에 남는다 — 프로브가
##    로그를 더럽히면 "오류 0줄" 이라는 인수 조건 자체가 무의미해진다. 그래서 **장면**을 쓴다.
const EnemyUnitScene = preload("res://scenes/tower/EnemyUnit.tscn")

## `Juice.damage_style` 의 `normal` 크기. 임계가 **없다**는 것을 재는 기준값이다.
## ⚠️ 계산에 쓰지 않는다 — S0 이 실제 값을 **재서** `measured_threshold` 로 넘긴다.
##    상수를 그대로 계산에 쓰면 "재는 대상" 이 아니라 "내가 적어 넣은 수" 를 재게 된다.
const EXPECTED_PLAIN_SIZE := 18

var failures := 0
## S0 이 `Juice.damage_style` 을 훑어 **찾아낸** 크기 임계. 없으면 -1.
var measured_threshold := -1.0


func check(cond: bool, msg: String, tag: int) -> void:
	if not cond:
		failures += 1
		print("FAIL_SECTION S%d :: %s" % [tag, msg])
		push_error("S%d %s" % [tag, msg])


# ── 화면에 실제로 만들어진 피해 숫자를 읽는다 ────────────────────────────────
# `_hit_kind` 를 직접 부르지 않는다 — **플레이어가 보는 것**을 재야 하므로
# `take_damage()` 를 태우고 그 결과 라벨의 색·크기·글자를 읽는다(§2.21 S6).
func _number_ids() -> Dictionary:
	var out := {}
	for n in get_tree().get_nodes_in_group("damage_numbers"):
		out[n.get_instance_id()] = true
	return out


func _added_numbers(before: Dictionary) -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("damage_numbers"):
		if not before.has(n.get_instance_id()):
			out.append(n)
	return out


## 한 대 때리고, 그때 화면에 뜬 숫자 라벨을 돌려준다.
## `pool_numbers = false` 라 **동기적으로** 라벨이 만들어진다(프레임을 넘기지 않는다).
## ⚠️ hp 를 매번 크게 되돌린다 — 안 그러면 큰 피해가 `_die()` 를 태워 라벨 대신 사망 연출이 난다.
func _hit(e: EnemyUnit, amount: float, mult: float, is_crit: bool) -> Dictionary:
	e.shield = 0.0
	e.hp = 1000.0
	e.max_hp = 1000.0
	e.is_dead = false
	var before := _number_ids()
	e.take_damage(amount, false, mult, false, is_crit)
	var added := _added_numbers(before)
	var style := {}
	if not added.is_empty():
		var lb: Label = added[added.size() - 1]
		style = {
			"text": lb.text,
			"size": lb.get_theme_font_size("font_size"),
			"color": lb.get_theme_color("font_color"),
		}
	return {"labels": added.size(), "style": style}


## `res://scripts` 를 재귀적으로 훑어 `needle` 이 나오는 **파일별** 횟수를 센다.
## 소스 텍스트를 읽는 이유: 배선 여부를 **런타임 호출로 재면 이 프로브 자신이 호출처가 된다.**
func _scan_source(dir_path: String, needle: String, hits: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			_scan_source(full, needle, hits)
		elif name.ends_with(".gd"):
			var text := FileAccess.get_file_as_string(full)
			var n := text.count(needle)
			if n > 0:
				hits[name] = n
		name = dir.get_next()
	dir.list_dir_end()


func _ready() -> void:
	var probe := EnemyUnit.new()

	# ── S0. `Juice` 의 `normal` 크기는 **피해량과 무관하다** — 임계가 사라졌다 ─────
	#   고치기 전에는 60 에서 18→22 로 바뀌었다(그리고 그 22px 은 **도달 불가**였다 —
	#   `_hit_kind` 가 `normal` 에 dealt<60 을 보장하므로). 이제 임계 자체가 없다.
	var prev_size := int(Juice.damage_style(0.0, "normal")["size"])
	var a0 := 0.0
	while a0 <= 300.0:
		var sz := int(Juice.damage_style(a0, "normal")["size"])
		if sz != prev_size:
			measured_threshold = a0
			break
		a0 += 0.5
	var plain_0 := Juice.damage_style(0.0, "normal")
	var plain_hi := Juice.damage_style(9999.0, "normal")
	print("%s plain_size measured_threshold=%.1f | size@0=%d size@9999=%d"
		% [PREFIX, measured_threshold, int(plain_0["size"]), int(plain_hi["size"])])
	check(measured_threshold == -1.0,
		"`Juice` 의 'normal' 크기에 임계가 **남아 있다**(측정 %.1f) — 옛 60 검사가 되살아났다"
			% measured_threshold, 0)
	check(int(plain_0["size"]) == EXPECTED_PLAIN_SIZE
			and int(plain_hi["size"]) == EXPECTED_PLAIN_SIZE,
		"'normal' 크기는 피해량과 무관하게 %d 이다" % EXPECTED_PLAIN_SIZE, 0)

	# ── S1. `_hit_kind` 의 우선순위 — 방어도 > 약점 > 내성 > 치명타 > 큰 한 방 ────
	var k_under: String = probe._hit_kind(59.9, 1.0, false)
	var k_at: String = probe._hit_kind(60.0, 1.0, false)
	var k_huge: String = probe._hit_kind(200.0, 1.0, false)
	var k_tiny_crit: String = probe._hit_kind(1.0, 1.0, true)
	var k_weak_crit: String = probe._hit_kind(200.0, 1.6, true)
	var k_resist_crit: String = probe._hit_kind(200.0, 0.65, true)
	var k_weak_plain: String = probe._hit_kind(200.0, 1.6, false)
	print("%s kinds under=%s at=%s huge=%s | tiny_crit=%s weak_crit=%s resist_crit=%s weak_plain=%s"
		% [PREFIX, k_under, k_at, k_huge, k_tiny_crit, k_weak_crit, k_resist_crit, k_weak_plain])
	check(k_under == "normal" and k_at == "big" and k_huge == "big",
		"임계(60)는 이제 '큰 한 방'(big) 이다 — 59.9=normal / 60.0=big / 200=big", 1)
	# ★ (A) 의 핵심 — **작은 치명타도 보인다.** 고치기 전에는 이 조합이 'normal' 이었다.
	check(k_tiny_crit == "crit",
		"1 피해짜리 치명타도 'crit' 이다 — (A) 의 핵심. 고치기 전에는 'normal' 이었다", 1)
	# ★ 결정 1 — 상성이 치명타를 **이긴다**.
	check(k_weak_crit == "weak",
		"약점 타격의 치명타는 'weak' 이다 — 상성이 사건보다 먼저다(§2.21 결정 1)", 1)
	check(k_resist_crit == "resist", "내성 타격의 치명타는 'resist' 이다", 1)
	check(k_weak_plain == "weak", "약점 타격은 치명타가 아니어도 'weak' 이다", 1)

	# ── S2. 유물·시너지 없이는 60 에 닿지 못한다 — 'big' 은 유물의 영역이다 ──────
	var crit_mult: float = WordTower.CRIT_DAMAGE_MULT
	var big_threshold: float = EnemyUnit.BIG_HIT_THRESHOLD
	print("%s crit_damage_mult=%.2f big_threshold=%.1f" % [PREFIX, crit_mult, big_threshold])
	check(crit_mult > 1.0,
		"치명타는 피해를 늘린다 (배수 %.2f) — 상점 문구 '2배' 의 근거" % crit_mult, 2)

	# ⚠️ **상수를 읽는 것만으로는 부족하다.** `crit_damage()` 가 그 상수를 **안 써도**
	#    위 단언은 통과한다 — §2.21-6 의 K2 가 밟은 함정(*"재는 대상이 상수가 아니라
	#    내가 적어 넣은 수"*)과 **같은 부류**다. 그래서 함수에 **직접 물어본다**.
	#    (이 검사가 없으면 `crit_damage()` 를 `return damage` 로 되돌려도 전부 초록이었다.)
	var probe_tower := WordTower.new()
	var crit_out := probe_tower.crit_damage(10.0, true)
	var plain_out := probe_tower.crit_damage(10.0, false)
	probe_tower.free()
	print("%s crit_damage 10.0 → crit=%.2f plain=%.2f (기대 %.2f / 10.00)"
		% [PREFIX, crit_out, plain_out, 10.0 * crit_mult])
	check(is_equal_approx(crit_out, 10.0 * crit_mult),
		"`crit_damage(10, true)` 가 %.2f 다 (기대 %.2f) — 굴림이 피해에 안 곱해진다"
			% [crit_out, 10.0 * crit_mult], 2)
	check(is_equal_approx(plain_out, 10.0),
		"`crit_damage(10, false)` 가 %.2f 다 (기대 10.00) — 치명타가 아닌데 배수가 붙는다"
			% plain_out, 2)

	var traits: Array = WordTower.TRAIT_NAMES.keys()
	var lens: Array = WordTower.BASE_DAMAGE_BY_LENGTH
	var best := 0.0
	var best_label := ""
	for t in traits:
		for l in range(1, lens.size() + 1):
			var base: float = float(lens[l - 1]) * 1.25
			var d: float = base * WordTower.trait_damage_multiplier(str(t))
			if d > best:
				best = d
				best_label = "%s %d음절" % [str(t), l]
	print("%s relic_free max_per_hit=%.2f (%s) big_threshold=%.0f"
		% [PREFIX, best, best_label, big_threshold])
	check(best < big_threshold,
		"유물·시너지 없이는 'big' 에 닿지 못한다 (%.2f < %.0f)" % [best, big_threshold], 2)

	# ── S3. 치명타가 **모든 조합에서** 시각적으로 구별되는가 ★ 고침의 목적 ────────
	var total := 0
	var invisible := 0
	var visible := 0
	var samples: Array = []
	for t in traits:
		for l in range(1, lens.size() + 1):
			var base: float = float(lens[l - 1]) * 1.25
			var d: float = base * WordTower.trait_damage_multiplier(str(t))
			var plain: String = probe._hit_kind(d, 1.0, false)
			var crit: String = probe._hit_kind(d, 1.0, true)
			var differs: bool = plain != crit
			total += 1
			if differs:
				visible += 1
			else:
				invisible += 1
				if samples.size() < 3:
					samples.append("%s %d음절 %.2f 둘 다 %s" % [str(t), l, d, plain])
	print("%s crit_visibility total=%d invisible=%d visible=%d | samples=%s"
		% [PREFIX, total, invisible, visible, samples])
	check(invisible == 0,
		"치명타가 통째로 안 보이는 조합이 **하나도 없어야** 한다 (실측 %d/%d)" % [invisible, total], 3)
	check(visible == total, "모든 조합이 구별된다 (%d/%d)" % [visible, total], 3)
	# 대표 사례를 직접 단언한다 — 가장 흔한 타워(1음절 균형).
	var rep_base: float = float(lens[0]) * 1.25
	var rep: float = rep_base * WordTower.trait_damage_multiplier("balanced")
	print("%s rep 1음절 균형 plain=%s crit=%s (%.2f)"
		% [PREFIX, probe._hit_kind(rep, 1.0, false), probe._hit_kind(rep, 1.0, true), rep])
	check(probe._hit_kind(rep, 1.0, false) != probe._hit_kind(rep, 1.0, true),
		"1음절 균형 타워(%.2f)의 치명타가 화면에서 구별된다" % rep, 3)

	# ── S4. `Juice` 의 `_` 분기에 **죽은 코드가 없다** ──────────────────────────
	#   고치기 전에는 `if amount >= 60.0: size = 22` 가 있었고, 유일한 호출자가
	#   `normal` 로만 그 분기에 오므로 **도달 불가**였다(§2.20 의 shield 죽은 분기와 같은 부류).
	var style_lo := Juice.damage_style(0.0, "normal")
	var style_hi := Juice.damage_style(1000.0, "normal")
	print("%s dead_branch size@0=%d size@1000=%d"
		% [PREFIX, int(style_lo["size"]), int(style_hi["size"])])
	check(int(style_lo["size"]) == int(style_hi["size"]),
		"`_` 분기의 크기가 피해량에 따라 달라진다 — 죽은 분기가 되살아났다", 4)

	# ── S5. 접두어 규칙 — 접두어는 **관계** 전용, 색·크기는 **사건** ─────────────
	var crit_style: Dictionary = Juice.damage_style(10.0, "crit")
	var big_style: Dictionary = Juice.damage_style(100.0, "big")
	var weak_style: Dictionary = Juice.damage_style(12.0, "weak")
	var resist_style: Dictionary = Juice.damage_style(12.0, "resist")
	var normal_style: Dictionary = Juice.damage_style(12.0, "normal")
	print("%s prefix crit=\"%s\" big=\"%s\" | weak=\"%s\" resist=\"%s\""
		% [PREFIX, crit_style["prefix"], big_style["prefix"],
			weak_style["prefix"], resist_style["prefix"]])
	check(str(crit_style["prefix"]) == "" and str(big_style["prefix"]) == "",
		"치명타·큰 한 방 숫자에는 단어가 붙지 않는다 — 색·크기뿐이다", 5)
	check(str(weak_style["prefix"]) != "" and str(resist_style["prefix"]) != "",
		"약점·내성에는 단어가 붙는다 — 대조군", 5)
	# ★ 두 사건의 색이 **다르다** — 같으면 §2.19 처럼 다시 한 채널로 뭉친다.
	var c_crit: Color = crit_style["color"]
	var c_big: Color = big_style["color"]
	var c_normal: Color = normal_style["color"]
	print("%s colors crit=%s size=%d | big=%s size=%d | normal=%s size=%d"
		% [PREFIX, str(c_crit), int(crit_style["size"]),
			str(c_big), int(big_style["size"]), str(c_normal), int(normal_style["size"])])
	check(c_crit != c_big,
		"치명타 색과 '큰 한 방' 색이 **같다** — 두 사건이 다시 한 채널로 뭉쳤다", 5)
	check(c_crit != c_normal, "치명타 색이 평범한 숫자와 같다", 5)
	check(c_big != c_normal, "'큰 한 방' 색이 평범한 숫자와 같다", 5)
	check(int(crit_style["size"]) > int(normal_style["size"]),
		"치명타 숫자가 평범한 숫자보다 크다", 5)

	# ── S6. 실제 경로 — **플레이어가 보는 라벨**이 치명타 색으로 뜨는가 ──────────
	var live := EnemyUnitScene.instantiate() as EnemyUnit
	add_child(live)
	var lbl_crit := _hit(live, 30.0, 1.0, true)
	var lbl_plain := _hit(live, 30.0, 1.0, false)
	var lbl_big := _hit(live, 200.0, 1.0, false)
	var lbl_weak_crit := _hit(live, 200.0, 1.6, true)
	print("%s labels crit=%s/%d plain=%s/%d big=%s/%d weak_crit=%s/%d"
		% [PREFIX,
			str(lbl_crit["style"].get("color")), int(lbl_crit["style"].get("size", 0)),
			str(lbl_plain["style"].get("color")), int(lbl_plain["style"].get("size", 0)),
			str(lbl_big["style"].get("color")), int(lbl_big["style"].get("size", 0)),
			str(lbl_weak_crit["style"].get("color")), int(lbl_weak_crit["style"].get("size", 0))])
	check(int(lbl_crit["labels"]) == 1 and lbl_crit["style"].get("color") == c_crit,
		"`is_crit=true` 로 때린 타격의 라벨이 치명타 색이 아니다 — 배선이 끊겼다", 6)
	check(lbl_plain["style"].get("color") == c_normal,
		"`is_crit=false` 인 30 피해가 평범한 색이 아니다", 6)
	check(lbl_big["style"].get("color") == c_big,
		"치명타가 아닌 200 피해가 '큰 한 방' 색이 아니다", 6)
	check(lbl_weak_crit["style"].get("color") == weak_style["color"],
		"약점 타격의 치명타가 약점 색이 아니다 — 상성 우선이 깨졌다", 6)
	check(str(lbl_crit["style"].get("text")) == "30",
		"치명타 숫자에 단어가 붙었다 (실측 \"%s\")" % str(lbl_crit["style"].get("text")), 6)
	# ⚠️ `free()` 가 아니라 `queue_free()` 다 — `_hit` 이 섬광 트윈을 이 노드에 걸어 두었다.
	#    즉시 해제하면 트윈이 죽은 노드를 가리킨다.
	live.queue_free()

	# ── S7. 일곱 종류가 색으로 구분되는가 ──────────────────────────────────────
	var kinds: Array = ["normal", "crit", "big", "dot", "shield", "weak", "resist"]
	var seen := {}
	var collisions: Array = []
	for kind in kinds:
		var col: Color = Juice.damage_style(100.0, kind)["color"]
		if seen.has(col):
			collisions.append("%s==%s" % [kind, str(seen[col])])
		seen[col] = kind
	print("%s kind_colors n=%d distinct=%d collisions=%s"
		% [PREFIX, kinds.size(), seen.size(), str(collisions)])
	check(collisions.is_empty(),
		"피해 종류가 색으로 구분되지 않는다: %s" % str(collisions), 7)
	check(seen.size() == kinds.size(),
		"종류 %d개가 색 %d개로 뭉쳤다" % [kinds.size(), seen.size()], 7)

	# ── S8. 배선 — `is_crit` 가 실제로 **내려오는가**, 유성·선회는 예외인가 ────────
	#   ⚠️ 소스 텍스트를 읽는다. `take_damage` 를 직접 부르면 **이 프로브가 호출처**가 되어
	#      "호출처가 있는가" 를 영원히 참으로 만든다.
	#   ⚠️ **개수가 아니라 '형태' 를 요구한다.** `is_crit` 이라는 낱말은 선언·주석에도 있으므로
	#      개수만 세면 **호출에서 빠져도 통과**한다 — `BotClaimProbe` 가 §2.16 에서 밟은 것과
	#      똑같은 함정이다(거기서는 `has_save_file` 이 전제에도 쓰여 개수 검사가 무의미했다).
	var chain: Array = [
		["res://scripts/tower/WordTower.gd", "_fire_projectile(enemy, damage, proj_type, is_crit)"],
		["res://scripts/tower/WordTower.gd", "_fire_projectile(targets[i], shares[i], proj_type, is_crit)"],
		["res://scripts/tower/WordTower.gd", "proj.setup(target, damage, proj_type, trait_id, self, projectile_scale(), is_crit)"],
		["res://scripts/tower/Projectile.gd", "is_crit = p_is_crit"],
		["res://scripts/tower/Projectile.gd", "take_damage(damage, true, damage_mult, false, is_crit)"],
		["res://scripts/tower/EnemyUnit.gd", "_damage_kind(absorbed, amount, dealt, mult, is_crit)"],
		["res://scripts/tower/EnemyUnit.gd", "_hit_kind(dealt, mult, is_crit)"],
		# ✅ §2.21-6 — 유성 경로. 굴림은 `attack_target()` 에서 이미 끝났고, 결과가
		#    `Meteor` 를 거쳐 `take_damage` 까지 내려간다. 한 칸이라도 끊기면 2배 피해가
		#    흰 숫자로 떠서 '보이는 치명타' 가 유성에서만 죽는다.
		["res://scripts/tower/WordTower.gd", "_cast_meteor(is_crit)"],
		["res://scripts/tower/WordTower.gd", "METEOR_BLAST_RADIUS, self, METEOR_FALL_TIME, is_crit)"],
		["res://scripts/tower/Meteor.gd", "is_crit = p_is_crit"],
		["res://scripts/tower/Meteor.gd", "take_damage(damage * mult, true, mult, false, is_crit)"],
		# ✅ §2.21-6 — 선회 경로. 굴림은 **타워**가 소유한다(`roll_crit()`), 오브는 결과만 받는다.
		["res://scripts/tower/TowerOrbit.gd", "var is_crit: bool = tower.roll_crit()"],
		["res://scripts/tower/TowerOrbit.gd", "tower.crit_damage(tower.orbit_damage() * mult, is_crit)"],
		["res://scripts/tower/TowerOrbit.gd", "take_damage(damage, false, mult, false, is_crit)"],
	]
	for pair in chain:
		var path: String = str(pair[0])
		var needle: String = str(pair[1])
		var text := FileAccess.get_file_as_string(path)
		print("%s chain %s :: \"%s\" x%d" % [PREFIX, path.get_file(), needle, text.count(needle)])
		check(text.count(needle) >= 1,
			"배선이 끊겼다 — %s 에 \"%s\" 가 없다" % [path.get_file(), needle], 8)
	# ✅ **§2.21-6 고침 (2026-10-01)** — 예전 이 단언은 `== 0` 이었고 **그것이 구멍의 기록**이었다
	#    (*"유성·선회는 굴림에 도달하지 않는다"*). 이제 **둘 다 나른다.** 되돌리면 빨개진다.
	#    ⚠️ 개수는 **거친** 검사다 — 정확한 것은 위 `chain` 의 문자열이다. 개수만 세면
	#       선언·주석에 있는 낱말도 세어져 **호출에서 빠져도 통과**한다(§2.16 의 함정).
	var wired := {}
	_scan_source("res://scripts", "is_crit", wired)
	print("%s wiring is_crit=%s" % [PREFIX, str(wired)])
	for f in ["Meteor.gd", "TowerOrbit.gd"]:
		check(int(wired.get(f, 0)) >= 2,
			"%s 에 `is_crit` 이 %d번뿐이다 — 굴림 결과가 피해 숫자까지 내려가야 한다(§2.21-6)"
				% [f, int(wired.get(f, 0))], 8)

	# ── S9. 계약 문구는 실제로 존재한다 ────────────────────────────────────────
	#   '화면에 없다' 를 주장하려면, 화면에 있어야 할 문구가 있다는 것을 먼저 세워야 한다.
	var promises: Array = [
		["res://scripts/tower/WordTower.gd", "치명타 %.0f%% (피해 2배)"],
		["res://scripts/ui/TowerInfoModal.gd", "치명타 %.0f%%"],
		["res://scripts/ui/ShopModal.gd", "25% 확률로 2배 치명타"],
	]
	for pair in promises:
		var path: String = str(pair[0])
		var needle: String = str(pair[1])
		var text := ""
		if FileAccess.file_exists(path):
			text = FileAccess.get_file_as_string(path)
		var n := text.count(needle)
		print("%s promise %s :: \"%s\" x%d" % [PREFIX, path.get_file(), needle, n])
		check(n >= 1, "계약 문구가 존재한다: %s" % needle, 9)
	# 치명타가 실제로 굴려지는 곳이 한 곳뿐인지 (작성자가 하나인지) 확인한다.
	# ⚠️ **`rolls.size()` 는 파일 수지 굴림 횟수가 아니다** — `_scan_source` 가 파일 이름으로
	#    키를 잡으므로, 한 파일 안에서 굴림을 **복제해도 size 는 그대로 1** 이다. 첫 판이
	#    정확히 그렇게 통과했다(K13 주입 RC=0). 값(횟수)을 **합해야** 한다 —
	#    `BotClaimProbe` 가 §2.16 에서 밟은 것과 같은 부류다(개수 vs 키).
	var rolls := {}
	_scan_source("res://scripts", "randf() < total_crit_chance()", rolls)
	var roll_total := 0
	for k in rolls:
		roll_total += int(rolls[k])
	print("%s crit_roll_sites %s total=%d" % [PREFIX, str(rolls), roll_total])
	check(roll_total == 1,
		"치명타를 굴리는 곳은 한 곳이다 (발견 %d곳 · 파일 %d개)" % [roll_total, rolls.size()], 9)

	# ✅ **§2.21-6 (2026-10-01)** — 굴림이 한 곳이라면, **세 경로가 그 문을 지나는지**를 잰다.
	#   ⚠️ 이 검사가 없으면 위 `roll_total == 1` 이 **공허**해진다 — 굴림 함수 하나만 남기고
	#      호출을 전부 지워도 개수는 그대로 1 이다(§2.16·§2.21 K13 의 *개수 vs 내용*).
	var callers := {
		"조준": ["res://scripts/tower/WordTower.gd", "var is_crit := roll_crit()"],
		"유성": ["res://scripts/tower/WordTower.gd", "_cast_meteor(is_crit)"],
		"선회": ["res://scripts/tower/TowerOrbit.gd", "tower.roll_crit()"],
	}
	for label in callers:
		var pair: Array = callers[label]
		var text := FileAccess.get_file_as_string(str(pair[0]))
		var n := text.count(str(pair[1]))
		print("%s roll_caller %s :: %s x%d" % [PREFIX, label, str(pair[1]), n])
		check(n >= 1,
			"%s 경로가 `roll_crit()` 을 안 부른다 — §2.21-6 의 구멍이 되살아났다" % label, 9)

	print("%s CRIT_DAMAGE_MULT=%.1f BIG_HIT_THRESHOLD=%.0f kinds=%s"
		% [PREFIX, crit_mult, big_threshold, str(kinds)])
	print("%s CLOSED §2.21-6 — 조준·유성·선회 셋 다 같은 굴림(`roll_crit()`)을 지난다. `예리한 렌즈` 계약이 세 경로에서 참이다."
		% PREFIX)

	if failures == 0:
		print("CRIT_SIGNAL_PROBE_OK")
	else:
		print("%s FAILURES=%d" % [PREFIX, failures])
	# 트리에 안 넣은 노드라 직접 해제한다 — 안 하면 CanvasItem 누수 경고가 로그에 남는다.
	probe.free()
	get_tree().quit(failures)
