import os
import cv2
import time
import sys
import numpy as np
from PIL import ImageGrab, ImageDraw
from helpers import resolve_dump_dir

parts = [[(482, 279, 482 + 102, 279 + 102), (0, 0)],
[(627, 279, 627 + 102, 279 + 102), (1, 0)],
[(482, 423, 482 + 102, 423 + 102), (0, 1)],
[(627, 423, 627 + 102, 423 + 102), (1, 1)],
[(482, 566, 482 + 102, 566 + 102), (0, 2)],
[(627, 566, 627 + 102, 566 + 102), (1, 2)],
[(482, 711, 482 + 102, 711 + 102), (0, 3)],
[(627, 711, 627 + 102, 711 + 102), (1, 3)]]

# Template caches (preloaded at module init)
_ANCHOR_TEMPLATES = {}
_PIECE_TEMPLATES = {}
_TEMPLATES_LOADED = False


def _preload_templates():
    """Preload all anchor and piece templates into memory cache."""
    global _ANCHOR_TEMPLATES, _PIECE_TEMPLATES, _TEMPLATES_LOADED
    
    if _TEMPLATES_LOADED:
        return
    
    # Resolve templates directory based on execution context
    if getattr(sys, 'frozen', False):
        # Running from compiled exe in lib/
        base_dir = os.path.dirname(sys.executable)  # lib/
        templates_dir = os.path.normpath(os.path.join(base_dir, '..', '1920x1080+'))
    else:
        # Running from source
        templates_dir = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..', '1920x1080+'))
    
    # Load anchor templates (1-4.png, 5-8.png, 9-12.png, 13-16.png)
    anchor_files = [
        ('1-4.png', [1, 2, 3, 4]),
        ('5-8.png', [5, 6, 7, 8]),
        ('9-12.png', [9, 10, 11, 12]),
        ('13-16.png', [13, 14, 15, 16]),
    ]
    
    for fname, slots_map in anchor_files:
        path = os.path.join(templates_dir, fname)
        if os.path.exists(path):
            tpl = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
            if tpl is not None:
                _ANCHOR_TEMPLATES[fname] = (tpl, slots_map)
    
    # Load piece templates (1.bmp through 16.bmp)
    for piece_idx in range(1, 17):
        piece_fname = f"{piece_idx}.bmp"
        piece_path = os.path.join(templates_dir, piece_fname)
        
        if os.path.exists(piece_path):
            piece_img = cv2.imread(piece_path, cv2.IMREAD_GRAYSCALE)
            if piece_img is not None:
                _PIECE_TEMPLATES[piece_idx] = piece_img
    
    _TEMPLATES_LOADED = True


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


def scan_fingerprint_slots(bbox, threshold=0.65, debug=False):
    """Helper scan routine used by external callers.

    Returns detected slot indices and elapsed milliseconds.
    """
    _preload_templates()  # Ensure templates are loaded into cache
    
    t0 = time.perf_counter()
    scale = 0.3

    im = ImageGrab.grab(bbox)
    im = im.resize((int(1920 * scale), int(1080 * scale)))
    im_array = np.array(im)
    im_gray = cv2.cvtColor(im_array, cv2.COLOR_BGR2GRAY)
    if debug:
        print(f"[debug] image resized to {im_gray.shape}", file=sys.stderr, flush=True)

    def detect_anchor_group(search_img, anchor_threshold=0.72):
        """Return anchor-matched piece indices for the current frame."""
        scr_h, scr_w = search_img.shape
        x1 = int(0.45 * scr_w)
        y1 = int(0.05 * scr_h)
        x2 = int(0.95 * scr_w)
        y2 = int(0.4 * scr_h)
        if x1 >= x2 or y1 >= y2:
            return None
        region = search_img[y1:y2, x1:x2]

        scale_factor = search_img.shape[1] / 1920.0
        for fname, slots_map in _ANCHOR_TEMPLATES.items():
            tpl, slots = slots_map
            tpl_resized = cv2.resize(tpl, (max(1, round(tpl.shape[1] * scale_factor)), max(1, round(tpl.shape[0] * scale_factor))))
            if tpl_resized.shape[0] > region.shape[0] or tpl_resized.shape[1] > region.shape[1]:
                continue
            res = cv2.matchTemplate(region, tpl_resized, cv2.TM_CCOEFF_NORMED)
            _, max_val, _, _ = cv2.minMaxLoc(res)
            if max_val >= anchor_threshold:
                return slots
        return None

    anchor_slots = detect_anchor_group(im_gray)
    if debug:
        print(f"[debug] anchor_slots={anchor_slots}", file=sys.stderr, flush=True)

    searched_piece_indices = anchor_slots if anchor_slots is not None else list(range(1, len(parts) + 1))

    found_slots = []
    found_pieces = set()
    
    for slot_num, part in enumerate(parts, start=1):
        sx1, sy1, sx2, sy2 = part[0]
        sx1_s = int(sx1 * scale)
        sy1_s = int(sy1 * scale)
        sx2_s = int(sx2 * scale)
        sy2_s = int(sy2 * scale)
        
        slot_region = im_gray[sy1_s:sy2_s, sx1_s:sx2_s]
        slot_region_color = im_array[sy1_s:sy2_s, sx1_s:sx2_s]
        try:
            hsv_v = float(np.mean(cv2.cvtColor(slot_region_color, cv2.COLOR_BGR2HSV)[:, :, 2]))
        except Exception:
            hsv_v = 0.0

        if hsv_v > 55:
            if debug:
                print(f"[debug] skipping slot {slot_num} (already selected) v={hsv_v:.1f}", file=sys.stderr, flush=True)
            continue

        for piece_idx in searched_piece_indices:
            if piece_idx not in _PIECE_TEMPLATES:
                continue
            
            if piece_idx in found_pieces:
                continue
            
            piece_resized = cv2.resize(_PIECE_TEMPLATES[piece_idx], (max(1, int(_PIECE_TEMPLATES[piece_idx].shape[1] * scale)), max(1, int(_PIECE_TEMPLATES[piece_idx].shape[0] * scale))))
            
            if piece_resized.shape[0] > slot_region.shape[0] or piece_resized.shape[1] > slot_region.shape[1]:
                continue
            
            res = cv2.matchTemplate(slot_region, piece_resized, cv2.TM_CCOEFF_NORMED)
            _, max_val, _, _ = cv2.minMaxLoc(res)
            
            if max_val >= threshold:
                found_slots.append(slot_num)
                found_pieces.add(piece_idx)
                if debug:
                    print(f"[debug] piece {piece_idx} matched in slot {slot_num} with score {max_val:.4f}", file=sys.stderr, flush=True)
                break
    
    if debug:
        print(f"[debug] search complete: found {len(found_slots)} slots", file=sys.stderr, flush=True)

    all_slots_list = list(range(1, len(parts) + 1))
    dump_debug_scan_image(im, found_slots, all_slots_list, scale=scale)

    im.close()
    elapsed_ms = (time.perf_counter() - t0) * 1000.0
    if debug:
        print(f"[debug] found_slots={found_slots}", file=sys.stderr, flush=True)
        print(f"[debug] elapsed_ms={elapsed_ms:.1f}ms", file=sys.stderr, flush=True)
    return found_slots, elapsed_ms


def main(bbox, debug=False):
    """Helper-facing entry point that returns sorted detected slots."""

    found_slots, _elapsed_ms = scan_fingerprint_slots(bbox, debug=debug)

    if not found_slots:
        return []

    ordered = sorted(found_slots)
    return ordered