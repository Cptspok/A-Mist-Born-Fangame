# Player stats and modifiers milestone

Implemented in C:/Users/CptSp/Documents/Codex/A Mist Born fangame.

## Ownership and API

Player/StatComponent is the authoritative source of base values, active numeric contributions, and cached effective values. EquipmentComponent still owns equipment; HealthComponent still owns current HP. No independent equipment-stat calculator was added.

Identifiers: StatIds.Stat { MAX_HEALTH, MOVE_SPEED, ARMOR, PHYSICAL_DAMAGE, ATTACK_SPEED }.

StatComponent API:
- get_value(stat): cached effective value.
- get_base_value(stat), set_base_value(stat, value).
- add_modifier(stat, operation, value, source): returns unique integer handle, or -1 for rejected input.
- remove_modifier(handle), remove_modifiers_from_source(source).
- begin_update()/end_update(): nestable batch for a single gameplay transaction.
- stat_changed(stat, effective_value) and values_changed: emitted only for effective changes (approximately equal floats are suppressed).

Defaults are 100 health, 10 world units/second movement (the previous player speed), 0 armor, 0 physical damage, 1 attack-speed multiplier. Configure Player/StatComponent.initial_base_values in the Inspector. Runtime edits use set_base_value; changing the startup dictionary directly is not a runtime update API.

## Modifier data and math

StatModifier is immutable contribution data: stat enum, operation enum, numeric value. ItemDefinition.stat_modifiers is a typed array of these Resources and can hold multiple entries. Active contributions are numeric snapshots owned by StatComponent, not mutable shared Resource state.

Exactly three operations:
- FLAT_ADD
- PERCENT_ADD
- MORE_MULTIPLIER

effective = (base + sum(flat)) * (1 + sum(percent)) * product(1 + each more)

Fractions are used: 0.20 means +20%, -0.20 means -20%.
Examples: (100 + 20 + 15) * 1.10 = 148.5; (20 + 5) * 1.20 * 1.20 = 36.
Effective minima are MAX_HEALTH 0.1, ATTACK_SPEED 0.01, other initial stats 0. No upper cap is imposed. Nonfinite input is rejected; arithmetic overflow warns and retains the last finite effective value.

A future passive or effect system can call:
~~~gdscript
var source := RefCounted.new() # Keep this source for the node/effect lifetime.
var handle := stats.add_modifier(
	StatIds.Stat.MAX_HEALTH, StatModifier.Operation.PERCENT_ADD, 0.05, source)
# Remove either one handle or every contribution from that source:
stats.remove_modifiers_from_source(source)
~~~
Source can also be a stable key or runtime object. Different sources must use distinct identities. No timers, conditions, stat dependencies, effects or skill-tree logic live in StatComponent.

## Equipment bridge and safety

Player/EquipmentStatsBridge listens to equipment_changed. Each ItemStack object is its source identity, so two instances of the same definition remain distinct. It diffs equipped identities: departing items lose all contributions, arriving items add theirs once, slot-only swaps retain existing contributions.

Changes are batched. Every affected value is calculated before notifications; consumers never see a transient removal state during replacement. This avoids accidentally clamping current HP during an intermediate max-health dip. Failed equipment/world-drop transactions emit no equipment change, so no bonuses move. Inventory pickup alone registers nothing.

Definition edits are configuration data: modifying a Resource while its item remains equipped does not live-refresh its numeric snapshot. Unequip/re-equip to apply development-time edits. Equipment modifiers can later be reconstructed from equipped items after load; cached effective numbers are not persistent authoritative data.

## Consumers

- HealthComponent's optional stat_component_path is set only on Player to ../StatComponent. Its maximum mirrors effective MAX_HEALTH. Increasing the cap preserves absolute HP; decreasing clamps HP. It never heals or revives. Existing health_changed updates the HP HUD. Enemies retain local maximum health.
- PlayerController receives MOVE_SPEED through stat_changed and caches it for locomotion. Base-speed configuration moved from Player.move_speed to StatComponent. No sprint/acceleration change.
- Existing player melee runtime resolves the player's StatComponent once. On each accepted attack, damage = weapon base damage + effective PHYSICAL_DAMAGE.
- Cooldown = weapon cooldown / effective ATTACK_SPEED. Changes affect the next accepted attack; they do not rescale a running cooldown or animation.
- ARMOR is queryable/displayed only. Incoming damage is unchanged.
- Inventory's existing left column now shows the five effective values through StatDebugDisplay.values_changed subscription. No polling or new character-sheet screen.

## Equipment test values

| Item | Contribution | Isolated effective result |
|---|---|---|
| Helmet | MAX_HEALTH +20 flat | 120 |
| Chest Armor | ARMOR +15 flat | 15 (no mitigation) |
| Gloves | ATTACK_SPEED +0.10 percent | 1.10 |
| Boots | MOVE_SPEED +0.10 percent | 11 |
| Trinket A | MAX_HEALTH +10 flat | 110 |
| Trinket B | MOVE_SPEED +0.05 percent | 10.5 |
| Sword | PHYSICAL_DAMAGE +5 flat | 5; hit = 25 + 5 = 30 |
| Greatsword | PHYSICAL_DAMAGE +10 flat | 10; hit = 45 + 10 = 55 |

Helmet + Trinket A: max 130. Boots + Trinket B: speed 11.5, since percentages add. Gloves: Sword cooldown 0.6 / 1.10 = about 0.545 seconds; Greatsword cooldown 1 / 1.10 = about 0.909 seconds.
Belt, Bow and Quiver have no stat modifiers. Existing pickups and all slot/compatibility rules are unchanged.

Inspector: open the existing item .tres, expand stat_modifiers, add StatModifier entries and select stat/operation/value. The item equipment_profile continues to govern placement separately. Weapon base damage/cooldown remains on its combat_definition. Never edit those definitions to reverse a removed modifier.

## Exact manual tests

Use existing E pickup / I inventory actions or current bindings. Debug values are in the inventory panel.
A. Start with empty equipment: health cap 100, move 10, armor 0, physical damage 0, attack speed 1.
B. Equip Helmet: HP 100/100 becomes 100/120. If damaged to 80 beforehand, expect 80/120.
C. Remove Helmet: max returns to 100, absolute HP is preserved up to the new cap. To exercise clamping above 100, use existing HealthComponent.restore_to_max() through a temporary debugger invocation while Helmet is equipped; 120/120 then becomes 100/100 on removal. No healing UI was added.
D. Equip Boots: debug speed 11; close inventory and walk. Unequip: speed 10 and original movement returns.
E. Equip Helmet + Trinket A: maximum 130, no healing. Remove either and verify its own contribution disappears.
F. Boots + Trinket B: move speed 11.5, not 11.55. Remove Boots: 10.5.
G. Equip Sword: physical damage 5, each accepted melee hit deals 30 to an otherwise unmodified enemy. Inspect enemy current health before/after.
H. Replace Sword with Greatsword: physical damage becomes 10, not 15; each hit deals 55. Existing off-hand conflict rules still apply.
I. Drag an equipped stat item outside the panel: one WorldItem appears and its contribution disappears immediately.
J. Pick up that item into the grid: contribution stays absent.
K. Equip it again: its contribution appears exactly once.
L. Repeat equip/unequip, world-drop/pickup and trinket-slot swaps: no accumulating modifiers. Swapping A/B between equivalent slots does not alter total stats or clamp HP.
M. Equip Gloves: attack speed 1.10. Sword cooldown is approximately 0.545 seconds. Visual swing speed remains unchanged.
N. Equip Chest: armor 15. Compare repeated hits from the same enemy before/after: incoming damage remains unchanged.
O. Keep inventory open while changing equipment: five effective values update immediately.

Additional numerical data check, if desired: temporarily give Trinket A two PHYSICAL_DAMAGE contributions (+0.20 PERCENT_ADD, +0.20 MORE_MULTIPLIER) and set base PHYSICAL_DAMAGE to 20; with Sword's +5 flat, expect 36 effective physical damage. Restore test configuration afterward. This uses the same generic API/data, without a separate test scene.

## Files

Added:
- scripts/stat_ids.gd, stat_modifier.gd, stat_component.gd, equipment_stats_bridge.gd, stat_debug_display.gd (and generated Godot UID files)
- PLAYER_STATS_MILESTONE.md

Modified:
- scripts/item_definition.gd, health_component.gd, player.gd, melee_weapon.gd, inventory_ui.gd
- scenes/player.tscn
- resources/helmet.tres, chest_armor.tres, gloves.tres, boots.tres, trinket_a.tres, trinket_b.tres, sword.tres, greatsword.tres

EquipmentComponent, inventory ownership/transfers, world dropping, damage-source/hurtbox, enemy scripts, navigation, dialogue and input bindings were not modified.

## Validation and limitations

Godot 4.7.2 headless editor parser/import checks passed. One startup sanity run loaded the actual main scene and opened the real inventory panel, reporting all five defaults plus 100/100 HP and movement 10. Detailed gameplay and arithmetic tests remain manual as requested. Temporary startup script/logs were removed.

No skill tree, buff/debuff lifecycle, timers, conditions, derived attributes, mitigation, rarity, save/load or final character-sheet UI. Melee damage remains immediate, with separate visual swing presentation. Attack speed does not synchronize animation. Existing combat runtime recreation on equipment changes is unchanged. Startup bases and modifier Resources are intended as authored configuration; callers must use the runtime APIs and balance begin_update/end_update.
