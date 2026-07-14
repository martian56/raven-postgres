#!/usr/bin/env sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo"

cleanup() {
    if [ "${KEEP_POSTGRES:-0}" != "1" ]; then
        docker compose down --volumes
    fi
}
trap cleanup EXIT INT TERM

docker compose up -d --wait
export RAVEN_POSTGRES_E2E=1
export RAVEN_POSTGRES_HOST=${RAVEN_POSTGRES_HOST:-127.0.0.1}
export RAVEN_POSTGRES_PORT=${RAVEN_POSTGRES_PORT:-55432}
export RAVEN_POSTGRES_USER=${RAVEN_POSTGRES_USER:-raven}
export RAVEN_POSTGRES_PASSWORD=${RAVEN_POSTGRES_PASSWORD:-ravenpw}
export RAVEN_POSTGRES_DATABASE=${RAVEN_POSTGRES_DATABASE:-ravendb}
${RVPM:-rvpm} test
