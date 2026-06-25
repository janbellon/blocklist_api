#!/bin/bash

set -euo pipefail

: "${API_URL:?API_URL is not set}"
: "${TOKEN:?TOKEN is not set}"

ACTION="${1:-}"

usage() {
    echo "Usage:"
    echo "  $0 ban <ip>"
    echo "  $0 unban <ip>"
    echo "  $0 list"
    exit 1
}

if [ -z "$ACTION" ]; then
    usage
fi

case "$ACTION" in

    ban|unban)
        if [ $# -ne 2 ]; then
            usage
        fi

        IP="$2"

        if ! python3 -c "import ipaddress; ipaddress.ip_address('$IP')" 2>/dev/null; then
            echo "Invalid IP address"
            exit 1
        fi

        if [ "$ACTION" = "ban" ]; then
            ENDPOINT="/banip"
        else
            ENDPOINT="/unbanip"
        fi

        RESPONSE=$(curl -s -X POST "$API_URL$ENDPOINT" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"address\":\"$IP\",\"reason\":\"manual\"}")

        echo "$RESPONSE"
        ;;

    list)
        if [ $# -ne 1 ]; then
            usage
        fi

        RESPONSE=$(curl -s "$API_URL/list" \
            -H "Authorization: Bearer $TOKEN")

        echo "$RESPONSE" | jq -r '
            .[] | "\(.address) | v\(.version) | \(.reason) | \(.timestamp)"
        '
        ;;

    *)
        usage
        ;;
esac
