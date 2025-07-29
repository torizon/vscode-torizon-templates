"""Tiny wait-animation wrapper to run a callable and show a spinner."""

import sys
import time
import threading
from itertools import cycle
from typing import Any, Callable, Optional


def run_command_with_wait_animation(call: Callable[..., Any], *args: Any) -> Any:
    """Run `call(*args)` while showing a spinner. Re-raises any exception from `call`."""
    anima_frames = ["🕐", "🕑", "🕒", "🕓", "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚", "🕛"]

    running = [True, False]  # [0]=running, [1]=failed
    output: Any = None
    exc: Optional[BaseException] = None

    def animate() -> None:
        for frame in cycle(anima_frames):
            if not running[0]:
                break
            sys.stdout.write(f"\r{frame} :: RUNNING PLEASE WAIT :: {frame}")
            sys.stdout.flush()
            time.sleep(0.1)

        # clear line and print final status
        sys.stdout.write("\r" + " " * 80)
        sys.stdout.flush()
        sys.stdout.write(
            "\r❌ ::    TASK FAILED    :: ❌\n"
            if running[1]
            else "\r✅ ::    TASK COMPLETED    :: ✅\n"
        )
        sys.stdout.flush()

    def target() -> None:
        nonlocal output, exc
        try:
            output = call(*args)
        except BaseException as e:  # pylint: disable=broad-exception-caught
            exc = e
            running[1] = True
        finally:
            running[0] = False

    t_anim = threading.Thread(target=animate)
    t_call = threading.Thread(target=target)
    t_anim.start()
    t_call.start()
    t_call.join()
    t_anim.join()

    if exc is not None:
        raise exc
    return output

