# Home Survival

`Home Survival` is a Godot 4 top-down survival-defense prototype.

The current MVP0 goal is to prove this loop:

`day prep -> dinner -> night defense -> sleep -> repeat`

## MVP0 Summary
- Desktop-first Godot 4 project
- One larger authored map
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
- multiple weapons, including POI-obtained baseball bat, pistol, and shotgun upgrades, bullet pickups, weapon switching, reloadable firearm behavior, and simple on-player weapon illustrations
- food as a prep resource, a dinner-at-table transition that starts the night wave, and bed-based sleep that returns the run to the next day with partial HP restore
- six authored POIs, eight authored waves, roaming prep-stage exploration spawns, and five live enemy definitions including an elite spitter variant
- fortified wall/door upgrades beyond the original reinforced tier
- review-driven guardrails around elite-only weapon drops, spitter structure range, and reset-state UI consistency
- HUD for core status display, including the currently equipped weapon
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
- Eat dinner at table / sleep on bed: `E` when in range
- Restart after win/loss: `R`

## Important Docs
- [`MVP0_SPEC.md`](MVP0_SPEC.md): implementation source of truth
- [`MVP0_ONE_PAGER.md`](MVP0_ONE_PAGER.md): product framing
- [`TASK_BREAKDOWN.md`](TASK_BREAKDOWN.md): milestone plan
- [`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md): coding and review workflow, including the picky post-change review rule
- [`PROJECT_EXECUTION_LOG.md`](PROJECT_EXECUTION_LOG.md): append-only project execution log
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
- decide whether elite variants stay data-only or get stronger visual differentiation in play
- decide whether the next content step is enemy patrols, reserve-ammo scarcity, or the fifth weapon pickup
- continue UI and readability polish from playtest feedback
