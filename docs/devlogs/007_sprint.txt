# Basic hold-to-sprint

## Implementation and tuning

Modified scripts/player.gd and project.godot. Added this report.

Semantic action: sprint. Default binding: Left Shift only (physical Shift key with left location).
PlayerController reads Input.is_action_pressed(&"sprint"), not a physical key.

Player Inspector: sprint_multiplier = 1.5.
Walking remains effective StatComponent MOVE_SPEED; sprint target is that value times sprint_multiplier. Default targets: 10 walking, 15 sprinting. Boots (+10% MOVE_SPEED) give 11 / 16.5; Boots + Trinket B (+15% total) give 11.5 / 17.25. Configure baseline on StatComponent.initial_base_values, not a duplicate walk/sprint stat.

While grounded with movement input, holding sprint multiplies the intended locomotion speed. Existing ground traction converges toward that target; releasing Shift returns smoothly toward walking. Holding Shift without movement input does not create movement. All WASD directions support sprint.

Airborne code does not read sprint and receives no additional sprint acceleration. Jumping retains the actual grounded velocity already attained. Releasing or pressing Shift in the air neither boosts nor clamps it. Steel/Iron still add acceleration after ground traction, and total velocity has no sprint-speed cap.

The existing gameplay lock check precedes movement/sprint handling. Inventory and dialogue still lock controls. Sprint is a hold action with no stored toggle state; if Shift remains held after unlocking, sprint resumes with movement input.

## Exact manual tests

A. Walk with WASD on normal ground without Shift: baseline speed and traction are unchanged.
B. Hold Left Shift with W, A, S, D or diagonal input: higher grounded speed, default target 15.
C. Release Shift while holding movement: existing traction smoothly returns toward normal target 10.
D. Build sprint speed, jump, release movement and Shift: forward momentum persists in flight.
E. Sprint, jump, aim at an overhead/right tether and hold C: running momentum combines with Ironpull.
F. Sprint/jump and Steelpush from an anchored tether with a forward/upward force component: velocity may exceed sprint target. Shift release does not cap airborne traversal.
G. Sprint while briefly Pushing/Pulling LIGHT objects, then release force and movement on ground: small Player response and corrected ground braking remain.
H. Open inventory or enter dialogue while holding Shift: movement stays locked. Close/finish and check normal controls resume.
I. Equip Boots: walking/sprint targets become 11/16.5. Add Trinket B: 11.5/17.25. Unequip to restore 10/15. The debug MOVE_SPEED display remains the effective walking stat; no sprint UI was added.

Also press Shift only after jumping: no immediate midair boost. Holding it through landing selects the sprint ground target normally.

## Validation and limits

Godot 4.7.2 parser/import checks passed. The startup harness initially compiled Player too early for autoloads; after correcting that temporary harness, the actual main scene started without reported errors and confirmed the Left Shift binding plus 10/15 defaults. Temporary script/logs were removed. Detailed gameplay testing remains manual.

Unlimited sprint. No stamina, new jump behavior, air-control changes, FOV effects, animation, camera shake, new movement mechanics, or Allomancy/physics-material tuning. Multiplier 1.5 is provisional. Ground traction still affects all grounded horizontal velocity, including speed gained from external forces; this existing behavior is unchanged.

