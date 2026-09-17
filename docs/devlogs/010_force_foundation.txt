# Shared force foundation and Allomantic terminal response

This report supersedes the force/acceleration descriptions in earlier milestone reports. Geometry, gravity (19.6 m/s²), jump speed (9.9 m/s), ground traction (12/s), sprint (1.5), and air control (4 m/s²) were not retuned for this milestone.

## Responsibility and integration

- World physics owns gravity, collision resolution, contact/friction, native rigid-body mass and damping. CharacterBody locomotion supplies the existing contact traction approximation; it does not receive native RigidBody friction automatically.
- Movement motors own controlled walking/running and air input. The existing grounded exponential convergence is retained, including contact braking of external motion. It is not an airborne speed cap. Air input remains additive with no drag.
- Impulses own instantaneous events. Jump now submits `J = UP * jump_speed * player_mass`, giving the same immediate `delta_v = J/m = UP * jump_speed` as before. Generic impulses are not automatically mass-compensated; jump uses this conversion deliberately to retain its authored height.
- Continuous forces own Steel/Iron and future sustained abilities. They submit forces once per physics tick, not impulses and not force multiplied by delta.

`PhysicalForceResponse` is a small static composition adapter with `apply_force`, `apply_impulse`, `get_velocity`, `get_effective_mass`, and `get_world_position`. It dispatches to native RigidBody operations or a CharacterBody motor implementing `apply_external_force`, `apply_external_impulse`, and `get_effective_mass`. Only the Player motor is implemented now; NPC motors are deliberately untouched. A null/unsupported owner is immovable. Frozen rigid bodies accept no forces or impulses and report zero translational velocity.

Player physics order remains:

1. Ground locomotion/contact convergence, or additive airborne input.
2. Jump impulse, if grounded and requested.
3. World gravity acceleration: `v += gravity_vector * dt`.
4. Collect active ability forces through the existing signal.
5. Integrate once: `v += sum(external_force) / mass * dt`; clear the force accumulator.
6. `move_and_slide()` resolves collision, retaining the resulting velocity for the next step.

Impulses change the same actual velocity immediately by `J/m`. Gameplay locks retain their existing velocity-reset behavior, clear pending forces and reject force/impulse submissions while locked. The first-person camera, targeting parent fix and fall reset are retained.

Rigid bodies receive `apply_central_force(F)` and `apply_central_impulse(J)`; Godot integrates mass, gravity, contacts and damping. There is no manual rigid-body velocity integration or mass cancellation. The cart's existing response component filters generic force/impulse vectors into its preferred axis and reduced lateral component before native submission. MetalTether now only identifies its volume, class and physical owner; it no longer applies acceleration to that owner.

## Exact Allomancy law

The spatial interaction point is the independently authored tether volume center. Target selection still uses its existing volume-based targeting/LOS logic. Keeping the force axis through the volume center avoids a vanishing axis when a participant enters the target volume. Forces remain central; torque is not introduced.

```
toward = normalize(tether_volume_world_position - player_world_position)
d = toward for Iron, -toward for Steel       # intended Player force direction
v_relative = player_velocity - owner_velocity
s = dot(v_relative, d)
r = clamp(1 - s / terminal_speed, 0, 1)
F = d * base_force * r
Player force = F * class_player_coupling
Object force = -F * class_object_coupling
```

ANCHORED uses zero owner velocity and submits no object force even if an owner is assigned. Each movable owner's actual native velocity participates; a loose object already moving away during Steel reduces the shared interaction response. Motion opposing the intended relative direction gives `s < 0` and full force, not reduced force based on absolute speed. Perpendicular velocity contributes zero to the dot product.

The linear factor is continuous through terminal speed: force gradually reaches zero, while velocity is never clamped or rewritten. Its derivative has corners at 0 and terminal speed; there is no force discontinuity. No exponent was introduced. A faster body stays faster until world forces, contact or another input changes it. Holding a force does not guarantee a constant speed: gravity, moving targets, changing axes and damping influence actual motion.

For a directly upward fixed anchor with Player mass 1, the current 30 force exceeds 19.6 gravity at rest. As upward speed builds, reduction leads to a theoretical vertical equilibrium near `24 * (1 - 19.6/30) = 8.32 m/s` while that vertical geometry remains fixed. Gravity is not used by the force law and changing it never changes Steel/Iron tuning automatically.

All submitted interactions read actual participant velocity before the accumulated forces are integrated. Future simultaneous anchors therefore add low-speed force without multiplying the configured terminal speed. Ordinary finite-step integration can overshoot that response speed; there is intentionally no corrective velocity clamp. Current targeting still selects only one tether. Holding both F and C explicitly produces no Allomantic force, preserving the old cancellation convention; applying two unequal velocity-dependent opposite laws instead would have introduced braking.

## Tuning and classes

`resources/allomancy_tuning.tres` is the existing central resource:

| Setting | Initial value |
| --- | --- |
| steel_force / iron_force | 30 / 30 force units |
| steel_terminal_speed / iron_terminal_speed | 24 / 24 m/s relative speed |
| LIGHT coupling, Player/object | 0.03 / 2 |
| MEDIUM coupling | 0.35 / 1 |
| HEAVY coupling | 0.85 / 0.25 |
| ANCHORED coupling | 1 / 0 |
| Range / targeting half-angle | 30 m / 45 degrees, unchanged |

The old `steel_acceleration` and `iron_acceleration` resource keys were migrated to `steel_force` and `iron_force`. Player physical response mass is exported as `force_response_mass` on the Player, initially 1. Existing props already have native mass 1, so low-speed acceleration magnitudes are preserved at these defaults. Changing physical mass now changes acceleration under the same force. Class authoring stays unchanged and remains a separate force-coupling control, not a disguised kilogram value.

Action/reaction uses opposite directions with independently authored coupling strengths. It is a gameplay coupling model, not strict equal-magnitude Newtonian momentum conservation. At default mass 1 and response factor 1, LIGHT gives Player/object force magnitudes 0.9/60; MEDIUM 10.5/30; HEAVY 25.5/7.5; ANCHORED 30/0. The cart can further attenuate its received vector in its own response layer.

## Debug and startup results

T retains existing debug visualization and now shows actual velocity, last active power, Player-directed axis, signed projected relative speed, terminal value, factor, and submitted Player/object forces. Object force is shown after directional filtering. On release/no target/both buttons held, the next physics step shows no active interaction. Detailed force data is hidden when debug is off; the previous basic binding/target hint remains.

Godot 4.7.2 parser/import and normal headless startup passed. Temporary startup diagnostics inspected the unchanged A2/A3 obstacle from Player world position `(48, 8.5, -17)`:

| Along-axis relative speed | Factor | Force magnitude (ANCHORED) |
| --- | --- | --- |
| 0 | 1 | 30 |
| 12 | 0.5 | 15 |
| 22 | 0.0833 | 2.5 |
| 40 | 0 | 0; 40 m/s velocity retained |
| -24 | 1 | 30 |
| 15 perpendicular to axis | 1 | 30 |

At velocity `(35, 9.9, 0)`, aiming and activating Iron at A3 yielded projected relative speed 36.06, factor 0, and zero added force while leaving that velocity untouched. Releasing retained it. This verifies that the old extra high-speed burst is suppressed; it does not guarantee landing or redirection when already above terminal along that same axis. A genuinely different axis can still provide force.

The cart projected `(10, 0, 10)` to `(1.5, 0, 10)`, preserving its 0.15 lateral response. No dedicated test suite, route simulation or detailed playtest was added. Earlier diagnostic-only autoload-order trouble was corrected, and a debug child-before-parent initialization access was fixed before final startup validation.

## Exact manual retest sequence

1. Restart, enable T, and reach station 02 using the ordinary jump references. At rest aim up at A1 and hold C: initial factor should be near 1, falling as approach speed grows. Release C and observe momentum; use F6 between trials.
2. Repeat with sideways motion while aiming up. Compare axis-projected speed to total velocity. Then move away from A1 and Pull: expect full response while opposing motion, reversal, then diminishing response.
3. Land on station 03. Jump and aim back/down at A2; hold F briefly, observe decreasing factor, release. Existing velocity should persist without an Allomancy braking phase.
4. Repeat the full primary case: Shift-sprint toward the +X launch side, Space, F on A2, release F, turn to A3 and C. Watch the projected speed/factor before deciding how long to hold C. Already-fast approach should not receive another full-strength burst. Release over station 04. Do not expect the model to delete an existing overshoot.
5. Continue via A4 or use the old yard. Separately Push/Pull LIGHT, MEDIUM and HEAVY while watching both submitted forces. Pull a loose object toward you, release and Steelpush while it approaches: expect full opposing response. Push it away repeatedly: response should shrink as separation speed increases. Compare against fixed ANCHORED behavior.
6. In the old yard, compare longitudinal and lateral cart Push/Pull. On the ground release movement and confirm ordinary traction; airborne release should preserve momentum. Fall deliberately to verify Start recovery. F6 restores fixture state.
7. If testing generic forces/mass in the editor, raise a prop's native mass or Player force_response_mass and compare acceleration at the same class and projected speed. Restore mass 1 afterward. Jump height should stay unchanged because its authored jump speed is converted into a mass-scaled impulse.

## Files and limitations

Added `scripts/physical_force_response.gd`, `scripts/allomancy_interaction.gd`, their generated UID sidecars and this report. Modified `scripts/player.gd`, `scripts/steel_push.gd`, `scripts/iron_pull.gd`, `scripts/allomancy_controller.gd`, `scripts/allomancy_debug.gd`, `scripts/allomancy_tuning.gd`, `scripts/allomancy_physical_response.gd`, `scripts/metal_tether_component.gd`, and `resources/allomancy_tuning.tres`.

No geometry, NPC/enemy/combat architecture, gravity, jump, ground traction, or reset code changed in this milestone. The historical cart component filename/class is retained to avoid breaking its existing scene reference; its force filtering is now generic.

Terminal values are an initial tuning hypothesis. The 20 m assisted gap may need timing/force-response tuning after manual testing; no geometry workaround was applied. Above-terminal motion along an anchor's direction receives no further force, including vertical components of that interaction; target another axis to redirect. Long airborne directional input can still build speed, as the existing air motor was intentionally preserved. Native body rotation/point velocity and torque are not modeled by these central Allomantic forces. NPCs require their own motor adapter before accepting generic forces. More simultaneous interactions can increase acceleration and numerical overshoot, not the configured terminal value. There is no hard practical speed guarantee.
