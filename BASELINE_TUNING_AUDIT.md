# Focused locomotion and Allomancy baseline audit

Actual code/resources and a fresh main-scene startup were inspected before editing. Earlier reports are historical; this table is the new initial test baseline, not final movement balance. No movement architecture or level layout was changed.

| Parameter | Old | New | Effective source |
| --- | --- | --- | --- |
| Normal MOVE_SPEED | 10 m/s | 5 m/s | Player StatComponent initial_base_values; scene override added |
| Sprint speed | 15 m/s | 7.5 m/s | Effective MOVE_SPEED × sprint_multiplier |
| Sprint multiplier | 1.5 | 1.5 | Player exported script default |
| Ground traction/deceleration | 12/s | 12/s | Player exported script default; same motor for acceleration/deceleration |
| Jump speed | 9.9 m/s | 10.8 m/s | Player scene Inspector override added |
| Gravity | 19.6 m/s² | 24 m/s² | Project Settings / physics/3d/default_gravity |
| Calculated jump height | 2.500 m | 2.430 m | v²/(2g) |
| Time to apex | 0.505 s | 0.450 s | v/g |
| Same-height total airtime | 1.010 s | 0.900 s | 2v/g |
| Air control | 4 m/s² | 4 m/s² | Player exported script default |
| Force-response mass | 1 | 1 | Player exported script default |
| Steel base force | 30 | 48 | resources/allomancy_tuning.tres |
| Iron base force | 30 | 48 | Same resource |
| Steel terminal response | 24 m/s | 24 m/s | Same resource |
| Iron terminal response | 24 m/s | 24 m/s | Same resource |

At startup there is no equipment speed modifier; effective speed was read as 10 before and 5 after. The existing StatComponent architecture still applies future equipment/modifiers normally. Only the Player scene overrides MOVE_SPEED; shared StatComponent/StatIds defaults remain 10 for unrelated consumers. Player's non-exported `move_speed = 10` initializer is replaced by the effective stat in `_ready`, not a second active tuning source. Likewise script fallback jump remains 9.9 while the Player scene explicitly selects 10.8. The selected Allomancy resource explicitly selects 48 even though the resource class defaults remain 30.

## Locomotion reasoning

At meter scale, 10/15 m/s correspond to 36/54 km/h, unsuitable as the requested mundane running baseline. The lower end of the proposed range, 5/7.5 m/s (18/27 km/h), gives the 1.8 m character and lab's 2/4 m gaps more readable timing. This is normal running, not a slow walking gait; extraordinary speed remains available through powers.

Ground motor implementation is unchanged:

`v_horizontal = lerp(v_horizontal, desired_ground_velocity, 1 - exp(-12 * dt))`.

There is no separate fixed acceleration value. Initial continuous-equivalent acceleration from rest is k × desired speed: formerly 120/180 m/s², now 60/90 m/s², decaying as target speed is approached. On release, `v(t)=v0*exp(-12*t)`; 95% speed reduction takes about 0.250 s. Grounded external momentum also experiences this existing traction law, while sustained external forces integrate afterward. There is no new external-momentum channel or braking rule.

Continuous approximations after tuning: by 95% speed reduction, travel is about 0.396 m normal / 0.594 m sprint. Infinite-tail stopping distance is 0.417 / 0.625 m; there is no exact finite stop in the exponential formula. At 60 Hz, because convergence happens before motion, the discrete total is approximately 0.376 / 0.565 m. Old continuous total distances were 0.833 / 1.250 m. No traction increase was needed to obtain predictable short stopping distances.

The jump/gravity pair shortens airborne time by about 11% and changes height by only -0.07 m, respecting the current acceptable/possibly-low height rather than restoring an earlier target. Fixed-step integration and unequal launch/landing heights shift ideal values slightly. Without additional air input, same-height horizontal jump travel falls from about 10.10 to 4.50 m normal and 15.15 to 6.75 m sprint. This is the main overshoot correction.

Air input adds `desired_direction * 4 * dt` to existing velocity; it does not target walk/sprint speed and does not overwrite external momentum. Over the new ideal ordinary jump, held input can add about 3.6 m/s and approximately 1.62 m extra travel. It remains influential but is left unchanged so the speed/arc correction can be evaluated first. Long Allomantic flights still allow accumulated steering speed. No air drag, clamp, fast fall or new jump feature was added.

## Allomancy authority

The existing formula is unchanged:

```
d = normalized axis in intended Player force direction
s = dot(player_velocity - owner_velocity, d)
factor = clamp(1 - s / terminal_speed, 0, 1)
Player force = d * base_force * factor * class_player_coupling
Player delta_v = sum(force) / force_response_mass * dt
```

Player mass is an effective force-resistance parameter, not a second speed limit: doubling it halves acceleration from the same force and halves delta-v from a generic impulse. Jump is deliberately converted to a mass-scaled impulse so authored jump speed stays independent of mass. Native props use their own mass; class coupling is separate. Couplings remain LIGHT (0.03,2), MEDIUM (0.35,1), HEAVY (0.85,0.25), ANCHORED (1,0). Range stays 30 m, target half-angle stays 45 degrees, and opposite movement still receives full response.

Initial authority was evaluated separately from jump tuning. At 45 degrees upward and 6 m/s approach, factor=0.75: old upward acceleration is only `30 * .75 * sin(45°) = 15.91 m/s²`, already below OLD gravity. New force 48 yields 25.46 m/s² at the same approach, slightly above new gravity. Directly upward at rest, net acceleration changes from 10.4 to 24 m/s². At 12 m/s aligned approach, force remains half its base; at/above 24 it contributes zero without deleting velocity.

Force 48 is an assistive-authority starting point, not an automatic gravity multiplier. It would improve the weak diagonal response even at the old gravity. Terminal values were not raised. Native loose props also receive 60% more low-speed coupled force; their mass, damping and materials stay unchanged. Loaded vertical equilibrium can change despite the fixed response-speed parameter: for an ideal vertical anchored Pull at mass 1 it changes from about 8.32 to 12 m/s. Actual angled/moving interactions require manual testing.

Hardcoded safeguards in the unchanged foundation include a minimum divisor mass/terminal of 0.001 and near-zero-axis rejection. They are numerical guards, not alternate tuning controls.

## Ledge audit: specific launch remains unresolved

Runtime configuration: CapsuleShape3D radius 0.4 m, total height 1.8 m; grounded motion mode; floor_max_angle 45°; floor_snap_length 0.1 m; floor_stop_on_slope=true; floor_block_on_wall=true; wall_min_slide_angle=15°; safe_margin=0.001 m. These are engine defaults with no Player scene overrides. Force integration occurs once before `move_and_slide`; there is no force reapplication or post-collision velocity restoration. The lab stairs/decks use axis-aligned box collision matching authored mesh dimensions; risers are 0.4/0.5 m and no stair motor exists.

Brief non-overlapping contact snapshots against the actual RunDeck side showed capsule corner normals varying with contact height. At incoming `(10,-2,0)`, wall-like normals stopped horizontal motion while retaining downward velocity. At incoming `(15,4,0)`, wall-like contacts reduced horizontal speed and retained vertical speed 4. Near the corner's top, normal `(-0.608,0.794,0)` falls within the 45° floor classification; one-step vertical displacement was approximately 0.0759 m versus the unconstrained 0.0667 m, while stored vertical velocity remained 4. This confirms a small rounded-capsule corner slide, not the reported upward/backward launch.

An initial diagnostic accidentally placed the capsule inside an entry step and triggered ordinary penetration recovery; those samples were discarded as evidence for the reported natural jump. No reliable root cause for an intermittent launch was established within lightweight checks. No collision shape/configuration change, velocity clamp, mantle or stair-climbing workaround was applied. The exact reproducible ledge and approach remain needed if the launch persists at the new speeds.

Godot documents that collision normals need not equal the surface normal: https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html . Local contact results, not that general statement alone, informed the decision not to make a speculative correction.

## Interaction radius

The actual script export is positive 1.75, the interaction sphere resource is radius 1.75, no scene override exists, and startup reports 1.75. It is a nearby-interaction detection radius centered on the Player. No evidence of -1.8 exists in the saved project; a rounded/unsaved Inspector reading cannot be established from these files. No unrelated interaction change was made.

## Files, validation and retest

Changed only `scenes/player.tscn` (Player StatComponent speed and jump override), `project.godot` (gravity), `resources/allomancy_tuning.tres` (base forces), and this report. No architecture change. Scene import/parser, resource loading, ordinary headless startup, effective-value readback and limited contact snapshots were used. Both layouts and movement/force/reset scripts were hash-checked as unchanged. No automated gameplay suite or detailed traversal test was performed.

1. Restart to reload project gravity. In Movement Lab, run straight, release, then repeat with Shift. Check roughly quarter-second strong slowing and sub-meter stopping.
2. At station 01, jump vertically first; compare apex and descent. Then jump the 2 m gap normally and the 4 m gap with sprint, moving takeoff closer than the old high-speed references. Compare released versus held airborne input.
3. Approach the same troublesome ledge/step from the same angle, with and without jumping. Compare normal/sprint approaches. If an upward/backward launch persists, identify the exact node/step and approach so it can be reproduced without guessing.
4. Deliberately undershoot station 01, select M1 and C; then use I2 upward and I3 diagonally in the Pull area. Observe immediate force and response factor with T.
5. At station 03, jump + F from S1, release, turn to S2 and C. Compare useful assistance against preserved momentum. Test both an early Pull and a late correction.
6. Return to advanced course: jump/Pull A1, then sprint→jump→A2 Push→release→A3 Pull. This remains a skill test with unchanged geometry; expect different timing at the slower launch speed, not guaranteed completion.
7. Briefly check LIGHT/MEDIUM/HEAVY response and fall reset. Force authority is higher for loose props too; F6 restores escaped fixtures.

Known limits: the specific collision launch is not fixed or conclusively diagnosed. Tuning is an initial test baseline. Higher shared gravity affects all falling bodies, and stronger forces affect props. Old printed jump-reference positions were deliberately not moved because layouts were protected. Detailed ledge behavior and advanced-course viability remain manual retests.
