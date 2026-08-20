#!/usr/bin/env bash
# Fetch CBP border wait times and archive distinct readings for the El Paso ports.
#
# Layout:
#   latest.json                    - pretty snapshot of the last fetch (all El Paso ports)
#   data/YYYY/MM/YYYY-MM-DD.ndjson - one line per *distinct* port reading, stamped with fetched_at (UTC)
#   state/<port_number>.json       - last seen reading per port (minus feed timestamps), for change detection
#
# A reading is "distinct" when anything other than the feed's own generation
# timestamp (top-level "date"/"time") changed since the last archived reading
# for that port. CBP updates roughly hourly; polling every 10 minutes with
# dedupe keeps only real transitions.

set -euo pipefail
cd "$(dirname "$0")"

API_URL="https://bwt.cbp.gov/api/waittimes"
FETCHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DAY_DIR="data/$(date -u +%Y/%m)"
DAY_FILE="$DAY_DIR/$(date -u +%Y-%m-%d).ndjson"

raw="$(mktemp)"
trap 'rm -f "$raw"' EXIT

curl --silent --show-error --fail \
     --max-time 60 --retry 3 --retry-delay 15 \
     --header 'Accept: application/json' \
     --output "$raw" \
     "$API_URL"

# Validate: parseable JSON array that actually contains the El Paso ports.
count="$(jq '[.[] | select(.port_name == "El Paso")] | length' "$raw")"
if [ "$count" -lt 1 ]; then
    echo "ERROR: response parsed but contained no El Paso ports" >&2
    exit 1
fi

mkdir -p "$DAY_DIR" state

jq --arg fetched_at "$FETCHED_AT" \
   '{fetched_at: $fetched_at, ports: [.[] | select(.port_name == "El Paso")]}' \
   "$raw" > latest.json

changed=0
for port in $(jq -r '.ports[].port_number' latest.json); do
    # Core view: the reading minus the feed's own generation timestamp,
    # key-sorted so comparison is stable.
    core="$(jq -S --arg p "$port" '.ports[] | select(.port_number == $p) | del(.date, .time)' latest.json)"
    state_file="state/$port.json"

    if [ -f "$state_file" ] && [ "$core" = "$(cat "$state_file")" ]; then
        continue
    fi

    printf '%s' "$core" > "$state_file"
    jq -c --arg fetched_at "$FETCHED_AT" --arg p "$port" \
       '.ports[] | select(.port_number == $p) | {fetched_at: $fetched_at} + .' \
       latest.json >> "$DAY_FILE"
    changed=1
    echo "changed: port $port"
done

if [ "$changed" -eq 0 ]; then
    echo "no changes since last distinct reading"
fi

# Signal to the workflow whether there is anything worth committing.
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "changed=$changed" >> "$GITHUB_OUTPUT"
fi
