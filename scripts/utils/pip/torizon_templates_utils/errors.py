"""Error utilities and exit codes used by Torizon templates."""

import sys
from enum import Enum
from dataclasses import dataclass

from .colors import Color, cprint


@dataclass  # pylint: disable=too-few-public-methods
class ErrorStruct:
    """Holds an error code and message."""

    code: int
    message: str


class Error(Enum):
    """Error codes and messages."""

    ENOCONF = ErrorStruct(1, "Not configured")
    EINVAL = ErrorStruct(22, "Invalid argument")
    ENOPKG = ErrorStruct(65, "Package not installed")
    EUSER = ErrorStruct(69, "User fault")
    EABORT = ErrorStruct(170, "Abort")
    ETASKEXEC = ErrorStruct(310, "Task execution error")
    ENOFOUND = ErrorStruct(404, "Not found")
    EFAIL = ErrorStruct(500, "Failed")
    EUNKNOWN = ErrorStruct(666, "Unknown error")
    ETOMCRUISE = ErrorStruct(999, "Impossible condition")


def error_out(msg: str, error: Error) -> None:
    """Print an error message and exit the program with the error code."""
    cprint(f"\n{msg}", color=Color.RED)
    cprint(f"Error cause: {error.value.message}\n", color=Color.RED)
    sys.exit(error.value.code)


def last_return_code() -> int:
    """Get the last return code from xonsh if present; otherwise 0."""
    try:
        # type: ignore[name-defined] – __xonsh__ exists only inside xonsh
        return __xonsh__.last.returncode  # noqa: F821
    except NameError:
        return 0

