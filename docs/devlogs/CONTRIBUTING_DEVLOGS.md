# Contributing development records

Codex and other contributors should read these rules before documenting a new milestone.

- Put new milestone documentation in `docs/devlogs/`; do not scatter implementation-report `.txt` files around the root or other project folders.
- Use the next unused three-digit chronological number and a concise descriptive name: `020_<descriptive_name>.txt` is the next slot after the initial archive. Check the directory before choosing a number.
- Append new milestones in development order. Do not renumber existing records routinely. For a newly discovered older report, explain its historical position and uncertainty in the index rather than silently rewriting the sequence.
- Update `README.md` in this folder with the sequence, milestone name, a concise description, and a supported current/evolved/superseded status. Separate chronology evidence from inference.
- Keep existing technical records useful even after implementation changes. Preserve obsolete descriptions as history; document later replacements in new records and index annotations.
- These records are source material for future public itch.io devlogs. Do not automatically rewrite them as polished public posts.

## What each record should contain

A small header may identify the milestone, approximate development order and original filename when applicable. Include dates only when supported by reliable evidence; distinguish commit dates from implementation dates.

Record:
1. The problem or milestone being addressed.
2. What was actually implemented and the relevant files.
3. Important design and architecture decisions, including alternatives or tradeoffs when useful.
4. Integration with existing systems and authoritative state ownership.
5. Limitations and technical debt discovered.
6. Relevant manual testing instructions and developer-supplied testing notes/results, with their source and scope.

Clearly distinguish implemented facts from planned or future ideas. Retain project-root-relative paths for code/scenes/resources; use archive-relative filenames for links to other records.

## Evidence and testing language

- Do not fabricate playtest results, completion claims, player reactions or validation.
- The project owner's own developer testing is **not an external playtest**.
- Do not call a feature player-validated unless actual external playtest evidence exists.
- Separate suggested manual steps, automated/static checks, developer testing, and external playtests. A test checklist is not a record of tests performed.
- When the developer supplies results, record what they observed without extending it into unsupported claims.
- Report unresolved problems and uncertainty honestly; do not turn plans into completed features.

## Documentation-only changes

Before moving an existing report, inspect references. Update documentation-only references safely; do not change runtime behavior to support an archive move. Preserve original names in an index mapping. Do not alter gameplay code, scenes, resources or the developer's level edits during documentation organization.

