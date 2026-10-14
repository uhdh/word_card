import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = Path(r"C:/Users/maktu/AppData/Roaming/orca/codex-runtime-home/home/generated_images/01a0be8e-af3b-7213-8465-72a350660cab")
MAP = ROOT / "tools" / "symbol_regen_map.json"
PAD = 0.10

JOBS = [
    ("exec-b856108b-ddfd-48c8-a705-539dc5e25f32.png", "word_072_2글자_골렘", "골렘"),
    ("exec-eee4f0b1-7fdb-4a39-b67f-42c8150b8131.png", "word_073_2글자_관문", "관문"),
    ("exec-edd8c4a3-1bfa-41e0-a553-a794a6814b5d.png", "word_074_2글자_광선", "광선"),
    ("exec-f814070c-38c8-4256-a297-c956382c05cb.png", "word_075_2글자_괴물", "괴물"),
    ("exec-75a5b02a-271e-471b-9ae2-681ec41a6632.png", "word_076_2글자_괴수", "괴수"),
    ("exec-1050a1e6-1641-4295-91f2-2a9b1977a892.png", "word_078_2글자_귀신", "귀신"),
    ("exec-942eff3f-eb26-442f-b6cc-da3b9212da37.png", "word_079_2글자_금강", "금강"),
]


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
        src = SRC / src_name
        im = Image.open(src).convert("RGBA")
        bbox = im.getbbox()
        cropped = im.crop(bbox) if bbox else im
        out256 = fit(cropped, 256)
        rgb = Image.new("RGB", out256.size, (0, 0, 0))
        rgb.paste(out256.convert("RGB"), mask=out256.split()[-1])
        pal = rgb.quantize(colors=16, method=Image.Quantize.MEDIANCUT).convert("RGB").convert("RGBA")
        pal.putalpha(out256.split()[-1])
        out32 = pal.resize((32, 32), Image.NEAREST)
        (ROOT / "assets" / "words_symbol_256px" / f"{stem}_256px.png").parent.mkdir(parents=True, exist_ok=True)
        out256.save(ROOT / "assets" / "words_symbol_256px" / f"{stem}_256px.png")
        out32.save(ROOT / "assets" / "words_symbol_32px" / f"{stem}.png")
        out32.save(ROOT / "godot" / "assets" / "words_symbol_32px" / f"{stem}.png")
        by_word[word] = {"file": src_name, "stem": stem, "word": word}
        print("ok", word)
    MAP.write_text(json.dumps(list(by_word.values()), ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
