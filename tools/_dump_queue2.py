import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
q = json.loads((root / "tools" / "symbol_regen_queue.json").read_text(encoding="utf-8"))
m = json.loads((root / "tools" / "symbol_regen_map.json").read_text(encoding="utf-8"))
done = {x["word"] for x in m}
parts = ["done %d" % len(done)]
for item in q:
    if item["word"] in done:
        continue
    parts.append("%s | %s | %s | %s" % (item["stem"], item["word"], item.get("name", ""), item.get("category", "")))
    if len(parts) >= 41:
        break
out = root / "tools" / "_next_symbols.txt"
out.write_text(chr(10).join(parts), encoding="utf-8")
print("wrote", out)
