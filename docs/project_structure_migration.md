# Structure migration record

Baseline: `d56fe805201d888ad1158a7a02d72bd4cd5e01af`; working tree was clean.
The complete source/destination map and original SHA-256 hashes are in
`project_structure_migration.json`. See `../PROJECT_STRUCTURE.md` for navigation.

- Moved 343 primary files and 213 UID/import sidecars in nine coherent groups.
- Retained all 603 original tracked files, including all models, standalone mouse
  textures, prototype environments, the shield, and the refill fixture.
- Preserved all 108 script UID sidecars and all 106 existing import identities
  and parameter sections. Godot regenerated location-dependent import cache paths.
- Compared every original text file against the baseline with only approved path
  substitutions applied (normalizing line endings for comparison). No gameplay,
  scene hierarchy, serialized tuning, class, or actor identity changes were made.
  Hathsin passed this same path-only comparison.
- Raw binary assets retain their original SHA-256 hashes.
- Startup remains `systems/session/playtest_shell.tscn`; autoload names remain
  unchanged. InventoryUI is registered from `ui/inventory/inventory_ui.gd`.
- Updated explicit scene/resource/script references, dynamic metal recipe paths,
  bake output/input paths, validation tool paths, and documentation path mentions.
- Removed only emptied former content directories and temporary migration scripts.
  The four existing editor-support directories remain untouched.

## Casing normalization

`Wooden_Shield.tres` became `wooden_shield.tres`; the six `P_*.glb` names became
`p_*.glb`; `SP_Wooden_Shield.png` became `sp_wooden_shield.png`;
`Butler-Free-Med.otf` became `butler_free_med.otf`; `Txt9.tres` became `txt9.tres`.
Hathsin's `Depths`, `Entrance`, `Quarters`, and `Shafts` filenames became lowercase.
Greybox texture color directories became lowercase. No semantic architectural
renames were performed.

## Validation

After each migration group, literal resource paths were checked for existence.
Final inspection found no stale moved source paths in current project source or
documentation (the historical map and generated editor cache intentionally retain
old-path records). Entry point, all autoload paths, and dynamic recipe destinations
were checked.

Godot 4.7.2 completed its import pass. Its initial cached lookup attempted old
autoload paths while rebuilding the filesystem cache; subsequent resource loading
and startup no longer reported those errors. All 238 moved GDScripts, scenes, and
text resources passed a resource-only load/parse audit. One minimal headless
application startup exited successfully, without script or missing-resource errors.
No combat/healing simulation, gameplay loops, or desktop control was performed.

Environment warnings remain: user-data/editor-cache access restrictions and an
unavailable system certificate store. These were not treated as gameplay issues.

The existing mouse GLB importer extracts three PNG companions beside the model.
Their newly generated PNG/import files are retained there; the original standalone
textures and their identities remain under `assets/textures/characters/knight_mouse/`.
Import behavior/settings were not changed to eliminate these companions.

## Review notes

Nothing in the approved migration remains blocked. Unreferenced-looking prototype
environments, six imported P-models, Wooden Shield, and the metal refill fixture
were deliberately retained; their gameplay roles are not decided by this migration.

README conflict markers and both conflicting text versions remain unresolved.
Only its startup path was updated. Resolve that conflict separately.

Manual review: reopen `project.godot`; inspect Hathsin subscenes and textures;
launch the existing menu into the hub/Mini City; inspect workshop inventory,
weapons, HUD, and Allomancy; exercise recovery/rest and the existing combat at your
convenience. This migration does not establish gameplay integration test coverage.
