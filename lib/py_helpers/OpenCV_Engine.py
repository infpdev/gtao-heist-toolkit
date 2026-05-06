import sys
import json
import traceback
from casinofingerprint import main as fingerprint_main
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

def handle_request(data):
    try:
        t = data.get("type")

        if t == "fingerprint":
            result = fingerprint_main(None)

            if not result:
                return ""   # empty = no match

            return ",".join(map(str, result))
        
        if t == "cayo":
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
            # Grab screen and detect which anchor type is present
            mode = run_anchor_detectors(forCasinoFP=True, forCasinoKP=True, forRubio=True)
            if mode:
                return mode
            return -1

        if t == "is_black_area_present_fingerprint":
            try:
                res = is_black_area_present_fingerprint()
                return json.dumps(1, ensure_ascii=True) if res else json.dumps(0, ensure_ascii=True)
            except Exception:
                return json.dumps(0, ensure_ascii=True)

        if t == "is_black_area_present_keypad":
            try:
                res = is_black_area_present_keypad()
                return json.dumps(1, ensure_ascii=True) if res else json.dumps(0, ensure_ascii=True)
            except Exception:
                return json.dumps(0, ensure_ascii=True)

        if t == "is_black_area_present_cayo":
            try:
                res = is_black_area_present_cayo()
                return json.dumps(1, ensure_ascii=True) if res else json.dumps(0, ensure_ascii=True)
            except Exception:
                return json.dumps(0, ensure_ascii=True)
        
        if t == "fpAnchor":
            result = fingerprintAnchor()
            return json.dumps(1, ensure_ascii=True) if result else json.dumps(0, ensure_ascii=True)
        
        if t == "kpAnchor":
            result = keypadAnchor()
            return json.dumps(1, ensure_ascii=True) if result else json.dumps(0, ensure_ascii=True)
        
        if t == "cayoAnchor":
            result = cayoAnchor()
            return json.dumps(1, ensure_ascii=True) if result else json.dumps(0, ensure_ascii=True)

        if t == "detect_ring":
            result = detect_ring(debug=False)
            if result and result.get("found"):
                return json.dumps(result["row"], ensure_ascii=True)
            return json.dumps(0, ensure_ascii=True)

        if t == "is_column_selected":
            col = int(data.get("col", 1))
            result = detect_column_selected(col=col, debug=False)
            return json.dumps(int(result), ensure_ascii=True)

        if t == "detect_keypad":
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

            response = handle_request(data)

            sys.stdout.write(str(response) + "\n")
            sys.stdout.flush()
        except Exception as e:
            print("FATAL:", e, flush=True)
            traceback.print_exc()


if __name__ == "__main__":
    run()