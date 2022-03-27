#!/bin/bash

[ -z "${WALLET_SRV_FQDN:-}" ] && echo "WALLET_SRV_FQDN env var must be set -- aborting" && exit 1
[ -z "${CARDANO_WALLET_ID:-}" ] && echo "CARDANO_WALLET_ID env var must be set -- aborting" && exit 1

mapfile -t wallet_urls <<<"$(srvaddr "${WALLET_SRV_FQDN}")"

STATUS="$(curl -sf "${wallet_urls[0]}/v2/wallets/$CARDANO_WALLET_ID" || :)"
jq <<<"$STATUS" || :
jq -e '.state.status == "ready"' <<<"$STATUS" || exit 1
