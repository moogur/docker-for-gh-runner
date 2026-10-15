#!/usr/bin/env bash

# Регистрирует runner при первом запуске и запускает его.
# Регистрация (файлы config.sh) живёт в volume state/, а не в /home/runner целиком:
# иначе после обновления образа в volume остался бы старый runner.
set -euo pipefail

state=/home/runner/state
files=(.runner .credentials .credentials_rsaparams)

if [[ -f "$state/.runner" ]]; then
  cp "${files[@]/#/$state/}" .
else
  if [[ -z "${RUNNER_TOKEN:-}" ]]; then
    echo "Runner is not registered: set RUNNER_TOKEN for the first start"
    exit 1
  fi
  ./config.sh --unattended --replace \
    --url "$RUNNER_URL" \
    --token "$RUNNER_TOKEN" \
    --name "${RUNNER_NAME:-$(hostname)}"
  cp "${files[@]}" "$state/"
fi

exec ./run.sh
