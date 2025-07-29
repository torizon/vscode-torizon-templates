"""Color + colored printing utilities for terminal output."""

import builtins
import enum


class Color(enum.IntEnum):
    """Text colors for terminal output."""

    NONE = 0
    BLACK = 30
    RED = 31
    GREEN = 32
    YELLOW = 33
    BLUE = 34
    MAGENTA = 35
    CYAN = 36
    WHITE = 37


class BgColor(enum.IntEnum):
    """Background colors for terminal output."""

    NONE = 0
    BLACK = 40
    RED = 41
    BRIGTH_RED = 101
    GREEN = 42
    BRIGTH_GREEN = 102
    YELLOW = 43
    BRIGTH_YELLOW = 103
    BLUE = 44
    BRIGTH_BLUE = 104
    MAGENTA = 45
    BRIGTH_MAGENTA = 105
    CYAN = 46
    BRIGTH_CYAN = 106
    WHITE = 47
    BRIGTH_WHITE = 107


def cprint(*args, color: Color = Color.NONE, bg_color: BgColor = BgColor.NONE, **kwargs) -> None:
    """Print like builtins.print, with optional foreground/background colors."""
    # If no colors requested, just delegate
    if color == Color.NONE and bg_color == BgColor.NONE:
        builtins.print(*args, **kwargs)
        return

    start = ""
    if color != Color.NONE and bg_color != BgColor.NONE:
        start = f"\033[{color.value};{bg_color.value}m"
    elif color != Color.NONE:
        start = f"\033[{color.value}m"
    elif bg_color != BgColor.NONE:
        start = f"\033[{bg_color.value}m"

    end = "\033[0m"
    text = " ".join(map(str, args))
    builtins.print(f"{start}{text}{end}", **kwargs)


# Back-compat alias if other code expects this name
printcb = cprint

