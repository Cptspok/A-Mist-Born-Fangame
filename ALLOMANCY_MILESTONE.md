# Allomancy metal tether / Push-Pull foundation

Actual project: C:/Users/CptSp/Documents/Codex/A Mist Born fangame.

## Editor workflow

1. Place/reuse any visual building, beam or prop normally. Imported GLB assets need no metadata or mesh changes.
2. Instance scenes/metal_tether.tscn under that object or anywhere appropriate in the level. A tether is an Area3D with a CollisionShape3D child, on dedicated physics layer 5 (Metal Tether).
3. Enable Editable Children on the instance, select CollisionShape3D, and configure a BoxShape3D or SphereShape3D. Make the Shape Resource unique when changing only one editor instance. Change Shape dimensions rather than scaling a rigid physics body. Move/rotate the tether or shape independently of the visual mesh.
4. Set enabled and allomancy_class on the tether root. Its same region is usable by both powers.
5. Optionally set physical_owner_path to the associated RigidBody3D. It may be elsewhere in the hierarchy; it is not inferred from mesh names. Empty means no movable-object reaction.
6. Ordinary rigid owners need no additional response script. For a cart, add a Node with scripts/allomancy_physical_response.gd, set its body_path (defaults to parent), mode DIRECTIONAL, preferred_local_axis and lateral_response. One response component per owner.
7. Run, aim at the tether, and hold Steel/Iron. Toggle development volumes with T.

Geometry and response are independent. Two instances of the same visual model may have different tether children, or none. Tether shape Resources are local-to-scene at runtime; use Make Unique for independently authored editor dimensions. Reusable test body scenes provide examples of owner paths and directional setup.

## Central tuning

Allomancy on Player references resources/allomancy_tuning.tres.

| Class | Player multiplier | Object multiplier |
|---|---:|---:|
| LIGHT | 0.03 | 2.0 |
| MEDIUM | 0.35 | 1.0 |
| HEAVY | 0.85 | 0.25 |
| ANCHORED | 1.0 | 0.0 |

Each Vector2 stores (player, object). ANCHORED always suppresses object reaction. Classes are gameplay responses, not kilograms.
Steel and Iron each default to 30 units/second squared, range 30, camera half-angle 45 degrees. Response is constant within range. Edit the central Resource for balance; individual tethers carry no duplicated strengths. Keep class multiplier values nonnegative for intended behavior.

Future Player strength/range modifiers can feed this central tuning/ability boundary without changing tether geometry or physical-owner response. No stat identifiers, reserves or skill restrictions were added now. Steel/Iron are unlimited.

## Responsibilities and targeting

- MetalTetherComponent declares the region, enabled state, class and optional owner. target_point isolates target geometry.
- Box targeting clamps the querying position into the shape's local bounds; sphere targeting clamps to its radius. This is a closest reasonable surface point for outside queries. Other Shape3D types fall back to the shape center. No mesh vertices are read.
- AllomancyTargeting owns a range Area3D and maintains candidates using area_entered/area_exited. Only nearby overlaps are evaluated each Player physics step. No global scans.
- Candidates must be enabled, in range, within the camera cone, and visible through a world-layer physics ray. Crosshair alignment dominates scoring, with a small distance preference. Player and the target's own rigid body are excluded from that ray to avoid self-occlusion; unrelated world bodies still block it.
- SteelPush and IronPull are separate numerical behaviors. AllomancyController reads semantic input and gives both the shared selected tether.
- AllomancyPhysicalResponse handles only the object's optional directional restriction.
- PlayerController integrates external acceleration, ordinary movement, gravity and collision response.

Do not place a static target fully buried behind world collision if it should be visible; put its volume at the accessible surface. No targeting through walls was added. Selection is generous and automatic, not a final lock-on UX. Inside a volume, or within 0.1 unit of the target point, force is skipped to avoid an undefined direction.

## Forces and momentum

Let d = normalize(target_point - Player.position).

Iron:
- player acceleration = +d * iron_strength * player_multiplier
- object acceleration = -d * iron_strength * object_multiplier

Steel:
- player acceleration = -d * steel_strength * player_multiplier
- object acceleration = +d * steel_strength * object_multiplier

The Player emits external_motion_requested during its physics update. The controller adds forces through add_external_acceleration, and the Player integrates acceleration * delta once before move_and_slide. Neither power assigns a target velocity or position. Holding both powers applies both contributions; with equal strengths they cancel.

The Player uses one actual CharacterBody3D velocity. Grounded horizontal motion converges smoothly toward stat-driven WASD speed (10 unmodified), with the same traction regardless of velocity source. In the air, existing velocity is preserved without any channel transfer. External acceleration is added once per physics tick; move_and_slide supplies the next collision-resolved velocity. See PLAYER_TRACTION_CORRECTION.md for the correction and tests.

New small movement tuning:
- jump_speed = 7, semantic jump action.
- air_control_acceleration = 4: optional additive steering while airborne.
- ground_traction = 12 (inverse seconds): shared horizontal input response/braking while grounded. No ground traction in air.
- gravity remains the existing project gravity throughout force application.

Releasing a power stops new acceleration, without clearing momentum. Releasing WASD in air also retains velocity. Air has no automatic drag. Ground friction, wall/floor collisions and the existing explicit gameplay-lock velocity reset remain legitimate reasons momentum can change. Space advances dialogue while locked and jumps only during gameplay.

RigidBody response uses apply_central_force(acceleration * body.mass), allowing the engine to integrate over time while compensating literal mass. Class multipliers, not kilograms, determine acceleration. Sleeping owners are awakened; frozen owners do not move. No force-at-offset torque is applied.

For DIRECTIONAL:
axis = normalized(body.global_basis * preferred_local_axis)
parallel = axis * acceleration.dot(axis)
object_acceleration = parallel + (acceleration - parallel) * lateral_response

The cart defaults to local -Z and lateral 0.15. This includes vertical perpendicular response. A zero axis falls back to free response. Only the object reaction is projected: the player's force remains along the original player-to-tether direction.

## Debug and test controls

| InputMap action | Temporary binding |
|---|---|
| steel_push | F held |
| iron_pull | C held |
| jump | Space |
| toggle_allomancy_debug | T |

Bindings are in project.godot, not inside ability code. Existing Q/R ability hooks and mouse combat actions remain.
Player/Allomancy.debug_enabled defaults true. Nearby volume wireframes and labels are class-colored: green Light, blue Medium, orange Heavy, purple Anchored. Selected tether is yellow, with an asterisk and a Player-to-target direction line. A small HUD label identifies selected metal and bindings. Depth-tested geometry is development visualization, not final blue-line VFX. Turning debug off disables its frame updates; normal spatial targeting continues. Editor shape gizmos support volume placement without runtime debug.

Test fixtures are under Main/AllomancyFixtures:
- OverheadAnchor: (-7, 6, 0), fixed primitive beam, ANCHORED.
- RedirectAnchor: (-2, 7, 2), second fixed beam for curved trajectories.
- LightObject: (-8, 0.4, -1).
- MediumObject: (-5, 0.6, -1).
- HeavyObject: (-2, 0.7, -1).
- DirectionalCart: (3, 0.6, 2), local -Z travel axis.

They are separate from the visual environment and existing inventory pickups. Loose objects are reusable primitive RigidBody scenes, not inventory items. The cart/props lock angular axes and share the normal movable-prop PhysicsMaterial (friction 0.65, zero bounce), with explicit Replace linear damping 0.15. The floor/architecture use the shared normal world surface material (friction 0.8). See WORLD_PHYSICS_BASELINE.md for the native contact convention. No wheels, torque or damage mechanics were added. Existing enemies remain active in the main environment.

## Exact manual tests

Start facing north from the usual Player spawn. Approach the fixtures and aim until the HUD names the intended target. Compare loose-body tests from similar distances/angles and reset the scene between trials.

A. Hold W, press Space, aim toward OverheadAnchor and hold C: forward movement continues as upward/toward-anchor acceleration is added.
B. Release C and W while airborne: continue ballistically; do not stop. Gravity curves the trajectory.
C. Aim at an anchored beam, hold F: Player moves away; beam stays fixed.
D. Hold C instead: Player accelerates toward the beam. Aim at RedirectAnchor to redirect the next segment.
E. Aim at LightObject and hold F briefly: object moves strongly away, Player reaction is small.
F. Reset; hold C on LightObject: it comes toward Player strongly, with small Player reaction.
G. Repeat on MediumObject: both reactions are noticeable.
H. Repeat on HeavyObject: Player response is stronger, object response weaker.
I. Stand south/behind the cart (positive Z), aim at its tether and hold F for a short interval: cart travels toward local -Z.
J. Reset; stand east or west of cart at similar distance and hold F equally: lateral motion is much smaller.
K. Reset; push from a diagonal position: mixed parallel/lateral response. The Player reaction still follows the direct tether line.
L. In the editor, move a beam's MetalTether child to another surface location without moving its Mesh: runtime target follows the tether.
M. Make the tether's BoxShape Resource unique, enlarge its dimensions and rerun: debug volume and nearest-point selection expand accordingly.
N. Duplicate/reuse the beam visual, give each instance different tether transforms/shapes or remove one tether: each is independent.
O. Set a tether enabled=false: it ceases being selectable. Re-enable and it returns on the next target evaluation.
P. Reduce iron_acceleration below gravity, pull toward an overhead anchor while falling: fall slows but continues. Raise it above gravity: upward response can reverse falling. Restore tuning afterward.
Q. Alternate F/C holds, release, jump and steer through several anchors: no force-induced velocity reset. Distinguish intended collisions/ground drag/gameplay locks from airborne force release.

Also check: out-of-range targets and targets behind a world wall cannot be selected; T toggles only debug geometry; Inventory/dialogue lock disables forces and preserves existing controls. Sword combat, equipment stats and inventory world dropping remain available.

## Files

Added:
- scripts/metal_tether_component.gd
- scripts/allomancy_tuning.gd
- scripts/allomancy_targeting.gd
- scripts/allomancy_physical_response.gd
- scripts/steel_push.gd
- scripts/iron_pull.gd
- scripts/allomancy_controller.gd
- scripts/allomancy_debug.gd
- Generated Godot UID sidecars for those scripts.
- resources/allomancy_tuning.tres
- scenes/metal_tether.tscn
- scenes/allomancy_anchor.tscn
- scenes/allomancy_light.tscn, allomancy_medium.tscn, allomancy_heavy.tscn, allomancy_cart.tscn
- ALLOMANCY_MILESTONE.md

Modified for this milestone:
- scripts/player.gd
- scenes/player.tscn
- scenes/main.tscn
- project.godot

Earlier stats/equipment changes already present in the working tree were preserved. No imported art, enemy scripts, stat catalogue, inventory transaction logic, or navigation mesh was modified.

## Validation and known limitations

Godot 4.7.2 parser/import checks passed. Main-scene startup initially caught an indentation issue in the debug script; corrected, and the successful startup sanity run reported no errors. Detailed movement/physics and editor-placement testing is left to the user as requested. Temporary logs were removed.

This is intentionally unbalanced constant-force traversal in a small existing arena. There is no top-speed cap, falloff, resource consumption, target lock/hysteresis, animation/VFX polish, wheel simulation, torque, airborne drag, or object-inflicted damage. Long holds can produce high speed; collision behavior at extreme speeds needs the later movement pass. Debug visuals cover nearby spatial candidates only, not an entire large level. Runtime reassignment of physical_owner_path/body_path is not live-bound; configure links in the editor before running. Box/sphere shapes have precise region calculations; other shapes use center fallback.
