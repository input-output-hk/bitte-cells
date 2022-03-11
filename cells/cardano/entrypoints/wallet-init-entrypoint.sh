echo "Sleeping a small amount of time to ensure this poststart task does not fail the deployment"
echo "https://github.com/hashicorp/nomad/issues/10058"
sleep 15

[ -z "${WALLET_SRV_URL:-}" ] && echo "WALLET_SRV_URL env var must be set -- aborting" && exit 1
[ -z "${CARDANO_WALLET_ID:-}" ] && echo "CARDANO_WALLET_ID env var must be set -- aborting" && exit 1
[ -z "${CARDANO_WALLET_INIT_DATA:-}" ] && echo "CARDANO_WALLET_INIT_DATA env var must be set -- aborting" && exit 1
[ -z "${CARDANO_WALLET_INIT_NAME:-}" ] && echo "CARDANO_WALLET_INIT_NAME env var must be set -- aborting" && exit 1
[ -z "${CARDANO_WALLET_INIT_PASS:-}" ] && echo "CARDANO_WALLET_INIT_PASS env var must be set -- aborting" && exit 1

# TODO: Fail after a certain period of time if the API server is unavailable
until curl -f "${WALLET_SRV_URL}/v2/network/information"; do
  echo "Waiting 10 seconds for cardano-wallet API server to become available..."
  sleep 10
done
echo
echo "Checking for walletId $CARDANO_WALLET_ID..."
if curl -f "${WALLET_SRV_URL}/v2/wallets/$CARDANO_WALLET_ID"; then
  echo
  echo "Found walletId $CARDANO_WALLET_ID..."
  echo "Cardano wallet initialization completed."
  sleep 10
  exit 0
else
  echo
  echo "WalletId $CARDANO_WALLET_ID not found..."
  echo "Initializing cardano wallet $CARDANO_WALLET_ID."

  # Required as regular wallet create since the extended public key wallet creation option creates the wallet as read-only
  MNEMONICS="$(sed -r -s 's/([[:alpha:]]+)/"\1"/g' <<<"$CARDANO_WALLET_INIT_DATA")"
  PAYLOAD="{\"name\":\"${CARDANO_WALLET_INIT_NAME}\",\"mnemonic_sentence\":${MNEMONICS},\"passphrase\":\"${CARDANO_WALLET_INIT_PASS}\"}"
  LOG_PAYLOAD="{\"name\":\"${CARDANO_WALLET_INIT_NAME}\",\"mnemonic_sentence\":${MNEMONICS}//+([[:alpha:]])/*****},\"passphrase\":\"*****\"}"
  CREATE_CMD=(
    curl -f -XPOST "${WALLET_SRV_URL}/v2/wallets"
    -H 'Content-Type: application/json'
    -d "$PAYLOAD"
  )
  LOG_CREATE_CMD=(
    curl -f -XPOST "${WALLET_SRV_URL}/v2/wallets"
    -H 'Content-Type: application/json'
    -d "$LOG_PAYLOAD"
  )
  echo "${LOG_CREATE_CMD[@]}"
  if "${CREATE_CMD[@]}"; then
    echo
    echo "Initializated cardano wallet $CARDANO_WALLET_ID."
    sleep 10
    exit 0
  else
    echo
    echo "Failed to initialize cardano wallet $CARDANO_WALLET_ID."
    sleep 10
    exit 1
  fi
fi
