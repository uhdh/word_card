# CardSystem.gd
# 타일 덱, 손패, 3단 슬롯(초/중/종성), 단어 조합 평가 시스템
class_name CardSystem
extends RefCounted

var draw_pile: Array[String] = []
var hand: Array[Dictionary] = [] # Array of { "id": int, "char": String, "isRotatable": bool }
var discard_pile: Array[String] = []
var slots: Array = [null, null, null] # [cho, jung, jong]
var crafted_card: Dictionary = {}
var _tile_id_counter: int = 1

func init_deck(player_deck: Array[String]) -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	slots = [null, null, null]
	crafted_card = {}
	
	for c in player_deck:
		draw_pile.append(c)
	draw_pile.shuffle()

func draw(amount: int = 5) -> void:
	for i in range(amount):
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
		
		var c = draw_pile.pop_back()
		hand.append({
			"id": _tile_id_counter,
			"char": c,
			"isRotatable": HangulEngine.is_rotatable(c)
		})
		_tile_id_counter += 1

func draw_specific_pool(pool: Array) -> void:
	if pool.is_empty():
		return
	var c = pool.pick_random()
	hand.append({
		"id": _tile_id_counter,
		"char": c,
		"isRotatable": HangulEngine.is_rotatable(c)
	})
	_tile_id_counter += 1

func rotate_tile(tile_id: int) -> bool:
	for t in hand:
		if t["id"] == tile_id:
			if t["isRotatable"]:
				t["char"] = HangulEngine.rotate(t["char"])
				t["isRotatable"] = HangulEngine.is_rotatable(t["char"])
				SoundEngine.play_tile_rotate()
				return true
	return false

func combine_tiles(tile_id_1: int, tile_id_2: int) -> bool:
	var idx1 = -1
	var idx2 = -1
	for i in range(hand.size()):
		if hand[i]["id"] == tile_id_1: idx1 = i
		if hand[i]["id"] == tile_id_2: idx2 = i
	
	if idx1 == -1 or idx2 == -1 or idx1 == idx2:
		return false
	
	var char1 = hand[idx1]["char"]
	var char2 = hand[idx2]["char"]
	
	if not HangulEngine.can_combine(char1, char2):
		return false
	
	var result_char = HangulEngine.combine(char1, char2)
	# Remove higher index first
	if idx1 > idx2:
		hand.remove_at(idx1)
		hand.remove_at(idx2)
	else:
		hand.remove_at(idx2)
		hand.remove_at(idx1)
	
	hand.append({
		"id": _tile_id_counter,
		"char": result_char,
		"isRotatable": HangulEngine.is_rotatable(result_char)
	})
	_tile_id_counter += 1
	SoundEngine.play_tile_combine()
	return true

func place_tile_in_slot(tile_id: int) -> bool:
	var tile_idx = -1
	for i in range(hand.size()):
		if hand[i]["id"] == tile_id:
			tile_idx = i
			break
	if tile_idx == -1:
		return false
	
	var tile = hand[tile_idx]
	var c = tile["char"]
	
	# Determine slot type
	if HangulEngine.CHOSUNG.has(c) and slots[0] == null:
		slots[0] = tile
		hand.remove_at(tile_idx)
	elif HangulEngine.JUNGSUNG.has(c) and slots[1] == null:
		slots[1] = tile
		hand.remove_at(tile_idx)
	elif HangulEngine.JONGSUNG.has(c) and slots[2] == null and slots[0] != null and slots[1] != null:
		slots[2] = tile
		hand.remove_at(tile_idx)
	elif slots[0] == null:
		slots[0] = tile
		hand.remove_at(tile_idx)
	elif slots[1] == null:
		slots[1] = tile
		hand.remove_at(tile_idx)
	elif slots[2] == null:
		slots[2] = tile
		hand.remove_at(tile_idx)
	else:
		return false
	
	SoundEngine.play_tile_click()
	evaluate_slots()
	return true

func remove_tile_from_slot(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx > 2:
		return false
	if slots[slot_idx] == null:
		return false
	
	var tile = slots[slot_idx]
	slots[slot_idx] = null
	hand.append(tile)
	SoundEngine.play_tile_click()
	evaluate_slots()
	return true

func evaluate_slots() -> void:
	crafted_card = {}
	if slots[0] == null or slots[1] == null:
		return
	
	var cho = slots[0]["char"]
	var jung = slots[1]["char"]
	var jong = slots[2]["char"] if slots[2] != null else ""
	
	var syllable = HangulEngine.compose_syllable(cho, jung, jong)
	if syllable == "":
		return
	
	var data = WordDatabase.get_word_data(syllable)
	if not data.is_empty():
		crafted_card = data
		crafted_card["syllable"] = syllable
		crafted_card["hasJong"] = jong != ""
		SoundEngine.play_word_crafted()
	else:
		# Unknown syllable fallback (기본 3 타격)
		crafted_card = {
			"word": syllable,
			"name": syllable + " (미지의 활자)",
			"category": "weapon",
			"cost": 1,
			"damage": 3,
			"desc": "기본 활자 타격. 3의 물리 피해를 입힙니다.",
			"icon": "res://assets/01_무기_공격/sword_검/sword_1_32px_pastel.png",
			"sound": "play_attack",
			"syllable": syllable,
			"hasJong": jong != ""
		}

func consume_crafted_card() -> void:
	for s in slots:
		if s != null:
			discard_pile.append(s["char"])
	slots = [null, null, null]
	crafted_card = {}

func discard_hand_and_slots() -> void:
	for t in hand:
		discard_pile.append(t["char"])
	hand.clear()
	for s in slots:
		if s != null:
			discard_pile.append(s["char"])
	slots = [null, null, null]
	crafted_card = {}
