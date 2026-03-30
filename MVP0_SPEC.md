# Home Survival MVP0 Spec

This document is the implementation source of truth for MVP0. It consolidates the product framing from `MVP0_ONE_PAGER.md`, the system defaults from `MVP0_DESIGN.md`, and the execution order from `TASK_BREAKDOWN.md`.

## Purpose
Build a desktop-first Godot 4 prototype that proves this loop:

`scavenge -> return -> strengthen base -> sleep -> defend -> repeat`

The prototype is successful if a first-time player can understand the loop without explanation, survive or fail a full run in about 10-20 minutes, and clearly feel that scavenging improves their odds in the next wave.

## Non-Goals
Do not implement for MVP0:
- realistic house layout
- neighborhood identity
- save/load
- traps or turrets
- freeform building
- multiple enemy types
- farming
- NPCs
- real-time day/night systems

## Source-Of-Truth Decisions
These decisions resolve ambiguities from the earlier docs.

- This file overrides the older MVP0 docs for implementation details.
- The run starts with no enemies present before the first wave.
- After wave `1` is cleared, `PRE_WAVE` exploration may include limited ambient enemies near POIs.
- Ambient exploration enemies do not target the base or defense sockets.
- Sleeping restores energy to full and restores a small amount of health.
- Defense sockets have 2 upgrade tiers: `damaged` and `reinforced`.
- `Broken` is not a third tier. It is any socket whose current HP reaches `0`.
- All POI nodes are finite for the entire run and only reset on full restart.
- Scavenging rewards use a deterministic baseline plus small bonus variance so every run keeps a valid win path.
- Core systems should stay small in MVP0, but data IDs and script boundaries should be stable enough to support additional content later.
- Wave 3 and later waves can use all 3 spawn lanes.

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
The run begins in a calm phase at wave `0`.

1. Player starts at base with full health and full energy.
2. The opening exploration phase is safe and has no enemies.
3. Player scavenges POI nodes to collect `Salvage`, `Parts`, and rare `Medicine`.
4. After wave `1`, later `PRE_WAVE` phases may include ambient exploration enemies around POIs.
5. Player returns to base and improves defense sockets.
6. Player sleeps to start the next wave, restore energy to full, and restore a small amount of HP.
7. Player survives the wave.
8. On wave clear, the game returns to calm phase.
9. The run ends when the player clears the final authored wave or dies.

## Run States
Use explicit run states:

- `PRE_WAVE`
- `ACTIVE_WAVE`
- `WIN`
- `LOSS`

Rules:
- Scavenging, strengthening, and sleeping are only available in `PRE_WAVE`.
- The initial `PRE_WAVE` phase before wave `1` is completely safe.
- After wave `1`, `PRE_WAVE` may contain ambient exploration enemies away from the base.
- Base-attacking enemies only exist in `ACTIVE_WAVE`.
- Restart is available in `WIN` and `LOSS`.
- The game starts in `PRE_WAVE` with `current_wave = 0`.

## Player
### Controls
- Move: 8-direction movement via 4 directional inputs
- `interact`
- `attack`
- `use_medicine`

### Stats
- Max health: `100`
- Max energy: `100`
- Melee damage: `25`
- Melee energy cost: `5`
- Melee cooldown: `0.45s`
- Medicine heal: `35`

### Rules
- Movement costs no energy.
- Attacking requires at least `5` energy.
- Scavenging consumes meaningful energy.
- Strengthening and repairing cost no energy.
- At `0` energy the player can still move, interact, return home, and sleep.
- At `0` energy the player cannot attack or search nodes.
- Sleep restores energy to full and leaves current health unchanged.

## Resources
Use only these resources:

- `Salvage`
- `Parts`
- `Medicine`

### Roles
- `Salvage`
  - common
  - used for repairs at any socket tier
  - used together with `Parts` for upgrades
  - gained from POIs and zombie drops
- `Parts`
  - uncommon
  - required to upgrade damaged sockets into reinforced sockets
  - gained from POIs only
- `Medicine`
  - rare
  - consumed by the player to restore health
  - gained from POIs only

### Inventory
- Inventory is unlimited.
- Resources are run-scoped and reset on restart.

### Resource IDs
Use stable lowercase IDs in code and data even if the HUD shows title case labels:

- `salvage`
- `parts`
- `medicine`

This avoids enum churn later if more resources are added.

## Map
### Structure
- One larger authored map
- One central abstract base
- Four authored POIs outside the base
- Three authored zombie spawn lanes at map edges

### Base
The base contains:
- 4 defense sockets
- 1 sleep point at the interior center
- open interior circulation so the player can rotate during waves

### Socket IDs
Use fixed IDs so wave targeting and reset logic stay simple:

- `wall_n`
- `wall_s`
- `door_w`
- `door_e`

The final art layout can be asymmetrical, but these IDs should remain stable in data and scripts.

### Content IDs
Use stable IDs for authored content. MVP0 only needs a few, but the pattern should hold:

- POIs: `poi_a`, `poi_b`, `poi_c`, `poi_d`
- spawn lanes: `north`, `east`, `west`
- enemy archetypes: `zombie_basic`, `zombie_brute`
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
  - includes one medicine node

### Node Rules
- `POI_A` has `4` searchable nodes.
- `POI_B` has `4` searchable nodes.
- `POI_C` has `4` searchable nodes.
- `POI_D` has `4` searchable nodes.
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
- node 4: `2 Parts`

`POI_C` baseline nodes
- node 1: `3 Salvage`
- node 2: `2 Salvage + 1 Parts`
- node 3: `2 Salvage + 1 Medicine`
- node 4: `2 Salvage + 1 Parts`

`POI_D` baseline nodes
- node 1: `1 Parts`
- node 2: `1 Salvage + 2 Parts`
- node 3: `1 Parts + 1 Medicine`
- node 4: `2 Parts`

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
- `tier`: `damaged` or `reinforced`
- `current_hp`

`Broken` means `current_hp == 0`. It is not a separate upgrade tier.

Implementation note:
- Keep `socket_type`, `tier`, and `socket_id` as explicit fields.
- Do not infer gameplay behavior from node names or art variants.

### Max HP By Type And Tier
- Wall damaged HP: `120`
- Wall reinforced HP: `240`
- Door damaged HP: `90`
- Door reinforced HP: `170`

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
- If the socket tier is `reinforced` and at full HP, show no action prompt.

### Costs
`Strengthen`
- wall: `6 Salvage + 2 Parts`
- door: `4 Salvage + 1 Parts`

`Repair`
- damaged wall: `2 Salvage`
- damaged door: `1 Salvage`
- wall: `3 Salvage`
- door: `2 Salvage`

### Results
- `Repair` on a damaged socket restores it to full damaged HP.
- `Strengthen` sets the socket to `reinforced` and restores it to full reinforced HP.
- `Repair` restores a reinforced socket to full reinforced HP.
- A broken damaged socket can still be strengthened.
- A broken damaged socket can also be repaired back to full damaged HP.
- A broken reinforced socket can still be repaired.

### Behavior
- Doors are weaker but cheaper to improve.
- Zombies can damage sockets until HP reaches `0`.
- A socket at `0` HP is breached and no longer blocks zombies.
- Socket visuals should clearly communicate damaged, reinforced, and breached conditions even though the only upgrade tiers are `damaged` and `reinforced`.

Future-facing rule:
- Additional socket types such as windows, barricades, or traps should be addable through socket data and visuals, without rewriting the wave or player interaction loop.

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
- Enemy stats and targeting preferences should come from an enemy definition resource or config object, even if MVP0 only ships one enemy archetype.

### Enemy Contexts
The same zombie archetype may appear in two different contexts:

- `exploration`
  - can appear during `PRE_WAVE`, but only after wave `1`
  - stays near POIs or authored exploration zones
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
- On death, a zombie drops a salvage pickup worth `1 Salvage`.
- `20%` of kills drop `2 Salvage` instead.
- Zombies never drop `Parts` or `Medicine`.

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
Wave `1`
- total zombies: `4`
- active lanes: `north`
- spawn split: `4`
- spawn interval: `0.8s`

Wave `2`
- total zombies: `7`
- active lanes: `east`, `west`
- spawn split: `4`, `3`
- spawn interval: `0.7s`

Wave `3`
- total zombies: `10`
- active lanes: `north`, `east`, `west`
- spawn split: `4`, `3`, `3`
- spawn interval: `0.6s`

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
- After wave `1`, later `PRE_WAVE` exploration may spawn ambient enemies near POIs.
- Clearing wave `3` ends the run in `WIN`.

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
