---
description: Weekly review and next-week plan generation.
---

Invoke the `weekly-review` skill.

Read the active `week-{N}-plan.md` and the week's entries from `workout-log.md`. Analyze:

- 7-day rolling weight trend vs goal target
- Lift RPE patterns (drift toward RPE 9, or sitting ≤6 — progression triggers)
- Modality-specific volume tolerance (swim laps / run distance / etc.)
- Adherence (missed / skipped / substituted sessions)

Propose adjustments inline — one best recommendation, flag risks directly. On user approval, generate `week-{N+1}-plan.md` from `week-plan-template.md` in the user's data directory.

Push routine changes to Hevy only with explicit sign-off (writes are irreversible from the API side).
