#!/bin/bash

STATUS="$(curl -sf "http://localhost:8090/v2/network/information" || :)"
jq <<<"$STATUS" || :
jq -e '.sync_progress.status == "ready"' <<<"$STATUS" || exit 1
