#!/bin/sh
#
# Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
#
# SPDX-License-Identifier: BSD-2-Clause

# Fetches the branch in ${GITHUB_REF} into a repo manifest checkout.
# Does nothing if INPUT_XML is set, because that means we have already done this.

set -e

if [ -z "${INPUT_XML}" ]
then
  REPO_PATH="github.com/${GITHUB_REPOSITORY}.git"

  if [ -n "${INPUT_TOKEN}" ]
  then
    URL="https://${INPUT_TOKEN}@${REPO_PATH}"
    REPO_PATH="token@${REPO_PATH}"
  else
    URL="https://${REPO_PATH}"
  fi

  if [ -n "${INPUT_SHA}" ]
  then
    REF=${INPUT_SHA}
    FETCH=${REF}
  elif [ -n "${GITHUB_SHA}" ]
  then
    REF=${GITHUB_SHA}
    FETCH=${REF}
  else
    REF=${GITHUB_REF}
    FETCH=${REF}:${REF}
  fi

  # Use REPO_PROJECT_DIR if set and is a directory, otherwise skip
  REPO_DIR="${REPO_PROJECT_DIR:-.}"
  if [ ! -d "${REPO_DIR}" ]; then
    echo "Warning: REPO_PROJECT_DIR invalid or not set; skipping branch fetch" >&2
    exit 0
  fi

  echo "Fetching ${REF} from ${REPO_PATH}"
  git -C "${REPO_DIR}" fetch -q --depth 1 "${URL}" "${FETCH}" || {
    echo "Warning: git fetch failed; skipping checkout" >&2
    exit 0
  }
  git -C "${REPO_DIR}" checkout -q "${REF}" || {
    echo "Warning: git checkout failed; continuing with current state" >&2
    exit 0
  }
  if [ -n "${BRANCH_NAME}" ]
  then
    git -C "${REPO_DIR}" checkout -b "${BRANCH_NAME}" || true
  fi
fi
