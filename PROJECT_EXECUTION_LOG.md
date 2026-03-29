# Project Execution Log

This file is the running execution log for `Home Survival`.

## Log Rules
- Append-only unless a previous entry is factually wrong
- Use absolute dates
- Record what changed, why it changed, and how it was validated
- Keep entries short and operational

## 2026-03-28

### Repository Setup
- Consolidated MVP0 implementation details into [`MVP0_SPEC.md`](MVP0_SPEC.md) and reduced the old design doc path to an archive pointer in [`MVP0_DESIGN.md`](MVP0_DESIGN.md).
- Clarified that damaged sockets can be repaired with `Salvage`.
- Added deterministic baseline scavenging rewards so the run always has a theoretical win path.
- Extended the spec with stable IDs, script boundaries, and data-driven guardrails for future expansion.
- Refined the design so the run starts with no enemies before the first wave, while later daytime exploration can include ambient enemies that do not target the base.

Validation:
- Docs reviewed and aligned to a single source of truth.

### Godot Project Scaffold
- Created the Godot scene and script structure for MVP0.
- Set `res://scenes/main/Game.tscn` as the main scene in [`project.godot`](project.godot).
- Added placeholder scenes for player, HUD, zombie, defense socket, scavenging node, sleep point, and resource pickup.
- Added initial manager scripts for run state and wave scaffolding.

Validation:
- Headless Godot project load succeeded.

### Core Prototype Slice
- Implemented player movement, health, energy, melee attack, medicine use, damage, death, and resource inventory tracking.
- Added a minimal game script to bind HUD and loss state.
- Added resource pickups and placeholder HUD status/resource display.
- Removed the invalid startup enemy from the main scene so the prototype begins in a safe pre-wave state.

Validation:
- Headless Godot project load succeeded after scene and script fixes.

### Git and GitHub Setup
- Configured git global identity to the connected GitHub account `fb-retired-eng`.
- Created the initial project commit and amended author metadata to the GitHub noreply identity.
- Installed `gh`, authenticated GitHub CLI, merged the pre-existing remote README history, and pushed `main` to GitHub.

Validation:
- `git push -u origin main` succeeded.

### README
- Replaced the placeholder README with a project overview, local run instructions, controls, key docs, and next development steps.

### Scavenging Interaction Slice
- Added a minimal interaction system to the player with proximity-based prompts, interact-key handling, and timed actions.
- Replaced temporary loose pickups in the main scene with 8 authored scavenging nodes across `POI_A` and `POI_B`.
- Implemented node search duration, energy spending, direct inventory payout, depletion for the rest of the run, and POI-specific bonus reward rolls.
- Added a temporary sleep interaction stub so the shared interaction contract already covers both scavenging and sleep points.
- Hardened resource handling by validating resource IDs before adding them to player inventory.

Validation:
- Headless Godot project load succeeded after the scavenging and interaction changes.

### Interaction And Data Cleanup
- Added timed-action cancellation on death so searches cannot complete after the player dies.
- Moved interaction gating into the player/game layer so current interactables are controlled by one run-state rule.
- Replaced hardcoded POI bonus-roll logic with data-driven bonus table resources in `data/pois/`.
- Centralized more player mutations through shared resource and energy helpers.
- Replaced scaffold-only phase text with state-aware status messages such as the safe opening phase before wave 1.
- Updated scavenging prompts so low-energy nodes clearly communicate that the player is too tired to search.

Validation:
- Headless Godot project load succeeded after the interaction and resource-data cleanup.

### Defense Socket Slice
- Implemented six authored defense sockets around the base using the exact starting HP pattern from the spec.
- Added repair and strengthen interactions with resource cost checks, damaged/reinforced tier transitions, and socket HP restoration rules.
- Added placeholder socket damage handling so future wave enemies can target the same socket script instead of introducing a second damage path.
- Exposed socket status visually with per-socket labels and color changes for damaged, reinforced, and broken states.
- Extended player resource helpers so socket interactions use the same shared spend/check path as scavenging and medicine use.

Validation:
- Headless Godot project load succeeded after the defense socket implementation.
