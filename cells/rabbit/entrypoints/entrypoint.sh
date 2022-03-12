#! /usr/env bash

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT

# Due to excessive rabbit command or daemon time on startup
# Ref:
#   https://rhye.org/post/erlang-kubernetes-liveness/  (FDs is proportional to startup and CLI times)
#   https://www.rabbitmq.com/production-checklist.html (50k min FDs suggested)
ulimit -n 50000

# Erlang cookie secret must be the same for any rabbit nodes wanting to join the same cluster.
# We cannot create this file by consul templates due to required ownership (nobody) and permission requirement (0600)
# Ref: https://github.com/hashicorp/nomad/issues/5020#issuecomment-8228130620
[ -z "${RABBITMQ_ERLANG_COOKIE:-}" ] && echo "RABBITMQ_ERLANG_COOKIE env var must be set -- aborting" && exit 1
[ -z "${RABBITMQ_ERLANG_COOKIE_PATH:-}" ] && echo "RABBITMQ_ERLANG_COOKIE env var must be set -- aborting" && exit 1

echo "Creating erlang cookie at \"$RABBITMQ_ERLANG_COOKIE_PATH\" and setting permissions"
echo "$RABBITMQ_ERLANG_COOKIE" > "$RABBITMQ_ERLANG_COOKIE_PATH"
chmod 0600 "$RABBITMQ_ERLANG_COOKIE_PATH"

exec rabbitmq-server "$@"
