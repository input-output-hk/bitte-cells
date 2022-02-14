#!/bin/bash

[ -z "${CARDANO_WALLET_ID:-}" ] && echo "CARDANO_WALLET_ID env var must be set -- aborting" && exit 1

STATUS="$(curl -sf "http://localhost:8090/v2/wallets/$CARDANO_WALLET_ID" || :)"
jq <<<"$STATUS" || :
jq -e '.state.status == "ready"' <<<"$STATUS" || exit 1
