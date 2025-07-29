#!/usr/bin/env xonsh
# -*- coding: utf-8 -*-
# pylint: disable=invalid-name
"""
Lightweight Xonsh linter: checks syntax using xonsh's compiler and a few styles.
Usage:
  xonsh scripts/lint-xonsh.xsh              # lint all tracked .xsh under scripts/
  xonsh scripts/lint-xonsh.xsh **/*.xsh     # or pass your own globs
"""

import sys
import pathlib
from xonsh.execer import Execer


def check_file(path):
    """Compile a file with Xonsh to validate syntax and run simple style checks.

    Returns:
        list[tuple[str, str]]: list of (KIND, MESSAGE) problem tuples.
    """
    txt = path.read_text(encoding="utf-8", errors="replace")
    problems = []

    # Syntax check (compile only, no execution)
    ex = Execer()
    try:
        ex.compile(txt, filename=str(path))
    except Exception as e:  # pylint: disable=broad-exception-caught
        problems.append(("SYNTAX", str(e).strip()))

    # Simple style checks
    if not txt.endswith("\n"):
        problems.append(("STYLE", "missing-final-newline"))
    if "\r\n" in txt:
        problems.append(("STYLE", "CRLF line endings"))
    if txt.rstrip() != txt:
        problems.append(("STYLE", "trailing whitespace"))

    return problems


globs = sys.argv[1:] or ["scripts/**/*.xsh"]
paths = []
for g in globs:
    paths.extend(pathlib.Path().glob(g))

EXIT_ERRORS = 0
for p in sorted(set(paths)):
    if not p.is_file():
        continue
    probs = check_file(p)
    if probs:
        for kind, msg in probs:
            print(f"[{kind}] {p}: {msg}")
        if any(k == "SYNTAX" for k, _ in probs):
            EXIT_ERRORS += 1
    else:
        print(f"[OK] {p}")

sys.exit(1 if EXIT_ERRORS else 0)

