#!/bin/bash

set -euo pipefail

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

source /opt/blocklist/blocklist_sync.env

STATE_DIR="/var/lib/blocklist-sync"

LAST_SYNC_IP_FILE="$STATE_DIR/last_sync_ip"
LAST_SYNC_NET_FILE="$STATE_DIR/last_sync_net"

IPSET_NAME="blocklist"
NETSET_NAME="blocklist_networks"

mkdir -p "$STATE_DIR"

# Create IP ipset if not exists
if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
    ipset create "$IPSET_NAME" hash:ip
fi

# Create network ipset if not exists
if ! ipset list "$NETSET_NAME" >/dev/null 2>&1; then
    ipset create "$NETSET_NAME" hash:net
fi

# Init sync files
if [ ! -f "$LAST_SYNC_IP_FILE" ]; then
    echo 0 > "$LAST_SYNC_IP_FILE"
fi

if [ ! -f "$LAST_SYNC_NET_FILE" ]; then
    echo 0 > "$LAST_SYNC_NET_FILE"
fi

LAST_SYNC_IP=$(cat "$LAST_SYNC_IP_FILE")
LAST_SYNC_NET=$(cat "$LAST_SYNC_NET_FILE")

# Fetch IP changes
IP_RESPONSE=$(curl -s --fail --max-time 10 \
    -H "Authorization: Bearer $TOKEN" \
    "$API_URL/changes?since=$LAST_SYNC_IP")

# Fetch network changes
NET_RESPONSE=$(curl -s --fail --max-time 10 \
    -H "Authorization: Bearer $TOKEN" \
    "$API_URL/changesnets?since=$LAST_SYNC_NET")

# Validate JSON
echo "$IP_RESPONSE" | jq empty
echo "$NET_RESPONSE" | jq empty

NEW_LAST_SYNC_IP="$LAST_SYNC_IP"
NEW_LAST_SYNC_NET="$LAST_SYNC_NET"

# Sync IPs
while read -r ENTRY; do

    ADDRESS=$(jq -r '.address' <<< "$ENTRY")
    DELETED=$(jq -r '.deleted' <<< "$ENTRY")
    UPDATED_AT=$(jq -r '.updated_at' <<< "$ENTRY")

    if [ "$DELETED" = "true" ]; then
        ipset del "$IPSET_NAME" "$ADDRESS" 2>/dev/null || true
        logger -t blocklist-sync "UNBAN IP $ADDRESS"
    else
        ipset add "$IPSET_NAME" "$ADDRESS" -exist
        logger -t blocklist-sync "BAN IP $ADDRESS"
    fi

    if [ "$UPDATED_AT" -gt "$NEW_LAST_SYNC_IP" ]; then
        NEW_LAST_SYNC_IP="$UPDATED_AT"
    fi

done < <(echo "$IP_RESPONSE" | jq -c '.[]')

# Sync networks
while read -r ENTRY; do

    NETWORK=$(jq -r '.network' <<< "$ENTRY")
    DELETED=$(jq -r '.deleted' <<< "$ENTRY")
    UPDATED_AT=$(jq -r '.updated_at' <<< "$ENTRY")

    if [ "$DELETED" = "true" ]; then
        ipset del "$NETSET_NAME" "$NETWORK" 2>/dev/null || true
        logger -t blocklist-sync "UNBAN NET $NETWORK"
    else
        ipset add "$NETSET_NAME" "$NETWORK" -exist
        logger -t blocklist-sync "BAN NET $NETWORK"
    fi

    if [ "$UPDATED_AT" -gt "$NEW_LAST_SYNC_NET" ]; then
        NEW_LAST_SYNC_NET="$UPDATED_AT"
    fi

done < <(echo "$NET_RESPONSE" | jq -c '.[]')

echo "$NEW_LAST_SYNC_IP" > "$LAST_SYNC_IP_FILE"
echo "$NEW_LAST_SYNC_NET" > "$LAST_SYNC_NET_FILE"
