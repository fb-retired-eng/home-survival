# Construction System Plan

## Summary
Add a controlled free-grid construction layer on top of the existing wall/door socket perimeter.

This system is meant for player-placed objects such as:
- barricades
- spike traps
- noise decoys
- future turrets like an auto machine gun

The perimeter sockets remain the backbone of base defense. Construction adds tactical freedom, not full sandbox wall building.

## Stage 0: Rules and Constraints
- Keep existing wall/door sockets as core perimeter.
- Add a separate controlled build grid for placeables.
- The placement grid is authored into the map, not inferred from all floor space.
- Building is day-only.
- No placement on POIs, bed, table, spawns, or reserved base circulation cells.
- Placeables are destructible, repairable, and removable.
- Placeables do not stack on the same cell by default unless a future profile explicitly allows it.

### Route Preservation
- Placement must preserve at least one valid route from each active wave lane to the base perimeter.
- Route validation is done on the construction grid / lane graph, not arbitrary full-physics checks.
- A valid route may include destructible player-built blockers such as barricades.
- Permanent sealing with no eventual enemy progression is forbidden.

### Turret Economy
- Turrets consume `bullets`.
- Turret bullets come from the shared player bullet pool.
- Turrets are never free-fire by default.
- `parts` and `salvage` gate turret construction.
- `bullets` gate turret operation.
- A later turret-control policy is required so the player can decide whether automation is allowed to spend shared bullets.

### Build Lifecycle
- Builds are atomic in the first version.
- Place, pay, and spawn immediately.
- No staged construction timers.
- No unfinished-building state in Stage 1.

## Stage 1: Grid Foundation and Feedback
- Add `ConstructionGrid`.
- Add `PlaceableProfile`.
- Add a generic `Placeable` base scene/script.
- Add build-mode preview ghost.
- Add occupancy validation.
- Add reserved-cell visualization.
- Add a run-state container for placed objects.

### Stage 1 Run State
- placed this run
- damaged this run
- dismantled this run
- cleared on restart
- rebuilt fresh on new run

### Stage 1 Readability
- green preview for valid cells
- red preview for invalid cells
- footprint visualization
- reserved-cell visualization
- short invalid reason text when practical:
  - `Blocked`
  - `Reserved`
  - `Would seal route`
  - `Too close`

### Stage 1 Controls
- `B` enter/exit build mode
- `Q/E` cycle buildables later
- place/cancel input later

## Stage 2: First Placeable - Barricade
- Cheap barrier.
- Blocks movement.
- Moderate HP.
- Repair and dismantle supported.

### Minimum AI Rule
- If a valid alternate route exists within the lane/path graph, enemies reroute.
- If no valid alternate route exists, enemies attack the blocking barricade.
- Enemies must not stall forever in indecision.

## Stage 3: Broader Enemy Integration
- Better target priority across multiple placeables.
- Better fallback rules when multiple obstacles exist.
- Anti-stall behavior.
- Lane pressure remains directed at the base.

## Stage 4: Second Placeable - Spike Trap
- Non-blocking damage object.
- Limited durability or charges.
- Good for doors and choke points.
- Does not stack on occupied cells by default.

## Stage 5: Economy and UX Pass
- Compact build HUD.
- Cost display.
- Selected build description.
- Repair and dismantle actions.
- Partial refund rules.

### Scope Control
- Placeable upgrades are deferred.
- First pass supports build, repair, and dismantle only.

## Stage 6: Utility Placeable
- Best first utility object: `Noise Decoy`.
- Fits the existing firearm-noise and alert systems.

## Stage 7: Turret Framework
- Add turret fields to `PlaceableProfile`:
  - `fire_range`
  - `fire_arc`
  - `fire_interval`
  - `target_mode`
  - `bullet_cost_per_shot`
  - `burst_count`
  - `burst_spacing`
  - `reload_time`
  - `line_of_fire_required`
- Turrets consume bullets from the shared player pool.

## Stage 8: Auto Machine Gun
- Expensive in `parts`.
- Consumes shared `bullets`.
- Moderate range.
- Limited arc.
- Vulnerable HP.
- Supports a lane, does not replace the player.

## Stage 9: Review and Tuning
After every stage:
- headless validation
- targeted runtime probes
- picky review
- fixes
- rerun probes

Key tuning areas:
- barricade HP vs cost
- anti-route-seal validation
- trap efficiency
- build-mode clarity
- turret bullet hunger
- player freedom vs exploit potential

## Current Stage
Started:
- Stage 0 rule documentation
- Stage 1 foundation scaffolding
- Stage 2 barricade slice

Not started yet:
- spike trap
- utility placeables
- turret framework
- broader lane-graph validation beyond the current door-route guard

Implemented:
- larger bounded construction grid with a local buildable band around the home
- build-mode preview and placement
- barricade placement, repair, dismantle, and occupancy refresh
- trap-prevention guard against sealing the player in
