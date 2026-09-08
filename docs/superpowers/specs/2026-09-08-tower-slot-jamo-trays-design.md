# Tower Slot Jamo Trays and Hover Info

## Goal

Let players decide which jamo build each tower. Each unlocked tower slot owns one independent jamo tray; only the tiles in that tray are parsed into that slot's tower. Newly acquired and migrated tiles remain in a waiting tray until assigned. Hovering a tower reveals its range and concise combat information.

## State

`JamoBelt` keeps the existing ordered `jamo_list` plus a parallel integer `slot_assignments` array. Each assignment is `-1` for waiting or `0..3` for a tower slot. Tile reorder and removal update both arrays together. This preserves existing callers that need the flat jamo inventory while adding the minimum state needed for independent trays.

New games assign starting jamo to waiting. Newly acquired jamo also goes to waiting. Saves include `slot_assignments`; older saves without it migrate every tile to waiting. Assignments outside the currently unlocked slot range are normalized to waiting.

## Parsing and Validation

Each unlocked slot filters its assigned jamo in inventory order and calls the existing `HangulStreamParser`. Empty or incomplete trays produce no tower. A tray is valid only when parsing yields at most one tower and that tower consumes every tile in the tray. A drop that would make the destination invalid is rejected and leaves both trays unchanged.

`JamoBelt` emits a four-position parsed list containing either a tower dictionary or an empty dictionary. `DefenseField` updates tower slots positionally instead of compacting the list, so an empty first tray does not move the second tray's tower.

## UI and Interaction

The belt renders one labeled tray per tower slot followed by a waiting tray. Locked trays remain visible but dimmed and reject drops. Every tile remains individually draggable between trays; ordering inside a tray uses the existing insertion behavior. New rewards visibly appear in waiting.

Tower hover uses the existing full-size transparent selection button. Mouse enter/exit toggles a range circle drawn by `WordTower`; the button's native tooltip displays the word description, effective range, damage per attack, and attack interval. Clicking continues to open the existing detail modal.

## Integration

`TowerDefenseMain` passes the current unlocked-slot count into belt rendering, saves both jamo arrays, restores both arrays, and moves assignments from newly locked slots back to waiting on load. Shop removal uses a `JamoBelt` removal method so the parallel arrays cannot diverge.

## Verification

Godot tests cover independent parsing (`부` and `루` in separate trays), new/migrated tiles entering waiting, locked-slot rejection, positional tower placement, save round-trip, and hover tooltip/range visibility. Existing wave, tower-trait, early-playtest, and web tests remain green.
