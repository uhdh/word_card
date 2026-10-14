# ActClearModal.gd
# 막 클리어 축하 모달 — **닫는 순간** 다음 막 웨이브가 시작된다.
#
# 왜 이렇게 바뀌었나 (2026-09-23):
# 예전에는 이 모달을 띄우는 줄 **바로 다음 줄**에서 다음 막 웨이브를 시작했다
# (`TowerDefenseMain._on_act_cleared`). 그래서 축하 문구를 읽는 동안 이미 적이 걷고
# 있었고, 480x260 중앙 패널이 경로의 S자 중간을 통째로 가렸다. 닫기 버튼도 없어서
# 유일한 탈출구가 3.0초 타이머였는데, 그 타이머는 `Engine.time_scale` 을 따르므로
# 4배속에서는 0.77초 만에 사라졌고 정지 중에는 아예 오지 않았다.
# (실측: `tools/PauseAbilityProbe.gd` — 3.0초 타이머가 @4x 에서 766ms)
#
# 이제 모달이 떠 있는 동안 **아무것도 움직이지 않는다** — 웨이브를 시작하지 않았으니
# 정지시킬 것도 없다. 다 읽고 닫으면 그때 시작한다.
#
# 씬(.tscn)을 두지 않은 이유: 내용을 전부 코드로 만든다. 레이아웃(중앙 정렬·등장 연출)은
# `TowerDefenseMain._show_modal` 이 소유하므로, 씬 파일에는 빈 PanelContainer 루트밖에
# 남을 것이 없다. (WaveRewardModal 은 Dim 오버레이 + 고정 크기 Panel 이 실제로 있어서 씬이다)
class_name ActClearModal
extends PanelContainer

var _on_dismiss: Callable = Callable()
var _closed := false

## 막 클리어 정보로 내용을 채운다. `on_dismiss` 는 **닫힐 때** 부를 것(다음 막 시작).
func setup(act: int, act_name: String, next_act: int, next_act_name: String, bonus_gold: int, on_dismiss: Callable) -> void:
	theme_type_variation = &"ModalPanel"
	custom_minimum_size = Vector2(480, 260)
	_on_dismiss = on_dismiss

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	add_child(vbox)

	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "제 %d막 완파 — %s" % [act, act_name]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.theme_type_variation = &"MutedLabel"
	# 문구가 계약이다. '시작' 은 버튼에만 적고, 본문은 **닫아야 시작된다**는 것만 말한다.
	# 예전 문구는 "제 N막 [..] 시작" 이었는데, 그때는 정말로 그 줄에서 시작했다.
	# ⚠️ 2026-10-06 (§2.27) — **`[SPACE]` 안내를 여기로 옮겼다.** 그 안내의 유일한 운반체가
	# 씬에서 `visible = false` 인 상단 `BtnStartWave` 의 툴팁이었는데(코드에 `.show()` 0건),
	# 플레이어는 그 문장을 **볼 수 없었다.** 이 모달이 Space 가 실제로 일하는 **유일한 순간**이다
	# (`TowerDefenseMain._on_start_wave_pressed` 참고) — 그래서 여기가 안내의 제자리다.
	desc.text = "막 보스를 물리치고 대보상을 획득했습니다!\n보너스 골드 +%d G · 주사위 +1 충전\n\n다음 막은 이 창을 닫으면 시작됩니다.\n단축키 [SPACE] 로도 닫힙니다." % [bonus_gold]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	var btn := Button.new()
	btn.text = "▶ 제 %d막 [%s] 시작" % [next_act, next_act_name]
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(_close)
	vbox.add_child(btn)

## 닫는다 — 그리고 **여기서** 다음 막을 시작한다.
##
## `DifficultyPlaytest._clear_modals()` 는 `has_method("_close")` 로 이 경로를 태운다.
## 봇이 다른 문(그냥 `queue_free`)으로 나가면 게이트가 재는 흐름이 실제 플레이와
## 달라지므로, 봇도 플레이어와 **같은 문**을 지나게 한다.
##
## 두 번 불려도 안전하다 — `_closed` 로 막고, 시작 자체도 `_start_wave_automatically()` 가
## `is_wave_running` 을 확인한다.
##
## Space 는 이 모달을 **우회하지 못한다.** `TowerDefenseMain` 이
## 그 입력을 여기(`_close`)로 보내기 때문이다 — 모달이 떠 있는 동안 다음 막을
## 시작하는 문은 이 하나뿐이다. (예전에는 둘 다 `_on_start_wave_pressed()` 로 직행해서
## 모달의 약속이 거짓이 되고, 모달 버튼은 `is_wave_running` 에 걸려 먹통이 됐다.)
func _close() -> void:
	if _closed:
		return
	_closed = true
	if _on_dismiss.is_valid():
		_on_dismiss.call()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.96, 0.96), 0.14)
	tween.tween_property(self, "modulate:a", 0.0, 0.14)
	tween.chain().tween_callback(queue_free)
