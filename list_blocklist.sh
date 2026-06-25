#!/bin/bash

set -euo pipefail

: "${API_URL:?API_URL is not set}"
: "${TOKEN:?TOKEN is not set}"

RESPONSE=$(curl -s "$API_URL/list" \
    -H "Authorization: Bearer $TOKEN")

echo "$RESPONSE" | jq -r '
    .[] |
    "\(.address) | v\(.version) | \(.reason) | \(.timestamp)"
'
