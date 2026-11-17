# Source this from the poc/ directory:  cd ~/workspace/webpact-testing/poc && source ./lib.sh
# Needs PACT_BROKER_USERNAME and PACT_BROKER_PASSWORD in the environment. Holds no secrets itself.

B="${PACT_BROKER_BASE_URL:-https://pact-broker.prod.getflex.org}"
AUTH="${PACT_BROKER_USERNAME:?set PACT_BROKER_USERNAME}:${PACT_BROKER_PASSWORD:?set PACT_BROKER_PASSWORD}"
REPO="ruicongy/webpact-testing"
CONSUMER="webpact-consumer"
PROVIDER="webpact-testing"

# One stable webhook UUID, remembered in ./.webhook-uuid so a new terminal reuses it (updates, not duplicates).
if [ -z "${WEBHOOK_UUID:-}" ]; then
  if [ -f ./.webhook-uuid ]; then
    WEBHOOK_UUID="$(cat ./.webhook-uuid)"
  else
    WEBHOOK_UUID="$(uuidgen | tr 'A-Z' 'a-z')"
    echo "$WEBHOOK_UUID" > ./.webhook-uuid
  fi
fi
export WEBHOOK_UUID

# put_webhook <true|false> <github token>: create or update the webhook. The token only travels through a pipe.
put_webhook() {
  jq -n --arg token "$2" --argjson enabled "$1" --arg repo "$REPO" \
        --arg consumer "$CONSUMER" --arg provider "$PROVIDER" --slurpfile body ./webhook-body.json '{
    description: "POC: webpact-consumer to webpact-testing, dispatching to a personal repo",
    enabled: $enabled,
    consumer: {name: $consumer},
    provider: {name: $provider},
    events: [{name: "contract_requiring_verification_published"}],
    request: {
      method: "POST",
      url: ("https://api.github.com/repos/" + $repo + "/dispatches"),
      headers: {"Content-Type": "application/json", "Accept": "application/vnd.github+json",
                "Authorization": ("Bearer " + $token)},
      body: $body[0] } }' |
  curl -s -w "\nHTTP %{http_code}\n" -X PUT -u "$AUTH" -H 'Content-Type: application/json' \
       -d @- "$B/webhooks/$WEBHOOK_UUID" | tail -2
}

# publish_pact <file> <consumer version>
publish_pact() {
  curl -s -o /dev/null -w "publish $2: HTTP %{http_code}\n" -X PUT -u "$AUTH" -H 'Content-Type: application/json' \
       -d @"$1" "$B/pacts/provider/$PROVIDER/consumer/$CONSUMER/version/$2"
}

echo "broker=$B  webhook uuid=$WEBHOOK_UUID  repo=$REPO"
