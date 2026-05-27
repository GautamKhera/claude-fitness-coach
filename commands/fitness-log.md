---
description: Append a workout / swim / weight entry using the canonical templates.
---

Invoke the `workout-logging` skill.

Ask which template to use (Gym / Swim / Weight-only) unless context makes it obvious. Gather the field values from the user, then append the entry to the `## Sessions` section of `workout-log.md` in the user's data directory. Weight-only entries go into the `## Weight Log` table instead.

Refuse to invent fields, reorder fields, or skip section headers. Apply the unilateral-set halving convention when reading Hevy data (4 Hevy entries = 2 sets per side for single-arm/leg exercises).
