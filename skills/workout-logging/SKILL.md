---
name: workout-logging
description: Use after any training session is reported, when the user runs /fitness-log, or when adding a weight-only entry. Enforces the canonical Gym / Swim / Weight templates from workout-log.md exactly — no invented fields, no reordered headers, no skipped sections.
---

# Workout Logging Skill

Log every training session and weight entry to `<data-dir>/workout-log.md` using the canonical templates below. Copy the template exactly — same field order, same headers, same markdown structure.

---

## Where to Append

- **Gym or Swim sessions:** append a new entry under the `## Sessions` heading in `<data-dir>/workout-log.md`.
- **Weight-only entries (no workout):** add a row to the `## Weight Log` table in the same file. Do not create a session block.
- **Never write workout data to:** `CLAUDE.md`, `week-{N}-plan.md`, any file under `memory/`, or any other file.

---

## Canonical Templates

### Gym Entry Template

```
### W{N}D{N} — {YYYY-MM-DD} — Gym {A/B/—}: {Session Name}
- **Weight (AM):** {kg} | **Duration:** {min} | **Location:** {gym, city} | **Overall RPE:** {1–10}

| # | Exercise | Set 1 | Set 2 | Set 3 | Set 4 | Set RPE | Notes |
|---|---|---|---|---|---|---|---|
| 1 | {name} | {load×reps or time} | … | … | … | {RPE} | {brief} |

**Notes:** {what happened, deviations from plan, equipment quirks}
**Observations:** {soreness, sleep, energy, recovery signals}
**Next session adjustments:** {what changes next time, or "hold"}
```

### Swim Entry Template

```
### W{N}D{N} — {YYYY-MM-DD} — Swim: {Session Name}
- **Weight (AM):** {kg} | **Duration:** {MM:SS} | **Location:** {pool, city} | **Overall RPE / Effort:** {1–10 + descriptor}

| Field | Value |
|---|---|
| Distance | {m} ({laps} × 12 m) |
| Avg pace | {x'xx"/100m} |
| Strokes | {Breaststroke xxx m, Mixed xxx m, …} |
| Avg HR | {bpm or —} |
| Active Cal / Total Cal | {x / y} |

**Notes:** {what happened, deviations from plan}
**Observations:** {soreness, sleep, energy, recovery signals}
**Next session adjustments:** {what changes next time, or "hold"}
```

### Weight-only Entry

Add a row to the `## Weight Log` table. Do not create a session entry.

```
| {YYYY-MM-DD} | {weight} | {notes or —} |
```

---

## Set-Cell Format Rules

| Situation | Format | Example |
|---|---|---|
| Weighted exercise | `{load}×{reps}` | `27.5×8` |
| Bodyweight exercise | `{reps} BW` | `6 BW` |
| Time-based hold | `{seconds}s` | `60s` |
| Unused set column | `—` | `—` |

Use em dash (`—`) for unused columns, not a hyphen or blank.

---

## Unilateral-Set Halving Convention

When reading from Hevy, unilateral exercises (e.g., single-arm rows, Bulgarian split squats) are logged as one Hevy set per side. Four Hevy set entries = 2 sets per side. Always prescribe and record as "2 sets per side" — do not double-count.

Example: Hevy shows 4 sets of Romanian single-leg deadlift → log as 2 sets per side in the set table, note "(unilateral)" in the Notes column.

---

## RPE Field Rule

- **Preferred:** compute Overall RPE as the average of the set-level RPEs from Hevy. Round to one decimal place.
- **Fallback:** if no set-level RPEs exist in Hevy data, ask the user for their perceived overall RPE before closing the log entry.
- Never leave the Overall RPE field blank or set it to `—` without first asking the user.

---

## Explicit Forbiddens

- Do NOT invent new fields (e.g., "Calories", "Heart Rate", "Mood") not present in the template.
- Do NOT reorder fields within a template entry.
- Do NOT skip section headers (`**Notes:**`, `**Observations:**`, `**Next session adjustments:**`).
- Do NOT write session or weight data to `CLAUDE.md`, `week-{N}-plan.md`, any `memory/*.md` file, or any file other than `<data-dir>/workout-log.md`.
- Do NOT merge two sessions into one entry block.
- If a field value is unknown, write `—` or `not logged` — never omit the field line.
