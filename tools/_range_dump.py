import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
q = json.loads((root / "tools" / "symbol_regen_queue.json").read_text(encoding="utf-8"))
words = [x["word"] for x in q]
try:
    a = words.index("골렘")
    b = words.index("불나방")
except ValueError as e:
    Path(root / "tools" / "_range.txt").write_text("missing: " + str(e), encoding="utf-8")
    raise
lo, hi = min(a, b), max(a, b)
chunk = q[lo:hi + 1]
parts = ["count %d  %s -> %s" % (len(chunk), q[lo]["word"], q[hi]["word"])]
for item in chunk:
    parts.append("%s | %s | %s | %s | exp=%s" % (item["stem"], item["word"], item.get("name", ""), item.get("category", ""), item.get("exp", False)))
out = root / "tools" / "_range.txt"
out.write_text(chr(10).join(parts), encoding="utf-8")
print("wrote", len(chunk))
