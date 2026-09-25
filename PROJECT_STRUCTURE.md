# Project structure

Organize by responsibility. Keep gameplay behavior, scene node names, serialized
IDs, and Resource class names independent of folder organization.

| Directory | Contents |
| --- | --- |
| `characters/` | Player, enemy, NPC, and ambient actor implementations and their Godot assembly/visual scenes. Shared enemy bases live in `characters/enemies/base/`. |
| `items/` | Item/consumable Resource class scripts, stack runtime, and specific equipment presentation scenes. |
| `weapons/` | Weapon runtime, attack/moveset Resource classes, projectiles, and weapon presentation scenes. |
| `abilities/` | Generic ability foundation and Allomancy implementation, including shared mechanics, Iron, Steel, Pewter, and metal tethers. |
| `components/` | Reusable actor-agnostic health, damage, interaction, inventory, equipment, stats, and combat capabilities. |
| `systems/` | Session/application orchestration, dialogue schemas, intelligence, and physics adapters. The real application entry layer is `systems/session/playtest_shell.tscn`. |
| `autoload/` | Global coordinators and session/settings singletons. Autoload registration remains in `project.godot`; InventoryUI lives with its UI implementation. |
| `world/` | Levels, level navigation, interactables, pickup representations, props, building blocks, and ambient spawners. Hathsin is `world/levels/hathsin_pit/`. |
| `ui/` | HUD, inventory, dialogue, intelligence, menus, and shared UI helpers. |
| `data/` | Authored gameplay `.tres` definitions: items, weapons, powers, dialogue, rewards, creatures, intelligence, and physics materials. |
| `assets/` | Imported models, raw textures/icons/fonts, and rendering materials. |
| `dev/` | Retained test scenes, fixtures, test data, debug helpers, and offline tools. Some are dependencies of the current playable application; this directory is not automatically excluded from exports. |
| `docs/` | Authoring guides, milestone history, and the migration manifest. |

## Implementation, data, and art

- Implementation and Resource **class scripts** belong to their domain, e.g.
  `items/base/item_definition.gd` or `weapons/base/weapon_moveset.gd`.
- Authored Resource **instances** belong under `data/`, e.g.
  `data/weapons/sword/sword.tres` and `data/items/consumables/healing/medical_supplies.tres`.
- Godot assembly/presentation scenes stay beside their actor/item/weapon. They
  may contain gameplay capabilities; they are not interchangeable with raw models.
- Raw models go in `assets/3d/{characters,weapons,props,environment}/`.
  Texture files go in `assets/textures/`, icons in `assets/2d/icons/`, fonts in
  `assets/fonts/`, and rendering materials in `assets/materials/`.
- The mouse GLB's existing import settings extract texture companions beside the
  model in `assets/3d/characters/knight_mouse/`. Keep those importer-generated
  companions there. The original standalone textures remain in
  `assets/textures/characters/knight_mouse/`, with their original import identities.
- When audio content is added, use `assets/audio/{music,ambience,sfx,dialogue}/`
  as needed. No empty audio categories have been created.
- Physics materials are behavior data under `data/physics/`. Navigation meshes
  stay with their owning level; bake input fixtures live under `dev/data/navigation/`.

## Naming and reference safety

Use `snake_case` for new folders and filenames. Preserve existing class names,
node hierarchies, identity strings, and architectural names such as
`example_enemy`, `ranged_enemy`, and `playtest_shell` unless separately approved.

Move `.gd.uid` sidecars with scripts. Preserve asset `.import` settings and UIDs.
Update scene/resource references, literal load/preload paths, tool paths,
autoloads, the main scene setting, and current documentation when moving files.
Do not rely solely on UID resolution.

Keep `project.godot`, export configuration, `default_bus_layout.tres`, and project
metadata at the root. Leave the existing editor-support directories in place.
`.godot/` is generated cache, not a source-content destination.

The path/hash record for this migration is `docs/project_structure_migration.json`.
README conflict markers were deliberately preserved for separate resolution.
