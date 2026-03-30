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
- Updated `WaveManager` and `Game.tscn` to load wave behavior from the wave-set resource while preserving the authored MVP0 wave flow.

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

### Enemy Facing Marker
- Added a visible facing marker to enemy scenes and rotated it from the current target direction so zombie orientation reads clearly while moving and while standing in attack range.

Validation:
- Headless Godot project load succeeded after the enemy facing marker update.

### Visible Attack Effects
- Added a visible melee swipe effect for the player so attacks read on screen instead of only through damage results.
- Added a brief enemy strike flash tied to zombie attack direction so enemy hits are easier to parse in combat.

Validation:
- Headless Godot project load succeeded after the visible attack effects pass.

### Review Fixes For Wave Cache And Attack Commitment
- Moved wave-definition cache rebuild to `WaveManager.configure()` so cache validation runs after live spawn markers, player, and perimeter sockets are available instead of rebuilding too early in `_ready()`.
- Fixed wave-lane cache validation so every lane now validates its enemy definition and preferred socket IDs during cache rebuild, preventing malformed wave data from being counted as a defined runnable wave.
- Changed player melee feedback so the visible swing only plays after a real hit attempt is committed, rather than showing free attack flashes when swinging at empty space.

Validation:
- Headless Godot project load succeeded after the wave-cache and attack-commitment review fixes.

### Sleep Partial HP Restore
- Changed sleep so a successful wave start now restores full energy and a small amount of HP instead of only restoring energy.
- Made the sleep heal amount configurable from `Game` so it can be tuned without touching the sleep interaction flow.
- Updated the MVP0 spec wording so the documented sleep behavior matches the current game.

Validation:
- Headless Godot project load succeeded after the sleep-heal update.

### End-State Overlay Visibility
- Added a centered end-state overlay to the HUD so victory and loss are visually obvious instead of only appearing as small text inside the top-left info panel.
- Wired `WIN` and `LOSS` state changes to show distinct overlay titles, messages, and accent colors while keeping restart instructions visible.
- Updated victory status text to use the configured final-wave count instead of a hardcoded `3`.

Validation:
- Headless Godot project load succeeded after the end-state overlay update.

### Configurable Enemy Intelligence
- Extended `EnemyDefinition` with configurable wave targeting and obstruction behavior so enemy resources can choose whether to prioritize sockets or players and whether to peel onto a blocking player.
- Updated zombie runtime targeting to read those intelligence settings from enemy configs instead of hardcoding one shared behavior in `zombie.gd`.
- Made the existing enemy types intentionally different: basic zombies still switch to a blocking player, while brutes stay committed to structure pressure.

Validation:
- Headless Godot project load succeeded after the configurable enemy-intelligence update.

### Enemy Intelligence Review Fixes
- Added exploration target mode and fallback-to-player behavior to enemy configs so the new intelligence settings apply outside wave mode and `socket_only` enemies do not go inert after all sockets are breached.
- Added contact retaliation behavior so heavy enemies can stay structure-focused without creating a free body-block exploit for the player.
- Updated the basic and brute enemy resources to author the new AI fields explicitly instead of relying on defaults.

Validation:
- Headless Godot project load succeeded after the enemy-intelligence review fixes.

### Facing-Gated Enemy Attacks
- Changed enemy melee so overlap alone is no longer enough to deal damage; enemies must also be facing the player or structure when the hit resolves.
- Added a configurable attack-facing cone threshold to enemy definitions so different enemy types can have tighter or wider attack arcs through data.
- Authored the current basic and brute enemies with different facing tolerances so heavier enemies can keep a broader attack cone without restoring rear-hit damage.

Validation:
- Headless Godot project load succeeded after the facing-gated enemy attack update.

### Nearby Player Aggro
- Added configurable nearby-player aggro and chase radii to enemy definitions so enemies can switch from their default target logic to actively pursuing the player when the player gets too close.
- Updated zombie runtime to maintain a chase state with separate acquire and break distances instead of doing a one-frame proximity override.
- Authored the current basic and brute enemies with different chase distances so lighter enemies react earlier while heavier enemies still require closer commitment.

Validation:
- Headless Godot project load succeeded after the nearby-player aggro update.

### Lowest-Tier Enemy Tuning
- Slowed the basic zombie down further and increased its attack interval so the lowest-tier enemy applies less constant pressure.
- Kept the change fully data-driven by tuning only the `zombie_basic` enemy resource.

Validation:
- Headless Godot project load succeeded after the lowest-tier enemy tuning pass.

### Lowest-Tier Enemy Tuning Pass 2
- Reduced the basic zombie move speed again and increased its attack interval again to further soften early-wave pressure.
- Kept the adjustment data-only so the balance remains editable from the enemy resource.

Validation:
- Headless Godot project load succeeded after the second lowest-tier enemy tuning pass.

### Socket Label Layout Cleanup
- Changed defense-socket HP labels to use side-aware placement instead of always rendering below the socket, which reduces overlap between wall and door labels around the base perimeter.
- Placed top-wall labels above, bottom-wall labels below, and door labels inward toward the base so nearby labels do not block each other as often.

Validation:
- Headless Godot project load succeeded after the socket-label layout cleanup.

### Player Attack Energy Tuning
- Reduced the player melee energy cost from `5` to `1` to make basic combat less punishing on the energy economy.

Validation:
- Headless Godot project load succeeded after the player attack energy tuning pass.

### Extended Wave Set
- Expanded the wave data from 3 waves to 5 waves so the run lasts longer without changing the core loop structure.
- Added two later waves with heavier mixed-lane pressure, including more north-wall basics and extra brute pressure on the side doors.
- Kept the change fully data-driven by extending `mvp0_waves.tres` only; final-wave count continues to sync from authored wave data at runtime.

Validation:
- Headless Godot project load succeeded after the wave-set extension.

### Review Fixes For Aggro And Docs Drift
- Changed nearby-player chase so it no longer overrides authored `SOCKET_ONLY` or `SOCKET_THEN_PLAYER` target modes; aggro now only takes priority for player-led target modes.
- Added line-of-sight gating to player detection so enemies do not start chasing through intact barriers.
- Generalized player lookup in enemy AI so future exploration enemies can resolve the live player without depending on wave-only setup.
- Updated stale 3-wave wording in the README, spec, and execution log to match the current authored 5-wave run.

Validation:
- Headless Godot project load succeeded after the aggro-and-docs review fixes.

### Basic Enemy Chase Override
- Added a per-enemy `chase_overrides_target_mode` setting so nearby-player aggro can be enabled for lighter enemies without forcing heavy enemies off their structure-focused behavior.
- Enabled chase override for the basic zombie and kept it disabled for the brute, restoring the intended split between player-reactive weak enemies and structure-committed heavy enemies.

Validation:
- Headless Godot project load succeeded after the basic-enemy chase override fix.

### Larger Map And Expanded Scavenging Layout
- Expanded the authored playfield from the original tight layout into a larger 1920x1080 map and recentered the base, sleep point, spawn markers, and perimeter around the new map center.
- Added two more POIs so the map now has four scavenging clusters distributed around the corners instead of only two side clusters.
- Increased the number of searchable nodes from 8 to 16 by adding four nodes each to the new POIs, giving the larger map more meaningful collection space instead of empty travel.

Validation:
- Headless Godot project load succeeded after the larger-map and POI expansion pass.

### Prep-Stage Exploration Enemies
- Added authored exploration spawn points near the POIs and wired `Game` to spawn those enemies only during later `PRE_WAVE` phases, while keeping the opening pre-wave phase safe.
- Exploration enemies now use exploration-only context, never target the base, and are cleared when a defense wave starts.
- Exploration enemies stay dormant until the player gets close, and defeated exploration spawns stay cleared for the rest of the run instead of respawning every prep phase.

Validation:
- Headless Godot project load succeeded after the prep-stage exploration-enemy pass.

### Exploration Enemy Persistence And Sleep Gating
- Changed prep-stage exploration enemies to persist across prep phases and wave transitions instead of being destroyed and respawned at full health whenever the run returns to `PRE_WAVE`.
- Exploration enemies are now suspended during active defense waves and resumed afterward, preserving their run-state without letting them interfere with base-defense targeting.
- Sleep is now blocked when an exploration enemy is actively engaged with the player, closing the exploit where a live prep threat could be deleted by sleeping.
- Updated the MVP0 spec so the authored 4-socket, 4-POI map and current baseline resource values match the actual game.

Validation:
- Headless Godot project load succeeded after the exploration-enemy persistence and sleep-gating fixes.

### Wave Spawn Spread And Enemy Crowd Steering
- Added spawn jitter to wave spawning so enemies no longer stack onto the exact lane marker position and march in a single straight file.
- Added configurable enemy separation and sidestep steering so zombies spread out and try to walk around other enemies that are blocking access to a player or structure target.
- Updated player chase detection to ignore other enemies as raycast blockers, so enemies can still notice a nearby player even when another zombie is standing between them.

Validation:
- Headless Godot project load succeeded after the spawn-spread and crowd-steering pass.

### Crowd Steering Review Fixes
- Tightened enemy attack validation so rear enemies cannot damage a player or socket through another enemy body.
- Narrowed sidestep steering to real crowd blocks near the attack target, reducing the risk of orbiting or unnecessary lateral drift.
- Changed wave spawn spread from full-circle scattering to lane-oriented fan-out, so enemies still approach from readable corridors instead of spawning behind or far off the lane marker.

Validation:
- Headless Godot project load succeeded after the crowd-steering review fixes.

### Reinforced Wall And Door Color Split
- Adjusted the reinforced structure colors in the wall and door profiles so upgraded walls and upgraded doors remain visually distinct instead of converging to the same reinforced tone.

Validation:
- Headless Godot project load succeeded after the reinforced color split update.

### Facing-Based Player Detection
- Added a separate detection facing threshold to enemy definitions so “can notice the player” is tuned independently from “can attack the player.”
- Updated chase detection so enemies only acquire nearby players when the player is inside their vision cone and line of sight, instead of noticing players from any nearby direction.

Validation:
- Headless Godot project load succeeded after the facing-based player detection update.

### Forced Enemy Awareness On Hit Or Contact
- Added a temporary player-alert state so enemies that are struck by the player or enter direct player contact will notice and chase that player even if the player was originally outside the normal detection cone.
- Kept ordinary proximity detection vision-cone-based, so only explicit combat/contact breaks the facing requirement.

Validation:
- Headless Godot project load succeeded after the forced-awareness update.

### Start-Of-Run POI Enemy Groups
- Changed exploration spawns so POI enemies can appear from the very start of the run instead of only after the first defense wave.
- Added per-spawn-point random group sizing with authored min/max counts, currently supporting groups between 1 and 5 enemies.
- Made those group sizes roll once per spawn point per run and persist correctly across prep phases and wave suspensions instead of rerolling every sync.
- Added local scatter around exploration spawn markers so POI enemies appear as loose groups instead of a single stack on the marker.

Validation:
- Headless Godot project load succeeded after the start-of-run POI group spawn update.

### Compact HUD Panel Pass
- Compressed the top-left HUD into fewer denser rows by combining HP and energy into one line and wave and phase into one line.
- Reduced the panel footprint, spacing, and text bloat so the HUD covers less of the enlarged map while keeping the important information visible.
- Shortened the resource row and refined status/interaction styling so the panel reads cleaner without losing functionality.

Validation:
- Headless Godot project load succeeded after the compact HUD pass.

### Review Fixes For Opening Threats And HUD Space
- Updated the opening pre-wave status text so it no longer claims the run starts safe now that exploration enemies can spawn near POIs from the beginning.
- Added duplicate exploration `spawn_id` validation and runtime skipping so malformed scene data cannot silently merge multiple POIs into one persistence bucket.
- Increased the compact HUD panel’s vertical breathing room and let the wrapped status and interaction rows claim vertical space, reducing the risk of clipping longer messages.

Validation:
- Headless Godot project load succeeded after the opening-threat, spawn-id, and HUD-space review fixes.

### Enemy Facing Alignment And Contact Push Fix
- Initialized enemy visuals from the same facing vector used by AI detection so newly spawned enemies no longer show a different facing direction than their internal detection cone.
- Removed zombie body-vs-player body collision so the player can no longer physically “carry” enemies around on contact, while leaving player contact/aggro behavior to the damage area and AI logic.

Validation:
- Headless Godot project load succeeded after the enemy-facing and contact-push fixes.

### Collision Layer And True Touch Follow-Up
- Moved zombie bodies onto their own physics layer so enemies collide with walls, doors, and each other again without restoring the old player-carry bug.
- Retargeted the player attack area to the new enemy layer so melee still hits correctly after the collision-layer split.
- Added a dedicated body-touch area for enemies and switched alert-on-touch to use that true body-contact signal instead of the larger attack/damage range.
- Rotated the zombie body visual from the same facing vector used by AI, making the shown facing direction easier to trust at a glance.

Validation:
- Headless Godot project load succeeded after the collision-layer and true-touch follow-up.

### Enemy Body Pressure And Sleep-Gating Fix
- Restored player collision against the enemy body layer so enemy packs occupy space again instead of being fully phaseable.
- Kept zombie bodies non-colliding against the player layer, preserving the fix for the old “player carries enemy around” artifact.
- Tightened prep-stage engagement checks so sleep blocking uses true body touch instead of the larger damage radius.

Validation:
- Headless Godot project load succeeded after the enemy body-pressure and sleep-gating fix.

### Short Player-Attack Windup
- Added a configurable player-attack preparation time to enemy definitions so enemies do not land an instant hit on the exact frame they first spot or aggro onto the player.
- Kept the general attack interval unchanged; the prep delay only affects the first player-directed hit after engagement and resets once the enemy loses the player.
- Tuned the current enemies with a short delay: basic zombies at `0.3s` and brutes at `0.4s`.

Validation:
- Headless Godot project load succeeded after the player-attack windup pass.

### General Enemy Attack Tell
- Generalized the short attack-prep timer so the same windup applies before both player attacks and structure attacks instead of only before player-directed hits.
- Moved the prep arming ahead of the visual update so the attack tell appears immediately on the first prep frame instead of one frame late.
- Added a tiny lost-target grace window so contact-edge jitter does not constantly restart the windup visual and delay.

Validation:
- Headless Godot project load succeeded after the generalized attack-tell pass.

### Kitchen Knife Weapon Data Refactor
- Added a `WeaponDefinition` resource path for player melee so damage, energy cost, cooldown, windup, hitbox, and flash styling can be tuned from weapon data instead of hardcoded player exports.
- Created the default `Kitchen Knife` weapon resource and wired the player scene to equip it at startup.
- Updated the player attack flow to use weapon-driven energy cost, attack cooldown, and a short configurable windup while preserving the existing rule that attacking air does not consume energy.

Validation:
- Headless Godot project load succeeded after the kitchen-knife weapon refactor.

### Configurable Weapon And Enemy Attack Visuals
- Added weapon-configurable attack-indicator styling so different player weapons can tune their projected hit area color, windup scale, strike burst, and fade timing through `WeaponDefinition`.
- Added enemy-configurable attack-tell styling so different enemy types can tune their prep color, prep growth, prep alpha, strike burst, and strike duration through `EnemyDefinition`.
- Tuned the current kitchen knife, basic zombie, and brute resources explicitly so their attack presentations now differ by data instead of sharing one hardcoded visual profile.

Validation:
- Headless Godot project load succeeded after the configurable weapon-and-enemy attack-visual pass.

### Weapon Windup And Fallback Hardening
- Preserved the no-effect attack rule for weapon windup by refunding the spent energy and skipping cooldown if the final strike resolves with no targets in range.
- Added a validated fallback to the default kitchen knife resource so a bad `equipped_weapon` assignment no longer silently disables player combat.
- Finished moving player strike-flash tuning into `WeaponDefinition`, including flash start scale and flash duration, so the remaining player attack presentation is data-driven too.

Validation:
- Headless Godot project load succeeded after the weapon windup and fallback hardening pass.

### Visible No-Hit Player Swings
- Changed player melee so attacks that miss still play the weapon windup and strike animation instead of failing silently.
- Kept the no-hit behavior non-committal: misses do not consume energy or apply cooldown, while real hits still follow the normal weapon-driven cost and cooldown rules.

Validation:
- Headless Godot project load succeeded after the visible no-hit swing update.

### Development Workflow Note
- Added `DEVELOPMENT_WORKFLOW.md` to document the repo rule that any significant code change should be followed by a picky code review pass.
- Linked the workflow doc from the README so the post-change review pattern stays visible during normal development.

### Weapon Runtime-Swap And Miss-Recovery Cleanup
- Made player weapon assignment runtime-aware so changing `equipped_weapon` now reapplies attack visuals and hitbox settings immediately instead of waiting for a reset path.
- Loosened weapon validation to accept resources that conform to the `WeaponDefinition` class contract instead of requiring one exact script file.
- Added a small weapon-configurable miss recovery so empty swings are still readable and free of energy cost, but no longer fully spam-free in pacing.

Validation:
- Headless Godot project load succeeded after the weapon runtime-swap and miss-recovery cleanup.

### Damage Reaction Animation Pass
- Added short directional damage reactions to the player and enemies using local nudge-plus-squash animation layered on top of the existing hit flash.
- Strengthened wall and door damage feedback with a visible impact pulse so structure hits read more clearly during defense.
- Kept all damage reactions visual-only so collision, navigation, and combat resolution still use the same underlying gameplay state.

Validation:
- Headless Godot project load succeeded after the damage reaction animation pass.

### Nearby Ally Aggro Propagation
- Added enemy-configurable local alert propagation so when one enemy detects the player, nearby enemies can be activated as well instead of staying dormant in place.
- Exposed `alert_nearby_enemies` and `ally_alert_radius` in `EnemyDefinition` so different enemy types can tune how strongly they wake nearby allies.
- Tuned the current basic zombie and brute with different ally-alert radii to keep the wake-up behavior local rather than map-wide.

Validation:
- Headless Godot project load succeeded after the nearby-ally aggro propagation pass.

### Review Workflow Clarification
- Updated the workflow doc so significant code changes now explicitly require an automatic same-session picky review pass, not just a manual reminder.
- Added a visible change checklist to the README and a commit checklist to the workflow doc so review and validation steps are easy to follow before commit or push.

### Differentiated Attack Prep Vs Strike Readability
- Split player weapon attack presentation into separate windup and strike indicator colors so the kitchen knife now reads as a softer prep telegraph followed by a brighter committed strike.
- Split enemy attack presentation into separate prep and strike styling by adding dedicated strike color and strike start-scale config to `EnemyDefinition`.
- Tuned the current basic zombie and brute so their prep tells remain readable, but their real hit now lands with a visibly sharper flash than the windup state.

Validation:
- Headless Godot project load succeeded after the prep-vs-strike readability pass.

### Longer Enemy Attack Windup Tuning
- Increased the basic zombie attack prep time from `0.3` to `0.45` so the enemy windup is easier to read before contact damage lands.
- Increased the brute attack prep time from `0.4` to `0.6` so its heavier attacks feel more deliberate and give the player a clearer reaction window.

Validation:
- Headless Godot project load succeeded after the enemy attack-windup tuning pass.

### Temporary One-Second Enemy Windup Test
- Set both the basic zombie and brute `attack_prep_time` to `1.0` second to make the distinction between attack prep and the actual strike state unmistakable during playtesting.
- Kept the rest of the attack visual pipeline unchanged so this test isolates timing rather than mixing in more presentation changes.

Validation:
- Headless Godot project load succeeded after the temporary one-second enemy windup test pass.

### Enemy Attack Tell Window Split
- Separated internal enemy attack prep from the visible tell so staying close to a target no longer keeps the attack animation on for the entire prep duration.
- Added `attack_tell_lead_time` to `EnemyDefinition` so enemies can spend longer charging an attack internally while only showing the visible warning during the final slice before the strike.
- Tuned the basic zombie and brute with short visible tell windows even while their prep time remains at `1.0` second for testing.

Validation:
- Headless Godot project load succeeded after the enemy attack tell-window split pass.

### Weapon Attack Tell Window Split
- Applied the same two-stage timing model to player weapons by separating total `attack_windup` from visible `attack_indicator_lead_time`.
- Changed the player windup indicator so it only appears during the final lead-time slice before the strike instead of staying on for the full weapon windup.
- Tuned the kitchen knife with a short `0.12` second visible tell window.

Validation:
- Headless Godot project load succeeded after the weapon attack tell-window split pass.

### Attack Feel Tuning Pass
- Retuned the kitchen knife for a faster, cleaner melee read: shorter visible tell, tighter strike burst, and faster strike fade so player attacks feel responsive without losing anticipation.
- Brought the basic zombie back from the `1.0s` test windup to a more playable medium telegraph with a short visible lead time and a sharper strike burst.
- Tuned the brute to stay heavier than the basic zombie, but with a shorter visible tell than the full internal prep so it feels deliberate instead of sluggish.

Validation:
- Headless Godot project load succeeded after the attack feel tuning pass.

### Enemy Attack State Machine Cleanup
- Fixed the enemy attack state so failed hits no longer leave the prep state armed at zero time, which could make the visible attack tell appear stuck on while the enemy stayed close to the player.
- Tightened attack prep so it only arms when the enemy has a valid attack solution: target in range, clear attack path, and correct facing.
- Changed successful attacks to enter cooldown before resetting the prep state so the real strike flash is not immediately suppressed by the prep reset path.

Validation:
- Headless Godot project load succeeded after the enemy attack state machine cleanup pass.

### Enemy Attack Prep Re-arming Adjustment
- Loosened enemy prep arming so attack windup can begin once a target is plausibly attackable in range, instead of requiring a fully valid strike solution before any tell can appear.
- Kept the stricter facing and clear-path checks for the actual hit resolution, so the attack tell is visible again without reintroducing the old always-on stuck prep state.

Validation:
- Headless Godot project load succeeded after the enemy attack prep re-arming adjustment.

### Restart Exploration Respawn Fix
- Fixed the run-reset ordering issue where exploration spawn defeat state was cleared after the `PRE_WAVE` resync had already run, leaving prep-stage enemies missing after pressing `R`.
- The reset handler now performs a fresh exploration-enemy sync after clearing defeated-spawn and spawn-count bookkeeping, so start-of-run POI enemies come back correctly on restart.

Validation:
- Headless Godot project load succeeded after the restart exploration respawn fix.

### Enemy Spawn Facing Initialization
- Fixed enemy spawn-time facing so enemies no longer all begin with the same default downward orientation.
- Wave enemies now initialize their facing toward their current wave target when configured, while exploration enemies randomize their starting facing if they do not yet have a live target.

Validation:
- Headless Godot project load succeeded after the enemy spawn facing initialization pass.

### Exploration Spawn Facing Hook
- Added optional authored initial facing to exploration spawn points so future patrol-like staging has a stable data hook instead of relying on pure random spawn orientation.
- Changed exploration-context configuration so newly spawned enemies can use authored facing when present, while surviving exploration enemies no longer get their facing randomly reset every prep-phase resync.

Validation:
- Headless Godot project load succeeded after the exploration spawn facing hook pass.

### Review Fixes For Restart Respawn And Enemy Prep Tells
- Fixed exploration-enemy restart resync to ignore nodes already queued for deletion, so pressing `R` no longer treats old prep enemies as still alive while rebuilding the new run state.
- Tightened enemy prep arming so attack tells now require attack-range plus valid facing, and only bypass the clear-path check for true player body contact.
- Kept real hit resolution stricter than prep, but removed the broad “nearby only” telegraph that could show attack tells for obviously invalid swings.

Validation:
- Headless Godot project load succeeded after the restart-respawn and enemy-prep review fixes.

### Review Workflow Hardening
- Strengthened the repo workflow so significant code changes now require runtime validation followed by an independent reviewer subagent when available, instead of relying on a same-context self-review by default.
- Expanded the documented review checklist to explicitly call out reset flow, spawn flow, timing/state-machine bugs, collision pressure, and config-driven validation as recurring risk areas for this project.
- Updated the README checklist so the stronger review expectation stays visible during normal development.

### Review Fixes For Restart Sync And Patrol Hooks
- Added a restart-only guard so actual `R`-triggered resets skip the earlier `PRE_WAVE` exploration sync and use the post-reset sync as the single authoritative rebuild path.
- Extended exploration enemy setup to preserve a stable spawn anchor position and authored facing alongside the existing spawn ID, creating a cleaner data hook for future patrol or return-to-post behavior.
- Added a minimal spawn-point anchor accessor so patrol-like systems can build from authored marker positions without another exploration-spawn refactor.

Validation:
- Headless Godot project load succeeded after the restart-sync and patrol-hook review fixes.

### Structure Attack Targeting Fix
- Fixed wave enemies using the center of large wall and door sockets for movement, facing, and attack-path checks, which could leave them in range but unable to satisfy the attack gates against structures.
- Added a structure-side attack aim point helper and switched zombie structure movement/facing/path logic to target the nearest reachable point on the socket face instead of the socket center.
- This keeps player-facing logic unchanged while making large perimeter segments attackable again by enemies standing near their edges.

Validation:
- Headless Godot project load succeeded after the structure attack targeting fix.

### Structure Target Selection Follow-Up
- Fixed a target-selection bug where wave enemies could override their wall or door target to the player whenever the player was merely inside the enemy damage radius, even if a structure was physically between them.
- Tightened the player-contact override to require literal body touch instead of damage-area overlap, so structure-focused enemies keep attacking walls and doors unless the player is actually in contact.
- Kept the earlier structure aim-point logic in place so large sockets still use nearest-face movement and attack checks.

Validation:
- Headless Godot project load succeeded after the structure target-selection follow-up.

### Root Cause Fix For Structure Attacks
- Investigated the wall-attack regression with a headless runtime probe and confirmed the real failure was not spawn or damage tuning: the enemy chase-state updater was resetting attack prep every physics frame whenever the player was not currently detectable.
- That continuously canceled two-stage structure attacks before they could finish windup, which is why walls and doors showed neither attack tell nor damage after the recent attack-state refactors.
- Fixed the chase-state logic so attack prep is only reset when an actual player-alert or player-chase state is being lost, not every frame while the enemy is structure-focused.

Validation:
- Headless Godot project load succeeded after the structure-attack root cause fix.
- A headless near-wall runtime probe confirmed a zombie next to `wall_n` now counts down prep and damages the wall from `120` to `117`.

### HUD Visual Upgrade
- Reworked the top-left HUD into a cleaner game-style status card with colored health and energy bars instead of a single plain-text vitals line.
- Tightened the information hierarchy so vitals, wave/phase, base integrity, resources, status text, and interaction prompt each have clearer visual separation and stronger color cues.
- Made the interaction callout hide itself when empty so the upgraded HUD does not carry an always-visible blank action panel.

Validation:
- Headless Godot project load succeeded after the HUD visual upgrade.

### Review Workflow Hardening Follow-Up
- Strengthened the documented picky-review rule so it now explicitly requires an adversarial reviewer stance instead of a soft confirmatory pass.
- Added a runtime-probe requirement for gameplay, AI, combat, collision, spawn, reset, and phase/state-machine changes when feasible.
- Updated the visible README checklist so the repo workflow now treats static review alone as insufficient for risky gameplay changes.

### HUD Footprint Refinement
- Split the HUD into a smaller top-left vitals card, a lighter secondary status panel, and a bottom-center interaction prompt instead of one large top-left block.
- Reduced persistent screen coverage by keeping only core always-on info in the main card and moving situational prompts out of that space.
- Fixed the review-found layout fragility by anchoring the interaction prompt to the bottom center instead of fixed screen pixels.

Validation:
- Headless Godot project load succeeded after the HUD footprint refinement.

### HUD Compactness And Readability Pass
- Replaced the compact HUD vitals/resource shorthand with lightweight emoji labels so the information density stays high without longer text labels consuming space.
- Collapsed health and energy into a single aligned vitals row so the main HUD card is shorter and reads more like a game overlay than a stacked debug panel.
- Tightened the vitals layout so icons, bars, and values share one straight line instead of appearing vertically staggered.

Validation:
- Headless Godot project load succeeded after the HUD compactness and readability pass.
