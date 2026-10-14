extends Node
## §2.22 — 소리 전수: **텍스트 고아와 실제 고아는 다르다**
##
## ## 왜 이 절이 필요한가
##
## §2.20 은 `play_shield` 가 고아라는 것을 **측정**했고, 그 과정에서 게임 코드의 고아 소리가
## **3개**(`play_shield`·`play_heal`·`play_freeze`)라는 것까지 세었다. 그런데 그 셈은
## **텍스트 등장 횟수**를 센 것이고, 이 엔진에는 **별칭(alias)** 이 있다:
##
## ```gdscript
## func play_buff() -> void:
##     play_heal()          # ← 본문이 한 줄뿐인 위임
##
## func play_freeze() -> void:
##     play_magic()
## ```
##
## 별칭은 **호출자 없는 것처럼 보이는 소리를 실제로 울린다.** `play_heal` 은
## `scripts/` 어디에서도 이름으로 불리지 않지만, `play_buff` 가 **3곳**에서 불리고
## 그 `play_buff` 가 `play_heal` 로 간다 → **`play_heal` 은 매일 울리고 있다.**
##
## 그래서 §2.20 의 *"고아 소리 3개"* 는 **텍스트 산물**이다. 실제로 도달 불가능한 소리는
## **1개**(`play_shield`)뿐이고, `play_freeze` 는 `play_magic` 의 별칭이라 **고유 파형이
## 없으므로** "빠진 소리" 라고 부를 것도 없다.
##
## ## 측정 결과 (기준선 RC=0)
##
## | | 개수 | |
## |---|---|---|
## | `play_*` 정의 | **21** | |
## | 고유 파형 (`var duration`) | **19** | 21 − 별칭 2 |
## | 별칭 | **2** | `play_buff`→`play_heal` · `play_freeze`→`play_magic` |
## | **텍스트** 고아 | 2 | `play_freeze`·`play_heal` |
## | **실제** 고아 | **1** | `play_freeze` (별칭이라 고유 파형이 없다) |
## | 실제 고아 **이면서 고유 파형이 있는 것** | **0** | **`play_shield` 가 §2.20-6 에서 배선됐다** |
##
## ⚠️ **2026-10-01 — `play_boss_death` 추가로 20/17 → 21/18** (§5.2 30 (A)).
## ⚠️ **2026-10-03 — `play_base_hit` 이 전용 파형을 얻어 18 → 19** (§2.23 · §5.2 35 (C)).
##    예전에는 `play_hit` 과 파형을 공유해 **귀로 구별되지 않았다** — 스로틀 키만 달랐다.
##    이 표는 **프로브가 실제로 읽는 수**와 같아야 한다. 다르면 표가 낡은 것이다.
##
## ## `play_heal` 은 다른 이름으로 쓰이고 있었다 → **2026-09-26 에 재배치했다**
##
## **고침 전** (§2.22-4 의 측정): `play_buff` 의 호출처는 **3곳**이고, 셋 다 회복과 무관했다.
##
## | 호출처 | 사건 | 고침 전 | 지금 |
## |---|---|---|---|
## | `ShopModal._on_buy_relic_pressed` | 유물 구매 | `play_buff` | **`play_buff` (유지)** |
## | `TowerDefenseMain._on_save_pressed` | **저장** | `play_buff` | **`play_tile_click`** |
## | `TowerDefenseMain._on_tile_ability_requested` | 밀어내기 | `play_buff` | **`play_magic`** |
##
## 즉 E5→A5→C6→E6 상행 아르페지오("좋은 일")는 **이미 게임에 있었다.** 그러므로
## *"회복 순간에 고아 소리를 연결하자"* 는 선택지는 **성립하지 않는다** — 그 소리는
## 이미 `play_buff` 로 나가고 있었다. 남는 질문은 *"회복 순간에 `victory` 위에
## `buff` 를 **더** 얹을 것인가"* 이고, 그건 §2.20 J1 과 같은 **겹침** 문제다.
##
## ## 고침 — 감독 선택 (C) 재배치 (2026-09-26)
##
## 감사 §5.2 34 의 **(C) 재배치** 를 감독이 골랐다. **새 소리 0** — 기존 소리를 옮길 뿐이다.
##
## **왜 저장이 `play_tile_click` 인가** — 저장은 **UI 동작**이라 게임 세계의 사건이 아니다.
## 버튼을 눌렀다는 사실만 알리면 되고, 이 프로젝트의 UI 클릭음은 이미 상점 닫기
## (`ShopModal.gd:283`)·타이틀 버튼·모달이 쓰는 **한 가지 소리**다.
##
## **왜 밀어내기가 `play_magic` 인가** — 밀어내기는 **값을 치르는 개입**(자모 1장 영구 소모)이지
## '좋은 일이 있었다' 가 아니다. `play_magic` 은 **내려가는 스윕**(700→250Hz)이라
## '밀려난다' 와 방향이 맞고, 보상 계열(상행 아르페지오)과 귀로 갈린다.
## ⚠️ **잔여** — `play_magic` 은 원소 타워 공격음(`WordTower.gd:621`)과 이름을 공유하므로
## 50 ms **이름별** 스로틀이 이 소리를 삼킬 수 있다(§2.23 과 **같은 부류**). 밀어내기는
## 웨이브당 1회뿐이라 노출은 제한적이지만, **사라진 결함이 아니라 줄어든 결함**이다.
##
## ## 이 프로브가 지키는 것
##
## S2 는 **고침 뒤의 상태**를 단언한다 — `play_buff` 의 호출처가 **1곳**(유물 구매)이고,
## S7 이 **어느 사건이 어느 소리를 쓰는가** 를 함수 단위로 잰다. 되돌리면 빨개진다.
##
## ## ⚠️ 2026-10-01 — 프로브가 두 번 낡아 있었다 (둘 다 이 창에서 발견)
##
## ① **§2.23 의 `play_base_hit` 신설** 이 정의 수를 19 → 20 으로 만들었는데 이 파일은
##    19 를 기대하고 있었다. 그리고 `play_hit` 이 `throttle_key` 인자를 받게 되면서
##    카테고리 파서(`^, (ui|sfx)_volume_db)$`)가 그 줄을 못 읽어 **17 → 16** 이 됐다.
##    ⚠️ 교훈 — **고침 뒤에 이 프로브를 다시 돌리지 않았다.** `run_all.sh` 에 없으므로
##    아무도 안 알려 준다. 새 소리/새 인자를 만드는 고침은 **이 파일을 반드시 다시 돌려라.**
## ② **`play_buff` 의 본문이 `play_magic()` 으로 바뀌어 있었다** — §2.22-6 이 기록한
##    별칭(`play_buff`→`play_heal`)과 정면으로 어긋나고, 그러면 유물 구매가 밀어내기와
##    같은 소리가 되며 `play_heal` 이 **다시 진짜 고아**가 된다. 2026-10-01 에 복원했다.
##    ⚠️ **이 프로브가 초록이어도 별칭 지도는 지켜지지 않았다** — 아래 `aliases ==` 단언이
##    그걸 잡을 **수 있었는데**, 프로브를 안 돌렸으므로 5일 동안 아무도 몰랐다.

const PREFIX := "ORPHAN_SOUND"
const DefenseFieldScript = preload("res://scripts/tower/DefenseField.gd")
const SOURCE_ROOT := "res://scripts"
## 정의가 있는 파일 — 여기서의 등장은 '호출' 이 아니다.
const ENGINE_FILE := "SoundEngine.gd"

## 텍스트 기준 고아 — 이름으로 불리지 않는 소리.
## ⚠️ **2026-10-01 에 `play_shield` 가 빠졌다** — §2.20 (B) 로 `EnemyUnit.take_damage` 가
##    막은 타격에 그 소리를 낸다. 이제 남은 텍스트 고아는 별칭 둘뿐이다.
const EXPECTED_TEXTUAL_ORPHANS: Array = ["play_freeze", "play_heal"]
## 별칭을 따라간 뒤에도 도달 불가능한 소리.
## ⚠️ **`play_heal` 은 여기 없다** — `play_buff`→`play_heal` 위임이 살아 있고 그 주인이
##    유물 구매 1곳이므로 **도달 가능**하다. `play_freeze` 는 별칭이지만 `play_freeze` 를
##    부르는 곳이 0건이라 실제 고아다.
const EXPECTED_EFFECTIVE_ORPHANS: Array = ["play_freeze"]
## 별칭이 가리키는 대상 — `play_X` 본문이 한 줄 위임이면 여기 들어간다.
const EXPECTED_ALIASES := {"play_buff": "play_heal", "play_freeze": "play_magic"}
## `play_heal` 이 실제로 울리는 경로. 이 수가 0 이 되면 위 결론이 무너진다.
##
## ⚠️ **2026-09-26 에 3 → 1 로 바뀌었다** — §5.2 34 (C) 재배치로 저장·밀어내기가
## 다른 소리를 받았고, 남은 주인은 **유물 구매 하나**다. 즉 `play_heal` 은 여전히
## 고아가 아니지만 **여유가 없어졌다** — 이 1곳마저 바뀌면 §2.22 의 결론이 뒤집힌다.
const EXPECTED_BUFF_CALLERS := 1

## 기지 HP 를 올리는 지점 — 사건이 실재한다는 증거.
## ⚠️ **겹치지 않는 패턴이어야 한다.** 처음에 `"base_hp + 1"` 로 셌더니 `"base_hp + 10"` 의
## 부분문자열까지 잡혀 **4곳**으로 보고했다(실제 3곳). 접두어가 겹치는 패턴은 세지 마라.
const HEAL_SITE_PATTERNS: Array = [
	"mini(max_base_hp, base_hp + 2)",
	"mini(max_base_hp, base_hp + 1)",
	"mini(defense_field.base_hp + 10,",
]

var failures := 0


func check(cond: bool, msg: String, tag: int) -> void:
	if not cond:
		failures += 1
		print("FAIL_SECTION S%d :: %s" % [tag, msg])
		push_error("S%d %s" % [tag, msg])


func _ready() -> void:
	# ⚠️ **첫 줄이어야 한다.** `muted` 면 `_play_synth_stream()` 이 **즉시 return** 해서
	#    `_last_played_msec` 이 통째로 비고, S4 의 모든 단언이 **공허**해진다.
	#    실제로 이 프로젝트의 `user://sound_config.json` 은 `muted: true` 다(사용자 설정).
	#    필드 직접 대입이라 `_save_config()` 를 지나지 않는다 → **설정 파일은 안전하다.**
	SoundEngine.muted = false

	# ── S1. 전수 — 정의·파형·별칭 ──────────────────────────────────────────────
	var defs := _play_defs()
	var durations := _sound_durations()
	var aliases := _alias_map()
	print("%s defs=%d waveforms=%d aliases=%s" % [PREFIX, defs.size(), durations.size(), str(aliases)])
	# 파서가 문구를 못 읽으면 아래 단언이 전부 **공허**해진다 — 먼저 개수를 못 박는다.
	# ⚠️ **2026-10-01: 20/17 → 21/18** (§5.2 30 (A) 가 `play_boss_death` 를 들였다).
	# ⚠️ **2026-10-03: 21/18 → 21/19** (§2.23 · §5.2 35 (C) — `play_base_hit` 전용 파형).
	#    이 개수 단언이 **제 일을 했다** — 새 소리를 넣자 S1 이 즉시 빨개져서
	#    "파서가 못 읽는 것" 과 "정말 늘어난 것" 을 구별하게 강제했다.
	#    ⚠️ 소리를 더하거나 지우면 **여기도 같이 고쳐야 한다.** 안 고치면 S1 이
	#       *"파서가 문구를 못 읽는다"* 며 거짓말을 한다.
	check(defs.size() == 21,
		"`play_*` 정의가 21개다 (측정 %d) — 파서가 문구를 못 읽으면 공허해진다" % defs.size(), 1)
	check(durations.size() == 19,
		"고유 파형은 19개다 (측정 %d) — 21 − 별칭 2" % durations.size(), 1)
	check(aliases == EXPECTED_ALIASES,
		"별칭 지도가 바뀌었다 (기대 %s / 실측 %s)" % [str(EXPECTED_ALIASES), str(aliases)], 1)

	# ── S2. 텍스트 고아 vs **실제** 고아 ──────────────────────────────────────
	#   ⚠️ **호출 여부를 함수 호출로 검사하면 그 검사가 호출자가 된다** — 소스를 읽는다.
	#   ⚠️ 그리고 **텍스트 스캔은 별칭을 못 본다.** 이 절이 §2.20 의 셈을 바로잡는 자리다.
	var counts := {}
	for name in defs:
		var hits: Dictionary = {}
		_scan_source(SOURCE_ROOT, str(name), hits, ENGINE_FILE)
		var n := 0
		for k in hits:
			n += int(hits[k])
		counts[name] = n

	#   대상 → 그 대상을 부르는 별칭들.
	var rev := {}
	for a in aliases:
		var t: String = aliases[a]
		if not rev.has(t):
			rev[t] = []
		rev[t].append(a)

	var textual: Array = []
	var effective: Array = []
	for name in defs:
		if int(counts[name]) == 0:
			textual.append(name)
			# 별칭 중 **하나라도** 불리면 실제로는 도달 가능하다.
			var reachable := false
			for a in rev.get(name, []):
				if int(counts.get(a, 0)) > 0:
					reachable = true
			if not reachable:
				effective.append(name)
	textual.sort()
	effective.sort()
	print("%s textual_orphans=%s" % [PREFIX, str(textual)])
	print("%s effective_orphans=%s" % [PREFIX, str(effective)])

	check(textual == EXPECTED_TEXTUAL_ORPHANS,
		"텍스트 고아 집합이 바뀌었다 (기대 %s / 실측 %s)" % [str(EXPECTED_TEXTUAL_ORPHANS), str(textual)], 2)
	check(effective == EXPECTED_EFFECTIVE_ORPHANS,
		"실제 고아 집합이 바뀌었다 (기대 %s / 실측 %s)" % [str(EXPECTED_EFFECTIVE_ORPHANS), str(effective)], 2)

	#   이 절의 결론 한 줄: **고유 파형을 가진 실제 고아는 `play_shield` 하나뿐이다.**
	var with_wave: Array = []
	for name in effective:
		if not aliases.has(name):
			with_wave.append(name)
	with_wave.sort()
	print("%s effective_orphans_with_waveform=%s" % [PREFIX, str(with_wave)])
	check(with_wave.is_empty(),
		"고유 파형을 가진 실제 고아가 **없다** — §2.20 (B) 로 `play_shield` 가 주인을 얻었다 (실측 %s)"
			% str(with_wave), 2)

	#   `play_heal` 이 실제로 울리는 증거 — 별칭의 호출 수.
	var buff: Dictionary = {}
	_scan_source(SOURCE_ROOT, "play_buff", buff, ENGINE_FILE)
	var buff_n := 0
	for k in buff:
		buff_n += int(buff[k])
	print("%s play_buff_callers=%d sites=%s" % [PREFIX, buff_n, str(buff.keys())])
	check(buff_n == EXPECTED_BUFF_CALLERS,
		"`play_buff` 호출이 %d곳이다 (측정 %d) — 이게 0 이면 `play_heal` 이 정말 고아가 된다"
			% [EXPECTED_BUFF_CALLERS, buff_n], 2)

	# ── S3. 각 고아에 주인이 될 사건이 있는가 ─────────────────────────────────
	var heal_sites := 0
	for pat in HEAL_SITE_PATTERNS:
		var h: Dictionary = {}
		_scan_source(SOURCE_ROOT, str(pat), h)
		for k in h:
			heal_sites += int(h[k])
	var shield_owner: Dictionary = {}
	_scan_source(SOURCE_ROOT, 'return "shield"', shield_owner)
	var freeze_owner: Dictionary = {}
	# ⚠️ `skip_file` 을 안 주면 **정의 자체**(`func play_freeze()`)가 호출로 세어진다.
	_scan_source(SOURCE_ROOT, "play_freeze", freeze_owner, ENGINE_FILE)
	print("%s owners heal_sites=%d shield_sites=%s freeze_sites=%s"
		% [PREFIX, heal_sites, str(shield_owner.keys()), str(freeze_owner.keys())])
	check(heal_sites == 3,
		"기지 HP 를 올리는 지점은 3곳이다 (측정 %d) — 회복 사건이 실재한다" % heal_sites, 3)
	check(not shield_owner.is_empty(),
		"`\"shield\"` 를 돌려주는 지점이 있다 — 그 사건의 주인이 실재한다", 3)
	check(freeze_owner.is_empty(),
		"`play_freeze` 에는 살아 있는 주인이 없다(§5.2 20 의 '전제 소멸' 과 같은 결론)", 3)

	# ── S4. 회복 순간에 **이미 나는 소리** ────────────────────────────────────
	#   실제 필드를 세우고 회복이 일어나는 함수를 그대로 태운다.
	var field = DefenseFieldScript.new()
	field.current_act = 1
	field.current_wave = 3            # 보스 라운드(5의 배수)를 피한다
	field.relic_ids = ["relic_healing_incense"]
	# ⚠️ **기지 HP 를 먼저 깎아야 한다.** 회복은 `mini(max_base_hp, base_hp + 2)` 라
	#    가득 찬 상태에서는 **아무 일도 안 일어난다**(첫 판이 `heal=+0` 을 냈다).
	field.base_hp = field.max_base_hp - 10
	var hp_before: int = field.base_hp

	# 환경 점검 — 소리가 아예 안 나는 환경이면 아래 단언이 **공허**해진다.
	SoundEngine._last_played_msec.clear()
	SoundEngine.play_coin()
	var sanity: Array = SoundEngine._last_played_msec.keys()
	check(sanity.has("coin"),
		"`SoundEngine` 이 소리를 등록하지 않는다(환경 문제) — 이 절이 공허해진다", 4)

	SoundEngine._last_played_msec.clear()
	field._grant_round_reward(false)
	var played: Array = SoundEngine._last_played_msec.keys()
	played.sort()
	var healed: int = field.base_hp - hp_before
	print("%s runtime heal=+%d plays=%s" % [PREFIX, healed, str(played)])
	check(healed == 2,
		"회복의 향로가 실제로 +2 회복한다 (측정 +%d)" % healed, 4)
	check(played.has("victory"),
		"회복 순간에 `victory` 가 난다 — 여기에 `buff` 를 얹으면 겹친다(§2.20 J1 과 같은 구조)", 4)
	check(not played.has("heal") and not played.has("buff"),
		"회복 순간에 이미 회복음을 낸다 — 연결됐다면 §5.2 34 와 이 절을 갱신하라", 4)
	field.free()

	# ── S5. 길이 순서 — 고아가 들어갈 자리가 있는가 ───────────────────────────
	#   이 프로젝트의 불변식은 **길이 = 강도 순서** 다.
	print("%s durations=%s" % [PREFIX, str(durations)])
	var d_heal: float = float(durations.get("play_heal", -1.0))
	var d_victory: float = float(durations.get("play_victory", -1.0))
	var d_hit: float = float(durations.get("play_hit", -1.0))
	var d_shield: float = float(durations.get("play_shield", -1.0))
	var d_final: float = float(durations.get("play_final_victory", -1.0))
	check(d_final >= 0.9,
		"런 승리음이 가장 길다 (%.2fs)" % d_final, 5)
	check(d_heal > 0.0 and d_heal < d_victory,
		"`play_heal`(%.2fs)은 `play_victory`(%.2fs)보다 **짧다** — 길이 순서를 깨지 않고 들어갈 수 있다"
			% [d_heal, d_victory], 5)
	# ✅ §5.2 32 (C) 고침 (2026-10-01) — 예전에는 이 단언이 **반대**(`shield > hit`)였고 그것이
	#    결함의 *기록* 이었다. 파형을 0.09초로 다시 썼으므로 이제 **고침을 지킨다.**
	check(d_shield < d_hit,
		"`play_shield`(%.2fs)는 `play_hit`(%.2fs)보다 **짧다** — 막은 타격이 맞은 타격보다 약하게 들린다(§5.2 32 (C))"
			% [d_shield, d_hit], 5)

	# ── S6. 계약 문구 — 회복을 약속하는 곳은 있는가 ───────────────────────────
	var incense: Dictionary = {}
	_scan_source(SOURCE_ROOT, "웨이브 종료 시 기지 HP 2 회복", incense)
	var rune: Dictionary = {}
	_scan_source(SOURCE_ROOT, "기지 최대 체력 +10 및 즉시 10 회복", rune)
	var toast: Dictionary = {}
	_scan_source(SOURCE_ROOT, '유물 획득 · %s', toast)
	print("%s contract incense=%s rune=%s toast=%s"
		% [PREFIX, str(incense.keys()), str(rune.keys()), str(toast.keys())])
	check(not incense.is_empty() and not rune.is_empty(),
		"회복을 약속하는 상점 문구가 두 곳에 있다", 6)
	check(not toast.is_empty(),
		"유물 획득 토스트는 **일반 문구**다 — 회복을 말하지 않는다", 6)

	# ── S7. 배치 — **어느 사건이 어느 소리를 쓰는가** (2026-09-26, 감독 선택 C) ──
	#   §2.22-4 의 결함은 '고아' 도 '무음' 도 아니고 **배치**였다 — 이 게임에서 유일하게
	#   '좋은 일' 을 뜻하는 파형(상행 아르페지오)이 *저장*·*밀어내기* 에 붙어 있었다.
	#   이 절은 그 배치를 **함수 단위로** 잰다. 되돌리면 빨개진다.
	var cats := _sound_category_map()
	print("%s categories=%s" % [PREFIX, str(cats)])
	#   ⚠️ 파서가 음원 종류를 못 읽으면 아래 단언이 전부 **공허**해진다 — 먼저 못 박는다.
	#   ⚠️ 2026-10-01: 17 → 18 (§5.2 30 (A) 의 `play_boss_death`). S1 과 **같은 수**여야 한다.
	#   ⚠️ 2026-10-03: 18 → 19 (§2.23 · §5.2 35 (C) — `play_base_hit` 이 전용 파형을 얻어
	#      `_play_synth_stream(..., sfx_volume_db, "hit_base")` 를 직접 부르게 됐다. 그 전에는
	#      `play_hit("hit_base")` 위임이라 **카테고리 지도에 없었다** → 감산 항이 하나 줄었다.
	check(cats.size() == 19,
		"음원 종류를 19개 읽었다 (측정 %d) — 21 정의 − 별칭 2"
			% cats.size(), 7)
	check(cats.get("play_tile_click", "") == "ui",
		"`play_tile_click` 은 UI 음원이다 (측정 %s)" % str(cats.get("play_tile_click", "?")), 7)
	check(cats.get("play_magic", "") == "sfx",
		"`play_magic` 은 전투 음원이다 (측정 %s)" % str(cats.get("play_magic", "?")), 7)

	var main_file := SOURCE_ROOT.path_join("ui").path_join("TowerDefenseMain.gd")
	var save_sounds := _sounds_in_func(main_file, "_on_save_pressed")
	var push_sounds := _sounds_in_func(main_file, "_on_tile_ability_requested")
	print("%s placement save=%s pushback=%s" % [PREFIX, str(save_sounds), str(push_sounds)])

	#   ⚠️ 개수를 먼저 못 박는다 — 파서가 함수를 못 찾으면 아래 단언이 **공허**해진다.
	check(save_sounds.size() == 1,
		"`_on_save_pressed` 가 소리를 정확히 1개 낸다 (측정 %s)" % str(save_sounds), 7)
	check(push_sounds.size() == 1,
		"`_on_tile_ability_requested` 가 소리를 정확히 1개 낸다 (측정 %s)" % str(push_sounds), 7)
	var save_sound := str(save_sounds[0]) if save_sounds.size() == 1 else ""
	var push_sound := str(push_sounds[0]) if push_sounds.size() == 1 else ""
	check(save_sound == "play_tile_click",
		"저장은 UI 클릭음이다 (측정 %s)" % save_sound, 7)
	check(push_sound == "play_magic",
		"밀어내기는 전투 효과음이다 (측정 %s)" % push_sound, 7)

	#   사건 종류와 음원 종류가 맞는가 — UI 사건은 UI 음원, 전투 사건은 전투 음원.
	check(str(cats.get(save_sound, "")) == "ui",
		"저장(UI 사건)이 UI 음원을 쓴다 (측정 %s)" % str(cats.get(save_sound, "?")), 7)
	check(str(cats.get(push_sound, "")) == "sfx",
		"밀어내기(전투 사건)가 전투 음원을 쓴다 (측정 %s)" % str(cats.get(push_sound, "?")), 7)

	#   핵심 불변식 — **보상 파형(`play_buff`→`play_heal`)의 주인은 상점 하나뿐**이다.
	var heal_owners: Dictionary = {}
	_scan_source(SOURCE_ROOT, "play_buff", heal_owners, ENGINE_FILE)
	var heal_files: Array = heal_owners.keys()
	heal_files.sort()
	print("%s heal_family_files=%s" % [PREFIX, str(heal_files)])
	check(heal_files.size() == 1 and str(heal_files[0]).ends_with("ShopModal.gd"),
		"보상 파형의 주인은 유물 구매 하나뿐이다 (측정 %s)" % str(heal_files), 7)

	print("%s RESOLVED 배치를 바로잡았다 — 저장=tile_click · 밀어내기=magic · 유물=buff (감사 §5.2 34 (C), 2026-09-26)" % PREFIX)

	if failures == 0:
		print("ORPHAN_SOUND_PROBE_OK")
	else:
		print("%s FAILURES=%d" % [PREFIX, failures])
	get_tree().quit(failures)


## `SoundEngine.gd` 안에 정의된 `play_*` 이름들.
func _play_defs() -> Array:
	var names: Array = []
	var text := ""
	var path := SOURCE_ROOT.path_join("core").path_join(ENGINE_FILE)
	if FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	var re := RegEx.new()
	re.compile("func (play_[a-z_]+)\\(")
	for m in re.search_all(text):
		names.append(m.get_string(1))
	names.sort()
	return names


## 본문이 **한 줄 위임**인 `play_*` → 위임 대상. `{play_buff: play_heal, ...}`
##
## ⚠️ 첫 본문 줄만 본다. 정상 파형 함수의 첫 줄은 `_play_synth_stream(...)` 이라
##    정규식에 걸리지 않는다. 별칭이 여러 줄이 되면 이 파서는 못 잡는다 — 그때 갱신하라.
## 줄에서 **문자열 밖의** `#` 이후를 잘라낸다.
##
## ⚠️ `s.begins_with("#")` 만으로는 부족하다 — 그건 *줄 전체가 주석인 줄*만 거른다.
##    코드 줄 **끝**에 붙은 주석(`return  # 설명`)은 그대로 남아 호출로 세어진다.
## ⚠️ 문자열 안의 `#`(`"#A6B8F2"`)은 살려야 한다 — 무조건 자르면 진짜 호출을 놓친다.
func _code_part(line: String) -> String:
	var in_str := false
	var quote := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if in_str:
			if c == "\\":
				i += 2
				continue
			if c == quote:
				in_str = false
		else:
			if c == "\"" or c == "'":
				in_str = true
				quote = c
			elif c == "#":
				return line.substr(0, i)
		i += 1
	return line


func _alias_map() -> Dictionary:
	var out := {}
	var path := SOURCE_ROOT.path_join("core").path_join(ENGINE_FILE)
	if not FileAccess.file_exists(path):
		return out
	var re := RegEx.new()
	re.compile("^play_[a-z_]+\\(\\)$")
	var cur := ""
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var s := str(line).strip_edges()
		if s.begins_with("func play_"):
			cur = _func_name(s)
		elif cur != "" and s != "":
			if re.search(s) != null:
				out[cur] = s.substr(0, s.length() - 2)
			cur = ""
	return out


func _func_name(decl: String) -> String:
	var a := decl.find("func ") + 5
	var b := decl.find("(")
	return decl.substr(a, b - a) if b > a else ""


## `func play_X` 바로 뒤에 오는 `var duration = N` 을 소리 이름 → 길이로 모은다.
func _sound_durations() -> Dictionary:
	var out := {}
	var path := SOURCE_ROOT.path_join("core").path_join(ENGINE_FILE)
	if not FileAccess.file_exists(path):
		return out
	var cur := ""
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var s := str(line).strip_edges()
		if s.begins_with("func play_"):
			cur = _func_name(s)
		elif cur != "" and s.begins_with("var duration ="):
			var parts := s.split("=")
			if parts.size() >= 2:
				out[cur] = float(parts[1].strip_edges())
			cur = ""
	return out


## `play_*` → `"ui"` / `"sfx"`. `_play_synth_stream(...)` 의 **마지막 인자**에서 읽는다.
##
## ⚠️ 파형 함수의 마지막 줄은 `\t, ui_volume_db)` 처럼 **한 줄에 홀로** 온다(실측).
##    별칭(`play_buff`·`play_freeze`)은 `_play_synth_stream` 을 안 부르므로 여기 안 들어온다
##    — 그래서 기대 개수가 19 가 아니라 **17** 이다.
func _sound_category_map() -> Dictionary:
	var out := {}
	var path := SOURCE_ROOT.path_join("core").path_join(ENGINE_FILE)
	if not FileAccess.file_exists(path):
		return out
	var cur := ""
	var re := RegEx.new()
	# ⚠️ **끝을 `)$` 로 못 박으면 안 된다**(2026-10-01) — `_play_synth_stream` 이 인자를 하나 더
	#    받는 호출(`play_hit` 의 `, sfx_volume_db, throttle_key)`)을 놓쳐, 그 소리가 지도에서
	#    통째로 사라진다. 실측: §2.23 의 스로틀 키 분리 뒤 카테고리가 17 → 16 이 됐고,
	#    아래 `cats.size() == 17` 이 **거짓으로 빨개졌다.**
	re.compile("^, (ui|sfx)_volume_db[,)]")
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var s := str(line).strip_edges()
		if s.begins_with("func play_"):
			cur = _func_name(s)
		elif cur != "":
			var m := re.search(s)
			if m != null:
				out[cur] = m.get_string(1)
				cur = ""
	return out


## 한 함수 **안에서** 불리는 `SoundEngine.play_*` 이름들 (정의 순서).
##
## ⚠️ 함수 경계는 **들여쓰기 0 의 `func `** 다 — GDScript 에 중첩 함수가 없다.
## ⚠️ 주석은 `_code_part()` 로 뺀다. 안 빼면 새로 단 *"…`play_buff()` 였다"* 같은
##    **설명이 호출로 세어져** 이 절이 거짓으로 빨개진다(실측: 그렇게 처음에 걸렸다).
func _sounds_in_func(path: String, target: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	var inside := false
	var re := RegEx.new()
	re.compile("SoundEngine\\.(play_[a-z_]+)\\(")
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var raw := str(line)
		if raw.begins_with("func "):
			inside = _func_name(raw.strip_edges()) == target
			continue
		if not inside:
			continue
		var m := re.search(_code_part(raw))
		if m != null:
			out.append(m.get_string(1))
	return out


## `dir_path` 아래 모든 `.gd` 에서 `needle` 을 **주석 줄을 빼고** 센다.
##
## ⚠️ 주석을 안 빼면 *"`play_shield` 는 고아다"* 같은 **주석이 호출로 세어진다** —
## §2.20 이 쓴 거친 판본과 달라지는 지점이고, 그쪽 결과와 **일치하는지**가 검산이다.
## `skip_file` 은 정의가 있는 파일(호출이 아님).
##
## ⚠️ **이 함수는 별칭을 못 본다.** `play_buff`→`play_heal` 같은 위임은 텍스트에
##    `play_heal` 이라는 글자를 남기지 않는다 — 그래서 S2 가 별도로 필요하다.
func _scan_source(dir_path: String, needle: String, hits: Dictionary, skip_file := "") -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			_scan_source(full, needle, hits, skip_file)
		elif name.ends_with(".gd") and name != skip_file:
			var n := 0
			for line in FileAccess.get_file_as_string(full).split("\n"):
				var s := _code_part(str(line)).strip_edges()
				if s == "":
					continue          # 빈 줄 / 주석
				if s.contains(needle):
					n += 1
			if n > 0:
				hits[full] = n
		name = dir.get_next()
	dir.list_dir_end()
