# DeckModal.gd
# 덱 보기 모달
extends Control

@onready var deck_grid: GridContainer = $Panel/VBox/Scroll/DeckGrid
@onready var btn_close: Button = $Panel/VBox/BtnClose
@onready var title_label: Label = $Panel/VBox/TitleLabel

func setup(deck: Array[String]) -> void:
	title_label.text = "현재 자모 덱 (%d장)" % deck.size()
	btn_close.pressed.connect(func(): queue_free())

	for c in deck:
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(50, 60)
		var lbl = Label.new()
		lbl.text = c
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(lbl)
		deck_grid.add_child(panel)
