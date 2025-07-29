"""Helpers to read CLI args or interactively prompt the user."""

import sys
from typing import Optional, Any

from .errors import Error, error_out


def _to_bool(val: str) -> bool:
    return val.strip().lower() in {"1", "true", "yes", "y", "on"}


def get_arg(
    index: int,
    prompt: str,
    default: Optional[str] = None,
    default_type: type = str,
    iterative: bool = False,
) -> Any:
    """
    Return argv[index] if present; otherwise use `default` or prompt if `iterative=True`.
    Coerces to bool when default_type is bool.
    """
    # From CLI
    if len(sys.argv) > index:
        val = sys.argv[index]
        return _to_bool(val) if default_type is bool else val

    # Use default when provided and not prompting
    if default is not None and not iterative:
        return _to_bool(str(default)) if default_type is bool else default

    # Prompt if allowed
    if iterative:
        _input = input(prompt)
        if _input == "":
            error_out("Error: Argument cannot be empty", Error.EUSER)
        return _to_bool(_input) if default_type is bool else _input

    # Otherwise it's an error
    error_out(f"Error: Argument for prompt [{prompt}] not provided", Error.EUSER)
    return None  # unreachable, keeps pylint satisfied

