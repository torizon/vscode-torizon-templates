import sys
import time
import threading
from itertools import cycle

def run_command_with_wait_animation(call, *args):
    anima_frames = ["🕐", "🕑", "🕒", "🕓", "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚", "🕛"]

    def animate():
        for frame in cycle(anima_frames):
            if not running[0]:
                break
            sys.stdout.write(f"\r{frame} :: RUNNING PLEASE WAIT :: {frame}")
            sys.stdout.flush()
            time.sleep(0.1)

        # Clear the line
        sys.stdout.write("\r                             ")

        if running[1]:
            sys.stdout.write("\r❌ ::    TASK FAILED    :: ❌\n")
        else:
            sys.stdout.write("\r✅ ::    TASK COMPLETED    :: ✅\n")

    def target():
        nonlocal output
        try:
            output = call(*args)
        except Exception as e:
            output = e
            running[1] = True
        finally:
            running[0] = False

    # [0] is if it's running [1] if it has failed
    running = [True, False]
    output = None

    animation_thread = threading.Thread(target=animate)
    command_thread = threading.Thread(target=target)

    animation_thread.start()
    command_thread.start()

    command_thread.join()
    animation_thread.join()

    if isinstance(output, Exception):
        raise output

    return output


# # Example usage
# def example_script(duration):
#     time.sleep(duration)
#     return "Task finished"

# if __name__ == "__main__":
#     print("LET'S RUN A SCRIPT THAT TAKES 5 SECONDS TO FINISH")
#     result = run_command_in_background_with_wait_animation(example_script, 5)
#     print(result)
