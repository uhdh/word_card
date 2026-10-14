from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = Path(r"C:/Users/maktu/AppData/Roaming/orca/codex-runtime-home/home/generated_images/01a0bd48-4f54-7791-bdfd-262409b1a397")
SRC2 = Path(r"C:/Users/maktu/AppData/Roaming/orca/codex-runtime-home/home/generated_images/01a0be8e-af3b-7213-8465-72a350660cab")


def fit32(src: Image.Image) -> Image.Image:
    src = src.convert("RGBA")
    bbox = src.getbbox()
    if bbox:
        src = src.crop(bbox)
    cw, ch = src.size
    inner = 28
    scale = min(inner / max(cw, 1), inner / max(ch, 1))
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    scaled = src.resize((nw, nh), Image.NEAREST)
    canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    canvas.paste(scaled, ((32 - nw) // 2, (32 - nh) // 2), scaled)
    return canvas


def slice_sheet(src_name: str, stem: str, frames: int = 4) -> None:
    src_path = SRC / src_name
    if not src_path.exists():
        src_path = SRC2 / src_name
    im = Image.open(src_path).convert("RGBA")
    w, h = im.size
    cell_w = w // frames
    dests = [
        ROOT / "godot" / "assets" / "monsters",
        ROOT / "assets" / "monsters",
    ]
    for i in range(frames):
        cell = im.crop((i * cell_w, 0, (i + 1) * cell_w, h))
        out = fit32(cell)
        for dest in dests:
            dest.mkdir(parents=True, exist_ok=True)
            out.save(dest / f"{stem}_walk_{i}.png")
        if i == 0:
            for dest in dests:
                out.save(dest / f"{stem}_32px_pastel.png")
        print("frame", i, stem)


if __name__ == "__main__":
    jobs = [
        ("exec-d52324b3-2913-4c21-8911-7647aa2d3f0e.png", "monster_skeleton_1"),
        ("exec-0626359a-dca4-43a6-8f4e-459e20dc6e9b.png", "monster_spider_1"),
        ("exec-2ba6af54-7200-44f0-aa69-a3800c2165e6.png", "monster_spirit_1"),
        ("exec-31236615-1a84-470c-b4e5-9d8330fbae43.png", "monster_slime_2"),
        ("exec-16a0f9c7-12bd-44d2-955f-89261e6bbf22.png", "monster_dragon_1"),
        ("exec-813f9fa9-a12b-4f3e-877e-f7c3db93cc64.png", "monster_spirit_2"),
        ("exec-33e7bcec-8fbe-49e4-b4d1-1b9e6ecb53db.png", "monster_vine_2"),
        ("exec-64591979-4a2b-4829-8b36-89be2552a3c4.png", "monster_boar_2"),
        ("exec-5c93b6ed-477f-42da-b6bf-19f21ad06919.png", "monster_golem_boss_1"),
        ("exec-cfd311f1-4aa4-4245-85a1-0b6f014b1b16.png", "monster_golem_boss_2"),
    ]
    for src, stem in jobs:
        slice_sheet(src, stem)
