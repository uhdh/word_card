# Six-Wave Easy Balance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand each act to six waves while reducing combat pressure and increasing upgrade income.

**Architecture:** Keep the existing table-driven wave builder and extend its count table from four to six entries. Move the boss condition to wave 6, slow the spawn cadence, and adjust the existing wave-clear reward helper. No new difficulty system or configuration layer is introduced.

**Tech Stack:** Godot 4.7, GDScript, existing headless balance/playtest scenes

**Spec:** Approved in chat on 2026-09-08: six waves per act, 0.65-second spawn interval, 10G normal clear, 20G boss clear, base HP remains 20.

## Global Constraints

- `MAX_WAVES_PER_ACT` is exactly 6.
- Waves 1 through 5 contain progressively mixed normal, fast, armored, or swarm enemies.
- Wave 6 contains the existing act boss plus an escort composition.
- Enemy HP and base HP remain unchanged; reduced pressure comes from cadence, starting slots, and added income.

---

### Task 1: Six-Wave Composition

**Files:**
- Modify: `godot/scripts/tower/DefenseField.gd`
- Test: `godot/tests/test_wave_balance.gd`

**Interfaces:**
- Produces: `_build_wave_monsters(act: int, wave: int)` for waves `1..6`
- Consumes: existing enemy dictionaries and spawn queue

- [ ] **Step 1: Write failing six-wave tests**

Change expected per-act wave counts to six entries and assert waves 1 through 5 have no boss while wave 6 has exactly one. Use literal expected totals:

```gdscript
var expected_counts = [
	[7, 10, 13, 16, 18, 15],
	[12, 16, 20, 24, 28, 20],
	[16, 20, 24, 28, 32, 24]
]
check(field.MAX_WAVES_PER_ACT == 6, "Each act must contain six waves")
```

The six-wave mixes are:

```gdscript
var counts = [
	[[6, 0, 1, 0], [6, 2, 2, 0], [8, 3, 2, 0], [8, 4, 3, 1], [10, 5, 3, 0], [8, 3, 3, 0]],
	[[8, 2, 2, 0], [10, 3, 3, 0], [10, 5, 4, 1], [12, 6, 5, 1], [14, 7, 6, 1], [10, 5, 4, 0]],
	[[10, 3, 3, 0], [12, 4, 4, 0], [12, 6, 5, 1], [14, 7, 6, 1], [16, 8, 7, 1], [12, 6, 5, 0]]
]
```

Each inner entry is `[normal, fast, armored, swarm_batch]`; `swarm_batch == 1` means replace that wave with the stated act's existing swarm count total from `expected_counts`.

- [ ] **Step 2: Run and verify RED**

```powershell
& $Godot --headless --path godot res://tests/test_wave_balance.tscn
```

Expected: FAIL because the maximum and count table still contain four waves.

- [ ] **Step 3: Extend the existing table and move the boss**

Set `MAX_WAVES_PER_ACT = 6`. Extend the count table with the approved literal mixes, treat waves 3 and 5 as swarm waves only where `swarm_batch == 1`, and add the boss before wave 6 escorts. Keep all existing enemy stat dictionaries.

- [ ] **Step 4: Run and verify GREEN**

Run the Task 1 test command. Expected: `wave balance tests passed`, exit 0.

- [ ] **Step 5: Commit Task 1**

```powershell
git add godot/scripts/tower/DefenseField.gd godot/tests/test_wave_balance.gd
git commit -m "feat(balance): expand acts to six waves"
```

---

### Task 2: Easier Cadence and Rewards

**Files:**
- Modify: `godot/scripts/tower/DefenseField.gd`
- Test: `godot/tests/test_wave_balance.gd`

**Interfaces:**
- Produces: `SPAWN_INTERVAL := 0.65`, `_wave_clear_bonus() -> 10 or 20`

- [ ] **Step 1: Write failing pressure and reward assertions**

```gdscript
check(is_equal_approx(field.SPAWN_INTERVAL, 0.65), "Spawn interval must be 0.65 seconds")
field.current_wave = 1
check(field._wave_clear_bonus() == 10, "Normal clear must award 10 gold")
field.current_wave = 6
check(field._wave_clear_bonus() == 20, "Boss clear must award 20 gold")
```

- [ ] **Step 2: Run and verify RED**

Run `res://tests/test_wave_balance.tscn`. Expected: FAIL on cadence and both reward values.

- [ ] **Step 3: Replace inline cadence and reward literals**

Add `const SPAWN_INTERVAL := 0.65`, use it in `_process`, and return `20` at `MAX_WAVES_PER_ACT`, otherwise `10`, from `_wave_clear_bonus`.

- [ ] **Step 4: Run full verification**

```powershell
& $Godot --headless --path godot res://tests/test_wave_balance.tscn
& $Godot --headless --path godot res://tests/test_tower_traits.tscn
& $Godot --headless --path godot res://tests/early_wave_playtest.tscn
npm test
git diff --check
```

Expected: all commands exit 0; existing UID and ObjectDB cleanup warnings may remain without script errors or test failures.

- [ ] **Step 5: Commit Task 2**

```powershell
git add godot/scripts/tower/DefenseField.gd godot/tests/test_wave_balance.gd
git commit -m "balance: reduce wave pressure and raise rewards"
```
