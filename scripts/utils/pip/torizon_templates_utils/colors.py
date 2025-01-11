
import builtins
import enum

class Color(enum.IntEnum):
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

# override print to have color and background color
def print(
        *args,
        color: Color = Color.NONE,
        bg_color: BgColor = BgColor.NONE,
        **kwargs
) -> None:
    _color: int = color.value
    _bg_color: int = bg_color.value

    start_escape = ""

    if _color != 0 and _bg_color != 0:
        start_escape += f"\033[{_color};{_bg_color}m"
    elif _color != 0:
        start_escape += f"\033[{_color}m"
    elif _bg_color != 0:
        start_escape += f"\033[{_bg_color}m"

    end_escape = "\033[0m"

    text = ' '.join(map(str, args))
    builtins.print(f'{start_escape}{text}{end_escape}', **kwargs)
