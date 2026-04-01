# Game Mechanics Research Report

Date: 2026-03-31

## Purpose
Identify high-value mechanics from strong survival-defense games and apply them to the current `Home Survival` prototype, not as abstract inspiration, but as practical next-step design work.

This report is grounded in the current game state described in [README.md](README.md) and [MVP0_SPEC.md](MVP0_SPEC.md):
- `day -> dinner -> night defense -> sleep -> repeat`
- 6 POIs
- 8 waves
- roaming prep enemies
- 4 weapons
- food, bullets, medicine, salvage, parts
- wall/door upgrades up to `fortified`

## Current Game Review
The prototype already has a strong core shape:
- a readable macro loop
- short-run survival pressure
- distinct prep and defense phases
- meaningful resource categories
- early foundations for weapon roles and enemy roles

The biggest current design gap is not missing content count. It is **decision texture**.

Right now the player often answers the same questions:
- which POI should I hit first?
- do I have enough food and bullets?
- which weapon should I use right now?
- should I spend on defense or save?

Those are good questions, but they need sharper mechanical support so each day feels less like repeating the same route and more like solving a new pressure pattern.

## Research Basis
These source patterns were especially relevant:

- `Left 4 Dead`:
  - adaptive dramatic pacing
  - structured unpredictability
  - enemy roles that force cooperation and tactical response
  - source: Valve GDC 2009 talk and AI Director materials
- `Darkwood`:
  - day scavenging / night fortification split
  - hideout tension and defensive preparation
  - source: Steam page
- `This War of Mine`:
  - day shelter management / night scavenging pressure
  - survival framed through constrained civilian tradeoffs
  - source: Steam page
- `The Last Spell`:
  - rebuild by day, defend by night
  - weapon-defined playstyles
  - specialist enemies plus elite pressure
  - source: Steam page
- `They Are Billions`:
  - noise attracts danger
  - breaches can create cascading failure
  - structured colony-defense escalation
  - source: Steam page

## Top Mechanics

### 1. Threat Heat / Noise Director
Priority: Highest
Fit: Excellent
Implementation Cost: Medium

#### What It Is
A lightweight hidden `threat heat` system that rises when the player makes noisy or greedy decisions during the day:
- gunfire
- repeated scavenging in one region
- fighting near a POI
- leaving enemies alive near a route
- opening high-value caches

As heat rises, the game responds with:
- more roaming enemies
- higher odds of runners or spitters
- elite chance increases in specific zones
- less safe return paths

#### Why It Works
This is the strongest mechanic to borrow from `Left 4 Dead` and `They Are Billions`.
The key idea is not “more randomness.” The key idea is **structured unpredictability**:
- player actions shape danger
- danger rises in understandable ways
- runs stay fresh without becoming unreadable

This also solves a current prototype issue: prep exploration can become either too routine or too binary. A heat system gives the day phase a real tension curve.

#### How To Apply It Here
Add three layers:

1. Global day heat
- starts low each morning
- rises from noise, gun use, and prolonged exploration
- affects roaming spawn budget and enemy mix

2. Local POI heat
- each POI tracks how “disturbed” it is that day
- repeated searches or combat there increase local ambush odds

3. Return-path pressure
- when day heat is high, spawn more enemies between outer POIs and base, not just around POIs

#### Rules To Keep It Fair
- never spawn inside the base-safe radius
- surface the system indirectly with UI/audio:
  - “too much noise”
  - “something is moving nearby”
  - stronger ambient threat cues
- make firearm use powerful but visibly risky in day exploration

#### Review
This is the best next mechanic because it improves replayability, economy, weapon choice, and route planning at once.

#### First Slice
- add `day_heat` in `Game`
- raise it from pistol/shotgun shots, scavenges, and elite fights
- map it to roaming spawn budget and special-enemy odds

---

### 2. Stronger POI Identity With Daily Route Commitments
Priority: Highest
Fit: Excellent
Implementation Cost: Low-Medium

#### What It Is
Make each POI not only a loot category, but a **day plan**.

Right now POIs already have authored reward identity. Push that further:
- one POI is the “food solve”
- one is the “repair solve”
- one is the “ammo solve”
- one is the “weapon gamble”
- one is the “medicine insurance” route
- one is the “high-risk mixed-value” route

Then add day-specific modifiers:
- one POI is swarming today
- one has extra food today
- one has an elite today
- one has reduced search cost today

#### Why It Works
`This War of Mine` and `Darkwood` both make the “where do I go tonight/today?” decision matter more than raw traversal.
Your game already has POIs, so this mechanic is low-risk and high-yield.

#### How To Apply It Here
Add a simple per-day POI modifier system:
- `bountiful_food`
- `disturbed`
- `elite_present`
- `quiet_today`
- `extra_parts`

These should be visible on the map or label:
- icon beside POI label
- color accent on marker

#### Review
This is one of the cheapest meaningful improvements you can make. It increases route diversity without needing new combat systems first.

#### First Slice
- roll one positive and one negative POI modifier each day
- expose them visually on POI markers
- tune rewards or guard counts accordingly

---

### 3. Breach Cascade / Interior Crisis
Priority: High
Fit: Very Good
Implementation Cost: Medium

#### What It Is
A breach should create more than “one socket has 0 HP.”
Borrow the core pressure idea from `They Are Billions`: once a defense point fails, the problem compounds quickly if ignored.

In `Home Survival`, this should be smaller and more readable:
- breached door/wall creates an `interior danger lane`
- enemies reaching the interior can:
  - interrupt table/bed use
  - threaten the player more directly
  - damage a small “home integrity” or “supplies at risk” layer

#### Why It Works
Right now base defense can still feel too socket-local. A breach should change the whole tactical meaning of the night.
This adds drama without requiring a full colony sim infection model.

#### How To Apply It Here
Do not make it instant-loss.
Use a small escalating penalty model:
- first breach: table/bed blocked until clear
- sustained breach: interior integrity meter drops slowly
- deeper breach: food/ammo stash risk, or stronger enemy flow into the base

#### Review
Good mechanic, but only if it stays simple. Full domino infection would be too much for this game right now.

#### First Slice
- any breached socket spawns an `interior breach alert`
- enemies inside the base suppress bed/table interaction and add an integrity drain

---

### 4. Weapon Sidegrades With Clear Combat Verbs
Priority: High
Fit: Excellent
Implementation Cost: Medium

#### What It Is
Weapons should not just differ by DPS, range, and windup. They should express different **verbs**.

Current roster:
- `Kitchen Knife`
- `Baseball Bat`
- `Pistol`
- `Shotgun`

Make them mechanically distinct in tactical purpose:
- knife: fast finisher / cheap recovery / maybe bonus on isolated targets
- bat: interrupt / knockback / anti-runner control
- pistol: precision / safe poke / best versus spitter
- shotgun: panic button / cone clear / anti-pack / anti-breach

#### Why It Works
`The Last Spell` leans heavily on weapon-defined playstyles. That maps very well to your current weapon-data architecture.

#### How To Apply It Here
Add one signature property per weapon:
- knife:
  - bonus damage to unalerted or single nearby enemy
  - or lower miss recovery than all others
- bat:
  - guaranteed attack-prep interrupt
  - or short stagger immunity break
- pistol:
  - weak-point bonus on fully winded shots
  - or lower heat than shotgun, but still some heat
- shotgun:
  - pellet spread + stronger close knockback
  - or structure-defense bonus when enemies cluster at sockets

#### Review
Very strong fit. This leverages existing systems rather than adding new UI burden.

#### First Slice
- implement one signature passive/verb per weapon
- surface it in weapon pickup text and HUD

---

### 5. Elite Bounties Instead of Pure Random Elite Surprises
Priority: High
Fit: Very Good
Implementation Cost: Medium

#### What It Is
Turn elite weapon-drop moments into partially forecasted **bounties**.

Current system:
- elite enemies can drop weapons with odds

Better system:
- some days announce a known elite somewhere
- killing it yields:
  - high weapon-drop chance
  - guaranteed bullets/parts
  - or a specific reward class

#### Why It Works
This makes elite encounters a route-planning decision instead of pure variance.
It also makes the current gold/amber weapon drop visuals much more meaningful.

#### How To Apply It Here
Add a daily bounty card:
- “Armed Spitter sighted at POI F”
- “Runner pack leader near POI B”

Reward rules:
- guaranteed resource cache
- weapon chance only if player does not already own that reward weapon
- duplicate converts to resources

#### Review
This is better than silently increasing random elite odds. It gives the player agency and supports the day-planning fantasy.

#### First Slice
- one bounty every 2-3 days
- one known elite marker on map
- fixed reward table with one rare weapon-drop chance

---

### 6. Prep Projects At Base
Priority: Medium
Fit: Good
Implementation Cost: Medium

#### What It Is
Give the player 1-night “projects” that convert resources into temporary or next-night advantages.

Examples:
- cook extra meal: gain bonus HP from sleep
- ammo sorting: faster reload on the next night
- brace door: one socket gets temporary armor
- sharpen blade / tune bat: next night weapon bonus

#### Why It Works
`This War of Mine` is strong because the shelter is not just storage. It is a place where constrained prep decisions happen.
You already have the bed and table. A small `Workbench` or `Projects Board` would deepen prep without demanding freeform building.

#### Review
Good fit, but not the first thing to build. This becomes excellent once route planning and heat are stronger.

#### First Slice
- add one simple project interaction near the table
- allow one project per day

---

### 7. Telegraph-Rich Specialist Enemies
Priority: Medium
Fit: Good
Implementation Cost: Medium

#### What It Is
Keep adding enemy variety, but bias toward **readable tells** over raw stat inflation.

The current game already has attack prep. Push it further:
- runners:
  - clearer charge tell
  - break off if shoved
- spitters:
  - visible windup arc / spit marker
  - easier to read than to tank
- elites:
  - larger silhouette
  - stronger attack tint / special audio / drop aura

#### Why It Works
This keeps combat fair as complexity grows. `Left 4 Dead` and `The Last Spell` both lean hard on role clarity.

#### Review
Good and necessary, but it supports the bigger systems above rather than replacing them.

#### First Slice
- stronger visual tell package for spitters and elites
- small projectile or target marker for ranged attacks

## Best Mechanics To Build Next
If you only do three, do these:

1. Threat heat / noise director
2. Stronger POI daily modifiers
3. Weapon sidegrades with explicit combat verbs

That combination gives the game:
- more replayability
- more route planning
- more weapon choice
- better day-phase tension

without exploding scope.

## Mechanics To Avoid Right Now
These sound attractive but are bad fits for the current stage:

### 1. Full farming / cooking sim
Too broad. `Food` should stay a concise prep resource for now.

### 2. Freeform building
Your socket model is one of the game’s best clarity wins. Keep it.

### 3. Large procedural maps
Current authored POI identity is a strength. Do not throw that away yet.

### 4. NPC survivor management
Adds UI and balancing overhead too early.

### 5. Permanent meta-progression
It would blur whether the core run is actually fun yet.

## Practical Application Plan

### Phase 1: High-Impact Low-Risk
- add `day_heat`
- add daily POI modifiers
- add one signature combat verb per weapon

### Phase 2: Mid-Depth Pressure
- add bounty elites
- add stronger spitter/elite telegraphs
- add breach interior consequences

### Phase 3: Longer-Term Depth
- add base prep projects
- add patrol behaviors
- add a fifth weapon only after the first four feel intentional

## Recommendation
Do not expand content breadth first.
The best next step is to make the current loop produce more distinct stories per day.

The strongest immediate milestone is:
- `day heat`
- `daily POI modifiers`
- `weapon sidegrade pass`

That is the smallest package that materially improves replayability and decision quality in the current prototype.

## Sources
- Valve, `Replayable Cooperative Game Design: Left 4 Dead` (GDC 2009 PDF): https://steamcdn-a.akamaihd.net/apps/valve/2009/GDC2009_ReplayableCooperativeGameDesign_Left4Dead.pdf
- `This War of Mine` on Steam: https://store.steampowered.com/app/282070/This_War_of_Mine/
- `Darkwood` on Steam: https://store.steampowered.com/app/274520/
- `The Last Spell` on Steam: https://store.steampowered.com/app/1105670/The_Last_Spell/
- `They Are Billions` on Steam: https://store.steampowered.com/app/644930/They_Are_Billions/

## Notes On Source Use
- The Steam sources are high-level product descriptions, not technical postmortems.
- The exact application recommendations in this report are design inferences based on those games plus the current `Home Survival` codebase and spec.
