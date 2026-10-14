import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
q = json.loads((root / "tools" / "symbol_regen_queue.json").read_text(encoding="utf-8"))
m = json.loads((root / "tools" / "symbol_regen_map.json").read_text(encoding="utf-8"))
done = {x["word"] for x in m}
words = [x["word"] for x in q]
a, b = words.index("골렘"), words.index("불나방")
lo, hi = min(a, b), max(a, b)
chunk = q[lo:hi + 1]
remain = [x for x in chunk if x["word"] not in done]
parts = ["done_in_range %d remain %d" % (len(chunk) - len(remain), len(remain))]
for item in remain:
    parts.append("%s | %s | %s | %s" % (item["stem"], item["word"], item.get("name", ""), item.get("category", "")))
(root / "tools" / "_remain_range.txt").write_text(chr(10).join(parts), encoding="utf-8")
print("remain", len(remain))
