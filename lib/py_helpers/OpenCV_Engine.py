import sys
import json
import traceback
import os
import faulthandler
import threading
import time


crash_log_path = os.path.join(os.getcwd(), "zCrash.log")


def write_crash_log(message):
    try:
        with open(crash_log_path, "a", encoding="utf-8") as log_file:
            log_file.write(message)
            if not message.endswith("\n"):
                log_file.write("\n")
    except Exception:
        pass


def log_exception(exc_type, exc_value, exc_tb):
    write_crash_log("".join(traceback.format_exception(exc_type, exc_value, exc_tb)))


try:
    faulthandler.enable(all_threads=True)
except Exception:
    pass


sys.excepthook = log_exception

try:
    from casinofingerprint import scan_fingerprint_slots
    from cayofingerprint import detect_fingerprint
    from anchorDetection import (
        run_anchor_detectors,
        keypadAnchor,
        fingerprintAnchor,
        cayoAnchor,
        is_black_area_present_fingerprint,
        is_black_area_present_keypad,
        is_black_area_present_cayo,
    )
    from casinokeypad import detect_ring, detect_column_selected, detect_keypad
except Exception:
    write_crash_log(traceback.format_exc())
    raise

last_heartbeat = time.monotonic()
busy = False


def touch_heartbeat():
    global last_heartbeat
    last_heartbeat = time.monotonic()


def watchdog_loop():
    while True:
        time.sleep(1)
        if busy:
            continue
        if time.monotonic() - last_heartbeat > 5:
            os._exit(0)


threading.Thread(target=watchdog_loop, daemon=True).start()

def handle_request(data):
    try:
        t = data.get("type")

        if t == "heartbeat":
            touch_heartbeat()
            return None

        if t == "fingerprint":
            touch_heartbeat()
            result = scan_fingerprint_slots(None)

            if not result:
                return -1   # empty = no match

            return result
        
        if t == "cayo":
            touch_heartbeat()
            result = detect_fingerprint()
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
            mode = run_anchor_detectors(forCasinoFP=True, forCasinoKP=True, forRubio=True)
            if mode:
                return mode
            return 0

        if t == "is_black_area_present_fingerprint":
            try:
                touch_heartbeat()
                res = is_black_area_present_fingerprint()
                return 1 if res else 0
            except Exception:
                return 0

        if t == "is_black_area_present_keypad":
            try:
                touch_heartbeat()
                res = is_black_area_present_keypad()
                return 1 if res else 0
            except Exception:
                return 0

        if t == "is_black_area_present_cayo":
            try:
                touch_heartbeat()
                res = is_black_area_present_cayo()
                return 1 if res else 0
            except Exception:
                return 0
        
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

            result = detect_ring(debug=False, col=col)
            if result and result.get("found"):
                return result["row"]
            return 0

        if t == "is_column_selected":
            touch_heartbeat()
            col = int(data.get("col", 1))
            result = detect_column_selected(col=col, debug=False)
            return int(result)

        if t == "detect_keypad":
            touch_heartbeat()
            result = detect_keypad(debug=False)
            if result:
                return result
            return ""

        return "ERR"

    except Exception:
        write_crash_log("REQUEST: " + json.dumps(data, ensure_ascii=True))
        write_crash_log(traceback.format_exc())
        return "ERR(Exception)"


def run():
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
            except:
                write_crash_log("BAD_JSON: " + line)
                sys.stdout.write(json.dumps("ERR(Exception)", ensure_ascii=True) + "\n")
                sys.stdout.flush()
                continue

            global busy
            busy = True
            try:
                response = handle_request(data)
                if response is not None:
                    if isinstance(response, str):
                        sys.stdout.write(str(response) + "\n")
                    else:
                        sys.stdout.write(json.dumps(response, ensure_ascii=True) + "\n")
                    sys.stdout.flush()
            finally:
                busy = False
        except Exception as e:
            write_crash_log("RUN_LOOP: " + traceback.format_exc())
            write_crash_log(traceback.format_exc())
            print("FATAL:", e, flush=True)
            traceback.print_exc()


if __name__ == "__main__":
    run()