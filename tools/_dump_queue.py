import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
q = json.loads((root / "tools" / "symbol_regen_queue.json").read_text(encoding="utf-8"))
m = json.loads((root / "tools" / "symbol_regen_map.json").read_text(encoding="utf-8"))
done = {x["word"] for x in m}
print("done", len(done), sorted(done))
print("--- remaining first 40 ---")
n = 0
for item in q:
    if item["word"] in done:
        continue
    print(f"{item['stem']}	{item['word']}	{item.get('name','')}	{item.get('category','')}	exp={item.get('exp', False)}")
    n += 1
    if n >= 40:
        break
print("remaining", sum(1 for x in q if x["word"] not in done))
