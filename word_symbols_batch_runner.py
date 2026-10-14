"""Build the next word-symbol queue and normalize staged image_gen outputs.

The built-in image_gen call remains one call per manifest entry.  This file
only makes the queue/prompt and the deterministic 256 -> 32/Godot processor
reproducible.
"""

from __future__ import annotations

import argparse
from collections import deque
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


ROOT = Path(__file__).parent
DB = ROOT / "assets/word_database_265.json"
STAGING = ROOT / "generated_word_symbols"
COMPLETED = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
    16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
    31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45,
    46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60,
    61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75,
    76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90,
    91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105,
    106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120,
    121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135,
    136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150,
    151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165,
    166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180,
    181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195,
    196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210,
    211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225,
    226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240,
    241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255,
    256, 257, 258, 259, 260, 261, 262, 263, 264, 265,
}
GENERATED = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 256, 257, 258, 259, 260, 261, 262, 263, 264, 265}
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


def key_white_background(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    if image.getchannel("A").getextrema() == (255, 255):
        rgb = np.array(image.convert("RGB"))
        hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
        mask = np.where((hsv[:, :, 1] > 45) | (hsv[:, :, 2] < 115), 255, 0).astype(np.uint8)
        count, labels, stats, _ = cv2.connectedComponentsWithStats(mask)
        assert count > 1, "no foreground found"
        foreground = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        mask = np.where(labels == foreground, 255, 0).astype(np.uint8)
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        mask.fill(0)
        cv2.drawContours(mask, contours, -1, 255, cv2.FILLED)
        mask = cv2.dilate(mask, np.ones((5, 5), np.uint8))
        image.putalpha(Image.fromarray(mask))
        return image
    pixels = image.load()
    seen = set()
    queue = deque(((0, 0), (image.width - 1, 0), (0, image.height - 1), (image.width - 1, image.height - 1)))
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen:
            continue
        seen.add((x, y))
        r, g, b, _ = pixels[x, y]
        if min(r, g, b) < 232:
            continue
        pixels[x, y] = (255, 255, 255, 0)
        queue.extend((p for p in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)) if 0 <= p[0] < image.width and 0 <= p[1] < image.height))
    return image


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


def process_staging(godot_only: bool = False) -> int:
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
        image = key_white_background(Image.open(source))
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
        if godot_only:
            targets = list(outputs[2].glob(f"word_{no:03d}_*.png"))
            assert len(targets) == 1, f"Godot target not unique for {no}: {targets}"
            output_32.save(targets[0], "PNG")
        else:
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
    parser.add_argument("--godot-only", action="store_true")
    args = parser.parse_args()
    assert len(COMPLETED) == 265
    assert len(entries()) == 265
    assert len(entries()) - len(COMPLETED) == 0
    if args.process:
        print(f"processed={process_staging(args.godot_only)}")
    queue = build_manifest()
    args.manifest.write_text(json.dumps(queue, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"pending={len(queue)} manifest={args.manifest}")


if __name__ == "__main__":
    main()
