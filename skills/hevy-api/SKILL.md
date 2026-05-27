---
name: hevy-api
description: Use whenever the user needs to read from or write to Hevy. Provides curl recipes, endpoint reference, POST/PUT field rules, set-type enum, pagination, and unilateral-exercise convention. Reads the API key from <data-dir>/.hevy-api.txt at point-of-use and never echoes it.
---

# Hevy API Skill

Full endpoint details, curl examples, and field rules are in `docs/HEVY-API-REFERENCE.md`
(relative to the plugin root). This skill covers the rules of engagement and quick reference.

---

## Rules of Engagement

### Transport

- **Always use `curl` via the Bash tool.** WebFetch cannot send custom headers correctly and will fail.
- **Never use WebFetch, fetch(), or any HTTP library** to call the Hevy API.

### Authentication

- Auth header is `api-key: <key>` — **not** `Authorization: Bearer <key>`.
- **Never put the key in the URL** (no `?api_key=...` query params).
- The key is read from a file at call time — never stored in a variable that gets logged.

### Key File Location

The API key is stored at `<data-dir>/.hevy-api.txt`.

**Resolving `<data-dir>`:**

1. Look for `.fitness-coach.json` in the current working directory, then walk up parent directories.
2. Parse the `data_dir` field from that JSON.
3. The key file is then `<data-dir>/.hevy-api.txt`.

```bash
# Resolve data_dir and read the key (one-liner)
DATA_DIR=$(python3 -c "import json,pathlib; \
  p=pathlib.Path('.'); \
  [exit(0) or print(json.load(open(str(p/'.fitness-coach.json')))['data_dir']) \
   for _ in [None] if (p/'.fitness-coach.json').exists()] or \
  [exit(0) or print(json.load(open(str(pp/'.fitness-coach.json')))['data_dir']) \
   for pp in p.parents if (pp/'.fitness-coach.json').exists()]" 2>/dev/null)

KEY=$(cat "$DATA_DIR/.hevy-api.txt" | tr -d '[:space:]')
```

Or with a simple shell loop:

```bash
DATA_DIR=""
dir="$(pwd)"
while [ "$dir" != "/" ]; do
  if [ -f "$dir/.fitness-coach.json" ]; then
    DATA_DIR=$(python3 -c "import json; print(json.load(open('$dir/.fitness-coach.json'))['data_dir'])")
    break
  fi
  dir="$(dirname "$dir")"
done
```

### Key Security Rules

- **Never echo the key** to the terminal, to chat, or to any file other than `.hevy-api.txt`.
- **Never log the key** in command output shown to the user.
- **Never write the key to memory** (CLAUDE.md, memory/*.md, week plans, workout logs).
- When confirming an action that used the key, **mask it**: show only the last 4 chars — e.g., `api-key: ••••a5b2`.

### Standard curl Template

```bash
KEY=$(cat "<data-dir>/.hevy-api.txt" | tr -d '[:space:]')
curl -s -H "api-key: $KEY" "https://api.hevyapp.com/v1/ENDPOINT"
```

---

## Endpoint Summary

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/workouts/count` | Total workout count |
| GET | `/workouts` | Paginated workout list (newest first) |
| GET | `/workouts/{id}` | Single workout by ID |
| GET | `/routines` | All routines (paginated, full data) |
| GET | `/routines/{id}` | Single routine (wrapped in `{"routine":{}}`) |
| GET | `/exercise_templates` | Paginated exercise library |
| GET | `/exercise_templates/{id}` | Single exercise template |
| POST | `/routines` | Create new routine (HTTP 201) |
| PUT | `/routines/{id}` | Replace entire routine (HTTP 200) |

See `docs/HEVY-API-REFERENCE.md` for full request/response schemas and curl examples.

---

## Common Pitfalls

### POST vs PUT differences

| Field | POST `/routines` | PUT `/routines/{id}` |
|-------|-----------------|---------------------|
| `routine.folder_id` | **Required** (must be `null`) | **Not allowed** — causes error |
| `routine.notes` | Omit or non-empty string | Omit or non-empty — **empty `""` causes error** |
| `exercise.index` | Not allowed | Not allowed |
| `exercise.title` | Not allowed | Not allowed |
| `exercise.notes` | Omit or non-empty | **Empty `""` causes error** |
| `set.index` | Not allowed | Not allowed |

### Other pitfalls

- **PUT replaces the entire routine.** All exercises must be included in every PUT — it is not a patch.
- **No DELETE.** `DELETE /routines/{id}` returns 404. Users must delete routines from the Hevy app.
- **Routine list vs single response shape differ.** `GET /routines` returns `{"routines":[...]}`;
  `GET /routines/{id}` returns `{"routine":{...}}` (singular, not an array).
- **POST /routines response quirk.** On success the `routine` value is an array, not an object.
- **Routine sets have no `rpe` field.** RPE exists only on workout (logged) sets, not routine sets.
- **`notes: ""` on exercise.** An empty string is rejected by PUT. Omit the field entirely if there are no notes.

### Unilateral exercise convention

When reading Hevy data for unilateral exercises (single-arm curl, single-leg press, etc.),
Hevy records each side as a separate set. **Halve the set count when logging to workout-log.md.**
Example: Hevy shows 4 sets → log as "2 sets per side".

---

## Writes Require Explicit User Sign-Off

Any POST or PUT to Hevy modifies the user's app data and cannot be undone via the API.
Always present the full payload for review and wait for explicit confirmation before executing a write.

---

## Further Reference

Full documentation with complete curl examples, all response field schemas, set-type enum,
and pagination patterns: **`docs/HEVY-API-REFERENCE.md`** (plugin root).
