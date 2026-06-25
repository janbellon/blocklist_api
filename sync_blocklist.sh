#!/bin/bash

set -euo pipefail

source /opt/blocklist/blocklist_sync.env

STATE_DIR="/var/lib/blocklist-sync"
LAST_SYNC_FILE="$STATE_DIR/last_sync"
IPSET_NAME="blocklist"

mkdir -p "$STATE_DIR"

# Create ipset if not exists
if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
    ipset create "$IPSET_NAME" hash:ip
fi

# Init sync file
if [ ! -f "$LAST_SYNC_FILE" ]; then
    echo 0 > "$LAST_SYNC_FILE"
fi

LAST_SYNC=$(cat "$LAST_SYNC_FILE")

# Fetch changes
RESPONSE=$(curl -s --fail --max-time 10 \
    -H "Authorization: Bearer $TOKEN" \
    "$API_URL/changes?since=$LAST_SYNC")

# Validate JSON
echo "$RESPONSE" | jq empty

NEW_LAST_SYNC="$LAST_SYNC"

# IMPORTANT: no pipe into while (avoid subshell issue)
while read -r ENTRY; do

    ADDRESS=$(jq -r '.address' <<< "$ENTRY")
    DELETED=$(jq -r '.deleted' <<< "$ENTRY")
    UPDATED_AT=$(jq -r '.updated_at' <<< "$ENTRY")

    if [ "$DELETED" = "true" ]; then
        ipset del "$IPSET_NAME" "$ADDRESS" 2>/dev/null || true

        logger -t blocklist-sync "UNBAN $ADDRESS"
    else
        ipset add "$IPSET_NAME" "$ADDRESS" -exist

        logger -t blocklist-sync "BAN $ADDRESS"
    fi

    if [ "$UPDATED_AT" -gt "$NEW_LAST_SYNC" ]; then
        NEW_LAST_SYNC="$UPDATED_AT"
    fi

done < <(echo "$RESPONSE" | jq -c '.[]')

echo "$NEW_LAST_SYNC" > "$LAST_SYNC_FILE"
