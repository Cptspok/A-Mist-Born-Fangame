# Court dossier authoring

1. Create a `CourtTargetDefinition` resource. Set a stable, globally unique `unique_id`, `display_name`, and `portrait`. Optional unknown name/portrait customize its undiscovered presentation.
2. Add any number of `CourtIntelFieldDefinition` resources to `dossier_fields`. Give each a non-empty ID unique **within this target**, a display label, revealed text, and display order. Save individual fields as `.tres` resources for easy reuse in clues. Equal display orders follow the target array order. There are no mandatory dossier categories.
3. Create an `IntelligenceClueDefinition`, give it a globally unique ID, document name/text/source, and assign its target. Enable `reveals_identity` and/or `reveals_portrait` as desired. Drag one or several of that target's field resources into `revealed_fields`. An empty list is valid for identity-only documents. Reveals use stable field IDs and display the target's canonical field content; foreign/empty IDs are ignored with a warning.
4. Add the target to `resources/intelligence/catalog.tres` (or the catalog assigned to RespawnSession). Assign it to the intended enemy's **Court Target** property. Assign clues to `EnemyRewardDefinition.intelligence_clues` on the intended enemy/group reward resource. Existing item rewards can coexist unchanged. `associated_clue_ids` on the target is optional authoring metadata, not a reveal gate.
5. Optional map integration: fill district/region/position and set `map_reveal_field_id` to one of this target's field IDs. Revealing that field reveals the map location. Leave it empty for a target without clue-driven map disclosure. No field must be named Location.

## Runtime rules

Definitions never store discovery or status. IntelligenceKnowledge stores collected clue IDs, identity/portrait knowledge, revealed field ID sets per target, and Unknown/Alive/Defeated status. Live Court actor registration sets Alive only when no runtime status exists. Its existing health death signal sets Defeated and reveals identity/portrait immediately, even with zero clues. Optional fields remain hidden until their clues are collected. Later clues only add knowledge, never modify status.

Knowledge retains the existing session/checkpoint lifecycle: checkpoint reloads preserve it (including Defeated status); session reset clears it. This pass does not change enemy respawning or add disk persistence.

## Mini City migration

- Sealed collection order: identity, portrait, and Profile (the existing collector/uniform/shield dossier text).
- Service-yard delivery note: Location (East service yard) and its linked map disclosure. Original delivery document text remains intact.
- Guard combat report: Tactical information (the existing sword/shield, no ranged attack, keep-distance text).

Existing clue IDs, rewards, item collection paths, actors, transforms and encounter scenes remain unchanged.

## Manual check

Open Intelligence with no clues: Name, portrait/placeholder and runtime Status are present; optional rows are absent. Collect the three documents and verify only their assigned fields appear in order. In a fresh session, defeat Voss before collecting all clues: identity/portrait and Defeated status appear without revealing missing optional fields. Collect remaining documents and verify Defeated persists. Check normal loot and world items, then author a target with different field labels and one clue referencing multiple fields.
