# Ashmarket urban district — Pass 2

Launch the project normally and choose **Urban District → Start**. **Play** still enters the original world. The new scene is `res://world/levels/urban_district/urban_district.tscn`; F6 also works, but the application menu is the recommended entry for pause/settings/retry flow.

## Layout and editing

The playable footprint is approximately 104 × 100 m, bounded by an irregular fortified perimeter. North is negative Z. The painted map governs the arrangement: broad east–west gate road, an open market slightly southwest of center, northern raised estate, and dense southern/eastern back streets. Thirty-one ordinary houses and two manor towers use one to three storeys. The cabin and manor hall are the only furnished, accessible interiors.

| Place | Approximate X / Z | Purpose |
| --- | --- | --- |
| Cabin | −31 / 31 | Sparse timber interior, bedroll, checkpoint, sword, medicine and mixed vial |
| Market statue | −15 / 3 | Main orientation landmark, clear central sightlines |
| Gate road | Z = 0 | Broad east–west controlled route; perimeter gates close the playable boundary |
| Manor hall | −8 / −35 | Baron, 3 m raised terrace, front and rear openings |
| Front manor stair | −8 / −21 | Broad guarded approach |
| Service stair | 11 / −40 | Eastern terrace exit and alternative approach |
| Low warehouse stair | −30 / 18 | Ordinary stair/gallery access to the adjacent low roof |
| Loading gallery | −9 / 16 | Public stair access, elevated market view |
| East service ladder | 36 / 8.6 | Existing ladder to a 3 m gallery and intelligence cache |
| High east gallery | 18 / 9.5 | 6 m Allomantic landing; roof metal above at about 10 m |

Back-street loops wrap around unequal building blocks. A fenced service court and narrow offsets break up the loops. Ordinary house doors are closed scenery. Selected southern roofs have mesh collision; the remaining roofs are scenery, not a continuous rooftop level. Iron/Steel helps reach higher galleries and roof anchors. The cabin exit faces south, away from the market.

The saved scene is directly editable. `Environment` holds architecture and props; `Gameplay` holds enemies, pickups, rest/checkpoint, metalwork and NPC; navigation and lighting have separate root groups. `Player`, `CentralHub/Spawn` and `TraversalCourse/Start` preserve the existing shell/death/fall contracts.

`res://dev/tools/build_urban_district.gd` is the offline authoring recipe. It instances source models and saves the scene/resources; it never runs in the shipped level. **Rerunning it replaces manual edits to this level, its navigation resource and its district data.** It leaves the source library untouched. Navigation is baked from the same selective collision geometry used to author the level, then excludes building/prop tops outside the estate. After manual collision/layout edits, update the recipe and regenerate the navigation rather than using the old bake.

## Existing gameplay reused

Twelve hostiles form separate local encounter groups. Heavy and crossbow enemies hold the market, gate mouths and estate approach. An archer covers the terrace with a level-local 25 m sensing/attack limit. Knife fighters occupy back streets; a heavy guards the warehouse court. These are placements and authored overrides of existing archetypes, not new factions or patrol systems. Same-encounter alerts retain their existing ranges; individual enemies can still independently acquire the player.

Iron fences, gate metal, signposts and gallery/roof rails use the current tether component. Four loose steel props sit around market cargo and back lanes. Fence collision belongs to the actual body and the tether shape fits its metalwork. Acquisition range, cone, selection and occlusion mechanics are unchanged. Source-model metallic materials alone are not treated as targets.

Mara, beside the cabin, uses the existing NPC/dialogue implementation to explain the square, collectors, galleries and bedroll. World pickups, inventory, weapons, reserve absorption, healing, rest, checkpoint and death/retry behavior remain existing implementations. Rest is not a new invulnerability or enemy-exclusion mechanic; do not assume a pursued player becomes safe merely by entering the cabin.

## Court scenario

The existing Court actor represents **Baron Darven Voss**, with district-local ID `ashmarket_voss`. His old Mini City resources remain unchanged. New data is under `res://data/intelligence/urban_district/`:

| Information | Sources | Result |
| --- | --- | --- |
| Collector's account | Eastern alley collector reward; discarded copy in western service court | Identity, portrait and profile |
| Sealed delivery order | Market sergeant reward; gate dispatch by eastern cargo | Location dossier and manor map marker |
| Watchman's private notes | East service gallery; copy in manor hall | Tactical dossier |

The three clues are independent. Duplicate copies share a clue ID, so they do not create duplicate progression. No clue gates the manor or the target. Killing the target first, finding clues later, or collecting all information first uses the existing knowledge/status rules. The authored schematic has three regions: cabin/back streets, market/gate road and northern estate; it is not a live spatial map. The level switches to this catalog on entry and restores the previous catalog on exit, including shell retries.

Enemy reward resources live under `res://data/enemies/rewards/urban_district/` and reference these clues.

## Assembly, collision and presentation

Plaster/timber and uneven-brick walls, closed door leaves, timber ledges, tiled roofs, chimneys, balconies, exterior stairs, fences and wagons come from the imported architecture library. Crates, barrels, statues, columns, shelves, chests and braziers use the supplied prop library. Models/textures remain referenced in `dev/Test_Environement`; they are not copied or modified. Ground paving uses shared imported meshes in MultiMeshes.

Ordinary houses use solid exterior-shell collision. Cabin walls have a 2 m entrance gap; manor walls have 6 m front/rear gaps. Stairs use smooth ramp collision. Selected roofs use shared triangle shapes; small decorative details have no collision. Ground and manor routes have a dedicated baked navigation mesh. Six offline route checks cover the cabin, both gate roads, manor entrance, service exit and east back streets. Roof routes are player traversal, not enemy navigation.

Overcast ambient light and a shadowed directional light keep alleys readable. Braziers have warm local lights. Lighting, roof seams and prop placement are an initial assembly pass rather than final art polish.

## Limits and manual checks

This pass does not add civilian crowds, patrols, opening ordinary house doors, save-game persistence or new combat behavior. Existing generic pickup/reward visuals remain placeholders. The outer gates are boundaries, not travel transitions. No detailed graphical playthrough or performance benchmark was run; check module joins, scaled roof silhouettes, gallery clearances and lighting in the editor/game.

- Start from the menu; inspect cabin sparseness, equipment pickup and Mara's dialogue.
- Take injury/Pewter Debt, use medicine, rest, then die and confirm cabin checkpoint recovery.
- Walk both gate roads and the southern/eastern loops; check narrow corners and perimeter closure.
- Fight local groups and verify distant encounters do not alert solely from shared encounter IDs.
- Check enemy movement up the front stair, through the manor hall and down the service stair.
- Try loading stairs, the low warehouse roof, the east ladder, gallery jumps/drops and high roof Allomancy.
- Acquire fences/rails/signposts above and below, test corner occlusion and manipulate loose steel.
- Collect identity/location/tactics in different orders; defeat Voss before and after discovery; inspect Court status/map.
- Test pause, inventory, restart, death/retry, and return to Main Menu → Play to verify original-world behavior.

Validation entry points, when needed: `--headless --path <project> --script res://dev/tools/build_urban_district.gd` authors/bakes/checks geometry; `--headless --path <project> --script res://dev/tools/check_urban_district.gd` performs one short shell startup and catalog-restoration check. Do not substitute these for the manual traversal/art pass.

Implementation validation: all six offline navigation checks and the single startup/exit sanity check passed. The engine also reported its certificate-store warning and resource-leak warnings during shutdown. The sanity helper now allows queued level deletion to flush before quitting; it was not launched again, respecting the single-startup limit. Detailed visual assembly, combat balance, traversal feel and performance still require the manual pass above.
