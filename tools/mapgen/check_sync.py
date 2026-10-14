#!/usr/bin/env python
# tools/mapgen/check_sync.py
#
# build_pads.py 가 만든 out/layout.json 과, 실제로 게임이 쓰는
# godot/scripts/tower/DefenseField.gd 의 ACT_PATHS / ACT_SLOTS 가 일치하는지 검사한다.
#
# 왜 필요한가:
#   이 파이프라인의 결과물은 '손으로 복사' 되어 DefenseField.gd 에 들어간다.
#   누군가 맵 아트를 고치고 build_pads.py 만 다시 돌린 뒤 복사를 빠뜨리면,
#   발판이 옛 길에 남아 타워가 길 위에 서거나 죽은 자리에 놓인다.
#   (실제로 2026-09-17 에 3막 경로를 전체 폭으로 바꾸면서 이 위험이 생겼다)
#
#   PY=~/.workbuddy-ai/binaries/python/envs/default/Scripts/python.exe
#   cd tools/mapgen && $PY check_sync.py
#
# 종료 코드: 0 = 일치, 1 = 불일치(또는 파싱 실패)

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LAYOUT = os.path.join(HERE, "out", "layout.json")
FIELD = os.path.normpath(os.path.join(HERE, "..", "..", "godot", "scripts", "tower", "DefenseField.gd"))

# layout.json 의 키 -> GDScript 상수 이름
PAIRS = (("slots", "ACT_SLOTS"), ("path", "ACT_PATHS"))

# 좌표는 소수 첫째 자리까지 적히므로 반올림 오차를 허용한다.
TOLERANCE = 0.6


def read_const_block(src, name):
    """`const NAME: Dictionary = { ... \n}` 본문을 뽑는다."""
    pattern = r"const " + name + r"(?:\s*:\s*Dictionary)?\s*=\s*\{(.*?)\n\}"
    match = re.search(pattern, src, re.S)
    return match.group(1) if match else None


def parse_acts(block):
    """{1: [(x,y), ...], 2: [...], 3: [...]} 로 파싱한다."""
    acts = {}
    for match in re.finditer(r"(\d+)\s*:\s*\[(.*?)\n\t\],", block, re.S):
        act = int(match.group(1))
        points = re.findall(r"Vector2\(([-\d\.]+),\s*([-\d\.]+)\)", match.group(2))
        acts[act] = [(float(x), float(y)) for x, y in points]
    return acts


def main():
    for path in (LAYOUT, FIELD):
        if not os.path.exists(path):
            print("missing file: %s" % path)
            return 1

    with open(LAYOUT, encoding="utf-8") as handle:
        layout = json.load(handle)
    with open(FIELD, encoding="utf-8") as handle:
        src = handle.read()

    ok = True
    for key, const in PAIRS:
        block = read_const_block(src, const)
        if block is None:
            print("DefenseField.gd: const %s not found (did it get renamed?)" % const)
            ok = False
            continue

        compiled = parse_acts(block)
        if not compiled:
            print("DefenseField.gd: could not parse %s (format changed?)" % const)
            ok = False
            continue

        for act in (1, 2, 3):
            act_key = "act%d" % act
            if act_key not in layout:
                print("layout.json: %s missing" % act_key)
                ok = False
                continue

            reference = layout[act_key].get(key)
            if reference is None:
                print("layout.json: %s.%s missing" % (act_key, key))
                ok = False
                continue

            reference = [(float(p[0]), float(p[1])) for p in reference]
            actual = compiled.get(act, [])

            if len(reference) != len(actual):
                print("%-9s act%d  layout=%2d  gd=%2d  COUNT MISMATCH"
                      % (const, act, len(reference), len(actual)))
                ok = False
                continue

            drifted = [
                i for i, ((rx, ry), (ax, ay)) in enumerate(zip(reference, actual))
                if abs(rx - ax) >= TOLERANCE or abs(ry - ay) >= TOLERANCE
            ]
            if drifted:
                print("%-9s act%d  layout=%2d  gd=%2d  DRIFT at indices %s"
                      % (const, act, len(reference), len(actual), drifted[:6]))
                ok = False
            else:
                print("%-9s act%d  layout=%2d  gd=%2d  ok" % (const, act, len(reference), len(actual)))

    print()
    if ok:
        print("in sync: out/layout.json == DefenseField.gd")
        return 0
    print("OUT OF SYNC — re-run build_pads.py and copy the result into DefenseField.gd")
    return 1


if __name__ == "__main__":
    sys.exit(main())
