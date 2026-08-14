#!/usr/bin/env bash
# Source drift check for the design-principles skill.
# Verifies registered sources are reachable, reports GitHub repo push dates,
# and fails when the registry's last full verification is older than MAX_AGE_DAYS.
# Exit codes: 0 = fresh, 1 = drift found (stale registry, dead source, or repo moved).
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCES_MD="$SKILL_DIR/references/sources.md"
MAX_AGE_DAYS=180
DRIFT=0

# --- staleness gate ---------------------------------------------------------
last_verified=$(grep -Eo 'Last full verification: \*\*[0-9]{4}-[0-9]{2}-[0-9]{2}\*\*' "$SOURCES_MD" | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}')
if [[ -z "$last_verified" ]]; then
  echo "DRIFT: no 'Last full verification' date found in sources.md"
  DRIFT=1
else
  last_epoch=$(date -j -f "%Y-%m-%d" "$last_verified" +%s 2>/dev/null || date -d "$last_verified" +%s)
  age_days=$(( ( $(date +%s) - last_epoch ) / 86400 ))
  echo "Registry last verified: $last_verified (${age_days}d ago, max ${MAX_AGE_DAYS}d)"
  if (( age_days > MAX_AGE_DAYS )); then
    echo "DRIFT: registry is stale — run the full update procedure (SKILL.md → Maintenance)"
    DRIFT=1
  fi
fi

# --- reachability -----------------------------------------------------------
# URLs come from the registry table between the check-sources markers.
urls=$(sed -n '/check-sources:begin/,/check-sources:end/p' "$SOURCES_MD" | grep -Eo 'https?://[^ |)]+')
for url in $urls; do
  # butunclebob is HTTP-only and utu.fi has broken TLS (documented in sources.md) — tolerate with -k, GET not HEAD (some hosts 405 HEAD).
  code=$(curl -k -s -L -o /dev/null -m 20 -w '%{http_code}' -A 'design-principles-skill-check' "$url")
  if [[ "$code" =~ ^(2|3) ]]; then
    printf 'OK   %-3s %s\n' "$code" "$url"
  else
    printf 'DEAD %-3s %s\n' "$code" "$url"
    DRIFT=1
  fi
done

# --- GitHub repo freshness (informational: shows what to re-review) --------
for repo in RefactoringGuru/design-patterns-typescript adnanhakim/copilot-instructions DovAmir/awesome-design-patterns mehdihadeli/awesome-software-architecture anthropics/skills; do
  pushed=$(curl -s -m 20 "https://api.github.com/repos/$repo" | grep -m1 '"pushed_at"' | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}')
  if [[ -n "$pushed" ]]; then
    echo "REPO $repo last push: $pushed$( [[ "$pushed" > "$last_verified" ]] && echo '  <- pushed since last verification, re-review' )"
  else
    echo "REPO $repo: could not read push date (rate limit?)"
  fi
done

echo
if (( DRIFT )); then
  echo "RESULT: DRIFT — update needed."
  exit 1
fi
echo "RESULT: fresh."
