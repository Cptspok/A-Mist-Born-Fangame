# Gameplay Ability / Allomantic State Foundations v0.1

## Architecture

AbilityDefinition is shared designer data: stable ID, name, description, INSTANT / HELD / TOGGLE lifecycle. AbilityComponent owns registration and per-character active state; it supports lookup, ID enumeration, availability queries, activation, deactivation and cancellation. It emits requested, activated, failed and deactivated-with-reason signals. Duplicate/unknown IDs and recursive same-ID activation are rejected.

Concrete adapters register optional validation and cost-check callables (empty StringName means success), a start callable (bool result), and a stop callable (reason argument). Validation hooks must be side-effect-free; start owns any actual cost commitment/effect initiation. Instant abilities activate and complete immediately. Held abilities await release/cancellation. Toggle abilities deactivate on a second request. The generic layer contains no metal, Player, health, inventory or force knowledge. No cooldown, targeting, buff or spell-effect framework was added.

MetalDefinition contains stable metal ID, name, maximum/default reserve, base consumption rate and description. AllomancyComponent copies mutable runtime values into per-instance state: reserve, maximum, access, burning and rate. It supports registration, access control, affordability, adding/consuming reserves, burn control and refill_all(). Negative/non-finite transaction amounts are rejected. Definitions are never mutated by runtime code.

One centralized physics update supports automatic continuous burns. Effect-metered consumption uses consume_usage(id, delta, engaged) and bypasses that loop to prevent double or stale-frame charges. Signals expose reserve changes, access changes, burn start/stop and depletion. Reaching zero clamps reserve, stops burning and cancels the corresponding ability. Revoking access also stops it.

## Steel / Iron integration

Player now owns AbilityComponent and AllomancyComponent alongside the existing Allomancy node. The existing controller is the concrete adapter: semantic steel_push / iron_pull actions request stable ability IDs with those same names. Activation records held intent; stop hooks end any current burn. The adapter requests consumption only when the existing interaction returns a nonzero accepted player or object force. The existing SteelPush.apply / IronPull.apply calls execute only while the ability is active and a tether is valid.

No Steel/Iron physics implementation, tuning, target selection, tether response, force integration, terminal response, or combat/movement code changed. Both-buttons cancellation is retained and consumes neither metal. Gameplay locks/death cancel both abilities. Scene pause suspends consumption with the existing paused tree.

Corrected consumption rule: held intent alone costs nothing. The existing apply() result is authoritative: only nonzero accepted player/object force consumes reserve. Losing a tether or reaching zero applied force stops burning without cancelling held intent; reacquisition resumes usage without a new press. Releasing input stops it. A depleted or access-revoked held action must be released and pressed again after refill/access restoration; it does not repeatedly retry or emit failure every frame.

Steel and Iron each start full at 1000 units and consume 1 unit/second. Configure resources/steel_metal.tres and resources/iron_metal.tres. Player/AllomancyComponent.start_at_full can instead use each definition's default_reserve. This is generous test data, not balancing.

Systems Workshop contains a small green refill station at local (5, 0.5, 5), world (5, 0.5, 50). Existing interaction refills both reserves; signal-driven Label3D text shows current/max values. It does not add ingestion, pickups or economy. refill_all() is also available to debugging/tools.

## Checkpoints and retry

Checkpoint is a reusable Area3D with stable ID, automatic Player entry activation, Respawn marker and a non-colliding floor marker/label. Re-entry is idempotent. RespawnSession is a lightweight autoload holding only the active ID and world transform, with change notification and fallback resolution. It survives death-driven world replacement and never writes persistent data.

Eight Trial checkpoints cover Start plus seven discrete obstacles, in course-local coordinates:

| Location | Floor position | ID |
|---|---|---|
| Start runway | (0, 0, 9) | trial_start |
| Jump landing after runway gap | (0, 0, -7) | trial_jumplanding |
| First roof after vertical lift | (0, 6, -17) | trial_firstroof |
| Arc landing after first major crossing | (29, 8, -17) | trial_arclanding |
| Loose-metal deck after redirect crossing | (29, 8, -2) | trial_loosemetaldeck |
| Ascent platform | (29, 16, 10) | trial_ascent |
| Safe step before the final section | (18, 20, 19) | trial_safestep |
| Destination after final crossing/ascent | (4, 25, 10) | trial_destination |

Each respawn is 0.95 above its platform; destination orientation faces the next section. Traversal geometry and difficulty were not edited.

Existing defeat timing, screen, world replacement, inventory/enemy reset and retry signal remain intact. Only destination selection checks RespawnSession after computing the old fallback. Without a checkpoint, the existing hub fallback remains. The Trial's existing fall reset also resolves the active checkpoint, making the checkpoints useful for missed jumps without creating another respawn flow.

Death preserves checkpoint state. Play/new session, Restart Test/F6 and return to Main Menu clear it. Fall resets preserve it. Checkpoints remain globally active within that session, including if the Player later visits Mini City; there is no per-zone checkpoint policy or save persistence yet.

## Validation

Headless import/class scanning completed with no script parse errors. Sandbox restrictions prevented Godot editor-cache/settings writes, and the existing Windows certificate-store error remained. No GUI or desktop input was used.

A focused runtime check and one confirmation covered:

- Real Player/shell/world instantiation and new NodePaths/resources.
- Semantic held Steel input, independent consumption, both-buttons cancellation and Iron activation.
- Depletion cancelling the ability, zero-reserve rejection, workshop refill, access revocation/restoration.
- Generic instant and toggle lifecycle, validation/cost rejection, unknown/duplicate IDs and recursive-request protection.
- No-checkpoint fallback, checkpoint replacement/idempotence, one timed defeat/world replacement to the checkpoint, Trial fall reset and Main Menu session clearing.

A short standalone Main-scene startup also passed. No new gameplay errors appeared. Temporary checks were removed; no permanent automated test suite was introduced. Full traversal/force-feel/combat testing remains manual.

## File inventory

Created scripts (with Godot UID companions): ability_definition.gd, ability_component.gd, metal_definition.gd, allomancy_component.gd, checkpoint.gd, respawn_session.gd, metal_refill_station.gd.

Created resources: steel_metal.tres, iron_metal.tres, steel_push_ability.tres, iron_pull_ability.tres. Created scenes: checkpoint.tscn, metal_refill_station.tscn. Created this report.

Modified: project.godot (autoload), scenes/player.tscn (components), scenes/traversal_course.tscn (checkpoint instances only), scenes/systems_workshop.tscn (refill station only), scripts/allomancy_controller.gd (adapter), scripts/player_death.gd (destination resolution), scripts/playtest_shell.gd (session lifetime), scripts/traversal_course.gd (fall destination/reset).

## Recommended manual order

1. Play from hub. Use the Workshop refill station; check independent values and interaction.
2. Hold/release Steel, then Iron, then both near existing fixtures. Confirm targeting, forces and momentum feel unchanged; check inventory/dialogue/pause interruption.
3. For a quick depletion test, temporarily reduce a metal resource's maximum_reserve to 2 (or raise consumption_rate), restart, hold it empty, release/retry at zero, refill and press again. Restore the generous test value afterward.
4. Before entering the Trial, test a combat death: retry should use the hub.
5. Enter Trial start, reach Arc Landing and miss a jump. Confirm fall recovery there. Activate Ascent then Safe Step; confirm later checkpoints replace earlier ones.
6. Test death/retry after a checkpoint, repeat it, and re-enter the same checkpoint. Restart Test or start a new session and confirm old checkpoints are cleared.
7. Finish with Mini City combat, movement, inventory and dialogue regressions.

Deferred intentionally: additional metals/spells, UI/hotbars/cooldowns, ingestion/economy, skill progression, buffs/status effects, save persistence and checkpoint-specific world rollback.

## Corrective pass: effect consumption, reserve HUD and obstacle checkpoints

Previously, the activation start hook called begin_burn(), so the automatic resource loop charged held input independently of targeting. The controller now reports actual accepted force from AllomancyInteraction.apply() to consume_usage(). No targeting rules, force laws, reserve values/rates or generic AbilityComponent code changed. Usage is charged for the current effect step, clamped at zero; depletion cancels intent, preventing another force step until refill and a fresh press. Automatic continuous burning remains available for future toggle policies.

New scenes/allomancy_reserve_hud.tscn and scripts/allomancy_reserve_hud.gd observe AllomancyComponent.reserve_changed and initialize from its current values. Two labeled bars with numeric values appear above the lower-right weapon display. Presentation owns no gameplay state. The Workshop refill remains unchanged and updates both HUD and its local text via the same signals.

Checkpoint count changed from 4 to 8. Seven obstacles are identified by successive safe platforms: runway gap, first roof lift, long arc crossing, redirect to loose-metal deck, vertical ascent, chained rise to safe step, final crossing/ascent. Start remains the initial checkpoint; each completion platform now has one checkpoint. The loose-deck marker sits clear of the initial test bodies. No platform/tether geometry or respawn-system code changed.

Files changed in this correction: scripts/allomancy_controller.gd, scripts/allomancy_component.gd, scenes/main.tscn, scenes/traversal_course.tscn, this report. New: scripts/allomancy_reserve_hud.gd and scenes/allomancy_reserve_hud.tscn.

Validation for this correction only: static inspection and one short standalone Main startup. No harness, gameplay scenarios or automated traversal/depletion tests. Startup completed with only the existing Windows certificate-store error and no script/resource errors.

Manual focus: hold without a target, acquire/lose/reacquire while held, confirm free zero-force terminal behavior, deplete/refill, and check both bars during traversal. Then complete each numbered platform, step through its checkpoint marker, and fail the next obstacle to verify the new retry rhythm. Check that the lower-right HUD remains readable alongside weapon text at your resolution.
