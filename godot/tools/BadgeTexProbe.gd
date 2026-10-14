# BadgeTexProbe.gd
# 특성 배지 텍스처가 **런타임에 실제로 무엇으로 로드되는지** 잰다.
#
# 왜 필요한가:
#   화면에는 타워 우상단에 22x22 순백 사각형이 뜨는데, 원본 PNG(assets/fx/badge_*.png)는
#   24x24 어두운 남색 원 + 색 아이콘이다. 크기(22)와 위치(우상단)가 WordTower.gd 의
#   `_draw_trait_badge_on` 과 소수점까지 일치하므로 그리는 주체는 확정이다.
#   그렇다면 **로드된 텍스처가 원본과 다른 것**이다 — 그걸 확인한다.
#
# 판정하지 않는다(보고 전용). 파일 존재/클래스/크기/포맷/픽셀을 그대로 찍는다.
extends Node

func _ready() -> void:
	var files: PackedStringArray = []
	var dir := DirAccess.open("res://assets/fx")
	if dir != null:
		for f in dir.get_files():
			if f.begins_with("badge_") and f.ends_with(".png"):
				files.append(f)
	files.sort()
	print("BADGE_PROBE 파일 %d개" % files.size())
	for f in files:
		var path := "res://assets/fx/" + f
		var exists: bool = ResourceLoader.exists(path)
		var res: Resource = load(path)
		if res == null:
			print("  %-32s exists=%s  LOAD_NULL" % [f, exists])
			continue
		var sz: Vector2 = res.get_size()
		var img: Image = null
		if res is Texture2D:
			img = (res as Texture2D).get_image()
		var desc := "image=null"
		if img != null:
			var iw := img.get_width()
			var ih := img.get_height()
			var pts: Array = [
				Vector2i(0, 0), Vector2i(iw - 1, 0), Vector2i(0, ih - 1),
				Vector2i(iw - 1, ih - 1), Vector2i(iw / 2, ih / 2), Vector2i(iw / 2, 1),
			]
			var parts: PackedStringArray = []
			for p in pts:
				parts.append("%s" % img.get_pixelv(p))
			desc = "img=%dx%d fmt=%d  %s" % [iw, ih, img.get_format(), " | ".join(parts)]
		print("  %-32s exists=%s class=%s size=%s  %s" % [f, exists, res.get_class(), sz, desc])
	print("BADGE_PROBE_DONE")
	get_tree().quit(0)
