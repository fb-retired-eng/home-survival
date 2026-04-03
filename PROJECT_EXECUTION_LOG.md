# Project Execution Log

This file is the running execution log for `Home Survival`.

## Log Rules
- Append-only unless a previous entry is factually wrong
- Use absolute dates
- Record what changed, why it changed, and how it was validated
- Keep entries short and operational

## 2026-03-31

### Construction Stage 0/1 Foundation
- Added [`CONSTRUCTION_SYSTEM_PLAN.md`](CONSTRUCTION_SYSTEM_PLAN.md) to define the staged controlled free-grid construction roadmap, including authored-grid constraints, shared-bullet turret philosophy, and the later auto machine gun path.
- Added generic construction scaffolding:
  - [`scripts/world/construction_grid.gd`](scripts/world/construction_grid.gd)
  - [`scenes/world/ConstructionGrid.tscn`](scenes/world/ConstructionGrid.tscn)
  - [`scripts/data/placeable_profile.gd`](scripts/data/placeable_profile.gd)
  - [`scripts/world/placeable.gd`](scripts/world/placeable.gd)
  - [`scenes/world/Placeable.tscn`](scenes/world/Placeable.tscn)
- Added an authored construction grid to [`scenes/main/Game.tscn`](scenes/main/Game.tscn) around the base with buildable and reserved cells.
- Added `B` build-mode toggle plumbing through the real player/game path so the preview can be entered during the day and is disabled outside the day state.
- Added [`scripts/debug/construction_grid_probe.gd`](scripts/debug/construction_grid_probe.gd) to validate build-mode activation and reserved-vs-valid preview behavior.

Validation:
- Headless load passed.
- `construction_grid_probe` passed:
  - `active=true`
  - `preview_visible=true`
  - `reserved_reason=Reserved`
  - `valid_reason=` (empty, valid)
  - `valid_cell=(1, 0)`
  - `inactive=true`

## 2026-04-01

### Map Expansion Pass
- Expanded the authored playfield from `2560x1440` to `5120x2880` by widening the world bounds symmetrically around the existing base layout.
- Kept the home, POIs, and spawn markers in their current authored positions while extending the collision walls to match the larger map footprint.
- Left the construction system as a local buildable band around the home, with the four home corners reserved and the rest of the far map still non-buildable.

Validation:
- Headless Godot project load succeeded after the map-expansion pass.
- `map_layout_probe` confirmed the player, sleep point, POIs, and spawn markers still line up in the enlarged world.
- `construction_grid_probe` confirmed:
  - `construction_grid_probe_map_in_bounds=true`
  - `construction_grid_probe_far_blocked_tactical=false`
  - `construction_grid_probe_home_corner_reserved=true`
  - `construction_grid_probe_home_corner_valid=false`
  - `construction_grid_probe_active_stage_build_mode=true`
  - `construction_grid_probe_post_stage_build_mode=true`

### Map Layout Optimization
- Spread the authored exploration POIs and their guard / roaming spawn anchors outward into the larger map so the added world space carries actual traversal and encounter value instead of only dead margins.
- Kept the wave spawn markers and the home/base layout stable so defense pacing and the core loop remain unchanged.
- Extended the map layout probe to print the full POI and roaming-anchor layout for easier future review.

Validation:
- Headless Godot project load succeeded after the layout optimization pass.
- `map_layout_probe` confirmed the new exploration spread:
  - `map_layout_probe_poi_a=(205.0, 220.0)`
  - `map_layout_probe_poi_b=(2355.0, 220.0)`
  - `map_layout_probe_poi_c=(205.0, 1220.0)`
  - `map_layout_probe_poi_d=(2355.0, 1220.0)`
  - `map_layout_probe_poi_e=(1280.0, 95.0)`
  - `map_layout_probe_poi_f=(1280.0, 1345.0)`
  - `map_layout_probe_roam_nw=(580.0, 95.0)`
  - `map_layout_probe_roam_se=(1980.0, 1345.0)`
- `construction_grid_probe` still confirmed the local build band and reserved home corners remained intact.

### MVP1 Fog Pass
- Added a home-anchored fog-of-war overlay so the enlarged map starts to fade once the player moves beyond the local home area.
- Wired the fog overlay through the HUD with explicit shader parameters for the home anchor, camera position, viewport size, fade distances, and a reveal texture.
- Added exploration-memory support so areas the player has already visited remain revealed for the rest of the run.
- Corrected the fog center update to use the camera's rendered screen center, which keeps the overlay from drifting as the player moves with camera smoothing enabled.
- Added a headless fog probe to verify the overlay exists, that distant map positions receive more fog than the home area, and that visited areas clear once explored.

Validation:
- Headless Godot project load succeeded after the fog pass.
- `map_fog_probe` confirmed:
  - `map_fog_probe_home_alpha=0.000`
  - `map_fog_probe_far_alpha_before_visit=0.636`
  - `map_fog_probe_far_alpha_after_visit=0.000`
  - `map_fog_probe_overlay_visible=true`
  - `map_fog_probe_home_center=(1280.0, 720.0)`
  - `map_fog_probe_camera_screen_center=(1464.159, 634.3447)`

### MVP0.5 Bridge Spec
- Added `MVP0_5_SPEC.md` as the bridge milestone between MVP0 and MVP1.
- Defined MVP0.5 as the menu, settings, save/load, and persistence layer needed to make the current prototype feel shippable without adding new combat or progression systems.
- Split persistence into separate settings and run saves, with explicit support for construction and fog-memory restoration.

### MVP0.5 Settings Shell
- Added a boot scene and menu shell that starts the project in a main menu instead of jumping directly into the run scene.
- Added persistent settings for master volume and fullscreen using a dedicated user-data settings file.
- Added a headless settings probe that verifies the settings file round-trips and that the boot scene constructs the menu and settings panel.

Validation:
- `settings_manager_probe` confirmed:
  - `settings_manager_probe_file_exists=true`
  - `settings_manager_probe_master_volume=0.37`
  - `settings_manager_probe_fullscreen=true`
  - `settings_manager_probe_boot_start_button=true`
  - `settings_manager_probe_boot_settings_button=true`
  - `settings_manager_probe_boot_settings_panel=true`

### MVP0.5 Run Save/Load Slice
- Added a slot-based run save manager plus Boot wiring for New Game, Continue, and Load Game.
- Persisted player state, defense sockets, scavenge nodes, placed construction, fog memory, and run metadata through a versioned JSON save payload.
- Added autosave hooks at safe points so construction and phase transitions can refresh the active slot without mid-wave serialization.
- Added a round-trip save probe that writes to a real slot, reloads it into a fresh game instance, and checks the boot menu can see the save summary.

### MVP0.5 Pause Menu Slice
- Added an in-game pause overlay with resume, save, and save-and-quit actions.
- Wired Escape to toggle pause while keeping the HUD responsive during paused state.
- Connected save-and-quit to the boot menu return flow so the current run can be persisted and dropped back to the menu cleanly.
- Added a pause-menu probe that verifies save, resume, and quit-to-menu behavior end to end.
- Tightened the pause save path so manual saves are blocked during active waves instead of bypassing the autosave safety rule.
- Removed slot rewrites on `Continue` / `Load Game` entry and scoped run serialization to the active `Game` scene so multiple live game instances cannot contaminate one another's save payloads.

Validation:
- `save_system_probe` confirmed:
  - `save_probe_slot_occupied=true`
  - `save_probe_summary_text=Slot 3 | Day 3 | Wave 2 | Post-Wave | 2026-04-02T06:58:14`
  - `save_probe_player_health=83`
  - `save_probe_player_build_mode=true`
  - `save_probe_placeable_id=spike_trap`
  - `save_probe_placeable_rotation=1`
  - `save_probe_socket_hp=117`
  - `save_probe_node_depleted=true`
  - `save_probe_daily_modifier=elite_present`
  - `save_probe_continue_did_not_rewrite=true`
  - `save_probe_boot_continue_disabled=false`
- `pause_menu_probe` confirmed:
  - `pause_probe_paused=true`
  - `pause_probe_menu_visible=true`
  - `pause_probe_saved_health=87`
  - `pause_probe_saved_slot_summary=Slot 2 | Day 1 | Wave 0 | Day | 2026-04-02T07:01:58`
  - `pause_probe_resumed=true`
  - `pause_probe_menu_hidden=true`
  - `pause_probe_active_wave_blocked=true`
  - `pause_probe_active_wave_status=Saving is blocked during active waves.`
  - `pause_probe_back_to_menu=true`
  - `pause_probe_game_host_children=0`

### Expanded Grid Playtest
- Added a dedicated probe for the outer-ring tactical build cells so the widened grid is exercised through the real barricade placement flow, not just validity checks.
- Confirmed the new expanded cell at `(-2, 3)` accepts barricade placement, spends salvage, and occupies the expected cell.

Validation:
- `construction_expanded_grid_probe` passed:
  - `construction_expanded_probe_build_mode=true`
  - `construction_expanded_probe_placeables=1`
  - `construction_expanded_probe_cell_occupied=true`

### Godot-Native UI Refactor
- Replaced the procedurally constructed Boot menu with an authored `Boot.tscn` scene and onready node bindings in `boot.gd`.
- Replaced the procedurally constructed HUD pause overlay with authored nodes in `HUD.tscn` and simplified `hud.gd` back to controller logic.
- Kept the existing probe paths and behavior stable so the refactor stayed architectural instead of user-facing.

Validation:
- `settings_manager_probe` still passed against the authored Boot scene.
- `save_system_probe` still passed against the authored Boot scene and slot flow.
- `pause_menu_probe` still passed against the authored HUD pause overlay.

### Godot-Native Controller Extraction
- Added a scene-owned `ConstructionController` under `Game` to own build selection, placement, occupancy refresh, and placeable save/load.
- Added a scene-owned `FogController` under `Game` to own fog-of-war memory, shader updates, and fog save/load.
- Reduced `game.gd` back toward orchestration by delegating construction and fog responsibilities to those child nodes instead of keeping them in one large script.
- Fixed a controller regression where recycled placeables were not clearing grid occupancy until a later refresh.
- Fixed the authored Boot scene so the full-screen menu backdrop is hidden while the game is running instead of darkening gameplay underneath.
- Corrected fullscreen settings to apply through Godot's active window mode API rather than relying only on a lower-level display call.

Validation:
- `settings_manager_probe` still passed after the extraction.
- `save_system_probe` still passed, including `save_probe_continue_did_not_rewrite=true`.
- `pause_menu_probe` still passed, including active-wave save blocking.
- `construction_grid_probe` still passed.
- `map_fog_probe` still passed, including matched camera center / screen center.
- `barricade_placement_probe` confirmed `barricade_probe_cell_occupied_after_recycle=false`.
  - `construction_expanded_probe_salvage_before=72`
  - `construction_expanded_probe_salvage_after=62`
  - `construction_expanded_probe_placeable_id=barricade`
  - `construction_expanded_probe_placeable_hp=90`

### Construction Tuning Pass
- Tuned barricade economy so the larger build grid does not collapse into cheap wall spam.
- Expanded the tactical build ring and then tightened it with corner reservations to remove dead placement cells.
- Improved construction preview feedback so outside-grid, non-buildable, reserved, and occupied cells report different reasons.

Validation:
- `barricade_placement_probe` passed with updated build and repair costs:
  - `barricade_probe_salvage_before=72`
  - `barricade_probe_salvage_after=62`
  - `barricade_probe_salvage_after_repair=58`
  - `barricade_probe_salvage_after_dismantle=63`
- `construction_grid_probe` passed with the new feedback states:
  - `construction_grid_probe_map_blocked_reason=Not buildable`
  - `construction_grid_probe_offgrid_reason=Outside grid`
  - `construction_grid_probe_non_buildable_reason=Not buildable`
  - `construction_grid_probe_corner_reason=Reserved`
  - `construction_grid_probe_corner_valid=false`

### MVP1 Spec Draft
- Added [`MVP1_SPEC.md`](MVP1_SPEC.md) to define the next expansion layer after MVP0, covering power-limited automation, the Dog companion, and heirloom persistence.
- Refined the MVP1 wording so the spec stays aligned with the current MVP0 grid/construction language and does not imply freeform walls or a zombie-derived companion.
- Linked the new spec from [`README.md`](README.md) so the project docs point to both the MVP0 source of truth and the next expansion target.

Validation:
- Docs reviewed for terminology drift and implementation-scope consistency.

## 2026-04-02

### POI Data-Driven Role Pass
- Added `PoiDefinition` resources for the six live POIs and moved display names, bonus-table ownership, elite eligibility, and daily-elite resolution into POI data.
- Replaced name-derived POI lookup with explicit `poi_id` wiring for exploration guard markers and POI-linked scene content.
- Made `reward_role` live data instead of descriptive-only:
  - POI labels now expose role text through tooltips and debug helpers.
  - POI-tied micro-loot markers can resolve their resource and amount from the POI role instead of hardcoded scene values.
  - POI definition caching now warns if a POI bonus table drifts away from the declared reward role.

Validation:
- `map_layout_probe` confirmed stable POI labels plus role output:
  - `map_layout_probe_poi_a_role=Salvage / Parts`
  - `map_layout_probe_poi_d_role=Ammo`
- `micro_loot_probe` confirmed role-driven support loot:
  - `micro_loot_probe_tool_yard_resource=salvage`
  - `micro_loot_probe_tool_yard_amount=2`
- `daily_poi_modifier_probe` still passed through disturbed and elite cases.

### App-Service Access Cleanup
- Stopped `Boot` from creating settings/save managers at runtime and treated `SettingsStore` / `SaveStore` as required autoload-owned app services.
- Added `AppServices` as the shared lookup path so Boot and Game stop scattering raw `/root/...` access.
- Tightened the save/settings probes to verify the autoload-backed path instead of silently constructing replacement services.

Validation:
- `settings_manager_probe` confirmed `settings_manager_probe_boot_settings_autoload=true`.
- `save_system_probe` still passed with `save_probe_continue_did_not_rewrite=true`.
- `pause_menu_probe` still passed with active-wave save blocking intact.

### Headless Probe Audio Cleanup
- Adjusted `CombatAudio2D` so headless probes record sound ids without instantiating or playing real 2D audio streams.
- Added cache clearing to the generated combat SFX library and improved probe teardown so temporary test scenes are freed before exit.
- Removed the repeatable headless `AudioStreamWAV` / `AudioStreamPlaybackWAV` leak warning from focused non-combat probes like micro-loot and save/load.

Validation:
- `micro_loot_probe` no longer emitted the prior combat-audio leak at shutdown in verbose headless runs.
- `save_system_probe` and `combat_audio_probe` still preserved probe-visible sound ids and save/load assertions.

### Construction Stage 2 Barricade Slice
- Added the first tactical placeable barricade through the shared construction grid, including placement, salvage spending, repair, dismantle, and occupancy refresh.
- Tightened the placement guard so barricades cannot trap the player in or permanently seal the base routes, while still allowing valid door-side placement.
- Updated the construction plan, README, and spec so construction is documented as an active tactical layer instead of only a future scaffold.

Validation:
- Headless load passed.
- `barricade_placement_probe` passed:
  - `barricade_probe_placeables=1`
  - `barricade_probe_cell_occupied=true`
  - `barricade_probe_salvage_before=72`

## 2026-04-03

### POI Guard And Wave Pressure Tuning
- Tuned the authored POI guard markers so the six POIs now read as clearer risk bands:
  - `Tool Yard`: `zombie_basic` `1-2`
  - `Freight Depot`: `zombie_runner` `2-3`
  - `Greenhouse`: `zombie_basic` `1-1`
  - `Checkpoint`: `zombie_spitter` `1-2`
  - `Truck Stop`: `zombie_basic` `2-2`
  - `Scrapyard`: `zombie_brute` `1-2`
- Softened the authored wave curve in `mvp0_waves.tres` by reducing several early/mid counts and easing spawn intervals from wave 1 through wave 8, so the scavenging/construction economy has more room to matter.
- Trimmed `Checkpoint`'s parts overflow and reduced `Truck Stop` food output so those POIs keep distinct roles instead of crowding each other.

Validation:
- `map_layout_probe` confirmed the new guard profiles:
  - `map_layout_probe_guard_a=zombie_basic:1-2`
  - `map_layout_probe_guard_b=zombie_runner:2-3`
  - `map_layout_probe_guard_d=zombie_spitter:1-2`
  - `map_layout_probe_guard_f=zombie_brute:1-2`
- `daily_poi_modifier_probe` still passed, including disturbed-count deltas and elite rolls.
- `save_system_probe` still passed with `save_probe_continue_did_not_rewrite=true`.

### Construction Economy Tuning
- Reduced barricade build/repair costs to keep lane control viable against the softened but still threatening eight-wave curve.
- Reduced spike trap build friction by lowering its salvage/parts cost, slightly lowering HP, and raising contact damage so it remains a tactical spend instead of a dead luxury item.

Validation:
- `barricade_placement_probe` confirmed:
  - `barricade_probe_salvage_after=63`
  - `barricade_probe_salvage_after_repair=60`
  - `barricade_probe_salvage_after_recycle=69`
- `spike_trap_probe` confirmed:
  - `spike_trap_probe_health_before=50`
  - `spike_trap_probe_health_after=38`
  - `spike_trap_probe_player_health_after=100`

### Economy Balance Probe
- Added `economy_balance_probe.gd` to report:
  - per-POI base resource totals
  - guard composition per POI
  - POI role-driven support-loot defaults
  - barricade and spike-trap build/repair economics
  - wave 3 / 5 / 7 pressure totals and enemy mix
- This probe is now the main numeric check for future MVP0 economy tuning instead of relying only on ad hoc play feel.

Validation:
- `economy_balance_probe` reported:
  - `economy_probe_poi_a_base_rewards=salvage:9,parts:3`
  - `economy_probe_poi_d_base_rewards=salvage:1,parts:4,medicine:1,bullets:16`
  - `economy_probe_poi_e_base_rewards=salvage:4,parts:1,medicine:1,food:6`
  - `economy_probe_barricade_build=salvage:9`
  - `economy_probe_spike_build=salvage:10,parts:1`
  - `economy_probe_wave_7_breakdown=zombie_brute:2,zombie_runner:3,zombie_spitter:1`
  - `barricade_probe_salvage_after=64`
  - `barricade_probe_placeable_id=barricade`
  - `barricade_probe_damaged_hp=78`
  - `barricade_probe_repaired_hp=90`
  - `barricade_probe_placeables_after_dismantle=0`
  - `barricade_probe_cell_occupied_after_dismantle=false`
- `barricade_attack_probe` passed:
  - `barricade_attack_probe_placed=true`
  - `barricade_attack_probe_barricade_hp=83`
  - `barricade_attack_probe_zombie_target=barricade`
- `construction_escape_probe` passed:
  - `construction_escape_probe_west_only=false`
  - `construction_escape_probe_east_only=false`
  - `construction_escape_probe_both=true`

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

### Baseball Bat Weapon Upgrade
- Added a second melee weapon, `Baseball Bat`, as a data-defined weapon resource with heavier impact damage, longer reach, longer windup, and slower recovery than the starting kitchen knife.
- Extended scavenge nodes so a POI search can grant a weapon reward and immediately equip it, then authored `poi_b_4` to award the baseball bat as a standout parts-heavy loot find.
- Hardened player weapon flow so run resets restore the starting kitchen knife instead of carrying the upgraded weapon across runs.
- Added data-driven weapon knockback and enemy knockback resistance so the baseball bat can launch regular enemies, only slightly move brutes, and support future bosses with full knockback immunity via config.
- Fixed the first knockback integration pass so knocked-back enemies no longer keep attacking during the shove, enemy hits now use the same knockback metadata path on the player side, and zero-damage armored hits can still apply a partial shove when the config allows it.
- Added a per-run obtained-weapon list so the player can switch between unlocked weapons after finding them, with `X` cycling the current loadout and run reset restoring the starting knife-only inventory.
- Hardened the documented picky-review rule so zero-finding reviews now require explicit negative checks or runtime-probe results instead of a generic `no issue found`.

Validation:
- Headless Godot project load succeeded after the baseball bat weapon integration.
- Headless runtime probe confirmed the player starts with `kitchen_knife`, switches to `baseball_bat` after searching `poi_b_4`, and resets back to `kitchen_knife` on run restart.
- Headless runtime probe confirmed the same knockback hit moved a regular zombie by about `51.75px` while only moving a brute by about `6.18px`, matching the intended regular-versus-elite split.
- Headless runtime probe confirmed a knocked-back enemy did not damage `wall_n` during the shove window (`117 -> 117`), enemy attacks now physically moved the player by about `3.46px`, and a brute still moved by about `8.23px` on a zero-damage bat-style hit.
- Headless runtime probe confirmed the player can obtain the baseball bat, cycle `kitchen_knife -> baseball_bat -> kitchen_knife`, and that run reset restores knife-only inventory.
- Headless runtime probe confirmed weapon switching is blocked during active cooldown, still works once cooldown clears, and invalid weapon resources now fail closed instead of silently collapsing to the kitchen knife.

### Weapon POI And Held-Weapon Visual Pass
- Gave the baseball-bat POI a distinct visual identity so the weapon location reads differently from the normal scavenging POIs.
- Added simple data-driven held-weapon visuals to the player, with weapon-specific polygon, offset, and color fields authored in weapon config instead of hardcoded in player logic.
- Tuned both starting weapons so the kitchen knife and baseball bat read differently in the player hand, then corrected their local facing so the visible weapon points in the attack direction.
- Added a reusable headless runtime probe for weapon visuals to confirm the held-weapon illustration updates when the equipped weapon changes.

Validation:
- Headless Godot project load succeeded after the weapon-POI and held-weapon visual pass.
- Headless runtime probe confirmed the player-held weapon visual changes at runtime from knife to bat, including distinct color and offset values.

### Docs Sync And Equipped-Weapon HUD Pass
- Brought the README and MVP0 spec back in line with the live game: opening POIs can already be hostile, the current run target is five waves, the player can switch obtained weapons, sleep restores a small amount of HP, and `poi_b_4` is now a baseball-bat reward node.
- Added an always-visible equipped-weapon readout to the HUD so weapon switching is no longer only message-driven.
- Added a small headless HUD probe to verify the HUD weapon label updates at runtime when the player equips the baseball bat.

Validation:
- Headless Godot project load succeeded after the docs-sync and equipped-weapon HUD pass.
- Headless runtime probe confirmed the HUD weapon label changes from `Weapon: Kitchen Knife` to `Weapon: Baseball Bat` when the bat is obtained and equipped.

### Pistol Weapon Pass
- Extended weapon config with a lightweight `attack_mode` split so the current system can support both melee and hitscan weapons without a larger projectile refactor.
- Added a new `Pistol` weapon resource with faster low-windup ranged attacks, modest per-shot energy cost, lighter knockback than the bat, and a compact held-weapon silhouette.
- Hooked the pistol into `poi_d_4` as a second weapon reward node and gave `POI_D` a distinct cooler color treatment so it reads differently from the bat POI.
- Switched player attack target collection from `Area2D.get_overlapping_bodies()` to a direct physics shape query, then layered pistol hitscan selection on top of that so ranged attacks use forward-target filtering plus an unobstructed ray to the enemy.

Validation:
- Headless Godot project load succeeded after the pistol pass.
- Headless pistol probe confirmed the pistol equips successfully, acquires a ranged target, and reduces a zombie from `50` HP to `16` HP at distance.

### Firearm Rules, Impact Feedback, And Weapon Balance Pass
- Extended `WeaponDefinition` with magazine/reload settings plus dedicated hitscan impact-feedback settings so firearm behavior and shot feel remain data-driven.
- Updated the player combat loop so magazine weapons fire committed shots, auto-reload when emptied, expose reload state in the HUD weapon label, and let weapon switching cancel an in-progress reload.
- Added a shot-impact flash at the tracer endpoint and tuned the pistol to show distinct enemy-hit and structure/world impact colors.
- Rebalanced the current weapon trio around clearer roles: faster knife, heavier slower bat with stronger knockback, and pistol as safe ranged pressure gated by a 6-round magazine and reload downtime.
- Added headless runtime probes for pistol reload, impact feedback, and reload-cancel-by-switch behavior.

Validation:
- Headless Godot project load succeeded after the firearm-rules and balance pass.
- Headless pistol probe confirmed the retuned pistol still acquires a ranged target and reduces a zombie from `50` HP to `24` HP at distance.
- Headless pistol reload probe confirmed:
  - `pistol_reload_probe_initial_status=Weapon: Pistol 1/6`
  - `pistol_reload_probe_after_shot_status=Weapon: Pistol 0/6 ↻`
  - `pistol_reload_probe_after_reload_complete=Weapon: Pistol 6/6`
- Headless pistol impact probe confirmed:
  - `pistol_impact_probe_enemy_visible=true`
  - `pistol_impact_probe_enemy_color=(1.0, 0.72, 0.42, 0.96)`
  - `pistol_impact_probe_structure_visible=true`
  - `pistol_impact_probe_structure_color=(0.96, 0.94, 0.88, 0.86)`
- Headless pistol reload-switch probe confirmed:
  - `pistol_reload_switch_probe_during_reload=Weapon: Pistol 0/6 ↻`
  - `pistol_reload_switch_probe_after_switch=Weapon: Baseball Bat`

### Test-Mode Weapon Loadout Pass
- Added a game-level `enable_test_mode` toggle plus authored `test_mode_weapons` so the player can start runs with the full weapon set unlocked for faster weapon testing.
- Applied the test-mode loadout both on initial scene startup and on full run reset so restart keeps the same debug loadout instead of dropping back to knife-only.
- Added a headless test-mode probe to verify the startup and reset loadouts.

Validation:
- Headless Godot project load succeeded after the test-mode pass.
- Headless test-mode probe confirmed:
  - `test_mode_probe_initial_weapon=Pistol`
  - `test_mode_probe_initial_loadout=kitchen_knife,baseball_bat,pistol`
  - `test_mode_probe_after_reset_weapon=Pistol`
  - `test_mode_probe_after_reset_loadout=kitchen_knife,baseball_bat,pistol`

### Pistol Energy Cost Tuning
- Restored a nonzero energy cost to the pistol so ranged pressure still participates in the player energy economy instead of bypassing it entirely.
- Kept the cost modest because the pistol already pays for safety with a 6-round magazine and reload downtime.

Validation:
- Headless pistol energy probe confirmed:
  - `pistol_energy_probe_before=100`
  - `pistol_energy_probe_after=99`
  - `pistol_energy_probe_cost=1`

### Weapon Data Rebalance Pass
- Retuned the current three-weapon set around cleaner roles instead of near-overlapping stats.
- `Kitchen Knife` is now slightly lighter and faster, so it stays the best close-range baseline and cleanup option.
- `Baseball Bat` is now slower, heavier, longer, and stronger on knockback so it reads as the deliberate crowd-control weapon.
- `Pistol` is now slightly less bursty and slightly shorter-ranged, with a bit more reload commitment, so it keeps its safety niche without dominating melee pickups.

### Bullet Resource And Pistol Ammo Pass
- Added `bullets` as a normal collectible run resource and surfaced it in the HUD resource strip.
- Updated pistol reload to consume bullet reserve ammo instead of assuming infinite reserve, and block empty-mag attacks when both magazine and reserve are empty.
- Extended scavenge nodes with `reward_bullets` and authored `POI_D` to grant bullet pickups alongside the pistol path.
- Added test and runtime probes for bullet-fed reload and empty-ammo behavior.

Validation:
- Headless Godot project load succeeded after the bullet-ammo pass.
- Headless reload-from-reserve probe confirmed:
  - `pistol_reload_probe_initial_status=Weapon: Pistol 1/6 | ◉5`
  - `pistol_reload_probe_after_shot_status=Weapon: Pistol 0/6 | ◉5 ↻`
  - `pistol_reload_probe_after_reload_complete=Weapon: Pistol 5/6 | ◉0`
- Headless empty-ammo probe confirmed:
  - `pistol_no_bullets_probe_status=Weapon: Pistol 0/6 | ◉0`
  - `pistol_no_bullets_probe_energy_before=100`
  - `pistol_no_bullets_probe_energy_after=100`
  - `pistol_no_bullets_probe_tracer_visible=false`

### Shotgun Weapon Pass
- Added a new `Shotgun` weapon as a spread-hitscan firearm with short range, wider cone coverage, heavier knockback than the pistol, and a small 2-shot magazine.
- Hooked the shotgun into `poi_d_1` so `POI_D` now serves as the firearm-cache POI, with bullet pickups supporting both the shotgun and pistol path.
- Extended test mode to include the shotgun in the authored startup loadout.
- Tuned the shotgun spread after the first runtime pass so it actually demonstrates multi-target value instead of behaving like a narrower pistol.

Validation:
- Headless shotgun probe confirmed:
  - `shotgun_probe_target_count=2`
  - `shotgun_probe_health_b_after=14`
  - `shotgun_probe_health_c_after=14`
  - `shotgun_probe_status=Weapon: Shotgun 1/2 | ◉4`
- Headless test-mode probe confirmed:
  - `test_mode_probe_initial_weapon=Shotgun`
  - `test_mode_probe_initial_loadout=kitchen_knife,baseball_bat,pistol,shotgun`
  - `test_mode_probe_after_reset_weapon=Shotgun`
  - `test_mode_probe_after_reset_loadout=kitchen_knife,baseball_bat,pistol,shotgun`

### Map Expansion Pass
- Expanded the authored playfield from `1920x1080` to `2560x1440`.
- Recentered the base, player spawn, perimeter resource, sleep point, wave lanes, map bounds, spawn markers, and all four POIs around the larger world footprint.
- Pushed exploration guards outward with the POIs so the larger map creates more traversal space instead of only adding empty margins.
- Added a headless layout probe to verify the recentered base and pushed-out POI/spawn coordinates.

Validation:
- Headless Godot project load succeeded after the map-expansion pass.
- Headless map layout probe confirmed:
  - `map_layout_probe_player=(1280.0, 720.0)`
  - `map_layout_probe_sleep=(1280.0, 720.0)`
  - `map_layout_probe_poi_a=(420.0, 320.0)`
  - `map_layout_probe_poi_d=(2140.0, 1120.0)`
  - `map_layout_probe_north_spawn=(1280.0, 110.0)`
  - `map_layout_probe_east_spawn=(2470.0, 720.0)`

### Expansion Systems Pass
- Added `food` as a first-class resource in the player inventory, HUD, scavenging rewards, bonus tables, and pickups.
- Added a new `FoodTablePoint` interaction and split the old sleep flow into:
  - table = consume exact food needed to refill energy to full
  - bed = restore some HP and start the next wave
- Tightened the bed gate so waves cannot start until the player has restored energy to full through the table flow.
- Extended structure profiles and sockets with a new `fortified` tier for both walls and doors, including stronger HP, stronger economy costs, and distinct visuals.

Validation:
- Headless Godot project load succeeded after the food/table/fortified pass.
- Headless food-table probe confirmed:
  - `food_table_probe_before_energy=55`
  - `food_table_probe_before_food=3`
  - `food_table_probe_after_energy=100`
  - `food_table_probe_after_food=0`
- Headless bed-gate probe confirmed:
  - `bed_gate_probe_can_sleep_before=false`
  - `bed_gate_probe_can_sleep_after=true`
- Headless fortified-socket probe confirmed:
  - `fortified_socket_probe_initial_tier=damaged`
  - `fortified_socket_probe_after_strengthen_tier=reinforced`
  - `fortified_socket_probe_after_fortify_tier=fortified`

### Expansion Content Pass
- Expanded authored content from `4` to `6` POIs by adding `POI_E` and `POI_F`, with `POI_E` biased toward food-heavy prep recovery and `POI_F` biased toward higher-risk combat rewards.
- Expanded authored wave content from `5` to `8` waves and introduced `zombie_runner` and `zombie_spitter` into the live wave data.
- Added POI-biased roaming exploration spawn zones that reroll each `PRE_WAVE` phase and stay outside a safe radius around the base.
- Added elite weapon-drop support through enemy data and weapon-drop pickups with a distinct gold visual treatment.
- Split the elite drop path out from the base spitter definition into a separate `zombie_elite_spitter` resource so not every spitter became a weapon-drop enemy.

Validation:
- Headless Godot project load succeeded after the expansion content pass.
- Headless roaming-spawn probe confirmed:
  - `roaming_spawn_probe_final_wave=8`
  - `roaming_spawn_probe_initial_roaming=2`
  - `roaming_spawn_probe_mid_roaming=4`
  - `roaming_spawn_probe_late_roaming=5`

### Expansion Fix Pass
- Added a separate `structure_attack_range_override` so ranged player-pressure enemies like spitters do not automatically inherit ranged siege behavior against walls and doors.
- Fixed restart-state HUD drift so resetting from `WIN` or `LOSS` explicitly restores the `Pre-Wave` phase label.
- Hardened elite weapon-drop enforcement so non-elite definitions cannot silently become weapon-dropping enemies by data accident.
- Added north/south roaming spawn zones so prep-stage roaming pressure now covers the new top/bottom POIs instead of only the original corner routes.
- Added fortified-tier damage mitigation on top of fortified HP so the top structure tier is not just a larger health pool.

Validation:
- Headless Godot project load succeeded after the fix pass.
- Headless reset-phase probe confirmed:
  - `reset_phase_probe_wave_label=Wave 0 / 8   |   Pre-Wave`
- Headless elite weapon-drop probe confirmed:
  - `elite_weapon_drop_probe_weapon_pickups=0`
- Headless roaming-zone probe confirmed:
  - `roaming_zone_probe_count=6`
  - `roaming_zone_probe_ids=roam_nw,roam_ne,roam_n,roam_sw,roam_se,roam_s`
- Headless spitter structure-range probe confirmed:
  - `spitter_structure_range_probe_far=false`
  - `spitter_structure_range_probe_near=true`
- Headless fortified-mitigation probe confirmed:
  - `fortified_mitigation_probe_damaged=16`
  - `fortified_mitigation_probe_reinforced=14`
  - `fortified_mitigation_probe_fortified=12`

### Docs Sync Pass
- Updated `README.md` so the shipped expansion summary matches the live repo more accurately:
  - five live enemy definitions instead of four
  - explicit note about the elite spitter variant
  - explicit note about the reviewed guardrails around elite drops, spitter siege range, and reset-state UI
- Updated `MVP0_SPEC.md` so the authored enemy list explicitly includes the current elite spitter variant.

### Day Night Loop Pass
- Reworked the daily routine so the run now flows:
  - day = exploration and construction
  - dinner at the table = exact food-to-full-energy conversion plus night-wave start
  - cleared night wave = bed sleep
  - bed sleep = next day plus partial HP restore
- Added a `POST_WAVE` state so sleeping happens after the night wave instead of before it.

Validation:
- Headless Godot project load succeeded after the day/night loop pass.
- Headless food-table probe confirmed:
  - `food_table_probe_before_energy=55`
  - `food_table_probe_before_food=3`
  - `food_table_probe_after_energy=100`
  - `food_table_probe_after_food=0`
  - `food_table_probe_after_wave=1`
  - `food_table_probe_after_state=1`
- Headless bed-gate probe confirmed:
  - `bed_gate_probe_can_sleep_before=false`
  - `bed_gate_probe_can_sleep_after=true`
  - `bed_gate_probe_after_sleep_state=0`
- Headless day-night cycle probe confirmed:
  - `day_night_cycle_probe_day_state=0`
  - `day_night_cycle_probe_after_dinner_state=1`
  - `day_night_cycle_probe_after_wave_state=2`
  - `day_night_cycle_probe_after_sleep_state=0`

### Day Entry Follow-Up Fix
- Fixed the new day-entry path so startup and post-sleep `PRE_WAVE` both run the real day setup again:
  - exploration enemies sync correctly
  - roaming enemies spawn correctly
  - HUD phase returns to `Day`
  - interaction/status refresh runs again
- Consolidated that setup into a shared day-entry helper to avoid `_ready()`, reset, and sleep transitions drifting apart.
- Strengthened the bed/day-cycle probes so they now verify real day-side effects, not just enum transitions.

Validation:
- Headless Godot project load still succeeded.
- Strengthened day-night cycle probe confirmed:
  - `day_night_cycle_probe_day_phase=Wave 0 / 8   |   Day`
  - `day_night_cycle_probe_day_enemy_count=19`
  - `day_night_cycle_probe_after_sleep_phase=Wave 1 / 8   |   Day`
  - `day_night_cycle_probe_after_sleep_enemy_count=20`
- Strengthened bed-gate probe confirmed:
  - `bed_gate_probe_after_sleep_phase=Wave 1 / 8   |   Day`
  - `bed_gate_probe_after_sleep_enemy_count=27`

### Day Night Probe Hardening
- Removed dead success-status writes from the dinner/sleep handlers so state transitions, not immediately overwritten messages, own the visible HUD text.
- Updated the day-night probes to clear waves through `WaveManager.clear_wave()` instead of bypassing the real night-end signal path with manual reset/callback calls.

Validation:
- Headless Godot project load still succeeded.
- Updated day-night cycle probe still confirmed:
  - `day_night_cycle_probe_after_dinner_state=1`
  - `day_night_cycle_probe_after_wave_state=2`
  - `day_night_cycle_probe_after_sleep_state=0`
- Updated bed-gate probe still confirmed:
  - `bed_gate_probe_can_sleep_before=false`
  - `bed_gate_probe_can_sleep_after=true`

### Full Wave-End Probe Upgrade
- Replaced the remaining forced wave-end shortcuts in the day-night probes with an actual “kill spawned enemies until the wave clears itself” loop.
- This exposed and fixed a real probe/runtime bug in `Zombie._spawn_death_drop()`, which had assumed `get_tree().current_scene` always existed.

Validation:
- Headless Godot project load still succeeded.
- End-to-end day-night cycle probe now reaches:
  - `day_night_cycle_probe_after_wave_state=2`
  - `day_night_cycle_probe_after_sleep_state=0`
- End-to-end bed-gate probe now reaches:
  - `bed_gate_probe_can_sleep_after=true`
  - `bed_gate_probe_after_sleep_state=0`

### Mechanics Plan Revision
- Added `MECHANICS_IMPLEMENTATION_PLAN.md` to capture the revised next-step design direction:
  - local firearm noise attraction
  - daily POI modifiers
  - weapon sidegrades with explicit visible traits
- Locked implementation scope to Phase 1 only for now: firearm noise with bounded investigate behavior.

### Firearm Noise Phase 1
- Added authored weapon noise fields:
  - `noise_radius`
  - `noise_alert_budget`
- Added authored enemy `noise_alert_weight`.
- Player firearms now emit a local noise event on shot commit.
- Exploration enemies now support a bounded `investigate` state from gunfire instead of jumping straight into full omniscient chase.
- The game now wakes the nearest exploration enemies within noise radius until the shot’s alert budget is exhausted.

Validation:
- Headless Godot project load still succeeded.
- New firearm noise probe confirmed:
  - `firearm_noise_probe_pistol_investigating=2`
  - `firearm_noise_probe_shotgun_investigating=2`
  - `firearm_noise_probe_open_pistol_investigating=0`
  - `firearm_noise_probe_open_shotgun_investigating=2`
  - `firearm_noise_probe_after_timeout_investigating=0`

### Daily POI Modifiers Phase 2 Slice
- Implemented the first working daily POI modifier slice in `Game` and `ScavengeNode`.
- Added:
  - one positive daily POI modifier
  - one negative daily POI modifier
  - depletion-aware rerolls
  - visible POI label and marker updates
- Current modifier effects:
  - `bountiful_food`: `+1 food` on POI searches
  - `extra_parts`: `+1 parts` on POI searches
  - `disturbed`: `+1` exploration guard count at that POI
  - `elite_present`: one extra elite exploration enemy at that POI
- Also added cleanup so daily elite enemies do not linger into a later day after the modifier moves elsewhere.

Validation:
- Headless Godot project load still succeeded.
- New daily POI modifier probe confirmed:
  - `daily_poi_modifier_probe_positive_count=1`
  - `daily_poi_modifier_probe_negative_count=1`
  - `daily_poi_modifier_probe_food_reward=3`
  - `daily_poi_modifier_probe_disturbed_counts=6>5`
  - `daily_poi_modifier_probe_elite_count=1`
  - `daily_poi_modifier_probe_elite_cleared=0`
  - `daily_poi_modifier_probe_depleted_poi_a_selected=false`
  - `daily_poi_modifier_probe_after_reset_positive=1`
  - `daily_poi_modifier_probe_after_reset_negative=1`
- Re-ran broader sanity probes after the phase 2 changes:
  - `day_night_cycle_probe_after_sleep_state=0`
  - `day_night_cycle_probe_after_sleep_enemy_count=18`
  - `firearm_noise_probe_after_timeout_investigating=0`

### Phase 2 Review Hardening
- Fixed `disturbed` so the modifier now raises the real POI clear threshold, not just the spawned guard count.
- Moved daily elite selection onto the authored exploration spawn points with a scene-level fallback instead of hardcoding one elite type in `Game`.
- Added a second authored daily elite variant: `zombie_elite_brute`.
- Strengthened the daily POI modifier probe so it now covers:
  - real day rerolls
  - disturbed clear bookkeeping
  - alternate elite selection
  - depleted-POI skip behavior
- Restored normal run defaults by turning `enable_test_mode` back off in `Game.tscn`.

Validation:
- Headless Godot project load still succeeded.
- Updated daily POI modifier probe confirmed:
  - `daily_poi_modifier_probe_live_cycle_positive=1`
  - `daily_poi_modifier_probe_live_cycle_negative=1`
  - `daily_poi_modifier_probe_disturbed_cleared_after_base=false`
  - `daily_poi_modifier_probe_disturbed_cleared_after_extra=true`
  - `daily_poi_modifier_probe_elite_enemy_id=zombie_elite_spitter`
  - `daily_poi_modifier_probe_alt_elite_enemy_id=zombie_elite_brute`
  - `daily_poi_modifier_probe_depleted_poi_a_selected=false`

### Phase 3 Weapon Sidegrades
- Added visible weapon trait text to the HUD and player weapon-state flow.
- Implemented:
  - `Kitchen Knife`: isolated-target bonus damage
  - `Baseball Bat`: explicit attack-prep interrupt
  - `Pistol`: precise/noisy role text
  - `Shotgun`: clustered-target bonus damage and very-noisy role text
- Added `weapon_sidegrade_probe.gd` and `hud_weapon_probe.gd` to verify sidegrade behavior and live HUD trait text.

Validation:
- Headless Godot project load still succeeded.
- Initial sidegrade probes confirmed:
  - `weapon_sidegrade_probe_knife_isolated_health=22`
  - `weapon_sidegrade_probe_knife_group_health_a=28`
  - `weapon_sidegrade_probe_knife_group_health_b=28`
  - `weapon_sidegrade_probe_bat_prep_before=true`
  - `weapon_sidegrade_probe_bat_prep_after=false`
  - `weapon_sidegrade_probe_shotgun_health_a=6`
  - `weapon_sidegrade_probe_shotgun_health_b=6`
- HUD weapon probe confirmed:
  - `initial_weapon_trait=Fast, isolated`
  - `after_bat_weapon_trait=Interrupt`

### Sidegrade Review Follow-Up
- Removed the generic “knockback always resets attack prep” behavior from `Zombie` so the bat's `Interrupt` trait is actually unique.
- Extended the sidegrade probe with a pistol control case:
  - bat still cancels prep
  - pistol now preserves armed prep
- Hardened the sidegrade probe twice:
  - first to use the real attack state machine instead of direct `_commit_attack(...)`
  - then to use the actual `attack` input path instead of calling `_attempt_attack()` directly

Validation:
- Headless Godot project load still succeeded.
- Input-driven sidegrade probe confirmed:
  - `weapon_sidegrade_probe_bat_prep_after=false`
  - `weapon_sidegrade_probe_pistol_prep_after=true`
  - `weapon_sidegrade_probe_shotgun_target_count=2`
- Regression probes still passed:
  - `firearm_noise_probe_after_timeout_investigating=0`
  - `daily_poi_modifier_probe_after_reset_positive=1`
  - `daily_poi_modifier_probe_after_reset_negative=1`
  - `day_night_cycle_probe_after_sleep_state=0`

### Balance And Readability Tuning Pass
- Tuned prep economy so dinner is less punishing:
  - increased `food_energy_per_unit` from `20` to `25`
  - increased food baseline at the food-heavy `POI_E`
  - slightly increased mixed-route food at `POI_F`
- Tightened firearm economy and late-wave pressure:
  - reduced shotgun damage from `36` to `34`
  - reduced shotgun cluster bonus from `8` to `6`
  - increased shotgun energy cost from `2` to `3`
  - increased shotgun reload time from `1.45s` to `1.55s`
  - reduced several authored bullet rewards in firearm-leaning POIs
  - reduced spitter and elite-spitter player range / detection pressure
  - softened waves `7` and `8` by slowing the spawn interval and reducing some late enemy counts
- Improved POI modifier readability:
  - stronger marker tinting
  - marker scale changes by modifier severity
  - clearer label tags: `[FOOD]`, `[PARTS]`, `[HOT]`, `[ELITE]`
  - restricted `elite_present` to the riskier weapon/combat POIs instead of the safer routes
- Added first-pass elite visual differentiation in `Zombie.tscn` / `Zombie`:
  - elite-only aura polygon
  - stronger elite facing-marker color
- Added `elite_visual_probe.gd` to verify the elite visual treatment at runtime.

Validation:
- Headless Godot project load still succeeded.
- Food-table probe now confirms the lighter dinner demand:
  - `food_table_probe_label=Eat 2 food and start night 1`
  - `food_table_probe_after_food=1`
- Daily POI modifier probe still confirmed:
  - one positive and one negative modifier
  - disturbed clear bookkeeping still correct
  - both elite variants still spawn through the authored daily-elite path
- Input-driven weapon sidegrade probe still confirmed:
  - `weapon_sidegrade_probe_bat_prep_after=false`
  - `weapon_sidegrade_probe_pistol_prep_after=true`
  - `weapon_sidegrade_probe_shotgun_health_a=10`
  - `weapon_sidegrade_probe_shotgun_health_b=10`
- New elite visual probe confirmed:
  - `elite_visual_probe_basic_aura_visible=false`
  - `elite_visual_probe_elite_aura_visible=true`
- Regression probes still passed:
  - `firearm_noise_probe_after_timeout_investigating=0`
  - `day_night_cycle_probe_after_sleep_state=0`

## 2026-04-01 Construction Safety Fix
- Adjusted barricade placement safety to use a local player-buffer rule instead of a global escape-to-edge trap test.
- Kept same-cell build placement working, while still rejecting adjacent pinch placements that can wedge the player between barricades.
- Updated the construction probes to cover:
  - same-cell placeable confirmation on a safe build cell
  - synthetic pinch rejection
  - expanded-ring outer-cell placement on a safe outer-ring candidate

Validation:
- `construction_grid_probe_active=true`
- `construction_grid_probe_corner_buffer=true`
- `construction_escape_probe_synth_one=true`
- `construction_escape_probe_synth_two=true`
- `construction_escape_probe_synth_same=false`
- `barricade_attack_probe_placed=true`
- `construction_expanded_probe_selected_cell=(-2, 3)`
- `construction_expanded_probe_placeables=1`

## 2026-04-01 Construction Anti-Wedge Refinement
- Tightened the barricade placement gate so the first nearby placement still succeeds, but a second nearby barricade that would wedge the player in a tight local cluster is rejected.
- The safety rule now looks at local player escape pressure plus existing runtime placeable occupancy, instead of a blanket player-buffer block that rejected valid first placements.
- Added a focused pinch probe to reproduce the exact “place one, step slightly, place another” case.

Validation:
- `barricade_pinch_probe_first=true`
- `barricade_pinch_probe_second_placed=false`
- `barricade_pinch_probe_status=Too cramped`
- `barricade_probe_placeables=1`
- `barricade_probe_placeables_after_dismantle=0`
- `construction_escape_probe_both=true`

## 2026-04-01 Construction Movement Safety Review
- Confirmed the chosen rule is to never auto-move the player when placing barricades.
- Reworked the check around local escape validation rather than forcing an avatar reposition.
- Added an end-to-end movement probe for the nearby barricade setup.

Validation:
- `barricade_escape_move_probe_second=false`
- `barricade_escape_move_probe_moved_right=true`
- `barricade_escape_move_probe_moved_left=true`
- `barricade_escape_move_probe_moved_up=true`
- `barricade_escape_move_probe_moved_down=true`

## 2026-04-01 Construction Placement Grace Fix
- Replaced the brittle anti-cramp placement veto with a player-only collision grace window on newly placed barricades.
- This keeps adjacent barricade construction legal while letting the player walk out of a newly placed barricade before it starts blocking them.
- Updated the repro scripts so the second placement keeps build mode active and exercises the real adjacent-place case.

Validation:
- `barricade_pinch_probe_first=true`
- `barricade_pinch_probe_second_placed=true`
- `barricade_escape_move_probe_second=true`
- `barricade_escape_move_probe_moved_right=true`
- `barricade_escape_move_probe_moved_left=true`
- `barricade_escape_move_probe_moved_up=true`
- `barricade_escape_move_probe_moved_down=true`

## 2026-04-01 Construction Collision Grace Refinement
- Tightened the barricade grace behavior to follow the player’s current grid cell instead of only using a short timer.
- The barricade now ignores the player until they leave the new barricade’s local footprint, which avoids the teleport/jam behavior without forcing any player movement.
- Verified the adjacent build case directly in the new pinch and movement probes.

Validation:
- `barricade_pinch_probe_first=true`
- `barricade_pinch_probe_second_placed=true`
- `barricade_escape_move_probe_after_first_cell=(-2, 3)`
- `barricade_escape_move_probe_second=true`
- `barricade_escape_move_probe_moved_right=true`
- `barricade_escape_move_probe_moved_left=true`
- `barricade_escape_move_probe_moved_up=true`
- `barricade_escape_move_probe_moved_down=true`

## 2026-04-01 Construction Collision Grace API Fix
- Replaced the invalid `set_collision_mask_bit()` calls on the player with a refcounted collision-mask exemption on `Player`.
- Barricades still block zombies, but the player can step out of a fresh placement without teleporting or getting wedged between adjacent builds.
- Kept the grace player-only and reversible so adjacent barricades remain legal.

Validation:
- `barricade_placement_probe_placeables=1`
- `barricade_pinch_probe_first=true`
- `barricade_pinch_probe_second_placed=true`
- `barricade_escape_move_probe_second=true`
- `barricade_escape_move_probe_moved_right=true`
- `barricade_escape_move_probe_moved_left=true`
- `barricade_escape_move_probe_moved_up=true`
- `barricade_escape_move_probe_moved_down=true`
- `barricade_attack_probe_placed=true`
- `barricade_attack_probe_barricade_hp=83`
- `construction_grid_probe_valid_tactical=true`

## 2026-04-01 Construction Recycle Function
- Added a full-refund `recycle()` path for `Placeable` so intact buildings can return all build materials instead of the previous half-refund dismantle behavior.
- Kept `dismantle()` as a separate helper path, but the normal full-health interact now shows and performs recycle.
- Updated the barricade lifecycle probe to verify repair followed by full refund recycle and occupancy clearing.

Validation:
- `barricade_probe_salvage_before=72`
- `barricade_probe_salvage_after=62`
- `barricade_probe_salvage_after_repair=58`
- `barricade_probe_placeables_after_recycle=0`
- `barricade_probe_cell_occupied_after_recycle=false`
- `barricade_probe_salvage_after_recycle=68`

## 2026-04-01 Recycle Key Binding
- Bound the full-health recycle action to `R` in the project input map.
- Kept `E` for repair/interact on placeables so the two actions are now distinct in play.
- Left the game-over restart path intact and restored the `R` restart binding in the input map.

Validation:
- `barricade_probe_recycle_action_exists=true`
- `barricade_probe_placeables_after_direct_recycle=0`
- `barricade_probe_cell_occupied_after_direct_recycle=false`
- `barricade_probe_salvage_after_direct_recycle=68`

## 2026-04-01 Build Selector and Multi-Cell Placeables
- Added a buildable catalog for build mode so the player can cycle between multiple authored placeables.
- Added `build_next` / `build_prev` inputs and updated build mode to show the selected buildable, its footprint, and the cycle hint in the HUD.
- Added a second authored placeable, `Spike Trap`, with a two-cell footprint to prove multi-grid occupancy and placement.
- Updated the construction grid preview to render the full footprint, not just the anchor cell, so multi-cell buildables are readable before placement.

Validation:
- `build_selector_probe_initial_profile=barricade`
- `build_selector_probe_next_profile=spike_trap`
- `build_selector_probe_next_footprint=2`
- `build_selector_probe_placeable_id=spike_trap`
- `build_selector_probe_second_cell_occupied=true`
- `build_selector_probe_placeable_scale=(2.0, 1.0)`
- `barricade_probe_placeables_after_recycle=0`
- `barricade_probe_cell_occupied_after_outside_recycle=false`

## 2026-04-01 Build Selector Keys
- Rebound build cycling to `Q` for previous and `Tab` for next, while keeping the mouse wheel as an optional next-cycle fallback.
- Updated the in-game build-mode prompt and HUD status text so they now describe `E` as place, `Q` as previous, and `Tab` / wheel as next.
- Kept `E` reserved for place/interact so the build selector no longer collides with placement controls.

Validation:
- `build_selector_probe_initial_profile=barricade`
- `build_selector_probe_next_profile=spike_trap`
- `build_selector_probe_placeable_id=spike_trap`
- `construction_grid_probe_active_stage_build_mode=true`
- `barricade_probe_placeables_after_recycle=0`

## 2026-04-01 Build Rotation
- Added a `build_rotate` input so build mode can rotate the currently selected placeable in 90-degree steps.
- Rotated footprints now drive both the preview footprint and the spawned placeable occupancy, so multi-cell buildables place in the rotated orientation instead of only changing the ghost.
- Added rotation-aware build-mode status text and build selector probe coverage for a rotated `Spike Trap`.

Validation:
- `build_selector_probe_rotation=1`
- `build_selector_probe_rotated_preview_footprint_cells=2`
- `build_selector_probe_horizontal_cell_occupied=false`
- `build_selector_probe_rotated_anchor_occupied=true`
- `build_selector_probe_rotated_second_cell_occupied=true`

## 2026-04-01 Rotate/Recycle Swap
- Swapped the build controls so `R` rotates the selected buildable and `C` recycles a full-health buildable in build mode.
- Removed the old direct `KEY_R` recycle fallback so recycle now uses the input map only.
- Updated the build-mode HUD prompt and README controls so the documented bindings match the runtime controls.

Validation:
- `build_selector_probe_rotation=1`
- `build_selector_probe_rotated_preview_footprint_cells=2`
- `build_selector_probe_rotated_anchor_occupied=true`
- `build_selector_probe_rotated_second_cell_occupied=true`
- `barricade_probe_placeables_after_recycle=0`
- `barricade_probe_cell_occupied_after_recycle=false`

## 2026-04-01 Build HUD Hints
- Tightened the build-mode HUD copy so it now shows the active buildable, footprint, and the core controls in a single compact line.
- Kept the build prompt aligned with the same compact control wording so the in-world hint and HUD status now match.

Validation:
- `barricade_probe_prompt=Build: E place | Q prev | Tab next | R rotate | C recycle`
- `build_selector_probe_rotation=1`
- `construction_grid_probe_active_stage_build_mode=true`

## 2026-04-02 Map Landmark Pass
- Added authored district landmark shells and route-island shapes across the enlarged world so the outer map reads as distinct regions instead of a mostly empty field.
- Kept the new landmark layer visual-only, preserving collisions, wave spawns, and the local home construction band while improving spatial identity.

Validation:
- `map_layout_probe_landmark_nw=true`
- `map_layout_probe_landmark_se=true`
- `map_layout_probe_route_islands=true`
- `construction_grid_probe_active=true`

## 2026-04-02 Micro-Loot Pass
- Added ten authored micro-loot spawn markers along district routes and landmark edges, using the existing `ResourcePickup` flow instead of hard-placed pickup instances.
- Tracked collected micro-loot in run save data so these travel rewards stay depleted after collection and restore cleanly on load.

Validation:
- `micro_loot_probe_initial_count=10`
- `micro_loot_probe_after_count=9`
- `micro_loot_probe_salvage_before=72`
- `micro_loot_probe_salvage_after=74`
- `micro_loot_probe_collected_saved=true`

## 2026-04-02 Ambient Threat Pass
- Expanded roaming exploration pressure from six outer anchors to twelve authored roaming zones, adding landmark-adjacent ambient threat around the yard, checkpoint, truck-stop, garden, clinic, and scrapyard districts.
- Increased the roaming spawn budget by one across the run so the enlarged map carries light ambient pressure without turning travel into constant combat.

Validation:
- `roaming_zone_probe_count=12`
- `roaming_zone_probe_has_landmark_zones=true`
- `roaming_spawn_probe_initial_roaming=3`
- `roaming_spawn_probe_mid_roaming=5`
- `roaming_spawn_probe_late_roaming=6`

## 2026-04-02 Combat Audio Pass
- Added a reusable `CombatAudio2D` node backed by a generated `CombatSfxLibrary`, so the game now has scene-owned positional combat SFX without requiring external audio assets first.
- Wired player attack, reload, and hurt events; zombie hurt, attack tell, and attack impact; and structure/trap hit events through the shared combat-audio component.
- Routed combat audio through a dedicated runtime-created `SFX` bus instead of `Master`, moved trap trigger playback behind the successful-hit gate, split player attack sounds by weapon id, and added hit-vs-miss impact layering.

Validation:
- `combat_audio_probe_player_miss_history=knife_swing,attack_miss`
- `combat_audio_probe_player_hit_history=knife_swing,attack_miss,pistol_shot,attack_hit_enemy`
- `combat_audio_probe_reload_start=player_reload_start`
- `combat_audio_probe_reload_done=player_reload_done`
- `combat_audio_probe_player_hurt=player_hurt`
- `combat_audio_probe_zombie_hurt=zombie_hurt`
- `combat_audio_probe_zombie_tell=zombie_attack_tell`
- `combat_audio_probe_zombie_hit=zombie_attack_hit`
- `combat_audio_probe_structure_hit=structure_hit`

## 2026-04-02 UI Polish Pass
- Reworked the authored boot shell so the main menu, settings panel, and load screen read more like intentional game UI instead of bare debug panels, while keeping the existing boot/save flow unchanged.
- Polished the HUD hierarchy by separating phase from wave count, switching the resource strip to clearer text labels, upgrading the status card into a titled field-status block, and styling pause/action surfaces more consistently.
- Added presentation-side severity handling in `hud.gd` so warning, danger, and success messages carry stronger visual feedback without changing gameplay logic.

Validation:
- `settings_manager_probe_boot_start_button=true`
- `settings_manager_probe_boot_settings_panel=true`
- `save_probe_boot_continue_disabled=false`
- `pause_probe_menu_visible=true`
- `pause_probe_active_wave_blocked=true`
- `initial_weapon_label=Weapon: Kitchen Knife`
- `after_bat_weapon_label=Weapon: Baseball Bat`
- `reset_phase_probe_wave_label=Night 0 / 8`

## 2026-04-03 Fog, Actor Visual, And Chase Polish
- Tightened the home fog presentation so it settles from the real viewport transform, thickens faster away from home, and still keeps a live clear pocket around the player.
- Added lightweight visual polish to the player and enemy actors, including shadows, state rings/indicators, smoother player movement bob/lean, and clearer in-world combat/readiness feedback.
- Forced gameplay actors and structures into a dedicated foreground z band and pushed decorative world art into a background layer to reduce accidental map-art overdraw.
- Fixed exploration enemy chase persistence so alerted enemies now keep chasing while they are still effectively on the current player view; once sight is broken and they fall off-screen/far enough away, they drop aggro.
- Renamed the enemy scene/script/controller surface to generic enemy terminology (`Enemy.tscn`, `enemy.gd`, `enemy_scene`, neutral `enemy_*` combat audio ids) so future non-zombie enemy types do not inherit zombie-specific code naming.

Validation:
- `actor_visual_probe_build_ring=true`
- `actor_visual_probe_reload_ring=true`
- `actor_visual_probe_enemy_noise_indicator=true`
- `actor_visual_probe_enemy_health_bar=true`
- `map_fog_probe_far_alpha_before_visit=0.900`
- `map_fog_probe_player_alpha_after_move=0.000`
- `zombie_chase_drop_probe_on_screen_engaged=true`
- `zombie_chase_drop_probe_far_engaged=false`
- `zombie_chase_drop_probe_far_alerted=false`
- `combat_audio_probe_enemy_tell=enemy_attack_tell`
- `combat_audio_probe_enemy_hit=enemy_attack_hit`
