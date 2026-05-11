import os

import numpy as np
import cv2

from helpers import prepare_detection_image, _dump_debug_image


# HSV color ranges
_RED_LOWER_1 = np.array([0, 80, 80], dtype=np.uint8)
_RED_UPPER_1 = np.array([10, 255, 255], dtype=np.uint8)
_RED_LOWER_2 = np.array([170, 80, 80], dtype=np.uint8)
_RED_UPPER_2 = np.array([180, 255, 255], dtype=np.uint8)
_PINK_LOWER = np.array([145, 40, 40], dtype=np.uint8)
_PINK_UPPER = np.array([180, 255, 255], dtype=np.uint8)
_BEIGE_LOWER = np.array([18, 15, 80], dtype=np.uint8)
_BEIGE_UPPER = np.array([55, 140, 255], dtype=np.uint8)
_GREEN_LOWER = np.array([40, 60, 60], dtype=np.uint8)
_GREEN_UPPER = np.array([90, 255, 255], dtype=np.uint8)

# Minimum edge density required to reject flat color backgrounds.
_FINGERPRINT_EDGE_MIN = 0.015
_KEYPAD_EDGE_MIN = 0.008

# Minimum combined confidence required to accept a mode.
_FINGERPRINT_FINAL_MIN = 0.20
_KEYPAD_FINAL_MIN = 0.20

# If two modes are very close, treat as ambiguous and return no mode.
_MODE_WIN_MARGIN = 0.03


def _clamp_region(img: np.ndarray, region: tuple) -> tuple:
    h_img, w_img = img.shape[:2]
    x1, y1, x2, y2 = region
    x1 = max(0, min(w_img - 1, int(x1)))
    x2 = max(0, min(w_img, int(x2)))
    y1 = max(0, min(h_img - 1, int(y1)))
    y2 = max(0, min(h_img, int(y2)))
    return x1, y1, x2, y2


def _color_ratio_in_region(img: np.ndarray, region: tuple, lower: np.ndarray, upper: np.ndarray) -> float:
    if img is None:
        return 0.0
    x1, y1, x2, y2 = _clamp_region(img, region)
    if x2 <= x1 or y2 <= y1:
        return 0.0
    crop = img[y1:y2, x1:x2]
    if crop.size == 0:
        return 0.0

    # ImageGrab -> numpy gives RGB; convert using RGB->HSV.
    hsv = cv2.cvtColor(crop, cv2.COLOR_RGB2HSV)
    mask = cv2.inRange(hsv, lower, upper)
    total = mask.size
    if total == 0:
        return 0.0
    return float(np.count_nonzero(mask)) / float(total)


def _multi_color_ratio_in_region(img: np.ndarray, region: tuple, ranges: tuple) -> float:
    if img is None:
        return 0.0
    x1, y1, x2, y2 = _clamp_region(img, region)
    if x2 <= x1 or y2 <= y1:
        return 0.0
    crop = img[y1:y2, x1:x2]
    if crop.size == 0:
        return 0.0

    hsv = cv2.cvtColor(crop, cv2.COLOR_RGB2HSV)
    combined = None
    for lower, upper in ranges:
        mask = cv2.inRange(hsv, lower, upper)
        combined = mask if combined is None else cv2.bitwise_or(combined, mask)

    total = combined.size
    if total == 0:
        return 0.0
    return float(np.count_nonzero(combined)) / float(total)


def _red_like_ratio_in_region(img: np.ndarray, region: tuple) -> float:
    # Warm indicator can skew across red, pink/magenta, and beige under overlays.
    return _multi_color_ratio_in_region(
        img,
        region,
        (
            (_RED_LOWER_1, _RED_UPPER_1),
            (_RED_LOWER_2, _RED_UPPER_2),
            (_PINK_LOWER, _PINK_UPPER),
            (_BEIGE_LOWER, _BEIGE_UPPER),
        ),
    )


def _green_ratio_in_region(img: np.ndarray, region: tuple) -> float:
    return _color_ratio_in_region(img, region, _GREEN_LOWER, _GREEN_UPPER)


def _edge_density_in_region(img: np.ndarray, region: tuple) -> float:
    if img is None:
        return 0.0
    x1, y1, x2, y2 = _clamp_region(img, region)
    if x2 <= x1 or y2 <= y1:
        return 0.0

    crop = img[y1:y2, x1:x2]
    if crop.size == 0:
        return 0.0

    gray = cv2.cvtColor(crop, cv2.COLOR_RGB2GRAY)
    # Light blur suppresses noisy pixel-level edges before Canny.
    gray = cv2.GaussianBlur(gray, (3, 3), 0)
    edges = cv2.Canny(gray, 70, 160)
    total = edges.size
    if total == 0:
        return 0.0
    return float(np.count_nonzero(edges)) / float(total)





def fingerprintAnchor(search_img: np.ndarray = None, threshold: float = 0.1, return_score: bool = False, scale: float = 0.5):
    """Detect fingerprint mode by red ratio in fingerprint region."""
    if search_img is None:
        search_img = prepare_detection_image(scale)

    rx1, ry1, rx2, ry2 = 0.757, 0.2182, 0.786, 0.267
    region = (
        int(rx1 * 1920 * scale),
        int(ry1 * 1080 * scale),
        int(rx2 * 1920 * scale),
        int(ry2 * 1080 * scale),
    )

    ratio = _red_like_ratio_in_region(search_img, region)
    edge_density = _edge_density_in_region(search_img, region)
    score_final = ratio * min(1.0, edge_density / _FINGERPRINT_EDGE_MIN)
    matched = (
        ratio >= threshold
        and edge_density >= _FINGERPRINT_EDGE_MIN
        and score_final >= _FINGERPRINT_FINAL_MIN
    )
    
    matched = is_black_area_present_fingerprint(search_img=search_img, scale=scale) if matched else False
    
    score = {
        'matched': matched,
        'score_raw': ratio,
        'score_edge': edge_density,
        'score_final': score_final,
        'ratio': ratio,
        'threshold': threshold,
    }

    if return_score:
        return {'mode': 'fingerprint' if matched else None, 'scores': score, 'region': region}
    return 'fingerprint' if matched else None


def keypadAnchor(search_img: np.ndarray = None, threshold: float = 0.1, return_score: bool = False, scale: float = 0.5):
    """Detect keypad mode by warm-color ratio in keypad region."""
    if search_img is None:
        search_img = prepare_detection_image(scale)

    rx1, ry1, rx2, ry2 = 0.536, 0.119, 0.563, 0.168
    region = (
        int(rx1 * 1920 * scale),
        int(ry1 * 1080 * scale),
        int(rx2 * 1920 * scale),
        int(ry2 * 1080 * scale),
    )

    ratio = _red_like_ratio_in_region(search_img, region)
    edge_density = _edge_density_in_region(search_img, region)
    score_final = ratio * min(1.0, edge_density / _KEYPAD_EDGE_MIN)
    matched = (
        ratio >= threshold
        and edge_density >= _KEYPAD_EDGE_MIN
        and score_final >= _KEYPAD_FINAL_MIN
    )
    
    matched = is_black_area_present_keypad(search_img=search_img, scale=scale) if matched else False
    score = {
        'matched': matched,
        'score_raw': ratio,
        'score_edge': edge_density,
        'score_final': score_final,
        'ratio': ratio,
        'threshold': threshold,
    }

    if return_score:
        return {'mode': 'keypad' if matched else None, 'scores': score, 'region': region}
    return 'keypad' if matched else None


def cayoAnchor(search_img: np.ndarray = None, threshold: float = 0.4, return_score: bool = False, scale: float = 0.5):
    """Detect cayo mode by green ratio in cayo region."""
    if search_img is None:
        search_img = prepare_detection_image(scale)

    rx1, ry1, rx2, ry2 = 0.48, 0.09, 0.6, 0.11
    region = (
        int(rx1 * 1920 * scale),
        int(ry1 * 1080 * scale),
        int(rx2 * 1920 * scale),
        int(ry2 * 1080 * scale),
    )

    ratio = _green_ratio_in_region(search_img, region)
    matched = ratio >= threshold
    
    matched = is_black_area_present_cayo(search_img=search_img, scale=scale) if matched else False
    
    score = {
        'matched': matched,
        'score_raw': ratio,
        'score_edge': 0.0,
        'score_final': ratio,
        'ratio': ratio,
        'threshold': threshold,
    }

    if return_score:
        return {'mode': 'cayo' if matched else None, 'scores': score, 'region': region}
    return 'cayo' if matched else None


def is_dark_uniform_region(img: np.ndarray, region: tuple) -> bool:
    if img is None:
        return False

    x1, y1, x2, y2 = _clamp_region(img, region)

    crop = img[y1:y2, x1:x2]

    if crop.size == 0:
        return False

    hsv = cv2.cvtColor(crop, cv2.COLOR_RGB2HSV)

    h, s, v = cv2.split(hsv)

    mean_v = np.mean(v)
    mean_s = np.mean(s)
    std_v = np.std(v)

    # return f"{mean_v} {mean_s} {std_v}"
    return (
    mean_v < 20
    and std_v < 12
)


def is_black_area_present_fingerprint(search_img: np.ndarray = None, scale: float = 0.5) -> bool:
    """Return True if the fingerprint anchor black-area is PRESENT.

    Region: 1606, 806, 1891, 943 (normalized: 0.837, 0.746, 0.985, 0.873)
    """
    if search_img is None:
        search_img = prepare_detection_image(scale)
    
    regions = [
        (
            int(1606 * scale),
            int(441 * scale),
            int(1882 * scale),
            int(531 * scale),
        ),

        (
            int(122 * scale),
            int(596 * scale),
            int(312 * scale),
            int(744 * scale),
        ),
    ]
    

    scores = [
        is_dark_uniform_region(search_img, r)
        for r in regions
    ]

    return any(scores)


def is_black_area_present_keypad(search_img: np.ndarray = None, scale: float = 1.0) -> bool:
    """Return True if the keypad anchor black-area is PRESENT.

    Region: 1606, 806, 1891, 943 (normalized: 0.837, 0.746, 0.985, 0.873)
    """
    if search_img is None:
        search_img = prepare_detection_image(scale)
    
    regions = [
        (
            int(1606 * scale),
            int(441 * scale),
            int(1882 * scale),
            int(531 * scale),
        ),

        (
            int(122 * scale),
            int(596 * scale),
            int(312 * scale),
            int(744 * scale),
        ),
    ]
    

    scores = [
        is_dark_uniform_region(search_img, r)
        for r in regions
    ]

    return any(scores)


def is_black_area_present_cayo(search_img: np.ndarray = None, scale: float = 0.5) -> bool:
    """Return True if the cayo anchor black-area is PRESENT.

    Region: 1605, 329, 1898, 783 (normalized: 0.836, 0.305, 0.989, 0.725)
    """
    if search_img is None:
        search_img = prepare_detection_image(scale)
    
    regions = [
        # 1666, 342, 1866, 547
        (
            int(1660 * scale),
            int(340 * scale),
            int(1870 * scale),
            int(550 * scale),
        ),

        # 68, 486, 285, 670
        (
            int(70 * scale),
            int(480 * scale),
            int(285 * scale),
            int(670 * scale),
        ),
    ]
    

    scores = [
        is_dark_uniform_region(search_img, r)
        for r in regions
    ]

    return any(scores)


def run_anchor_detectors(
    forCasinoFP=False,
    forCasinoKP=False,
    forRubio=False,
    thresholds=None,
    debug=False,
    debug_path=None,
    processing_scale=0.5,
    return_details=False,
    image=None,
):
    if image is None:
        img = prepare_detection_image(processing_scale)
    else:
        img = image

    details = {}
    candidates = []
    debug_regions = []
    if thresholds is None:
        thresholds = {}

    # ------------------------
    # FINGERPRINT
    # ------------------------
    if forCasinoFP:
        if debug:
            fp = fingerprintAnchor(img, threshold=thresholds.get('fp', 0.1), return_score=True, scale=processing_scale)

            if fp:
                details['fingerprint'] = fp['scores']
                debug_regions.append(
                    (f"fp {fp['scores']['score_final']:.4f}", fp['region'], (0, 255, 0))
                )
                if fp['mode']:
                    candidates.append(('fingerprint', fp['scores']['score_final']))
            else:
                details['fingerprint'] = None

        else:
            fp = fingerprintAnchor(img, threshold=thresholds.get('fp', 0.1), return_score=False, scale=processing_scale)

            if fp:
                candidates.append(('fingerprint', 1.0))  # dummy score

    # ------------------------
    # KEYPAD
    # ------------------------
    if forCasinoKP:
        if debug:
            kp = keypadAnchor(img, threshold=thresholds.get('kp', 0.1), return_score=True, scale=processing_scale)

            if kp:
                details['keypad'] = kp['scores']
                debug_regions.append(
                    (f"kp {kp['scores']['score_final']:.4f}", kp['region'], (255, 255, 0))
                )
                if kp['mode']:
                    candidates.append(('keypad', kp['scores']['score_final']))
            else:
                details['keypad'] = None

        else:
            kp = keypadAnchor(img, threshold=thresholds.get('kp', 0.1), return_score=False, scale=processing_scale)

            if kp:
                candidates.append(('keypad', 1.0))

    # ------------------------
    # CAYO
    # ------------------------
    if forRubio:
        if debug:
            rb = cayoAnchor(img, threshold=thresholds.get('rubio', 0.4), return_score=True, scale=processing_scale)

            if rb:
                details['cayo'] = rb['scores']
                debug_regions.append(
                    (f"cayo {rb['scores']['score_final']:.4f}", rb['region'], (255, 128, 0))
                )
                if rb['mode']:
                    candidates.append(('cayo', rb['scores']['score_final']))
            else:
                details['cayo'] = None

        else:
            rb = cayoAnchor(img, threshold=thresholds.get('rubio', 0.4), return_score=False, scale=processing_scale)

            if rb:
                candidates.append(('cayo', 1.0))

    # ------------------------
    # PICK BEST
    # ------------------------
    mode = None
    if candidates:
        ranked = sorted(candidates, key=lambda x: x[1], reverse=True)
        mode = ranked[0][0]
        if len(ranked) > 1:
            if (ranked[0][1] - ranked[1][1]) < _MODE_WIN_MARGIN:
                mode = None

    # ------------------------
    # DEBUG OUTPUT
    # ------------------------
    if debug:
        _dump_debug_image(img, debug_regions)

    # ------------------------
    # RETURN
    # ------------------------
    if return_details:
        return {
            "mode": mode,
            "scores": details
        }

    return mode



if __name__ == "__main__":
    base_dir = os.path.dirname(__file__)
    img_path = os.path.join(base_dir, "zkeypadwide.png")

    img = cv2.imread(img_path)

    if img is None:
        raise FileNotFoundError(img_path)

    # convert BGR -> RGB BEFORE helper
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    img = prepare_detection_image(0.5, img)

    result = run_anchor_detectors(True, True, True, debug=True, processing_scale=0.5, return_details=True, image=img)

    print(result)