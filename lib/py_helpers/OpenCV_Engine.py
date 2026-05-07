import sys
import json
import traceback
import os
import threading
import time
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
            return "1"

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
            return json.dumps(payload, ensure_ascii=True)

        if t == "detect_anchor":
            touch_heartbeat()
            # Grab screen and detect which anchor type is present
            mode = run_anchor_detectors(forCasinoFP=True, forCasinoKP=True, forRubio=True)
            if mode:
                return mode
            return -1

        if t == "is_black_area_present_fingerprint":
            try:
                touch_heartbeat()
                res = is_black_area_present_fingerprint()
                return json.dumps(1, ensure_ascii=True) if res else json.dumps(0, ensure_ascii=True)
            except Exception:
                return json.dumps(0, ensure_ascii=True)

        if t == "is_black_area_present_keypad":
            try:
                touch_heartbeat()
                res = is_black_area_present_keypad()
                return json.dumps(1, ensure_ascii=True) if res else json.dumps(0, ensure_ascii=True)
            except Exception:
                return json.dumps(0, ensure_ascii=True)

        if t == "is_black_area_present_cayo":
            try:
                touch_heartbeat()
                res = is_black_area_present_cayo()
                return json.dumps(1, ensure_ascii=True) if res else json.dumps(0, ensure_ascii=True)
            except Exception:
                return json.dumps(0, ensure_ascii=True)
        
        if t == "fpAnchor":
            touch_heartbeat()
            result = fingerprintAnchor()
            return json.dumps(1, ensure_ascii=True) if result else json.dumps(0, ensure_ascii=True)
        
        if t == "kpAnchor":
            touch_heartbeat()
            result = keypadAnchor()
            return json.dumps(1, ensure_ascii=True) if result else json.dumps(0, ensure_ascii=True)
        
        if t == "cayoAnchor":
            touch_heartbeat()
            result = cayoAnchor()
            return json.dumps(1, ensure_ascii=True) if result else json.dumps(0, ensure_ascii=True)

        if t == "detect_ring":
            touch_heartbeat()
            result = detect_ring(debug=False)
            if result and result.get("found"):
                return json.dumps(result["row"], ensure_ascii=True)
            return json.dumps(0, ensure_ascii=True)

        if t == "is_column_selected":
            touch_heartbeat()
            col = int(data.get("col", 1))
            result = detect_column_selected(col=col, debug=False)
            return json.dumps(int(result), ensure_ascii=True)

        if t == "detect_keypad":
            touch_heartbeat()
            result = detect_keypad(debug=False)
            if result:
                return result
            return ""

        return "ERR"

    except Exception:
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
                sys.stdout.write("ERR(Exception)\n")
                sys.stdout.flush()
                continue

            global busy
            busy = True
            try:
                response = handle_request(data)
                sys.stdout.write(str(response) + "\n")
                sys.stdout.flush()
            finally:
                busy = False
        except Exception as e:
            print("FATAL:", e, flush=True)
            traceback.print_exc()


if __name__ == "__main__":
    run()