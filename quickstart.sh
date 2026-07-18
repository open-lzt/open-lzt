#!/usr/bin/env bash
# One-shot bootstrap: `bash quickstart.sh` brings the entire open-lzt stand up from a fresh clone.
# Populates the project submodules, then runs the full installer (Docker infra + all services).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

c_cyan=$'\033[1;36m'; c_reset=$'\033[0m'
printf '\n%s== open-lzt quickstart ==%s\n' "$c_cyan" "$c_reset"

if [[ -f .gitmodules ]]; then
  printf '%s-> fetching project submodules%s\n' "$c_cyan" "$c_reset"
  git submodule update --init --recursive
fi

exec bash install.sh "$@"
