#!/usr/bin/env python3
#
# Copyright 2021, Proofcraft Pty Ltd
#
# SPDX-License-Identifier: BSD-2-Clause

"""
Utilities for `repo`.

Prints path for GITHUB_REPOSITORY and shows hashes for all manifest repos +
manifest itself.

Uses git and repo as shell processes. Hopefully a more stable interface
than trying to mess with repo python library directly.

Repo URLs are treated as case insensitive to line up with GitHub and Bitbucket
behaviour. This means, keys in the `projects` dict are lower-case, but we keep
the spelling for the name as value to reflect what is in the manifest.
"""

import subprocess
import sys
import os

usage = "repo-util [path <path> | hashes]"


def removesuffix(string: str, suffix: str) -> str:
    """Like .removesuffix in python 3.9"""
    if string.endswith(suffix):
        return string[0:-len(suffix)]
    else:
        return string


def removeprefix(string: str, prefix: str) -> str:
    """Like .removeprefix in python 3.9"""
    if string.startswith(prefix):
        return string[len(prefix):]
    else:
        return string


def add_manifest(projects: dict):
    """Add the manifest repo itself as a project to the projects dict."""
    repo_root = os.environ.get("REPO_ROOT", ".")
    manifest_path = os.path.join(repo_root, ".repo", "manifests")
    try:
        git_cmd = ["git", "-C", manifest_path, "config", "--get", "remote.origin.url"]
        url = subprocess.check_output(git_cmd, text=True).rstrip()
        repo = removesuffix(url.split('/')[-1], '.git')
        projects[repo.lower()] = (manifest_path, repo)
    except Exception:
        # Log warning but continue; repo may not be fully initialized yet
        print('Warning: could not get manifest repo info', file=sys.stderr)

def get_projects() -> dict:
    """Create dict from repo manifest; maps repo name to path."""
    project_dict = {}
    add_manifest(project_dict)
    try:
        projects = subprocess.check_output(['repo', 'list'], text=True)
        for line in projects.splitlines():
            path, repo = line.split(':')
            repo = removesuffix(repo.strip(), '.git')
            # lower-case name as key to remain case insensitive; store manifest name as value
            project_dict[repo.lower()] = (path.strip(), repo)
    except:
        print("Failed to get project list from `repo`")
        project_dict = {}

    return project_dict


def get_hash(path: str) -> str:
    """Get git HEAD hash of repo at path."""
    try:
        return subprocess.check_output(['git', '-C', path, 'rev-parse', 'HEAD'], text=True).rstrip()
    except:
        print('Error getting hash', file=sys.stderr)
        return ""


# give full line a decent chance to fit into 100 chars
title_len = 46


def get_title(path: str, hash: str) -> str:
    """Return commit title line for hash."""
    try:
        title = subprocess.check_output(['git', '-C', path, 'log', '--format=%s',
                                         '-n', '1', hash], text=True).rstrip()
        if len(title) > title_len:
            title = title[0:title_len-2]+".."
        return title
    except:
        print('Error getting title', file=sys.stderr)
        return ""


def get_name(path: str, hash: str):
    """Get a symbolic name (if available) of hash in repo at path.
    Return empty string if no such name."""
    try:
        git_cmd = f"git -C {path} name-rev --name-only --no-undefined".split(' ')
        # exclude ref names that don't give much info:
        cmd = git_cmd + ["--exclude", "m/*",      # put in by repo, seems to be always "master"
                         "--exclude", "default",  # manifest is always on "default"
                         hash]
        name = subprocess.check_output(cmd, text=True, stderr=subprocess.PIPE).rstrip()
        return f"({removeprefix(name,'remotes/')})"
    except:
        return ""


def show_project_hashes(projects: dict):
    """Print all project repos with hash and symbolic (branch/tag) names."""
    print('Manifest summary:')
    print('-----------------')
    indent = max([len(repo) for repo in projects])+2 if len(projects) > 0 else 0
    for (path, repo) in projects.values():
        hash = get_hash(path)[0:8]
        print((repo+": ").rjust(indent) +
              hash + " " +
              get_title(path, hash).ljust(title_len+1) +
              get_name(path, hash))


def show_all_hashes():
    """Print repos, hashes and symbolic (branch/tag) names of current repo manifest."""
    show_project_hashes(get_projects())


# Map renamed-fork repo names (as they appear in GITHUB_REPOSITORY) to the
# project name the upstream seL4 manifests actually use. Add an entry here
# any time a fork's GitHub repo name no longer matches its manifest project
# name (e.g. our kernel fork is "perception", but every seL4 manifest still
# calls the kernel project "seL4").
ALIASES = {
    'perception': 'sel4',
}


def path_of(gh_repo: str, projects: dict) -> str:
    """Get the path of a given repo in projects dict.
    Accepts GITHUB_REPOSITORY-style references like seL4/seL4 (for repo "seL4")"""
    repo = gh_repo.split('/')[-1]
    # remove optional -priv suffix for private forks
    repo = removesuffix(repo.lower(), '-priv')
    repo = ALIASES.get(repo, repo)
    result = projects.get(repo, (None, None))[0]
    return result if result else ""


# main program:
if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(usage)
        sys.exit(1)

    if sys.argv[1] == 'hashes' and len(sys.argv) == 2:
        show_all_hashes()
        sys.exit(0)
    elif sys.argv[1] == 'path' and len(sys.argv) == 3:
        path = path_of(sys.argv[2], get_projects())
        if path:
            print(path)
            sys.exit(0)
        else:
            print('unknown', file=sys.stderr)
            sys.exit(1)
    else:
        print(usage)
        sys.exit(1)
