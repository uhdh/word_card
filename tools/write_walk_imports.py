from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "godot" / "assets" / "monsters"
SAMPLE = ROOT / "monster_slime_1_32px_pastel.png.import"


def uid() -> str:
    alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
    n = abs(hash(alphabet))
    # ponytail: Godot only needs a unique uid string; editor will rewrite on import.
    import os
    return "uid://w" + os.urandom(8).hex()


def main() -> None:
    tmpl = SAMPLE.read_text(encoding="utf-8")
    n = 0
    for png in sorted(ROOT.glob("*_walk_*.png")):
        dest = png.with_name(png.name + ".import")
        if dest.exists():
            continue
        name = png.name
        text = tmpl.replace("monster_slime_1_32px_pastel.png", name)
        text = text.replace('uid="uid://bykwr3c2adqf0"', f'uid="{uid()}"')
        dest.write_text(text, encoding="utf-8")
        n += 1
        print("import", name)
    print("wrote", n)


if __name__ == "__main__":
    main()
