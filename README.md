# claude-fitness-coach

A Claude Code plugin that turns Claude into a personal fitness coach connected to your Hevy account. You run a one-time onboarding wizard that captures your goals, training schedule, equipment, and coaching preferences; the plugin generates a personalized week-1 program and keeps coaching you session-to-session, adapting based on your logged workouts and weekly reviews. It works for any goal type — fat loss, muscle gain, strength, maintenance, general fitness, or sport-specific preparation — and stores all your data in a plain-markdown directory you own and control.

---

## Prerequisites

- **Claude Code** installed and authenticated. See [claude.ai/code](https://claude.ai/code).
- **Hevy account** with API key access. Get your key in the Hevy app under **Settings → Developer**. (If you do not see a Developer section, make sure your Hevy subscription is active; API access is available on paid plans.)
- **`curl`** available on your PATH. It ships by default on macOS and most Linux distros. On Windows 10 and later, `curl.exe` is built into the system — no install needed.

---

## Install (60 seconds)

Run these three commands in Claude Code, in order:

```
/plugin marketplace add https://github.com/<user>/claude-fitness-coach
/plugin install fitness-coach
/fitness-onboard
```

> Note: `<user>` is a placeholder for the GitHub username where this repo is published.

The third command starts the onboarding wizard. It asks questions in six short stages and ends with a generated week-1 plan ready to start the next day.

---

## What gets stored where

```
~/.claude/plugins/cache/fitness-coach/     Plugin code (managed by Claude Code)
                                           Updated via /plugin update.
                                           Never contains your personal data.

<data-dir>/                                Your data directory.
  Default: ~/fitness/                      Chosen during onboarding.
  CLAUDE.md                                Coach instructions (edit freely)
  workout-log.md                           Session log
  week-1-plan.md, week-2-plan.md, ...      Weekly programs
  week-plan-template.md                    Template for new weeks
  memory/                                  Goal, equipment, coaching prefs
  .fitness-coach.json                      Plugin config (safe to commit)
  .hevy-api.txt                            Hevy API key (gitignored, perm-locked)
```

Plugin updates (via `/plugin update`) touch only the plugin cache directory. They never modify any file inside your data directory.

---

## Daily / weekly use

| Command | When to run | What it does |
|---|---|---|
| `/fitness-onboard` | First run, or any time you want to update your profile | Onboarding wizard; if already onboarded, shows a menu to edit profile, coaching style, rotate Hevy key, regenerate week plan, or start fresh |
| `/fitness-session` | Before each training session | Reads your current week plan, recent log entries, and fatigue signals; produces a pre-session brief with today's targets |
| `/fitness-log` | After each session | Appends a structured entry to `workout-log.md` using the canonical Gym / Swim / Weight-only templates |
| `/fitness-review` | Once a week (Sunday by default) | Reads the week's log, analyzes weight trend, RPE drift, adherence; proposes adjustments; on approval writes the next week's plan |

---

## Security

- **Key storage.** Your Hevy API key is written as plain text to `<data-dir>/.hevy-api.txt`. It is not encrypted at rest. The file's access is restricted at the OS level: `chmod 600` on macOS/Linux (owner read/write only), and `icacls /inheritance:r /grant:r` on Windows (stripping inherited ACLs, leaving only the current user). This is the same protection model as SSH private keys.

- **Gitignore.** Onboarding writes a `.gitignore` into your data directory that lists `.hevy-api.txt`. If you initialize a git repo in your data directory, the key file will not be staged by default.

- **Optional pre-commit hook.** During onboarding you can opt in to install a pre-commit hook (`templates/git-hooks/pre-commit`) in your data directory's git repo. The hook scans staged content for strings matching a Hevy-key shape (long alphanumeric token near a "hevy" or "api-key" context) and blocks the commit if found. It prints a `--no-verify` escape hatch for false positives.

- **Network calls.** The plugin makes outbound HTTP calls only to `https://api.hevyapp.com`. There is no telemetry, no analytics, and no callback to the plugin author. Claude itself reads your local files when you invoke a command; that is governed by your Claude Code session's normal data handling.

- **Key rotation.** There is no rotation API in Hevy. To rotate, generate a new key in Hevy's UI, overwrite `<data-dir>/.hevy-api.txt`, and run `/fitness-onboard` → "Rotate Hevy key" to re-validate.

---

## Customization

All files in your data directory are plain Markdown. You can edit them directly:

- **`CLAUDE.md`** — the coach's core instructions. Change your goal, adjust standing rules, add sport-specific notes, or modify the red-flag thresholds. Claude reads this at the start of every session.
- **`memory/*.md`** — profile, coaching preferences, equipment and schedule. These are the structured facts the coach draws on. Edit any field to reflect a change (new gym, different schedule, updated goal).
- **`week-{N}-plan.md`** — the active week's program. If you want to swap an exercise or adjust a volume target manually, just edit the file; the coach will read your version next session.

No plugin reinstall is needed after editing. Changes take effect the next time you run a command.

---

## Troubleshooting

**Hevy key validation fails**
- Confirm the key is copied in full with no leading/trailing spaces.
- Test your internet connection: `curl -I https://api.hevyapp.com` should return HTTP headers.
- Check whether you recently rotated the key in Hevy's UI — if so, the stored key is stale. Run `/fitness-onboard` → "Rotate Hevy key".
- Hevy returns 401 if the key is invalid and 429 if you've exceeded rate limits. The wizard displays the raw HTTP status to help diagnose.

**Plugin doesn't activate / commands not found**
- The plugin is activated when Claude Code finds a `.fitness-coach.json` file at your current working directory or any parent directory. Make sure you are working in or below your data directory when running `/fitness-session`, `/fitness-log`, or `/fitness-review`.
- If `.fitness-coach.json` is missing, re-run `/fitness-onboard` to regenerate it.

**Windows ACL command fails**
- The `icacls` command must be run as the same user who owns the file. If you opened your terminal via "Run as administrator," the effective owner may differ from your normal user account. Close the elevated terminal and run from a standard prompt.
- If the command still fails, you can manually restrict the file: right-click `<data-dir>\.hevy-api.txt` → Properties → Security → remove all entries except your own user account.

**`workout-log.md` has stale or malformed entries**
- The `workout-logging` skill enforces the canonical templates strictly and will not invent fields. If you edited the log manually and broke the structure, the coach may misread entries. Check that each entry starts with the correct section header (`## Gym Entry`, `## Swim Entry`, or `## Weight-only Entry`) and that no fields are missing.

---

## License

MIT. See [LICENSE](LICENSE).

---

## Acknowledgments

Built on [Claude Code's plugin system](https://claude.ai/code). Hevy integration uses the Hevy REST API — all workout data remains in your Hevy account and your local data directory.
