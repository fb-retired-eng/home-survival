# Home Survival

`Home Survival` is a Godot 4 top-down survival-defense prototype.

The current MVP0 goal is to prove this loop:

`scavenge -> return -> strengthen base -> sleep -> defend -> repeat`

## MVP0 Summary
- Desktop-first Godot 4 project
- One larger authored map
- Central abstract base
- Four scavenging POIs
- Sleep-triggered zombie waves
- Five-wave authored run target
- Small, readable systems intended to be extended later

The intended run starts safe before the first wave. Later daytime exploration phases may include ambient enemies near POIs, while wave enemies are reserved for base-defense phases.

## Current Project State
The repo currently includes:
- project scaffold and main scene setup
- player movement, health, energy, melee attack, medicine use, and inventory tracking
- HUD for core status display
- placeholder world scenes for sockets, scavenging nodes, sleep point, pickups, and zombie enemy
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
- Fix review findings, re-run validation, then review again if the fixes are substantial

## Repo Structure
- [`project.godot`](project.godot): Godot project entry
- [`scenes/`](scenes): scene files
- [`scripts/`](scripts): gameplay scripts
- [`data/`](data): future data-driven content definitions

## Next Development Steps
- implement authored scavenging nodes and loot payout
- implement defense sockets and strengthening/repair actions
- add wave spawning and base-targeting enemy behavior
- add phase-based exploration enemies after wave 1
- complete win/loss and restart flow
