#!/usr/bin/env bash
# Seeds the workspace with the bench fixture as a wf/ branch: plan committed first, code on top.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -R "$here/fixture/." .
git init -q -b main
git -c user.name=eval -c user.email=eval@example.com commit -q --allow-empty -m "init"
git checkout -q -b wf/bench
git add .phased
git -c user.name=eval -c user.email=eval@example.com commit -q -m "wf: plan bench"
git add -A
git -c user.name=eval -c user.email=eval@example.com commit -q -m "chore: textutils baseline"
