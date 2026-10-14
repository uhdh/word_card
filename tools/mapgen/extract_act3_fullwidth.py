# -*- coding: utf-8 -*-
"""3막(천공성) 전폭 경로 추출 v2.

v1 실패: 돌바닥 전체의 최장 지오데시를 쓰면 **중앙 룬길을 무시하고**
  석재 플랫폼을 가로질러 직선으로 질러간다. 또 우측 다리가 별도 연결요소라
  x=800 에서 끊겼다.

v2 해법: 3조각으로 나눠 붙인다.
  1) 중앙 = 시안 룬길(칠해진 도로)의 최장 지오데시 — 게임의 '진짜 길'
  2) 좌측 연장 = 룬길 왼쪽 끝에서 **좌측 상단 섬**(SPAWN_TARGET)까지 돌바닥 지오데시
  3) 우측 연장 = 룬길 오른쪽 끝에서 **우측 돌난간**(BASE_TARGET)까지
  → 좌(역순) + 중앙 + 우 로 이어 붙이고 스무딩.

'가장 왼쪽/오른쪽 점' 을 목표로 삼으면 안 된다 — 스켈레톤이 플랫폼 위쪽
가장자리를 타고 돌아가 경로가 계단처럼 꺾인다. 목표를 손으로 찍어 준다.

주의: 우측 상단/하단 플랫폼은 **끊긴 다리** 너머의 별도 연결요소다
(실측: 중앙 연결요소와 40px 보이드 간격). 아트에 없는 길을 만들 수 없으므로
경로는 우측 돌난간(x≈818)에서 끝난다. 그래도 맵 폭의 80% 를 쓴다.

출력: out/act3_fullwidth.json + out/act3_fullwidth.png
"""
import json
import math
from collections import deque

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from skimage.morphology import skeletonize

MAP = r"E:\project\word_card\godot\assets\map\map_act3_sky_citadel_td_1024x352.png"
OUT_JSON = r"E:\project\word_card\tools\mapgen\out\act3_fullwidth.json"
OUT_PNG = r"E:\project\word_card\tools\mapgen\out\act3_fullwidth.png"

NBR8 = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]

# 손으로 찍은 목표점 (아트에서 확인). 좌 = 스폰, 우 = 기지.
SPAWN_TARGET = (30, 95)
BASE_TARGET = (815, 168)
# 워커블 마스크를 닫을 반복 횟수. 2 면 좌측 섬과 중앙이 한 연결요소가 된다(실측).
CLOSE_ITER = 2


def channels(a):
    r = a[:, :, 0].astype(np.int32)
    g = a[:, :, 1].astype(np.int32)
    b = a[:, :, 2].astype(np.int32)
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    return r, g, b, mx, mn, lum


def rune_road(a):
    """칠해진 룬길(시안 발광)."""
    r, g, b, mx, mn, lum = channels(a)
    seed = ((g - r) > 35) & ((b - r) > 45) & (g > 150) & (b > 165)
    loose = ((g - r) > 15) & ((b - r) > 25) & (g > 90) & (b > 110)
    s = ndimage.binary_dilation(seed, np.ones((3, 3)), iterations=3)
    p = ndimage.binary_propagation(s, mask=loose)
    p = ndimage.binary_closing(p, np.ones((3, 3)), iterations=4)
    p = ndimage.binary_opening(p, np.ones((3, 3)), iterations=1)
    lab, n = ndimage.label(p, np.ones((3, 3)))
    if n == 0:
        return p
    sizes = ndimage.sum(p, lab, range(1, n + 1))
    return lab == (int(np.argmax(sizes)) + 1)


def stone_floor(a):
    """밝은 석재 바닥(플랫폼/다리). 금색 구조물은 채도가 높아 제외된다."""
    r, g, b, mx, mn, lum = channels(a)
    stone = (lum > 118) & ((mx - mn) < 62)
    stone = ndimage.binary_opening(stone, np.ones((3, 3)), iterations=1)
    return stone


def bfs(start, pts, stop_fn=None):
    dist = {start: 0}
    prev = {}
    q = deque([start])
    while q:
        cur = q.popleft()
        cy, cx = cur
        for dy, dx in NBR8:
            nb = (cy + dy, cx + dx)
            if nb in pts and nb not in dist:
                dist[nb] = dist[cur] + 1
                prev[nb] = cur
                q.append(nb)
    return dist, prev


def geodesic(pts, start, target):
    dist, prev = bfs(start, pts)
    if target not in dist:
        return None
    path = []
    cur = target
    while cur != start:
        path.append((cur[1], cur[0]))
        cur = prev[cur]
    path.append((start[1], start[0]))
    path.reverse()
    return path


def farthest_on_side(pts, start, side):
    """start 에서 닿는 점 중 side='L' 이면 가장 왼쪽, 'R' 이면 가장 오른쪽."""
    dist, prev = bfs(start, pts)
    best, best_key = None, None
    for (y, x) in dist:
        if side == "L":
            key = (-x, dist[(y, x)])
        else:
            key = (x, dist[(y, x)])
        if best_key is None or key > best_key:
            best_key, best = key, (y, x)
    return best


def rdp(points, eps):
    if len(points) < 3:
        return points
    (x1, y1), (x2, y2) = points[0], points[-1]
    dx, dy = x2 - x1, y2 - y1
    norm = math.hypot(dx, dy)
    dmax, idx = -1.0, 0
    for i in range(1, len(points) - 1):
        x0, y0 = points[i]
        d = math.hypot(x0 - x1, y0 - y1) if norm == 0 else abs(dy * x0 - dx * y0 + x2 * y1 - y2 * x1) / norm
        if d > dmax:
            dmax, idx = d, i
    if dmax > eps:
        return rdp(points[:idx + 1], eps)[:-1] + rdp(points[idx:], eps)
    return [points[0], points[-1]]


def skeleton_points(mask):
    sk = skeletonize(mask)
    ys, xs = np.nonzero(sk)
    return set(zip(ys.tolist(), xs.tolist()))


def despike(pts, max_turn_deg=95.0, passes=6):
    """스켈레톤이 만드는 '가시' 를 제거한다.

    돌기둥/아치 위로 스켈레톤 가지가 뻗으면 경로가 잠깐 위로 갔다가 되돌아온다
    (실측: (319,134) → (321,108) → (325,135) — 26px 왕복).
    진행 방향이 max_turn_deg 이상 꺾이는 중간점을 반복 제거한다.
    """
    out = list(pts)
    for _ in range(passes):
        if len(out) < 3:
            break
        keep = [out[0]]
        removed = False
        for i in range(1, len(out) - 1):
            ax, ay = out[i][0] - keep[-1][0], out[i][1] - keep[-1][1]
            bx, by = out[i + 1][0] - out[i][0], out[i + 1][1] - out[i][1]
            na, nb = math.hypot(ax, ay), math.hypot(bx, by)
            if na < 1e-6 or nb < 1e-6:
                removed = True
                continue
            cosang = max(-1.0, min(1.0, (ax * bx + ay * by) / (na * nb)))
            if math.degrees(math.acos(cosang)) > max_turn_deg:
                removed = True
                continue
            keep.append(out[i])
        keep.append(out[-1])
        out = keep
        if not removed:
            break
    return out


def smooth(dense, radius=5):
    out = []
    for i in range(len(dense)):
        lo, hi = max(0, i - radius), min(len(dense), i + radius + 1)
        xs_ = [p[0] for p in dense[lo:hi]]
        ys_ = [p[1] for p in dense[lo:hi]]
        out.append((sum(xs_) / len(xs_), sum(ys_) / len(ys_)))
    return out


def densify(pts, step=6.0):
    out = []
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        d = math.hypot(x1 - x0, y1 - y0)
        n = max(1, int(d / step))
        for k in range(n):
            out.append((x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n))
    out.append(pts[-1])
    return out


def main():
    img = Image.open(MAP).convert("RGB")
    a = np.array(img)
    h, w = a.shape[:2]

    road = rune_road(a)
    stone = stone_floor(a)
    # 룬길도 걸을 수 있는 바닥으로 친다 (연결성 확보)
    walk = ndimage.binary_closing(stone | road, np.ones((5, 5)), iterations=CLOSE_ITER)
    lab, n = ndimage.label(walk, np.ones((3, 3)))
    sizes = ndimage.sum(walk, lab, range(1, n + 1))
    walk = lab == (int(np.argmax(sizes)) + 1)
    print("walkable components:", n, "largest px:", int(sizes.max()))
    pts = skeleton_points(walk)

    road_pts = skeleton_points(road)
    if not road_pts:
        print("NO ROAD")
        return
    # 룬길의 최장 지오데시 = 중앙 구간
    a0 = next(iter(road_pts))
    d0, _ = bfs(a0, road_pts)
    far1 = max(d0, key=lambda k: d0[k])
    mid = geodesic(road_pts, far1, farthest_on_side(road_pts, far1, "R"))
    if mid is None:
        print("NO MID")
        return
    mx0 = min(p[0] for p in mid)
    mx1 = max(p[0] for p in mid)
    print("road span x:", mx0, "->", mx1, "pts:", len(mid))

    # 룬길 양 끝점과 가장 가까운 '걸을 수 있는' 스켈레톤 점을 시작점으로
    def nearest_walk(pt):
        best, bd = None, 1e9
        for (y, x) in pts:
            d = (x - pt[0]) ** 2 + (y - pt[1]) ** 2
            if d < bd:
                bd, best = d, (y, x)
        return best

    def nearest_walk_to(pt):
        return nearest_walk(pt)

    left_start = nearest_walk(mid[0])
    right_start = nearest_walk(mid[-1])
    left_goal = nearest_walk(SPAWN_TARGET)
    right_goal = nearest_walk(BASE_TARGET)

    left_ext = geodesic(pts, left_start, left_goal) or []
    left_ext = list(reversed(left_ext))

    right_ext = geodesic(pts, right_start, right_goal) or []

    print("left_ext pts:", len(left_ext), "start x:", left_ext[0][0] if left_ext else None)
    print("right_ext pts:", len(right_ext), "end x:", right_ext[-1][0] if right_ext else None)

    combined = left_ext + mid + right_ext
    # 중복점 제거
    dedup = [combined[0]]
    for p in combined[1:]:
        if math.hypot(p[0] - dedup[-1][0], p[1] - dedup[-1][1]) > 0.5:
            dedup.append(p)

    # 스무딩을 먼저 하면 가시(spike)가 둥근 혹으로 변해 각도 기반 제거가 안 먹는다.
    # 반드시 원본 경로에서 먼저 제거하고, 스무딩 뒤 한 번 더 훑는다.
    final = rdp(despike(smooth(despike(dedup, 95.0), 8), 95.0), 4.0)

    out = [(round(x, 1), round(y, 1)) for x, y in final]
    print("waypoints:", len(out), "x:", out[0][0], "->", out[-1][0])
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump({"size": [w, h], "path": out}, f, ensure_ascii=False, indent=2)

    vis = img.copy()
    d = ImageDraw.Draw(vis)
    d.line([tuple(p) for p in out], fill=(255, 40, 40), width=2, joint="curve")
    for i, (x, y) in enumerate(out):
        d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(0, 255, 255), outline=(0, 0, 0))
        d.text((x + 5, y - 14), str(i), fill=(255, 255, 0))
    vis.resize((w * 2, h * 2), Image.LANCZOS).save(OUT_PNG)
    print("saved", OUT_PNG)


if __name__ == "__main__":
    main()
