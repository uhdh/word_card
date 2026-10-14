# -*- coding: utf-8 -*-
"""경로를 피해 고르게 퍼진 타워 발판 좌표를 만든다 (v3).

v1 실패: `dist_to_poly(q) >= 48` — 중심선 기준 고정값.
  act2 레일 폭 ~61px, act3 룬길 폭 ~39px 이라 48px 도 도로 위였다.
  → 사용자 신고: "타워 위치가 길에 겹쳐"

v2 실패: 색 추출 리본 마스크에 의존.
  act3 의 룬길은 라벤더 석재 플랫폼과 색이 비슷해 전파(propagation)가
  플랫폼 전체로 번졌다. 리본이 실제 도로보다 훨씬 넓어져
  발판이 중앙을 못 쓰고 맵 구석으로 밀려났다.

v3 해법: 게임이 실제로 걷는 대상 = DefenseField 의 Path2D(= ACT_PATHS) 다.
  색 추출 대신 '손으로 검증한 웨이포인트 폴리라인'에서의 거리로 막는다.
  필요한 거리 = 도로 반폭 + 발판 반지름 + 여유(8px)  ← 막별로 계산
  → 어떤 막에서도 기하학적으로 절대 겹치지 않는다.
"""
import json
import math

import numpy as np
from PIL import Image, ImageDraw

from waypoints import MAPS, PATHS

PAD_R = 32.0        # 발판/타워 카드 반지름(px) — WordTower.tscn 64x64 와 동일
GAP = 8.0           # 발판 가장자리 ↔ 도로 가장자리 최소 여유
MARGIN = 34.0       # 맵 가장자리 여유
SEP = 72.0          # 발판끼리 최소 간격 (64px 카드가 서로 붙지 않게)
# 발판 중심에서 도로 중심선까지의 최대 거리.
# 예전 값은 need + 132 였는데(act3 기준 194px) 타워 사거리는 150px 밖에 안 된다 —
# 그래서 '사거리가 길에 전혀 닿지 않는' 발판이 생겼다.
# (실측: 3막 (962,58) 이 끊긴 다리 너머에서 통과 — 길까지 194px)
# 사거리와 정확히 일치시킨다. WordTower.BASE_ATTACK_RANGE 와 같은 값이어야 한다.
MAX_DIST_FROM_ROAD = 150.0
# 이 발판 하나가 사거리 안에 담아야 하는 최소 경로 길이(px).
# 거리 상한만으로는 부족하다 — 3막은 끊긴 다리 너머 우측 플랫폼도
# 경로 끝에서 120~146px 라서 통과했는데, 실제로 덮는 경로는 30px 도 안 됐다.
# (경로 길이 기준으로 막으면 그런 '사거리 밖 발판' 이 정확히 걸러진다)
MIN_PAD_COVERAGE = 70.0
WANT = 11           # 맵당 발판 수 (DefenseField.MAX_SLOT_COUNT)
MAP_W, MAP_H = 1024.0, 352.0

# 막별 '칠해진 도로' 반폭(px). extract_paths 로 측정한 리본 코어 기준.
ROAD_HALF = {"act1": 23.0, "act2": 31.0, "act3": 22.0}

# 막별 '보이드(밟을 수 없는 배경)' 로 볼 휘도 상한.
# 기존 검사(patch.mean() >= lum_ref*0.46)만으로는 3막에서 부족하다 —
# 3막은 맵의 30% 가 우주 배경(lum≈40)이고 lum_ref=104 라서 48.0 이 문턱인데,
# 배경+가장자리가 조금 섞인 64px 원판은 평균이 48 을 넘겨 통과해 버린다.
# (실측: 패드 (175.7,39.5) 가 허공에 놓였다)
# 막별 휘도 분포 — act1 p10=58.7 / act2 p10=18.7 / act3 보이드 군집 39.7~43.0.
VOID_LUM = {"act1": 40.0, "act2": 15.0, "act3": 62.0}
MAX_VOID_FRACTION = 0.15


def resample(pts, step=2.5):
    out = []
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        seg = math.hypot(x1 - x0, y1 - y0)
        n = max(1, int(seg / step))
        for k in range(n):
            t = k / n
            out.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
    out.append(pts[-1])
    return out


def total_length(pts):
    return sum(math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1])
               for i in range(len(pts) - 1))


def point_normal_at(pts, s):
    acc = 0.0
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        seg = math.hypot(x1 - x0, y1 - y0)
        if acc + seg >= s and seg > 0.0:
            t = (s - acc) / seg
            return ((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t),
                    (-(y1 - y0) / seg, (x1 - x0) / seg))
        acc += seg
    return pts[-1], (0.0, 1.0)


def dist_to_poly(p, poly):
    px, py = p
    best = 1e9
    for (x, y) in poly:
        d = (x - px) ** 2 + (y - py) ** 2
        if d < best:
            best = d
    return math.sqrt(best)


def covered_length(pad, poly, reach):
    """pad 중심에서 reach 안에 들어오는 경로 길이(px). 단일 발판 기준(합집합 아님).

    주의: '양 끝점 중 하나라도 사거리 안' 으로 세면 과대평가된다 —
    긴 선분의 끝만 스쳐도 선분 전체를 세기 때문. 선분의 최근접점으로 판정한다.
    """
    total = 0.0
    for i in range(len(poly) - 1):
        ax, ay = poly[i]
        bx, by = poly[i + 1]
        dx, dy = bx - ax, by - ay
        l2 = dx * dx + dy * dy
        if l2 <= 0.0:
            t = 0.0
        else:
            t = max(0.0, min(1.0, ((pad[0] - ax) * dx + (pad[1] - ay) * dy) / l2))
        px, py = ax + t * dx, ay + t * dy
        if (px - pad[0]) ** 2 + (py - pad[1]) ** 2 <= reach * reach:
            total += math.sqrt(l2)
    return total


def build_slots(name, pts, want=WANT):
    img = Image.open(MAPS[name]).convert("RGB")
    lum = np.array(img).astype(np.float32).mean(axis=2)
    lum_ref = float(np.percentile(lum, 60))  # 배경 대표 밝기(상대 기준)

    poly = resample(pts, 2.5)
    need = ROAD_HALF[name] + PAD_R + GAP
    total = total_length(pts)

    def ok(q):
        x, y = q
        if not (MARGIN <= x <= MAP_W - MARGIN and MARGIN <= y <= MAP_H - MARGIN):
            return False
        d = dist_to_poly(q, poly)
        # 도로와 절대 겹치지 않을 것 + 사거리 안에 있을 것
        if d < need or d > MAX_DIST_FROM_ROAD:
            return False
        gx, gy = int(round(x)), int(round(y))
        y0, y1 = max(0, gy - int(PAD_R)), min(lum.shape[0], gy + int(PAD_R) + 1)
        x0, x1 = max(0, gx - int(PAD_R)), min(lum.shape[1], gx + int(PAD_R) + 1)
        patch = lum[y0:y1, x0:x1]
        if patch.size == 0:
            return False
        if patch.mean() < lum_ref * 0.46:
            return False
        # 허공(보이드) 위에 놓이지 않게 한다. 발판 원판의 15% 넘게 보이드면 탈락.
        void_ratio = float((patch < VOID_LUM[name]).mean())
        if void_ratio > MAX_VOID_FRACTION:
            return False
        # 사거리 안에 의미 있는 길이가 들어와야 한다.
        return covered_length(q, poly, MAX_DIST_FROM_ROAD) >= MIN_PAD_COVERAGE

    pads = []

    def try_place(q):
        if not ok(q):
            return False
        if any(math.hypot(q[0] - r[0], q[1] - r[1]) < SEP for r in pads):
            return False
        pads.append(q)
        return True

    # ── 1차: 경로를 want 등분한 각 구간 중앙, 도로 양옆에 최대한 붙여 놓는다.
    offsets = (0.0, 10.0, 22.0, 36.0, 52.0, 70.0, 92.0, 118.0)
    step = total / want
    s = step * 0.5
    k = 0
    guard = 0
    while len(pads) < want and s < total and guard < 600:
        guard += 1
        (px, py), (nx, ny) = point_normal_at(pts, s)
        prefer = 1.0 if k % 2 == 0 else -1.0
        placed = False
        for sgn in (prefer, -prefer):
            for off in offsets:
                r = need + off
                if try_place((px + nx * r * sgn, py + ny * r * sgn)):
                    placed = True
                    break
            if placed:
                break
        k += 1
        s += step if placed else step * 0.25

    # ── 2차: 아직 모자라면 유효 격자에서 최원거리 샘플링으로 채운다.
    pass1 = len(pads)
    if len(pads) < want:
        cand = []
        for gy in range(int(MARGIN), int(MAP_H - MARGIN), 8):
            for gx in range(int(MARGIN), int(MAP_W - MARGIN), 8):
                q = (float(gx), float(gy))
                if ok(q):
                    cand.append(q)
        while len(pads) < want and cand:
            best, best_d = None, -1.0
            for q in cand:
                d = min((math.hypot(q[0] - r[0], q[1] - r[1]) for r in pads), default=1e9)
                if d > best_d:
                    best, best_d = q, d
            if best is None or best_d < SEP:
                break
            pads.append(best)
            cand = [c for c in cand if math.hypot(c[0] - best[0], c[1] - best[1]) >= SEP]

    # ── 검증: 모든 발판의 '도로 가장자리까지' 실제 여유(px)
    gaps = [dist_to_poly(q, poly) - ROAD_HALF[name] - PAD_R for q in pads]
    worst = min(gaps) if gaps else -1.0
    return ([(round(x, 1), round(y, 1)) for x, y in pads], worst, pass1, poly, need)


def main():
    out = {}
    for name, pts in PATHS.items():
        slots, worst, pass1, poly, need = build_slots(name, pts)
        out[name] = {
            "path": pts,
            "slots": slots,
            "road_half": ROAD_HALF[name],
            "min_edge_gap": round(worst, 1),
        }
        img = Image.open(MAPS[name]).convert("RGB")
        # 위험 밴드(도로 반폭 + 발판 반지름 + 여유)를 붉게 덮어 시각 검증
        vis = np.array(img).astype(np.float32)
        h, w = vis.shape[:2]
        yy, xx = np.mgrid[0:h, 0:w]
        blocked = np.zeros((h, w), bool)
        for i in range(len(poly) - 1):
            ax, ay = poly[i]
            bx, by = poly[i + 1]
            dx, dy = bx - ax, by - ay
            L2 = dx * dx + dy * dy
            if L2 <= 0:
                continue
            t = np.clip(((xx - ax) * dx + (yy - ay) * dy) / L2, 0.0, 1.0)
            px = ax + t * dx
            py = ay + t * dy
            blocked |= ((xx - px) ** 2 + (yy - py) ** 2) < need * need
        vis[blocked] = vis[blocked] * 0.30 + np.array([255, 40, 40], np.float32) * 0.70
        vis[~blocked] = vis[~blocked] * 0.88 + np.array([0, 255, 120], np.float32) * 0.12
        img = Image.fromarray(vis.astype(np.uint8))
        d = ImageDraw.Draw(img, "RGBA")
        d.line(pts, fill=(255, 255, 0, 170), width=2, joint="curve")
        for i, (x, y) in enumerate(slots):
            d.ellipse([x - PAD_R, y - PAD_R, x + PAD_R, y + PAD_R],
                      outline=(0, 255, 255, 255), width=2)
            d.text((x - 4, y - 7), str(i + 1), fill=(255, 255, 0, 255))
        sx, sy = pts[0]
        ex, ey = pts[-1]
        d.ellipse([sx - 14, sy - 14, sx + 14, sy + 14], outline=(255, 0, 255, 255), width=3)
        d.ellipse([ex - 14, ey - 14, ex + 14, ey + 14], outline=(120, 255, 120, 255), width=3)
        img.save(rf"E:\project\word_card\tools\mapgen\out\pads_{name}.png")
        print(f"{name}: pads={len(slots)} (경로변={pass1}) road_half={ROAD_HALF[name]} "
              f"need={need:.0f} min_edge_gap={worst:.1f}px")
        print("   ", " ".join("(%g,%g)" % p for p in slots))
    with open(r"E:\project\word_card\tools\mapgen\out\layout.json", "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print("saved out/layout.json")


if __name__ == "__main__":
    main()
