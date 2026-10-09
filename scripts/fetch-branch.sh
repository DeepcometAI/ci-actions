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

  # Assumes a repo manifest checkout, and current working dir in the repo
  # to fetch the branch for.

  REPO_PATH="github.com/${GITHUB_REPOSITORY}.git"

  if [ -n "${INPUT_TOKEN}" ]
  then
    URL="https://${INPUT_TOKEN}@${REPO_PATH}"
    REPO_PATH="token@${REPO_PATH}"
  else
    URL="https://${REPO_PATH}"
  fi

  # if an explicit SHA is set as INPUT (e.g. for pull request target), prefer that
  if [ -n "${INPUT_SHA}" ]
  then
    REF=${INPUT_SHA}
    FETCH=${REF}
  # if GITHUB_SHA is available, prefer that over REF, because the branch GITHUB_REF
  # refers to may have been pushed to again to since we have been invoked.
  elif [ -n "${GITHUB_SHA}" ]
  then
    REF=${GITHUB_SHA}
    FETCH=${REF}
  # if nothing better is available, use GITHUB_REF
  else
    REF=${GITHUB_REF}
    FETCH=${REF}:${REF}
  fi

  # Get the actual git directory path from repo tool
  REPO_DIR=$(repo forall -c pwd | head -n 1)
  
  echo "Fetching ${REF} from ${REPO_PATH}"
  
  # Use git -C to run git commands in the repo directory
  git -C "${REPO_DIR}" fetch -q --depth 1 ${URL} ${FETCH}
  git -C "${REPO_DIR}" checkout -q ${REF}
  if [ -n "${BRANCH_NAME}" ]
  then
    git -C "${REPO_DIR}" checkout -b "${BRANCH_NAME}"
  fi
fi
