"""Build 16:9 Hangul-accurate first/last frames for the ㅂ+vowel+ㄹ tower morph."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1920, 1080
ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
FONT = ROOT / "public" / "fonts" / "neodgm.ttf"

FIRE = ROOT / "assets" / "words_1letter" / "word_1_불_fire_32px_pastel.png"
BEE = ROOT / "assets" / "words_1letter" / "word_1_벌_bee_32px_pastel.png"
KICK = ROOT / "assets" / "words_symbol_256px" / "word_012_1글자_발_256px.png"
PEDESTAL = ROOT / "assets" / "map_ui" / "map_tower_pedestal_32px_pastel.png"


def backdrop() -> Image.Image:
    img = Image.new("RGB", (W, H), (18, 28, 36))
    px = img.load()
    for y in range(H):
        t = y / H
        r = int(16 + 8 * t)
        g = int(28 + 22 * t)
        b = int(26 + 6 * t)
        for x in range(W):
            n = ((x * 13 + y * 7) % 9) - 4
            px[x, y] = (
                max(0, min(255, r + n)),
                max(0, min(255, g + n)),
                max(0, min(255, b + n)),
            )
    d = ImageDraw.Draw(img)
    d.rectangle([0, 860, W, H], fill=(46, 92, 62))
    d.rectangle([0, 840, W, 860], fill=(34, 70, 48))
    for tx, ty in ((60, 560), (200, 520), (1700, 540), (1840, 580)):
        d.rectangle([tx + 40, ty + 140, tx + 88, ty + 320], fill=(72, 48, 36))
        d.rectangle([tx, ty, tx + 128, ty + 160], fill=(48, 110, 68))
        d.rectangle([tx + 20, ty - 40, tx + 110, ty + 30], fill=(58, 128, 78))
    d.ellipse([620, 780, 1300, 980], fill=(36, 90, 96))
    return img.convert("RGBA")


def paste_center(dst: Image.Image, src: Image.Image, cx: int, cy: int, size: int) -> None:
    im = src.convert("RGBA")
    # trim near-black / empty
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    im = im.resize((size, int(size * im.height / im.width)), Image.NEAREST)
    x = int(cx - im.width / 2)
    y = int(cy - im.height / 2)
    dst.alpha_composite(im, (x, y))


def draw_tile(target: Image.Image, cx: int, cy: int, size: int, ch: str, font: ImageFont.FreeTypeFont) -> None:
    s = size
    x0, y0 = int(cx - s / 2), int(cy - s / 2)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([x0 - 40, y0 - 40, x0 + s + 40, y0 + s + 40], fill=(80, 220, 230, 50))
    target.alpha_composite(glow.filter(ImageFilter.GaussianBlur(16)))
    d = ImageDraw.Draw(target)
    d.rounded_rectangle([x0 + 10, y0 + 14, x0 + s + 10, y0 + s + 14], radius=16, fill=(30, 32, 48, 150))
    d.rounded_rectangle([x0, y0, x0 + s, y0 + s], radius=16, fill=(62, 70, 98, 255), outline=(20, 22, 36, 255), width=8)
    d.rounded_rectangle([x0 + 14, y0 + 14, x0 + s - 14, y0 + s - 14], radius=10, outline=(90, 210, 220, 255), width=4)
    d.rounded_rectangle(
        [x0 + 24, y0 + 24, x0 + s - 24, y0 + s - 24],
        radius=8,
        fill=(240, 230, 196, 255),
        outline=(48, 40, 32, 255),
        width=5,
    )
    bbox = d.textbbox((0, 0), ch, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = cx - tw / 2 - bbox[0]
    ty = cy - th / 2 - bbox[1] - 6
    d.text((tx + 3, ty + 3), ch, font=font, fill=(120, 90, 50, 180))
    d.text((tx, ty), ch, font=font, fill=(32, 24, 20, 255))


def highlight_middle(target: Image.Image, cx: int, cy: int, size: int) -> None:
    s = size + 28
    x0, y0 = int(cx - s / 2), int(cy - s / 2)
    ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    rd.rounded_rectangle([x0, y0, x0 + s, y0 + s], radius=20, outline=(255, 220, 90, 220), width=8)
    target.alpha_composite(ring)


def compose(jamo: tuple[str, str, str], word: str | None, sprite: Path | None, highlight_vowel: bool, name: str) -> Path:
    font_jamo = ImageFont.truetype(str(FONT), 150)
    font_word = ImageFont.truetype(str(FONT), 120)
    canvas = backdrop()

    paste_center(canvas, Image.open(PEDESTAL), 960, 930, 420)

    y_jamo = 168
    sizes = (240, 260, 240)
    xs = (500, 960, 1420)
    for x, ch, sz in zip(xs, jamo, sizes):
        draw_tile(canvas, x, y_jamo, sz, ch, font_jamo)
    if highlight_vowel:
        highlight_middle(canvas, xs[1], y_jamo, sizes[1])

    if sprite is not None:
        paste_center(canvas, Image.open(sprite), 780, 640, 300)
    if word:
        draw_tile(canvas, 1180, 620, 240, word, font_word)

    path = OUT / name
    canvas.convert("RGB").save(path, "PNG")
    print(path)
    return path


def main() -> None:
    compose(("ㅂ", "ㅜ", "ㄹ"), None, None, True, "ref_tower_bul_start.png")
    compose(("ㅂ", "ㅜ", "ㄹ"), "불", FIRE, True, "ref_tower_bul_end.png")
    compose(("ㅂ", "ㅓ", "ㄹ"), "벌", BEE, True, "ref_tower_beol_end.png")
    compose(("ㅂ", "ㅏ", "ㄹ"), "발", KICK, True, "ref_tower_bal_end.png")


if __name__ == "__main__":
    main()
