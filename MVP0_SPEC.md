# Home Survival MVP0 Spec

This document is the implementation source of truth for MVP0. It consolidates the product framing from `MVP0_ONE_PAGER.md`, the system defaults from `MVP0_DESIGN.md`, and the execution order from `TASK_BREAKDOWN.md`.

## Purpose
Build a desktop-first Godot 4 prototype that proves this loop:

`day prep -> dinner -> night defense -> sleep -> repeat`

The prototype is successful if a first-time player can understand the loop without explanation, survive or fail a full run in about 10-20 minutes, and clearly feel that scavenging improves their odds in the next wave.

## Non-Goals
Do not implement for MVP0:
- realistic house layout
- neighborhood identity
- save/load
- traps or turrets
- freeform building
- farming
- NPCs
- real-time day/night systems

## Source-Of-Truth Decisions
These decisions resolve ambiguities from the earlier docs.

- This file overrides the older MVP0 docs for implementation details.
- `PRE_WAVE` exploration can include ambient enemies near POIs from the start of the run.
- Ambient exploration enemies do not target the base or defense sockets.
- Eating dinner at the table restores energy to full by consuming the exact food needed from inventory and then starts the next night wave.
- Sleeping on the bed after a cleared night wave restores a small amount of health and returns the run to the next day.
- Sleeping currently restores `25` HP.
- Defense sockets now have 3 progression states: `damaged`, `reinforced`, and `fortified`.
- `Broken` is not a third tier. It is any socket whose current HP reaches `0`.
- All POI nodes are finite for the entire run and only reset on full restart.
- Scavenging rewards use a deterministic baseline plus small bonus variance so every run keeps a valid win path.
- Core systems should stay small in MVP0, but data IDs and script boundaries should be stable enough to support additional content later.
- Wave 3 and later waves can use all 3 spawn lanes.
- The current authored run target is `8` waves.
- The current weapon set includes the starting `kitchen_knife` plus POI-obtained `baseball_bat`, `pistol`, and `shotgun` upgrades.
- The current pistol is a simple magazine-based sidearm with a `6`-round magazine, `1.0s` reload, and collectible bullet reserve ammo.
- The current resource set also includes `food`, used during prep to refill energy at the table.
- Prep phases now include both authored POI guards and rerolled roaming exploration enemies.

## Pillars
- Readability over simulation.
- Scarcity and prioritization over twitch pressure.
- Fixed authored content over procgen.
- Small enough to finish and tune quickly.

## Extensibility Guardrails
Build MVP0 in a way that supports richer future iterations without adding speculative systems now.

- Keep runtime logic simple, but keep content data-driven.
- Prefer stable IDs and small enums over hardcoded scene-name checks.
- Separate content definitions from gameplay rules wherever possible.
- Add new content by authoring data and scenes first, not by branching core logic.
- Avoid building a generic ECS or plugin-style architecture for MVP0.
- If a future feature is not used by MVP0, leave a clean extension point rather than a half-built subsystem.

## Run Structure
The run begins in `PRE_WAVE` at wave `0`.

1. Player starts at base with full health and full energy.
2. The opening exploration phase may already have hostile POIs away from the base.
3. Player scavenges POI nodes to collect `Salvage`, `Parts`, `Medicine`, `Bullets`, and `Food`.
4. Exploration enemies persist across prep phases unless killed and suspend during active waves.
5. Player returns to base, improves defense sockets, and eats dinner at the table to refill energy and begin the night wave.
6. Player survives the night wave.
7. On wave clear, the player sleeps on the bed to restore a small amount of HP and begin the next day.
8. The game returns to calm day phase.
9. The run ends when the player clears the final authored wave or dies.

## Run States
Use explicit run states:

- `PRE_WAVE`
- `ACTIVE_WAVE`
- `WIN`
- `LOSS`

Rules:
- Scavenging, strengthening, and eating dinner are only available in `PRE_WAVE`.
- Sleeping on the bed is available after a cleared wave, before the next day begins.
- `PRE_WAVE` can contain ambient exploration enemies away from the base, including before wave `1`.
- Base-attacking enemies only exist in `ACTIVE_WAVE`.
- Restart is available in `WIN` and `LOSS`.
- The game starts in `PRE_WAVE` with `current_wave = 0`.

## Player
### Controls
- Move: 8-direction movement via 4 directional inputs
- `interact`
- `attack`
- `use_medicine`
- `switch_weapon`
- `reload_weapon`

### Stats
- Max health: `100`
- Max energy: `100`
- Medicine heal: `35`
- Sleep heal: `25`
- Food energy refill: exact-to-full via table interaction

### Rules
- Movement costs no energy.
- Attack timing, damage, reach, energy cost, and knockback are weapon-defined.
- The player starts with `Kitchen Knife`.
- Additional obtained weapons can be switched during the run.
- Firearms can define magazine size and reload timing separately from melee timing.
- Scavenging consumes meaningful energy.
- Strengthening and repairing cost no energy.
- At `0` energy the player can still move, interact, return home, and sleep.
- At `0` energy the player cannot attack or search nodes.
- The table restores energy to full by consuming food.
- Sleep restores a small amount of HP and starts the next day.

## Resources
Use only these resources:

- `Salvage`
- `Parts`
- `Medicine`
- `Bullets`
- `Food`

### Roles
- `Salvage`
  - common
  - used for repairs at any socket tier
  - used together with `Parts` for upgrades
  - gained from POIs and zombie drops
- `Parts`
  - uncommon
  - required for reinforced and fortified upgrades
  - gained mainly from POIs and some elite drops
- `Medicine`
  - rare
  - consumed by the player to restore health
  - gained from POIs only
- `Bullets`
  - uncommon
  - consumed by firearm reloads
  - gained from POIs and some elite drops
- `Food`
  - prep-focused
  - consumed at the table to refill missing energy to full
  - gained mainly from POIs

### Inventory
- Inventory is unlimited.
- Resources are run-scoped and reset on restart.

### Resource IDs
Use stable lowercase IDs in code and data even if the HUD shows title case labels:

- `salvage`
- `parts`
- `medicine`
- `bullets`
- `food`

This avoids enum churn later if more resources are added.

## Map
### Structure
- One 2x larger authored map
- One central abstract base
- Six authored POIs outside the base
- Three authored zombie spawn lanes at map edges

### Base
The base contains:
- 4 defense sockets
- 1 food table near the interior center
- 1 bed near the interior center
- open interior circulation so the player can rotate during waves
- a local construction band around the home for tactical barricades and traps, with the four home corners reserved

### Socket IDs
Use fixed IDs so wave targeting and reset logic stay simple:

- `wall_n`
- `wall_s`
- `door_w`
- `door_e`

The final art layout can be asymmetrical, but these IDs should remain stable in data and scripts.

### Content IDs
Use stable IDs for authored content. MVP0 only needs a few, but the pattern should hold:

- POIs: `poi_a`, `poi_b`, `poi_c`, `poi_d`, `poi_e`, `poi_f`
- spawn lanes: `north`, `east`, `west`
- enemy archetypes: `zombie_basic`, `zombie_brute`, `zombie_runner`, `zombie_spitter`
- elite variants currently authored: `zombie_elite_spitter`, `zombie_elite_brute`
- socket IDs: the 4 fixed socket IDs listed above

Future systems should refer to these IDs, not scene paths or display names.

## Scavenging
### POIs
- `POI_A`
  - closer
  - safer
  - favors `Salvage`
- `POI_B`
  - upper-right
  - favors `Parts`
  - lower raw `Salvage`
- `POI_C`
  - lower-left
  - favors `Salvage`
  - includes one medicine node
- `POI_D`
  - lower-right
  - favors `Parts`
  - firearm cache with bullets and weapon rewards
- `POI_E`
  - upper-mid
  - favors `Food`
  - supports prep recovery
- `POI_F`
  - lower-mid
  - higher-risk combat POI
  - supports elite encounters and stronger mixed rewards

### Node Rules
- `POI_A` has `4` searchable nodes.
- `POI_B` has `4` searchable nodes.
- `POI_C` has `4` searchable nodes.
- `POI_D` has `4` searchable nodes.
- `POI_E` has `4` searchable nodes.
- `POI_F` has `4` searchable nodes.
- Search time: `0.9s`
- Search energy cost: `15`
- A searched node becomes depleted for the rest of the run.
- Node visuals must clearly show `available` vs `depleted`.
- Search rewards are granted directly to inventory when the interaction completes.
- Each node grants a fixed baseline reward.
- Some nodes also roll a small bonus reward.
- Bonus variance must never remove the baseline win path.
- Each node should store its own authored baseline reward and optional bonus table reference.

### Loot Tables
Use authored baseline rewards per node.

`POI_A` baseline nodes
- node 1: `3 Salvage`
- node 2: `2 Salvage`
- node 3: `2 Salvage + 1 Parts`
- node 4: `2 Salvage + 1 Medicine`

`POI_B` baseline nodes
- node 1: `1 Parts`
- node 2: `1 Salvage + 1 Parts`
- node 3: `1 Parts`
- node 4: `2 Parts + Baseball Bat`

`POI_C` baseline nodes
- node 1: `3 Salvage`
- node 2: `2 Salvage + 1 Parts`
- node 3: `2 Salvage + 1 Medicine`
- node 4: `2 Salvage + 1 Parts`

`POI_D` baseline nodes
- node 1: `1 Parts + 4 Bullets + Shotgun`
- node 2: `1 Salvage + 2 Parts + 4 Bullets`
- node 3: `1 Parts + 1 Medicine + 2 Bullets`
- node 4: `2 Parts + 6 Bullets + Pistol`

`POI_E` baseline nodes
- node 1: `2 Food + 1 Salvage`
- node 2: `2 Food + 1 Parts`
- node 3: `1 Food + 1 Medicine`
- node 4: `3 Food + 1 Parts`

`POI_F` baseline nodes
- node 1: `2 Parts + 2 Bullets`
- node 2: `2 Salvage + 1 Parts + 1 Food`
- node 3: `1 Medicine + 1 Food`
- node 4: `2 Parts + 4 Bullets`

Optional bonus roll after baseline reward:

`POI_A` bonus table
- `50%`: `+1 Salvage`
- `30%`: no bonus
- `15%`: `+1 Parts`
- `5%`: `+1 Medicine`

`POI_B` bonus table
- `40%`: `+1 Parts`
- `35%`: `+1 Salvage`
- `20%`: no bonus
- `5%`: `+1 Medicine`

Intent:
- Minimum guaranteed rewards across all POIs are `20 Salvage`, `14 Parts`, and `3 Medicine`.
- That baseline must preserve a valid win path if the player manages combat and spending well.
- Bonus rolls improve margins and recovery without deciding whether the run is fundamentally winnable.
- `POI_A` and `POI_C` mainly fund repairs and recovery.
- `POI_B` and `POI_D` mainly fund upgrade progression.

## Defense Sockets
### Tier Model
Each socket has:
- `socket_type`: `wall` or `door`
- `tier`: `damaged`, `reinforced`, or `fortified`
- `current_hp`

`Broken` means `current_hp == 0`. It is not a separate upgrade tier.

Implementation note:
- Keep `socket_type`, `tier`, and `socket_id` as explicit fields.
- Do not infer gameplay behavior from node names or art variants.

### Max HP By Type And Tier
- Wall damaged HP: `120`
- Wall reinforced HP: `240`
- Wall fortified HP: `380`
- Door damaged HP: `90`
- Door reinforced HP: `170`
- Door fortified HP: `250`

### Starting Setup
All 4 sockets begin in the `damaged` tier.

Starting HP:
- `wall_n`: `120 / 120`
- `wall_s`: `120 / 120`
- `door_w`: `90 / 90`
- `door_e`: `90 / 90`

The run starts with a fully repaired but unreinforced perimeter.

### Actions
Expose one context-sensitive interaction at each socket.

- If the socket tier is `damaged` and missing HP, show `Repair`.
- If the socket tier is `damaged` and at full damaged HP, show `Strengthen`.
- If the socket tier is `reinforced` and missing HP, show `Repair`.
- If the socket tier is `reinforced` and at full HP, show `Fortify`.
- If the socket tier is `fortified` and missing HP, show `Repair`.
- If the socket tier is `fortified` and at full HP, show no action prompt.

### Costs
`Strengthen`
- wall: `6 Salvage + 2 Parts`
- door: `4 Salvage + 1 Parts`

`Fortify`
- wall: `9 Salvage + 4 Parts`
- door: `6 Salvage + 3 Parts`

`Repair`
- damaged wall: `2 Salvage`
- damaged door: `1 Salvage`
- reinforced wall: `4 Salvage`
- reinforced door: `2 Salvage`
- fortified wall: `6 Salvage + 1 Parts`
- fortified door: `4 Salvage + 1 Parts`

### Results
- `Repair` on a damaged socket restores it to full damaged HP.
- `Strengthen` sets the socket to `reinforced` and restores it to full reinforced HP.
- `Fortify` sets the socket to `fortified` and restores it to full fortified HP.
- `Repair` restores a reinforced socket to full reinforced HP.
- `Repair` restores a fortified socket to full fortified HP.
- A broken damaged socket can still be strengthened.
- A broken damaged socket can also be repaired back to full damaged HP.
- A broken reinforced socket can still be repaired.
- A broken reinforced socket can still be fortified.
- A broken fortified socket can still be repaired.

### Behavior
- Doors are weaker but cheaper to improve.
- Fortified structures are a late-run investment, not an invulnerability state.
- Zombies can damage sockets until HP reaches `0`.
- A socket at `0` HP is breached and no longer blocks zombies.
- Socket visuals should clearly communicate damaged, reinforced, fortified, and breached conditions.

Future-facing rule:
- Additional socket types such as windows, plus tactical placeables such as barricades or traps, should be addable through authored data and visuals, without rewriting the wave or player interaction loop.

## Construction
- The game includes a controlled free-grid construction layer for tactical placeables.
- Build mode is available during `PRE_WAVE` and is toggled with `B`.
- The first implemented placeable is a barricade, which costs `Salvage`, occupies grid cells, can be repaired or dismantled, and blocks movement until destroyed.
- Construction placement must not trap the player or permanently seal the base routes.
- Future placeables such as traps, decoys, and turrets should share the same placement and interaction plumbing.

## Combat
### Player Attack
- Single short-range melee strike
- Hits enemies in front of the player
- Costs `5` energy
- Uses the player damage default of `25`

Implementation note:
- Keep damage application behind shared methods such as `take_damage`, `heal`, and `is_alive`.
- MVP0 does not need a full status-effect system, but it should not special-case damage separately for player, zombie, and sockets if a common helper will do.

### Zombie
Use one zombie type only.

Stats:
- Health: `50`
- Structure damage per hit: `10`
- Player damage per hit: `10`
- Move speed: slow and readable
- Attack interval: `1.0s`

Future-facing rule:
- Enemy stats and targeting preferences should come from an enemy definition resource or config object so new archetypes can be added without rewriting core AI flow.

### Enemy Contexts
The same zombie archetype may appear in two different contexts:

- `exploration`
  - can appear during `PRE_WAVE` from the start of the run
  - includes both authored POI guards and rerolled roaming prep spawns
  - pressures the player during scavenging
  - does not target sockets or path toward the base
- `wave`
  - appears only during `ACTIVE_WAVE`
  - targets the base and defense sockets
  - creates the home-defense phase

### Targeting Rules
- `wave` enemies:
  - each zombie is assigned a target socket when it spawns
  - it pathfinds to that socket and attacks it until one of these conditions applies:
    - the player damages the zombie
    - the player enters close aggro range
    - the target socket is breached and the player is a nearer valid target
  - if the player disengages, the zombie returns to socket pressure when possible
- `exploration` enemies:
  - patrol, idle, or hold position within authored exploration areas
  - aggro onto the player when nearby or attacked
  - do not select defense sockets as targets
- Keep retargeting simple. Do not build complex threat systems for MVP0.

### Drops
- Basic enemies still primarily drop salvage.
- Some enemy definitions can also drop `Parts`, `Bullets`, or `Food`.
- Elite enemy definitions can also roll weapon drops at low odds.
- Weapon-drop pickups must render differently from normal resource pickups.

## Waves
### Lane Setup
Author three spawn lanes:

- `north`
- `east`
- `west`

Each lane should have one or more spawn points and a preferred list of nearby socket IDs. Zombies spawned in a lane should pick targets from that lane's preferred sockets first.

Implementation note:
- Wave data should define lane entries explicitly rather than hardcoding `if wave == 2` logic in scripts.
- Each lane entry should support at least: `lane_id`, `enemy_id`, `count`, and `spawn_interval`.

### Wave Data
The current authored wave set contains `8` waves and mixes:
- `zombie_basic`
- `zombie_brute`
- `zombie_runner`
- `zombie_spitter`

Late waves increase pressure mainly through composition and lane variety rather than only higher counts.

### Flow
- Sleeping in `PRE_WAVE` increments the wave number and starts that wave immediately.
- Sleeping is disabled during `ACTIVE_WAVE`.
- Base-attacking wave enemies spawn only during `ACTIVE_WAVE`.
- A wave ends when all zombies from that wave are dead.
- On wave clear:
  - state returns to `PRE_WAVE`
  - player keeps current health
  - player keeps current energy
  - sleep becomes available again
- Every `PRE_WAVE` phase can also reroll roaming exploration enemies in POI-biased outer zones.
- Clearing wave `8` ends the run in `WIN`.

## UI
### HUD
Always show:
- health bar
- energy bar
- current wave
- `Salvage`
- `Parts`
- `Medicine`
- interaction prompt

### Messages
Support temporary messages for:
- `Not enough resources`
- `Too tired`
- `Wave N started`
- `Wave cleared`
- `Base strengthened`
- `Base repaired`
- `You survived`
- `You died`

### End States
- `WIN` shows a victory message and restart prompt.
- `LOSS` shows a death message and restart prompt.

## Restart
Restart must fully reset:
- run state
- current wave
- player position
- player health
- player energy
- all resources
- medicine count
- POI depletion
- socket tiers
- socket HP
- active zombies
- HUD messages

## Script Boundaries
Use small, explicit ownership boundaries so future features can plug in cleanly.

- `GameManager`
  - owns run state, win/loss, restart, and references to top-level systems
- `WaveManager`
  - owns wave definitions, spawning cadence, alive enemy tracking, and wave completion
- `Player`
  - owns movement, combat input, health, energy, medicine use, and inventory counts
- `DefenseSocket`
  - owns socket state, HP, repair/strengthen interactions, and breach state
- `ScavengeNode`
  - owns search timing, depletion, authored reward data, and payout
- `Zombie`
  - owns movement, target selection within its allowed rules, attacks, aggro, and death drops
- `HUD`
  - reads from managers and player state and displays prompts, bars, and messages

Rules:
- Managers should coordinate state, not implement every gameplay detail themselves.
- World objects should expose clear methods and signals instead of being manipulated by deep scene-tree lookups.
- Prefer signals or direct references passed at setup over global string-based node searches.

## Suggested Project Structure
- `scenes/main/Game.tscn`
- `scenes/player/Player.tscn`
- `scenes/enemies/Zombie.tscn`
- `scenes/world/DefenseSocket.tscn`
- `scenes/world/ScavengeNode.tscn`
- `scenes/ui/HUD.tscn`
- `scripts/managers/game_manager.gd`
- `scripts/managers/wave_manager.gd`
- `scripts/player/player.gd`
- `scripts/enemies/zombie.gd`
- `scripts/world/defense_socket.gd`
- `scripts/world/scavenge_node.gd`
- `scripts/ui/hud.gd`
- `data/resources/resource_defs.tres`
- `data/enemies/zombie_basic.tres`
- `data/pois/poi_a.tres`
- `data/pois/poi_b.tres`
- `data/waves/wave_1.tres`
- `data/waves/wave_2.tres`
- `data/waves/wave_3.tres`

## Interaction Contract
Interactable world objects should follow one small contract, even if it is informal in MVP0.

Recommended methods:
- `get_interaction_label(player) -> String`
- `can_interact(player) -> bool`
- `interact(player) -> void`

MVP0 interactables:
- `ScavengeNode`
- `DefenseSocket`
- `SleepPoint`

This keeps future interactables such as storage, crafting stations, NPCs, or traps compatible with the same player interaction loop.

## Implementation Order
1. Scaffold the Godot project structure, input map, main scene, camera, and placeholder map.
2. Implement player movement, collision, health, energy, attack, death, and pickup collection.
3. Add HUD bars, resource counts, wave display, prompts, and message text.
4. Implement POIs, searchable nodes, search timing, energy use, depletion, and loot payout.
5. Implement defense sockets, HP, breach behavior, strengthen and repair interactions, and visual state changes.
6. Implement sleep point logic and run-state transitions.
7. Implement zombie spawning, targeting, combat, socket attacks, drops, and wave completion.
8. Implement win, loss, and full restart.
9. Tune numbers for pacing, pressure, and run length.

## Acceptance Checklist
- A complete run can be played from start to finish with no soft-locks.
- The player must scavenge to obtain enough `Parts` to win.
- The scavenging baseline guarantees a theoretical win path; RNG can improve a run but must not invalidate it.
- Zombie drops help maintain the base but do not replace scavenging.
- Doors feel like meaningful weak points and early priorities.
- The player can always understand current health, energy, resources, wave state, and nearby interaction.
- Sleeping is the only way to start a wave.
- Wave `3` is winnable with good play but not trivial.
- Restart returns the game to a fully clean initial state.
