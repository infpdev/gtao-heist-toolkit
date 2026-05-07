import os

import cv2
import time
import numpy as np
from PIL import ImageGrab, ImageDraw
from helpers import resolve_dump_dir

tofind = (950, 155, 1335, 685)

parts = [[(482, 279, 482 + 102, 279 + 102), (0, 0)],
[(627, 279, 627 + 102, 279 + 102), (1, 0)],
[(482, 423, 482 + 102, 423 + 102), (0, 1)],
[(627, 423, 627 + 102, 423 + 102), (1, 1)],
[(482, 566, 482 + 102, 566 + 102), (0, 2)],
[(627, 566, 627 + 102, 566 + 102), (1, 2)],
[(482, 711, 482 + 102, 711 + 102), (0, 3)],
[(627, 711, 627 + 102, 711 + 102), (1, 3)]]


def dump_debug_scan_image(image, found_slots, searched_slots, scale=0.5):
    """Helper debug renderer for slot detection results.

    Saves an annotated scan image that highlights searched slots and matched slots.
    """
    
    output_path = os.path.join(resolve_dump_dir(), "debug.png")

    debug_image = image.copy()
    draw = ImageDraw.Draw(debug_image)
    found_set = set(found_slots)
    searched_set = set(searched_slots)

    for idx, part in enumerate(parts, start=1):
        if idx not in searched_set:
            continue
        
        box = part[0]
        box_scaled = tuple(int(c * scale) for c in box)
        color = "lime" if idx in found_set else "red"
        draw.rectangle(box_scaled, outline=color, width=2)
        label_x = box_scaled[0] + 3
        label_y = box_scaled[1] + 3
        draw.text((label_x, label_y), str(idx), fill=color)

    debug_image.save(output_path)
    debug_image.close()




def is_in(img, subimg, threshold=0.65):
    """Optimized template matching with early exit using minMaxLoc"""
    subimg_gray = cv2.cvtColor(np.array(subimg), cv2.COLOR_BGR2GRAY)
    res = cv2.matchTemplate(img, subimg_gray, cv2.TM_CCOEFF_NORMED)
    
    # Use minMaxLoc for faster single-match detection
    _, max_val, _, _ = cv2.minMaxLoc(res)
    return max_val >= threshold


def scan_fingerprint_slots(bbox=None, threshold=0.65, debug=False):
    """Helper scan routine used by CasinoFingerprint.ahk.

    Returns detected slot indices and elapsed milliseconds.
    """
    t0 = time.perf_counter()

    scale = 0.5

    if bbox:
        im = ImageGrab.grab(bbox)
    else:
        im = ImageGrab.grab()

    # scale whole image once
    im = im.resize((
        int(1920 * scale),
        int(1080 * scale)
    ))

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

    for idx, part in enumerate(parts, start=1):
        rect = part[0]

        rect_scaled = tuple(int(v * scale) for v in rect)

        template = im.crop(rect_scaled)

        if is_in(sub0, template, threshold=threshold):
            found_slots.append(idx)

        template.close()

    if debug:
        dump_debug_scan_image(
            im,
            found_slots,
            range(1, len(parts) + 1),
            scale=scale
        )

    sub0_.close()
    im.close()

    elapsed_ms = (time.perf_counter() - t0) * 1000.0
    # print(elapsed_ms)

    if not found_slots:
        return 0
    
    ordered = sorted(found_slots)
    return ",".join(str(slot) for slot in ordered)



def main(bbox, debug=False):
    """Helper-facing entry point that returns sorted detected slots."""
    result = scan_fingerprint_slots(bbox, debug=debug)
    return result

if __name__ == "__main__":
    main(None, False)