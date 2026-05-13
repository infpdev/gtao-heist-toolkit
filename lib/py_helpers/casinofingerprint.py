import os

import cv2
import time
import numpy as np
from PIL import ImageDraw, Image
from helpers import resolve_dump_dir, prepare_detection_image

tofind = (950, 155, 1335, 685)

parts = [[(482, 279, 482 + 102, 279 + 102), (0, 0)],
[(627, 279, 627 + 102, 279 + 102), (1, 0)],
[(482, 423, 482 + 102, 423 + 102), (0, 1)],
[(627, 423, 627 + 102, 423 + 102), (1, 1)],
[(482, 566, 482 + 102, 566 + 102), (0, 2)],
[(627, 566, 627 + 102, 566 + 102), (1, 2)],
[(482, 711, 482 + 102, 711 + 102), (0, 3)],
[(627, 711, 627 + 102, 711 + 102), (1, 3)]]


def dump_debug_scan_image(image, found_slots, searched_slots, brightness_map, scale=0.5):
    """Helper debug renderer for slot detection results.

    Saves an annotated scan image that highlights searched slots and matched slots,
    including brightness value for each slot.
    """
    
    output_path = os.path.join(resolve_dump_dir(), "fingerprint_debug.png")

    debug_image = image.copy()
    draw = ImageDraw.Draw(debug_image)
    found_set = set(found_slots)
    searched_set = set(searched_slots)

    for idx, part in enumerate(parts, start=1):
        if idx not in searched_set:
            continue
        
        box = part[0]
        box_scaled =  tuple(int(v * scale) for v in box)
        color = "lime" if idx in found_set else "red"
        draw.rectangle(box_scaled, outline=color, width=2)
        label_x = box_scaled[0]
        label_y = box_scaled[1] - 15
        brightness = brightness_map.get(idx, 0)
        label_text = f"{idx} ({brightness:.0f})"
        draw.text((label_x, label_y), label_text, fill=color)

    debug_image.save(output_path)
    debug_image.close()




def is_in(img, subimg, threshold=0.65):
    """Return True when template match score is above threshold."""
    subimg_gray = cv2.cvtColor(np.array(subimg), cv2.COLOR_BGR2GRAY)
    res = cv2.matchTemplate(img, subimg_gray, cv2.TM_CCOEFF_NORMED)
    
    # Use minMaxLoc for faster single-match detection
    _, max_val, _, _ = cv2.minMaxLoc(res)
    return max_val >= threshold


def scan_fingerprint_slots(img=None, threshold=0.65, debug=False):
    """Detect candidate fingerprint slots from the prepared game frame.

    Returns:
        str: Comma-separated slot indices (for example, "1,3,4") when accepted matches exist.
        int: 100 when matches exist but all are already selected.
        int: 0 when no slot matches are found.
    """
    t0 = time.perf_counter()

    scale = 0.5
    if img is None: 
        img = prepare_detection_image(scale)
        
    im = Image.fromarray(img)

    # scale fingerprint search region
    tofind_scaled = tuple(int(v * scale) for v in tofind)

    sub0_ = im.crop(tofind_scaled)

    sub0 = cv2.cvtColor(
    np.array(
        sub0_.resize((
            round(sub0_.size[0] * 0.77),
            round(sub0_.size[1] * 0.77)
        ))
    ),
    cv2.COLOR_BGR2GRAY
)

    found_slots = []
    brightness_map = {}
    templates = []
    has_matches = False

    # first pass → collect brightness
    for idx, part in enumerate(parts, start=1):
        rect = part[0]
        rect_scaled = tuple(int(v * scale) for v in rect)

        template = im.crop(rect_scaled)

        gray_template = cv2.cvtColor(np.array(template), cv2.COLOR_BGR2GRAY)
        brightness = float(np.mean(gray_template))

        brightness_map[idx] = brightness
        templates.append((idx, template, brightness))

    # calculate dynamic baseline
    all_brightness = list(brightness_map.values())
    avg_brightness = np.mean(all_brightness)

    # brightest tiles are usually the selected ones
    brightness_cutoff = avg_brightness * 1.22

    for idx, template, brightness in templates:

        matched = is_in(sub0, template, threshold=threshold)

        if matched:
            has_matches = True

        # reject unusually bright matched tiles
        if brightness > brightness_cutoff:
            template.close()
            continue

        if matched:
            found_slots.append(idx)

        template.close()

    if debug:
        dump_debug_scan_image(
            im,
            found_slots,
            range(1, len(parts) + 1),
            brightness_map,
            scale=scale
        )

    sub0_.close()
    im.close()

    elapsed_ms = (time.perf_counter() - t0) * 1000.0
    # print(elapsed_ms)
    
    if has_matches and not found_slots:
        return 100   # special code for "matches found but all were too bright"

    if not found_slots:
        return 0
    
    ordered = sorted(found_slots)
    return ",".join(str(slot) for slot in ordered)



def main(debug=False):
    """Run fingerprint scan against live capture and return solver payload."""
    result = scan_fingerprint_slots(None, debug=debug)
    return result

if __name__ == "__main__":
    base_dir = os.path.dirname(__file__)
    img_path = os.path.join(base_dir, "zcasinowide.png")

    img = cv2.imread(img_path)
    # BGR -> RGB
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    processed = prepare_detection_image(0.5, img)

    scan_fingerprint_slots(processed, debug=True)