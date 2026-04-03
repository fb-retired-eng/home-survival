# Home Survival MVP0.5 Spec

This document defines the bridge between **MVP0** and **MVP1**. MVP0.5 exists to make the current prototype feel shippable without adding new combat, construction, or meta-progression systems.

## Purpose
Add a reliable front-end and persistence layer so a player can:
- start a new game
- continue or load a run
- change settings
- save and resume a run cleanly

MVP0.5 is successful if the game feels like a usable product shell rather than a prototype that always starts from scratch.

## Implementation Status
The MVP0.5 foundation is now in place:
- boot flow and main menu shell
- persistent settings save/load
- slot-based run save/load
- construction, socket, POI, and fog-memory persistence
- autosave hooks at safe points
- pause-menu save, resume, and quit-to-menu flow
- authored Boot and HUD front-end scenes instead of procedural menu construction
- fullscreen/windowed settings applied through the active Godot window
- active-wave manual saves blocked by policy
- loading or continuing a slot no longer rewrites it on entry

## Scope

### In Scope
- boot flow
- main menu
- new game / continue / load game / settings / quit
- one fixed small number of save slots
- settings save
- run save and load
- construction persistence
- POI and fog-memory persistence
- pause-menu save / quit
- autosave at safe points
- save-file versioning

### Out of Scope
- cloud sync
- account login
- mid-wave save anywhere
- multiple campaigns
- full enemy state serialization
- Dog, Power, or Heirloom systems from MVP1
- new combat, weapon, or construction features

## Game Start Flow

1. **Boot**
- load settings
- detect save slots
- route to main menu

2. **Main Menu**
- `New Game`
- `Continue`
- `Load Game`
- `Settings`
- `Quit`

3. **New Game**
- create a fresh run state
- enter `Game.tscn`

4. **Continue / Load Game**
- select a save slot
- restore the run
- enter `Game.tscn`

5. **Settings**
- apply changes immediately where possible
- persist them separately from run data

## Save Model

Use two save layers:

### Settings Save
Persistent across all runs.
- volume
- fullscreen or window mode
- resolution
- keybindings if editable
- accessibility flags if needed

### Run Save
Per slot or per run.
- current day, wave, and phase
- player position, health, energy, inventory, weapon, and build mode state
- placed constructions and their HP / rotation / state
- defense socket state
- POI depletion and modifiers
- fog / exploration memory
- run flags and save version

Run persistence should be collected from the active game scene only.
- do not serialize by walking global groups across the whole tree
- save/load must not accidentally merge state from another live `Game` instance

## Save Rules
- version every save file
- reject or migrate incompatible versions
- treat the save file as the source of truth
- never partially apply a save
- keep settings independent from run data
- block manual save during `ACTIVE_WAVE`
- loading or continuing a save must be read-only until the player causes a new state change

## Construction Persistence
Construction is already active in MVP0, so it must persist.

Save for each placed object:
- `placeable_id`
- grid cell or world position
- rotation
- current HP
- trap or cooldown state if applicable

On load:
- rebuild the placeables
- restore HP and state
- re-register occupancy
- refresh build mode and interaction state

## Fog Persistence
Fog memory should survive save/load so exploration feels persistent.

Persist:
- revealed fog cells
- visited-area memory
- home anchor if required by the format

## Settings Persistence
Settings should be separate from run state and load before the main menu.

Persist:
- audio volumes
- display mode
- resolution
- input remaps if supported
- accessibility flags if needed

## Implementation Order
1. settings save/load
2. boot flow and main menu
3. save-file schema and versioning
4. run restore
5. construction restore
6. POI and fog restore
7. autosave
8. pause-menu save / quit

## Definition of Done
MVP0.5 is done when:
- a new player can start from a menu
- an existing player can continue or load a run
- settings persist independently
- the current run restores cleanly after reload
- construction and fog memory survive save/load
- the save system is stable enough to support MVP1
