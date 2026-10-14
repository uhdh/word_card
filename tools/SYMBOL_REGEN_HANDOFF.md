# Word symbol regeneration handoff

## Current state (2026-09-21)

- Queue: `tools/symbol_regen_queue.json` (338 entries)
- Completed map: `tools/symbol_regen_map.json` (209 entries)
- Tracked `골렘` through `불나방` range: **remain 0** (`python tools/_remain_range.py`)
- Last fully installed entry: `word_265_3글자_불나방`
- Do not clean/reset the worktree.

## Done this session

Installed the leftover 168/169 pair, then generated and installed the rest of the `골렘`~`불나방` slice through 불나방.

Installer: `tools/_install_jobs.py`
Generated source dir: `C:/Users/maktu/AppData/Roaming/orca/codex-runtime-home/home/generated_images/01a0bef9-af98-7493-b46e-790f3fe616ec`

Writes to:

- `assets/words_symbol_256px/{stem}_256px.png`
- `assets/words_symbol_32px/{stem}.png`
- `godot/assets/words_symbol_32px/{stem}.png`

Do not use `tools/install_symbol_batch.py`.

## Next work (outside the 골렘~불나방 slice)

The remaining-range script is complete. The full queue still has 136 unmapped words. Next remaining items:

```text
word_032 독 | 독 (맹독/부식) | element
word_033 돌 | 돌 (투석/기절) | weapon
word_034 마 | 마 (산약/마비침) | heal
word_035 막 | 막 (결계/감속장막) | defense
word_036 말 | 말 (군마/질주) | summon
word_037 망 | 망 (포획망/속박) | skill
word_038 못 | 못 (대못/출혈) | weapon
word_039 무 | 무 (무/대포탄) | heal
word_040 묵 | 묵 (도토리묵/슬로우) | heal
word_041 문 | 문 (관문/철문낙하) | defense
word_042 물 | 물 (수류/물줄기) | element
word_043 방 | 방 (방패/충격파) | defense
word_046 봉 | 봉 (장봉/광역) | weapon
word_047 북 | 북 (전쟁의북/고동) | skill
word_048 불 | 불 (화염/화구) | element
```

Write `tools/_jobs.json` as UTF-8 **without BOM**, then:

```powershell
$env:PYTHONIOENCODING='utf-8'
python tools/_install_jobs.py
python tools/_remain_range.py
```

Use the built-in image generation tool, one call per distinct asset. Two calls may run in parallel.

Prompt template:

```text
Use case: stylized-concept
Asset type: transparent raster game word-symbol icon, 256x256 square
Primary request: one distinct centered pixel-art symbol for the Korean word "{word}", concept "{name}". Render the concrete object or effect named by the concept, not typography.
Scene/backdrop: none, genuinely transparent background
Subject: a single unmistakable {name} symbol; one main object or tightly unified effect
Style/medium: crisp 16-bit SNES-inspired pixel art matching the existing Korean word-card icon set; hard pixel edges, chunky pixel clusters, limited palette, no anti-aliasing
Composition/framing: centered compact silhouette, generous transparent padding, readable at 32px
Lighting/mood: polished game icon lighting with a subtle luminous rim
Color palette: {palette}
Materials/textures: simple readable forms, no gradients, no micro-detail
Text (verbatim): none
Constraints: genuinely transparent background with preserved alpha; one distinct asset only; no Korean letters, no text, no border, no card frame, no watermark; subject must remain recognizable after nearest-neighbor downscaling to 32px
Avoid: photorealism, smooth vector art, multiple unrelated objects, scenery, background shadows
```

Palette by category:

```text
weapon: steel silver, sharp crimson, and charcoal gray
element: electric cyan, fiery amber, and deep midnight blue
skill: mystic amethyst, arcane lavender, and pale gold
buff: royal blue, violet, and gold
defense: bronze, warm stone gray, and sturdy ochre
heal: fresh green, aqua, and warm gold
summon: moss green, earth brown, and warm cream
```
