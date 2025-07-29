#!/usr/bin/env bash
set -euo pipefail

# Lint Python with pylint (score printed)
pylint $(git ls-files 'scripts/**/*.py')

# Lint Xonsh separately (no effect on pylint score).
# If you already have scripts/lint-xonsh.xsh, call it; otherwise do a very light check.
if command -v xonsh >/dev/null 2>&1; then
  echo "— Linting Xonsh (syntax parse) —"
  # try-parse each .xsh with xonsh; prints failures but doesn't impact pylint score
  while IFS= read -r f; do
    printf '%s\n' "Checking $f"
    xonsh -c "exec(open('$f').read())" >/dev/null 2>&1 || echo "Syntax issue in $f"
  done < <(git ls-files 'scripts/**/*.xsh')
else
  echo "xonsh not installed; skipping .xsh check"
fi
