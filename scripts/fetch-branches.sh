#!/bin/sh
#
# Copyright 2021, Proofcraft Pty Ltd
#
# SPDX-License-Identifier: BSD-2-Clause

# Fetches any PR branches and extra simultaneous PRs if available.
# Skips branch fetching if explicit input manifest XML is present.
# Always print repo summary. Needs a repo checkout.

set -e

# Ensure we are in the repo root before calling repo-util
REPO_ROOT="${REPO_ROOT:-/github/workspace}"
if [ ! -d "${REPO_ROOT}/.repo/manifests" ]; then
    if [ -d /workspace/.repo/manifests ]; then
        REPO_ROOT=/workspace
    elif [ -d /github/workspace/.repo/manifests ]; then
        REPO_ROOT=/github/workspace
    else
        echo "Error: repo root with .repo/manifests not found" >&2
        exit 1
    fi
fi

cd "${REPO_ROOT}"

if [ -z "${INPUT_XML}" ]
then
  cd "$(repo-util path "${GITHUB_REPOSITORY}")"
  fetch-branch.sh
  cd - >/dev/null

  if [ "${GITHUB_EVENT_NAME}" = "pull_request_target" ] ||
     [ "${GITHUB_EVENT_NAME}" = "pull_request" ]
  then
    export INPUT_EXTRA_REFS="$(get-prs)"
    fetch-extra-refs.sh
  fi
fi

repo-util hashes
