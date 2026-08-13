import cv2
import numpy as np
from helpers import dump_debug_image, prepare_detection_image

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
    """Clamp (x1, y1, x2, y2) to valid image bounds."""
    h_img, w_img = img.shape[:2]
    x1, y1, x2, y2 = region
    x1 = max(0, min(w_img - 1, int(x1)))
    x2 = max(0, min(w_img, int(x2)))
    y1 = max(0, min(h_img - 1, int(y1)))
    y2 = max(0, min(h_img, int(y2)))
    return x1, y1, x2, y2


def _color_ratio_in_region(
    img: np.ndarray, region: tuple, lower: np.ndarray, upper: np.ndarray
) -> float:
    """Return ratio of pixels in region within a single HSV range."""
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


def _multi_color_ratio_in_region(
    img: np.ndarray, region: tuple, ranges: tuple
) -> float:
    """Return ratio of pixels in region matching any of multiple HSV ranges."""
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
    """Return warm-color ratio (red/pink/beige) used by casino anchor checks."""
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
    """Return green pixel ratio in region for cayo anchor detection."""
    return _color_ratio_in_region(img, region, _GREEN_LOWER, _GREEN_UPPER)


def _edge_density_in_region(img: np.ndarray, region: tuple) -> float:
    """Estimate structure in region using Canny edge density."""
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


def fingerprintAnchor(
    search_img: np.ndarray = None,
    threshold: float = 0.1,
    return_score: bool = False,
    scale: float = 0.5,
):
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

    matched = (
        is_black_area_present_fingerprint(search_img=search_img, scale=scale)
        if matched
        else False
    )

    score = {
        "matched": matched,
        "score_raw": ratio,
        "score_edge": edge_density,
        "score_final": score_final,
        "ratio": ratio,
        "threshold": threshold,
    }

    if return_score:
        return {
            "mode": "fingerprint" if matched else None,
            "scores": score,
            "region": region,
        }
    return "fingerprint" if matched else None


def keypadAnchor(
    search_img: np.ndarray = None,
    threshold: float = 0.1,
    return_score: bool = False,
    scale: float = 0.5,
):
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

    matched = (
        is_black_area_present_keypad(search_img=search_img, scale=scale)
        if matched
        else False
    )
    score = {
        "matched": matched,
        "score_raw": ratio,
        "score_edge": edge_density,
        "score_final": score_final,
        "ratio": ratio,
        "threshold": threshold,
    }

    if return_score:
        return {
            "mode": "keypad" if matched else None,
            "scores": score,
            "region": region,
        }
    return "keypad" if matched else None


def cayoAnchor(
    search_img: np.ndarray = None,
    threshold: float = 0.4,
    return_score: bool = False,
    scale: float = 0.5,
):
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
    # print("matched? " + ("true" if matched else "false"), flush=True)

    matched = (
        is_black_area_present_cayo(search_img=search_img, scale=scale)
        if matched
        else False
    )

    score = {
        "matched": matched,
        "score_raw": ratio,
        "score_edge": 0.0,
        "score_final": ratio,
        "ratio": ratio,
        "threshold": threshold,
    }

    if return_score:
        return {"mode": "cayo" if matched else None, "scores": score, "region": region}
    return "cayo" if matched else None


def is_dark_uniform_region(img: np.ndarray, region: tuple) -> float:
    """
    Returns percentage [0.0 - 1.0] of very dark pixels in region.
    """

    if img is None:
        return 0.0

    x1, y1, x2, y2 = _clamp_region(img, region)

    crop = img[y1:y2, x1:x2]

    if crop.size == 0:
        return 0.0

    gray = cv2.cvtColor(crop, cv2.COLOR_RGB2GRAY)

    # tweak this if needed
    threshold = 10

    dark_pixels = gray <= threshold

    return float(np.count_nonzero(dark_pixels) / gray.size)


def is_black_area_present_fingerprint(
    search_img: np.ndarray = None, scale: float = 0.5
) -> bool:
    """Return True if the fingerprint anchor black-area is PRESENT.

    Region: 1606, 441, 1882, 531 (normalized: 0.837, 0.218, 0.786, 0.267)
    Region: 122, 596, 312, 744 (normalized: 0.064, 0.552, 0.163, 0.689)
    """
    if search_img is None:
        search_img = prepare_detection_image(scale)

    regions = get_black_area_regions("fingerprint", scale)

    scores = [is_dark_uniform_region(search_img, r) for r in regions]

    return all(s > 0.3 for s in scores)


def is_black_area_present_keypad(
    search_img: np.ndarray = None, scale: float = 1.0
) -> bool:
    """Return True if the keypad anchor black-area is PRESENT.

    Region: 1606, 441, 1882, 531 (normalized: 0.837, 0.218, 0.786, 0.267)
    Region: 122, 596, 312, 744 (normalized: 0.064, 0.552, 0.163, 0.689)
    """
    if search_img is None:
        search_img = prepare_detection_image(scale)

    regions = get_black_area_regions("keypad", scale)

    scores = [is_dark_uniform_region(search_img, r) for r in regions]
    return all(s > 0.3 for s in scores)


def is_black_area_present_cayo(
    search_img: np.ndarray = None, scale: float = 0.5
) -> bool:
    """Return True if the cayo anchor black-area is PRESENT.

    Region: 1605, 329, 1898, 783 (normalized: 0.836, 0.305, 0.989, 0.725)
    """
    if search_img is None:
        search_img = prepare_detection_image(scale)

    regions = get_black_area_regions("cayo", scale)

    scores = [is_dark_uniform_region(search_img, r) for r in regions]
    return all(s > 0.7 for s in scores)


def get_black_area_regions(mode: str, scale: float = 0.5):
    """Return list of black-area region tuples for the given mode.

    mode: 'fingerprint', 'keypad', or 'cayo'
    """
    if mode == "fingerprint":
        return [
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
    if mode == "keypad":
        return [
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
    if mode == "cayo":
        return [
            (
                int(1649 * scale),
                int(437 * scale),
                int(1891 * scale),
                int(564 * scale),
            ),
            # 35, 331, 127, 683
            (
                int(35 * scale),
                int(331 * scale),
                int(127 * scale),
                int(683 * scale),
            ),
        ]
    return []


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
    """Run enabled anchor detectors and return best mode or detailed scores.

    Args:
        forCasinoFP: Enable fingerprint detector.
        forCasinoKP: Enable keypad detector.
        forRubio: Enable cayo detector.
        thresholds: Optional per-mode threshold overrides.
        debug: If true, writes annotated debug image.
        debug_path: Reserved for compatibility; currently unused.
        processing_scale: Screen/image scaling factor used during detection.
        return_details: If true, return score payload for each enabled mode.
        image: Optional RGB image. If omitted, screen is captured.
    """
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
            fp = fingerprintAnchor(
                img,
                threshold=thresholds.get("fp", 0.1),
                return_score=True,
                scale=processing_scale,
            )

            if fp:
                details["fingerprint"] = fp["scores"]
                debug_regions.append(
                    (f"fp {fp['scores']['score_final']:.4f}", fp["region"], (0, 255, 0))
                )

                if fp["mode"]:
                    candidates.append(("fingerprint", fp["scores"]["score_final"]))
            else:
                details["fingerprint"] = None

        else:
            fp = fingerprintAnchor(
                img,
                threshold=thresholds.get("fp", 0.1),
                return_score=False,
                scale=processing_scale,
            )

            if fp:
                candidates.append(("fingerprint", 1.0))

    # ------------------------
    # KEYPAD
    # ------------------------
    if forCasinoKP:
        if debug:
            kp = keypadAnchor(
                img,
                threshold=thresholds.get("kp", 0.1),
                return_score=True,
                scale=processing_scale,
            )

            if kp:
                details["keypad"] = kp["scores"]
                debug_regions.append(
                    (
                        f"kp {kp['scores']['score_final']:.4f}",
                        kp["region"],
                        (255, 255, 0),
                    )
                )
                if kp["mode"]:
                    candidates.append(("keypad", kp["scores"]["score_final"]))

            else:
                details["keypad"] = None

        else:
            kp = keypadAnchor(
                img,
                threshold=thresholds.get("kp", 0.1),
                return_score=False,
                scale=processing_scale,
            )

            if kp:
                candidates.append(("keypad", 1.0))

    # ------------------------
    # CAYO
    # ------------------------
    if forRubio:
        if debug:
            rb = cayoAnchor(
                img,
                threshold=thresholds.get("rubio", 0.4),
                return_score=True,
                scale=processing_scale,
            )

            if rb:
                details["cayo"] = rb["scores"]
                debug_regions.append(
                    (
                        f"cayo {rb['scores']['score_final']:.4f}",
                        rb["region"],
                        (255, 128, 0),
                    )
                )
                if rb["mode"]:
                    candidates.append(("cayo", rb["scores"]["score_final"]))

            else:
                details["cayo"] = None

        else:
            rb = cayoAnchor(
                img,
                threshold=thresholds.get("rubio", 0.4),
                return_score=False,
                scale=processing_scale,
            )

            if rb:
                candidates.append(("cayo", 1.0))

    # ------------------------
    # PICK BEST
    # ------------------------
    mode = None
    if candidates:
        ranked = sorted(candidates, key=lambda x: x[1], reverse=True)
        mode = ranked[0][0]
        if len(ranked) > 1 and (ranked[0][1] - ranked[1][1]) < _MODE_WIN_MARGIN:
            mode = None

    # ------------------------
    # BLACK-REGION OVERLAYS (centralized)
    # If a specific mode was detected, annotate only that mode's black regions.
    # Otherwise annotate all black-region areas for debugging.
    if debug:
        label_map = {"fingerprint": "blk_fp", "keypad": "blk_kp", "cayo": "blk_cayo"}
        if mode is not None:
            label = label_map.get(mode, f"blk_{mode}")
            for r in get_black_area_regions(mode, processing_scale):
                s = is_dark_uniform_region(img, r)
                debug_regions.append((f"{label} {s:.3f}", r, (255, 0, 255)))
        else:
            for m, label in [
                ("fingerprint", "blk_fp"),
                ("keypad", "blk_kp"),
                ("cayo", "blk_cayo"),
            ]:
                for r in get_black_area_regions(m, processing_scale):
                    s = is_dark_uniform_region(img, r)
                    debug_regions.append((f"{label} {s:.3f}", r, (255, 0, 255)))

    # ------------------------
    # DEBUG OUTPUT
    # ------------------------
    if debug:
        dump_debug_image(img, debug_regions)

    # ------------------------
    # RETURN
    # ------------------------
    if return_details:
        return {"mode": mode, "scores": details}

    return mode


if __name__ == "__main__":
    # base_dir = os.path.dirname(__file__)
    # img_path = os.path.join(base_dir, "zkeypadwide.png")

    # img = cv2.imread(img_path)

    # if img is None:
    #     raise FileNotFoundError(img_path)

    # # convert BGR -> RGB BEFORE helper
    # img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    # img = prepare_detection_image(0.5, img)

    result = run_anchor_detectors(
        True, True, True, debug=True, processing_scale=0.5, return_details=True
    )

    print(result)
