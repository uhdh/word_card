class_name AutoArrange
extends RefCounted

## '전략 추천' 프로필이 선호하는 분류.
##
## 예전에는 이 목록에 든 분류에 가산점(+700)을 더했다. 그 눈금(DB 의 damage 10~50)
## 에서는 가산점이 사실상 전부를 눌러서 프로필이 방향을 정했다. 순위 눈금을 실제
## DPS 로 바꾸자(460~11200) 가산점이 묻혀 **세 프로필이 같은 답**을 냈다 —
## 실측(tools/HintValueProbe.gd): 좁은 벨트에서 서로 다른 조합이 3개 중 1개.
## 가산점을 키우면 이번엔 실제로 더 센 단어를 제치고 약한 쪽을 추천한다(힌트에서
## 막 고친 그 버그). 그래서 가산점 대신 **후보를 좁힌다** — 둘 다 피할 수 있다.
const PROFILE_CATEGORIES: Dictionary = {
	"single": ["weapon", "defense"],
	"area": ["magic", "skill"],
	"control": ["heal", "element", "summon"],
}

## 힌트가 고르는 후보를 좁히는 비율 — **DPS 1위의 이 비율 이상**인 것만 남긴다.
##
## 감독 지시(2026-10-02)는 *"가장 타일을 많이 쓰는 타워 중 랜덤"* 이었다. 그런데 실측
## (`tools/HintVarietyProbe`, 2315봉지)이 그 규칙이 **"큰 타워" 를 고르지 않는다**는 것을
## 보였다 — `required_jamo` 가 겹모음·겹받침을 펼치므로 **생(ㅅㅏㅣㅇ) = 4장 = 우수(4장)** 이고,
## 최대 타일 그룹의 **61%가 1음절**이다. 작은 봉지에서는 **가장 작은 타워**를 가리킨다.
## 세기 손실도 컸다 — 기대 세기 **0.774**(23% 손실) · 최악 **0.082**(12배 약함).
## 그것은 감독이 두 번 보고한 버그의 형태다(가루 9.5 vs 바늘 45.4 = 비율 0.21 —
## `tests/test_tower_traits.gd` 의 두 계약이 그걸 잠그고 있다).
##
## 그래서 감독이 고른 대안(2026-10-02): **세기로 후보를 좁히고, 그 안에서 고르게 한다.**
## 실측 대안 C — 기대 세기 **0.979**(2% 손실) · 최악 **0.800** · 봉지 **41.8%** 에서
## 선택지가 2개 이상. 같은 목적(획일화 해소)을 거의 무손실로 이룬다.
const HINT_KEEP_RATIO := 0.8


static func _inverse(combinations: Dictionary) -> Dictionary:
	var result := {}
	for parts in combinations:
		result[combinations[parts]] = str(parts).split("+")
	return result

static func get_word_syllable_slots(word: String) -> Array:
	var consonants := _inverse(HangulEngine.CONSONANT_COMBINATIONS)
	var vowels := _inverse(HangulEngine.VOWEL_COMBINATIONS)
	var syllables := []
	for character in word:
		var jamo := HangulEngine.decompose_syllable(character)
		var slots := [consonants.get(jamo.chosung, [jamo.chosung]), vowels.get(jamo.jungsung, [jamo.jungsung])]
		if jamo.jongsung != "": slots.append(consonants.get(jamo.jongsung, [jamo.jongsung]))
		syllables.append(slots)
	return syllables

static func _can_rotate_to(tile: String, target: String) -> bool:
	for _turn in range(4):
		if tile == target: return true
		tile = HangulEngine.rotate(tile)
	return false

## 이 타일을 회전시켜 그 자모를 채울 수 있는가.
## 슬롯 채점이 '회전해서 맞출 수 있는 타일' 을 놓치지 않도록 밖에서도 쓴다.
static func can_fill(tile: String, jamo: String) -> bool:
	return _can_rotate_to(tile, jamo)

## 단어가 요구하는 자모를 순서대로 펼친 열.
##
## 합자(ㄲ, ㅘ …)는 구성 자모로 펼쳐진다 — 그래서 ㄲ 한 장은 두 자리를 채운다.
## get_word_syllable_slots 가 이미 그 펼침을 담고 있으므로 그대로 이어 붙이기만 한다.
static func required_jamo(word: String) -> Array:
	var out: Array = []
	for syllable in get_word_syllable_slots(word):
		for slot in syllable:
			out.append_array(slot)
	return out

## 그 단어를 만들 때 실제로 쓸 타일의 인덱스(owned 기준). 못 만들면 빈 배열.
##
## _tiles_for_word 와 같은 greedy 매칭이지만 '값' 이 아니라 '인덱스' 를 돌려준다.
## 고정이 타일을 예약하려면 인덱스가 있어야 한다 — 같은 자모 타일이 여러 장일 때
## 값만으로는 어느 장을 잡았는지 알 수 없다.
## blocked 에 든 인덱스는 후보에서 뺀다(이미 다른 슬롯이 고정한 타일).
static func tile_indices_for(word: String, owned: Array[String], blocked: Array = []) -> Array:
	var taken: Array = []
	for target in required_jamo(word):
		var found := -1
		for i in range(owned.size()):
			if i in blocked or i in taken: continue
			if _can_rotate_to(owned[i], target):
				found = i
				break
		if found < 0: return []
		taken.append(found)
	return taken

static func _tiles_for_word(word: String, owned: Array[String]) -> Dictionary:
	var available := []
	for index in range(owned.size()): available.append({"tile": owned[index]})
	var arranged: Array[String] = []
	for syllable in get_word_syllable_slots(word):
		for slot in syllable:
			for target in slot:
				var match_index := -1
				for index in range(available.size()):
					if _can_rotate_to(available[index].tile, target):
						match_index = index
						break
				if match_index < 0: return {}
				available.remove_at(match_index)
				arranged.append(target)
	return {"arranged": arranged, "unused": available}

static func shuffled_tiles_for(owned: Array[String], words: Array) -> Dictionary:
	var candidates := []
	for data in words:
		var word_match := _tiles_for_word(str(data.get("word", "")), owned)
		if not word_match.is_empty(): candidates.append({"data": data, "tiles_match": word_match})
	if candidates.is_empty(): return {}
	candidates.sort_custom(func(a, b):
		var a_tier := int(a.data.get("tier", str(a.data.word).length()))
		var b_tier := int(b.data.get("tier", str(b.data.word).length()))
		return a_tier > b_tier or (a_tier == b_tier and int(a.data.get("damage", 0)) > int(b.data.get("damage", 0)))
	)
	var best: Dictionary = candidates[0]
	var leftovers: Array = best.tiles_match.unused
	var tiles: Array[String] = best.tiles_match.arranged.duplicate()
	for item in leftovers:
		tiles.append(item.tile)
	return {"word": best.data.word, "tiles": tiles, "word_tile_count": best.tiles_match.arranged.size()}

## 남은 타일로 만들 수 있는 단어 — **[0] 은 추천, 나머지는 세기 순서의 후보**.
##
## [0] 은 DPS 1위의 `HINT_KEEP_RATIO` 이상인 것 중에서 **봉지 시드로** 고른 하나다.
## [1..] 은 세기 순서 그대로 — 조합 추천 패널이 여섯 줄을 그대로 보여 줄 수 있어야 한다.
## (좁힌 후보만 돌려주면 패널이 평균 1.9줄로 준다 — 실측 대안 C 의 평균 선택지가 1.86 이다)
##
## 슬롯 힌트는 `limit=1` 로 불러 `[0]` 만 쓴다. 두 화면이 **같은 함수**를 쓴다 —
## 한쪽이 다른 답을 하면 플레이어는 어느 쪽도 믿지 못한다(`JamoBelt._show_slot_hint` 참고).
static func buildable_words_for(owned: Array[String], words: Array, limit := 6) -> Array:
	var candidates := words.filter(func(data): return not _tiles_for_word(str(data.get("word", "")), owned).is_empty())
	if candidates.is_empty():
		return candidates
	candidates.sort_custom(func(a, b): return _word_score(a) > _word_score(b))
	var pool := _keep_strong(candidates)
	var picked: Dictionary = pool[_pick_candidate(pool, owned)]
	var picked_word := str(picked.get("word", ""))
	var out: Array = [picked]
	for data in candidates:
		if out.size() >= limit:
			break
		if str(data.get("word", "")) == picked_word:
			continue
		out.append(data)
	return out


## DPS 1위의 `HINT_KEEP_RATIO` 이상인 후보만 남긴다.
##
## 바닥은 `_word_score` 가 아니라 **`word_value`(실제 DPS)** 로 잡는다 — `_word_score` 의
## tier 항(최대 +3 = 0.03 DPS)은 순위를 가르는 한 자리 보정일 뿐이고, 감독이 고른 대안 C 의
## 실측(기대 0.979 · 최악 0.800)도 DPS 로 잰 값이다. 그래야 측정과 코드가 같은 것을 말한다.
static func _keep_strong(candidates: Array) -> Array:
	var best_value := 0
	for data in candidates:
		best_value = maxi(best_value, word_value(str(data.get("word", "")), data))
	if best_value <= 0:
		return candidates
	var floor_value := int(round(float(best_value) * HINT_KEEP_RATIO))
	var pool: Array = []
	for data in candidates:
		if word_value(str(data.get("word", "")), data) >= floor_value:
			pool.append(data)
	return pool


## 봉지에서 만든 시드로 후보 하나를 고른다.
##
## ⚠️ 무작위는 **봉지가 정한다** — 같은 봉지는 같은 답이다. 이유 셋:
##   (1) 힌트는 **토글**이다(`_show_slot_hint`). 누를 때마다 답이 바뀌면 그건 힌트가 아니라
##       슬롯머신이고, 플레이어는 마음에 들 때까지 취소→힌트를 반복한다.
##   (2) 테스트·프로브가 결정적이어야 한다(이 저장소의 봇 결정성 규칙과 같다).
##   (3) `tests/test_tower_traits.gd` 의 슬롯 힌트 계약이 `buildable_words_for(...)[0]` 을
##       힌트의 목표와 **직접 비교**한다 — 결정적이지 않으면 그 테스트가 동전 던지기가 된다.
## 봉지가 다르면 시드가 달라져 **런마다 다른 타워**가 나온다 — 감독이 원한 다양성이다.
static func _pick_candidate(pool: Array, owned: Array) -> int:
	if pool.size() <= 1:
		return 0
	var tiles: Array = []
	for tile in owned:
		tiles.append(str(tile))
	# 타일 **순서**에 흔들리지 않게 정렬해서 넣는다 — 같은 봉지가 다른 순서로 와도 같은 답.
	tiles.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("".join(tiles))
	return rng.randi_range(0, pool.size() - 1)

static func best_word_set_for(owned: Array[String], words: Array, slot_count: int, profile := "overall") -> Array:
	# 프로필은 점수가 아니라 **후보**를 바꾼다. 가산점으로 만들면 그 값이 실제 세기
	# 차이를 앞지를 때 약한 단어를 1위로 올린다(위 PROFILE_CATEGORIES 주석 참고).
	var pool := words
	var favored: Array = PROFILE_CATEGORIES.get(profile, [])
	if not favored.is_empty():
		var narrowed: Array = words.filter(func(d): return str(d.get("category", "")) in favored)
		# 그 방향의 단어가 벨트에 없어 슬롯을 못 채우면 전체 후보로 돌아간다.
		# 빈 추천보다는 다른 방향이라도 보여 주는 게 낫다.
		if narrowed.size() >= slot_count: pool = narrowed
	var candidates := pool.filter(func(data): return not _tiles_for_word(str(data.get("word", "")), owned).is_empty())
	candidates.sort_custom(func(a, b):
		return _word_score(a) > _word_score(b)
	)
	# ponytail: cap recommendation candidates to keep the UI instant; widen after profiling if quality suffers.
	if candidates.size() > 60: candidates.resize(60)
	var states := [{"score": 0, "words": [], "tiles": owned}]
	for _slot in range(slot_count):
		var next_by_tiles := {}
		for state in states:
			for data in candidates:
				if state.words.any(func(chosen): return chosen.get("word", "") == data.get("word", "")): continue
				var matched := _tiles_for_word(str(data.get("word", "")), state.tiles)
				if matched.is_empty(): continue
				var unused: Array[String] = []
				for item in matched.unused: unused.append(item.tile)
				var sorted_unused := unused.duplicate()
				sorted_unused.sort()
				var key := "".join(sorted_unused)
				var next_state := {"score": int(state.score) + _word_score(data), "words": state.words + [data], "tiles": unused}
				if not next_by_tiles.has(key) or int(next_state.score) > int(next_by_tiles[key].score):
					next_by_tiles[key] = next_state
		if next_by_tiles.is_empty(): break
		states = next_by_tiles.values()
		states.sort_custom(func(a, b): return int(a.score) > int(b.score))
		# ponytail: fixed-width beam caps 30-tile optimization; widen if profiling shows quality loss.
		if states.size() > 24: states.resize(24)
	return states[0].words

static func strategic_sets_for(owned: Array[String], words: Array, slot_count: int) -> Array:
	var profiles := [
		{"id": "single", "name": "단일 화력", "counter": "방어·보스"},
		{"id": "area", "name": "광역 방어", "counter": "군집"},
		{"id": "control", "name": "둔화 중심", "counter": "빠른 적"}
	]
	for profile in profiles:
		profile["words"] = best_word_set_for(owned, words, slot_count, profile.id)
	return profiles

## 단어별 값어치 캐시(초당 피해 x100).
##
## `preview_stats` 는 AttackStyle 의 의미 키워드 스캔(문자열 수십 번)을 하므로,
## 빔 서치가 수천 번 부르는 자리에서 매번 다시 계산하면 힌트가 눈에 띄게 느려진다.
## 단어 DB 는 런 중에 바뀌지 않고 유물도 이 값에 들어가지 않으므로 캐시가 안전하다.
static var _value_cache: Dictionary = {}


## 단어 하나의 값어치 = **실제 타워가 내는 초당 피해**(x100, 정수 비교용).
##
## 예전에는 `tier * 1000 + data.damage` 였다. tier 는 음절 수와 같아서 '긴 단어 먼저'
## 라는 뜻이었고(그 방향 자체는 맞다), 동점을 가르는 것은 DB 의 `damage` 필드였다.
## 그런데 그 필드는 **게임이 읽지 않는다** — 발당 피해는 길이와 특성 배율이, 발수는
## 길이가, 간격은 특성과 길이가 정한다. 그래서 같은 음절 수 안의 순위가 사실상 동전
## 던지기가 됐다: 실측(tools/HintValueProbe.gd) 같은 음절 수 쌍 25,554개 중 **47.9%**
## 가 실제와 반대로 뽑혔고, 힌트가 뽑는 1위 마신검(73.7 DPS)보다 모루돌(112.0 DPS)이
## 1.5배 셌다.
##
## 디렉터가 잡은 사례: 지금 바늘(45.4 DPS)을 세워 뒀는데 힌트는 가루(9.5 DPS)를
## 목표로 세웠다. 가루의 db_damage 가 44 로 바늘의 22 보다 컸기 때문이다.
## **힌트가 '지금보다 약한 것' 을 목표로 세우면 힌트를 따르는 것이 손해가 된다.**
##
## 그래서 DPS 가 주(主)다. tier 는 DPS 가 **정확히 같을 때** 긴 단어를 고르는 한 자리
## 보정일 뿐이다 — 그마저도 실제 세기를 이기게 두면 위의 버그가 그대로 돌아온다.
static func word_value(word: String, data: Dictionary) -> int:
	if _value_cache.has(word):
		return int(_value_cache[word])
	var stats: Dictionary = WordTower.preview_stats(word, data)
	var value := int(round(float(stats["dps"]) * 100.0))
	_value_cache[word] = value
	return value


static func _word_score(data: Dictionary) -> int:
	return word_value(str(data.get("word", "")), data) + int(data.get("tier", 1))
