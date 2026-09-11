# Opening traversal blocker repair

This is a historical diagnosis of the opening blocker. Current locomotion values are documented in `BASELINE_TUNING_AUDIT.md`; the in-world instructions described below were later removed during environment cleanup.

## Jump tuning

| | Previous | New |
| --- | --- | --- |
| Shared world gravity | 9.8 m/s² (engine default) | 19.6 m/s² (explicit project setting) |
| Player jump velocity | 7 m/s | 9.9 m/s |
| Ballistic apex, v²/(2g) | 2.50 m | 2.50 m |
| Same-height airtime, 2v/g | 1.43 s | 1.01 s |

Airtime is about 29% shorter with approximately the same height. Fixed-step integration and platform elevation slightly change these ideal estimates. Shared gravity also makes loose bodies fall faster; their materials, damping, class responses and force code are unchanged.

Air control remains 4 m/s², with no air drag or total-velocity clamp. Sprint's 1.5 multiplier is used only on the ground. Air input adds acceleration and releasing input preserves velocity. Previous long airtime allowed about 5.7 m/s of extra speed with continuously held input; the new ordinary jump allows about 4.0 m/s. Airtime is the first tuning correction, not a claim that manual feel is proven. Very long Allomantic flights still permit accumulated steering acceleration; this was not redesigned.

## Confirmed root cause of “nothing reacts”

`Player/Allomancy` was a plain `Node`. Its `Targeting` Area3D did not inherit the Player's spatial transform across that non-spatial parent. Startup inspection with the Player at the ordinary landing showed Player position `(45, 0.91, -7)` but detector position `(0, 0, 0)`. Its 30 m sphere discovered the six old-yard tethers, not the course's A1.

The detection sphere was already assigned correctly. An initial reading suggested otherwise, but runtime inspection disproved that hypothesis; the targeting algorithm needed no change.

The scene's Allomancy parent is now `Node3D`, and `AllomancyController` extends `Node3D`. Existing child paths, shared selection, additive force integration and inputs are preserved. The detector now inherits both Player movement and fall reset transforms.

Startup inspection confirmed:

- A1 exists, enabled, ANCHORED (3), collision layer 16, monitorable, valid independent radius-0.8 m sphere. Detector monitoring is enabled and its mask is 16.
- A1's nearest point is approximately 10.91 m from the landing camera, well inside unchanged 30 m range. Its line of sight is clear.
- A1 is roughly 53 degrees above the level view from the landing center, outside the unchanged 45-degree targeting half-angle until the tester looks up. Aiming at A1 now selects A1, not another candidate.
- Existing C/F mappings reach the shared ability controller. At this position, C adds `(0, 24.649, -17.100)` m/s²; F adds its opposite. The upward Pull exceeds new gravity by approximately 5.05 m/s², so it can lift from rest. Jump + Pull provides a stronger initial ascent. An ANCHORED bar itself stays still.
- On the first roof at `(48, 6.91, -17)`, aiming individually at A2 and A3 selects each correctly; clear line of sight, nearest-point ranges approximately 4.24 m and 24.22 m.

Steel and Iron remain 30 m/s²; range, response multipliers and selection rules remain unchanged. Directly upward anchored force exceeds gravity by 10.4 m/s². A shallower force can slow a fall without reversing it. No force rebalance was needed to establish a functioning first lift; subsequent traversal feel remains for manual testing.

## Minimal course changes

No platform, gap, anchor position or tether volume was changed. The original station guidance is preserved in the manual retest below rather than displayed as floating in-world instructions.

Two non-colliding reference stripes on the runway mark approximate takeoff points for the unchanged 6 m landing: WALK at local z=3, SPRINT at z=8. These assume roughly established 10/15 m/s takeoff speed and released directional input in flight. They make timing comparable; they are not automatic landing assistance. Jumping from the gap edge at full sprint can still overshoot because momentum is intentionally preserved.

## Exact manual retest

1. Restart the running game so the new project gravity is loaded. With debug enabled (T), walk forward and jump near the WALK stripe; release directional input while airborne. Land on station 02. Compare apex height and landing timing. F6 repeats from Start.
2. Repeat holding Shift on the runway, jumping near the SPRINT stripe. Release forward input in flight. Account for acceleration from the spawn; the stripes are references. Compare preserved forward velocity and ground traction when landing.
3. Stop on 02, look up at the purple A1 bar until the debug readout names `A1_Lift` / ANCHORED. Hold C and confirm an obvious upward response. Separately tap F to confirm movement away from it. Do not hold both, as their accelerations cancel.
4. Jump + C toward A1. Release C after clearing the roof lip, move forward as needed and land on station 03 at 6 m. Avoid holding forward at sprint speed throughout this first lift.
5. On 03 move toward its right (+X) launch side. Jump, aim back/down at A2 and use F; release F, turn across the gap toward A3, and hold C. Release C above station 04 to land. This tests the next two stations after the ordinary landing, and Push-to-Pull continuity.
6. Optionally continue via A4 toward the loose deck. Compare LIGHT/MEDIUM object response, force release and grounded traction. HEAVY and the original yard/cart remain available. Fall deliberately and verify recovery; F6 restores props/full fixture state.

## Validation and limits

Godot 4.7.2 editor import/parser, resource loading, a brief startup inspection of transforms/target access/input-to-acceleration, ordinary headless startup, and `git diff --check` passed. Temporary diagnostic code was not installed into the project. No automated traversal, detailed physics benchmark or full-course playtest was performed.

Higher gravity changes the duration of all ballistic arcs, including loose props. Allomantic momentum is preserved, but upward forces now have less excess acceleration against gravity. The 20 m assisted gap and later stations still require manual timing and balance assessment. No landing guarantee, drag, speed clamp, new movement feature or final tutorial UI was added.

Files changed for this repair: `project.godot`, `scripts/player.gd`, `scripts/allomancy_controller.gd`, `scenes/player.tscn`, `scenes/traversal_course.tscn`, `TRAVERSAL_GREYBOX.md`, and this report.
