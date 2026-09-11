# Playtest Shell v0.1

Launch the configured project normally. The startup scene is now `scenes/playtest_shell.tscn`; the existing `scenes/main.tscn` environment is instantiated beneath the shell only after Play. There is still one Player and one shared environment per session. Both lab and advanced layouts, locomotion and force tuning are unchanged.

## Menu and session flow

- Main: **MISTBORN PROTOTYPE → Play / Settings / Controls / Quit**.
- Play: **Movement Lab / Advanced Traversal / Back**. Both choices load the same environment. Lab starts at world (45,0.95,49), facing +Z into the lab. Advanced retains its authored Player spawn and orientation.
- A fresh session from Main shows a single Controls card, populated from live bindings, with **Start**. It freezes the scene and releases the mouse. Restart skips this card.
- Escape in gameplay: **Resume / Settings / Controls / Restart Test / Main Menu / Quit**.
- Settings/Controls Back or Escape returns to its parent menu. Escape on Main never quits. Escape from the intro opens Pause, from which Resume begins gameplay.
- Restart Test replaces the entire environment instance, restoring loose bodies and scene-authored state at the chosen destination. F6 invokes the same restart while normal gameplay owns input. Returning to Main closes inventory and dialogue, removes the environment and its Player, and clears shell references.
- The existing single fall-reset Start marker is repositioned at session launch to the chosen spawn. This is runtime-only: no checkpoint system or authored layout changes. Falling in a Lab session returns to its lab entrance; Advanced sessions retain their normal start.

## Pause, locks and mouse ownership

The shell/UI root uses PROCESS_MODE_ALWAYS. The environment root explicitly uses PROCESS_MODE_PAUSABLE, so actual Pause freezes gameplay, AI and physics without disabling menu controls. Settings and the intro also pause gameplay. Main has no live gameplay environment.

Pause does not acquire/release an inventory/dialogue lock or zero Player velocity. SceneTree pause is its own control boundary, preserving physics state. Resume unpauses the scene but leaves named gameplay locks intact: Player's existing lock check still blocks camera/movement during active dialogue. The shell captures the mouse only when its page is gameplay and GameplayLocks reports no remaining owner; otherwise the mouse is visible.

Inventory retains its existing pause/lock behavior. Escape while inventory is open belongs to inventory and closes it; a subsequent Escape opens Pause. A minimal input guard prevents opening inventory over an already-paused shell menu. Thus inventory cannot close and accidentally unpause an active shell menu. Inventory drag/drop and presentation are unchanged.

Dialogue may be paused. Resume returns to the still-active dialogue; normal dialogue advancement/closure then releases its lock. Mouse remains free while the dialogue owns the lock, preventing a shell submenu from recapturing it prematurely. This is a minimal coordination change, not a gameplay-state refactor. Other future pause owners should follow the same explicit ownership policy.

UI layering: existing HUDs stay as authored; crosshair layer 2 hides for any paused/locked interface; existing dialogue layer 10 remains unchanged; shell menus/intro are layer 100 over everything. Player health, equipment, weapon and pickup presentation remain in the original environment.

## Settings and data

`PlaytestSettings` autoload stores only settings in **user://playtest_settings.cfg** via ConfigFile. There is no gameplay save data. Defaults: sensitivity 0.1 degrees/pixel, all three volumes 1.0, Windowed. Changes save immediately and sensitivity applies to the active Player immediately; newly launched Players receive the persisted value.

Settings include sensitivity (0.01–0.5), Master/Music/SFX volumes (0–1), and Windowed/Fullscreen. Display switching is skipped on the headless renderer. No resolution/quality controls or borderless option were added. A save failure reports an engine warning. OS filesystem/display failures still need normal desktop verification.

`default_bus_layout.tres` supplies **Master**, **Music → Master**, **SFX → Master**. Sliders set each bus's gain and mute at zero. No sound/music assets were added; future AudioStreamPlayers must choose Music or SFX rather than leaving every sound routed directly to Master.

`PlaytestControls` defines presentation groups and semantic action names, while binding text comes from existing `InputHint.binding()` and InputMap. Only existing actions display. As with the current helper, the first binding is the displayed primary binding. No rebinding was implemented. New semantic `pause` (Escape) and `reset_test` (F6) actions are in project settings. The existing standalone traversal reset now reads `reset_test` instead of checking a literal physical key. Running main.tscn directly from the editor still bypasses shell menus and uses its ordinary reload; launch the configured project to test this shell.

## Player target feedback

The neutral centered crosshair becomes gold for an available selected tether. A small gold ring marks its volume center, with a faint line from the crosshair to that point. It observes `AllomancyTargeting.selected`; it performs no overlap/range/LOS search, scoring or selection. Unselected/off-aim metal does not get an independent UI availability claim. Aim until gold feedback confirms the current target.

Developer T/debug remains a separate observer showing volumes, classes and force data. It defaults off for fresh shell sessions, and its label now also hides when debug is off. Turning T on retains existing diagnostics. Player feedback itself exposes no force/class calculations. Crosshair/marker are hidden during pause, inventory, dialogue and intro.

## Files

Added: `scenes/playtest_shell.tscn`, `scripts/playtest_shell.gd` (session/menu state), `scripts/playtest_menu_view.gd` (replaceable prototype presentation), `scripts/playtest_controls.gd` (action groups), `scripts/playtest_settings.gd` (settings persistence/application), `scripts/playtest_target_feedback.gd` (target presentation), `default_bus_layout.tres`, generated script UID sidecars and this report.

Modified: `project.godot` (startup, settings autoload, pause/reset actions), `scripts/inventory_ui.gd` (paused-shell input guard), `scripts/traversal_course.gd` (semantic reset action), `scripts/allomancy_debug.gd` (hide developer label when debug is off). No environment scene or physics code was changed.

## Validation and exact manual test

Godot parser/import and one bounded headless startup sanity run passed. That run instantiated the shell, opened Controls and Settings, launched Lab intro, resumed, visited Pause→Controls, restarted and returned to Main. It confirmed lab spawn, paused intro, Pause as submenu parent, scene cleanup, three buses and Escape/F6 semantic bindings. No dedicated automated suite was added, no settings were saved by the sanity check, and no detailed desktop input/display/audio playtest is claimed.

1. Launch normally: Main Menu and free mouse. Open Controls; compare shown movement, combat and developer bindings. Escape returns to Main.
2. Settings: change sensitivity and all volume sliders; switch fullscreen/windowed. Back, quit and relaunch; confirm persistence. Actual audio loudness awaits routed sound assets.
3. Play→Movement Lab: read the one-page Controls card; Start. Confirm mouse capture, normal movement, neutral crosshair, then gold marker when aiming at metal. Push/Pull; toggle T and compare developer diagnostics.
4. Open/close inventory using its normal keys, including Escape. Then Escape again should open Pause. Resume and check mouse/camera.
5. Pause→Controls→Back, and Pause→Settings→Back: both return to Pause. Adjust sensitivity and Resume; test camera response immediately.
6. Start dialogue in the retained yard. Escape→Pause→Resume; dialogue should still own input. Finish dialogue, then confirm camera control and mouse capture return.
7. Move loose props and open Pause→Restart Test. Confirm props and Player reset to the lab entrance without intro. Check F6 and an intentional fall also use the intended session flow.
8. Pause→Main Menu. Play→Advanced Traversal: confirm a fresh controls card and advanced spawn. Repeat restart and verify it retains this destination.
9. Quit from either menu. Confirm no stuck cursor or stale scene/locks on another launch.

Known limits: prototype layout/fonts, mouse/keyboard only, no full rebinding, no sound assets, no permanent onboarding flag and no graphics-quality controls. Display behavior, persistence across a real application restart, inventory/dialogue interactions and visual target readability remain manual checks. Directly launching the old gameplay scene in the editor intentionally bypasses the shell.
