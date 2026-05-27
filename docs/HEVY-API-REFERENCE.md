# Hevy API Reference

**Base URL:** `https://api.hevyapp.com/v1`
**Auth header:** `api-key: <key>` (not `Authorization: Bearer`)
**Transport:** Always use `curl` via the Bash tool — WebFetch cannot send custom headers correctly.

**Key file:** `<data-dir>/.hevy-api.txt`
Resolve `<data-dir>` by locating `.fitness-coach.json` at the current working directory or any
parent directory, then reading its `data_dir` field.

**Standard curl template:**
```bash
KEY=$(cat "<data-dir>/.hevy-api.txt" | tr -d '[:space:]')
curl -s -H "api-key: $KEY" "https://api.hevyapp.com/v1/ENDPOINT"
```

---

## Critical: Use curl (not WebFetch)

WebFetch fails to send custom headers correctly against the Hevy API. Always use the Bash tool
with `curl`. The `hevy-api` skill has full rules of engagement including key security requirements.

---

## Endpoints Reference

### GET /workouts/count

Returns total number of logged workouts.

```bash
KEY=$(cat "<data-dir>/.hevy-api.txt" | tr -d '[:space:]')
curl -s -H "api-key: $KEY" "https://api.hevyapp.com/v1/workouts/count"
# → {"workout_count": 95}
```

---

### GET /workouts

Paginated list of workouts, newest first. `pageSize` up to at least 10 confirmed.

```bash
KEY=$(cat "<data-dir>/.hevy-api.txt" | tr -d '[:space:]')
curl -s -H "api-key: $KEY" "https://api.hevyapp.com/v1/workouts?page=1&pageSize=10"
# → {"page":1,"page_count":10,"workouts":[...]}
```

**Workout fields:**

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | UUID |
| `title` | string | |
| `routine_id` | string \| null | ID of the routine it was logged from |
| `description` | string | |
| `start_time` | ISO 8601 | |
| `end_time` | ISO 8601 | |
| `updated_at` | ISO 8601 | |
| `created_at` | ISO 8601 | |
| `exercises[]` | array | See exercise fields below |

**Exercise fields (within a workout):**

| Field | Type | Notes |
|-------|------|-------|
| `index` | int | Order within workout |
| `title` | string | Display name |
| `notes` | string | |
| `exercise_template_id` | string | Links to `/exercise_templates` |
| `superset_id` | string \| null | |
| `sets[]` | array | See set fields below |

**Set fields (within a workout exercise):**

| Field | Type | Notes |
|-------|------|-------|
| `index` | int | Order within exercise |
| `type` | string | `normal` / `warmup` / `failure` / `dropset` |
| `weight_kg` | float \| null | |
| `reps` | int \| null | |
| `distance_meters` | float \| null | |
| `duration_seconds` | int \| null | |
| `rpe` | float \| null | Only on logged sets, not routine sets |
| `custom_metric` | any \| null | |

To fetch all workouts, iterate pages until `page >= page_count`.

---

### GET /workouts/{id}

Single workout by ID. Same schema as items in the list response.

```bash
KEY=$(cat "<data-dir>/.hevy-api.txt" | tr -d '[:space:]')
curl -s -H "api-key: $KEY" "https://api.hevyapp.com/v1/workouts/WORKOUT_ID"
```

---

### GET /routines

All routines (paginated). Returns full exercise and set data.

```bash
KEY=$(cat "<data-dir>/.hevy-api.txt" | tr -d '[:space:]')
curl -s -H "api-key: $KEY" "https://api.hevyapp.com/v1/routines"
# → {"page":1,"page_count":1,"routines":[...]}
```

Notes:
- Routine sets do **not** have `rpe` (that field exists only on logged workout sets).
- Sets in routines have no `notes` field.

---

### GET /routines/{id}

Single routine by ID. **Response shape differs from the list:** the value is a single object,
not an array.

```bash
KEY=$(cat "<data-dir>/.hevy-api.txt" | tr -d '[:space:]')
curl -s -H "api-key: $KEY" "https://api.hevyapp.com/v1/routines/ROUTINE_ID"
# → {"routine": {...}}   ← singular object, not array
```

Compare with list: `GET /routines` → `{"routines": [...]}` (plural array).

---

### GET /exercise_templates

Paginated library of all exercises (88+ pages at pageSize 5; use pageSize 20 for efficiency).

```bash
KEY=$(cat "<data-dir>/.hevy-api.txt" | tr -d '[:space:]')
curl -s -H "api-key: $KEY" "https://api.hevyapp.com/v1/exercise_templates?page=1&pageSize=20"
# → {"page":1,"page_count":N,"exercise_templates":[...]}
```

**Template fields:**

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | Use this in routine exercises |
| `title` | string | Display name |
| `type` | string | `weight_reps` / `reps_only` / `duration` / etc. |
| `primary_muscle_group` | string | |
| `secondary_muscle_groups[]` | array | |
| `equipment` | string | |
| `is_custom` | bool | True if user-created |

---

### GET /exercise_templates/{id}

Single exercise template by ID.

```bash
KEY=$(cat "<data-dir>/.hevy-api.txt" | tr -d '[:space:]')
curl -s -H "api-key: $KEY" "https://api.hevyapp.com/v1/exercise_templates/TEMPLATE_ID"
```

---

### POST /routines — Create new routine

HTTP 201 on success.

**Response quirk:** The `routine` value in the response is an **array**, not an object
(unlike `GET /routines/{id}` which returns an object).

```bash
KEY=$(cat "<data-dir>/.hevy-api.txt" | tr -d '[:space:]')
curl -s -X POST \
  -H "api-key: $KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "routine": {
      "title": "Day A — Upper Push",
      "folder_id": null,
      "exercises": [
        {
          "exercise_template_id": "3601968B",
          "superset_id": null,
          "rest_seconds": 90,
          "sets": [
            {"type": "warmup", "weight_kg": 20, "reps": 8, "distance_meters": null, "duration_seconds": null, "custom_metric": null},
            {"type": "normal", "weight_kg": 27.5, "reps": 8, "distance_meters": null, "duration_seconds": null, "custom_metric": null}
          ]
        }
      ]
    }
  }' \
  "https://api.hevyapp.com/v1/routines"
```

---

### PUT /routines/{id} — Update existing routine

HTTP 200 on success. **Replaces the entire routine** — all exercises must be included.

```bash
KEY=$(cat "<data-dir>/.hevy-api.txt" | tr -d '[:space:]')
curl -s -X PUT \
  -H "api-key: $KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "routine": {
      "title": "Day A — Upper Push",
      "exercises": [
        {
          "exercise_template_id": "3601968B",
          "superset_id": null,
          "rest_seconds": 90,
          "sets": [
            {"type": "warmup", "weight_kg": 20, "reps": 8, "distance_meters": null, "duration_seconds": null, "custom_metric": null},
            {"type": "normal", "weight_kg": 30, "reps": 8, "distance_meters": null, "duration_seconds": null, "custom_metric": null}
          ]
        }
      ]
    }
  }' \
  "https://api.hevyapp.com/v1/routines/ROUTINE_ID"
```

---

## POST vs PUT Field Rules

| Field | POST `/routines` | PUT `/routines/{id}` |
|-------|-----------------|---------------------|
| `routine.folder_id` | **Required** — must be `null` | **Not allowed** — causes error |
| `routine.notes` | Omit or non-empty string | Omit or non-empty — **empty `""` causes error** |
| `exercise.index` | Not allowed (API rejects) | Not allowed |
| `exercise.title` | Not allowed (API derives from template) | Not allowed |
| `exercise.notes` | Omit or non-empty | **Empty `""` causes error** |
| `set.index` | Not allowed | Not allowed |

---

## Set Types

| `type` value | Use for |
|---|---|
| `normal` | Regular working sets |
| `warmup` | Warm-up sets |
| `failure` | Sets taken to failure |
| `dropset` | Drop sets |

---

## Pagination Pattern

```bash
KEY=$(cat "<data-dir>/.hevy-api.txt" | tr -d '[:space:]')

# Page 1
curl -s -H "api-key: $KEY" "https://api.hevyapp.com/v1/workouts?page=1&pageSize=10"

# Check page_count in response, then fetch remaining pages
curl -s -H "api-key: $KEY" "https://api.hevyapp.com/v1/workouts?page=2&pageSize=10"
# ... repeat until page == page_count
```

The pattern is the same for `/workouts`, `/routines`, and `/exercise_templates`.
Response always includes `page` and `page_count` fields at the top level.

---

## Finding Exercise Template IDs

To find exercise template IDs, page through `GET /exercise_templates?page=1&pageSize=20`
until you locate the exercise by `title` and copy its `id` field. Alternatively, fetch your
existing workouts via `GET /workouts` and grep the `exercise_template_id` values already in use —
any exercise you have previously logged in Hevy will appear there with the correct ID.

---

## Endpoints That Don't Exist

| Endpoint | Response | Notes |
|----------|----------|-------|
| `DELETE /routines/{id}` | 404 | Routines cannot be deleted via the API — delete from the Hevy app |
| `GET /profile` | 404 | Not available |
| `GET /workout_events` | 404 | Not available |
