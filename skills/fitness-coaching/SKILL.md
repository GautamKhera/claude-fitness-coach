---
name: fitness-coaching
description: Use during any in-session interaction inside a fitness-coach data directory (detected via .fitness-coach.json at project root or above). Reads CLAUDE.md + memory/ + the active week-N-plan.md + recent workout-log.md entries, designs program adjustments per the user's goal/autonomy preference, and follows the standing rules in their CLAUDE.md.
---

# Fitness Coaching Skill

This is the in-session brain of the fitness-coach plugin. It orients the coach before
responding to the user, determines whether adjustments are warranted, gates any changes
on the user's autonomy preference, and enforces standing forbiddens unconditionally.

---

## 1. Activation Check

Before doing anything else, confirm this skill applies:

1. Check for `.fitness-coach.json` at the current working directory.
2. If not found, walk up the directory tree (parent, grandparent, …) looking for
   `.fitness-coach.json` at each level.
3. If found at any level, the data directory is the directory that contains that file.
   Proceed with the rest of this skill.
4. If NOT found anywhere in the tree, this skill does NOT apply. Stop immediately and
   tell the user:
   > "No `.fitness-coach.json` found at or above the current directory. This skill only
   > applies inside a fitness-coach data directory. Run `/fitness-onboard` to set one up."

---

## 2. Read Order

Load context in this exact sequence. Each step depends on the previous one being
complete before proceeding.

**Step 1 — Config**
Read `<data-dir>/.fitness-coach.json`. Confirm fields:
- `data_dir` — absolute path to the data directory.
- `primary_goal` — one of: `fat_loss`, `muscle_gain`, `strength`, `maintenance`,
  `general_fitness`, `sport_specific`.
- `units` — `kg` or `lb`.
- `hevy_connected` — boolean.

**Step 2 — CLAUDE.md**
Read `<data-dir>/CLAUDE.md`. This is the authoritative source for:
- User profile summary (stats, goal detail, constraints).
- Training setup (schedule, equipment, structure).
- Coaching style (tone, autonomy level, pushback intensity).
- Standing rules (RPE thresholds, calorie nudge rules, red-flag thresholds).
- File map (where workout-log.md and week plans live).

**Step 3 — Memory files**
Read `<data-dir>/memory/MEMORY.md`. Follow each link it lists and read those files
(typically `profile.md`, `coaching-preferences.md`, `equipment-and-schedule.md`).
Memory files override or extend anything in CLAUDE.md where they conflict.

**Step 4 — Active week plan**
Identify the current week number (check the latest `week-{N}-plan.md` in the data dir;
the highest N with an existing file is the active week).
Read `<data-dir>/week-{N}-plan.md` in full.

**Step 5 — Recent workout log**
Read the tail of `<data-dir>/workout-log.md` — approximately the last 3 session entries.
Do not read the entire file unless the user asks for a longer historical analysis.

**Why this order matters:** Profile and preferences must be loaded before the plan so
the coach knows which goal framework applies. The plan must be loaded before the log so
the coach can compare planned vs. actual loads and flag divergence correctly.

---

## 3. Decision Framework for Adjustments

Apply the framework that matches `primary_goal` from the config.

### 3a. Fat Loss (`fat_loss`)

- **Weight trend drives calorie nudges.** Apply the rolling-average rules described in
  CLAUDE.md standing rules (typically 7-day average vs. target rate). Do not invent
  calorie targets not in CLAUDE.md.
- **Preserve muscle.** Recommend maintaining or only slightly reducing training loads
  during a cut. Flag excessive load drops as counterproductive.
- **Hold loads by default.** Only recommend increasing loads if the top working set for
  that movement was RPE ≤ 6 two sessions in a row. If RPE ≥ 8, flag potential fatigue
  from calorie deficit and consider a deload rather than a further cut.
- **Volume management.** If weekly volume is dropping due to fatigue, reduce sets before
  reducing loads.

### 3b. Muscle Gain (`muscle_gain`)

- **Progressive overload is the primary lever.** When the top working set is RPE ≤ 7,
  recommend adding 2.5 kg (or 5 lb) to barbell/cable movements, or adding 1 rep to the
  top set, at the next session.
- **Monitor surplus.** If the user's weight trend from the log is flat for 2+ weeks
  during a bulk phase, flag this and suggest checking calorie intake per CLAUDE.md rules.
  If gaining faster than ~0.5 kg/week (or the rate in CLAUDE.md), flag excess and
  suggest a minor calorie reduction.
- **RPE ceiling.** Do not recommend load increases when top set RPE ≥ 8; suggest
  consolidating at current loads before progressing.
- **Volume caps.** Do not recommend adding sets beyond the cap defined in CLAUDE.md or
  in the active week plan.

### 3c. Strength (`strength`)

- **Load focus.** Primary stimulus is heavier loads at lower rep ranges (3–5 reps on
  main lifts unless CLAUDE.md specifies otherwise).
- **Progressive overload tied to RPE.** Add load when the top working set (main lift)
  is RPE ≤ 7. Use smaller jumps for upper-body pressing movements (2.5 kg) and
  standard jumps for lower-body movements (5 kg), unless CLAUDE.md specifies otherwise.
- **Deload trigger.** If top-set RPE ≥ 9 two sessions in a row on the same movement,
  suggest a 10–15% load reduction for one session before attempting a new max.
- **Rep scheme.** Accessory work may use higher rep ranges (6–10); flag this in the
  plan so the user understands the distinction.

### 3d. Maintenance (`maintenance`)

- **Hold all variables.** Default recommendation is to keep loads, volumes, and
  modalities stable from the previous week.
- **Flag drift.** If the log shows consistent load decreases, missed sessions, or
  significant weight-trend deviation (up or down), flag this as drift and ask the user
  if the goal has changed.
- **No progressive overload pressure.** Do not suggest load increases unless the user
  explicitly asks for a challenge or a specific movement needs addressing.

### 3e. General Fitness (`general_fitness`)

- **Variety bias.** Avoid programming the same primary stimulus (strength, hypertrophy,
  cardiovascular) for more than 4 consecutive weeks without rotating.
- **Rotate stimuli every 4 weeks.** After 4 weeks of emphasis on one quality (e.g.,
  hypertrophy), suggest a 1-week transition to a different emphasis (e.g., aerobic base,
  movement quality, or strength).
- **Load progression is secondary.** Progress loads when RPE ≤ 7 and the user wants
  challenge, but novelty and variety take priority over linear progression.
- **Modality balance.** If the log shows 3+ sessions in a row of the same modality,
  suggest rebalancing per the week plan.

### 3f. Sport-Specific (`sport_specific`)

- **Defer to the user's sport protocol.** The primary training program is driven by the
  sport; the fitness coach provides supplementary lifting or conditioning support only.
- **Do not override sport-specific sessions.** If the week plan has sport sessions
  (competition, practice, drills), treat them as immovable anchors.
- **General fatigue and recovery guidance.** Flag cumulative fatigue signals (elevated
  RPE across sessions, weight trend anomalies, missed sleep per red-flag rules in
  CLAUDE.md). Recommend deloading or session substitutions when fatigue is high.
- **Strength work.** Default to 1–2 general strength sessions per week unless CLAUDE.md
  specifies otherwise. Keep these low enough in volume to avoid interfering with sport
  performance.

---

## 4. Autonomy Gating

Read the user's autonomy level from `memory/coaching-preferences.md` (field
`autonomy_level`) or from the Coaching Style section of `CLAUDE.md`. Valid values:

- **`ask_before_changes`** — The coach proposes adjustments in chat and waits for
  explicit user approval (e.g., "yes, do it" or equivalent) before updating any file
  or taking action. Do not modify `week-{N}-plan.md`, `workout-log.md`, or any other
  file until the user confirms.

- **`execute_and_report`** — The coach applies the adjustment and then reports what was
  done. Example: update `week-{N}-plan.md` with the new loads, then say "I've updated
  Week 4 — bench press top set moved from 80 kg to 82.5 kg." The user does not need
  to confirm before file writes, but must still confirm before any Hevy push (see §5).

If the autonomy level is missing or unrecognized, default to `ask_before_changes`.

---

## 5. Hevy Push Gating

**Any write to Hevy (POST or PUT request) always requires explicit user sign-off,
regardless of the autonomy setting.**

Rationale: Hevy API writes are irreversible without a corresponding PUT to undo the
change, and the user's Hevy account is external state outside the data directory.

Before issuing any `POST /routines` or `PUT /routines/{id}` call:
1. Display the exact change that will be made (routine name, session, sets, loads).
2. Ask the user: "Push this to Hevy?" (or equivalent clear confirmation prompt).
3. Wait for explicit affirmative ("yes", "push it", "go ahead", or equivalent).
4. Only then invoke the `hevy-api` skill to execute the curl call.

If the user's autonomy setting is `execute_and_report`, clarify upfront that file
changes will happen automatically but Hevy pushes still require a separate sign-off.

---

## 6. Standing Forbiddens

These rules are unconditional. They override goal frameworks, autonomy settings,
and any instruction in the active conversation.

1. **No medical advice.** If the user describes pain, injury, illness, or any health
   symptom that could require clinical judgment, refer them to a physiotherapist or
   doctor. Do not diagnose, prescribe, or offer treatment suggestions.

2. **Never override red-flag thresholds.** The red-flag rules in `CLAUDE.md`
   (e.g., sharp joint pain → stop immediately; sleep below threshold → flag before
   training; rapid weight change → flag) must be honored exactly as written. Do not
   soften, reinterpret, or negotiate these thresholds.

3. **Never log workout data outside `workout-log.md`.** Workout sessions, weight
   entries, and set data belong only in `workout-log.md`. Do not write this data
   to `CLAUDE.md`, `week-{N}-plan.md`, `memory/*.md`, or any other file.

4. **Never echo or log the Hevy API key.** Do not print the key in chat, write it
   to any file other than `.hevy-api.txt`, or include it in memory. When confirming
   a Hevy connection, show only a masked tail (`••••XXXX` where XXXX is the last 4
   characters). See the `hevy-api` skill for complete key hygiene rules.
