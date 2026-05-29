#!/bin/sh
# claude-fitness-coach plugin — structural validation script.
#
# Run from the repo root. Exits 0 if all checks pass, non-zero on first failure.
# Each check prints a one-line status. Use this before tagging a release.

set -u

PASS=0
FAIL=0

ok()   { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }

require_file() {
    if [ -f "$1" ]; then
        ok "$1"
    else
        bad "missing: $1"
    fi
}

require_executable() {
    if [ -f "$1" ] && [ -x "$1" ]; then
        ok "$1 (executable)"
    else
        bad "not executable or missing: $1"
    fi
}

# Detect a working python interpreter once (Windows ships a broken `python3`
# Store stub that exits non-zero on real invocations).
PYTHON=""
for candidate in python python3; do
    if command -v "$candidate" >/dev/null 2>&1; then
        if "$candidate" --version >/dev/null 2>&1; then
            PYTHON="$candidate"
            break
        fi
    fi
done

require_json() {
    if [ ! -f "$1" ]; then
        bad "missing: $1"
        return
    fi
    if [ -n "$PYTHON" ]; then
        if "$PYTHON" -c "import json, sys; json.load(open(sys.argv[1]))" "$1" 2>/dev/null; then
            ok "$1 (valid JSON)"
        else
            bad "invalid JSON: $1"
        fi
    else
        # Fallback: very weak — just check braces exist
        if grep -q '{' "$1" && grep -q '}' "$1"; then
            ok "$1 (brace-shape; install python for real check)"
        else
            bad "no JSON braces: $1"
        fi
    fi
}

require_starts_with_frontmatter() {
    if [ ! -f "$1" ]; then
        bad "missing: $1"
        return
    fi
    first_line=$(head -n 1 "$1")
    if [ "$first_line" = "---" ]; then
        ok "$1 (has frontmatter)"
    else
        bad "no frontmatter: $1"
    fi
}

echo ""
echo "== Plugin manifest =="
require_json ".claude-plugin/plugin.json"
require_json ".claude-plugin/marketplace.json"

# Validate every marketplace plugin source. A string source must be a relative
# path starting with "./" (a bare "." is rejected by Claude Code as an
# unsupported source type) that resolves to a dir containing a plugin manifest.
# An object source must declare a recognized type (github/url/git-subdir/npm)
# with that type's required fields.
require_plugin_sources() {
    if [ -z "$PYTHON" ]; then
        ok ".claude-plugin/marketplace.json plugin sources (skipped; install python for check)"
        return
    fi
    msg=$("$PYTHON" - <<'PY'
import json, os, sys
root = os.getcwd()
with open(os.path.join(root, ".claude-plugin", "marketplace.json"), encoding="utf-8") as fh:
    marketplace = json.load(fh)
RECOGNIZED = {"github": ["repo"], "url": ["url"], "git-subdir": ["url", "path"], "npm": ["package"]}
for index, plugin in enumerate(marketplace.get("plugins", [])):
    source = plugin.get("source")
    if isinstance(source, str):
        if not source.startswith("./"):
            print(f"plugins[{index}].source string must start with './' (found {source!r})")
            sys.exit(1)
        manifest = os.path.normpath(os.path.join(root, source, ".claude-plugin", "plugin.json"))
        if not os.path.isfile(manifest):
            print(f"plugins[{index}].source missing .claude-plugin/plugin.json: {source}")
            sys.exit(1)
    elif isinstance(source, dict):
        stype = source.get("source")
        if stype not in RECOGNIZED:
            print(f"plugins[{index}].source has unrecognized type {stype!r} (expected one of {sorted(RECOGNIZED)})")
            sys.exit(1)
        missing = [f for f in RECOGNIZED[stype] if not source.get(f)]
        if missing:
            print(f"plugins[{index}].source ({stype}) missing required field(s): {missing}")
            sys.exit(1)
    else:
        print(f"plugins[{index}].source must be a string or object (found {type(source).__name__})")
        sys.exit(1)
PY
)
    if [ $? -eq 0 ]; then
        ok ".claude-plugin/marketplace.json plugin sources"
    else
        bad "marketplace.json source: $msg"
    fi
}
require_plugin_sources

echo ""
echo "== Skills =="
for s in fitness-onboarding fitness-coaching hevy-api weekly-review workout-logging; do
    require_starts_with_frontmatter "skills/$s/SKILL.md"
done

echo ""
echo "== Commands =="
for c in fitness-onboard fitness-session fitness-log fitness-review; do
    require_starts_with_frontmatter "commands/$c.md"
done

echo ""
echo "== Templates =="
require_file "templates/CLAUDE.md.tmpl"
require_file "templates/workout-log.md.tmpl"
require_file "templates/week-plan-template.md"
require_file "templates/swim-alternate-template.md"
require_file "templates/memory/MEMORY.md.tmpl"
require_file "templates/memory/profile.md.tmpl"
require_file "templates/memory/coaching-preferences.md.tmpl"
require_file "templates/memory/equipment-and-schedule.md.tmpl"
require_file "templates/gitignore.tmpl"
require_file "templates/fitness-coach-config.json.tmpl"
require_executable "templates/git-hooks/pre-commit"

echo ""
echo "== Docs =="
require_file "README.md"
require_file "LICENSE"
require_file "docs/HEVY-API-REFERENCE.md"

echo ""
echo "== No leaked user-specific strings =="
# Build the exclusion path list so we ignore the spec/plan dirs which legitimately
# discuss the source project.
LEAK_FOUND=0
for s in "Lagos" "Dubai" "aa9f32a0-c0da-4a38-a545-68baec25d797" "c3b0c721-45ac-471d-a515-afa324231c79" "airoidswithgautam"; do
    # Search everything except docs/superpowers/{specs,plans} (legitimately discuss source)
    # and scripts/ (this validator script itself contains the search strings).
    hits=$(grep -r -l --exclude-dir=.git --exclude-dir=specs --exclude-dir=plans --exclude-dir=scripts -F "$s" . 2>/dev/null || true)
    if [ -n "$hits" ]; then
        bad "found leaked string '$s' in: $hits"
        LEAK_FOUND=1
    fi
done
if [ "$LEAK_FOUND" -eq 0 ]; then
    ok "no leaked user-specific strings outside docs/superpowers/"
fi

echo ""
echo "== Template substitution dry-run =="
# Render CLAUDE.md.tmpl with a mock answer set and verify no {{...}} remains.
TMP_RENDER="/tmp/fitness-coach-render-test.md"
rm -f "$TMP_RENDER"

# Mock substitutions
sed \
    -e 's/{{USER_NAME}}/Alex/g' \
    -e 's/{{AGE}}/28/g' \
    -e 's/{{SEX}}/male/g' \
    -e 's/{{HEIGHT}}/180 cm/g' \
    -e 's/{{CURRENT_WEIGHT}}/82/g' \
    -e 's/{{UNITS}}/kg/g' \
    -e 's/{{LOCATION_CONTEXT}}/None/g' \
    -e 's/{{PRIMARY_GOAL}}/fat_loss/g' \
    -e 's/{{GOAL_DETAIL}}/75 kg in 12 weeks/g' \
    -e 's/{{SECONDARY_GOALS}}/None/g' \
    -e 's/{{INJURIES_LIMITATIONS}}/None/g' \
    -e 's/{{DAYS_PER_WEEK}}/5/g' \
    -e 's/{{SESSION_LENGTH_MIN}}/60/g' \
    -e 's/{{TIME_OF_DAY}}/7-8am/g' \
    -e 's|{{EQUIPMENT_SUMMARY}}|full gym|g' \
    -e 's/{{MODALITIES}}/lift, swim/g' \
    -e 's|{{WEEKLY_STRUCTURE_TABLE}}|(table)|g' \
    -e 's/{{COACHING_TONE}}/direct/g' \
    -e 's/{{AUTONOMY_LEVEL}}/ask_before_changes/g' \
    -e 's/{{PUSHBACK_INTENSITY}}/3/g' \
    -e 's/{{START_DATE}}/2026-05-27/g' \
    -e 's/{{RECENT_TRAJECTORY}}/None reported/g' \
    -e 's/{{GOAL_TARGET}}/75 kg/g' \
    -e 's/{{GOAL_TIMELINE}}/12 weeks/g' \
    -e 's/{{SELF_CONSTRAINTS}}/None/g' \
    -e 's/{{INJURIES_CONDITIONS}}/None/g' \
    -e 's/{{TRAINING_WINDOW}}/7-8am/g' \
    -e 's|{{EQUIPMENT_LIST}}|- full gym|g' \
    -e 's/{{RPE_LOGGING_PREFERENCE}}/always/g' \
    templates/CLAUDE.md.tmpl > "$TMP_RENDER"

if grep -q '{{[A-Z_]*}}' "$TMP_RENDER"; then
    remaining=$(grep -o '{{[A-Z_]*}}' "$TMP_RENDER" | sort -u | head -20 | tr '\n' ' ')
    bad "CLAUDE.md.tmpl has unrendered placeholders after mock substitution: $remaining"
else
    ok "CLAUDE.md.tmpl renders with no remaining {{...}} placeholders"
fi

# Note: conditional blocks <!-- IF KEY=VALUE --> are NOT stripped by this dry-run;
# that's done by the onboarding skill at render time. We just check placeholders here.

echo ""
echo "================================================================"
printf "  PASS: %d   FAIL: %d\n" "$PASS" "$FAIL"
echo "================================================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
