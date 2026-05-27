# Claude Fitness Coach Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a redistributable Claude Code plugin that turns the existing fitness-coaching system into a generic, goal-agnostic coach friends can install with one command and onboard in ~6 minutes.

**Architecture:** Single plugin repo (MIT) with five SKILLs, four slash commands, and template files rendered into a user-chosen data directory at onboarding. Plugin code lives in `~/.claude/plugins/`; user data lives in `<data-dir>` (default `~/fitness/`). Hevy API key stored in `<data-dir>/.hevy-api.txt` with OS-level perm locking, never echoed.

**Tech Stack:** Claude Code plugin format (`.claude-plugin/plugin.json`, `marketplace.json`), Markdown skills, Bash/PowerShell for OS calls, `curl` for Hevy API, git pre-commit hook in POSIX shell.

**Source references:**
- Spec: `docs/superpowers/specs/2026-05-27-claude-fitness-coach-plugin-design.md`
- Original system (to generalize from): `C:\google-drive\ai-playground\personal\fitness\` — `CLAUDE.md`, `hevy-instructions.md`, `workout-log.md`, `week-plan-template.md`, `swim-alternate-template.md`, `memory/*.md`

**Working directory:** `C:\google-drive\ai-playground\code\fitness-tracker` (git repo already initialized, `main` branch, spec committed).

**Dispatch lanes:**
- **S** = Sonnet 4.6 subagent (templates, skill content authoring, docs)
- **C** = Codex CLI subagent (logic-heavy, security, OS-specific)
- **O** = Opus 4.7 (this session — scaffolding + dispatch + review)

---

## File Structure

```
fitness-tracker/                              # working dir, becomes the repo
├── .claude-plugin/
│   ├── plugin.json                           # [O]  T1
│   └── marketplace.json                      # [O]  T1
├── LICENSE                                   # [O]  T1
├── .gitignore                                # [O]  T1
├── README.md                                 # [S]  T15
├── skills/
│   ├── fitness-onboarding/SKILL.md           # [C]  T11
│   ├── fitness-coaching/SKILL.md             # [S]  T10
│   ├── hevy-api/SKILL.md                     # [S]  T7
│   ├── weekly-review/SKILL.md                # [S]  T9
│   └── workout-logging/SKILL.md              # [S]  T8
├── commands/
│   ├── fitness-onboard.md                    # [O]  T14
│   ├── fitness-session.md                    # [O]  T14
│   ├── fitness-log.md                        # [O]  T14
│   └── fitness-review.md                     # [O]  T14
├── templates/
│   ├── CLAUDE.md.tmpl                        # [S]  T3
│   ├── workout-log.md.tmpl                   # [S]  T5
│   ├── week-plan-template.md                 # [S]  T5
│   ├── swim-alternate-template.md            # [S]  T6
│   ├── memory/
│   │   ├── MEMORY.md.tmpl                    # [S]  T4
│   │   ├── profile.md.tmpl                   # [S]  T4
│   │   ├── coaching-preferences.md.tmpl      # [S]  T4
│   │   └── equipment-and-schedule.md.tmpl    # [S]  T4
│   ├── gitignore.tmpl                        # [O]  T2
│   ├── fitness-coach-config.json.tmpl        # [O]  T2
│   └── git-hooks/
│       └── pre-commit                        # [C]  T12
├── docs/
│   ├── HEVY-API-REFERENCE.md                 # [S]  T7
│   └── superpowers/                          # already exists
└── scripts/
    └── validate-plugin.sh                    # [C]  T16
```

---

## Phase 1 — Scaffolding (Opus, sequential, blocks Phase 2+)

### Task 1: Plugin scaffolding files

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`
- Create: `LICENSE`
- Create: `.gitignore`

- [ ] **Step 1: Write `.claude-plugin/plugin.json`**

```json
{
  "name": "fitness-coach",
  "version": "0.1.0",
  "description": "A personal fitness coach with Hevy integration. Goal-agnostic (fat loss, muscle, strength, maintenance) with onboarding and weekly review workflows.",
  "author": {
    "name": "Gautam",
    "url": "https://github.com/REPLACE_WITH_GITHUB_USERNAME"
  },
  "homepage": "https://github.com/REPLACE_WITH_GITHUB_USERNAME/claude-fitness-coach",
  "license": "MIT",
  "keywords": ["fitness", "hevy", "coaching", "workout", "training"]
}
```

- [ ] **Step 2: Write `.claude-plugin/marketplace.json`**

```json
{
  "name": "claude-fitness-coach",
  "owner": {
    "name": "Gautam",
    "url": "https://github.com/REPLACE_WITH_GITHUB_USERNAME"
  },
  "plugins": [
    {
      "name": "fitness-coach",
      "source": ".",
      "description": "Personal fitness coach with Hevy integration",
      "version": "0.1.0",
      "category": "lifestyle"
    }
  ]
}
```

- [ ] **Step 3: Write `LICENSE` (MIT)**

```
MIT License

Copyright (c) 2026 Gautam

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 4: Write `.gitignore` (for the plugin repo itself)**

```
# OS
.DS_Store
Thumbs.db
desktop.ini

# Editors
.vscode/
.idea/
*.swp

# Local Claude state
.claude/

# Never commit Hevy keys (defense-in-depth — users' data dirs are separate but just in case)
.hevy-api.txt
.hevy-key.txt

# Node / package manager artifacts (no JS code expected, but defensive)
node_modules/
```

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/ LICENSE .gitignore
git commit -m "feat: plugin scaffold (plugin.json, marketplace.json, LICENSE, gitignore)"
```

---

### Task 2: User-data templates (gitignore + config)

**Files:**
- Create: `templates/gitignore.tmpl`
- Create: `templates/fitness-coach-config.json.tmpl`

- [ ] **Step 1: Write `templates/gitignore.tmpl`** (rendered into the user's data dir)

```
# Hevy API key — NEVER commit
.hevy-api.txt

# OS / editor cruft
.DS_Store
Thumbs.db
desktop.ini
.vscode/
.idea/
*.swp
```

- [ ] **Step 2: Write `templates/fitness-coach-config.json.tmpl`** (rendered into the user's data dir; safe to commit)

```json
{
  "data_dir": "{{DATA_DIR_ABS_PATH}}",
  "plugin_version": "0.1.0",
  "onboarded_at": "{{ONBOARDED_AT_ISO}}",
  "units": "{{UNITS}}",
  "primary_goal": "{{PRIMARY_GOAL}}",
  "hevy_connected": {{HEVY_CONNECTED_BOOL}}
}
```

Template placeholders use `{{NAME}}` syntax. The onboarding skill (T11) substitutes these.

- [ ] **Step 3: Commit**

```bash
git add templates/gitignore.tmpl templates/fitness-coach-config.json.tmpl
git commit -m "feat(templates): gitignore and config templates for user data dir"
```

---

## Phase 2 — Content templates (Sonnet lane, parallel-safe after T2)

Sonnet subagents are dispatched with the brief shown in each task. Each subagent must:
- Read the spec: `docs/superpowers/specs/2026-05-27-claude-fitness-coach-plugin-design.md`
- Read the source references it's generalizing from
- Write the file specified, then stop. Do not commit (Opus reviews + commits in batch).

### Task 3: `templates/CLAUDE.md.tmpl` (generic instruction template)

**Files:**
- Create: `templates/CLAUDE.md.tmpl`

**Source references:**
- `C:\google-drive\ai-playground\personal\fitness\CLAUDE.md` — original (fat-loss specific)

**Subagent brief (Sonnet):**

> Generalize the source CLAUDE.md into a goal-agnostic template. The original is hardcoded for fat-loss + upper-body preservation + swim-heavy. The template must work for any goal type (fat loss / muscle gain / strength / maintenance / general fitness / sport-specific).
>
> Use `{{PLACEHOLDER}}` syntax for fields the wizard fills in. Required placeholders:
> - `{{USER_NAME}}`, `{{AGE}}`, `{{SEX}}`, `{{HEIGHT}}`, `{{CURRENT_WEIGHT}}`, `{{UNITS}}` (kg or lb)
> - `{{LOCATION_CONTEXT}}` (free text from onboarding, optional)
> - `{{PRIMARY_GOAL}}`, `{{GOAL_DETAIL}}` (target weight/timeline OR sport-specific description)
> - `{{SECONDARY_GOALS}}` (bulleted, optional)
> - `{{INJURIES_LIMITATIONS}}` (free text or "None reported")
> - `{{DAYS_PER_WEEK}}`, `{{SESSION_LENGTH_MIN}}`, `{{TIME_OF_DAY}}`
> - `{{EQUIPMENT_SUMMARY}}` (one-line summary)
> - `{{MODALITIES}}` (comma-separated)
> - `{{WEEKLY_STRUCTURE_TABLE}}` (rendered table of Mon–Sun day assignments)
> - `{{COACHING_TONE}}`, `{{AUTONOMY_LEVEL}}`, `{{PUSHBACK_INTENSITY}}`
> - `{{START_DATE}}` (ISO)
>
> Required sections (preserve these headings in this order):
> 1. **Profile** — stats + goals + constraints
> 2. **Training Setup** — schedule, equipment, weekly structure
> 3. **Coaching Style** — tone, autonomy, pushback
> 4. **File Map** — `workout-log.md`, `week-{N}-plan.md`, `week-plan-template.md`, `swim-alternate-template.md` (if pool), `memory/`, `.hevy-api.txt`, plugin's `HEVY-API-REFERENCE.md`
> 5. **Logging Discipline** — preserve the unilateral-set halving rule from the source
> 6. **Weekly Review Workflow** — generalize the Sunday workflow from source §"Sunday Workflow"
> 7. **Hevy Integration** — point to the plugin's `hevy-api` skill and `HEVY-API-REFERENCE.md`
> 8. **Standing Rules** — goal-conditional block: include cut-mode rules ONLY if `{{PRIMARY_GOAL}}` is fat loss; bulk rules only if muscle gain; etc. Use clear conditional comments like `<!-- IF PRIMARY_GOAL=fat_loss -->` ... `<!-- ENDIF -->` so the wizard can strip irrelevant blocks. List all conditional blocks the wizard needs to handle.
> 9. **Red Flags** — sharp joint pain → physio; sleep <6h two nights; rapid loss/gain; strength drops two sessions running; lightheadedness; etc. Universal across goals.
>
> Do NOT include: any user-specific data from the source (no "20Y male, Dubai/Lagos", no specific routine IDs, no actual weight numbers).
>
> Length target: ~120 lines.

**Acceptance:**
- File exists, contains all 9 sections in order
- All placeholders use `{{NAME}}` syntax
- Conditional blocks use `<!-- IF KEY=value -->` / `<!-- ENDIF -->` markers
- No user-specific data leaked from source
- Lists which conditional keys exist in a comment at the top of the file

---

### Task 4: `templates/memory/*.tmpl` (four memory templates)

**Files:**
- Create: `templates/memory/MEMORY.md.tmpl`
- Create: `templates/memory/profile.md.tmpl`
- Create: `templates/memory/coaching-preferences.md.tmpl`
- Create: `templates/memory/equipment-and-schedule.md.tmpl`

**Source references:**
- `C:\google-drive\ai-playground\personal\fitness\memory\MEMORY.md`
- `C:\google-drive\ai-playground\personal\fitness\memory\profile.md`
- `C:\google-drive\ai-playground\personal\fitness\memory\coaching-preferences.md`
- `C:\google-drive\ai-playground\personal\fitness\memory\equipment-and-schedule.md`

**Subagent brief (Sonnet):**

> Generalize each memory file to a template using `{{PLACEHOLDER}}` syntax. Preserve the frontmatter format (`name`, `description`, `type` fields).
>
> **`MEMORY.md.tmpl`** — index file (no frontmatter). Three bullet lines pointing to the three other memory files, each with a goal-agnostic one-liner. Include a header note about what memory should/shouldn't hold (preserve from source).
>
> **`profile.md.tmpl`** — placeholders: `{{AGE}}`, `{{SEX}}`, `{{HEIGHT}}`, `{{CURRENT_WEIGHT}}`, `{{UNITS}}`, `{{RECENT_TRAJECTORY}}` (optional, "None reported" default), `{{PRIMARY_GOAL}}`, `{{GOAL_TARGET}}`, `{{GOAL_TIMELINE}}`, `{{SECONDARY_GOALS}}`, `{{SELF_CONSTRAINTS}}` (free text), `{{INJURIES_CONDITIONS}}`. Frontmatter: name="User profile", description="Physical stats and goal context", type=user.
>
> **`coaching-preferences.md.tmpl`** — placeholders: `{{COACHING_TONE}}`, `{{AUTONOMY_LEVEL}}`, `{{PUSHBACK_INTENSITY}}`, `{{RPE_LOGGING_PREFERENCE}}`. Sections: Communication, Pushback, Adaptation, Recording conventions (keep the unilateral-set halving rule verbatim — it's framework-level, not user-specific). Frontmatter: name="Coaching preferences", description="How to deliver plans and communicate", type=feedback.
>
> **`equipment-and-schedule.md.tmpl`** — placeholders: `{{TRAINING_WINDOW}}`, `{{SESSION_LENGTH_MIN}}`, `{{DAYS_PER_WEEK}}`, `{{EQUIPMENT_LIST}}` (bullets), `{{MODALITIES}}`, `{{WEEKLY_STRUCTURE_TABLE}}`. Frontmatter: name="Equipment and schedule", description="Where, when, and how the user trains", type=project.
>
> No user-specific data from source.

**Acceptance:**
- Four files exist with valid frontmatter
- All `{{PLACEHOLDERS}}` use the syntax in T3
- No leaked user data

---

### Task 5: `templates/week-plan-template.md` + `templates/workout-log.md.tmpl`

**Files:**
- Create: `templates/week-plan-template.md`
- Create: `templates/workout-log.md.tmpl`

**Source references:**
- `C:\google-drive\ai-playground\personal\fitness\week-plan-template.md` — already generic, lift mostly verbatim
- `C:\google-drive\ai-playground\personal\fitness\workout-log.md` — first ~50 lines are the canonical templates (Gym/Swim/Weight); the rest is user data

**Subagent brief (Sonnet):**

> **`week-plan-template.md`**: Lift the source file mostly verbatim. Replace the hardcoded gym sessions (Day A — Upper Push, Day B — Upper Pull) with a generic structure: "Session 1 — {Name}", "Session 2 — {Name}", etc., supporting up to 6 sessions. Swim sessions table stays but renamed to "Conditioning / Cardio sessions" with rows defined by modality (Swim / Run / Bike / Row / Other). Keep the 7-section structure (Focus, Schedule, Targets, Gym sessions, Conditioning sessions, Adjustments, Notes). Keep the standing-rules footer pointer.
>
> **`workout-log.md.tmpl`**: Take the source `workout-log.md` from line 1 through the end of the "Weight-only Entry" section (~line 50), which contains the three canonical templates and the header note. Drop everything below that ("## Weight Log" table and "## Sessions" — those are user data, not template). Append:
> - Empty `## Weight Log` table with just the header row: `| Date | Weight ({{UNITS}}) | Notes |`
> - Empty `## Sessions` section with placeholder text: `_No sessions logged yet. Append entries below using the templates above._`

**Acceptance:**
- Both files exist
- `week-plan-template.md` supports any modality, not just lift/swim
- `workout-log.md.tmpl` has canonical templates intact, empty Weight Log + Sessions ready to fill

---

### Task 6: `templates/swim-alternate-template.md`

**Files:**
- Create: `templates/swim-alternate-template.md`

**Source:** `C:\google-drive\ai-playground\personal\fitness\swim-alternate-template.md`

**Subagent brief (Sonnet):**

> Lift verbatim. Only seeded into user data dir if the user picked Pool as equipment. Add a one-line note at the very top: `> Seeded because you selected pool/swim during onboarding. Delete if not relevant.`

**Acceptance:**
- File matches source content, plus the one-line seeded-because note.

---

## Phase 3 — Skill content (Sonnet lane, parallel-safe after T1)

### Task 7: `skills/hevy-api/SKILL.md` + `docs/HEVY-API-REFERENCE.md`

**Files:**
- Create: `skills/hevy-api/SKILL.md`
- Create: `docs/HEVY-API-REFERENCE.md`

**Source:** `C:\google-drive\ai-playground\personal\fitness\hevy-instructions.md`

**Subagent brief (Sonnet):**

> Split the source into two artifacts:
>
> **`skills/hevy-api/SKILL.md`** — a Claude Code skill with frontmatter:
> ```
> ---
> name: hevy-api
> description: Use whenever the user needs to read from or write to Hevy. Provides curl recipes, endpoint reference, POST/PUT field rules, set-type enum, pagination, and unilateral-exercise convention. Reads the API key from <data-dir>/.hevy-api.txt at point-of-use and never echoes it.
> ---
> ```
> Skill body: rules of engagement (curl not WebFetch; api-key header not Bearer; key file at `<data-dir>/.hevy-api.txt`; never echo, log, or write key to memory; never put key in URL query params; mask key when confirming). Brief endpoint summary table. Common pitfalls (POST requires `folder_id:null`, PUT forbids it; no `index` in exercises/sets; empty-string `notes` rejected by PUT). Point to `docs/HEVY-API-REFERENCE.md` for full details.
>
> **`docs/HEVY-API-REFERENCE.md`** — lift the bulk of the source `hevy-instructions.md` content (endpoints, curl examples, POST/PUT field rules table, set types, pagination). Remove the "Known Routine IDs" section (user-specific). Remove the user-specific "Common Exercise Template IDs" table — instead replace with a one-paragraph note explaining how to discover IDs via `GET /exercise_templates`.
>
> Both files: replace hardcoded `cat .hevy-key.txt` with `cat <data-dir>/.hevy-api.txt` in all curl examples. Show how to resolve `<data-dir>` from `<data-dir>/.fitness-coach.json` (the file is at the project root the user is working in).

**Acceptance:**
- SKILL.md has valid frontmatter and ≤200 lines
- HEVY-API-REFERENCE.md contains all endpoints (GET /workouts, GET /workouts/{id}, GET /routines, GET /routines/{id}, GET /exercise_templates, GET /exercise_templates/{id}, POST /routines, PUT /routines/{id})
- All curl examples reference `.hevy-api.txt` (not `.hevy-key.txt`)
- No user-specific routine IDs leaked

---

### Task 8: `skills/workout-logging/SKILL.md`

**Files:**
- Create: `skills/workout-logging/SKILL.md`

**Subagent brief (Sonnet):**

> Frontmatter:
> ```
> ---
> name: workout-logging
> description: Use after any training session is reported, when the user runs /fitness-log, or when adding a weight-only entry. Enforces the canonical Gym / Swim / Weight templates from workout-log.md exactly — no invented fields, no reordered headers, no skipped sections.
> ---
> ```
>
> Body: the three templates (Gym Entry, Swim Entry, Weight-only). Set-cell format rules (`27.5×8`, `6 BW`, `60s`, `—`). Unilateral-set halving convention (4 Hevy entries = 2 sets per side). RPE field calculation rule (average of set-level RPEs from Hevy; ask user only if no set-level RPEs exist).
>
> Skill must explicitly forbid: inventing new fields, reordering fields, skipping section headers, writing workout data to CLAUDE.md / week-N-plan.md / memory/.
>
> Length target: ~80 lines.

**Acceptance:**
- File exists, frontmatter valid, all three templates present, halving rule documented.

---

### Task 9: `skills/weekly-review/SKILL.md`

**Files:**
- Create: `skills/weekly-review/SKILL.md`

**Source:** `C:\google-drive\ai-playground\personal\fitness\CLAUDE.md` §"Sunday Workflow" (generalize)

**Subagent brief (Sonnet):**

> Frontmatter:
> ```
> ---
> name: weekly-review
> description: Use on the user's weekly review day (Sunday by default, configurable in their CLAUDE.md) or when they run /fitness-review. Reads the active week plan and that week's workout-log entries, analyzes weight trend / RPE drift / volume tolerance / adherence, proposes adjustments, and on approval generates the next week-N+1-plan.md from the canonical template.
> ---
> ```
>
> Body: the 5-step Sunday Workflow from source §"Sunday Workflow", generalized:
> 1. Read current `week-{N}-plan.md` and all Week N entries in `workout-log.md`
> 2. Analyze: weight-trend (rolling 7-day avg vs goal); load progression (RPE drift); modality-specific volume tolerance; adherence
> 3. Propose adjustments in chat — one best recommendation; flag risks
> 4. On approval, create `week-{N+1}-plan.md` from `week-plan-template.md` (copied during onboarding into the user's data dir)
> 5. Push routine changes to Hevy only after explicit user sign-off
>
> Include goal-conditional weight-trend rules: for fat loss (slow/on-track/fast deltas), muscle gain (gain too fast/slow), maintenance (any deviation flagged). Use `<!-- IF PRIMARY_GOAL=... -->` style if conditional output is needed in the skill itself, or just describe all variants and let the coaching skill pick.
>
> Length target: ~100 lines.

**Acceptance:**
- File exists, frontmatter valid, 5-step workflow present, goal-conditional trend rules included.

---

### Task 10: `skills/fitness-coaching/SKILL.md`

**Files:**
- Create: `skills/fitness-coaching/SKILL.md`

**Subagent brief (Sonnet):**

> This is the in-session brain. Frontmatter:
> ```
> ---
> name: fitness-coaching
> description: Use during any in-session interaction inside a fitness-coach data directory (detected via .fitness-coach.json at project root or above). Reads CLAUDE.md + memory/ + the active week-N-plan.md + recent workout-log.md entries, designs program adjustments per the user's goal/autonomy preference, and follows the standing rules in their CLAUDE.md.
> ---
> ```
>
> Body sections:
> 1. **Activation check** — verify `.fitness-coach.json` exists at cwd or parent; if not, this skill doesn't apply.
> 2. **Read order** — `.fitness-coach.json` → `CLAUDE.md` → `memory/MEMORY.md` then each linked memory → active `week-{N}-plan.md` → tail of `workout-log.md` (last ~3 sessions). Reading order is important: profile/preferences load before plan, plan loads before log.
> 3. **Decision framework for adjustments** — goal-conditional:
>    - Fat loss: weight-trend drives calorie nudges (described in CLAUDE.md standing rules); preserve muscle, hold loads unless RPE ≤6
>    - Muscle gain: progressive overload — add load when top set is RPE ≤7; calorie surplus monitoring
>    - Strength: heavier loads, lower reps (3–5); progressive overload tied to top-set bar speed/RPE
>    - Maintenance: hold all variables unless deviation; flag any drift
>    - General fitness: variety bias; rotate stimuli every 4 weeks
>    - Sport-specific: defer to user's sport-specific protocol; provide general fatigue/recovery guidance
> 4. **Autonomy gating** — `ask-before-changes` mode requires explicit user approval before changing loads/volumes/routines; `execute-and-report` mode applies the change and reports what was done. Per the user's `{{AUTONOMY_LEVEL}}`.
> 5. **Hevy push gating** — any push to Hevy (POST/PUT) always requires explicit user sign-off regardless of autonomy setting (writes are irreversible).
> 6. **Standing forbiddens** — never give medical advice (refer to physio/doctor); never override red-flag thresholds in CLAUDE.md.
>
> Length target: ~150 lines.

**Acceptance:**
- File exists, frontmatter valid
- All six sections present
- Activation check explicitly described (don't apply outside a fitness-coach data dir)
- All five goal-conditional decision frameworks present

---

## Phase 4 — Logic-heavy & security (Codex lane)

### Task 11: `skills/fitness-onboarding/SKILL.md` (the wizard)

**Files:**
- Create: `skills/fitness-onboarding/SKILL.md`

**Subagent brief (Codex):**

> This is the most complex skill — the onboarding wizard with starter-program decision tree. Frontmatter:
> ```
> ---
> name: fitness-onboarding
> description: Use when the user runs /fitness-onboard, or when they invoke the fitness-coach plugin and no .fitness-coach.json exists at their cwd or in a parent directory. Drives a 6-stage wizard that collects goals, training setup, coaching style, and Hevy API key, then renders templates and generates a starter week-1 program tailored to the user's goal type.
> ---
> ```
>
> The skill must cover all six stages from spec §4. Each stage's content + behavior:
>
> **Stage 0 — Welcome & data location**
> - Print summary of what'll happen and what gets stored where (one short paragraph each).
> - Ask data directory path (default `~/fitness`, OS-aware: `C:\Users\<name>\fitness` on Windows, `~/fitness` elsewhere).
> - Validate: not inside `~/.claude/`; parent dir exists or can be created.
> - Create dir + `memory/` subdir.
> - Render `templates/gitignore.tmpl` → `<data-dir>/.gitignore`.
>
> **Stage 1 — Identity & goals**
> - Ask: age (int), sex (m/f/other), height (cm or ft+in based on units), current weight (kg/lb based on units), units (kg/lb).
> - Ask: primary goal (multiple choice: fat_loss / muscle_gain / strength / maintenance / general_fitness / sport_specific). If sport_specific, follow-up: which sport, what's the goal (race, comp, peak season, etc.).
> - Ask: target weight + timeline (only if fat_loss or muscle_gain). For other goals, ask a goal-appropriate target (e.g., strength: target lifts; sport: target event/date).
> - Ask: injuries / limitations / conditions (free text, "None" allowed).
>
> **Stage 2 — Training setup**
> - Ask: days/week (1–7), session length (min), time of day.
> - Ask: equipment checklist (multi-select: full_gym / home_dumbbells / bodyweight_only / pool / cardio_machines / barbell_rack / cables / bands / kettlebells).
> - Ask: preferred modalities (multi-select: lift / swim / run / cycle / row / sport).
> - Ask: current routine (free text, optional).
>
> **Stage 3 — Coaching style**
> - Ask: tone (direct / encouraging / clinical).
> - Ask: autonomy (ask_before_changes / execute_and_report).
> - Ask: pushback intensity (1–5).
> - Ask: RPE logging preference (always / only_when_relevant).
>
> **Stage 4 — Hevy integration**
> - Print: "Get your API key from Hevy → Settings → Developer. Paste it on the next prompt. The key will be written to `<data-dir>/.hevy-api.txt` with restricted permissions and never echoed back."
> - Prompt for key. Capture but do NOT echo.
> - Write key to `<data-dir>/.hevy-api.txt`.
> - Apply restrictive permissions:
>   - Windows (detect via `$IsWindows` in pwsh or `case "$OSTYPE"` in bash): `icacls "<path>" /inheritance:r /grant:r "${env:USERNAME}:F"` (PowerShell).
>   - macOS/Linux: `chmod 600 "<path>"`.
> - Validate via `curl -s -o /dev/null -w "%{http_code}" -H "api-key: $(cat <path> | tr -d '[:space:]')" https://api.hevyapp.com/v1/workouts/count`. Expect HTTP 200.
> - On 200: fetch the JSON body, parse `workout_count`, display "Connected — N workouts found." with masked tail (`••••XXXX` where `XXXX` is last 4 chars of key).
> - On non-200: display response, offer retry or skip-Hevy-for-now.
> - Optional: ask "Pull last 30 days of workouts into your log?" — if yes, page through `GET /workouts?page=1&pageSize=10` until end-of-window, append entries to `workout-log.md` using the Gym/Swim templates (best-effort mapping from Hevy fields).
>
> **Stage 5 — Generate starter program**
>
> Decision tree to pick split (deterministic, table-lookup):
>
> | Goal | Days/wk | Equipment includes | Split |
> |---|---|---|---|
> | fat_loss | 5–6 | full_gym + pool | upper push / upper pull + 3–4 swim |
> | fat_loss | 5–6 | full_gym (no pool) | upper push / upper pull / lower (light) + 2–3 cardio |
> | fat_loss | 3–4 | full_gym | full body 3x + 1 cardio |
> | fat_loss | 3–4 | home_dumbbells / bodyweight | full body 3x + 1 cardio |
> | muscle_gain | 5–6 | full_gym | upper / lower x2 + arms day |
> | muscle_gain | 4 | full_gym | upper / lower x2 |
> | muscle_gain | 3 | full_gym | full body 3x |
> | strength | 4 | barbell_rack | upper / lower x2 (5x5 / 3x5 main lifts) |
> | strength | 3 | barbell_rack | full body 3x (5x5 / 3x5) |
> | maintenance | 3–4 | any | full body 3x or push/pull/legs |
> | general_fitness | any | any | mixed: 2 lift + remainder cardio/modality variety |
> | sport_specific | any | any | one default lift day + sport-specific guidance ("plan around your sport schedule") |
>
> For combinations not in the table, fall back to: full body 3x with appropriate rep schemes for the goal.
>
> Render `templates/CLAUDE.md.tmpl` → `<data-dir>/CLAUDE.md` with all placeholders substituted and goal-conditional blocks stripped.
> Render `templates/memory/*.tmpl` → `<data-dir>/memory/*.md`.
> Render `templates/week-plan-template.md` → `<data-dir>/week-plan-template.md` (verbatim, no placeholders — it's the user's reference template).
> Render `templates/workout-log.md.tmpl` → `<data-dir>/workout-log.md` with `{{UNITS}}` substituted.
> If pool ∈ equipment: copy `templates/swim-alternate-template.md` → `<data-dir>/swim-alternate-template.md`.
> Render `templates/fitness-coach-config.json.tmpl` → `<data-dir>/.fitness-coach.json` with `{{DATA_DIR_ABS_PATH}}`, `{{ONBOARDED_AT_ISO}}` (current UTC ISO timestamp), `{{UNITS}}`, `{{PRIMARY_GOAL}}`, `{{HEVY_CONNECTED_BOOL}}` (true/false).
>
> Generate `<data-dir>/week-1-plan.md` from the canonical template, populated with the chosen split's exercises. Use "establish baseline" as the load placeholder for week 1 since we don't know the user's strength yet.
>
> Display the proposed week-1 plan inline. Ask sign-off before considering onboarding complete.
>
> **Stage 6 — Done**
> - Summary table of files created (path + 1-line purpose).
> - Optional: push starter routines to Hevy. Default no — user can do it later via `/fitness-session` workflow.
> - Print next-steps: `/fitness-session` before training; `/fitness-log` after; `/fitness-review` weekly.
>
> **Idempotency**
> - At skill start, check for `<cwd>/.fitness-coach.json` or `<cwd>/<data-dir-from-config>/.fitness-coach.json`. If found, show menu:
>   1. Edit profile
>   2. Edit coaching style
>   3. Rotate Hevy key
>   4. Regenerate week plan
>   5. Start fresh (deletes data dir contents — require typing the word "DELETE" to confirm)
>
> **Placeholder substitution implementation**
> - Substitution is plain string replace of `{{PLACEHOLDER}}` → value. No template engine. Document this in the skill.
> - Conditional block stripping: scan template for `<!-- IF KEY=VALUE -->` ... `<!-- ENDIF -->` markers. Keep block if the user's value for KEY equals VALUE; strip otherwise. Nested conditionals not supported in v1 — document as a limitation.
>
> Length target: 250–400 lines.

**Acceptance:**
- File exists, frontmatter valid
- All six stages documented with the question text, expected input, and write-side effects
- Decision-tree table for split selection is present and exhaustive (every goal has at least a fallback)
- Hevy key handling spells out: write path, OS-specific permission commands, validation curl, masked display
- Idempotency menu present
- Placeholder substitution & conditional-block rules documented

---

### Task 12: `templates/git-hooks/pre-commit` (Hevy-key leak guard)

**Files:**
- Create: `templates/git-hooks/pre-commit`

**Subagent brief (Codex):**

> POSIX-sh pre-commit hook. Reads staged blob content via `git diff --cached -U0` and rejects the commit if any line contains a Hevy-key-shaped token.
>
> Hevy key shape: empirically, Hevy keys are alphanumeric strings ~40+ chars (UUIDs or similar entropy). Heuristic: any token of ≥30 chars matching `[A-Za-z0-9_-]+` with ≥4 distinct character classes (mix of upper/lower/digit) AND the surrounding context contains "hevy" (case-insensitive) OR "api[-_]?key" (case-insensitive). Use grep -E.
>
> Hook exit codes: 0 = pass; 1 = block, with a message naming the offending file and line number, and a hint: "If this is a false positive, commit with `git commit --no-verify`."
>
> Must be executable (`chmod +x`); the onboarding skill (T11) is responsible for symlinking or copying it into `<data-dir>/.git/hooks/pre-commit` and making it executable when the user opts in.
>
> Also handle Windows: hook should be a POSIX shell script with `#!/bin/sh` — Git for Windows ships with sh.exe, so this is fine. Document this in a comment at the top.
>
> Reference the Hevy key examples are NOT to be included literally in the hook source — that would itself trip the heuristic on the plugin repo.

**Acceptance:**
- File exists with `#!/bin/sh` shebang
- Heuristic logic implemented (≥30 chars, mixed character classes, hevy/api-key context)
- Manual test: stage a file containing a fake Hevy key (e.g., `HEVY_API_KEY=aB3dE4fG5hI6jK7lM8nO9pQ0rS1tU2vW3xY4zA5b`), run the hook, confirm it blocks. Stage an innocent file, confirm it passes.
- Hook prints the `--no-verify` escape-hatch hint when it blocks

---

## Phase 5 — Slash commands (Opus, depends on Phase 3 skill files existing)

### Task 13: Four slash command files

**Files:**
- Create: `commands/fitness-onboard.md`
- Create: `commands/fitness-session.md`
- Create: `commands/fitness-log.md`
- Create: `commands/fitness-review.md`

- [ ] **Step 1: Write `commands/fitness-onboard.md`**

```markdown
---
description: Start (or re-enter) the fitness-coach onboarding wizard.
---

Invoke the `fitness-onboarding` skill. If `.fitness-coach.json` is found in the current working directory or any parent directory, show the re-onboarding menu (edit profile / edit coaching style / rotate Hevy key / regenerate week plan / start fresh). Otherwise, start a fresh onboarding from Stage 0.
```

- [ ] **Step 2: Write `commands/fitness-session.md`**

```markdown
---
description: Pre-session brief — today's plan, target loads, recent context.
---

Invoke the `fitness-coaching` skill. Locate the data directory via `.fitness-coach.json`. Read `CLAUDE.md`, `memory/MEMORY.md` + linked files, the active `week-{N}-plan.md`, and the tail of `workout-log.md`. Produce a brief for today's session: scheduled session, target loads/volumes, recent fatigue/recovery signals, anything to watch for.
```

- [ ] **Step 3: Write `commands/fitness-log.md`**

```markdown
---
description: Append a workout / swim / weight entry using the canonical templates.
---

Invoke the `workout-logging` skill. Ask which template (Gym / Swim / Weight-only) unless context makes it obvious, gather field values, append to `workout-log.md` in the data directory. Refuse to invent fields, reorder fields, or skip headers. Apply the unilateral-set halving convention when reading Hevy data.
```

- [ ] **Step 4: Write `commands/fitness-review.md`**

```markdown
---
description: Sunday review and next-week plan generation.
---

Invoke the `weekly-review` skill. Read the active week-N-plan.md and the week's workout-log entries. Analyze weight trend, RPE drift, modality volume tolerance, and adherence. Propose adjustments inline. On user approval, generate `week-{N+1}-plan.md` from `week-plan-template.md`. Push routine changes to Hevy only with explicit sign-off.
```

- [ ] **Step 5: Commit (Opus runs after T11 is complete and reviewed)**

```bash
git add commands/
git commit -m "feat(commands): four slash commands wired to skills"
```

---

## Phase 6 — README + smoke test (Sonnet + Codex parallel)

### Task 14: `README.md`

**Files:**
- Create: `README.md`

**Subagent brief (Sonnet):**

> Public-facing README for the GitHub repo. Sections:
>
> 1. **What it is** — one paragraph. Personal fitness coach plugin for Claude Code. Onboarding-driven, goal-agnostic, Hevy-integrated.
> 2. **Prerequisites** — Claude Code installed; Hevy subscription with API key (link to Hevy's developer settings); `curl` available (default on macOS/Linux; built into Windows 10+).
> 3. **Install (60 seconds)** —
>    ```
>    /plugin marketplace add https://github.com/<user>/claude-fitness-coach
>    /plugin install fitness-coach
>    /fitness-onboard
>    ```
> 4. **What gets stored where** — diagram showing: plugin in `~/.claude/plugins/`, user data in `<data-dir>` (default `~/fitness/`), Hevy key in `<data-dir>/.hevy-api.txt`. Plugin updates never touch user data.
> 5. **Daily / weekly use** — `/fitness-session` before training, `/fitness-log` after, `/fitness-review` weekly.
> 6. **Security** —
>    - Hevy key is stored in `.hevy-api.txt` with restricted file perms (icacls on Windows, chmod 600 on Unix).
>    - Key is gitignored by default.
>    - Optional pre-commit hook detects accidental key commits.
>    - Network calls: only outbound to `api.hevyapp.com`. No telemetry.
>    - Rotate your Hevy key periodically via Hevy's UI.
> 7. **Customization** — edit your `CLAUDE.md`, `memory/*.md`, or `week-{N}-plan.md` directly. They're plain markdown.
> 8. **Troubleshooting** — common issues: Hevy key validation fails (check key format, check internet); plugin doesn't activate (verify `.fitness-coach.json` exists at or above cwd); Windows ACL command fails (run terminal as same user who owns the file).
> 9. **License** — MIT.
> 10. **Acknowledgments** — Built on Claude Code's plugin system.
>
> Length target: ~150 lines. No corporate-blog tone. Direct and information-dense.

**Acceptance:**
- File exists with all 10 sections
- Install commands match Claude Code's actual plugin marketplace syntax
- Security section is honest (does not overclaim — e.g., does not claim "encryption at rest" since the key is just a file)

---

### Task 15: `scripts/validate-plugin.sh` (smoke test)

**Files:**
- Create: `scripts/validate-plugin.sh`

**Subagent brief (Codex):**

> POSIX-sh script that runs structural validation on the plugin repo. Checks:
>
> 1. `.claude-plugin/plugin.json` exists and is valid JSON; has `name`, `version`, `description` fields.
> 2. `.claude-plugin/marketplace.json` exists and is valid JSON; has `name`, `plugins` array with one entry whose `name` matches the plugin.json.
> 3. All five skill SKILL.md files exist at expected paths and start with frontmatter (`---` on line 1).
> 4. All four command files exist at expected paths.
> 5. All template files exist at expected paths.
> 6. No file in the repo (excluding `docs/superpowers/specs/`) contains the string `83 kg`, `Lagos`, `Dubai`, `aa9f32a0-c0da-4a38-a545-68baec25d797`, `airoidswithgautam` — these are user-specific leaks.
> 7. `templates/git-hooks/pre-commit` is executable.
> 8. Dry-run template substitution: render `templates/CLAUDE.md.tmpl` with a mock answer set (use `sed` or a tiny inline awk). Verify the output has no remaining `{{...}}` placeholders. Print the rendered output for visual inspection.
>
> Exit non-zero on any failure with a clear message. Print a checkmark line per passing check.

**Acceptance:**
- Script runs from repo root, exits 0 on healthy repo
- Catches: missing JSON file, malformed JSON, missing SKILL.md, leaked user data string, non-executable hook
- Renders CLAUDE.md.tmpl with mock data and confirms no stray `{{...}}`

---

## Phase 7 — Final integration (Opus, after all subagent work)

### Task 16: Integration review + final commit

- [ ] **Step 1:** Run `bash scripts/validate-plugin.sh` from repo root. Expected: all checks pass.
- [ ] **Step 2:** Manually inspect each subagent-produced file for: completeness vs the brief, no leaked user data, valid markdown.
- [ ] **Step 3:** Test the pre-commit hook manually:
  ```bash
  cd /tmp/test-fitness-data && git init
  cp <plugin-path>/templates/git-hooks/pre-commit .git/hooks/
  chmod +x .git/hooks/pre-commit
  echo "HEVY_API_KEY=aB3dE4fG5hI6jK7lM8nO9pQ0rS1tU2vW3xY4zA5b" > test.txt
  git add test.txt
  git commit -m "test"   # expect: blocked
  ```
- [ ] **Step 4:** Commit all subagent work in logical chunks:
  ```bash
  git add templates/
  git commit -m "feat(templates): goal-agnostic user data templates"
  git add skills/
  git commit -m "feat(skills): five skills (onboarding, coaching, hevy-api, weekly-review, logging)"
  git add commands/ docs/HEVY-API-REFERENCE.md README.md scripts/
  git commit -m "feat: slash commands, hevy api reference, readme, validate script"
  ```
- [ ] **Step 5:** Print final status: file tree, line counts, what's ready for `gh repo create`.

---

## Self-review

**Spec coverage:**
- §3.1 repo layout — covered by file structure above
- §3.2 plugin/data separation — T1 (.gitignore), T2 (.fitness-coach.json), T11 (config write)
- §3.3 components — all five skills (T7–T11), all four commands (T13), all templates (T2–T6)
- §3.4 data flow — T11 (onboarding), T10 (coaching read order), T9 (weekly review)
- §4 onboarding stages — T11
- §5 security — T1 (.gitignore), T2 (gitignore.tmpl), T7 (skill rules), T11 (icacls/chmod), T12 (pre-commit hook), T14 (README disclosure)
- §6 slash commands — T13
- §7 distribution — T1 (LICENSE), T14 (README install)
- §8 implementation lanes — annotated in each task header
- §10 success criteria — T15 (validate script) + T16 (manual smoke)

**Placeholder scan:** No "TBD" / "TODO" / "implement later" / "appropriate error handling" — every task has concrete deliverables or precise subagent briefs. The two-letter placeholders in plugin.json (`REPLACE_WITH_GITHUB_USERNAME`) are intentional and called out for human substitution at publish time.

**Type consistency:** Placeholder names (`{{UNITS}}`, `{{PRIMARY_GOAL}}`, `{{HEVY_CONNECTED_BOOL}}`, etc.) used consistently between T2 (config), T3 (CLAUDE.md), T4 (memory files), T11 (onboarding renderer). Conditional-block syntax `<!-- IF KEY=value -->` used consistently in T3 and T11.

**Gaps:** None identified.
