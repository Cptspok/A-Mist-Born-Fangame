# Allomancy Movement Lab

The new forgiving practice space is an instance in the existing main scene. The original advanced course remains the precision challenge; its authored scene and all physics tuning are unchanged.

## Access and organization

Choose **Playground** in the playtest shell. The Player spawns at the lab entrance near world **(45, 0.95, 49)** facing **+Z**. The **8 m wide, 34 m long** walkway connects the advanced course at world z=12 to the lab at z=46, x=45. The lab root is at world **(45, 0, 80)**; its floor spans x=11..79 and z=46..114. The previous gameplay yard remains intact.

In `scenes/main.tscn`, the sibling nodes are the existing Environment, TraversalCourse, and new MovementLab. The lab scene groups its nodes by Foundation and stations 01–04. No second Player or duplicate Allomancy implementation is present.

## Stations and dimensions

All coordinates below are local to MovementLab: add (45, 0, 80) for world positions. Heights are top surfaces, not slab centers.

| Station | Geometry | Purpose |
| --- | --- | --- |
| 01 Ordinary movement, west/north | 12×10 m run deck at y=1.2; 12×10 m short landing at y=1.2; 12×14 m sprint landing at y=2 | Walk/sprint acceleration and stopping; 2 m gap; 4 m gap with 0.8 m rise; optional correction |
| 02 Iron, east/north | Open floor and 18×12 m roof at y=4 | Forward, vertical, diagonal and sideways-moving Pull |
| 03 Steel/chaining, east/south | 14×10 m launch at y=2; 22×14 m landing at y=3; 4 m gap | Upward/away Push, sprint + jump + Push, easy Push→Pull, late correction |
| 04 Objects/targeting, west/south | Approximately 24×20 m open bay with three 2 m boundary walls | LIGHT/MEDIUM/HEAVY response, friction and terminal factor; three separately visible fixed targets |

The continuous catch floor is **68×68 m at y=0**, with margins outside the landings. Broad steps reach the decks again using ordinary movement/jumping; they do not implement automatic stair stepping. All practice platforms can be reached without Allomancy. The Iron roof rises beyond a single ordinary jump, but its side steps provide an ordinary alternative.

The lab intentionally uses more floor area than the compact precision course to provide room for misses. Geometry is primitive and modular. Edit a block's `dimensions` to keep its mesh and collision synchronized, using the existing greybox block tool.

## Tethers and assist scenarios

Twelve ANCHORED practice fixtures reuse the existing MetalTether script through `scenes/lab_anchor.tscn`. Each has a **1.25 m radius** spherical volume and an independently editable sibling purple marker, with no marker collision. Sphere resources are local to each instance. Existing class selection, range, force, mass and terminal-response behavior are reused unchanged.

| Fixture | Local position | Practice |
| --- | --- | --- |
| M1 CorrectShort | (-20,6,-7) | Pull to extend a normally possible short jump |
| M2 ReturnPull | (-27,5,-9) | Look back/sideways and Pull after overshooting |
| M3 LowAssist | (-20,1,-2) | Low reference in the open 4 m gap; Push upward after jumping past/above it |
| I1 Forward | (7,2,-8) | Forward Pull across open floor |
| I2 Up | (6,9,-23) | Vertical Pull; repeat while carrying sideways velocity |
| I3 Diagonal | (20,10,-13) | Jump + diagonal Pull onto the broad 4 m roof |
| S1 Push | (17,2.7,1) | Jump past it, aim back/down, Push away/up |
| S2 Catch | (17,9,19) | Follow-up Pull onto the broad landing |
| S3 SideReturn | (28,7,16) | Sideways correction while approaching/passing the landing |
| T1 Left / T2 Center / T3 Right | (-27,4,29), (-19,4,29), (-11,4,29) | Stationary target-selection practice, spaced 8 m apart |

The bay also instances the existing LIGHT, MEDIUM and HEAVY scenes at x=-26/-19/-12, z=21. No new object physics is implemented. Its three fixed targets provide the ANCHORED comparison. Purple markers remain visible when T debug is off; T retains the shared axis/speed/factor/force diagnostics. The fixed instances' selected child is named MetalTether in the existing HUD. In-world instructional and fixture labels were removed; this document remains the detailed test reference.

## Recovery

Missing a lab platform normally drops only **1.2–4 m** onto the solid floor. Walk back, jump onto a low platform, or use the broad steps. No pit or mandatory reset separates these exercises. The metal bay walls retain many low throws while leaving its entry open; props can still fly out.

Existing fall recovery beyond the map still returns the Player to advanced Start. **F6** retains the existing full-scene restart: Player returns to advanced Start and all props are restored. Return to the lab via the short walkway. No new checkpoint, teleport action or save system was added. Ordinary practice misses do not trigger this reset.

## Suggested manual sequence

1. From advanced Start turn toward +Z and follow the walkway. Enable T if needed. On open floor, walk forward and release; repeat with Shift-sprint to compare acceleration/stopping.
2. Go left to station 01. Use its north entry steps to the run deck. Jump the **2 m gap** toward +Z onto the broad middle deck. Repeat with different takeoff/release timing. Floor below catches misses.
3. Sprint-jump the **4 m gap with 0.8 m rise** onto the larger final deck. Jump early enough to compare preserved velocity; try modest airborne steering and stopping after contact.
4. At station 02, start around (7,0,-26), aim forward/+Z at **I1**, hold C. Compare grounded traction with a jump + Pull. Then stand beneath **I2** and Pull upward; release and land on the floor.
5. Start around (16,0,-24), aim at **I3**, jump + C diagonally toward the roof, release above it and land. Repeat moving sideways beneath I2 to isolate how lateral velocity affects the force direction.
6. Walk/jump up the west access steps onto station 03's launch. Face +Z, jump past **S1**, aim back/down and hold F briefly, then release. Repeat with sprint speed and with existing momentum; observe declining response factor.
7. Repeat **sprint → jump → S1 Push → release F → aim S2 → C Pull → release over landing**. The gap is only 4 m and the landing is 22×14 m. First try it as an ordinary jump, then use powers as assistance. Avoid holding F and C together because the existing controller cancels them.
8. Return to station 01 and deliberately jump late/short. Aim at **M1** for an upward/forward correction. At the second gap try a small Push from **M3** while above/past it. If a tether is behind a slab, move into the open gap or change your view; world occlusion remains active.
9. Deliberately carry too much forward momentum, look back/sideways at **M2**, and Pull to redirect. At station 03 repeat with **S3**. A miss lands on the floor; the ability will not erase existing velocity.
10. Enter station 04 through its open north side. Push/Pull LIGHT, MEDIUM, HEAVY separately, comparing Player reaction, object reaction, terminal factor, and friction after release. Pull objects back before they escape; F6 restores lost ones.
11. Stand near (-19,0,16), look toward +Z and aim between **T1/T2/T3** without moving. All three fit in the current broad forward view. Observe selected highlighting and how closer loose objects compete; no target cycling was added.
12. Return to the walkway and travel -Z to the existing advanced course. Compare the same Push→Pull maneuver under its unchanged gap/landing pressure.

## Files, validation and limits

Added `scenes/movement_lab.tscn`, `scenes/lab_anchor.tscn`, and this report. Modified `scenes/main.tscn` only to reference and instance the lab. No runtime scripts or new physics mechanics were added.

Godot 4.7.2 editor import/parser, scene/resource loading and normal headless startup passed. Byte hashes confirmed the advanced traversal scene, its reset script, prototype yard, Player movement script, project settings, Allomancy tuning resource and force-law/adapter scripts stayed unchanged during this milestone. No automated gameplay tests or manual route-completion claims are made.

The lab is a first-pass geometry layout for manual evaluation. Strong retained momentum can still carry the Player or props beyond the floor/walls. Low tethers can be occluded by slabs, and larger volumes can expose selection competition. Holding Pull at ground level is affected by normal ground traction; jump to isolate airborne forces. Step access uses the existing jump behavior rather than a new stair motor. Current terminal response may require release/aim timing even in this easier space. These are observable physics behaviors, not hidden by special assistance rules.
