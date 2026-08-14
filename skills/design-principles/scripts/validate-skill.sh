#!/usr/bin/env bash
# Structural self-check for the design-principles skill.
# Validates the Anthropic skill-authoring rules this skill was built to:
#   frontmatter present, SKILL.md < 500 lines, all relative links resolve,
#   reference files >100 lines start with a Contents TOC,
#   every entry carries the Use when / Skip when / Trade-off template.
# Exit codes: 0 = valid, 1 = violations found.
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
err() { echo "FAIL: $*"; FAIL=1; }

# --- SKILL.md ---------------------------------------------------------------
SKILL_MD="$SKILL_DIR/SKILL.md"
[[ -f "$SKILL_MD" ]] || { err "SKILL.md missing"; echo "RESULT: invalid."; exit 1; }

head -1 "$SKILL_MD" | grep -q '^---$' || err "SKILL.md: missing YAML frontmatter"
grep -q '^name: design-principles$' "$SKILL_MD" || err "SKILL.md: frontmatter 'name: design-principles' missing"
grep -q '^description: .\+' "$SKILL_MD" || err "SKILL.md: frontmatter description missing"

lines=$(wc -l < "$SKILL_MD" | tr -d ' ')
(( lines < 500 )) && echo "OK   SKILL.md is $lines lines (<500)" || err "SKILL.md is $lines lines (must stay <500)"

# --- links resolve (SKILL.md + all reference files) --------------------------
while IFS=: read -r file link; do
  base_dir=$(dirname "$file")
  target="${link%%#*}"
  [[ -z "$target" ]] && continue
  [[ -f "$base_dir/$target" || -f "$SKILL_DIR/$target" ]] || err "$(basename "$file"): broken link -> $target"
done < <(
  for f in "$SKILL_MD" "$SKILL_DIR"/references/*.md; do
    grep -Eo '\]\(([^)#]+\.md)[^)]*\)' "$f" 2>/dev/null | sed -E 's/\]\(([^)]*)\)/\1/' | sed "s|^|$f:|"
  done
)

# --- reference files ---------------------------------------------------------
for f in "$SKILL_DIR"/references/*.md; do
  name=$(basename "$f")
  flines=$(wc -l < "$f" | tr -d ' ')
  if (( flines > 100 )); then
    head -20 "$f" | grep -q '^## Contents' || err "$name: >100 lines but no '## Contents' TOC at top"
  fi
done

# --- entry template integrity (principle/pattern files only) -----------------
for f in solid.md package-principles.md general-principles.md creational-patterns.md structural-patterns.md behavioral-patterns.md; do
  p="$SKILL_DIR/references/$f"
  [[ -f "$p" ]] || { err "references/$f missing"; continue; }
  use=$(grep -c '^\*\*Use when:\*\*' "$p")
  skip=$(grep -c '^\*\*Skip when:\*\*' "$p")
  trade=$(grep -c '^\*\*Trade-off:\*\*' "$p")
  if [[ "$use" -eq "$skip" && "$skip" -eq "$trade" && "$use" -gt 0 ]]; then
    echo "OK   $f: $use entries with full Use/Skip/Trade-off template"
  else
    err "$f: template mismatch (Use when: $use, Skip when: $skip, Trade-off: $trade)"
  fi
  grep -q '^## Sources' "$p" || err "$f: missing '## Sources' section"
done

# --- pattern files must carry Idiomatic TS notes -----------------------------
for f in creational-patterns.md structural-patterns.md behavioral-patterns.md; do
  p="$SKILL_DIR/references/$f"
  [[ -f "$p" ]] || continue
  entries=$(grep -c '^\*\*Use when:\*\*' "$p")
  idio=$(grep -c '^\*\*Idiomatic TS:\*\*' "$p")
  (( idio >= entries )) || err "$f: $idio 'Idiomatic TS' notes for $entries entries"
done

echo
if (( FAIL )); then
  echo "RESULT: invalid."
  exit 1
fi
echo "RESULT: valid."
