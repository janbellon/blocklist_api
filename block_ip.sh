#!/bin/bash

set -euo pipefail

# Vérification des variables d'environnement
: "${API_URL:?API_URL is not set}"
: "${TOKEN:?TOKEN is not set}"

if [ $# -ne 2 ]; then
    echo "Usage: $0 <ban|unban> <ip_address>"
    exit 1
fi

ACTION="$1"
IP="$2"

case "$ACTION" in
    ban)
        ENDPOINT="/banip"
        ;;
    unban)
        ENDPOINT="/unbanip"
        ;;
    *)
        echo "Invalid action: use 'ban' or 'unban'"
        exit 1
        ;;
esac

# Appel API
RESPONSE=$(curl -s -X POST "$API_URL$ENDPOINT" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"address\":\"$IP\",\"reason\":\"manual\"}")

echo "$RESPONSE"
