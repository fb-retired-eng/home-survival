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
- multiple weapons, including POI-obtained baseball bat, pistol, and shotgun upgrades, bullet pickups, weapon switching, reloadable firearm behavior, true projectile-based pistol/shotgun shots, blocker-aware multi-pellet shotgun spread, bat/pistol/shotgun role tuning backed by a balance probe, simple on-player weapon illustrations, and visible weapon-trait HUD text
- food as a prep resource, a dinner-at-table transition that starts the night wave, and bed-based sleep that returns the run to the next day with partial HP restore
- six authored POIs, eight authored waves, roaming prep-stage exploration spawns, and eight live enemy definitions including screamer, breaker, elite spitter, and elite brute variants
- exploration enemies now keep chasing while they remain effectively on the current player view, then drop aggro once sight is broken and they fall off-screen/far enough away
- fortified wall/door upgrades beyond the original reinforced tier
- review-driven guardrails around elite-only weapon drops, spitter structure range, reset-state UI consistency, and bat-only attack interrupt behavior
- a polished authored UI shell across the boot menu, settings/load panels, pause overlay, and HUD, with clearer phase emphasis, tighter panel layout, cleaner resource/readout labels, icon-based resource display, stronger status treatment, more responsive firearm HUD state, and more intentional interaction prompts
- smoothed player/enemy presentation polish, including lighter player bob/lean motion, smoother enemy turning and movement presentation, clearer enemy state indicators, lingering post-alert readability cues, generic enemy scene/class naming for future non-zombie enemy types, data-driven archetype silhouettes plus archetype-specific attack-tell profiles, and a red projectile-based spitter presentation with longer detection pressure
- construction-system foundation for a larger authored map with a local buildable band around the home, build-mode placement, tactical cell reservations, selectable multi-cell buildables, and the first barricade placeable with repair/recycle support; this is now an active tactical layer, not just scaffolding
- home-anchored fog-of-war that starts beyond the local home area and keeps areas the player has already visited revealed, so the enlarged map has clearer nearby readability and persistent exploration memory
- MVP0.5 boot shell with authored menu and pause scenes, continue/load slots, persistent settings, pause-menu save/quit, and versioned run saves that restore construction and fog memory; manual saves are blocked during active waves, active-wave quitting now cleanly returns to menu without saving, loading a slot no longer rewrites it on entry, and fullscreen now applies through Godot's window mode API
- enriched outer-map structure with authored district landmarks, route islands, micro-loot between POIs, and a broader ambient roaming-threat layer so the enlarged map has actual travel value instead of empty margins
- data-driven POI identity through `PoiDefinition` resources, with role-driven bonus tables, POI-tied micro-loot defaults, explicit `poi_id` wiring, and probe-visible role labels for debugging and UI
- authored POI guard tuning and softer mid/late-wave pacing, plus an economy balance probe that reports POI yield, support loot, construction costs, and wave pressure totals for future tuning passes
- MVP1 strategic systems now live:
  - Dog companion support with follow, feed, known-POI scavenging, night lure, HUD status, and save/load
  - generator-based power management with battery upgrades, powered turrets, and floodlights
  - heirloom debris on previously broken fortified sockets, plus a small legacy-perk layer at boot
- MVP2 expansion systems now live:
  - daytime patrol pressure through scene-authored patrol routes and a dedicated `PatrolDirector`
  - daily POI events that modify reward pressure and guard expectations, including event-owned forced-elite pressure
  - a home contract board with day-specific objectives and rewards chosen from the live event/depletion-aware world state
  - powered-construction expansion with `Power Relay`, plus earlier utility placeables (`alarm beacon`, `repair station`, `ammo locker`)
  - wave- and day-facing enemy counterplay through `screamer` and `breaker`
  - one-per-day mutators that currently modify patrol count, salvage yield, floodlight strength, POI guard pressure, and enemy movement pressure
  - expanded legacy-perk pool with `ammo cache`, `scrapper`, and `trainer`
- the largest runtime scripts have been cut back into scene-owned controllers:
  - `game.gd` now delegates MVP1 run state, phase flow, POI logic, exploration, construction, and fog to child controllers
  - `enemy.gd` now delegates targeting, combat, presentation, movement, and runtime/drop plumbing to dedicated enemy controllers
- generated positional combat and interaction SFX, including weapon-specific attack sounds, hit-vs-miss feedback, enemy attack tell/impact, structure hits, trap triggers, pickup sounds, and construction feedback routed through a dedicated `SFX` bus
- shared app-service access through `AppServices`, so boot/game code resolve autoloaded settings/save services through one helper instead of ad hoc `/root/...` lookups
- placeholder world scenes for sockets, scavenging nodes, bed/table interactions, pickups, and enemy actor
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
- [`MVP2_SPEC.md`](MVP2_SPEC.md): pressure, POI events, contracts, counterplay enemies, mutators, and powered-expansion roadmap
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
- run a full MVP2 playtest pass covering patrol pressure, daily event variety, contract reward value, and relay-driven base layouts
- tune mutator intensity so `strong_lights`, `restless_dead`, and `extra_patrols` change the day meaningfully without making routes unreadable
- tune screamer and breaker wave pressure against turret/floodlight/alarm-beacon clusters
- decide whether the next post-MVP2 step is more powered utility depth, more POI-event variety, or a broader contract/intel layer
- continue weapon/combat tuning with the balance probe now that projectile firearms, spread shotgun behavior, and new defense-side enemies are stable
- continue HUD and readability polish from playtest feedback
