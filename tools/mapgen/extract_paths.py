# -*- coding: utf-8 -*-
"""Act 맵 TD 경로 추출 v3.

전략 (막별로 다른 아트 스타일 대응):
  seed  = 아주 확실한 경로 픽셀 (좁은 색 조건)
  loose = 느슨한 경로 픽셀 (넓은 색 조건)
  seed 를 조금 팽창시킨 뒤 loose 안에서 전파(binary_propagation) → 경로 리본 복원
  → 최대 연결요소 → 스켈레톤 → 최장 지오데식 → Douglas-Peucker
"""
import json
import math
from collections import deque

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from skimage.morphology import skeletonize

BASE = r"E:\project\word_card\godot\assets\map"
MAPS = {
    "act1": BASE + r"\map_act1_garden_td_1024x352.png",
    "act2": BASE + r"\map_act2_rock_mine_td_1024x352.png",
    "act3": BASE + r"\map_act3_sky_citadel_td_1024x352.png",
}
NBR8 = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]


def masks(name, a):
    """(seed, loose) 마스크 반환."""
    r, g, b = a[:, :, 0].astype(np.int32), a[:, :, 1].astype(np.int32), a[:, :, 2].astype(np.int32)
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    if name == "act1":
        # 정원 흙길: 따뜻한 황갈색 (밝고 채도 있음)
        seed = ((r - b) > 45) & ((r - g) > 12) & (r > 150)
        loose = ((r - b) > 25) & ((r - g) > 5) & (r > 105)
    elif name == "act2":
        # 광산 레일: 밝은 회색 레일 라인
        seed = (mn > 95) & ((mx - mn) < 40)
        loose = (mn > 72) & ((mx - mn) < 55)
    else:
        # 천공성 룬길: 밝은 시안 발광
        seed = ((g - r) > 35) & ((b - r) > 45) & (g > 150) & (b > 165)
        loose = ((g - r) > 15) & ((b - r) > 25) & (g > 90) & (b > 110)
    return seed, loose


def ribbon(seed, loose, name):
    grow = {"act1": 3, "act2": 4, "act3": 3}[name]
    s = ndimage.binary_dilation(seed, np.ones((3, 3)), iterations=grow)
    p = ndimage.binary_propagation(s, mask=loose)
    p = ndimage.binary_closing(p, np.ones((3, 3)), iterations=4)
    p = ndimage.binary_opening(p, np.ones((3, 3)), iterations=1)

    # 조각으로 끊긴 경로를 이어 붙인다 (act2 광산 레일은 조명 때문에 색이 끊긴다)
    bridge = {"act1": 0, "act2": 10, "act3": 0}[name]
    if bridge:
        lab, n = ndimage.label(p, np.ones((3, 3)))
        if n == 0:
            return None, 0
        sizes = ndimage.sum(p, lab, range(1, n + 1))
        keep = np.isin(lab, [i + 1 for i, sz in enumerate(sizes) if sz > 250])
        p = ndimage.binary_closing(keep, np.ones((5, 5)), iterations=bridge)

    lab, n = ndimage.label(p, np.ones((3, 3)))
    if n == 0:
        return None, 0
    sizes = ndimage.sum(p, lab, range(1, n + 1))
    best = int(np.argmax(sizes)) + 1
    return lab == best, int(sizes[best - 1])


def longest_path_on_skeleton(mask):
    sk = skeletonize(mask)
    ys, xs = np.nonzero(sk)
    if len(xs) == 0:
        return None, sk
    pts = set(zip(ys.tolist(), xs.tolist()))

    def bfs(start):
        dist = {start: 0}
        prev = {}
        q = deque([start])
        far = start
        while q:
            cur = q.popleft()
            cy, cx = cur
            for dy, dx in NBR8:
                nb = (cy + dy, cx + dx)
                if nb in pts and nb not in dist:
                    dist[nb] = dist[cur] + 1
                    prev[nb] = cur
                    if dist[nb] > dist[far]:
                        far = nb
                    q.append(nb)
        return far, prev

    a, _ = bfs((int(ys[0]), int(xs[0])))
    b, prev = bfs(a)
    path = []
    cur = b
    while cur != a:
        path.append((cur[1], cur[0]))
        cur = prev[cur]
    path.append((a[1], a[0]))
    path.reverse()
    return path, sk


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


def main():
    result = {}
    for name, p in MAPS.items():
        img = Image.open(p).convert("RGB")
        a = np.array(img)
        h, w = a.shape[:2]
        seed, loose = masks(name, a)
        rib, size = ribbon(seed, loose, name)
        if rib is None:
            print(name, "NO RIBBON")
            continue
        cl, sk = longest_path_on_skeleton(rib)
        if cl is None:
            print(name, "NO SKELETON")
            continue
        road_w = size / max(1, len(cl))
        pts = [(float(x), float(y)) for (x, y) in cl]
        simp = rdp(pts, 4.0)
        step = max(1, len(simp) // 22)
        sampled = simp[::step]
        if sampled[-1] != simp[-1]:
            sampled.append(simp[-1])
        sampled = [(round(x, 1), round(y, 1)) for x, y in sampled]
        result[name] = {"size": [w, h], "road_width": round(road_w, 1),
                        "path": sampled, "raw_len": len(pts)}
        print(f"{name}: {w}x{h} ribbon={size} road_w~{road_w:.1f} raw={len(pts)} final={len(sampled)}")

        vis = img.copy()
        d = ImageDraw.Draw(vis)
        d.line(pts, fill=(255, 40, 40), width=2)
        for i, (x, y) in enumerate(sampled):
            d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=(0, 255, 255), outline=(0, 0, 0))
            d.text((x + 6, y - 16), str(i), fill=(255, 255, 0))
        vis.save(rf"E:\project\word_card\tools\mapgen\out\path_{name}.png")

    with open(r"E:\project\word_card\tools\mapgen\out\paths.json", "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    print("saved out/paths.json")


if __name__ == "__main__":
    main()
