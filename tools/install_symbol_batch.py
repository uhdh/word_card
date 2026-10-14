from __future__ import annotations

import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = Path(r"C:/Users/maktu/AppData/Roaming/orca/codex-runtime-home/home/generated_images/01a0bd48-4f54-7791-bdfd-262409b1a397")
PAD = 0.10
MAP = ROOT / "tools" / "symbol_regen_map.json"


def fit(src: Image.Image, size: int) -> Image.Image:
    cw, ch = src.size
    pad = int(size * PAD)
    inner = size - pad * 2
    scale = min(inner / cw, inner / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    scaled = src.resize((nw, nh), Image.NEAREST)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(scaled, ((size - nw) // 2, (size - nh) // 2), scaled)
    return canvas


def main() -> None:
    jobs = json.loads(MAP.read_text(encoding="utf-8"))
    for job in jobs:
        src_name = job["file"]
        stem = job["stem"]
        src = SRC / src_name
        if not src.exists():
            print("MISSING src", src_name)
            continue
        im = Image.open(src).convert("RGBA")
        bbox = im.getbbox()
        cropped = im.crop(bbox)
        out256 = fit(cropped, 256)
        rgb = Image.new("RGB", out256.size, (0, 0, 0))
        rgb.paste(out256.convert("RGB"), mask=out256.split()[-1])
        pal = rgb.quantize(colors=16, method=Image.Quantize.MEDIANCUT).convert("RGB").convert("RGBA")
        pal.putalpha(out256.split()[-1])
        out32 = pal.resize((32, 32), Image.NEAREST)
        dests = [
            ROOT / "assets" / "words_symbol_256px" / f"{stem}_256px.png",
            ROOT / "assets" / "words_symbol_32px" / f"{stem}.png",
            ROOT / "godot" / "assets" / "words_symbol_32px" / f"{stem}.png",
        ]
        if job.get("exp"):
            dests.append(ROOT / "godot" / "assets" / "open_source" / "words_exp" / f"{stem}.png")
        out256.save(dests[0])
        for path in dests[1:]:
            path.parent.mkdir(parents=True, exist_ok=True)
            out32.save(path)
        print("ok", stem)


if __name__ == "__main__":
    main()
