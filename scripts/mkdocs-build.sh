#!/bin/sh
# SPDX-License-Identifier: MIT
# Build the site into ./site with pinned, hash-checked dependencies. Used locally (via Docker) and in CI.
#   sh scripts/mkdocs-build.sh            run inside a Docker container (pinned image digest)
#   sh scripts/mkdocs-build.sh --inner    run directly (CI, python 3.12 present); installs into ./.venv
set -eu
cd "$(dirname "$0")/.."
# renovate: datasource=docker depName=python
IMAGE=python:3.12-slim@sha256:5e2bdb1b0d542d5039cffb8181c65930093949194a65c365dfb1b0fe13a4fa5b
if [ "${1:-}" = "--inner" ]; then
    python3 -m venv .venv
    .venv/bin/pip install --quiet --require-hashes --no-deps -r requirements.txt
    rm -rf site
    .venv/bin/mkdocs build --strict
    exit 0
fi
docker run --rm -v "$PWD":/w -w /w -e HOME=/tmp -u "$(id -u):$(id -g)" "$IMAGE" sh scripts/mkdocs-build.sh --inner
