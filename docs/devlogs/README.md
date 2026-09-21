# Development archive

These 19 records were originally milestone Markdown reports at the project root; no existing `.txt` files were found. They are now numbered plain-text files, retaining their Markdown notation and historical technical content. Only references to moved documentation filenames were updated. Original filenames are mapped below so Git history remains traceable.

This is technical history and source material for possible future itch.io devlogs, not public-facing posts or a guarantee of current behavior. Paths to code/scenes/resources within the reports remain **project-root-relative**, not relative to this folder. Historical tests are the reports' own claims; archiving them does not establish external playtest evidence.

For future milestones, follow [CONTRIBUTING_DEVLOGS.md](CONTRIBUTING_DEVLOGS.md).

## Chronological index

| Sequence | Milestone / archived document | Summary | Status |
| --- | --- | --- | --- |
| 001 | [Hand equipment](001_equipment.txt) | Introduced equipment ownership, compatibility rules, inventory transfers and dropping. | Evolved: expanded by 002; stats added in 003. |
| 002 | [Full equipment layout](002_full_equipment.txt) | Expanded hand equipment to nine slots with armor, trinkets and category-based placement. | Current foundation; its no-stats statement predates 003. |
| 003 | [Player stats](003_player_stats.txt) | Added authoritative stats, modifier resources and equipment integration. | Current foundation; later tuning and Pewter extend its use. |
| 004 | [Allomancy and accumulated combat notes](004_allomancy_and_combat.txt) | Records metal tethers, Push/Pull and later world/carried metal, combat timing, damage fixes and encounter aggro additions. | Evolved: force and control descriptions were revised by later milestones; this document spans multiple stages. |
| 005 | [Ground traction correction](005_player_traction.txt) | Replaced separate drive/momentum channels with one collision-resolved velocity and consistent ground traction. | Current foundation; later force integration and tuning build on it. |
| 006 | [World physics baseline](006_world_physics.txt) | Established shared world/prop physics materials and documented friction and damping behavior. | Current foundation; historical scene assignments describe that version. |
| 007 | [Hold-to-sprint](007_sprint.txt) | Added stat-driven hold-to-sprint with preserved airborne momentum. | Superseded controls: 016 changed to default running and held walking. |
| 008 | [Vertical traversal greybox](008_traversal_greybox.txt) | Added an advanced traversal course, modular blocks, anchors and fall recovery. | Evolved: opening repairs, world relocation, checkpoints and later manual scene edits followed. |
| 009 | [Opening traversal repair](009_traversal_blocker_fix.txt) | Diagnosed the non-spatial Allomancy parent and adjusted the jump/gravity pair. | Spatial fix retained; numeric tuning superseded by 012. |
| 010 | [Shared force foundation](010_force_foundation.txt) | Introduced shared force/impulse response and velocity-dependent Allomantic terminal response. | Current foundation; later tuning, combat adapters and controls extend it. |
| 011 | [Movement Lab](011_movement_lab.txt) | Added a forgiving practice area alongside the advanced course. | Evolved: hub routing and location changed in 014; current layouts include later manual edits. |
| 012 | [Locomotion and Allomancy tuning audit](012_baseline_tuning.txt) | Recorded movement, jump/gravity and force tuning plus an unresolved ledge-launch investigation. | Historical baseline; control semantics changed in 016. The unresolved issue is not treated as fixed. |
| 013 | [Playtest shell](013_playtest_shell.txt) | Added menus, settings, pause/restart flow and target feedback around the existing world. | Evolved: hub entry and later control settings replaced parts of the original launch flow. |
| 014 | [Prototype world organization](014_prototype_world.txt) | Organized the hub, Movement Lab, Allomancy Trial, Systems Workshop and Mini City. | Evolved: subsequent milestones and the developer's current scene edits are authoritative. |
| 015 | [Ability and reserve foundations](015_ability_and_reserve_foundations.txt) | Added reusable ability lifecycle, Allomantic reserves, HUD and checkpoint integration. | Evolved: burn semantics changed in 017; the temporary refill station was later retired. |
| 016 | [Control cleanup](016_control_cleanup.txt) | Established revised semantic bindings, default running/held walking and temporary V/B powers. | Partially superseded: 017 replaced V/B with Focus routing and enabled the wheel. |
| 017 | [Burn, metal wheel and Focus](017_burn_wheel_focus.txt) | Separated burn state from engagement and introduced wheel/Focus routing with settings. | Current foundation; 018 added Pewter to the earlier wheel/state setup. |
| 018 | [Pewter burn and debt](018_pewter_burn.txt) | Added Pewter reserve/burn behavior, stat effects and deferred damage debt. | Current foundation; replenishment in 019 does not forgive debt. Refill-station references are historical. |
| 019 | [Metal consumables](019_metal_consumables.txt) | Added authored single/multi-metal recipes, inventory Use, timed absorption and repeatable Workshop supplies. | Current foundation; the old refill station mentioned in its route notes was subsequently removed. |

| 020 | [Crouch, origin and greybox](020_crouch_origin_greybox.txt) | Replaced Walk with crouch, set three reserves to 200, added a chest force origin and opt-in prototype materials. | Current implementation; owner gameplay evaluation pending. |

| 021 | [Loose Metal Capture v0.1](021_loose_metal_capture.txt) | Added opt-in LIGHT prop capture, maintained targeting and constrained force-based aim/release. | Current implementation; owner manipulation-feel testing pending. |

| 022 | [Capture control refinement](022_capture_control_refinement.txt) | Replaced the spring with collision-checked positional control, COM alignment and clean release. | Current correction after owner feedback; manual retesting pending. |

| 023 | [Blended damped capture](023_blended_damped_capture.txt) | Replaced frozen follow with physics-callback damping, interpolated visuals and captured-release geometry/impulse. | Current implementation; owner smoothness acceptance pending. |

| 029 | [Combat rewards, Intelligence and ladders](029_combat_intelligence_ladders.txt) | Adds authored Court clues/rewards, inventory Intelligence tab and reusable parametric ladder. | Implemented; conservative checks passed, owner gameplay evaluation pending. |
| 030 | [Ambient Creatures v0.1](030_ambient_creatures.txt) | Reusable sensing-only creatures, ground/flying definitions, spawners and five Mini City prototype groups. | Implemented; conservative checks only, manual gameplay validation pending. |
| 031 | [Ambient Creature corrections](031_ambient_creature_corrections.txt) | Larger reaction radii and spawner-owned group respawn gated by player distance. | Implemented; parser/static checks passed, owner gameplay testing pending. |

## Ordering evidence and uncertainty

Numbering follows the first milestone represented, not the report's last edit or filesystem timestamp. Git dates below are **commit dates**, not claims of exact implementation dates.

- **001–002:** separate commits `99f9971` and `f78cea4` on 2026-09-10 establish equipment followed by full equipment.
- **003–004:** both first appear in `cdc4fc1` on 2026-09-10. Stats precede Allomancy here because the Allomancy report describes stat-driven movement, but the exact within-commit order is not recorded.
- **005–006:** both first appear in `7eaedec` on 2026-09-11. Both correct the first Allomancy prototype; their relative order is uncertain and the numbering is an archive convention, not a proven sequence.
- **007:** `82c2985` on 2026-09-11 follows those corrections.
- **008–013:** all first appear in `6bae32e` on 2026-09-11. Contents establish course → opening blocker repair → shared force foundation → Movement Lab, and the tuning audit discusses that lab and force model. The shell wraps both courses. **The relative order of the tuning audit and shell is uncertain.** The Movement Lab report also contains a later shell launch instruction, illustrating why current report text cannot prove every original step.
- **014:** `bf3ce47` on 2026-09-13 establishes the hub/world reorganization.
- **015:** `6e97ebe` on 2026-09-13 establishes ability/reserve foundations.
- **016–017:** both first appear in `0733e7c` on 2026-09-13. The cleanup report explicitly anticipates Focus and its historical note points to the wheel milestone, establishing their order.
- **018:** `6721c4d` on 2026-09-13 adds Pewter.
- **019:** an uncommitted report from the subsequent metal-consumables implementation in this task; its integration depends on inventory, reserves and Pewter. No implementation date is assigned from filesystem timestamps.

**004 is a cumulative record.** It begins with the 2026-09-10 foundation but received later combat/world-metal material in commits `e6a6856`, `ecc673c`, `d09059d` (2026-09-12) and `99ed236` (2026-09-13), before the world reorganization. It remains intact rather than being split or rewritten into a falsely single-date report.

The Git history includes earlier player-controller, NPC/dialogue, inventory, health and enemy milestones, but no standalone reports for them were found. No retrospective records were invented to fill those gaps.

## Original filename mapping

| Original root filename | Archived filename |
| --- | --- |
| `EQUIPMENT_MILESTONE.md` | [001_equipment.txt](001_equipment.txt) |
| `FULL_EQUIPMENT_MILESTONE.md` | [002_full_equipment.txt](002_full_equipment.txt) |
| `PLAYER_STATS_MILESTONE.md` | [003_player_stats.txt](003_player_stats.txt) |
| `ALLOMANCY_MILESTONE.md` | [004_allomancy_and_combat.txt](004_allomancy_and_combat.txt) |
| `PLAYER_TRACTION_CORRECTION.md` | [005_player_traction.txt](005_player_traction.txt) |
| `WORLD_PHYSICS_BASELINE.md` | [006_world_physics.txt](006_world_physics.txt) |
| `SPRINT_MILESTONE.md` | [007_sprint.txt](007_sprint.txt) |
| `TRAVERSAL_GREYBOX.md` | [008_traversal_greybox.txt](008_traversal_greybox.txt) |
| `TRAVERSAL_BLOCKER_FIX.md` | [009_traversal_blocker_fix.txt](009_traversal_blocker_fix.txt) |
| `PHYSICS_FORCE_FOUNDATION.md` | [010_force_foundation.txt](010_force_foundation.txt) |
| `MOVEMENT_LAB.md` | [011_movement_lab.txt](011_movement_lab.txt) |
| `BASELINE_TUNING_AUDIT.md` | [012_baseline_tuning.txt](012_baseline_tuning.txt) |
| `PLAYTEST_SHELL.md` | [013_playtest_shell.txt](013_playtest_shell.txt) |
| `PROTOTYPE_WORLD_MILESTONE.md` | [014_prototype_world.txt](014_prototype_world.txt) |
| `ABILITY_FOUNDATIONS_MILESTONE.md` | [015_ability_and_reserve_foundations.txt](015_ability_and_reserve_foundations.txt) |
| `CONTROL_CLEANUP.md` | [016_control_cleanup.txt](016_control_cleanup.txt) |
| `BURN_WHEEL_FOCUS_MILESTONE.md` | [017_burn_wheel_focus.txt](017_burn_wheel_focus.txt) |
| `PEWTER_BURN_MILESTONE.md` | [018_pewter_burn.txt](018_pewter_burn.txt) |
| `METAL_CONSUMABLES_MILESTONE.md` | [019_metal_consumables.txt](019_metal_consumables.txt) |

## Preservation and scope

- Root `README.md` remains the project overview, not a milestone archive entry. Its existing conflict-marker content is left intact; only the old report-location sentence now points here and to the contribution rules.
- No runtime/tooling references to the moved report paths were found. Cross-references between reports were updated to the numbered filenames, including historical changed-file lists; the mapping above preserves the original names.
- The obsolete MetalRefillStation remains described in older reports intentionally. Its later removal does not invalidate the historical record; current scenes are authoritative.
- No gameplay/code/scene/resource/configuration/imported-asset changes or gameplay tests are part of this archive task.
- Files were moved without staging or committing existing work. High content similarity supports Git rename detection when the archive is later staged; use the original-name mapping when following history across extension changes.
