# Tower Slot Jamo Trays Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let players drag jamo into independent tower-slot trays and inspect tower range and combat details on hover.

**Architecture:** `JamoBelt` retains the flat inventory and adds a parallel slot-assignment array, so current shop and hint inputs stay simple. Each slot parses independently and emits a positional four-entry result; save/load persists assignments with waiting-tray migration for old saves. `WordTower` reuses its transparent selection button for tooltip and hover-range behavior.

**Tech Stack:** Godot 4.7, GDScript, existing headless scene tests

**Spec:** `docs/superpowers/specs/2026-09-08-tower-slot-jamo-trays-design.md`

## Global Constraints

- New and migrated jamo use assignment `-1` (waiting).
- Tower assignments are `0..3`; locked or invalid assignments normalize to waiting.
- A tower tray must parse to exactly one tower consuming every assigned tile; otherwise a drop is rejected.
- No new dependency or subsystem.

---

### Task 1: Independent Jamo Trays

**Files:**
- Modify: `godot/scripts/ui/JamoBelt.gd`
- Modify: `godot/scenes/tower/JamoBelt.tscn`
- Test: `godot/tests/test_tower_traits.gd`

**Interfaces:**
- Produces: `slot_assignments: Array[int]`, `set_unlocked_slot_count(count: int)`, `remove_jamo(index: int)`, positional `parsed_towers_updated`
- Consumes: `HangulStreamParser.parse_jamo_stream(jamo: Array) -> Array`

- [ ] **Step 1: Write failing tray behavior tests**

Add a test that assigns `ㅂㅜ` to slot 0 and `ㄹㅜ` to slot 1, renders, and asserts emitted entries contain `부` and `루` at those exact positions. Add assertions that `add_jamo("ㄱ")` appends `-1`, locked slot 3 rejects assignment, and an invalid multi-tower destination leaves assignments unchanged.

```gdscript
func _test_each_tower_slot_parses_only_its_tiles() -> void:
	var belt = JamoBeltScene.instantiate()
	add_child(belt)
	belt.jamo_list.assign(["ㅂ", "ㅜ", "ㄹ", "ㅜ"])
	belt.slot_assignments.assign([0, 0, 1, 1])
	belt.set_unlocked_slot_count(3)
	var emitted: Array
	belt.parsed_towers_updated.connect(func(value): emitted = value)
	belt.render_belt()
	check(emitted.size() == 4, "Belt must emit four positional slots")
	check(emitted[0].get("syllable") == "부", "Slot 1 must build 부")
	check(emitted[1].get("syllable") == "루", "Slot 2 must build 루")
	belt.add_jamo("ㄱ")
	check(belt.slot_assignments[-1] == -1, "New jamo must enter waiting")
	belt.free()
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& $Godot --headless --path godot res://tests/test_tower_traits.tscn
```

Expected: FAIL because `slot_assignments` and `set_unlocked_slot_count` do not exist and parsing is still global.

- [ ] **Step 3: Implement parallel assignments and tray rendering**

Add `slot_assignments`, normalize its length in one helper, filter tile indices per slot, validate each tray with the existing parser, and emit four positional entries. Render four labeled drop trays plus waiting; make `JamoTileBox` carry its destination assignment and move both parallel values during drag. Reject a candidate move unless the destination parses to zero or one fully consumed tower. `remove_jamo(index)` removes from both arrays and renders once.

```gdscript
var slot_assignments: Array[int] = []
var unlocked_slot_count := 3

func add_jamo(c: String) -> void:
	if jamo_list.size() < 30:
		jamo_list.append(c)
		slot_assignments.append(-1)
		render_belt()

func remove_jamo(index: int) -> void:
	if index < 0 or index >= jamo_list.size(): return
	jamo_list.remove_at(index)
	slot_assignments.remove_at(index)
	render_belt()
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the Task 1 command. Expected: `tower trait tests passed`, exit 0.

- [ ] **Step 5: Commit Task 1**

```powershell
git add godot/scripts/ui/JamoBelt.gd godot/scenes/tower/JamoBelt.tscn godot/tests/test_tower_traits.gd
git commit -m "feat(ui): assign jamo to independent tower trays"
```

---

### Task 2: Positional Tower Placement

**Files:**
- Modify: `godot/scripts/tower/DefenseField.gd`
- Test: `godot/tests/test_wave_balance.gd`

**Interfaces:**
- Consumes: four-entry parsed list where empty dictionaries mean empty slots
- Produces: towers remain in their assigned slot index

- [ ] **Step 1: Write the failing positional-placement test**

Instantiate `DefenseFieldScene`, call `update_towers_from_parsed_list([{}, tower_data_for_루, {}, {}])`, and assert slot 0 stays empty while slot 1 owns the only tower.

```gdscript
var parsed = [{}, {"syllable": "루", "word_data": {"category": "basic", "damage": 4, "is_unknown": true}}, {}, {}]
field.update_towers_from_parsed_list(parsed)
check(field.tower_slots[0].get_node_or_null("WordTower") == null, "Empty slot must stay empty")
check(field.tower_slots[1].get_node_or_null("WordTower") != null, "Slot 2 tower must not compact into slot 1")
```

- [ ] **Step 2: Run and verify RED**

Run `res://tests/test_wave_balance.tscn`. Expected: FAIL because empty entries are passed to tower creation or compacted.

- [ ] **Step 3: Skip empty positional entries**

Change the existing indexed loop to preserve each list index and `continue` when the entry is empty. Name instantiated towers `WordTower` so the scene assertion observes real placement.

- [ ] **Step 4: Run and verify GREEN**

Run `res://tests/test_wave_balance.tscn`. Expected: `wave balance tests passed`, exit 0.

- [ ] **Step 5: Commit Task 2**

```powershell
git add godot/scripts/tower/DefenseField.gd godot/tests/test_wave_balance.gd
git commit -m "fix(tower): preserve assigned tower slot positions"
```

---

### Task 3: Save and Load Slot Assignments

**Files:**
- Modify: `godot/scripts/core/SaveManager.gd`
- Modify: `godot/scripts/ui/TowerDefenseMain.gd`
- Modify: `godot/scripts/ui/ShopModal.gd`
- Test: `godot/tests/test_wave_balance.gd`

**Interfaces:**
- Produces: save field `slot_assignments: Array[int]`
- Consumes: `JamoBelt.remove_jamo(index)` and `JamoBelt.set_unlocked_slot_count(count)`

- [ ] **Step 1: Write failing save round-trip and migration tests**

Save a known inventory with `[0, 0, 1, 1, -1]`, reload, and assert exact equality. Also assert missing assignments normalize to an all-`-1` array of the inventory length through a small `JamoBelt.restore_assignments(saved)` method.

- [ ] **Step 2: Run and verify RED**

Run `res://tests/test_wave_balance.tscn`. Expected: FAIL because save data omits assignments.

- [ ] **Step 3: Persist, restore, and keep arrays synchronized**

Add an optional final `slot_assignments: Array = []` argument to `SaveManager.save_game` and store it. Pass `jamo_belt.slot_assignments` from `save_game_state`. On load, assign the jamo inventory, set the unlocked count, then restore assignments. New game clears assignments to waiting. Replace direct shop removal from `jamo_list` with `jamo_belt.remove_jamo(idx)`.

- [ ] **Step 4: Run and verify GREEN**

Run `res://tests/test_wave_balance.tscn`. Expected: exit 0.

- [ ] **Step 5: Commit Task 3**

```powershell
git add godot/scripts/core/SaveManager.gd godot/scripts/ui/TowerDefenseMain.gd godot/scripts/ui/ShopModal.gd godot/tests/test_wave_balance.gd
git commit -m "feat(save): persist tower tray assignments"
```

---

### Task 4: Tower Hover Range and Description

**Files:**
- Modify: `godot/scripts/tower/WordTower.gd`
- Test: `godot/tests/test_tower_traits.gd`

**Interfaces:**
- Produces: `is_hovered: bool`, native `BtnSelect.tooltip_text`, hover range drawing
- Consumes: `word_data.desc`, `damage_per_attack()`, `attack_range`, `attack_interval`

- [ ] **Step 1: Write the failing hover behavior test**

Create a real tower, emit `mouse_entered` on its selection button, and assert `is_hovered`, tooltip content, and redraw-visible range state. Emit `mouse_exited` and assert the state clears.

```gdscript
tower.btn_select.mouse_entered.emit()
check(tower.is_hovered, "Tower hover must show its range")
check(tower.btn_select.tooltip_text.contains(str(int(tower.attack_range))), "Tooltip must include range")
check(tower.btn_select.tooltip_text.contains("설명"), "Tooltip must include description")
tower.btn_select.mouse_exited.emit()
check(not tower.is_hovered, "Range must hide after hover")
```

- [ ] **Step 2: Run and verify RED**

Run `res://tests/test_tower_traits.tscn`. Expected: FAIL because hover state and tooltip are absent.

- [ ] **Step 3: Reuse the selection button for hover UI**

Connect `mouse_entered` and `mouse_exited` in `_ready`, update `is_hovered`, and call `queue_redraw()`. Populate the tooltip after tower stats are calculated. In `_draw`, draw the existing range arc whenever `is_hovered`; keep the first-craft magic circle behavior unchanged.

- [ ] **Step 4: Run focused and full verification**

```powershell
& $Godot --headless --path godot res://tests/test_tower_traits.tscn
& $Godot --headless --path godot res://tests/test_wave_balance.tscn
& $Godot --headless --path godot res://tests/early_wave_playtest.tscn
npm test
git diff --check
```

Expected: all commands exit 0; existing UID and ObjectDB cleanup warnings may remain, but no test failure or script error appears.

- [ ] **Step 5: Commit Task 4**

```powershell
git add godot/scripts/tower/WordTower.gd godot/tests/test_tower_traits.gd
git commit -m "feat(tower): show range and details on hover"
```
