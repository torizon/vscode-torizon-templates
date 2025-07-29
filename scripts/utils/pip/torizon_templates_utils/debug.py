"""Small helpers for optional debugpy integration."""

# pylint: disable=missing-function-docstring, missing-module-docstring

from __future__ import annotations

try:
    import debugpy  # type: ignore[import-untyped]
except ImportError:  # pragma: no cover
    DEBUGPY = None  # type: ignore[assignment]
else:
    DEBUGPY = debugpy  # type: ignore[assignment]

# simple internal state without using `global`
_STATE = {"initialized": False}


def vscode_prepare(port: int = 5679) -> None:
    """Start debugpy server (no-op if already started or not installed)."""
    if _STATE["initialized"] or DEBUGPY is None:
        return

    print("Starting debugpy…")
    DEBUGPY.listen(("0.0.0.0", port))
    print(f"Waiting for VS Code to attach on port {port}…")
    DEBUGPY.wait_for_client()
    print(f"Attached: {DEBUGPY.is_client_connected()}")
    _STATE["initialized"] = True


def debug_breakpoint() -> None:
    """Trigger a breakpoint if debugpy is available."""
    if DEBUGPY is not None:
        DEBUGPY.breakpoint()

