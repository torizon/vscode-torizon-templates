# pylint: disable=missing-function-docstring
# pylint: disable=missing-module-docstring
import debugpy # type: ignore[import-untyped]

DEBUG_INITIALIZED = False

def vscode_prepare(port: int = 5679) -> None:
    global DEBUG_INITIALIZED

    if DEBUG_INITIALIZED:
        return

    print("__debugpy__")
    debugpy.listen(("0.0.0.0", port))
    print("__debugpy__ go")
    debugpy.wait_for_client()
    print(f"__debugpy__ is connected [{debugpy.is_client_connected()}]")

    DEBUG_INITIALIZED = True

def breakpoint() -> None:
    debugpy.breakpoint()
