import cv2
import numpy as np
from PIL import ImageGrab, Image
from helpers import resolve_dump_dir
import os

TARGETS = [
    (907, 331, 1562, 431),
    (907, 404, 1562, 504),
    (907, 500, 1562, 600),
    (907, 560, 1562, 660),
    (907, 627, 1562, 727),
    (907, 697, 1562, 809),
    (907, 780, 1562, 883),
    (907, 863, 1562, 975),
]

SCAN = [
    (424, 360, 810, 415),
    (424, 360 + 76, 810, 415 + 76),
    (424, 360 + 76 * 2, 810, 415 + 76 * 2),
    (424, 360 + 76 * 3, 810, 415 + 76 * 3),
    (424, 360 + 76 * 4, 810, 415 + 76 * 4),
    (424, 360 + 76 * 5, 810, 415 + 76 * 5),
    (424, 360 + 76 * 6, 810, 415 + 76 * 6),
    (424, 360 + 76 * 7, 810, 415 + 76 * 7),
]


def _find_match_index(scan_part: np.ndarray, target_parts: list) -> int:
    """Find which target part matches the scan part. Return -1 if no match."""
    
    threshold = 0.88

    for i, target_part in enumerate(target_parts):
        res = cv2.matchTemplate(target_part, scan_part, cv2.TM_CCOEFF_NORMED)

        if cv2.minMaxLoc(res)[1] >= threshold:
            return i

    return -1


def _dump_debug_image(image, debug_overlay, filename):
    """Dump debug overlay image to lib/dump directory."""
    dump_dir = resolve_dump_dir()
    os.makedirs(dump_dir, exist_ok=True)
    filepath = os.path.join(dump_dir, filename)
    
    # Convert BGR to RGB for PIL
    if debug_overlay.ndim == 3 and debug_overlay.shape[2] == 3:
        debug_overlay = cv2.cvtColor(debug_overlay, cv2.COLOR_BGR2RGB)
    pil_img = Image.fromarray(debug_overlay)
    pil_img.save(filepath)



def detect_fingerprint(image=None, debug=False):
    """Detect Cayo Perico fingerprint parts.

    Returns:
      dict with:
        - solution: list of signed integers (positive=right, negative=left, 0=none)
        - cursor_row: 1-based row index of the brightest matched scan row, or -1 if unknown
    """
    if image is None:
        image = np.array(ImageGrab.grab())
    elif not isinstance(image, np.ndarray):
        image = np.array(image)

    if image.ndim == 3 and image.shape[2] == 4:
        image = image[:, :, :3]
    
    if image.shape[:2] != (1080, 1920):
        image = cv2.resize(image, (1920, 1080))

    # Prepare target parts (right side)
    target_parts = []
    for x1, y1, x2, y2 in TARGETS:
        part = image[y1:y2, x1:x2]
        resized = cv2.resize(part, (int((x2 - x1) * 0.91), int((y2 - y1) * 0.91)))
        gray = cv2.cvtColor(resized, cv2.COLOR_RGB2GRAY)
        target_parts.append(gray)

    # Detect each scan part and calculate smart clicks
    signed_clicks = []
    brightest_row = -1
    brightest_value = -1.0
    debug_overlay = np.copy(image) if debug else None
    
    for row_idx, (x1, y1, x2, y2) in enumerate(SCAN):
        scan_part = image[y1:y2, x1:x2]
        scan_gray = cv2.cvtColor(scan_part, cv2.COLOR_RGB2GRAY)

        matched_idx = _find_match_index(scan_gray, target_parts)

        if matched_idx != -1:
            # Cursor row is the selected (white-ish) segment.
            # Use HSV white-pixel scoring: white has high V and low S, while green has high S.
            max_ch = np.max(scan_part, axis=2)
            fg_mask = max_ch > 35
            if np.any(fg_mask):
                hsv = cv2.cvtColor(scan_part, cv2.COLOR_RGB2HSV)
                h, s, v = cv2.split(hsv)
                white_mask = (s < 70) & (v > 150) & fg_mask
                white_count = int(np.count_nonzero(white_mask))

                # Tie-breaker: average min channel on fg pixels.
                whiteness = np.min(scan_part, axis=2)
                white_mean = float(np.mean(whiteness[fg_mask]))
                row_score = float(white_count) + (white_mean / 1000.0)
            else:
                row_score = -1.0

            if row_score > brightest_value:
                brightest_value = row_score
                brightest_row = row_idx + 1

        if debug:
            # Draw scan box
            cv2.rectangle(debug_overlay, (x1, y1), (x2, y2), (0, 255, 0), 2)
            # Draw matched index text
            if matched_idx != -1:
                label = f"Row {row_idx + 1}: Match {matched_idx + 1} S={brightest_value:.1f}" if brightest_row == row_idx + 1 else f"Row {row_idx + 1}: Match {matched_idx + 1}"
            else:
                label = f"Row {row_idx + 1}: No Match"
            cv2.putText(debug_overlay, label, (x1, y1 - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 0, 0), 1)

        if matched_idx == -1:
            signed_clicks.append(0)
            continue

        # Circular offset from matched index to current row, mod 8 since it's a loop of 8 rows.
        offset = (row_idx - matched_idx) % 8

        if offset == 0:
            signed = 0
        elif offset <= 4:
            signed = int(offset)   # positive = right
        else:
            signed = -int(8 - offset)  # negative = left

        signed_clicks.append(signed)

    if debug:
        if brightest_row != -1:
            x1, y1, x2, y2 = SCAN[brightest_row - 1]
            cv2.rectangle(debug_overlay, (x1, y1), (x2, y2), (255, 255, 0), 2)
            cv2.putText(
                debug_overlay,
                f"Cursor Row: {brightest_row}",
                (x1, max(20, y1 - 12)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.6,
                (255, 255, 0),
                2,
            )
        _dump_debug_image(image, debug_overlay, "fingerprint_debug_overlay.png")

    return {
        "solution": signed_clicks,
        "cursor_row": int(brightest_row),
    }


def main(image=None):
    """Main entry point for direct execution."""
    result = detect_fingerprint(image, True)
    print("[*] Cayo Perico Fingerprint Detection")
    print(result["solution"])
    print("cursor_row:", result["cursor_row"])
    return result


if __name__ == "__main__":
    main()