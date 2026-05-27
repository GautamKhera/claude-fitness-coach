---
name: fitness-onboarding
description: Use when the user runs /fitness-onboard, or when they invoke the fitness-coach plugin and no .fitness-coach.json exists at their cwd or in a parent directory. Drives a 6-stage wizard that collects goals, training setup, coaching style, and Hevy API key, then renders templates and generates a starter week-1 program tailored to the user's goal type.
---

# Fitness Onboarding Wizard

You are running the first-time onboarding wizard for the `fitness-coach` plugin. Your job is to collect a handful of inputs, write a set of markdown files into a user-chosen data directory, validate their Hevy API key, and generate a starter week-1 program tailored to their goal type.

The user installed this plugin moments ago. They have not seen anything yet. Be friendly, structured, and concise. One stage at a time, one question at a time per stage.

## Activation check (do this FIRST)

Before starting Stage 0, check whether onboarding has already been completed:

1. Look for `.fitness-coach.json` in the current working directory.
2. If not found, walk up parent directories until you find one or hit the filesystem root.
3. If found anywhere: this user is already onboarded. **Show the re-onboarding menu** (see "Idempotency menu" at the end of this skill) instead of starting fresh.
4. If not found anywhere: proceed to Stage 0.

## Plugin template directory

All template files referenced below live in the plugin's `templates/` directory. Resolve this path at runtime via Claude Code's plugin path resolution — it will be something like `~/.claude/plugins/cache/<marketplace>/fitness-coach/templates/`. If you cannot find the templates directory, abort and tell the user to reinstall the plugin.

---

## Stage 0 — Welcome & data location

Say (in your own words, but cover this):

> Welcome. This wizard takes about 6 minutes. I'll ask about your goals, training setup, coaching preferences, and Hevy API key, then generate a starter program for you.
>
> Nothing leaves your machine except API calls to Hevy. Your data lives in a directory you choose. Your Hevy key is stored locally with restricted file permissions and is never echoed back or written to memory.

**Ask:** "Where should your fitness data live? (Default: `~/fitness`)"

- Default value: `~/fitness` on macOS/Linux; `C:\Users\<current-user>\fitness` on Windows. Resolve `~` to the current user's home directory.
- Validate the answer:
  - Reject paths inside `~/.claude/` — that directory is for plugin code, not user data. If they insist, repeat the explanation and re-ask.
  - The parent directory must exist or be creatable.
  - If the directory already exists and is non-empty AND does not contain `.fitness-coach.json`, warn the user and ask whether to merge into it or pick a different path.

Once a path is chosen, store it as `<data-dir>` for the rest of the wizard. Create the directory and a `<data-dir>/memory/` subdirectory.

Render `templates/gitignore.tmpl` → `<data-dir>/.gitignore` (this template has no placeholders).

**Confirm:** "Data directory created at `<data-dir>`. Moving on."

---

## Stage 1 — Identity & goals

Ask these questions one at a time. Wait for each answer before moving to the next.

1. **Units?** kg or lb. Store as `{{UNITS}}`.
2. **Age?** Integer 13–100. Store as `{{AGE}}`.
3. **Sex?** male / female / other. Store as `{{SEX}}`.
4. **Height?** In cm if units=kg; in feet+inches if units=lb. Store the raw answer as `{{HEIGHT}}` (e.g., "177 cm" or "5'10\"").
5. **Current weight?** Numeric, in the chosen units. Store as `{{CURRENT_WEIGHT}}`.
6. **Primary goal?** Multiple choice — exactly one:
   - `fat_loss`
   - `muscle_gain`
   - `strength`
   - `maintenance`
   - `general_fitness`
   - `sport_specific`

   Store as `{{PRIMARY_GOAL}}`. This drives goal-conditional template blocks and the starter program decision tree.
7. **Goal detail?**
   - If `fat_loss` or `muscle_gain`: ask for target weight and target date (or weeks). Format: "75 kg by 2026-08-17" or "75 kg in 12 weeks". Store as `{{GOAL_DETAIL}}`.
   - If `strength`: ask which lifts and target loads. Format: "Bench 100 kg, Squat 140 kg, Deadlift 180 kg". Store as `{{GOAL_DETAIL}}`.
   - If `sport_specific`: ask which sport and what the goal is (race date, comp, peak season). Store as `{{GOAL_DETAIL}}`.
   - If `maintenance` or `general_fitness`: ask for a free-text description of what success looks like. Store as `{{GOAL_DETAIL}}`.
8. **Secondary goals?** Free text, optional. "None" is acceptable. Store as `{{SECONDARY_GOALS}}`.
9. **Injuries / limitations / conditions?** Free text. "None" is acceptable. Store as `{{INJURIES_LIMITATIONS}}`. If non-empty, also write a flag to `<data-dir>/memory/red-flags.md` (single-line: "User reported at onboarding: <text>. Refer to a physio/doctor for diagnosis or treatment.").
10. **Optional context?** Anything else relevant (location, recent training trajectory, time-zone constraints). Free text, optional. Store as `{{LOCATION_CONTEXT}}` and `{{RECENT_TRAJECTORY}}` (use the same text for both if user gives a single answer).

---

## Stage 2 — Training setup

Ask these one at a time.

1. **Days per week available for training?** Integer 1–7. Store as `{{DAYS_PER_WEEK}}`.
2. **Session length (minutes)?** Integer 15–180. Store as `{{SESSION_LENGTH_MIN}}`.
3. **Time of day?** Free text (e.g., "7–8am" or "evening, 6–7pm"). Store as `{{TIME_OF_DAY}}` and `{{TRAINING_WINDOW}}` (same value).
4. **Equipment access?** Multiple choice, multi-select:
   - `full_gym`
   - `home_dumbbells`
   - `bodyweight_only`
   - `pool`
   - `cardio_machines`
   - `barbell_rack`
   - `cables`
   - `bands`
   - `kettlebells`

   Store as a list. Build `{{EQUIPMENT_LIST}}` as a bulleted list and `{{EQUIPMENT_SUMMARY}}` as a one-line comma-joined summary.
5. **Preferred modalities?** Multiple choice, multi-select: `lift`, `swim`, `run`, `cycle`, `row`, `sport`. Store as `{{MODALITIES}}` (comma-joined).
6. **Current routine** (optional). Paste or describe. Free text. Store as part of `{{LOCATION_CONTEXT}}` (append) or into the profile memory file directly.

---

## Stage 3 — Coaching style

Ask these one at a time.

1. **Tone?** `direct`, `encouraging`, or `clinical`. Store as `{{COACHING_TONE}}`.
2. **Autonomy?** `ask_before_changes` (you ask before adjusting loads/volumes) or `execute_and_report` (you adjust and report what you did). Store as `{{AUTONOMY_LEVEL}}`.
3. **Pushback intensity?** 1 (gentle) – 5 (assertive). Store as `{{PUSHBACK_INTENSITY}}`.
4. **RPE logging preference?** `always` (every set gets an RPE) or `only_when_relevant` (RPE only on hard sets or when something feels off). Store as `{{RPE_LOGGING_PREFERENCE}}`.

---

## Stage 4 — Hevy integration

Print this exactly:

> To connect Hevy, get your API key from the Hevy app: Settings → Developer → API Key.
>
> Paste the key on the next prompt. The key will be written to `<data-dir>/.hevy-api.txt` with restricted file permissions and never echoed back to this chat.

**Ask:** "Paste your Hevy API key (or type `skip` to skip Hevy setup for now):"

- If the user types `skip`: set `{{HEVY_CONNECTED_BOOL}}` to `false` and proceed to Stage 5.
- Otherwise:
  1. Write the key (verbatim, no surrounding whitespace) to `<data-dir>/.hevy-api.txt`.
  2. Apply restrictive permissions:
     - **Windows** (detect via `$IsWindows` in PowerShell or `case "$OSTYPE" in cygwin*|msys*|win*)`):
       ```powershell
       icacls "<data-dir>\.hevy-api.txt" /inheritance:r /grant:r "${env:USERNAME}:F"
       ```
     - **macOS/Linux**:
       ```sh
       chmod 600 "<data-dir>/.hevy-api.txt"
       ```
  3. Validate the key by calling Hevy's `/workouts/count` endpoint:
     ```sh
     curl -s -o /tmp/hevy-resp.json -w "%{http_code}" \
       -H "api-key: $(cat <data-dir>/.hevy-api.txt | tr -d '[:space:]')" \
       https://api.hevyapp.com/v1/workouts/count
     ```
     (On Windows PowerShell, adapt to `Invoke-WebRequest` or run via Git Bash.)
  4. Inspect the HTTP code:
     - **200**: parse the JSON response, read `workout_count`. Display: `Connected — N workouts found. Key set ✓ (last 4: ••••XXXX)` where `XXXX` is the last 4 characters of the key. Set `{{HEVY_CONNECTED_BOOL}}` to `true`.
     - **Non-200**: display the response body, ask whether to retry or skip. Do NOT proceed past this step on an unrecognized error.
- **CRITICAL**: never print the full key. Never store it in any file other than `.hevy-api.txt`. Never write it to chat output, memory files, plan files, or commit messages.

**Optional initial pull.** If Hevy connected successfully, ask: "Pull your last 30 days of Hevy workouts into your `workout-log.md` so I have immediate context? (y/n)"

If yes, page through `GET /workouts?page=1&pageSize=10` until the workout's `start_time` is older than 30 days ago or you've exhausted pages. For each workout, append a Gym Entry (or Swim Entry where appropriate) to `workout-log.md` using the canonical template. Map Hevy fields to template fields best-effort; mark any fields you can't fill with `—`.

---

## Stage 5 — Generate starter program

Use this decision tree to choose a split. Match on `(PRIMARY_GOAL, DAYS_PER_WEEK_RANGE, has-equipment)`:

| Goal | Days/wk | Required equipment | Split |
|---|---|---|---|
| fat_loss | 5–6 | full_gym + pool | upper push / upper pull + 3–4 swim |
| fat_loss | 5–6 | full_gym (no pool) | upper push / upper pull / lower (light) + 2–3 cardio |
| fat_loss | 3–4 | full_gym | full body 3x + 1 cardio |
| fat_loss | 3–4 | home_dumbbells or bodyweight_only | full body 3x + 1 cardio |
| muscle_gain | 5–6 | full_gym | upper / lower x2 + arms day |
| muscle_gain | 4 | full_gym | upper / lower x2 |
| muscle_gain | 3 | full_gym | full body 3x |
| muscle_gain | any | home_dumbbells or bodyweight_only | full body Nx (volume scaled to days) |
| strength | 4 | barbell_rack | upper / lower x2 with 5x5 / 3x5 main lifts |
| strength | 3 | barbell_rack | full body 3x with 5x5 / 3x5 |
| strength | any | no barbell_rack | recommend acquiring barbell access; meanwhile run muscle_gain split |
| maintenance | 3–4 | any | full body 3x or push/pull/legs |
| general_fitness | any | any | mixed: 2 lift days + remainder cardio/modality variety |
| sport_specific | any | any | one default lift day + free description: "plan around your sport schedule — the coach will adapt during /fitness-session" |

If no row matches exactly, fall back to: **full body 3x with rep schemes appropriate to the goal** (8–12 reps for hypertrophy, 3–5 for strength, 10–15 for endurance/fat loss).

**Build the weekly structure table.** With the chosen split + `DAYS_PER_WEEK` + `MODALITIES`, lay out Mon–Sun. Default: gym sessions on Mon/Wed/Fri (or Mon/Tue/Thu/Fri for 4-day), cardio/swim days in between, Sun off. Override if `TIME_OF_DAY` or current routine implies a different default. Store as `{{WEEKLY_STRUCTURE_TABLE}}` (markdown table with columns: Day | Modality).

**Render templates.** Plain string substitution: `{{NAME}}` → value. After substitution, scan each file for `<!-- IF KEY=VALUE -->` ... `<!-- ENDIF -->` markers. Keep a block if the user's value for KEY equals VALUE; otherwise strip it (including the marker lines). Nested conditionals are not supported in v1 — if encountered, treat them as flat and log a warning.

Render and write:
- `templates/CLAUDE.md.tmpl` → `<data-dir>/CLAUDE.md`
- `templates/memory/MEMORY.md.tmpl` → `<data-dir>/memory/MEMORY.md`
- `templates/memory/profile.md.tmpl` → `<data-dir>/memory/profile.md`
- `templates/memory/coaching-preferences.md.tmpl` → `<data-dir>/memory/coaching-preferences.md`
- `templates/memory/equipment-and-schedule.md.tmpl` → `<data-dir>/memory/equipment-and-schedule.md`
- `templates/week-plan-template.md` → `<data-dir>/week-plan-template.md` (verbatim — this is the user's reference template)
- `templates/workout-log.md.tmpl` → `<data-dir>/workout-log.md` (only `{{UNITS}}` substitution needed)
- If `pool` in equipment OR `swim` in modalities: `templates/swim-alternate-template.md` → `<data-dir>/swim-alternate-template.md` (verbatim)
- `templates/fitness-coach-config.json.tmpl` → `<data-dir>/.fitness-coach.json`. Substitute `{{DATA_DIR_ABS_PATH}}` (absolute path), `{{ONBOARDED_AT_ISO}}` (current UTC ISO 8601 timestamp), `{{UNITS}}`, `{{PRIMARY_GOAL}}`, `{{HEVY_CONNECTED_BOOL}}` (lowercase `true`/`false`, no quotes).

**Generate `<data-dir>/week-1-plan.md`** from the canonical template. Populate:
- Dates: Monday of current week through Sunday.
- Focus: "First week of new program. Establish baseline loads. RPE 7 cap on all working sets. No PR chasing."
- Targets: weight target (start → target end-of-week, derived from goal); protein floor (1.6 g/kg for maintenance/general; 1.8 g/kg for fat_loss/muscle_gain/strength).
- Sessions: chosen split rendered into the Sessions tables. For exercises, use generic names appropriate to the equipment (e.g., "Bench Press (Dumbbell)" if no barbell, "Barbell Bench Press" if barbell). Load column: "establish baseline" for week 1.
- Conditioning rows: filled in if modalities include swim/run/bike/row.

**Display the proposed week-1 plan inline.** Then ask: "Look good? (y / suggest changes / start over)". On `y`: proceed to Stage 6. On suggestion: incorporate changes and re-show. On start over: return to Stage 1.

---

## Stage 6 — Done & next steps

Print a summary table:

```
Files created in <data-dir>:
  .fitness-coach.json        — plugin config (commit-safe)
  .gitignore                 — protects .hevy-api.txt
  .hevy-api.txt              — Hevy API key (gitignored, perm-locked)
  CLAUDE.md                  — your coach's standing instructions
  workout-log.md             — append session entries here (or use /fitness-log)
  week-plan-template.md      — reference template for future weeks
  week-1-plan.md             — this week's plan
  memory/
    MEMORY.md
    profile.md
    coaching-preferences.md
    equipment-and-schedule.md
```

Ask: "Want me to push starter routines to Hevy now? (y/n, default n — you can always do this later via /fitness-session.)"
- If yes AND Hevy connected: walk through the chosen split, build a `POST /routines` payload per session, ask for explicit sign-off on each one before pushing.
- If no or skipped: move on.

**Print next steps:**
- `/fitness-session` — get a brief before each training session
- `/fitness-log` — log a session after each one
- `/fitness-review` — weekly review and next-week plan generation (default day: Sunday)

End the wizard.

---

## Idempotency menu

If activation check found an existing `.fitness-coach.json`, do NOT run the wizard from Stage 0. Instead, display this menu:

> You're already onboarded (data at `<data-dir>`, onboarded `<onboarded_at>`). What do you want to do?
> 1. Edit profile (age, weight, goals)
> 2. Edit coaching style (tone, autonomy, pushback)
> 3. Rotate Hevy API key
> 4. Regenerate this week's plan
> 5. Start fresh (DELETES everything in `<data-dir>` — requires typing `DELETE` to confirm)

Behavior per choice:
1. Re-run Stage 1 questions, update `<data-dir>/memory/profile.md` in place (read existing, present current value as default, accept new value).
2. Re-run Stage 3 questions, update `<data-dir>/memory/coaching-preferences.md` in place.
3. Re-prompt for the Hevy key (same handling as Stage 4); overwrite `.hevy-api.txt`; re-apply perms; re-validate.
4. Regenerate `<data-dir>/week-{N}-plan.md` for the current week from the template, preserving any sessions already marked done in the current file.
5. Display: "This will delete every file in `<data-dir>`. Type the word `DELETE` (uppercase, no quotes) to confirm." Only proceed on exact match. Then `rm -rf <data-dir>` and restart from Stage 0.

---

## Substitution rules (reference)

- **Placeholders** use `{{NAME}}` syntax. Plain string replace. Apply to each template file after reading and before writing.
- **Conditional blocks** use `<!-- IF KEY=VALUE -->` and `<!-- ENDIF -->` as line-anchored markers. Both must appear on their own line (with optional leading whitespace).
- For each conditional block: if the user's resolved value for `KEY` equals `VALUE`, keep the block content (drop only the marker lines). Otherwise, drop the entire block including markers.
- Nested conditionals are not supported in v1. If encountered, treat them as flat — outermost markers control, inner markers are passed through literally. Log a warning to chat and recommend the template be flattened.

## Security forbiddens

- Never echo the Hevy API key in chat output.
- Never write the key to any file other than `<data-dir>/.hevy-api.txt`.
- Never include the key in a curl URL query string — only in the `api-key:` request header.
- Never commit `.hevy-api.txt` (it's gitignored by the template, but verify after writing).
- If the user appears to be in a public/shared environment (asks about shared computers, mentions remote pair-programming, etc.), warn them about the file's plaintext storage and recommend a private machine for setup.
