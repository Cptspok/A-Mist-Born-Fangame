# Health & Recovery v0.1

HealthComponent remains generic. Its new damage_received signal reports accepted
injury before damage processors, including fully deferred injury and direct Debt
repayment. PlayerRecovery owns recovery policy, action timing, natural recovery,
and presentation state. No rest or inventory policy lives in HealthComponent.

## Active recovery and medicine

PlayerRecovery.apply_recovery(amount) treats Pewter Debt first, then heals missing
HP and clamps excess. It never revives. PewterBurn.recover_debt(amount) changes
only untreated Debt, emits debt_changed, and stops repayment processing when empty.
Burn state, depletion, combat modifiers, deferral, and lethal repayment remain.

Medical Supplies use the existing ItemDefinition / ConsumableDefinition and normal
inventory grid: one cell per authored pickup, five pickups total. Right-click the
item and choose Use, then close inventory to let the action advance. Inventory
already pauses the game; remaining paused never advances healing or regeneration.

Each use takes 3 seconds and provides 30 recovery against the player's 100 max HP.
One action per player; repeated use cannot bypass its timer. One item is consumed
at completion. Damage interrupts without consuming it, as do death, rest, and
removing the selected stack. If no injury remains on completion, retain the item.
Movement and combat controls remain unchanged during use.

Damage includes existing Debt repayment ticks: with Pewter off and Debt repaying,
those ticks interrupt medicine too. Keep Pewter burning to treat masked injury
without repayment ticks. Turning it off never erases untreated Debt.

At 40 HP / 30 Debt, apply_recovery(20) gives 40 HP / 10 Debt; the next 30 gives
60 HP / 0 Debt. Medicine knows only the recovery entry point, not Pewter.

## Natural recovery and condition

Player/PlayerRecovery Inspector defaults:

| Parameter | Default |
| --- | --- |
| natural_regen_enabled | true; turn off to disable only passive recovery |
| regen_delay_after_damage | 12 seconds |
| regen_rate | 1 HP/second |
| regen_health_ceiling | 0.65, fraction of max HP |
| wounded_threshold | 0.50, fraction of max HP |
| critical_threshold | 0.20, fraction of max HP |

Passive recovery pauses while any Debt or healing action exists. It neither
treats Debt nor reduces HP already above the ceiling. All accepted damage resets
the delay. Dead actors cannot regenerate. Thresholds emit condition_changed;
the existing health HUD changes its bar color and adds WOUNDED or CRITICAL text.
There are no low-health stat penalties or fullscreen effects.

Tune heal_amount, use_duration, and interrupt_on_damage on the consumable
subresource in data/items/consumables/healing/medical_supplies.tres. Keep critical_threshold
at or below wounded_threshold. Item description text is authored separately;
update it if changing medicine values.

healing_started(duration), healing_finished(recovered), healing_cancelled(reason),
and is_healing()/healing_remaining are lightweight future presentation hooks.
The health HUD shows remaining time and a brief completion/interruption message.

## Rest and authored test content

world/interactables/rest_point/rest_point.tscn contains a bedroll, label, and the existing
InteractionComponent. Rest is immediate through the usual interaction input:
cancel medicine, clear Debt, restore full HP, and briefly report the result.
There is no general debuff system to clear. Rest does not refill inventory or
metal reserves, change a checkpoint, respawn enemies, or advance world time.

Subscribe to PlayerRecovery.rested(rest_point) for all rest locations, or
RestPoint.rested(interactor) on a particular location. Rest points join the
rest_points group and expose rest_name plus normal interaction_enabled controls.
Safety is authored spatially; there is no new combat detector or invulnerability.

Mini City local coordinates (under the new Recovery node):

| Content | Location |
| --- | --- |
| Market shelter rest | (-8, 0, -10.2), behind the west market stall |
| East wall refuge rest | (28.5, 0, -20), ground-level foot of the wall south of encounters |
| Three individual medicines | West market counter: (-8.8, 1.65, -8), (-7.5, 1.65, -8), (-6.8, 1.65, -8) |
| Two individual medicines | East refuge: (27.2, 0.45, -20), (27.2, 0.45, -18.8) |

Pickups use WorldItem and ordinary inventory capacity. Rest never regenerates
them. Existing scene reload/death behavior is unchanged.

## Scope and validation

No Hathsin files or content were changed. Shared player recovery naturally works
wherever that player scene is used; all new world content is Mini City only.
No Sword/Club, enemy, block, Steel/Iron, Focus, wheel, reserve, or movement balance
changes. No UI/style overhaul; only health/recovery text and state color feedback.

Deferred: world progression on rest, Gold/Electrum, armor, injury simulation,
coyote time, and Ironpull ledge recovery.

Validation is static inspection plus dev/tools/validate_recovery_resources.gd, a
resource-only load/parse check with no actor instantiation. No automated combat,
healing scenarios, desktop control, or gameplay runs. The engine reports an
environment root-certificate-store warning unrelated to these local resources.

Manual playtesting should cover delayed capped regen, interrupted/successful
medicine, Debt-first spillover, lethal untreated Debt, full rest without
restocking, critical-health feedback, and the unchanged combat movesets.
