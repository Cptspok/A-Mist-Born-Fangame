# Allomancy metal tether / Push-Pull foundation

Actual project: C:/Users/CptSp/Documents/Codex/A Mist Born fangame.

## Editor workflow

1. Place/reuse any visual building, beam or prop normally. Imported GLB assets need no metadata or mesh changes.
2. Instance scenes/metal_tether.tscn under that object or anywhere appropriate in the level. A tether is an Area3D with a CollisionShape3D child, on dedicated physics layer 5 (Metal Tether).
3. Enable Editable Children on the instance, select CollisionShape3D, and configure a BoxShape3D or SphereShape3D. Make the Shape Resource unique when changing only one editor instance. Change Shape dimensions rather than scaling a rigid physics body. Move/rotate the tether or shape independently of the visual mesh.
4. Set enabled and allomancy_class on the tether root. Its same region is usable by both powers.
5. Optionally set physical_owner_path to the associated PhysicsBody3D (rigid body, character carrier, or static fixture). It may be elsewhere in the hierarchy; it is not inferred from mesh names. Empty means no movable-object reaction. Character carriers implement the shared PhysicalForceResponse force/impulse contract; static/ANCHORED fixtures remain immovable.
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

## World metal & carried metal v0.1

Implemented directly in the existing project. The generic tether already inherited
parent transforms, used its own world-space volume, and supported multiple independent
candidates. Its rigid-only owner type was widened to PhysicsBody3D in the component
and interaction evaluator. No new tether class or targeting algorithm was added.

- `example_enemy_visual.tscn`: primitive head, torso, arms and legs; bright, low-roughness
  steel short sword and shield. SwordTether and ShieldTether sit under their equipment
  mesh, each resolving `../../../..` through the visual instance and VisualRoot to the
  enemy root. Both use MEDIUM response; neither equipment mesh is a separate body.
- `ranged_enemy_visual.tscn`: cloth humanoid, wooden bow and string, leather belt pouch
  with three exposed metallic coin discs. Only CoinPouchTether exists, with the same
  carrier path and MEDIUM response. Coins are static visual details, not inventory.
- `enemy.gd` / `enemy_movement.gd`: generic force and impulse entry points used by
  PhysicalForceResponse. Force accumulates once, integrates F/m * dt, and contributes
  momentum alongside navigation intent before move_and_slide. Contact normals remove
  inward momentum; ground drag dissipates horizontal motion. Vertical movement keeps
  the existing gravity integration. Mass defaults to 2 gameplay units, drag to 4 m/s².
  Locks clear pending momentum; death clears it and disables carried tethers. AI state,
  destinations, sensing, attack logic and damage rules are unchanged.
- `main.tscn`: replaces RedirectAnchor with `world_metal_signpost.tscn` at (-11.8,0,2),
  a timber post/sign with anchored steel bracket. Replaces LightObject with
  `world_loose_steel.tscn` at (-8,0.4,-1), a loose LIGHT steel bar. Adds
  `wooden_practice_dummy.tscn` at (11.8,0,-8), a non-metal comparison prop without a
  tether or damage/loot behavior. Static additions sit at the navigation perimeter
  so this pass does not change the baked navigation mesh. Other abstract fixtures remain.
- Playground and Allomancy Trial scenes/fixtures are unchanged. Existing main-scene
  edits, including the player spawn at (45,0.95,9), remain intact.

One selected tether is passed to one Steel/Iron application per physics step. Sharing
an owner does not duplicate force. The existing broad aim cone may switch between
sword and shield when they overlap in screen space, especially at distance; no cycling
or target hysteresis was added. Existing visibility ignores the physical owner's
collider, so carried metal may be selected through its carrier, as with rigid props.
Debug T remains available; no new floating affordance labels were added.

Design rules: free Steel/Iron remains systemic physical Allomancy, constrained to the
Allomancer-to-metal axis, never arbitrary-direction telekinesis. Carried metal makes
its carrier physically vulnerable. Diegetic shapes/materials should increasingly
communicate interaction. Future Coinshot or Iron-shard techniques may be authored/faked
abilities rather than simulations of free Allomancy; none are implemented here.

Validation: Godot 4.7.2 parser/import check and a temporary main-scene startup/ownership
sanity check passed (two melee tethers, one ranged tether, static bracket owner and
loose-bar owner). No persistent test suite. The sandbox emitted log-write and system
certificate-store warnings during startup; no script/resource errors were reported.
Detailed visual readability, force feel and navigation recovery remain manual checks.

Manual sequence (default bindings F = Steelpush, C = Ironpull, T = debug):
1. Run the existing main scene and travel from its preserved traversal spawn to Testing
   Zone around world origin. Start with T debug off; inspect the red sword/shield enemy
   near (4,0.9,-4), teal bow/pouch enemy near (5,0.9,9), and wooden dummy at the east edge.
2. Turn T on. Aim separately at sword and shield; verify the selected name changes.
   Hold C on the sword, release, then F on the shield. Repeat with the other item.
   The carrier should move and the equipment should stay attached.
3. Repeat while strafing. Pull into melee range, perform an existing sword attack,
   then Push away. Release and watch the enemy resume chase/attack/return behavior.
4. Inspect the wooden bow: it has no tether (the broad cone can still select the nearby
   pouch). Aim at the pouch, Pull toward melee range, then Push away; release and watch
   ranged AI reposition and resume firing. Confirm no coins enter inventory.
5. At the west edge, target the signpost's steel bracket and Push/Pull: the anchored
   fixture stays fixed and the player responds. Push/Pull the loose bar near (-8,0,-1).
   Compare with the untethered wooden dummy; switch debug off and repeat recognition.
6. Kill an enemy and verify carried tethers become unavailable during its existing fade.
   Check movement, ordinary melee/ranged combat, inventory and dialogue as usual.
7. Visit Playground and Allomancy Trial and confirm their existing fixtures/controls.

Future tasks only if playtesting warrants: target hysteresis/cycling for screen-space
overlap, force-mass/drag tuning, navigation recovery after displacement beyond the baked
map, and equipment animation. No disarm, breakage, loot, ragdoll or new damage mechanics.

## Semantic Combat Encounter v0.1

The north-east portion of Testing Zone is now a loading courtyard (roughly x=1..11,
z=3..-11). Two masonry warehouses frame a low loading platform. The existing sight
screen and east passage divider form approach corners; crates and a masonry pier
interrupt ranged LOS. A broad central ramp rises 0.8 m over 4 m, with ground-level
flanks on either side. Ordinary walking reaches the ranged position. Primitive stone,
rough timber, and bright low-roughness metal carry the visual language; no labels added.

Existing melee enemy starts at (5,0.9,-1.2), facing the approaching player once sensed.
Existing ranged enemy starts at (6.2,1.7,-9), on the loading platform. Both retain their
existing AI, navigation agents, equipment visuals, carried tethers and force response.
The approach brings the player into melee pressure before the platform firing position;
cover and the ramp offer different ways to close or retreat.

Six environmental opportunities / seven tethers:
- Reused timber signpost at (1.1,0,1.8), anchored bracket near the entrance.
- Chocked timber freight cart at (3,0,1), anchored iron wheel hardware on both sides.
  This new parked cart is static cover; the old movable directional cart remains in
  the western general testing area at (-9.5,0.6,-2.5).
- Steel beam at (10.1,3.6,-4.3), visibly carried by two timber posts over the east flank.
- Loading-platform rear rail at (5.9,1.6,-10.85).
- Flush drainage grate at (2.35,0.025,-6.1) in the western flank.
- Reused loose LIGHT steel bar at (8.3,0.25,-4.8), beside the loading approach.
The sign, cart and overhead structure are mixed material. Crates, masonry and timber
supports have no tethers. Loose steel keeps its existing generic physics; no ammunition,
projectile behavior, damage rules or pickups were added.

NPCs, world items, pickup access and general testing remain to the south-west. Existing
abstract force-class fixtures remain in that separate western testing area; the heavy
fixture moved to (-5.5,0.7,-3.5). The non-metal dummy remains available on the east edge.
Playground and Allomancy Trial geometry, fixtures and tuning are unchanged.

Navigation: new static bodies and the reused sign/dummy participate in navigation_static.
The existing NavigationRegion3D now references resources/testing_zone_navigation.tres,
baked from the complete Testing Zone source geometry. Its transform and the enemy
NavigationOrigin workaround are unchanged. A connectivity check exposed a real ramp
blocker: the old bake agent_max_climb=.2 rounded to zero against cell_height=.25.
Only the NavigationMesh bake allowance changed to .25 (one voxel); NavigationAgent
settings are untouched. The corrected navigation route connects (5,.5,2) through the
ramp to (6.2,1.25,-9). No manual rebake is required for this saved layout. After future
static edits, select the existing NavigationRegion3D and bake again with the same group.

Validation was limited to scene startup/resource loading, ownership checks, source-group
sanity and navigation-mesh connectivity while preparing the bake. Temporary preparation
scripts were removed. No gameplay scripts changed and no automated combat tests were
added. Godot reported sandbox log/certificate warnings, a one-time mesh parsing warning,
and existing voxel rounding warnings for bake height/radius. Detailed combat, visual
readability and displacement recovery require manual playtesting.

Exact manual route:
1. Start the existing Allomancy Trial session or run main.tscn. Use the existing return
   route to Testing Zone's east gate near (12,0,8). No spawn/menu changes were made.
2. Head west to the item/NPC area around (-6,0,6); equip the existing sword. Head east
   to (5,0,4), then north past the parked cart into the courtyard.
3. First fight with ordinary movement and sword. Use cart/crates/corners for LOS cover;
   approach the platform via the central ramp beginning near (5.9,0,-3.8).
4. Restart and repeat: Pull melee sword/shield while strafing, Push to create space,
   then Pull the ranged pouch from its platform. Release and watch both AIs recover.
5. Try the sign bracket to retreat, the eastern beam to change approach/height, and
   the platform rail to close distance. Compare the western grate's low force axis.
6. Manipulate the loose bar beside the ramp opportunistically; compare non-metal cover.
   Toggle T only to inspect ownership/selection, then repeat with debug off.
7. Walk both ground flanks and the ramp; check cover against actual ranged attacks.
   Return to NPC/item testing, then check the unchanged Playground and Allomancy Trial.

No new carried-metal or targeting blocker was established by the lightweight checks.
Known screen-space sword/shield switching remains; seven environmental tethers may
compete under pressure and need manual assessment. Off-nav displacement recovery remains
an existing future concern, not a newly observed gameplay failure. Separate future
system work is warranted only if playtests expose a blocker; no recovery, targeting,
cover, combat or force-system redesign was attempted.
