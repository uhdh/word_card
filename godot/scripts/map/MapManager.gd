# MapManager.gd
# Slay the Spire 스타일 1막 15층 맵 노드 생성 및 분기 경로 이동
class_name MapManager
extends RefCounted

const ACT_1_NAME = "제 1막 : 흩어진 활자의 숲"
const MAX_FLOORS = 15

var act_name: String = ACT_1_NAME
var floors: Array = [] # Array of Arrays of node Dictionary
var current_floor: int = -1
var current_node_id: String = ""

func _init() -> void:
	generate_map()

func generate_map() -> void:
	floors.clear()
	current_floor = -1
	current_node_id = ""

	for f in range(MAX_FLOORS):
		var floor_nodes = []
		if f == 0:
			# Starting 1st floor (3 battle choices)
			floor_nodes = [
				_create_node(f, 0, "battle", "일반 전투", "⚔️"),
				_create_node(f, 1, "battle", "일반 전투", "⚔️"),
				_create_node(f, 2, "battle", "일반 전투", "⚔️")
			]
		elif f == MAX_FLOORS - 1:
			# Boss floor
			floor_nodes = [
				_create_node(f, 0, "boss", "1막 보스: 서예 골렘", "👹")
			]
		elif f == MAX_FLOORS - 2:
			# Rest before boss
			floor_nodes = [
				_create_node(f, 0, "rest", "휴식처 (모닥불)", "🔥")
			]
		elif f == 8:
			# Mid boss / treasure
			floor_nodes = [
				_create_node(f, 0, "elite", "엘리트 전투", "💀"),
				_create_node(f, 1, "rest", "휴식처", "🔥")
			]
		else:
			var count = 2 + (randi() % 2)
			for i in range(count):
				var r = randf()
				if r < 0.5:
					floor_nodes.append(_create_node(f, i, "battle", "일반 전투", "⚔️"))
				elif r < 0.7:
					floor_nodes.append(_create_node(f, i, "event", "신비한 비석", "📜"))
				elif r < 0.85:
					floor_nodes.append(_create_node(f, i, "shop", "활자 상점", "🛒"))
				else:
					floor_nodes.append(_create_node(f, i, "rest", "휴식처", "🔥"))
		floors.append(floor_nodes)

func _create_node(floor_idx: int, lane: int, type: String, name: String, icon: String) -> Dictionary:
	return {
		"id": "node_%d_%d" % [floor_idx, lane],
		"floor": floor_idx,
		"lane": lane,
		"type": type,
		"name": name,
		"icon": icon
	}

func get_available_next_nodes() -> Array:
	if current_floor == -1:
		return floors[0]
	var next_floor = current_floor + 1
	if next_floor >= floors.size():
		return []
	return floors[next_floor]

func select_node(node_id: String) -> Dictionary:
	var available = get_available_next_nodes()
	for n in available:
		if n["id"] == node_id:
			current_floor = n["floor"]
			current_node_id = n["id"]
			return n
	return {}
