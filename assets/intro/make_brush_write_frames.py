"""16:9 Hangul calligraphy frames: ㅂ ㅜ ㄹ written in ink, then fire."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1920, 1080
OUT = Path(__file__).resolve().parent
ROOT = Path(__file__).resolve().parents[2]
FIRE = ROOT / "assets" / "words_1letter" / "word_1_불_fire_32px_pastel.png"
FONT = Path(r"C:\Windows\Fonts\H2GSRB.TTF")


def backdrop() -> Image.Image:
    img = Image.new("RGB", (W, H), (22, 28, 32))
    px = img.load()
    for y in range(H):
        t = y / H
        for x in range(W):
            n = ((x * 11 + y * 5) % 7) - 3
            r = int(28 + 8 * t + n)
            g = int(36 + 18 * t + n)
            b = int(38 + 6 * t + n)
            px[x, y] = (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 900, W, H], fill=(42, 78, 56))
    d.rectangle([0, 880, W, 900], fill=(32, 60, 44))
    return img.convert("RGBA")


def parchment(canvas: Image.Image) -> None:
    d = ImageDraw.Draw(canvas)
    # leave the left third empty so Veo can place the Word Weaver
    x0, y0, x1, y1 = 520, 200, 1780, 760
    d.rounded_rectangle([x0 + 18, y0 + 22, x1 + 18, y1 + 22], radius=18, fill=(60, 48, 32, 90))
    d.rounded_rectangle([x0, y0, x1, y1], radius=18, fill=(236, 220, 184, 255))
    d.rounded_rectangle([x0 + 10, y0 + 10, x1 - 10, y1 - 10], radius=12, outline=(120, 92, 58, 180), width=3)


def ink_letters(canvas: Image.Image, chars: str, wet: bool = False, cx: int = 1150) -> None:
    font = ImageFont.truetype(str(FONT), 240)
    d = ImageDraw.Draw(canvas)
    bbox = d.textbbox((0, 0), chars, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = cx - tw / 2 - bbox[0]
    y = 360 - th / 2 - bbox[1]
    fill = (28, 24, 22, 200) if wet else (18, 16, 14, 255)
    d.text((x + 4, y + 6), chars, font=font, fill=(70, 60, 50, 70))
    d.text((x, y), chars, font=font, fill=fill)


def brush(canvas: Image.Image, tip: tuple[int, int]) -> None:
    """Bamboo ink brush, tip at the given point, handle going down-right."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    tx, ty = tip
    hx, hy = tx + 420, ty + 380
    d.line([(tx, ty), (hx, hy)], fill=(92, 58, 28, 255), width=22)
    d.line([(tx + 8, ty + 8), (hx, hy)], fill=(140, 92, 48, 255), width=8)
    d.polygon(
        [(tx - 10, ty + 8), (tx + 18, ty - 4), (tx - 2, ty - 28), (tx - 22, ty - 8)],
        fill=(22, 20, 18, 255),
    )
    d.ellipse([tx - 14, ty - 14, tx + 10, ty + 10], fill=(12, 10, 10, 255))
    # ink drop
    d.ellipse([tx - 6, ty + 18, tx + 8, ty + 36], fill=(16, 14, 14, 200))
    canvas.alpha_composite(layer)


def inkstone(canvas: Image.Image) -> None:
    d = ImageDraw.Draw(canvas)
    d.ellipse([140, 820, 340, 980], fill=(40, 38, 44, 255), outline=(18, 16, 18, 255), width=6)
    d.ellipse([180, 850, 300, 950], fill=(16, 14, 16, 255))
    d.ellipse([210, 870, 250, 900], fill=(70, 70, 80, 180))


def paste_fire(canvas: Image.Image, cx: int, cy: int, size: int) -> None:
    im = Image.open(FIRE).convert("RGBA")
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    im = im.resize((size, int(size * im.height / im.width)), Image.NEAREST)
    canvas.alpha_composite(im, (int(cx - im.width / 2), int(cy - im.height / 2)))


def glow(canvas: Image.Image, color: tuple[int, int, int, int], box: tuple[int, int, int, int]) -> None:
    g = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(g).ellipse(list(box), fill=color)
    canvas.alpha_composite(g.filter(ImageFilter.GaussianBlur(28)))


def save(canvas: Image.Image, name: str) -> Path:
    path = OUT / name
    canvas.convert("RGB").save(path, "PNG")
    print(path)
    return path


def main() -> None:
    # 1) first stroke: only ㅂ, brush at the character
    a = backdrop()
    parchment(a)
    inkstone(a)
    ink_letters(a, "ㅂ", wet=True)
    brush(a, (1000, 500))
    save(a, "ref_brush_1_bieup.png")

    # 2) ㅂ ㅜ written, brush moving to ㄹ
    b = backdrop()
    parchment(b)
    inkstone(b)
    ink_letters(b, "ㅂ    ㅜ", wet=True)
    brush(b, (1320, 490))
    save(b, "ref_brush_2_bieup_ueo.png")

    # 3) finished ㅂ ㅜ ㄹ
    c = backdrop()
    parchment(c)
    inkstone(c)
    ink_letters(c, "ㅂ   ㅜ   ㄹ", wet=False)
    brush(c, (1600, 540))
    save(c, "ref_brush_3_bul_written.png")

    # 4) same letters, fire erupts in front of the scroll
    d = backdrop()
    parchment(d)
    inkstone(d)
    glow(d, (255, 120, 40, 70), (780, 620, 1480, 1080))
    ink_letters(d, "ㅂ   ㅜ   ㄹ", wet=False)
    paste_fire(d, 1150, 820, 340)
    brush(d, (1600, 540))
    save(d, "ref_brush_4_fire.png")


if __name__ == "__main__":
    main()
