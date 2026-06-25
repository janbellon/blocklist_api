#!/bin/bash

ENV_FILE="secrets.env"

ADMIN_TOKEN=$(openssl rand -hex 32)
READONLY_TOKEN=$(openssl rand -hex 32)

cat > "$ENV_FILE" <<EOF
ADMIN_TOKEN=${ADMIN_TOKEN}
READONLY_TOKEN=${READONLY_TOKEN}
EOF

chmod 600 "$ENV_FILE"

cat $ENV_FILE
