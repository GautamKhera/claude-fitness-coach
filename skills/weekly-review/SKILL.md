---
name: weekly-review
description: Use on the user's weekly review day (Sunday by default, configurable in their CLAUDE.md) or when they run /fitness-review. Reads the active week plan and that week's workout-log entries, analyzes weight trend / RPE drift / volume tolerance / adherence, proposes adjustments, and on approval generates the next week-N+1-plan.md from the canonical template.
---

# Weekly Review Skill

Run this skill on the user's designated review day (default: Sunday) or when `/fitness-review` is invoked.
Locate the user's data directory via `.fitness-coach.json` at the project root or a parent directory.
Read `primary_goal` from `.fitness-coach.json` — it governs which weight-trend rules apply in Step 2.

---

## Step 1 — Read

1. Open `week-{N}-plan.md` (the currently active plan file). Identify N from the filename.
2. Open `workout-log.md`. Extract all entries whose date falls within Week N (Mon–Sun of the plan dates).
3. Note: if the user has not logged any sessions this week, proceed with adherence = 0 and skip the RPE/volume sub-analyses.

---

## Step 2 — Analyze

### 2a. Weight trend (7-day rolling average vs goal)

Compute the rolling 7-day average from the Weight Log table in `workout-log.md`.
Compare to the goal rate defined by `primary_goal`:

**fat_loss**
- On track (0.5–0.8 kg/wk loss sustained) → hold calories and cardio volume.
- Slow (<0.4 kg/wk for 10+ days) → recommend −150 kcal/day OR add one cardio session.
- Fast (>1.0 kg/wk for 10+ days) → recommend +150 kcal/day to protect muscle.

**muscle_gain**
- On track (~0.2–0.4 kg/wk for novice/intermediate) → hold surplus and volume.
- Too slow (<0.2 kg/wk for 10+ days) → recommend +150 kcal/day.
- Too fast (>0.6 kg/wk for 10+ days) → recommend −150 kcal/day to limit fat gain.

**strength**
- Bodyweight is secondary. Focus on top-set load trend week-over-week.
- Flag if bodyweight is falling while loads are staying flat — this may indicate the cut is interfering with recovery capacity.

**maintenance**
- Any sustained drift of ±0.5 kg or more over 14 days is flagged.
- Recommend a gentle nudge to caloric balance (±100–150 kcal/day).

**general_fitness / sport_specific**
- Weight is informational only. Do not trigger caloric adjustments from weight alone.
- Flag extreme deviations (>1.5 kg shift in either direction over 14 days) for awareness.

### 2b. Lift RPE patterns

For each gym session logged in Week N:
- If any top working set is logged at ≤ RPE 6: flag as a progression trigger for that exercise.
- If any top working set dropped to RPE 9 unprompted (no change in load or reps from prior week): flag as an overload signal.

**Progression rule:** load stays week-to-week by default. Advance only when the top working set of a given exercise was ≤ RPE 6 this week — add 2.5 kg or 1 rep (whichever is appropriate for the lift). If the top set hit RPE 9 unprompted, drop load 5% next session.

### 2c. Modality-specific volume tolerance

For each conditioning modality logged (swim laps, run distance/duration, bike distance, row meters, etc.):
- Note total weekly volume vs the plan target.
- Check for recovery signals (user-reported soreness, pace drift, RPE elevation across the week).
- Flag any modality where volume was missed by >20% or where recovery signals suggest overreach.

### 2d. Adherence

Count sessions: planned vs completed, missed, skipped (intentional), and substituted.
- Missed = no entry in `workout-log.md` for a scheduled session day.
- Skipped = logged as "skipped" with or without a reason.
- Substituted = different modality or variant recorded (e.g., Swim-Alternate instead of Swim).

Report adherence as: `X / Y sessions completed (Z skipped, W substituted)`.

---

## Step 3 — Propose adjustments

Present findings and one best recommendation in chat. Structure:

```
### Week N Review

**Weight trend:** [summary] → [recommendation or "hold"]
**Lift RPE signals:** [per-exercise flags, or "none"]
**Volume tolerance:** [per-modality note, or "on track"]
**Adherence:** X / Y sessions completed

**Recommended adjustment for Week N+1:**
[One clear action. If multiple changes are warranted, rank and present the top one first.]

**Risks to flag:**
[Any red-flag conditions. If none, omit this section.]
```

Do not propose more than one primary adjustment unless the risks of inaction are high. If the user asks for options, provide at most two with trade-offs noted.

---

## Step 4 — Generate Week N+1 plan (on approval only)

When the user approves the proposed adjustments:

1. Open `week-plan-template.md` from the data directory (copied there during onboarding).
2. Create `week-{N+1}-plan.md` in the same directory by filling in:
   - **Dates:** Mon–Sun of the upcoming week (ISO format, e.g., `2026-06-02`).
   - **Focus statement:** one line reflecting the key adjustment (e.g., "Calorie hold week — consolidate W5 loads before progressing").
   - **Targets:** updated weight projection or performance target per goal type.
   - **Session tables:** carry forward all exercises with updated loads/volumes per the Step 2 analysis. Apply progression triggers identified in 2b. Do not change exercises that showed no RPE signal.
   - **Conditioning tables:** apply volume adjustments from 2c.
   - **Adjustments section:** state what changed, why, and cite the specific workout-log evidence (e.g., "OHP top set logged at RPE 6 on 2026-05-28 → advancing to 22.5 kg").
3. Do not modify `week-plan-template.md` — it is the master skeleton.

---

## Step 5 — Push to Hevy (explicit sign-off required)

If the adjustments in Week N+1 require changes to Hevy routines (different exercises, updated loads in the routine definition):

- Do NOT push until the user explicitly confirms with a clear affirmation (e.g., "yes, push to Hevy" or "go ahead and update Hevy").
- State exactly what will change before pushing: routine name, exercise, old value → new value.
- Hevy writes are irreversible from the API side — treat them as permanent unless the user manually edits via the Hevy app.
- After a successful push, log the routine ID and timestamp in the Adjustments section of `week-{N+1}-plan.md`.
- If no routine changes are needed (load adjustments are plan-only, not pushed to Hevy), skip this step and say so.
