# Home Survival MVP1 Design Spec

This document outlines the expansion from **MVP0** to **MVP1**.

MVP0 proved the core `scavenge -> defend` loop and established the systems MVP1 will build on:
- the base grid, sockets, and tactical construction layer
- POIs, loot tables, and run-time depletion
- Salvage / Parts / Food economy
- wave timing and run reset flow

MVP1 keeps those systems intact and adds three strategic layers on top:
- **Infrastructure Constraints**: power-limited automation and lighting
- **Companion Synergy**: the Dog as a logistical and tactical support unit
- **Tactical Persistence**: heirloom debris and a small permanent legacy choice

## 1. High-Level Goals
- **Strategic Allocation**: Shift from "build everything" to "choose what gets power and attention."
- **Logistical Relief**: Let the Dog reduce repetitive scavenging without replacing player exploration.
- **Visual History**: Use heirloom debris to make prior run outcomes visible in the next run.

## 1.1 MVP0 -> MVP1 Bridge
MVP1 should feel like a continuation of MVP0, not a separate game.

- **Construction**: MVP0 already has a tactical grid and barricades. MVP1 adds power constraints and new placeables to that same system.
- **Scavenging**: MVP0 already has POIs and loot tables. MVP1 adds the Dog as a helper that reuses those same POIs.
- **Defense**: MVP0 already has sockets and repair/strengthen loops. MVP1 adds heirloom persistence to those same sockets.
- **Run Flow**: MVP0 already has reset, sleep, and wave progression. MVP1 keeps that flow and layers long-term memory onto it.

## 2. New Systems

### 2.1 The Power Grid (System: `PowerManager`)
To prevent the player from flooding the map with automation, automated units now require power from the base interior.

- **The Generator**: Located in the base interior; it provides a fixed number of **Load Slots**.
- **Power Radius**: A visual circular overlay centered on the Generator, and later relays; automated defenses only function while inside powered cells.
- **Load Constraints**:
  - **Turrets**: Require 2 Load Slots.
  - **Floodlights**: Require 1 Load Slot (increases zombie visibility/reduces their speed).
- **Upgrade Path**: A new rare resource, `Battery`, is required to upgrade the Generator's total Load Slots.
- **Scope**: MVP1 power is a local base-network system, not a whole-map wiring simulator.
- **Placement Rule**: Automated placeables may be built while the player is in `PRE_WAVE`, but they only activate while powered. If a build cannot be powered by the current grid, it is allowed to sit dormant until power is added or it may be rejected by UI if the player prefers a hard warning.

### 2.2 The Companion (System: `DogAI`)
The Dog acts as a tactical extension of the player’s stamina and route planning.

- **Stats**:
  - **Dog Stamina**: Starts at `100`.
  - **Recovery**: Refilled to full by interacting with the dog at the base and consuming `1 Food`.
- **Costs**:
  - Dog actions consume stamina.
  - If stamina is exhausted, the dog cannot be commanded again until it recovers.
- **States**:
  - **Follow**: Default behavior; dog stays near the player.
  - **Scavenge**: Player sends the dog to a known (previously visited) POI. The dog returns after 60s with a modest haul sampled from that POI's baseline table.
  - **Lure (Night Only)**: Player commands the dog to a spot; the dog barks to draw aggro from zombies in a 5m radius for 8 seconds.
- **Rules**:
  - The Dog cannot scavenge an unvisited POI.
  - The Dog cannot use Lure while on a Scavenge trip.
  - Dog actions should feel useful, but not replace the player.

### 2.3 Grid-Based Construction (System: `PlacementManager`)
Construction already supports tactical placement on a grid, separate from fixed wall/door sockets. MVP1 extends that existing layer instead of introducing it.

- **Rules**:
  - Uses the existing `B` build mode and grid placement flow from MVP0/MVP0.5.
  - **Energy Cost**: `0` (Building is a mental/strategic act, not a physical drain).
  - **Resource Cost**: Consumes `Salvage` and `Parts`.
- **New Placeables**:
  - **Barricades**: Existing low-HP wooden blockers used to create funnels (Mazing).
  - **Spike Traps**: Existing floor traps that damage/slow zombies.
  - **Powered Placeables**: New MVP1 additions such as turrets and floodlights that plug into the power system.
- **Scope**: MVP1 extends the existing construction layer; it does not add player-built walls or freeform structural editing.

### 2.4 Map Fog
The larger map already uses home-anchored fog-of-war. MVP1 keeps that system and tunes it as the world becomes denser and more strategically layered.

- **Home Anchor**: Fog is centered on the home/base area, not on the player.
- **Readability Rule**: The local home band should remain clear, while the far map becomes progressively obscured.
- **Exploration Memory**: Areas the player has already visited remain revealed for the rest of the run.
- **Scope**: This remains a presentation layer for exploration and pacing, not a stealth or visibility simulation.

## 3. Updated Core Loop
The loop remains consistent with MVP0 but adds a "Strategic Allocation" layer during the evening.

1. **Day Prep (`PRE_WAVE`)**:
   - Player scavenges high-value `Parts` or `Medicine`.
   - Player commands the dog to scavenge a known POI for low-tier `Salvage` or `Food`.
2. **Evening (Construction)**:
   - Player uses the Grid System to place traps/barricades at `0` Energy cost.
   - Player manages the **Power Grid**, deciding which turrets to activate based on current Load Slots.
3. **Dinner**: Consumes `Food` to refill player/dog energy and start the wave.
4. **Night Defense (`ACTIVE_WAVE`)**:
   - Player uses the Dog's **Lure** ability to protect damaged sockets.
   - Zombies attack defenses; if a fortified socket is destroyed during a losing run, it can leave "Golden Debris" for the next run.
5. **Sleep**: Restore HP and advance to the next day.

## 4. Roguelite Persistence: Heirlooms
Failure (Run Loss) can trigger the "Heirloom System" to encourage the next attempt.

- **Golden Debris**: If a socket reached `fortified` tier in the previous run before breaking, it leaves a unique debris pile at that socket location in the next run.
- **Reconstruction**: Rebuilding a socket over Golden Debris costs `50%` fewer resources and grants a `+15% HP bonus` to that socket for the current run.
- **Legacy Perk**: Upon a full restart, the player can choose one permanent "Legacy Perk" from a small curated pool (for example `+10 Max Energy` or `Dog starts with a backpack`).
- **Scope**: Heirlooms are intentionally small and visual; they should not replace the main MVP1 progression loop.

## 5. Technical Specification Updates

### 5.1 New Data Resources
Add these IDs to the stable resource list:
- `battery`: Rare; used for Generator upgrades.
- `dog_stamina`: Floating point; managed by the `DogAI`.
- `load_slots`: Integer; tracking the current power draw.

### 5.2 Updated Script Boundaries
- **`PowerManager`**: New manager responsible for power radius overlap, slot math, and activation state.
- **`ConstructionController`**: Extends the current construction controller for powered placeables, placement validity, and ghost previews. If a later rename to `PlacementManager` happens, it should be a code-alignment pass rather than a design change.
- **`DogAI`**: New companion state machine for follow/scavenge/lure behavior. It should share pathing helpers with other actors, but it is not a zombie variant.

## 6. Implementation Order
1. **Dog v1.0**: Implement the `Follow` and `Scavenge` state machine using existing POI data.
2. **Powered Construction**: Extend the existing tactical grid and construction controller for powered placeables such as turrets and floodlights.
3. **Power v1.0**: Create the `PowerManager` and the visual radius effect for turrets and floodlights.
4. **Heirloom Logic**: Implement the persistence layer to detect, save, and restore "Golden Debris" positions between runs.
5. **Fog Tuning**: Tune the existing home-anchored fog and exploration memory against the denser MVP1 map.

## 7. Out of Scope for MVP1
- Player-built walls or freeform base architecture
- Full generator wiring simulation across the whole map
- Companion combat as a primary damage source
- Large meta-progression trees
- Multi-dog management
