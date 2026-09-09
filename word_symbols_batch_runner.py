"""Build the next word-symbol queue and normalize staged image_gen outputs.

The built-in image_gen call remains one call per manifest entry.  This file
only makes the queue/prompt and the deterministic 256 -> 32/Godot processor
reproducible.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).parent
DB = ROOT / "assets/word_database_265.json"
STAGING = ROOT / "generated_word_symbols"
COMPLETED = {
    5, 15, 19, 44, 45, 64, 70, 89, 139, 148, 151, 158, 166, 172, 174,
    239, 241, 242, 245, 260,
    1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12,
}
GENERATED = {1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12}
PALETTE = {
    "magic": "deep violet and cyan energy with warm gold highlights",
    "defense": "steel blue, slate, and warm gold defensive accents",
    "weapon": "iron gray, warm bronze, and a bright accent color",
    "element": "luminous elemental colors with dark brown outline",
    "summon": "natural creature colors with a warm gold accent",
    "skill": "arcane blue-purple with cyan highlights",
    "heal": "fresh green, aqua, and warm gold",
    "buff": "royal blue, violet, and gold",
}


def prompt(x: dict) -> str:
    return f"""Use case: stylized-concept
Asset type: transparent raster game word-symbol icon, 256x256 square
Primary request: one distinct centered pixel-art symbol for the Korean word "{x['word']}", concept "{x['name']}". Render the concrete object or effect named by the concept, not typography.
Scene/backdrop: none, genuinely transparent background
Subject: a single unmistakable {x['name']} symbol; one main object or tightly unified effect
Style/medium: crisp 16-bit SNES-inspired pixel art matching the existing Korean word-card icon set; hard pixel edges, chunky pixel clusters, limited palette, no anti-aliasing
Composition/framing: centered compact silhouette, generous transparent padding, readable at 32px
Lighting/mood: polished game icon lighting with a subtle luminous rim
Color palette: {PALETTE[x['category']]}
Materials/textures: simple readable forms, no gradients, no micro-detail
Text (verbatim): none
Constraints: genuinely transparent background with preserved alpha; one distinct asset only; no Korean letters, no text, no border, no card frame, no watermark; subject must remain recognizable after nearest-neighbor downscaling to 32px
Avoid: photorealism, smooth vector art, multiple unrelated objects, scenery, background shadows"""


def entries() -> list[dict]:
    db = json.loads(DB.read_text(encoding="utf-8"))
    return sorted(db.values(), key=lambda x: x["no"])


def stem(x: dict) -> str:
    return f"word_{x['no']:03d}_{x['length']}글자_{x['word']}"


def build_manifest() -> list[dict]:
    pending = []
    for x in entries():
        if x["no"] in COMPLETED:
            continue
        s = stem(x)
        pending.append({
            "no": x["no"],
            "word": x["word"],
            "name": x["name"],
            "category": x["category"],
            "length": x["length"],
            "staging": f"generated_word_symbols/{x['no']:03d}.png",
            "output_256": f"assets/words_symbol_256px/{s}_256px.png",
            "output_32": f"assets/words_symbol_32px/{s}.png",
            "output_godot": f"godot/assets/words_symbol_32px/{s}.png",
            "prompt": prompt(x),
        })
    return pending


def process_staging() -> int:
    db = {x["no"]: x for x in entries()}
    outputs = (
        ROOT / "assets/words_symbol_256px",
        ROOT / "assets/words_symbol_32px",
        ROOT / "godot/assets/words_symbol_32px",
    )
    count = 0
    for source in sorted(STAGING.glob("*.png")):
        if not source.stem.isdigit():
            continue
        no = int(source.stem)
        # Staging is an image_gen scratch area, not the completion ledger.
        if no not in GENERATED:
            print(f"skipped stray staging id: {no}")
            continue
        assert no in db
        x = db[no]
        image = Image.open(source).convert("RGBA")
        alpha = image.getchannel("A").point(lambda p: p if p >= 16 else 0)
        image.putalpha(alpha)
        bbox = alpha.getbbox()
        assert bbox, f"empty transparent asset: {source}"
        image = image.crop(bbox)
        pad = round(256 * 0.10)
        inner = 256 - 2 * pad
        scale = min(inner / image.width, inner / image.height)
        size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
        image = image.resize(size, Image.Resampling.NEAREST)
        output = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        output.paste(image, ((256 - size[0]) // 2, (256 - size[1]) // 2), image)
        output_32 = output.resize((32, 32), Image.Resampling.NEAREST)
        s = stem(x)
        output.save(outputs[0] / f"{s}_256px.png", "PNG")
        output_32.save(outputs[1] / f"{s}.png", "PNG")
        output_32.save(outputs[2] / f"{s}.png", "PNG")
        assert output.size == (256, 256) and output.mode == "RGBA"
        assert output_32.size == (32, 32) and output_32.getchannel("A").getbbox()
        count += 1
    return count


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=ROOT / "word_symbols_next_batch_manifest.json")
    parser.add_argument("--process", action="store_true")
    args = parser.parse_args()
    assert len(COMPLETED) == 31
    assert len(entries()) == 265
    assert len(entries()) - len(COMPLETED) == 234
    if args.process:
        print(f"processed={process_staging()}")
    queue = build_manifest()
    args.manifest.write_text(json.dumps(queue, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"pending={len(queue)} manifest={args.manifest}")


if __name__ == "__main__":
    main()
