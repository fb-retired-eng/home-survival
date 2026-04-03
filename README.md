# Home Survival

`Home Survival` is a Godot 4 top-down survival-defense prototype.

The current MVP0 goal is to prove this loop:

`day prep -> dinner -> night defense -> sleep -> repeat`

## MVP0 Summary
- Desktop-first Godot 4 project
- One 2x larger authored map
- Central abstract base
- Six scavenging POIs
- Table + bed prep loop
- Eight-wave authored run target
- Small, readable systems intended to be extended later

The current run can start with hostile POIs already active, while wave enemies remain reserved for sleep-triggered base-defense phases.

## Current Project State
The repo currently includes:
- project scaffold and main scene setup
- player movement, health, energy, melee/ranged attack, medicine use, and inventory tracking
- multiple weapons, including POI-obtained baseball bat, pistol, and shotgun upgrades, bullet pickups, weapon switching, reloadable firearm behavior, simple on-player weapon illustrations, and visible weapon-trait HUD text
- food as a prep resource, a dinner-at-table transition that starts the night wave, and bed-based sleep that returns the run to the next day with partial HP restore
- six authored POIs, eight authored waves, roaming prep-stage exploration spawns, and six live enemy definitions including elite spitter and elite brute variants
- fortified wall/door upgrades beyond the original reinforced tier
- review-driven guardrails around elite-only weapon drops, spitter structure range, reset-state UI consistency, and bat-only attack interrupt behavior
- HUD for core status display, including the currently equipped weapon
- construction-system foundation for a larger authored map with a local buildable band around the home, build-mode placement, tactical cell reservations, selectable multi-cell buildables, and the first barricade placeable with repair/recycle support; this is now an active tactical layer, not just scaffolding
- home-anchored fog-of-war that starts beyond the local home area and keeps areas the player has already visited revealed, so the enlarged map has clearer nearby readability and persistent exploration memory
- MVP0.5 boot shell with authored menu and pause scenes, continue/load slots, persistent settings, pause-menu save/quit, and versioned run saves that restore construction and fog memory; manual saves are blocked during active waves, loading a slot no longer rewrites it on entry, and fullscreen now applies through Godot's window mode API
- enriched outer-map structure with authored district landmarks, route islands, micro-loot between POIs, and a broader ambient roaming-threat layer so the enlarged map has actual travel value instead of empty margins
- data-driven POI identity through `PoiDefinition` resources, with role-driven bonus tables, POI-tied micro-loot defaults, explicit `poi_id` wiring, and probe-visible role labels for debugging and UI
- generated positional combat and interaction SFX, including weapon-specific attack sounds, hit-vs-miss feedback, zombie attack tell/impact, structure hits, trap triggers, pickup sounds, and construction feedback routed through a dedicated `SFX` bus
- shared app-service access through `AppServices`, so boot/game code resolve autoloaded settings/save services through one helper instead of ad hoc `/root/...` lookups
- placeholder world scenes for sockets, scavenging nodes, bed/table interactions, pickups, and zombie enemy
- consolidated MVP0 design/spec documentation

This is still an early prototype scaffold, not a feature-complete vertical slice.

## Run Locally
If Godot is installed on macOS as `/Applications/Godot.app`, the CLI binary is:

```bash
/Applications/Godot.app/Contents/MacOS/Godot
```

From the repo root you can open the project with:

```bash
godot --path .
```

Headless validation:

```bash
godot --headless --path . --quit
```

## Controls
- Move: `WASD` or arrow keys
- Attack: `Space` or left mouse
- Interact: `E`
- Use medicine: `F` or `Q`
- Switch weapon: `X`
- Reload firearm: `C`
- Toggle build mode: `B`
- Cycle buildables while in build mode: `Q` for previous, `Tab` or mouse wheel for next
- Rotate selected buildable while in build mode: `R`
- Place selected buildable while in build mode: `E`
- Recycle full-health buildable while in build mode: `C`
- Pause / resume: `Esc`
- Eat dinner at table / sleep on bed: `E` when in range
- Restart after win/loss: `Shift+R`

## Important Docs
- [`MVP0_SPEC.md`](MVP0_SPEC.md): implementation source of truth
- [`MVP0_5_SPEC.md`](MVP0_5_SPEC.md): bridge spec for menu, settings, save/load, and persistence
- [`MVP1_SPEC.md`](MVP1_SPEC.md): expansion spec for power, dog synergy, and heirlooms
- [`MVP0_ONE_PAGER.md`](MVP0_ONE_PAGER.md): product framing
- [`TASK_BREAKDOWN.md`](TASK_BREAKDOWN.md): milestone plan
- [`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md): coding and review workflow, including the picky post-change review rule
- [`GODOT_BEST_PRACTICES.md`](GODOT_BEST_PRACTICES.md): repo-specific rules for scene ownership, resource-driven tuning, controller boundaries, and save-friendly Godot architecture
- [`PROJECT_EXECUTION_LOG.md`](PROJECT_EXECUTION_LOG.md): append-only project execution log
- [`CONSTRUCTION_SYSTEM_PLAN.md`](CONSTRUCTION_SYSTEM_PLAN.md): staged plan for controlled free-grid construction, barricades, and future turrets
- [`MVP0_DESIGN.md`](MVP0_DESIGN.md): archive pointer for the old design doc path

## Change Checklist
- Significant code change: run runtime validation first, then an automatic picky review pass in the same session
- Prefer an independent reviewer subagent for the picky review rather than only a same-context self-check
- Picky review should be adversarial: assume the change is wrong and look for regressions, state-machine bugs, reset-order bugs, and config drift
- For gameplay, AI, combat, collision, spawn, or reset changes, run a targeted runtime probe when feasible, not just a static code review
- A zero-finding review still needs evidence: list the negative checks or runtime-probe results instead of saying only `no issue found`
- Fix review findings, re-run validation, then review again if the fixes are substantial

## Repo Structure
- [`project.godot`](project.godot): Godot project entry
- [`scenes/`](scenes): scene files
- [`scripts/`](scripts): gameplay scripts
- [`data/`](data): future data-driven content definitions

## Next Development Steps
- tune food scarcity versus prep energy demands
- balance roaming prep spawns and the full 8-wave run
- tune elite weapon-drop odds and duplicate-conversion economy
- decide whether elite variants need even stronger silhouette differentiation beyond the new aura/marker treatment
- decide whether the next content step is enemy patrols, reserve-ammo scarcity, or the fifth weapon pickup
- tune the selectable buildable catalog and add the next construction-placeable type after barricades and spike traps
- tune the enlarged-map enrichment pass so landmark density, micro-loot, and ambient roaming pressure feel worthwhile without crowding prep-time scavenging
- keep pushing POI tuning through `PoiDefinition` data instead of scene-only overrides now that role-driven reward defaults and validation are in place
- keep improving combat and interaction audio feel now that the basic SFX layer is in place
- continue UI and readability polish from playtest feedback
