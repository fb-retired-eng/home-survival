# Home Survival MVP0 One-Pager

Implementation note: [`MVP0_SPEC.md`](MVP0_SPEC.md) is the source of truth for implementation details. This file remains the high-level product framing.

## Concept
A compact top-down survival-defense prototype where the player leaves a fragile base to scavenge nearby points of interest, returns with materials, strengthens walls and doors, then chooses when to sleep and trigger the next zombie wave.

This is the smallest version of the game's core fantasy:

`go out -> bring things back -> make home safer -> survive the next attack`

## Goal of MVP0
Prove that the core loop is fun before building the fuller suburban-home version.

The prototype should answer:
- Is scavenging for materials satisfying?
- Does returning home with resources feel meaningful?
- Do repairs and upgrades visibly improve survival chances?
- Is choosing when to sleep and trigger danger interesting?

## Player Experience
The tone should feel low-pressure and readable rather than stressful or simulation-heavy.

The player should feel like they are slowly stabilizing a vulnerable shelter by making repeated choices about:
- where to scavenge
- what to repair first
- when to spend resources
- when they are ready to trigger the next wave

## Core Loop
1. Start at base with full health and energy.
2. Travel to one of two nearby scavenging POIs.
3. Spend energy to search for resources and fight if needed.
4. Return to base.
5. Repair or reinforce defenses.
6. Sleep to restore energy and trigger the next wave.
7. Survive the wave.
8. Repeat until wave 3 is cleared.

## MVP0 Scope
### Included
- Desktop-first Godot 4 prototype
- Top-down 2D presentation
- One compact authored map
- Central abstract base
- 2 scavenging POIs
- 6 defense sockets around the base
- 4 wall sockets and 2 door sockets
- Unlimited inventory
- 3 resources: `Salvage`, `Parts`, `Medicine`
- One zombie type
- Sleep-triggered waves
- 3-wave win condition
- Player death loss condition
- Full restart

### Excluded
- Realistic house layout
- Neighborhood identity
- Personalized map generation
- Farming
- NPCs
- Save/load
- Turrets or traps
- Freeform building
- Multiple enemy types
- Real-time day/night cycle

## Economy
- `Salvage`: common repair resource, found in POIs and dropped in small amounts by zombies
- `Parts`: key upgrade resource, mainly from POIs
- `Medicine`: rare healing resource, found in POIs

Economy intent:
- zombies help sustain repairs
- scavenging is required for real advancement

## Defenses
The base starts with 6 fixed defense sockets:
- 4 walls
- 2 doors

Each socket has a simple gameplay arc:
- starts weak or damaged
- can be strengthened with resources
- visibly changes state
- buys the player more survivability during waves

Doors should be weaker but cheaper to strengthen so they become natural priority targets.

## Waves
- Sleeping starts a wave immediately.
- Wave 1 teaches the loop.
- Wave 2 increases pressure.
- Wave 3 is the final test.
- Win by surviving wave 3.

## Design Principles
- Prioritize readability over fidelity.
- Keep systems shallow but satisfying.
- Make choices come from scarcity and prioritization, not from real-time stress.
- Keep the prototype small enough to finish and tune quickly.

## Success Criteria
MVP0 is successful if:
- players understand the loop without explanation
- scavenging feels necessary
- upgrading the base feels rewarding
- sleeping feels like an intentional commitment to risk
- a full run fits into about 10-20 minutes
- the prototype is fun enough to justify building MVP1 around a real home parcel later
