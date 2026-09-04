#!/usr/bin/env bash
# Synthetic flaky skill (EPIC-012 / REQ-EXEC-004, T-04 fixture).
# Fails on its FIRST invocation, passes on every later one. State lives in
# the caller-supplied file so each test gets an independent flake sequence:
#   flaky-skill.sh <state-file>

state="${1:?usage: flaky-skill.sh <state-file>}"
if [ -f "$state" ]; then
    exit 0
fi
touch "$state"
exit 1
