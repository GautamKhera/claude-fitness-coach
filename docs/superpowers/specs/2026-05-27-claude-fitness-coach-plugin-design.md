# Claude Fitness Coach — Plugin Design Spec

**Date:** 2026-05-27
**Status:** Approved (design phase)
**Owner:** Gautam
**Target repo:** `claude-fitness-coach` (GitHub, MIT license)
**Working directory:** `C:\google-drive\ai-playground\code\fitness-tracker`

---

## 1. Purpose

Package the working fitness-coaching system (CLAUDE.md instructions, templates, Hevy integration, weekly review workflow, RPE-based progression rules) as a redistributable Claude Code plugin. Friends with their own Claude + Hevy subscription install it, run a one-time onboarding wizard, and end up with a personalized fitness coach connected to their Hevy account — with their own goals, schedule, equipment, and training program generated from their inputs.

## 2. Goals & non-goals

**Goals**
- Single-command install via Claude Code's plugin marketplace.
- Self-contained onboarding (~6 minutes) that captures everything the coach needs.
- Generic across goal types: fat loss, muscle gain, strength, maintenance, general fitness, sport-specific.
- Hevy API integration with the same conventions as the source project (curl-based, set-type rules, unilateral halving, POST/PUT field rules).
- Secure handling of the Hevy API key (file perms, gitignore, never echoed).
- Plugin updates never touch user data; user data updates never require plugin changes.
- Distributable on GitHub — anyone can clone and use.

**Non-goals**
- Nutrition prescription (the coach respects user-provided protein/calorie targets but does not design diets).
- Medical advice — flag red flags and refer out.
- Non-Hevy integrations (Strava, Garmin, MyFitnessPal) — explicitly out of scope for v1.
- Mobile UX — this is a CLI plugin for Claude Code.
- Multi-user / shared data — single user per data directory.

## 3. Architecture

### 3.1 Repo layout

```
claude-fitness-coach/
├── .claude-plugin/
│   ├── plugin.json           # name, version, description, author
│   └── marketplace.json      # repo acts as its own marketplace
├── README.md                 # install + first-run + security disclosure
├── LICENSE                   # MIT
├── skills/
│   ├── fitness-onboarding/SKILL.md
│   ├── fitness-coaching/SKILL.md
│   ├── hevy-api/SKILL.md
│   ├── weekly-review/SKILL.md
│   └── workout-logging/SKILL.md
├── commands/
│   ├── fitness-onboard.md
│   ├── fitness-session.md
│   ├── fitness-log.md
│   └── fitness-review.md
├── templates/                # rendered into user's data dir at onboarding
│   ├── CLAUDE.md.tmpl
│   ├── workout-log.md.tmpl
│   ├── week-plan-template.md
│   ├── swim-alternate-template.md     # only seeded if user picks swim modality
│   ├── memory/
│   │   ├── MEMORY.md.tmpl
│   │   ├── profile.md.tmpl
│   │   ├── coaching-preferences.md.tmpl
│   │   └── equipment-and-schedule.md.tmpl
│   ├── gitignore.tmpl
│   └── git-hooks/
│       └── pre-commit              # optional, blocks Hevy key leaks
└── docs/
    └── HEVY-API-REFERENCE.md       # full reference shipped with plugin
```

### 3.2 Separation of plugin code vs user data

- **Plugin** lives in `~/.claude/plugins/...` (managed by Claude Code). Read-only from the user's perspective; updated via `/plugin update`.
- **User data** lives in a directory chosen during onboarding (default: `~/fitness/`). Owned by the user, gitignore-ready, safe to put in cloud-synced folders.
- The link is a single config value: `data_dir`. Stored in the user data dir itself (`<data-dir>/.fitness-coach.json` with `{ "data_dir": "/abs/path", "version": "1.0.0" }`) — so the plugin discovers the dir by either (a) being invoked from inside it (cwd check), or (b) the user passing the path explicitly. Onboarding writes this file.

### 3.3 Components

| Component | Responsibility | Source of behavior |
|---|---|---|
| `fitness-onboarding` skill | 6-stage wizard, template rendering, Hevy key setup, starter program generation | New, written for this plugin |
| `fitness-coaching` skill | In-session brain: read profile/memory/plan/log, design adjustments, follow autonomy preference | Generalized from current `CLAUDE.md` |
| `hevy-api` skill | Curl recipes, endpoint reference, POST/PUT rules, set-type enum, pagination, unilateral convention | Generalized from `hevy-instructions.md` |
| `weekly-review` skill | Sunday workflow: trend analysis, load/volume adjustments, next-week plan generation | Generalized from current `CLAUDE.md` §"Sunday Workflow" |
| `workout-logging` skill | Enforce Gym/Swim/Weight entry templates exactly | Generalized from `workout-log.md` headers |
| Slash commands | Thin entry points that surface the skills | `commands/*.md` |
| Templates | Files copied into user data dir at onboarding | `templates/` |

### 3.4 Data flow

```
First run:
  user: /fitness-onboard
    → fitness-onboarding skill
      → asks questions stage-by-stage
      → writes <data-dir>/{CLAUDE.md, workout-log.md, week-1-plan.md, memory/*}
      → writes <data-dir>/.hevy-api.txt (locked perms)
      → writes <data-dir>/.fitness-coach.json
      → validates Hevy key via GET /workouts/count
      → (optional) seeds workout-log.md from last 30 days Hevy pull

Daily use:
  user: /fitness-session
    → fitness-coaching skill
      → reads <data-dir>/CLAUDE.md, memory/, active week-N-plan.md, workout-log.md tail
      → outputs pre-session brief

  user: /fitness-log
    → workout-logging skill
      → reads canonical template
      → appends entry to workout-log.md

Sunday:
  user: /fitness-review
    → weekly-review skill
      → reads week-N-plan.md + workout-log.md week entries
      → analyzes trends, proposes adjustments
      → on approval, writes week-{N+1}-plan.md
```

## 4. Onboarding wizard — detailed flow

**Stage 0 — Welcome & data location**
- Print: what'll happen, what gets stored where, that nothing leaves the machine except Hevy API calls.
- Ask data directory path. Default `~/fitness`. Validate: not inside `~/.claude/`, parent dir exists or can be created.
- Create dir; write `.gitignore` (includes `.hevy-api.txt`, `.fitness-coach.json` is committed); create empty `memory/` subdir.

**Stage 1 — Identity & goals**
- Age, sex, height, current weight, units (kg/lb) → `profile.md`.
- Primary goal (fat loss / muscle gain / strength / maintenance / general fitness / sport-specific) → `profile.md`.
- Target weight + timeline (or "no specific number") → `profile.md`.
- Injuries, limitations, conditions (free text) → `profile.md` + flagged in `memory/red-flags.md` if non-empty.

**Stage 2 — Training setup**
- Days/week, session length, time of day → `equipment-and-schedule.md`.
- Equipment checklist (full gym / home dumbbells / bodyweight / pool / cardio machines / barbell+rack / cables / bands) → `equipment-and-schedule.md`.
- Preferred modalities (lift / swim / run / cycle / row / sport) → `equipment-and-schedule.md`.
- Current routine free-text (optional) → `profile.md` context block.

**Stage 3 — Coaching style**
- Tone (direct / encouraging / clinical) → `coaching-preferences.md`.
- Autonomy (ask-before-changes vs execute-and-report) → `coaching-preferences.md`.
- Pushback intensity 1–5 → `coaching-preferences.md`.
- Tracking preferences (RPE always / only when relevant) → `coaching-preferences.md`.

**Stage 4 — Hevy integration**
- Explain: Hevy → Settings → Developer → copy API key.
- Prompt for key (input is captured but not echoed — the wizard explicitly suppresses).
- Write to `<data-dir>/.hevy-api.txt`. Apply restrictive perms:
  - Windows: `icacls "<path>" /inheritance:r /grant:r "%USERNAME%:F"`
  - macOS/Linux: `chmod 600`
- Validate via `curl -s -H "api-key: $(cat ...)" https://api.hevyapp.com/v1/workouts/count`. On 200, show "Connected — N workouts found." On non-200, show error and offer retry.
- Offer optional initial pull (last 30 days workouts) → seeded into `workout-log.md` so coach has immediate context.

**Stage 5 — Generate starter program**
- Based on goal + days/week + equipment + modalities, the onboarding skill designs a week-1 program using a decision tree documented in `fitness-onboarding/SKILL.md`. Examples:
  - Fat loss + 6 days + gym+pool → upper push / upper pull + 4 cardio sessions
  - Muscle gain + 5 days + barbell+dumbbells → upper/lower 2x + arms day
  - Strength + 4 days + barbell+rack → upper/lower 2x with strength rep schemes (3–5 reps)
  - Maintenance / general fitness + 3 days + full gym → full-body 3x
- Renders `CLAUDE.md` from template with: profile summary, goals, training setup, coaching style, standing rules (protein floor, RPE progression, red flags) calibrated to goal type.
- Renders `week-1-plan.md` from canonical template with exercises, target loads (or "establish baseline" placeholder), volumes.
- Shows proposed plan inline; asks for sign-off before writing.

**Stage 6 — Done & next steps**
- Summary of files created and where.
- Optional: push starter routines to Hevy (requires explicit sign-off per coaching-preferences autonomy rule).
- Instructions for `/fitness-session`, `/fitness-log`, `/fitness-review`.

**Idempotency**
- Re-running `/fitness-onboard` after a completed onboarding detects `<data-dir>/.fitness-coach.json` and offers a menu: "edit profile" / "edit coaching style" / "rotate Hevy key" / "regenerate week plan" / "start fresh (deletes data dir contents — confirm twice)".

## 5. Security model

1. **Key storage**
   - `<data-dir>/.hevy-api.txt` — bare key, no wrapper.
   - Windows: ACL inheritance stripped, current user only via `icacls`.
   - Unix: `chmod 600`.
   - `.gitignore` lists `.hevy-api.txt`. Onboarding refuses to proceed if data dir is a git repo without that entry.

2. **In-conversation hygiene**
   - `hevy-api` skill instructs Claude to read the key only at point-of-use, pipe directly into curl `-H "api-key: ..."`.
   - Forbid: echoing key in chat, writing to memory files, putting in URL query params, logging.
   - Setup confirmation shows masked tail only (`••••XXXX`).

3. **Optional pre-commit hook**
   - `templates/git-hooks/pre-commit` rejects commits in `<data-dir>` containing strings matching Hevy key shape (length-based + entropy heuristic). User opts in during onboarding.

4. **Network surface**
   - Only outbound calls: `https://api.hevyapp.com/v1/*` via curl.
   - No telemetry, no plugin-author callback, no analytics.

5. **README disclosure**
   - "What this plugin sends where" section: Claude reads your data when invoked; Hevy gets your training data via the API; nothing else leaves your machine.
   - Recommend periodic key rotation in Hevy UI (no rotation API exists).

## 6. Slash commands

| Command | Skill it activates | Use |
|---|---|---|
| `/fitness-onboard` | `fitness-onboarding` | First-run wizard or re-run for edits |
| `/fitness-session` | `fitness-coaching` | Pre-session brief: today's plan, target loads, recent context |
| `/fitness-log` | `workout-logging` | Append a session entry to `workout-log.md` |
| `/fitness-review` | `weekly-review` | Sunday review + next-week plan generation |

## 7. Distribution

- GitHub public repo `claude-fitness-coach`, MIT license.
- README install: `/plugin marketplace add https://github.com/<user>/claude-fitness-coach` then `/plugin install fitness-coach` then `/fitness-onboard`.
- Versioning: `plugin.json` `version` field, semver. Initial release `0.1.0`.
- Prerequisites listed: Claude Code installed, Hevy subscription with API key access, `curl` available (default on macOS/Linux; built into Windows 10+).

## 8. Implementation lanes

Per user direction, Opus 4.7 owns design + plan. Implementation is split:

**Sonnet 4.6 lane — template / docs / static content**
- Templates: `CLAUDE.md.tmpl`, `workout-log.md.tmpl`, `week-plan-template.md`, `swim-alternate-template.md`, `memory/*.tmpl`, `gitignore.tmpl`.
- Skill SKILL.md files for `fitness-coaching`, `hevy-api`, `weekly-review`, `workout-logging`.
- Slash command markdown files.
- README.md and LICENSE.
- `docs/HEVY-API-REFERENCE.md`.

**Codex CLI lane — logic / security / Windows-specific**
- `fitness-onboarding/SKILL.md` (wizard logic with decision tree for starter program generation).
- Windows `icacls` + Unix `chmod` permission handling.
- `templates/git-hooks/pre-commit` script.
- Hevy key validation logic (curl + status check + masked display).
- Plugin scaffold: `.claude-plugin/plugin.json` and `marketplace.json` with correct schema.

Both lanes run in parallel where dependencies allow. Sequence and dependencies will be detailed in the implementation plan (next step via writing-plans skill).

## 9. Open questions / decisions made

- **Coaching scope:** generic (any goal). Decided 2026-05-27.
- **Distribution:** Claude Code plugin via marketplace. Decided 2026-05-27.
- **Data location:** user-chosen, default `~/fitness`. Decided 2026-05-27.
- **Onboarding fields:** identity/goals + training setup + coaching style + Hevy (nutrition out of scope). Decided 2026-05-27.
- **Hevy key filename:** `.hevy-api.txt` (per user request — note: differs from current `.hevy-key.txt` in source project). Decided 2026-05-27.
- **License:** MIT.
- **Initial version:** `0.1.0`.

## 10. Success criteria

- Friend with no prior context can: install plugin → run `/fitness-onboard` → answer questions → end up with a working data directory, validated Hevy connection, and week-1 plan they can start tomorrow.
- All Hevy curl calls from the plugin succeed against a real Hevy account (validated with author's account during dev).
- No Hevy key ever appears in chat transcripts, memory files, or git history.
- Plugin updates do not modify any file in the user's data directory.
- Repo is publicly cloneable and `/plugin marketplace add` from a fresh Claude Code install works end-to-end.
