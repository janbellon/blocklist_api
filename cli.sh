#!/bin/bash

set -euo pipefail

: "${API_URL:?API_URL is not set}"
: "${TOKEN:?TOKEN is not set}"

ACTION="${1:-}"

usage() {
    echo "Usage:"
    echo "  $0 ban <ip>"
    echo "  $0 unban <ip>"
    echo "  $0 bannet <network>"
    echo "  $0 unbannet <network>"
    echo "  $0 list"
    echo "  $0 listnets"
    exit 1
}

[ -n "$ACTION" ] || usage

case "$ACTION" in

    ban|unban)

        [ $# -eq 2 ] || usage

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

        curl -s -X POST "$API_URL$ENDPOINT" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"address\":\"$IP\",\"reason\":\"manual\"}"

        echo
        ;;

    bannet|unbannet)

        [ $# -eq 2 ] || usage

        NETWORK="$2"

        if ! python3 -c "import ipaddress; ipaddress.ip_network('$NETWORK', strict=True)" 2>/dev/null; then
            echo "Invalid network"
            exit 1
        fi

        if [ "$ACTION" = "bannet" ]; then
            ENDPOINT="/bannet"
        else
            ENDPOINT="/unbannet"
        fi

        curl -s -X POST "$API_URL$ENDPOINT" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"network\":\"$NETWORK\",\"reason\":\"manual\"}"

        echo
        ;;

    list)

        [ $# -eq 1 ] || usage

        curl -s "$API_URL/list" \
            -H "Authorization: Bearer $TOKEN" |
        jq -r '.[] | "\(.address) | IPv\(.version) | \(.reason) | \(.timestamp)"'
        ;;

    listnets)

        [ $# -eq 1 ] || usage

        curl -s "$API_URL/listnets" \
            -H "Authorization: Bearer $TOKEN" |
        jq -r '.[] | "\(.network) | IPv\(.version) | \(.reason) | \(.timestamp)"'
        ;;

    *)

        usage
        ;;

esac
