import json, sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tools" / "_grok_out"
MAP = ROOT / "tools" / "symbol_regen_map.json"
PAD = 0.10
JOBS = json.loads((ROOT / "tools" / "_jobs.json").read_text(encoding="utf-8"))

def fit(src: Image.Image, size: int) -> Image.Image:
    cw, ch = src.size
    pad = int(size * PAD)
    inner = size - pad * 2
    scale = min(inner / max(cw, 1), inner / max(ch, 1))
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    scaled = src.resize((nw, nh), Image.NEAREST)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(scaled, ((size - nw) // 2, (size - nh) // 2), scaled)
    return canvas

def main() -> None:
    jobs = json.loads(MAP.read_text(encoding="utf-8"))
    by_word = {j["word"]: j for j in jobs}
    for src_name, stem, word in JOBS:
        im = Image.open(SRC / src_name).convert("RGBA")
        bbox = im.getbbox()
        cropped = im.crop(bbox) if bbox else im
        out256 = fit(cropped, 256)
        rgb = Image.new("RGB", out256.size, (0, 0, 0))
        rgb.paste(out256.convert("RGB"), mask=out256.split()[-1])
        pal = rgb.quantize(colors=16, method=Image.Quantize.MEDIANCUT).convert("RGB").convert("RGBA")
        pal.putalpha(out256.split()[-1])
        out32 = pal.resize((32, 32), Image.NEAREST)
        out256.save(ROOT / "assets" / "words_symbol_256px" / f"{stem}_256px.png")
        out32.save(ROOT / "assets" / "words_symbol_32px" / f"{stem}.png")
        out32.save(ROOT / "godot" / "assets" / "words_symbol_32px" / f"{stem}.png")
        by_word[word] = {"file": src_name, "stem": stem, "word": word}
        print("ok", word)
    MAP.write_text(json.dumps(list(by_word.values()), ensure_ascii=False, indent=2), encoding="utf-8")

if __name__ == "__main__":
    main()
