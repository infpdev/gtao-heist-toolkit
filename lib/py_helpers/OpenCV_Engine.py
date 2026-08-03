import faulthandler
import json
import os
import sys
import threading
import traceback
from time import monotonic, sleep

from helpers import is_black_area_present_ledge_grab, log_exception, write_crash_log

try:
    faulthandler.enable(all_threads=True)
except Exception:  # noqa: BLE001, S110
    pass

sys.excepthook = log_exception

##############################################
# Imports and Initialization with Error Handling
##############################################

try:
    from anchorDetection import (
        cayoAnchor,
        fingerprintAnchor,
        is_black_area_present_cayo,
        is_black_area_present_fingerprint,
        is_black_area_present_keypad,
        keypadAnchor,
        run_anchor_detectors,
    )
    from Fingerprint import get_fingerprints
    from Keypad import detect_column_selected, detect_ring, get_keypad
    from Rubio import get_cayo_prints
except Exception:
    write_crash_log(traceback.format_exc())
    raise

last_heartbeat = monotonic()
busy = False


def touch_heartbeat():
    global last_heartbeat
    last_heartbeat = monotonic()


def watchdog_loop():
    """Monitors the heartbeat and exits the process if no heartbeat is received for 5 seconds."""
    while True:
        sleep(1)
        if busy:
            continue
        if monotonic() - last_heartbeat > 5:
            os._exit(0)


threading.Thread(target=watchdog_loop, daemon=True).start()


##############################################
# IPC Request Handling
##############################################


def handle_request(data):
    """Handles incoming requests based on the 'type' field in the data dictionary."""
    try:
        t = data.get("type")

        if t == "heartbeat":
            touch_heartbeat()
            return None

        should_capture_window = data.get("wasGtaFocused", False)

        # write_crash_log(f"should_capture_window: {json.dumps(should_capture_window, ensure_ascii=True)}")

        try:
            if t == "get_fingerprint":
                touch_heartbeat()
                result = get_fingerprints(
                    None, should_capture_window=should_capture_window
                )

                if not result:
                    return -1  # empty = no match

                return result

            if t == "get_cayo":
                touch_heartbeat()
                result = get_cayo_prints(should_capture_window=should_capture_window)
                if not result:
                    return ""

                cursor_row = int(result.get("cursor_row", -1))
                solution = result.get("solution", [])
                payload = {
                    "row": cursor_row,
                    "clicks": [int(v) for v in solution],
                }
                return payload

            if t == "detect_anchor":
                touch_heartbeat()
                # Grab screen and detect which anchor type is present
                mode = run_anchor_detectors(
                    forCasinoFP=True, forCasinoKP=True, forRubio=True
                )
                if mode:
                    return mode
                return 0

            if t == "is_black_area_present_fingerprint":
                touch_heartbeat()
                res = is_black_area_present_fingerprint()
                return 1 if res else 0

            if t == "is_black_area_present_keypad":
                touch_heartbeat()
                res = is_black_area_present_keypad()
                return 1 if res else 0

            if t == "is_black_area_present_cayo":
                touch_heartbeat()
                res = is_black_area_present_cayo()
                return 1 if res else 0

            if t == "is_black_area_present_ledge_grab":
                touch_heartbeat()
                res = is_black_area_present_ledge_grab()
                return 1 if res else 0

            if t == "fpAnchor":
                touch_heartbeat()
                result = fingerprintAnchor()
                return 1 if result else 0

            if t == "kpAnchor":
                touch_heartbeat()
                result = keypadAnchor()
                return 1 if result else 0

            if t == "cayoAnchor":
                touch_heartbeat()
                result = cayoAnchor()
                return 1 if result else 0

            if t == "detect_ring":
                touch_heartbeat()
                col_raw = data.get("col", None)
                try:
                    col = int(col_raw) if col_raw is not None else None
                except (TypeError, ValueError):
                    col = None

                result = detect_ring(
                    col=col, debug=False, should_capture_window=should_capture_window
                )
                if result and result.get("found"):
                    return result["row"]
                return 0

            if t == "is_column_selected":
                touch_heartbeat()
                col = int(data.get("col", 1))
                result = detect_column_selected(col=col, debug=False)
                return int(result)

            if t == "get_keypad":
                isKortzHeist = data.get("isKortzHeist", False)
                cols = 5 if isKortzHeist else 6
                touch_heartbeat()
                result = get_keypad(
                    debug=False, cols=cols, should_capture_window=should_capture_window
                )
                if result:
                    return result
                return ""
        except Exception:  # noqa: BLE001
            write_crash_log(
                "REQUEST: "
                + json.dumps(data, ensure_ascii=True)
                + "\n"
                + traceback.format_exc()
            )
            return 0

        return "ERR"

    except Exception:  # noqa: BLE001
        write_crash_log(
            "REQUEST: "
            + json.dumps(data, ensure_ascii=True)
            + "\n"
            + traceback.format_exc()
        )
        write_crash_log(traceback.format_exc())
        return "ERR(Exception)"


def run():
    """Main loop to read requests from stdin and handle them.
    Exits the loop if a request of type 'STOP' is received.
    """
    while True:
        try:
            line = sys.stdin.readline()
            # print(f"RAW: [{line}]")
            if not line:
                continue

            line = line.strip()
            if not line:
                continue

            try:
                data = json.loads(line)
            except:  # noqa: E722
                write_crash_log("BAD_JSON: " + line)
                sys.stdout.write(json.dumps("ERR(Exception)", ensure_ascii=True) + "\n")
                sys.stdout.flush()
                continue

            global busy
            busy = True
            try:
                request_type_str = data.get("type")
                if request_type_str == "STOP":
                    break

                response = handle_request(data)

                if response is not None:
                    if isinstance(response, str):
                        sys.stdout.write(str(response) + "\n")
                    else:
                        sys.stdout.write(json.dumps(response, ensure_ascii=True) + "\n")
                    sys.stdout.flush()
            finally:
                busy = False
        except Exception as e:  # noqa: BLE001
            write_crash_log("RUN_LOOP: " + traceback.format_exc())
            write_crash_log(traceback.format_exc())
            print("FATAL:", e, flush=True)
            traceback.print_exc()


if __name__ == "__main__":
    run()
