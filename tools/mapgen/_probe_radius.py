# -*- coding: utf-8 -*-
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_pads as bp
from waypoints import PATHS

for r in (32.0, 34.0, 36.0, 38.0, 40.0, 42.0, 44.0):
    bp.PAD_R = r
    bp.SEP = r * 2.0 + 8.0   # 카드가 서로 붙지 않게
    line = []
    for name, pts in PATHS.items():
        slots, worst, pass1, poly, need = bp.build_slots(name, pts)
        line.append(f"{name}: n={len(slots):2d} pass1={pass1:2d} worst={worst:5.1f}")
    print(f"PAD_R={r:5.1f} SEP={bp.SEP:5.1f} | " + " | ".join(line))
