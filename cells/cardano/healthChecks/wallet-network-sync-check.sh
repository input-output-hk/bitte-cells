#!/bin/bash

[ -z "''${CARDANO_WALLET_NODE_URL:-}" ] && echo "CARDANO_WALLET_NODE_URL env var must be set -- aborting" && exit 1

STATUS="$(curl -sf "$CARDANO_WALLET_NODE_URL/v2/network/information" || :)"
jq <<< "$STATUS" || :
jq -e '.sync_progress.status == "ready"' <<< "$STATUS" || exit 1

