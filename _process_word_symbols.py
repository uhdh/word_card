from collections import deque
from pathlib import Path
from PIL import Image

SRC = Path(r"C:\Users\maktu\.grok\sessions\E%3A%5Cproject%5Cword_card\01a0864a-a3a3-7cf2-b34b-c48f9e87b2bb\images")
DIR_32 = Path(r"E:\project\word_card\assets\words_symbol_32px")
DIR_256 = Path(r"E:\project\word_card\assets\words_symbol_256px")
DIR_GODOT = Path(r"E:\project\word_card\godot\assets\words_symbol_32px")
THRESH = 232
PAD_RATIO = 0.10

# generated jpg stem -> (32 filename without suffix, 256 filename)
MAPPING = {
    "27.jpg": "word_174_3글자_살무사",
    "31.jpg": "word_044_1글자_뱀",
    "33.jpg": "word_148_3글자_개구리",
    "34.jpg": "word_151_3글자_구렁이",
    "32.jpg": "word_166_3글자_독수리",
    "30.jpg": "word_239_3글자_거북이",
    "29.jpg": "word_260_3글자_너구리",
    "28.jpg": "word_172_3글자_불사조",
    "37.jpg": "word_158_3글자_까마귀",
    "39.jpg": "word_019_1글자_곰",
    "40.jpg": "word_005_1글자_닭",
    "36.jpg": "word_064_1글자_쥐",
    "38.jpg": "word_015_1글자_개",
    "35.jpg": "word_089_2글자_늑대",
    "41.jpg": "word_242_2글자_나비",
    "42.jpg": "word_045_1글자_벌",
    "44.jpg": "word_070_2글자_거미",
    "45.jpg": "word_139_2글자_전갈",
    "46.jpg": "word_241_2글자_매미",
    "47.jpg": "word_245_2글자_지네",
}


def flood_key(im: Image.Image) -> Image.Image:
    rgba = im.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size
    seen = [[False] * h for _ in range(w)]
    q = deque()

    def is_bg(x, y):
        r, g, b, a = px[x, y]
        return r >= THRESH and g >= THRESH and b >= THRESH

    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        q.append((x, y))
        seen[x][y] = True
    while q:
        x, y = q.popleft()
        if not is_bg(x, y):
            continue
        px[x, y] = (255, 255, 255, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[nx][ny]:
                seen[nx][ny] = True
                q.append((nx, ny))
    return rgba


def fit(im: Image.Image, size: int) -> Image.Image:
    bbox = im.getbbox()
    if bbox is None:
        raise RuntimeError("empty after keying")
    cropped = im.crop(bbox)
    cw, ch = cropped.size
    pad = int(size * PAD_RATIO)
    inner = size - pad * 2
    scale = min(inner / cw, inner / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    resample = Image.NEAREST if size <= 64 else Image.NEAREST
    scaled = cropped.resize((nw, nh), resample)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(scaled, ((size - nw) // 2, (size - nh) // 2), scaled)
    return canvas


def main():
    written = 0
    for src_name, stem in MAPPING.items():
        src = SRC / src_name
        if not src.exists():
            print("MISSING", src_name)
            continue
        keyed = flood_key(Image.open(src))
        out256 = fit(keyed, 256)
        out32 = out256.resize((32, 32), Image.NEAREST)
        p32 = DIR_32 / f"{stem}.png"
        p256 = DIR_256 / f"{stem}_256px.png"
        pg = DIR_GODOT / f"{stem}.png"
        out32.save(p32, "PNG")
        out256.save(p256, "PNG")
        out32.save(pg, "PNG")
        written += 1
        print("wrote", stem)
    print("done", written)


if __name__ == "__main__":
    main()
