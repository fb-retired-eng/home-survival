# Mechanics Implementation Plan

Date: 2026-03-31

## Scope
This plan replaces the earlier `threat heat` direction with a more readable first step:

1. local firearm noise attraction
2. daily POI modifiers
3. weapon sidegrades with explicit visible traits

Current implementation status:
- Phase 1 is implemented and probe-verified
- Phase 2 is implemented in its current planned slice:
  - one positive POI modifier per day
  - one negative POI modifier per day
  - visible POI label/marker updates
  - depletion-aware rerolls
  - reward, disturbed-clear, and daily-elite hooks
- Phase 3 is implemented and probe-verified:
  - HUD trait line near the equipped weapon
  - knife isolated bonus
  - bat-only attack-prep interrupt
  - pistol/shotgun role text
  - shotgun clustered-target bonus
  - runtime probe coverage through the real `attack` input path

## Why This Version
The earlier global heat idea had good tension upside, but too much hidden-state risk for the current prototype.

This revised plan keeps the strongest gameplay consequence:
- firearms are powerful
- firearms create danger

but makes the consequence local, visible, and easier to tune.

## Phase 1: Local Firearm Noise Attraction

### Goal
Make firearm use during day exploration tactically expensive in a readable way.

### Rules
- only exploration enemies react
- no new enemies spawn from noise
- no noise effect during `ACTIVE_WAVE`
- knife stays silent
- bat stays silent for now
- pistol creates medium local attraction
- shotgun creates stronger local attraction

### Enemy Reaction Model
Gunfire should not create instant omniscient chase.

Use a two-step response:
1. `investigate`
2. `chase` only after valid player detection, attack, or touch

### Investigate Lifecycle
Investigation needs a clean end rule.

Defaults:
- `investigate_duration`: `3.0s`
- investigation ends early if:
  - the enemy reaches the shot location
  - the enemy detects the player normally
  - the enemy is hit or body-touched
- if investigation expires without detection:
  - anchored exploration enemies return to their anchor/facing behavior
  - roaming exploration enemies return to idle roaming behavior

### Fairness Guards
Do not wake enemies by raw count alone.

Use a small alert budget:
- pistol:
  - `noise_radius = 160`
  - `noise_alert_budget = 3.0`
- shotgun:
  - `noise_radius = 240`
  - `noise_alert_budget = 5.0`

Enemy alert weights:
- basic: `1.0`
- runner: `1.5`
- brute: `2.0`
- spitter: `2.0`
- elite spitter: `3.0`

Selection rule:
- nearest eligible exploration enemies first
- stop once the per-shot alert budget is exhausted

### Implementation

#### Weapon Data
Add to [weapon_definition.gd](scripts/data/weapon_definition.gd):
- `noise_radius`
- `noise_alert_budget`

#### Enemy Data
Add to [enemy_definition.gd](scripts/data/enemy_definition.gd):
- `noise_alert_weight`

#### Player
In [player.gd](scripts/player/player.gd):
- emit a signal when a firearm attack commits successfully or fires a visible shot
- include:
  - shot source position
  - noise radius
  - noise alert budget
  - weapon id

#### Game
In [game.gd](scripts/main/game.gd):
- handle firearm noise events
- gather valid exploration enemies
- sort by distance
- apply budget-limited investigate alerts

#### Enemy
In [zombie.gd](scripts/enemies/zombie.gd):
- add `receive_noise_alert(player_ref, source_position)`
- add noise-investigation state
- move toward investigation point when not already chasing
- exit investigate cleanly on timeout or arrival

### Readability
Required:
- alerted enemies visibly turn and move
- optional short status message only if useful

The player should be able to explain:
- `I fired`
- `they heard it`
- `they came to investigate`

### Success Criteria
- one pistol shot near a POI creates a local, usually solvable complication
- repeated shotgun use reliably creates a much more dangerous local pull
- firearm noise does not wake the whole map
- enemies do not remain stuck in investigate forever

### Tests
- pistol shot alerts nearby exploration enemies, not far ones
- shotgun alerts more total threat than pistol
- knife produces no alert
- wave enemies ignore exploration firearm noise logic
- alerted enemies leave investigate after timeout if no player is found

## Phase 2: Daily POI Modifiers

### Goal
Make route choice vary by day without unreadable spikes.

### Rules
- exactly one positive modifier per day
- exactly one negative modifier per day
- no POI gets both on the same day
- no POI gets more than one combat-escalation modifier
- depleted POIs should be deprioritized or rerolled

### Candidate Modifiers
Positive:
- `bountiful_food`
- `extra_parts`
- `ammo_cache`
- `quiet_today`

Negative:
- `disturbed`
- `heavy_guard`
- `elite_present`

### Readability
- POI label or marker must show the modifier before commit

### Current First Slice
Implemented now:
- exactly one positive and one negative daily POI modifier when eligible
- no POI receives both on the same day
- depleted POIs are skipped during assignment
- visible label and marker tint updates on the map
- `bountiful_food` adds `+1 food` to POI searches
- `extra_parts` adds `+1 parts` to POI searches
- `disturbed` adds `+1` to that POI's exploration guard target count and clear threshold
- `elite_present` adds one POI-local elite exploration enemy for the day from the authored spawn-point elite definition or scene fallback

Not implemented yet:
- additional modifiers like `ammo_cache` or `quiet_today`
- cluster-aware POI escalation tuning beyond the first bounded slice

## Phase 3: Weapon Sidegrades With Visible Traits

### Goal
Make each weapon solve a different problem and surface that role clearly.

### Required Surfacing
Every sidegrade must be visible in live play:
- HUD trait line near current weapon
- pickup text
- switch/equip status text

### Intended Roles
- `Kitchen Knife`: fast, strong vs isolated
- `Baseball Bat`: interrupts attacks
- `Pistol`: precise, noisy
- `Shotgun`: anti-pack, very noisy

### Current Slice
Implemented now:
- `hud_trait_text` is surfaced in the live HUD next to the equipped weapon
- `Kitchen Knife` gets an isolated-target damage bonus
- `Baseball Bat` explicitly interrupts enemy attack prep
- `Pistol` and `Shotgun` expose their role text without inheriting the bat interrupt behavior
- `Shotgun` gets clustered-target bonus damage

Validation now includes:
- `weapon_sidegrade_probe.gd` through the real `attack` input path
- `hud_weapon_probe.gd`
- regression sweeps for day/night, firearm noise, and daily POI modifiers

## Rollout
- implement and validate Phase 1 first
- review and tune before touching Phase 2
- do not build all three systems together
