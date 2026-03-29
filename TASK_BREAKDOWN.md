# MVP0 Task Breakdown

Implementation note: [`MVP0_SPEC.md`](MVP0_SPEC.md) is the current implementation source of truth. This file remains a milestone-oriented planning reference.

## Goal
Translate the MVP0 design into an execution sequence that can be implemented incrementally and tested after each step.

The target is a playable desktop-first Godot 4 prototype with this loop:

`scavenge -> return -> strengthen base -> sleep -> defend -> repeat`

## Milestone 1: Project Scaffold
### Objective
Set up the project so gameplay systems can be added cleanly.

### Tasks
- Create a new Godot 4 project for desktop.
- Set up input actions:
  - move up/down/left/right
  - attack
  - interact
  - use medicine if separate
- Create the initial folder structure for:
  - scenes
  - scripts
  - data
  - UI
  - placeholder art/assets
- Create the main game scene.
- Create a simple placeholder map with a central base area and surrounding play space.
- Add a basic camera setup.

### Done when
- The project runs.
- The player can be placed into the map.
- The main scene loads without errors.

## Milestone 2: Core Player Systems
### Objective
Make the game controllable and establish the player’s main stats.

### Tasks
- Implement top-down 8-direction movement.
- Add collision against map boundaries and obstacles.
- Implement player health.
- Implement player energy.
- Implement basic melee attack.
- Prevent attacking when energy is zero.
- Add simple hit feedback and death handling.
- Add item pickup support.

### Done when
- The player can move, attack, take damage, die, and collect pickups.
- Health and energy values update correctly.

## Milestone 3: HUD and Core Feedback
### Objective
Expose the game state clearly enough to playtest the loop.

### Tasks
- Add HUD elements for:
  - health
  - energy
  - wave number
  - salvage
  - parts
  - medicine
- Add an interaction prompt.
- Add temporary message text for:
  - not enough resources
  - too tired
  - wave started
  - wave cleared
  - strengthened
  - win/loss

### Done when
- The player can always tell current health, energy, resources, and interaction state.

## Milestone 4: Scavenging System
### Objective
Create the outbound progression loop.

### Tasks
- Create 2 authored POIs.
- Add searchable scavenging nodes to each POI.
- Implement search interaction time.
- Make searching consume energy.
- Add finite depletion per node.
- Add loot rewards using simple data-driven loot tables.
- Make POI A favor salvage and POI B favor parts.
- Add medicine as a rare scavenging reward.

### Done when
- The player can leave base, search nodes, spend energy, receive loot, and deplete nodes for the run.

## Milestone 5: Base Defense Sockets
### Objective
Create the home-improvement payoff.

### Tasks
- Create 6 fixed defense sockets around the base.
- Use:
  - 4 wall sockets
  - 2 door sockets
- Give each socket:
  - type
  - HP
  - damaged/reinforced state
  - strengthen cost
- Implement strengthen interaction at sockets.
- Use resource costs:
  - walls cost more than doors
  - reinforcement requires parts
- Add clear visual changes between weakened and reinforced states.

### Done when
- The player can spend resources at sockets and see the base become stronger.

## Milestone 6: Sleep and Run Flow
### Objective
Create the phase transition that drives the game loop.

### Tasks
- Add a sleep interaction point inside the base.
- Make sleep unavailable during active waves.
- Make sleeping:
  - restore full energy
  - increment/start the next wave
  - trigger wave-start UI feedback
- Track run progression across 3 waves.

### Done when
- The player can intentionally start the next defense phase by sleeping.

## Milestone 7: Zombie and Wave Systems
### Objective
Create the defense phase and core threat.

### Tasks
- Implement one zombie type.
- Add authored spawn points on 3 map edges.
- Implement simple zombie behavior:
  - move to assigned socket
  - attack socket
  - attack player if engaged or nearby after breach
- Spawn zombies only during waves.
- Configure waves:
  - wave 1: 4 zombies, 1 side
  - wave 2: 7 zombies, 2 sides
  - wave 3: 10 zombies, 2-3 sides
- Detect wave completion when all zombies are dead.
- Drop small salvage rewards on zombie death.

### Done when
- Sleeping starts a real wave, zombies pressure the base, and the wave ends cleanly when cleared.

## Milestone 8: Win, Loss, and Restart
### Objective
Close the run loop completely.

### Tasks
- Trigger loss on player death.
- Trigger win after wave 3 is cleared.
- Add win/loss UI.
- Add restart action.
- Fully reset:
  - player stats
  - resources
  - scavenging node depletion
  - socket states and HP
  - active zombies
  - current wave
  - UI state

### Done when
- A full run can end and cleanly restart without stale state.

## Milestone 9: Balancing Pass
### Objective
Tune the prototype so the intended loop is actually testable.

### Tasks
- Tune search energy cost.
- Tune attack energy cost.
- Tune socket HP and upgrade costs.
- Tune zombie damage and counts.
- Tune POI rewards.
- Check that zombie drops help sustain repairs but do not replace scavenging.
- Check that doors feel like important weak points.
- Check that a run lands around 10-20 minutes.

### Done when
- The game feels playable, understandable, and appropriately pressured.

## Suggested File Ownership
- `GameManager`
  - run state, win/loss, restart
- `WaveManager`
  - wave progression and zombie spawning
- `Player`
  - movement, combat, energy, health, inventory/resources
- `Zombie`
  - targeting, attacking, drops
- `DefenseSocket`
  - HP, strengthen logic, visual state
- `ScavengeNode`
  - search interaction, depletion, loot payout
- `HUD`
  - bars, prompts, messages

## Recommended Execution Order
1. Scaffold the project and base map.
2. Implement player movement, combat, and stats.
3. Add HUD and interaction prompts.
4. Add scavenging nodes and loot.
5. Add defense sockets and strengthening.
6. Add sleep-triggered wave flow.
7. Add zombies and wave progression.
8. Add win/loss and restart.
9. Tune balance and cleanup.

## Acceptance Checklist
- Player can complete a full run from start to finish.
- Scavenging is necessary to get parts.
- Zombie drops only meaningfully support repairs.
- Base strengthening visibly improves survivability.
- Sleeping is the only phase trigger.
- Wave 3 can be won with good play but not trivially.
- Restart returns the game to a fully clean state.
