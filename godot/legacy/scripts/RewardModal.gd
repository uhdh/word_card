# RewardModal.gd
# 전투 승리 보상 모달
extends Control

@onready var gold_label: Label = $Panel/VBox/GoldLabel
@onready var relic_box: PanelContainer = $Panel/VBox/RelicBox
@onready var relic_label: Label = $Panel/VBox/RelicBox/RelicLabel
@onready var tiles_container: HBoxContainer = $Panel/VBox/TilesContainer
@onready var btn_skip: Button = $Panel/VBox/BtnSkip

var on_complete_cb: Callable

func setup(rewards: Dictionary, player: PlayerState, p_on_complete: Callable) -> void:
	on_complete_cb = p_on_complete
	gold_label.text = "🪙 +%d 골드를 획득했습니다." % rewards.get("gold", 0)

	var relic_drop = rewards.get("relicDrop")
	if relic_drop != null:
		relic_box.visible = true
		relic_label.text = "👑 희귀 유물 획득: %s" % str(relic_drop)
		player.relic_manager.add_relic(relic_drop)
	else:
		relic_box.visible = false

	for c in rewards.get("tileOptions", []):
		var btn = Button.new()
		btn.text = c
		btn.custom_minimum_size = Vector2(60, 70)
		btn.pressed.connect(func():
			player.deck.append(c)
			SoundEngine.play_word_crafted()
			queue_free()
			on_complete_cb.call()
		)
		tiles_container.add_child(btn)

	btn_skip.pressed.connect(func():
		queue_free()
		on_complete_cb.call()
	)
