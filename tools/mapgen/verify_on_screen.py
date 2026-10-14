# -*- coding: utf-8 -*-
"""실제 게임 스크린샷 위에 ACT_SLOTS(발판) / ACT_PATHS(길) 를 정확히 겹쳐 그린다.

좌표는 godot tools/Probe.tscn 이 출력한 실측값을 쓴다:
  field_pos=(28,74)  fit_scale=1.03409  fit_offset=(82.54547, 0)
  screen = field_pos + fit_offset + map * fit_scale

목적: "발판이 길에 겹치는가" 를 게임 화면에서 직접 확인.
"""
import json
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, r"E:\project\word_card\tools\mapgen")
from waypoints import MAPS, PATHS

ROOT = r"E:\project\word_card"
PAD_R = 26.0

# Probe 실측값 (1280x720 뷰포트)
FIELD_POS = (28.0, 74.0)
FIT_OFFSET = (82.54547, 0.0)
FIT_SCALE = 1.03409090909091


def m2s(p):
    return (FIELD_POS[0] + FIT_OFFSET[0] + p[0] * FIT_SCALE,
            FIELD_POS[1] + FIT_OFFSET[1] + p[1] * FIT_SCALE)


def main():
    layout = json.load(open(rf"{ROOT}\tools\mapgen\out\layout.json", encoding="utf-8"))
    for act in (1, 2, 3):
        shot = Image.open(rf"{ROOT}\_shot_act{act}.png").convert("RGB")
        vis = shot.copy()
        d = ImageDraw.Draw(vis, "RGBA")
        slots = layout[f"act{act}"]["slots"]
        rh = layout[f"act{act}"]["road_half"]
        path = PATHS[f"act{act}"]

        # 도로 밴드(반폭 rh) — 실제 길이 차지하는 영역
        for i in range(len(path) - 1):
            d.line([m2s(path[i]), m2s(path[i + 1])],
                   fill=(255, 40, 40, 90), width=int(rh * 2 * FIT_SCALE))
        d.line([m2s(p) for p in path], fill=(255, 255, 0, 230), width=2, joint="curve")

        worst = 1e9
        for i, p in enumerate(slots):
            x, y = m2s(p)
            r = PAD_R * FIT_SCALE
            d.ellipse([x - r, y - r, x + r, y + r], outline=(0, 255, 255, 255), width=3)
            d.text((x - 6, y - 8), str(i + 1), fill=(255, 255, 0, 255))
        vis.save(rf"{ROOT}\tools\mapgen\out\verify_act{act}.png")
        print(f"act{act}: pads={len(slots)} road_half={rh} -> out/verify_act{act}.png")


main()
