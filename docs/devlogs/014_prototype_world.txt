# Prototype World / Test Environment Reorganization v0.1

Main is now an orchestrator for five independently maintained zones. Everything remains in one loaded world; no streaming, final art, or new gameplay systems were introduced.

## Layout and first manual route

Coordinates use north = -Z and east = +X. Play opens at the hub at (0, 0.95, 3). Four framed exits and a concise directory identify the destinations.

1. Start with Play, inspect the hub board, then walk west into Movement Lab (root -55, 0, 0). Return east to the hub. Only the former Playground label changed; course geometry and tuning remain intact.
2. Walk north along the bridge to Allomancy Trial (root 0, 0, -55). Its original scene, local geometry, tethers and tuning are unchanged. Return along the same entry route.
3. Walk south to Systems Workshop (root 0, 0, 45). Test Dialogue, Items, Weapons, Equipment, Interactables and Physics fixtures. The east-side empty pad reserves expansion space without implementing consumables or money.
4. Return to the hub and take the east bridge into Mini City (root 55, 0, 0). Visit the stalls and fountain and speak to both NPCs. Follow the north lane between the tall buildings into the ambush.
5. Fight two melee enemies in the lane and one ranged enemy on the raised loading deck. The short loading ramp is on the right. The longer rooftop access ramp is on the left, beyond the west frontage.
6. Ascend the left ramp to the large west roof. One melee and two ranged enemies occupy separate roofs. Test the roof-edge metal, the gap, and the walking bridge at the north end.
7. Cross the east roof to the wall bridge through the parapet opening. Advance south along the wall past cover and two ranged enemies. Descend the south ramp, turn west across the ground-level return route, and reach the market and hub again.
8. Test death/retry in the city: a fresh world and the safe hub spawn are expected. Then test shared aggro, hit/miss, Ironpull recovery and longer combat manually.

## Contents and preservation

- Market: three primitive stalls, a square fountain basin/column/spout, a freight cart, crates, and two existing-framework NPCs with short local dialogue. No merchants or economy logic. Market bounds are outside initial enemy sensing ranges; NPCs have no enemy encounter membership.
- Local encounter IDs: city_ambush (2 melee + 1 ranged), city_roofs (1 melee + 2 ranged), city_wall (2 ranged). No city-wide encounter group. Nearby spaces may still produce overlapping direct detection during play.
- Metal affordances: timber sign brackets, cart hardware, physical fountain spout, loading rail, roof gutters/braces, wall fixture and loose steel. The new reusable rail has matching visible/collision geometry and a slightly generous anchored target volume. Stone and wood architecture has no tethers.
- Workshop reuses Avery, Momouse, generic interaction, Red Orb and Blue Bar stacks, sword/greatsword/bow/quiver, armor, belt, boots, gloves, both trinkets, practice dummy, overhead anchor, medium/heavy bodies and directional cart. Item-definition resources remain authoritative and shared.
- Old spawn combat and miscellaneous fixtures are removed from Main. Legacy courtyard/environment scenes and navigation resource remain available as reusable references; city paths replace the active courtyard navigation test.
- Main keeps Player, HUD and TraversalCourse names required by existing paths. CombatRetry and the death fallback point to the safe hub. Play defaults to the hub; retained course-launch actions use scene markers instead of obsolete world coordinates.
- Combat, movement, Allomancy, health, projectile, inventory, equipment and dialogue tuning are unchanged.

## Navigation and validation

The saved city navmesh contains 268 polygons. It inherits the existing testing-zone bake settings, including navigation_static sources, agent height 1.8 and radius 0.45. No global parameters, enemy agents or NavigationOrigin offsets changed. Geometry edits require a fresh offline bake:

`godot --headless --path . --script res://tools/bake_mini_city.gd`

Headless validation loaded the real playtest shell and launched the hub, instantiated all five zones/eight enemies/workshop resources, resolved retry references, checked four connector floor rays, and checked paths for alley pursuit, loading ramp, roof access, roof-to-roof bridge, roof-to-wall bridge and wall descent. A follow-up corrected a parapet detour. A separate short Main startup passed. No new script/resource/gameplay errors or missing metadata errors appeared. Import/class scanning completed, but sandbox access prevented editor-cache/settings writes; Godot also reported the existing Windows certificate-store error. Offline baking emitted the existing voxel-rounding and mesh-read warnings.

Temporary checks were removed; the bake utility is an authoring tool, not a permanent test suite. No GUI, mouse or keyboard control was used.

## Files

Created: scenes/central_hub.tscn, scenes/mini_city.tscn, scenes/systems_workshop.tscn, scenes/world_metal_rail.tscn, resources/mini_city_navigation.tres, tools/bake_mini_city.gd (and its Godot UID), this document.

Modified: scenes/main.tscn, scenes/movement_lab.tscn (label only), scripts/playtest_shell.gd, scripts/playtest_menu_view.gd, scripts/player_death.gd (hub fallback only).

## Greybox limits

No visual inspection or full combat simulation was performed. Signs, cover spacing, melee pressure, ramp movement, rooftop falls and sustained ranged repositioning need manual assessment. Wall enemies use their existing combat movement, not a new patrol AI. Roof gaps have ordinary ramp/bridge alternatives. The existing courses retain their original footprint and secondary access geometry; these were not redesigned. Dynamic loose metal is intentionally excluded from the static bake.
