> Historical cleanup milestone. Current controls are documented in BURN_WHEEL_FOCUS_MILESTONE.md; V/B were subsequently removed.

# Control cleanup v0.1

Gameplay uses semantic InputMap actions. Letter bindings changed here use logical keycodes so Z/Q/S/D and A/E match the requested key labels rather than US physical positions. Left Ctrl and Left Shift use left-side modifier events.

| Actions | Defaults |
|---|---|
| move_forward / move_left / move_backward / move_right | Z / Q / S / D |
| jump | Space |
| walk | Left Ctrl, held |
| interact | F |
| primary_action / secondary_action | LMB / RMB, equipment only |
| toggle_inventory | I |
| metal_wheel | Left Shift; reserved, no handler |
| allomancy_focus | C; reserved, no handler or hold/toggle assumption |
| steel_push / iron_pull | V / B; temporary testing bindings |
| ability_1 / ability_2 | A / E; existing semantic placeholders, no spell content |

Other retained defaults: 1/2 equipment slots, wheel up/down previous/next equipment, Escape pause, Space advance dialogue (existing modal gameplay lock), T debug feedback, F6 restart test.

Future controls documented only: R flare, G consumable, U skill tree, J quest journal. No systems or InputMap actions were added for these. The already-existing ability_1/ability_2 placeholders were rebound from Q/R to A/E; their existing request signal remains, with no new behavior.

## Movement

The only movement logic change inverts the target-speed modifier: without walk, use effective MOVE_SPEED times the existing sprint_multiplier; with walk held, use effective MOVE_SPEED. In the current Player scene these are 7.5 and 5 before equipment/stat modifiers. The serialized multiplier property retains its existing name and value for compatibility. The old sprint InputMap action is removed, freeing Shift for metal_wheel. No acceleration, traction, air motor, jump, gravity, momentum, external force or bunny-hop changes.

## Temporary Allomancy and routing

F/C no longer activate Steel/Iron. V/B preserve access through the existing semantic actions and ability adapter. They are explicitly temporary, not the upcoming permanent Focus scheme. LMB/RMB remain exclusively equipment actions; no Allomancy mouse bindings or Focus routing were introduced. Shift/C do nothing for now. A later Focus milestone must implement exclusive routing at the equipment input dispatch boundary, and may choose hold/toggle behavior via settings.

## Files and validation

Changed project.godot, scripts/player.gd, scripts/playtest_controls.gd; added this document. Other ongoing project changes were preserved.

Inspected input consumers, current Player stats, movement target selection and equipment routing. One short standalone Main headless startup completed without script/resource errors, with the existing Windows certificate-store error. No harnesses, duplicate scenes, gameplay simulations or desktop control.

## Manual checks

1. On your normal keyboard layout, verify Z/Q/S/D directions, Space jump, and diagonal movement.
2. Compare default running, Ctrl-held walking and release back to running. Check airborne momentum and an Allomancy launch remain unaffected by the modifier.
3. Use F on an NPC, pickup and refill station. E must no longer interact.
4. Verify LMB/RMB equipment actions, I inventory, equipment switching, dialogue and pause.
5. Use V/B for Steel/Iron. F must not push; C must not pull. Confirm reserve/HUD behavior still works.
6. Confirm Shift/C trigger no wheel, Focus or movement slowdown. A/E have no new spells; R/G/U/J have no newly implemented systems.
