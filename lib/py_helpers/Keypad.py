import os
import cv2
import numpy as np
from PIL import Image, ImageGrab
from helpers import resolve_dump_dir, prepare_detection_image

SCREEN_W = 1920
SCREEN_H = 1080

KEY_BASE_X1_RATIO = 0.2375
KEY_BASE_Y1_RATIO = 0.275
KEY_BASE_X2_RATIO = 0.29
KEY_BASE_Y2_RATIO = 0.769
KEY_SPACING_RATIO = 108 / 1920

RING_SEARCH_X1_RATIO = 0.23
RING_SEARCH_Y1_RATIO = 0.25
RING_SEARCH_X2_RATIO = 0.57
RING_SEARCH_Y2_RATIO = 0.77
RING_BASE_RADIUS = 52


DEBUG_DUMP_DIR = resolve_dump_dir()
RING_DEBUG_PATH = os.path.join(DEBUG_DUMP_DIR, "ring_debug.png")


def _dump_debug_image(image: np.ndarray, filename: str):
    """Write an RGB debug image into the configured dump directory."""
    os.makedirs(DEBUG_DUMP_DIR, exist_ok=True)
    Image.fromarray(image.astype(np.uint8), mode="RGB").save(os.path.join(DEBUG_DUMP_DIR, filename))


def _prepare_image(image=None, scale: float = 0.5):
    """Normalize input frame into RGB numpy array at requested scale."""
    if image is None:
        image = prepare_detection_image(scale)
    else:
        if not isinstance(image, np.ndarray):
            image = np.array(image)

        if image is None or image.size == 0:
            return None

        if image.ndim == 3 and image.shape[2] == 4:
            image = image[:, :, :3]

        # normalize externally supplied images too
        image = prepare_detection_image(scale, image)

    if image is None or image.size == 0:
        return None

    if image.ndim == 3 and image.shape[2] == 4:
        image = image[:, :, :3]

    return image

def _grid_metrics(scale: float):
    """Return scaled keypad grid coordinates and spacing constants."""
    base_x1 = int(KEY_BASE_X1_RATIO * SCREEN_W * scale)
    base_y1 = int(KEY_BASE_Y1_RATIO * SCREEN_H * scale)
    base_x2 = int(KEY_BASE_X2_RATIO * SCREEN_W * scale)
    base_y2 = int(KEY_BASE_Y2_RATIO * SCREEN_H * scale)
    col_spacing = int(KEY_SPACING_RATIO * SCREEN_W * scale)
    row_spacing = int(KEY_SPACING_RATIO * SCREEN_H * scale)
    row_base = int(KEY_BASE_Y1_RATIO * SCREEN_H * scale)
    col_base = int(KEY_BASE_X1_RATIO * SCREEN_W * scale)
    return base_x1, base_y1, base_x2, base_y2, col_spacing, row_spacing, row_base, col_base


def get_keypad(image=None, scale=0.5, debug=False, cols=6):
    """Detect all 6 keypad columns in one call and return the row values."""
    image = _prepare_image(image, scale)
    if image is None:
        return False
    
    if cols==6:
        is_kortz = is_kortz_heist(image=image, scale=scale, col=0, debug=debug)
        if is_kortz:
            cols = 5

    base_x1, base_y1, base_x2, base_y2, col_spacing, row_spacing, row_base, _ = _grid_metrics(scale)

    lower_cyan = np.array([88, 140, 150])
    upper_cyan = np.array([102, 255, 255])
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    debug_img = image.copy() if debug else None

    cols_data = []
    for col in range(cols):
        x1 = base_x1 + (col * col_spacing)
        x2 = base_x2 + (col * col_spacing)
        y1 = base_y1
        y2 = base_y2

        x1 = max(0, min(image.shape[1] - 1, x1))
        x2 = max(x1 + 1, min(image.shape[1], x2))
        y1 = max(0, min(image.shape[0] - 1, y1))
        y2 = max(y1 + 1, min(image.shape[0], y2))

        if debug:
            cv2.rectangle(debug_img, (x1, y1), (x2, y2), (0, 255, 0), 1)

        search_region = image[y1:y2, x1:x2]
        hsv = cv2.cvtColor(search_region, cv2.COLOR_RGB2HSV)
        cyan_mask = cv2.inRange(hsv, lower_cyan, upper_cyan)
        raw_mask = cv2.inRange(hsv, lower_cyan, upper_cyan)

        # if debug:
        #     cv2.imwrite("raw_mask.png", raw_mask)

        cyan_mask = cv2.morphologyEx(
            raw_mask,
            cv2.MORPH_CLOSE,
            kernel,
            iterations=2
        )
            

        contours, _ = cv2.findContours(cyan_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if not contours:
            cols_data.append(-1)
            continue

        valid = []
        for cnt in contours:
            area = cv2.contourArea(cnt)
            if area < 80:
                continue

            x, y, w, h = cv2.boundingRect(cnt)

            if w < 8 or h < 8:
                continue

            # prefer roughly circular blobs
            aspect = w / float(h)
            if aspect < 0.6 or aspect > 1.4:
                continue

            valid.append((cnt, area))

        if not valid:
            cols_data.append(-1)
            continue

        largest_contour = max(valid, key=lambda x: x[1])[0]

        moments = cv2.moments(largest_contour)
        if moments["m00"] == 0:
            cols_data.append(-1)
            continue

        cy_local = int(moments["m01"] / moments["m00"])
        cy_full = y1 + cy_local

        top = base_y1
        bottom = base_y2
        height = bottom - top

        row_height = height / 5
        row = int((cy_full - top + row_height * 0.15) / row_height) + 1
        row = max(1, min(5, row))
        
        cols_data.append(max(1, min(5, row)))

        if debug:
            cnt = largest_contour.copy()
            cnt[:, 0, 0] += x1
            cnt[:, 0, 1] += y1
            cv2.drawContours(debug_img, [cnt], -1, (255, 0, 0), 2)
            cx_local = int(moments["m10"] / moments["m00"])
            cx_full = x1 + cx_local
            cv2.circle(debug_img, (cx_full, cy_full), 5, (0, 0, 255), -1)
            print(hsv[cy_local, cx_local])

    if any(v == -1 for v in cols_data):
        if debug:
            _dump_debug_image(debug_img, "keypad_debug.png")
        return "-1"

    if debug:
        _dump_debug_image(debug_img, "keypad_debug.png")

    return ",".join(map(str, cols_data))

def is_kortz_heist(image=None, scale=0.5, col=0, debug=False):
    """
    Returns True if the selected column looks like the Kortz puzzle
    (bottom circle is dark while the four above are gray).
    """

    if image is None:
        image = _prepare_image(None, scale)
    if image is None:
        return False

    base_x1, base_y1, base_x2, base_y2, col_spacing, row_spacing, _, _ = _grid_metrics(scale)

    x1 = base_x1 + col * col_spacing
    x2 = base_x2 + col * col_spacing

    x1 = max(0, min(image.shape[1] - 1, x1))
    x2 = max(x1 + 1, min(image.shape[1], x2))

    lower_cyan = np.array([90, 40, 20])
    upper_cyan = np.array([150, 255, 255])

    row_h = (base_y2 - base_y1) / 5

    brightness = []
    cyan_counts = []

    for row in range(5):
        cy = int(base_y1 + row_h * (row + 0.5))
        cx = int((x1 + x2) / 2)

        r = int(row_h * 0.4)

        roi = image[
            max(0, cy - r):min(image.shape[0], cy + r),
            max(0, cx - r):min(image.shape[1], cx + r)
        ]

        if roi.size == 0:
            brightness.append(None)
            cyan_counts.append(0)
            continue

        hsv = cv2.cvtColor(roi, cv2.COLOR_RGB2HSV)
        gray = cv2.cvtColor(roi, cv2.COLOR_RGB2GRAY)

        count = cv2.countNonZero(cv2.inRange(hsv, lower_cyan, upper_cyan))

        cyan_counts.append(count)
        brightness.append(float(gray.mean()))

    avg_cyan = sum(cyan_counts) / len(cyan_counts)

    for i in range(5):
        if cyan_counts[i] > avg_cyan * 1.5:
            brightness[i] = None

    bottom = brightness[4]
    if bottom is None:
        return False

    valid = [b for b in brightness[:4] if b is not None]

    if len(valid) < 3:
        return False

    avg_upper = sum(valid) / len(valid)
    diff = avg_upper - bottom

    if debug:
        print("Cyan:", cyan_counts)
        print("Brightness:", brightness)
        print("Upper:", valid)
        print("Bottom:", bottom)
        print("Diff:", diff)

    return diff > 15

def detect_ring(image=None, scale=0.5, debug=False, col=None):
    """Detect the keypad ring position and map it to row 1..5.

    Args:
        image: Optional RGB frame. If omitted, captures screen via helper pipeline.
        scale: Downscale factor used for circle search.
        debug: If true, dumps annotated ring debug image.
        col: Optional 1-based target column. If omitted, scans all columns.

    Returns:
        dict: {"found": True, "circle": (x, y, r), "row": int} when found.
        bool: False when no ring is detected.
    """
    image = _prepare_image(image, 1.0)

    if image is None:
        return False

    img_small = cv2.resize(image, (0, 0), fx=scale, fy=scale)

    base_x = int(RING_SEARCH_X1_RATIO * SCREEN_W * scale)
    col_spacing = int(KEY_SPACING_RATIO * SCREEN_W * scale)

    y1 = int(SCREEN_H * RING_SEARCH_Y1_RATIO * scale)
    y2 = int(SCREEN_H * RING_SEARCH_Y2_RATIO * scale)
    y1 = max(0, min(img_small.shape[0] - 1, y1))
    y2 = max(y1 + 1, min(img_small.shape[0], y2))

    debug_img = image.copy() if debug else None

    def run_region(x1, x2):
    # --- ALWAYS draw region (even if detection fails)
            if debug:
                gx1 = int(x1 / scale)
                gy1 = int(y1 / scale)
                gx2 = int(x2 / scale)
                gy2 = int(y2 / scale)
                cv2.rectangle(debug_img, (gx1, gy1), (gx2, gy2), (0, 255, 0), 2)

            crop = img_small[y1:y2, x1:x2]
            if crop.size == 0:
                return None

            gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
            gray = cv2.GaussianBlur(gray, (9, 9), 2)

            r_scaled = int(RING_BASE_RADIUS * scale)

            circles = cv2.HoughCircles(
                gray,
                cv2.HOUGH_GRADIENT,
                dp=1.2,
                minDist=int(20 * scale),
                param1=100,
                param2=18,
                minRadius=int(r_scaled * 1.0),
                maxRadius=int(r_scaled * 1.1),
            )

            if circles is None:
                return None

            circles = np.uint16(np.around(circles[0]))

            best = None
            best_score = -1

            for cx, cy, r in circles:
                # Brightness of the ring itself
                ring_mask = np.zeros_like(gray, np.uint8)
                cv2.circle(ring_mask, (cx, cy), r, 255, 2)
                ring_score = cv2.mean(gray, mask=ring_mask)[0]

                # Darkness of the center
                center_mask = np.zeros_like(gray, np.uint8)
                cv2.circle(center_mask, (cx, cy), max(2, r // 3), 255, -1)
                center_score = cv2.mean(gray, mask=center_mask)[0]

                # Ring should be bright while center stays dark
                score = ring_score - center_score

                if score > best_score:
                    best_score = score
                    best = (cx, cy, r)

            if best is None:
                return None

            cx, cy, r = best

            full_x = int((x1 + cx) / scale)
            full_y = int((y1 + cy) / scale)
            full_r = int(r / scale)

            if debug:
                for rx, ry, rr in circles:
                    gx = int((x1 + rx) / scale)
                    gy = int((y1 + ry) / scale)
                    gr = int(rr / scale)

                    color = (0, 0, 255)
                    if rx == cx and ry == cy:
                        color = (0, 255, 0)

                    cv2.circle(debug_img, (gx, gy), gr, color, 2)
                    cv2.circle(debug_img, (gx, gy), 3, (255, 255, 0), -1)

            return (full_x, full_y, full_r)
        
    # --- MULTI-COLUMN MODE ---
    if col is None:
        half_w = int(col_spacing)

        for c in range(1, 7):
            cx = base_x + int((c - 0.5) * col_spacing)

            x1 = cx - half_w
            x2 = cx + half_w

            x1 = max(0, min(img_small.shape[1] - 1, x1))
            x2 = max(x1 + 1, min(img_small.shape[1], x2))

            result = run_region(x1, x2)
            if result:
                full_x, full_y, full_r = result
                break
        else:
            if debug:
                _dump_debug_image(debug_img, "ring_debug.png")
            return False

    # --- SINGLE COLUMN MODE ---
    else:
        if not (1 <= col <= 6):
            return False

        cx = base_x + int((col - 0.5) * col_spacing)
        half_w = int(col_spacing)

        x1 = int(cx - half_w * 3/4)
        x2 = int(cx + half_w * 3/4)

        x1 = max(0, min(img_small.shape[1] - 1, x1))
        x2 = max(x1 + 1, min(img_small.shape[1], x2))

        result = run_region(x1, x2)
        if not result:
            if debug:
                _dump_debug_image(debug_img, "ring_debug.png")
            return False

        full_x, full_y, full_r = result

    # --- ROW CALC ---
    top = int(SCREEN_H * RING_SEARCH_Y1_RATIO)
    bottom = int(SCREEN_H * RING_SEARCH_Y2_RATIO)
    height = bottom - top

    row_height = height / 5
    row = int((full_y - top + row_height * 0.15) / row_height) + 1
    row = max(1, min(5, row))

    if debug:
        _dump_debug_image(debug_img, "ring_debug.png")

    return {
        "found": True,
        "circle": (full_x, full_y, full_r),
        "row": row,
    }
    
    
def detect_column_selected(image=None, col=1, scale=0.5, debug=False):
    """Check whether a requested column is selected by detecting cyan pixel patches."""
    image = _prepare_image(image, scale)
    if image is None:
        return False

    if col < 1 or col > 6:
        return False

    base_x1, base_y1, base_x2, base_y2, col_spacing, row_spacing, row_base, _ = _grid_metrics(scale)

    col_index = col - 1
    x1 = base_x1 + (col_index * col_spacing)
    x2 = base_x2 + (col_index * col_spacing)
    y1 = base_y1
    y2 = base_y2

    x1 = max(0, min(image.shape[1] - 1, x1))
    x2 = max(x1 + 1, min(image.shape[1], x2))
    y1 = max(0, min(image.shape[0] - 1, y1))
    y2 = max(y1 + 1, min(image.shape[0], y2))

    search_region = image[y1:y2, x1:x2]

    # Convert to HSV and detect cyan patches
    hsv = cv2.cvtColor(search_region, cv2.COLOR_RGB2HSV)
    
    lower_cyan = np.array([88, 140, 150])
    upper_cyan = np.array([102, 255, 255])
    cyan_mask = cv2.inRange(hsv, lower_cyan, upper_cyan)
    
    # Morphological operations to remove noise and connect nearby pixels
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    cyan_mask = cv2.morphologyEx(cyan_mask, cv2.MORPH_CLOSE, kernel, iterations=2)
    
    # Find contours to identify cyan patches
    contours, _ = cv2.findContours(cyan_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    if not contours:
        return False
    
    # Find largest cyan patch (most likely to be the selection indicator)
    largest_contour = max(contours, key=cv2.contourArea)
    contour_area = cv2.contourArea(largest_contour)
    
    # Minimum area threshold to avoid noise (at least 20 pixels for a solid patch)
    min_area = 20
    if contour_area < min_area:
        return False
    
    # Get the Y position of the cyan patch centroid
    M = cv2.moments(largest_contour)
    if M["m00"] == 0:
        return False
    
    if debug:
        debug_img = image.copy()

        # search region
        cv2.rectangle(debug_img, (x1, y1), (x2, y2), (0, 255, 0), 2)

        # contour (shift to full image coords)
        cnt = largest_contour.copy()
        cnt[:, 0, 0] += x1
        cnt[:, 0, 1] += y1
        cv2.drawContours(debug_img, [cnt], -1, (255, 0, 0), 2)

        # centroid
        cx_local = int(M["m10"] / M["m00"])
        cy_local = int(M["m01"] / M["m00"])
        cx_full = x1 + cx_local
        cy_full_dbg = y1 + cy_local

        cv2.circle(debug_img, (cx_full, cy_full_dbg), 5, (0, 0, 255), -1)

        _dump_debug_image(debug_img, "col_selected_debug_full_col.png")
    
    cy_local = int(M["m01"] / M["m00"])
    cy_full = y1 + cy_local

    # Calculate row from cyan patch Y position (using same logic as AHK)
    top = base_y1
    bottom = base_y2
    height = bottom - top

    row = int((cy_full - top) / (height / 5)) + 1
    row = max(1, min(5, row))
    
    if(debug):
        return {
            "col": col,
            "row": row,
            "point": (x1, cy_full),
            "score": float(contour_area),
        }
    else:
        return True


if __name__ == "__main__":
    # base_dir = os.path.dirname(__file__)
    # img_path = os.path.join(base_dir, "zkeypadwide.png")

    # img = cv2.imread(img_path)

    # if img is None:
    #     raise FileNotFoundError(img_path)

    # # BGR -> RGB
    # img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    
    # result = detect_keypad(image=None, scale=0.5, debug=True, cols=6)
    
    result = detect_ring(image=None, scale=0.5, debug=True)

    # result = detect_column_selected(image=None, debug=True, col=2)
    
    # result = is_kortz_heist(image=None, scale=0.5, col=0, debug=True)

    print(result)