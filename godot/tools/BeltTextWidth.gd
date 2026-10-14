extends Node
# 벨트 헤더의 미리보기 라벨이 **실제로 몇 px 인지** 재고, 후보 문장이 그 안에 들어가는지 본다.
#
#   godot --path . res://tools/BeltTextWidth.tscn
#   godot --path . res://tools/BeltTextWidth.tscn -- text=최적 조합: 지금 41.0 → 54.3 DPS
#
# 왜 필요한가: 이 라벨은 `clip_text = true` 라 넘치면 **조용히 잘린다.** 예외도 경고도 없다.
# 실제로 긴 문장이 '회색 1개는 이 단어에 안 쓰임' 을 화면 밖으로 밀어낸 적이 있고,
# 그래서 힌트 한 줄이 '행동만' 쓰도록 줄어든 적이 있다. 눈으로 "들어가 보인다" 는
# 판단은 두 번 틀렸다.
#
# **헤더 폭은 버튼 개수에 따라 달라진다.** 유물(훈민정음의 나침반)을 사면 '전체 힌트'
# 버튼이 붙어 라벨이 좁아지는데, 그 줄은 **유물을 산 사람에게만** 보인다. 그래서
# 벨트만 단독으로 띄워 재면 실제보다 넓은 자리에서 재게 되어 거짓 통과가 난다.
# 이 도구는 전체 씬을 띄우고, 유물이 있을 때와 없을 때를 **둘 다** 잰다.

const MainScene = preload("res://scenes/TowerDefenseMain.tscn")

## 아무것도 안 줬을 때 재 볼 문장들. 벨트 헤더가 실제로 쓰는 형식들이다.
##
## **여기 적는 문장은 '도달 가능한 것' 이어야 한다.** 손으로 만든 최악값을 넣으면
## 도구가 거짓 경보를 낸다 — 실제로 그렇게 한 번 속았다. 아래 '3음절 + 다섯 조각'
## 문장은 545 px 로 '잘림' 이라 찍혔지만, 등록 단어 6810개 조합을 겨냥해 훑어도
## 도달 가능한 최장 줄은 **428 px** 였다(유물 보유 479 px 안에 51 px 여유).
## 슬롯 힌트는 색의 '행동' 만 말하도록 이미 한 번 줄여 둔 문장이라 그 이상 못 길어진다.
## 그래서 아래 목록은 **관측된 실제 최장값** 을 쓴다.
const DEFAULT_CANDIDATES: Array = [
	"자동 완성 타워: [감 타워]  >  [날 타워]  >  [굴 타워]",
	"최적 조합: 지금 배치 그대로 완성 (54.3 DPS)",
	"최적 조합: 지금 41.0 → 54.3 DPS  (회전 6 · 이동 1)",
	"최적 조합: 최고 54.3 DPS  (회전 6 · 이동 1)",
	# 네 자리 DPS + 세 종류의 손볼 타일이 다 있는 경우 (합성 상한 — 실제로는 더 짧다)
	"최적 조합: 지금 1234.5 → 2345.6 DPS  (회전 12 · 이동 6 · 제외 3)",
	"최적 조합: 지금 배치 그대로 완성 (2345.6 DPS)",
	# 슬롯 힌트 한 줄 (이 라벨을 공유한다). 관측된 최장 형태.
	"1번 목표 1음절  ·  파랑 1개 ↻  ·  금색 1개 이동  ·  회색 10개 제외",
	# 사전 단어를 못 세울 때의 두 형태. 아래쪽은 슬롯이 '미지의 활자' 를 세운 경우다
	# (도달 가능: 봉지 15종 1~5장 전수 15503개 중 1462건). 위쪽이 그보다 길다.
	"1번 슬롯: 지금 타일로 만들 수 있는 단어가 없어요",
	"1번 슬롯: 가 (미지의 활자) — 기본 탄환만 나가요",
]

var _candidates: Array = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("text="):
			_candidates.append(a.split("=", true, 1)[1])
	if _candidates.is_empty():
		_candidates = DEFAULT_CANDIDATES.duplicate()

	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var belt = main.find_child("JamoBelt", true, false)
	var field = main.find_child("DefenseField", true, false)

	# 유물이 있을 때 / 없을 때를 둘 다 잰다. 유물이 헤더 버튼을 하나 더 붙이므로
	# 라벨은 유물이 있을 때가 가장 좁다 — 그 줄은 유물을 산 사람만 보는 줄이다.
	for relic_case in [false, true]:
		field.relic_ids.clear()
		if relic_case:
			field.relic_ids.append("relic_initial_compass")
		belt.set_relics(field.relic_ids)
		belt.render_belt()
		await get_tree().process_frame
		_measure(belt.parsed_preview_label, "유물 %s" % ("있음" if relic_case else "없음"))

	get_tree().quit(0)

func _measure(label: Label, title: String) -> void:
	var font: Font = label.get_theme_font("font")
	var fsize: int = label.get_theme_font_size("font_size")
	var limit: float = label.size.x
	print("── %s ── 라벨 폭 %.1f px · 폰트 %s %d · clip=%s" % [
		title, limit, font.get_font_name(), fsize, str(label.clip_text)])
	for c in _candidates:
		var text := str(c)
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var mark := "OK  " if w <= limit else "잘림"
		var margin := "여유 %.0f px" % (limit - w) if w <= limit else "%.0f px 초과" % (w - limit)
		print("   %s %6.1f px (%s)  %s" % [mark, w, margin, text])
