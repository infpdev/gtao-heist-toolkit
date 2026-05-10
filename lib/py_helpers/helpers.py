import os
import sys
import numpy as np
from PIL import ImageGrab, Image, ImageDraw
import cv2

def runtime_dir():
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(__file__)


def resolve_dump_dir():
    return os.path.abspath(os.path.join(runtime_dir(), "..", "dump"))

def prepare_detection_image(scale=1.0, img=None):

    if img is None:
        img = np.array(ImageGrab.grab())

    h, w = img.shape[:2]
    aspect = w / h

    # ultrawide -> crop centered 16:9 region
    if aspect > 2.0:
        target_w = int(h * (16 / 9))

        x1 = (w - target_w) // 2
        x2 = x1 + target_w

        img = img[:, x1:x2]

    # normalize to virtual 1920x1080
    img = cv2.resize(
        img,
        (
            int(1920 * scale),
            int(1080 * scale)
        )
    )

    return img

def _dump_debug_image(search_img: np.ndarray, debug_regions) -> None:
    if search_img is None:
        return
    
    output_path = os.path.join(resolve_dump_dir(), "anchorDebug.png")

    if len(search_img.shape) == 2:
        canvas = Image.fromarray(search_img.astype(np.uint8), mode='L').convert('RGB')
    else:
        canvas = Image.fromarray(search_img.astype(np.uint8), mode='RGB')

    draw = ImageDraw.Draw(canvas)
    for label, region, color in debug_regions:
        x1, y1, x2, y2 = [int(v) for v in region]
        draw.rectangle((x1, y1, x2, y2), outline=color, width=2)
        draw.text((x1 + 4, max(0, y1 - 12)), label, fill=color)

    canvas.save(output_path)