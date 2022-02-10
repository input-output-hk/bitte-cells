#!/bin/bash

[ -z "''${CARDANO_WALLET_ID:-}" ] && echo "CARDANO_WALLET_ID env var must be set -- aborting" && exit 1
[ -z "''${CARDANO_WALLET_NODE_URL:-}" ] && echo "CARDANO_WALLET_NODE_URL env var must be set -- aborting" && exit 1

STATUS="$(curl -sf "$CARDANO_WALLET_NODE_URL/v2/wallets/$CARDANO_WALLET_ID" || :)"
jq <<< "$STATUS" || :
jq -e '.state.status == "ready"' <<< "$STATUS" || exit 1

