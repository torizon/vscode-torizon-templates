
import sys
from enum import Enum
from torizon_templates_utils.colors import Color, BgColor, print

class _error_struct:
    code: int
    message: str

    def __init__(self, code: int, message: str):
        self.code = code
        self.message = message

# Standard Unix errors. There may be other standard error codes also:
# https://github.com/kaushalparikh/nuttx/blob/master/include/errno.h
class Error(Enum):
    ENOCONF = _error_struct(
        1, "Not configured"
    )
    EINVAL = _error_struct(
        22, "Invalid argument"
    )
    ENOPKG = _error_struct(
        65, "Package not installed"
    )
    EUSER = _error_struct(
        69, "User fault"
    )
    EABORT = _error_struct(
        170, "Abort"
    )
    ETASKEXEC = _error_struct(
        310, "Task execution error"
    )
    ENOFOUND = _error_struct(
        404, "Not found"
    )
    EFAIL = _error_struct(
        500, "Failed"
    )
    EUNKNOWN = _error_struct(
        666, "Unknown error"
    )
    ETOMCRUISE = _error_struct(
        999, "Impossible condition"
    )


def Error_Out(msg: str, error: Error) -> None:
    print(f"\n{msg}", color=Color.RED)
    print(f"Error cause: {error.value.message}\n", color=Color.RED)
    sys.exit(error.value.code)


def last_return_code() -> int:
    # we are ignoring the type here because this will get the current
    # xonsh shell instance
    return __xonsh__.lastcmd.returncode # type: ignore
