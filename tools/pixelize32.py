from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "tools" / "symbol_regen_map.json"


def to32(src: Image.Image) -> Image.Image:
    src = src.convert("RGBA")
    bbox = src.getbbox()
    if bbox:
        src = src.crop(bbox)
    rgb = Image.new("RGB", src.size, (0, 0, 0))
    rgb.paste(src.convert("RGB"), mask=src.split()[-1])
    pal = rgb.quantize(colors=16, method=Image.Quantize.MEDIANCUT).convert("RGB").convert("RGBA")
    pal.putalpha(src.split()[-1])
    cw, ch = pal.size
    inner = 28
    scale = min(inner / cw, inner / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    scaled = pal.resize((nw, nh), Image.NEAREST)
    canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    canvas.paste(scaled, ((32 - nw) // 2, (32 - nh) // 2), scaled)
    return canvas


def main() -> None:
    import json
    jobs = json.loads(MAP.read_text(encoding="utf-8"))
    for job in jobs:
        stem = job["stem"]
        src = ROOT / "assets" / "words_symbol_256px" / f"{stem}_256px.png"
        if not src.exists():
            print("missing", src.name)
            continue
        out = to32(Image.open(src))
        out.save(ROOT / "assets" / "words_symbol_32px" / f"{stem}.png")
        out.save(ROOT / "godot" / "assets" / "words_symbol_32px" / f"{stem}.png")
        print("32", stem)


if __name__ == "__main__":
    main()
