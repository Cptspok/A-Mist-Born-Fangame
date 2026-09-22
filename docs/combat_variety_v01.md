# Combat Variety v0.1

Reusable archetypes: scenes/knife_fighter.tscn, heavy_enemy.tscn,
crossbow_skirmisher.tscn, long_range_archer.tscn. Scene overrides are configuration;
shared attack and behaviour scripts own runtime state. Original example_enemy and
ranged_enemy defaults remain available for existing scenes, including Hathsin.

## Foundation

CommittedEnemyAttack still owns windup -> strike -> recovery, committed facing,
cooldown, and the existing CombatReaction interruption window. New melee roles opt
into a box query against HurtboxComponent areas on every active physics tick.
Each player hurtbox is damaged at most once per swing through DamageSourceComponent.
World cover blocks hits. Enemy friendly fire is excluded. Box height permits jumping
over coverage when the player's full hurtbox clears it; merely jumping is no guarantee.
Legacy enemies retain their previous single-target sector check.

Knife: 0.55 wide x 0.7 high x 1.45 deep volume, centered 0.95 forward.
Heavy: 4.8 wide x 0.8 high x 2.8 deep volume, centered 1.5 forward.
These are boxes, not radial sweeps: corners are intentionally broad. Attack range
is the distance to START a swing; the configured volume determines actual contact.
The Heavy visibly draws its enlarged weapon sideways then sweeps horizontally.
The entire box is active throughout the strike; the visual arc is prototype feedback,
not a per-blade collision simulation. Facing is fixed during commitment.

## Initial tuning

| Role | HP | Chase speed | Damage | Start/fire range | Windup / active / recovery | Cooldown |
| --- | ---: | ---: | ---: | ---: | --- | ---: |
| Knife Fighter | 65 | 8.5 | 16 | 1.65 | 0.24 / 0.12 / 0.30 s | 0.75 s |
| Heavy | 180 | 3.2 | 42 | 2.9 | 1.10 / 0.32 / 1.25 s | 2.9 s |
| Crossbow Skirmisher | 95 | 5.5 | 22 | 24 | 0.45 / 0.10 / 0.40 s | 1.55 s |
| Long-range Archer | 60 | 1.5 (holds position) | 12 | 60 | 0.90 / 0.10 / 0.80 s | 3.6 s |

Cooldown begins at windup, not recovery completion. Reposition/LOS can lengthen cadence.
Knife rapidly alerts, closes to 0.95 between commitments, and skips the old post-attack
orbit. Heavy uses the existing short reposition after its long recovery.
Skirmisher seeks an 8-18 distance band, moves at 6 while repositioning, checks decisions
every 0.2 s, retries retreat every 0.7 s, and seeks a lateral position after one shot
when its 1.4 s move cooldown allows. Its bolt travels at 32 for 1.2 s.
Archer detects/fires to 60 in 3D, holds its perch, has no close-range fallback, and fires
at speed 65 with a 1.5 s projectile lifetime. Existing aim snapshot, cover collision,
and projectile architecture are preserved. Crossbow has a simple stock/limb visual
and raising/reloading pose; Archer retains its bow draw pose.

## Mini City compositions

Existing encounter node names and reward assignments are preserved.

- B / city_ambush: two Knives at (-1, 0.9, -33) and (1, 0.9, -37),
  Skirmisher on the loading deck (4.5, 2.4, -42).
- C / city_roofs: Heavy on west roof (-4, 12.828, -59), Skirmisher farther
  back on west roof (-9, 12.828, -64), Archer across the elevated east roof
  (8, 16.398, -65). Heights match existing scaled roof tops plus body half-height.
- A / city_wall: Knife at (34, 16.479, -30), Heavy at (35, 16.479, -35),
  distant Archer at (35, 16.479, -51), along the existing eastern wall walk.

No architecture, navigation bake, ladders, props, Court targets, NPCs, ambient
creatures, equipment pickups, or UI were changed. Existing cover controls sightlines;
archers are not guaranteed a clear shot at every approach angle.

## Inspector tuning

Open an archetype inherited scene and tune its existing child nodes:
HealthComponent.max_health; Sensing.detection_range/ally_alert_radius;
Movement.chase_speed/reposition_speed; MeleeAttack timing, range, volume size/offset,
horizontal_sweep and its DamageSourceComponent.damage_amount;
MeleeBehaviour.persistent_close_pressure/preferred_engagement_distance/leash;
RangedAttack range, projectile speed/lifetime/damage, timing and crossbow_pose;
RangedBehaviour comfortable/preferred/max ranges, hold_position, reposition step,
duration/cooldown, escape retry, decision interval, shots_before_reposition and leash.
Keep projectile speed * lifetime above firing range. Keep sensing range at least as
large as firing range. Visual scenes can be replaced separately. No configuration
resource is mutated during play.

## Validation and limits

Conservative Godot resource-load check passed: all four archetypes and Mini City
loaded and instantiated off-tree; expected HP, timing and weapon nodes resolved.
No gameplay simulation or desktop/editor control was performed. Godot reported
sandbox log-write and Windows certificate-store errors, but no script/resource errors.
Static diff/whitespace inspection passed. Temporary checker removed.

Navigation and actual combat feel need manual testing. No navigation rebake was done.
All enemies retain shared motors, reaction rules and prototype humanoid meshes.
Knife retains a small metal buckler; Heavy retains its metal shield. Their inherited
weapon/shield tethers and the ranged coin-pouch tethers remain attached to the actor.
No new immunity, mass override, or Steel/Iron/Pewter changes were introduced.
Archer holds position even when LOS is blocked, so cover is an effective counter.
Long-range shots use a windup-start aim snapshot and do not lead moving targets.
There are no dedicated solo test arenas; reuse each archetype individually for tests.

Manual checks: fight each role alone, test dodging/jumping/cover against the Heavy,
close on a distant Archer, fight each mixed encounter, and use Steel/Iron/Pewter.
Confirm the existing sword/equipment still works; player bow remains unimplemented.
Hathsin files, player sword, player bow, healing/rest, and enemy Coinshot were untouched.
