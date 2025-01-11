
import sys
from typing import TypeVar, Type
from torizon_templates_utils.errors import Error, Error_Out

T = TypeVar('T')

def get_arg_not_empty(index: int) -> str:
    """
    Get an argument from the command line.
    If the argument is an empty string, an error is raised.
    """
    _arg = sys.argv[index]

    if _arg == "":
        Error_Out(
            "Error: Argument cannot be empty",
            Error.EUSER
        )

    return _arg


def get_optional_arg(index: int, default: T) -> T | bool | str:
    """
    Get an optional argument from the command line.
    If the argument is not provided, the default value is returned.
    """
    if len(sys.argv) > index:
        # sys.argv return string
        # we need to return T
        # FIXME: this only convert string to bool for now
        if type(default) is bool:
            if sys.argv[index] == "True" or sys.argv[index] == "true" or sys.argv[index] == "1":
                return True
            else:
                return False

        return sys.argv[index]

    return default


def get_arg_iterative(
        index: int, prompt: str, default_type: Type, default: T | None = None, iterative: bool = False
    ) -> T | None | bool | str:
    """
    Get an argument from the command line.
    If the argument is not provided, an error is raised.
    """
    if len(sys.argv) > index:
        if default_type is bool:
            if sys.argv[index] == "True":
                return True
            else:
                return False

        return sys.argv[index]
    elif default != None:
        return default
    elif iterative:
        _input = input(prompt)
        if _input == "":
            Error_Out(
                "Error: Argument cannot be empty",
                Error.EUSER
            )
        else:
            if default_type is bool:
                if _input == "True":
                    return True
                else:
                    return False

            return _input

    else:
        Error_Out(
            f"Error: Argument for prompt [{prompt}] not provided",
            Error.EUSER
        )

    return default
