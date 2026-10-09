#!/bin/sh
#
# Copyright 2021, Proofcraft Pty Ltd
#
# SPDX-License-Identifier: BSD-2-Clause

# Fetches any PR branches and extra simultaneous PRs if available.
# Skips branch fetching if explicit input manifest XML is present.
# Always print repo summary. Needs a repo checkout.

set -e

if [ -z "${INPUT_XML}" ]
then
  # Only attempt branch fetch if we can reliably locate the repo root and project
  REPO_ROOT="${REPO_ROOT:-/github/workspace}"
  
  # Verify repo root exists with .repo/manifests
  if [ ! -d "${REPO_ROOT}/.repo/manifests" ]; then
    echo "Warning: repo root with .repo/manifests not found; skipping branch fetch" >&2
  else
    (
      cd "${REPO_ROOT}"
      
      # Safely get project directory; skip if it fails
      REPO_PROJECT_DIR=$(repo-util path "${GITHUB_REPOSITORY}" 2>/dev/null) || {
        echo "Warning: repo-util failed to resolve project path; skipping branch fetch" >&2
        exit 0
      }
      
      if [ -z "${REPO_PROJECT_DIR}" ] || [ ! -d "${REPO_PROJECT_DIR}" ]; then
        echo "Warning: project directory not found; skipping branch fetch" >&2
        exit 0
      fi
      
      export REPO_PROJECT_DIR
      fetch-branch.sh || {
        echo "Warning: branch fetch failed; continuing with sync state" >&2
        exit 0
      }
      
      if [ "${GITHUB_EVENT_NAME}" = "pull_request_target" ] ||
         [ "${GITHUB_EVENT_NAME}" = "pull_request" ]
      then
        export INPUT_EXTRA_REFS="$(get-prs 2>/dev/null || true)"
        fetch-extra-refs.sh || true
      fi
    ) || true
  fi
fi

repo-util hashes
