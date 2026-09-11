# Vertical Allomancy greybox

Implemented in `C:/Users/CptSp/Documents/Codex/A Mist Born fangame`, integrated into the existing `scenes/main.tscn`. Run the normal main scene (F6 below means the in-game reset key, not the editor shortcut). Opening-blocker follow-up: gravity/jump and the Allomancy spatial parent were corrected; see TRAVERSAL_BLOCKER_FIX.md for diagnosis and the current retest sequence. Inventory, stats, combat, dialogue and enemy code remain unchanged.

## Files and authoring

- Modified `scenes/main.tscn`: instance the course at (45, 0, 0); move the existing Player spawn to (45, 0.95, 9). All original gameplay fixtures remain.
- Modified `scenes/prototype_environment.tscn`: 4 m opening in the east wall at z=8 connects the yard to the access bridge. Existing navigation remains limited to the old yard; no traversal navigation was baked.
- Added `scenes/traversal_course.tscn`: named platforms, standalone MetalTether instances, separate visible purple anchor markers, three loose objects, Start marker, catch floor.
- Added `scenes/greybox_block.tscn` and `scripts/greybox_block.gd`: small editor tool; `dimensions` updates box mesh and collision together, `tint` changes the greybox color. Shared normal-world physics material is reused.
- Added `scripts/traversal_course.gd`: failure-height recovery and F6 scene restart.
- Added this document. Godot generates script `.uid` sidecars.

Open the course scene to edit its modular blocks and anchors. Block positions are slab centers; surface height is position.y + dimensions.y / 2. Move or resize a block using its position and exported dimensions, not mesh-only scaling. Anchor Area3D instances are independent from their named Marker siblings; move the marker too if you want its visible cue to follow an edited volume. Their existing sphere collision resource is local to each scene instance. No final art or targeting UI was added.

## Dimensions and topology

Coordinates below are course-local (add 45 to x for main-scene world coordinates). Slabs are 1 m thick unless stated otherwise. Course platform footprint is approximately 38 x 45 m, excluding the access bridge and 66 x 68 m catch floor. The route rises 25 m.

| Station | Center x,z | Surface y | Width x depth | Transition |
| --- | --- | --- | --- | --- |
| 01 Runway | 0, 5 | 0 | 6 x 14 | 2 m ordinary gap |
| 02 Jump landing | 0, -7 | 0 | 6 x 6 | 3 m gap, 6 m rise to first roof |
| 03 First roof | 0, -17 | 6 | 8 x 8 | Turn +X; 20 m gap, 2 m rise |
| 04 Arc landing | 29, -17 | 8 | 10 x 8 | Turn +Z; 4 m gap |
| 05 Loose deck | 29, -4 | 8 | 10 x 10 | 5 m gap, 8 m rise |
| 06 Ascent | 29, 10 | 16 | 8 x 8 | Safe branch or direct shortcut |
| 07 Safe step | 18, 19 | 20 | 7 x 7 | 4 m rise, then 5 m rise to finish |
| 08 Destination | 4, 10 | 25 | 10 x 10 | End |

The safe branch has approximately 3.8 m and 5.5 m nearest-corner planar gaps and an extra landing/anchor. The direct branch crosses 16 m edge-to-edge and rises 9 m. Main-route anchor center spacings are approximately 3.6 / 30.0 / 15.5 / 14.6 / 7.1 / 19 / 18.2 m; each intended next anchor is within the existing 30 m range from its preceding launch station. A2 to A3's center spacing is close to the limit; the Player launches ahead of A2.

Landing stripes on station 04 at local x=25,29,33 mark SHORT/CENTER/LONG. Its far edge exposes overshoot. The deck has a 0.6 m end curb and 2 m side stop; objects can still escape. Airspace above the slabs is open, so releasing or redirecting motion is observable.

## Metal topology

Eight new ANCHORED tethers use the existing `metal_tether.tscn` and its independent 0.8 m sphere volume. Purple visible bars are sibling MeshInstance3Ds without world collision, so they do not obstruct the targeting ray.

| Anchor | Local position x,y,z | Purpose |
| --- | --- | --- |
| A1 Lift | 0,11,-14 | Upward Pull from mundane landing |
| A2 Push heel | -2,7,-17 | Jump past it, look back/down, Push across long gap |
| A3 Arc catch | 27,14,-20 | Pull-assisted arc and release |
| A4 Redirect | 31,14,-5 | Sideways redirection toward loose deck |
| A5 Ascent | 29,22,7 | Strong 8 m ascent |
| A6 Chain heel | 30,15,8 | Below/behind launch reference on station 06 |
| A7 Safe | 18,26,19 | Additional landing and slower branch |
| A8 Finish | 4,31,10 | Final upward Pull; direct shortcut target |

Three existing loose-body scene instances: LIGHT at (26,8.4,-6), MEDIUM at (30,8.6,-5), HEAVY at (31,16.7,11). LIGHT and MEDIUM are on station 05 to Pull inward, reposition, and Push outward using generic physics. HEAVY on station 06 offers a movable launch reference beside the fixed A6 comparison. No object is required as a puzzle key, and no bespoke success condition is scripted. The original yard retains its original tethers and directional cart.

## Exact manual route

1. Start facing -Z. Walk, then Shift-sprint along 01. Space-jump the 2 m gap to 02 without using powers. Compare walk/sprint and jump height.
2. From 02, aim up toward A1 and hold C. Repeat with sprint + jump + C; release while approaching the 6 m first roof. Check that forward velocity persists.
3. On 03 turn right (+X). Jump, look back/down at A2 and hold F briefly, then release; turn toward A3 across the 20 m gap. Use C for correction. Observe SHORT/CENTER/LONG landing bands and overshoot. Compare release timing without changing tuning.
4. Pull toward A3, release, then turn +Z and Pull A4 to redirect onto 05. Repeat the transition in flight to judge continuous redirection and target selection with multiple candidates visible.
5. On 05 aim separately at LIGHT and MEDIUM. Pull toward yourself, release, move around them, then Push. Compare object motion and Player reaction. Reposition freely; F6 restores escaped props. Loose interaction is optional experimentation, not a gate.
6. Aim up/+Z at A5; sprint, jump and Pull to 06 (16 m surface). Release above the lip. Compare HEAVY reaction there against ANCHORED A6; jump before pushing from a low reference to avoid ground traction masking the launch.
7. Safe route: from 06, jump and Push away from A6, release F, turn toward A7 (-X,+Z), then C. Land on 07, release and Pull A8 to 08. Judge Push-to-Pull continuity and targeting pressure around A5/A6/A7.
8. Repeat using shortcut: from 06, Push A6, release, turn left (-X) and Pull A8 directly. This skips 07 and requires stronger height/momentum management.
9. Reach the 25 m destination. Fall deliberately: crossing y=-5 teleports the existing Player to Start, zeroes velocity and resets view/target. The lower catch floor is at y=-7; recovery does not require waiting for contact. F6 reloads the full main scene, restoring all props and original fixture state. Close inventory/dialogue before using F6 if their UI consumes key input.
10. Repeat with T toggling debug off/on. Separate anchor bars remain visible with debug off. Aim near individual bars to test target competition; no cycling was added.

## Current tuning controls

| Parameter | Location | Current base |
| --- | --- | --- |
| Walk speed | Player / StatComponent / initial_base_values / MOVE_SPEED | 10 m/s; effective stats still apply |
| Sprint | Player / sprint_multiplier | 1.5 (15 m/s with base stats) |
| Jump | Player / jump_speed | 9.9 m/s |
| Gravity | Project Settings / Physics / 3D / Default Gravity (advanced settings) | explicit 19.6 m/s² |
| Ground acceleration/deceleration | Player / ground_traction | 12/s shared convergence law |
| Air control | Player / air_control_acceleration | 4 m/s² |
| Steel / Iron acceleration | resources/allomancy_tuning.tres | 30 / 30 m/s² |
| Range / half angle | same resource | 30 m / 45 degrees |
| LIGHT player/object response | same resource | 0.03 / 2 |
| MEDIUM response | same resource | 0.35 / 1 |
| HEAVY response | same resource | 0.85 / 0.25 |
| ANCHORED response | same resource | 1 / 0 |

All relevant values already have suitable controls; no new tuning system or air drag was added. Ground acceleration/deceleration intentionally share one existing control.

## Validation and limitations

Godot 4.7.2 headless editor import/parser and main-scene startup sanity were used; detailed traversal feel is for manual testing. No automated route completion or visual playtest is claimed. Geometry is a first authored hypothesis and may need anchor, landing or gap adjustments after play.

Following manual feedback, 9.9 m/s jump with 19.6 m/s² gravity gives approximately 2.5 m rise and 1.01 seconds of level-ground flight. At 15 m/s, that is approximately 15.2 m horizontal travel before additional air control. Height was preserved while airtime was reduced. The 20 m assisted gap lands 2 m higher, reducing ordinary-jump flight time; the 6/8/9 m rises also prevent mundane jumping from trivializing the route. Sustained air control can keep increasing horizontal speed, and sustained powers can permit route skips. These are observations to test, not blocked by artificial walls.

Falling restores Player position only, not props or inventory; F6 is a full fixture restart and discards current test-run state. No checkpoint, timer, completion trigger or save system exists. Loose props can leave the deck and remain lost until F6. New platforms are not NPC-navigable. Original NPCs/enemies/items remain in their yard, outside normal course detection distance. In-world instructional and route labels were removed; this document remains the detailed test reference.


