# Godot Best Practices

This repo should follow Godot's strengths:

- scenes own structure
- nodes own local behavior
- resources own tunable data
- signals own cross-node communication
- saves store reconstructable state, not transient runtime noise

## Core Rules

1. Author static structure in scenes first
- If a feature has stable layout, build it in `.tscn` instead of assembling it fully in code.
- Good examples in this repo:
  - `Boot.tscn`
  - `HUD.tscn`
  - `Game.tscn`
  - POI landmark shells and route blockers

2. Keep behavior attached to the node that owns it
- Player logic belongs on `Player`.
- Placeable logic belongs on `Placeable`.
- Fog logic belongs on `FogController`.
- Construction logic belongs on `ConstructionController`.
- Do not grow `Game.gd` into the owner of subsystem details that already have a better node home.

3. Prefer composition over deep inheritance
- Add child nodes for audio, detection, timers, effects, and helper areas.
- Prefer scene composition to long inheritance chains.
- Good examples:
  - `CombatAudio` as a child node
  - attack areas as child nodes
  - pause/menu panels authored into scenes

4. Prefer signals over polling and global tree scans
- Use signals for:
  - state changes
  - pickup collected
  - placeable changed
  - socket changed
  - menu actions
- Tree scans are acceptable for bounded local queries, but should not replace architecture.

5. Put gameplay tuning in resources or exported fields
- If a designer should tune it without rewriting code, it belongs in:
  - a `Resource`
  - an `@export` field
  - scene-authored properties
- Good fits:
  - enemy definitions
  - weapon definitions
  - placeable profiles
  - POI bonus tables
  - wave data

6. Save compact state and reconstruct the world
- Save only what is needed to rebuild runtime state:
  - player stats and inventory
  - run phase / wave / day
  - placeables and their persistent state
  - POI depletion and modifiers
  - fog reveal memory
- Do not save:
  - VFX state
  - transient timers unless gameplay-critical
  - one-frame UI state
  - runtime-only temporary objects that can be regenerated

7. Use controllers for orchestration, not ownership bloat
- A controller should coordinate subsystem behavior across nodes.
- A controller should not absorb every detail that a local node can own itself.
- Current repo examples:
  - `ConstructionController`
  - `FogController`

8. Keep `_process` and `_physics_process` narrow
- Continuous loops should only handle things that truly need per-frame updates:
  - movement
  - camera/fog tracking
  - build preview
  - live combat timing
- Use `Timer`, signals, and one-shot refresh paths instead of broad continuous orchestration.

9. Use groups intentionally
- Groups are good for bounded categories:
  - `scavenge_nodes`
  - `pickups`
  - `placeables`
  - `defense_sockets`
- Prefer local-scene queries over global ones when possible.
- Do not use groups as a substitute for explicit ownership.

10. Scene-local queries beat whole-tree queries
- When scanning or restoring state, scope to the active gameplay scene whenever possible.
- Avoid cross-run contamination from unrelated scene instances.

11. Access app-wide services through one helper path
- If a service is an autoload, do not recreate it from scene scripts.
- Use one shared helper or explicit injected reference for settings/save access.
- Avoid scattering raw `/root/...` lookups across gameplay code.

## Repo-Specific Rules

1. `Game.gd` should keep shrinking
- New subsystem behavior should not default into `Game.gd`.
- Prefer extracting:
  - POI/exploration controller logic
  - roaming/exploration orchestration
  - future power or dog systems

2. UI should be authored, not constructed ad hoc
- Static menus, pause overlays, and HUD structures belong in scenes.
- Runtime UI creation should be reserved for truly dynamic content.

3. POI identity should be data + scene driven
- POI fantasy should come from:
  - authored local scene shapes
  - tuned scavenge reward tables
  - tuned guard composition
- Avoid hardcoding POI-specific logic branches in generic systems unless the mechanic truly differs.

4. Construction should stay profile-driven
- New buildables should extend `PlaceableProfile` and authored scene data first.
- Avoid one-off placement rules hardcoded only for a single buildable unless they are promoted into general placement policy.

5. Audio should stay node-owned and bus-routed
- Positional SFX belong on scene nodes like player, zombie, socket, and placeable scenes.
- Sound routing should use dedicated buses such as `SFX`, not `Master` by default.
- Headless probes should avoid real playback while still recording sound ids for verification.

## Review Checklist

When reviewing a change, ask:

1. Should this structure have been authored in a scene instead of built in code?
2. Is this behavior attached to the right node?
3. Should this tuning live in a resource or exported field?
4. Could this communication be a signal instead of a global lookup?
5. Is this save data compact and reconstructable?
6. Did this make `Game.gd` larger when it should have made a subsystem more local?
7. Is the scene tree being used as composition, or is code fighting it?

## Preferred Direction

For this repo, the preferred long-term architecture is:

- `scene`
  - authored structure and composition
- `resource`
  - tunable content definitions
- `script`
  - node-local behavior
- `controller`
  - subsystem orchestration
- `save manager`
  - persistence and restore boundaries

If a new feature does not fit that split cleanly, stop and simplify it before implementation grows.
