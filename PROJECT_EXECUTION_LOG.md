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

### Sleep And Wave Slice
- Replaced the sleep-point stub with a real transition that restores player energy to full, increments the wave number, and enters `ACTIVE_WAVE`.
- Expanded `WaveManager` into a real authored wave spawner using the three lane markers and the wave counts/intervals from the spec.
- Added live wave-state HUD display and phase-aware sleep labels so the player can see when the next wave will start.
- Updated zombies to use wave targeting behavior against intact defense sockets first and the player only after the base is breached.
- Tightened combat grouping so player melee only hits enemies and spawned wave enemies no longer depend on hand-placed scene content.

Validation:
- Headless Godot project load succeeded after the sleep and wave implementation.

### Wave Architecture And Blocking Fixes
- Converted defense sockets into real static blockers that disable collision only when breached, so wave enemies cannot walk through intact base defenses.
- Updated player interaction detection to handle both area-based interactables and body-based blockers, preserving socket repair and strengthen interactions after the scene change.
- Moved zombie combat stats into a shared enemy definition resource so future wave and exploration spawners can reuse the same enemy data without duplicating stats.
- Split wave enemies into a dedicated `WaveEnemies` layer and reserved a separate `ExplorationEnemies` layer so wave cleanup no longer wipes future daytime enemies.
- Refined wave zombie behavior so sockets remain the primary siege target, but the player is hit when physically obstructing a zombie on the way in.
- Added authored-wave validation and final-wave syncing so wave-data drift no longer traps the run in an empty `ACTIVE_WAVE` state.

Validation:
- Headless Godot project load succeeded after the architecture and blocking fixes.

### Reset And Perimeter Cleanup
- Resized and repositioned the six authored sockets so they now form a continuous perimeter around the base instead of leaving large open gaps.
- Added per-run reset hooks for the player, defense sockets, and scavenge nodes so a future restart path can restore a clean run state instead of reusing depleted or damaged world state.
- Made sleep misconfiguration visible in the interaction prompt while keeping sleep interactable in `PRE_WAVE`.
- Improved zombie obstruction handling so stationary player blocking near a socket still counts as obstruction instead of relying only on slide collisions.

Validation:
- Headless Godot project load succeeded after the reset and perimeter cleanup.

### Review Follow-Up Fixes
- Added a line-of-sight ray check to zombie obstruction logic so players are no longer damaged through intact sockets or walls.
- Moved the sleep energy refill behind successful wave-start validation so failed or misconfigured sleep attempts do not grant free recovery.
- Cleared the player's cached nearby interactables during run reset so teleports and future restart flow do not leave stale prompt state behind.

Validation:
- Headless Godot project load succeeded after the review follow-up fixes.

### Drops, Restart, And Tuning
- Added zombie salvage drops using the shared enemy definition resource, with a guaranteed `1 Salvage` drop and a `20%` chance to drop `2 Salvage` total.
- Implemented a real restart action on `R` for `WIN` and `LOSS`, reusing the existing run reset hooks and clearing leftover pickups on restart.
- Tuned the authored wave counts and intervals back to the MVP0 spec values for waves `1` through `3`.
- Added lane-preferred socket targeting so north, east, and west spawns pressure the expected sides of the base first instead of choosing any socket globally.

Validation:
- Headless Godot project load succeeded after the drop, restart, and tuning changes.

### Config Safety Cleanup
- Hardened wave startup validation so authored waves now require a valid player reference, defense socket container, and at least one registered defense socket before a wave can begin.
- Filtered the wave socket list to the actual `defense_sockets` group so future helper nodes under the socket container do not break siege targeting.
- Made resource pickups keep their world presence if inventory insertion fails, preventing silent loss from bad authored pickup IDs or future drop mistakes.

Validation:
- Headless Godot project load succeeded after the config-safety cleanup.

### MVP0 Polish Pass
- Added clearer HUD state reads for phase and overall base integrity so the player can track run flow and defense health without inspecting individual sockets.
- Reworked pre-wave and active-wave status text so the game now communicates the next useful action instead of only naming the state.
- Added socket damage flash feedback so siege hits read more clearly during defense.
- Hooked defense socket state changes into the main game loop so HUD base status updates live during repairs, strengthens, breaches, and resets.

Validation:
- Headless Godot project load succeeded after the MVP0 polish pass.

### Spatial And Perimeter Cleanup
- Tightened the player camera zoom so the playable space occupies more of the screen during normal play.
- Increased the player interaction radius so doors and wall sockets are easier to repair or strengthen from inside the base.
- Thickened the authored wall and door socket sizes slightly to reduce seam leaks and make the intact perimeter more reliable as a blocker.

Validation:
- Headless Godot project load succeeded after the spatial and perimeter cleanup.

### Control Layout Cleanup
- Moved keyboard attack from `J` to `Space` while keeping left mouse as the mouse attack input.
- Simplified interaction to `E` only so attack and interact no longer compete for the same key.
- Updated the README controls section to match the current project bindings, including restart on `R`.

Validation:
- Headless Godot project load succeeded after the control layout cleanup.

### Display And Door Collision Follow-Up
- Added explicit Godot window stretch settings so the game viewport scales to the window instead of reading like a small fixed-size scene.
- Tightened the player camera zoom again so the world occupies more of the screen during normal play.
- Split door visual size from door collision size so the doors still read as substantial barriers while letting the player move closer to them from inside the base.

Validation:
- Headless Godot project load succeeded after the display and door collision follow-up.

### Interior Interaction Cleanup
- Replaced direct socket-body interaction with dedicated socket interaction proxy areas so base blockers can stay physically honest while still being easy to repair and strengthen from inside the base.
- Restored door collision to match the visible door instead of relying on narrower hidden collision.
- Authored explicit interior interaction zones for all six sockets so wall and door maintenance works from the intended side of the perimeter.

Validation:
- Headless Godot project load succeeded after the interior interaction cleanup.

### Perimeter Alignment Follow-Up
- Moved the wall and door blockers outward so their inner faces align with the base perimeter instead of intruding into the base interior.
- Tightened the player camera zoom further so the authored MVP0 map occupies more of the visible play window.

Validation:
- Headless Godot project load succeeded after the perimeter alignment follow-up.

### Screenshot-Driven Camera Correction
- Reversed the previous camera zoom drift after reviewing a real game-window screenshot that showed the world rendered too small inside a large debug window.
- Restored the player camera to `Vector2(1, 1)` so the authored map is framed closer to a one-screen playfield instead of a distant overview.

Validation:
- Headless Godot project load succeeded after the screenshot-driven camera correction.

### HUD Readability Cleanup
- Replaced the floating top-left HUD text with a dedicated semi-opaque panel so health, energy, wave, and status text remain readable over the playfield.
- Added wrapping to longer status and interaction lines so guidance text stays legible instead of stretching across the world view.

Validation:
- Headless Godot project load succeeded after the HUD readability cleanup.

### Perimeter Readability Cleanup
- Hid the always-on socket HP labels to reduce on-map text clutter that was making the closed perimeter hard to read.
- Added subtle inner perimeter edge lines to the base floor so the actual blocking boundary is visually clearer before any socket is breached.

Validation:
- Headless Godot project load succeeded after the perimeter readability cleanup.

### No-Op Action Cost Cleanup
- Updated melee attack so energy and cooldown are only consumed when at least one valid enemy is actually inside the attack area.
- Whiffing into empty space now has no gameplay cost, matching the intended rule that ineffective actions should not consume resources.

Validation:
- Headless Godot project load succeeded after the no-op action cost cleanup.

### Contextual Socket Labels
- Restored socket HP labels only while the player is inside that socket's interaction zone, keeping the map clear at a distance while still exposing wall and door state during maintenance.
- Connected the socket interaction proxy to player enter/exit events so label visibility follows actual nearby interaction context instead of staying always on or always off.

Validation:
- Headless Godot project load succeeded after the contextual socket labels pass.

### Perimeter Seal Cleanup
- Increased overlap between adjacent wall and door socket blockers so the `24x24` player body cannot slip through intact perimeter seams before a socket is actually breached.
- Expanded the related interior interaction areas to keep maintenance interaction comfortable after the blocker sizes changed.

Validation:
- Headless Godot project load succeeded after the perimeter seal cleanup.

### Real Door And Wall Split
- Stopped treating doors as just thin walls by moving intact doors onto a separate blocker layer that the player ignores but zombies still collide with.
- Kept intact walls on the normal world-blocker layer so players and zombies are both blocked until the wall is breached.
- Updated zombie movement and damage detection to include both blocker layers, so siege enemies still path into and attack intact doors correctly.

Validation:
- Headless Godot project load succeeded after the real door and wall split.

### Player Collision Explicitness
- Set the player body's collision layer and mask explicitly to the wall-blocker layer so door passability no longer depends on Godot's default collision-mask behavior.

Validation:
- Headless Godot project load succeeded after the player collision explicitness follow-up.

### Dedicated Barrier Layers
- Replaced the ambiguous shared player/wall collision setup with dedicated physics layers: player body on layer `1`, intact walls on layer `2`, and intact doors on layer `3`'s bitmask value.
- Set the player to collide only with wall blockers, while zombies still collide with both wall and door blockers plus the player.
- Updated zombie contact and attack range detection to use the same explicit barrier-layer model.

Validation:
- Headless Godot project load succeeded after the dedicated barrier layer cleanup.

### Wall Occlusion Clarity
- Added Y-based draw ordering for the player and defense sockets so top walls visually occlude the player when they are on the far side instead of making it look like the player is standing on the wall surface.

Validation:
- Headless Godot project load succeeded after the wall occlusion clarity pass.

### Door Assumption Reversal
- Reverted the mistaken player-passable door model. Intact doors now block the player the same way intact walls do, matching the current perimeter expectation that no segment is traversable until breached.

Validation:
- Headless Godot project load succeeded after the door assumption reversal.

### Wall And Door Mapping Correction
- Reinstated the intended collision split after re-reading the screenshots: north/south wall sockets remain solid for the player, while west/east door sockets are again placed on the separate non-player blocker layer.
- Kept zombie collision configured against both barrier layers so wave enemies still collide with and attack intact walls and intact doors.

Validation:
- Headless Godot project load succeeded after the wall and door mapping correction.

### Wall Footprint Alignment
- Reduced the north and south wall socket widths from `232` back to `200` so their colliders match the actual base width instead of protruding past the house footprint.
- Kept the door heights unchanged, since the screenshot issue was coming from the horizontal wall rectangles creating exterior vertical side faces near `wall_nw` and `wall_ne`.

Validation:
- Headless Godot project load succeeded after the wall footprint alignment fix.

### Four-Socket Perimeter Redesign
- Simplified the base perimeter from six sockets to four: one full-width top wall, one full-width bottom wall, and one vertical door on each side.
- Removed the split north/south wall segments and updated lane targeting so wave zombies now prefer `wall_n` from the north, `door_e` from the east, and `door_w` from the west.
- Re-authored the starting wall HP values for the new two-wall layout while keeping the side doors as the player traversal points.

Validation:
- Headless Godot project load succeeded after the four-socket perimeter redesign.

### Socket Collider Resource Fix
- Found that all defense socket instances were mutating the same shared `RectangleShape2D` resources, so door sockets were overwriting wall collider sizes at runtime.
- Duplicated the blocker and interaction shapes per socket instance during `_ready()`, which restores the intended full-width horizontal walls and keeps the doors as separate vertical colliders.
- Removed the temporary debug overlap script after confirming the root cause.

Validation:
- Headless Godot project load succeeded after the socket collider resource fix.

### Data-Driven Perimeter
- Moved perimeter authoring out of `Game.tscn` into `data/resources/mvp0_perimeter.tres` so socket IDs, positions, HP, collider sizes, and interaction zones now live in one authored resource.
- Added lightweight perimeter resource scripts and updated `Game` to instantiate defense sockets at runtime from that resource before wave-manager setup and base-status binding.
- Removed the hand-authored defense socket instances from the main scene so the scene no longer has a second competing perimeter definition.
- Fixed the runtime build order so perimeter socket properties are assigned before each socket enters the scene tree; otherwise Godot was running `_ready()` with the default `48x16` socket geometry and drawing tiny placeholder bars.

Validation:
- Headless Godot project load succeeded after the data-driven perimeter refactor.

### Perimeter Hardening And Interaction Priority
- Added perimeter resource validation in `Game` so bad resource types, duplicate socket IDs, and invalid sizes are rejected with warnings instead of causing blind property access on generic resources.
- Added explicit interaction priority so the sleep point outranks wall/door actions and scavenge nodes outrank sockets when multiple interactables overlap the player.
- Changed the authored perimeter resource to start at full HP and updated the opening pre-wave status text so the run no longer appears to begin with unexplained base damage.

Validation:
- Headless Godot project load succeeded after the perimeter hardening and interaction-priority cleanup.

### Defense Balance Tuning
- Reduced zombie move speed and slightly slowed their structure attack cadence so wave enemies do not reach and chew through the base as quickly.
- Lowered per-hit structure damage from the basic zombie definition.
- Increased damaged and reinforced HP for both walls and doors, and updated the authored starting perimeter HP values to match the new stronger base.

Validation:
- Headless Godot project load succeeded after the defense balance tuning pass.

### Typed Structure Damage Model
- Added data-driven structure profiles for walls and doors, including tier HP, repair/strengthen costs, and per-damage-type reduction rules.
- Added enemy `structure_damage_type` to the shared enemy definition model and updated zombies to send typed structure damage payloads when attacking sockets.
- Updated perimeter segment data so each authored socket references a wall or door structure profile, letting future enemy/resource tuning happen through data instead of hardcoded wall-vs-door branches.

Validation:
- Headless Godot project load succeeded after the typed structure damage model refactor.

### Enemy Defense Stats
- Extended `EnemyDefinition` so enemy resources can now configure HP, defense reduction, defense multiplier, player damage, structure damage, structure damage type, move speed, attack interval, and salvage drops in one place.
- Updated player melee to send a typed damage payload and updated zombies to resolve incoming damage through the shared enemy definition instead of assuming all incoming damage is raw.
- Kept the default zombie config neutral on defense for now, but future enemy resources can now vary survivability and resistance by data.

Validation:
- Headless Godot project load succeeded after the enemy defense stats refactor.

### Socket Profile Cleanup
- Moved the remaining wall/door tuning out of `DefenseSocket` code and into `StructureProfile` resources, including damaged/reinforced/breached colors and interaction priority.
- Removed the old wall-vs-door fallback stats/cost branches from `DefenseSocket`; sockets now expect a structure profile for HP, costs, and damage reduction.
- Kept only engine-facing logic such as blocker layers in code, while gameplay tuning now lives in the wall and door profile `.tres` files.

Validation:
- Headless Godot project load succeeded after the socket profile cleanup.

### Wave Definitions To Data
- Moved wave counts, spawn intervals, lane IDs, and preferred socket targets out of `wave_manager.gd` into `data/waves/mvp0_waves.tres`.
- Added wave-set, wave, and wave-lane resource scripts so authored wave data can be validated and cached into the runtime spawn queue without hardcoded dictionaries.
- Updated `WaveManager` and `Game.tscn` to load wave behavior from the wave-set resource while preserving the existing 3-wave MVP0 flow.

Validation:
- Headless Godot project load succeeded after the wave-definition data refactor.

### Config Validation Hardening
- Tightened perimeter validation so segments without a valid `StructureProfile` are rejected before sockets are instantiated.
- Made sockets fail closed when their structure profile is missing, preventing free repair/strengthen actions from empty cost dictionaries.
- Tightened wave validation so preferred socket IDs must match the live perimeter, invalid lane resources invalidate the whole wave, and non-positive spawn intervals are rejected.

Validation:
- Headless Godot project load succeeded after the config validation hardening pass.

### Multiple Enemy Types In Wave Data
- Added per-lane `enemy_definition` references to wave data so lane entries now choose which enemy config to spawn instead of assuming a single global zombie type.
- Added a second enemy resource, `zombie_brute`, with distinct HP, speed, defense, damage, salvage, and visual color.
- Extended wall and door structure profiles with `crush` damage modifiers and updated wave 3 to mix brutes into the east and west lanes.

Validation:
- Headless Godot project load succeeded after the multi-enemy wave-data update.

### Review Fixes For Data Validation
- Reduced the basic-zombie counts in wave 3 so the brute rollout adds variety without unintentionally inflating the total enemy count.
- Added validation methods for structure profiles and enemy definitions so malformed modifier resources or mismatched wall/door profiles are rejected instead of silently falling back.
- Tightened perimeter and wave validation to require profile/type consistency before content is accepted into the runtime caches.

Validation:
- Headless Godot project load succeeded after the review-fix data validation pass.
