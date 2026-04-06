# Home Survival MVP2 Design Spec

MVP2 expands the prototype from a stable `prep -> defend` run into a more variable day-and-night survival loop.

MVP1 already established:
- power-limited construction
- Dog support
- heirlooms and legacy perks
- data-driven POIs
- a cleaner controller split for game and enemy logic

MVP2 should make runs feel less static without turning the game into a simulation-heavy content swamp.

## Goals
- make daytime routes contested and interesting
- make POIs vary by day
- give the player a daily objective layer
- deepen the power network beyond generator + slot math
- introduce enemy counterplay to static defenses
- add light run-to-run variation without unreadable stacking

## Milestones

### MVP2A
- PatrolDirector
- POI events

### MVP2B
- contract board
- power relay

### MVP2C
- screamer
- breaker
- daily mutators

### MVP2D
- optional legacy perk expansion, only if A-C are stable

## Locked Decisions
- `Power Relay` is a local powered anchor with a fixed radius.
- `Power Relay` does not directly stretch the main generator radius.
- contracts are generated from current POI-event and patrol-aware world state.
- `Sensor Tower` is out of scope for MVP2.
- perk expansion is optional-last, not required core scope.

## Systems

### 1. PatrolDirector
Daytime patrol squads move between authored route points and investigate noise.

Rules:
- active only in `PRE_WAVE`
- use the exploration enemy layer
- patrol enemies still use existing enemy AI once alerted
- patrols should reset cleanly on day reset / run reset / load

### 2. POI Events
Each day, some POIs receive an authored event definition.

Events may affect:
- reward bonuses
- guard count
- elite pressure
- event label / tooltip text

### 3. Contract Board
The base gets a board that offers daily objectives.

MVP2 contract types:
- visit specific POI
- defeat patrols
- survive the night without a breach

Rewards:
- salvage
- parts
- battery

### 4. Power Relay
Relay acts as a local powered anchor.

Rules:
- requires power draw
- only works while powered by the existing network
- once powered, it can power nearby powered placeables
- saved as normal construction state plus power-manager runtime reconstruction

### 5. Enemy Counterplay

#### Screamer
- weak body
- moderate detection
- periodically alerts nearby enemies once engaged

#### Breaker
- prefers powered placeables and tactical defenses over default structures
- pressures static automation first

### 6. Daily Mutators
One active mutator per day.

Initial MVP2 mutators:
- extra patrols
- rich salvage
- strong lights
- restless dead

Mutators are intentionally light and should stay readable.

## Persistence Requirements
The following must persist:
- patrol day state needed to restore current patrol spawns
- daily POI event assignments
- contract state and claimed/completed flags
- relay-powered construction state via reconstruction
- current mutator assignment

## Verification Requirements
Every new MVP2 system needs:
- one focused runtime probe
- one persistence probe if it owns day/run state
- targeted regression probes

Required regression set remains:
- `save_system_probe`
- `pause_menu_probe`
- `powered_defense_probe`
- `dog_companion_probe`
- `dog_lure_probe`
- `daily_poi_modifier_probe`
- `build_selector_probe`

## Out of Scope
- whole-map wiring simulation
- sensor tower / full intel network
- large perk trees
- faction systems
- procedural map generation
