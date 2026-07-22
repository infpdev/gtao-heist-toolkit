import os
import sys
import numpy as np
from PIL import ImageGrab, Image, ImageDraw
import cv2
# import win32gui
# import win32ui
# import ctypes

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
    
def is_black_area_present_ledge_grab(search_img: np.ndarray = None, scale: float = 0.5) -> bool:

    if search_img is None:
        search_img = prepare_detection_image(scale)

    h, w = search_img.shape[:2]

    x1 = int(w * 0.35)
    y1 = int(h * 0.35)
    x2 = int(w * 0.65)
    y2 = int(h * 0.65)

    roi = search_img[y1:y2, x1:x2]

    # Must be very dark
    if np.mean(roi) > 15:
        return False

    # Must be essentially a single color
    return np.max(roi) - np.min(roi) < 3


# Set this once to your target app's window title (or a substring of it).
# TARGET_WINDOW_TITLE = "Grand Theft Auto V"

# def capture_window(window_title_substring):
#     """Capture only the specified app window's contents, bypassing any
#     overlapping windows (like an AHK tooltip) since those are separate
#     top-level windows and are never drawn into this capture. Returns an
#     RGB numpy array (matching ImageGrab.grab()'s channel order), or None
#     if the window wasn't found or capture failed."""

#     hwnd = None
#     def enum_handler(h, _):
#         nonlocal hwnd
#         if win32gui.IsWindowVisible(h) and window_title_substring.lower() in win32gui.GetWindowText(h).lower():
#             hwnd = h
#     win32gui.EnumWindows(enum_handler, None)

#     if hwnd is None:
#         return None

#     left, top, right, bottom = win32gui.GetClientRect(hwnd)
#     left, top = win32gui.ClientToScreen(hwnd, (left, top))
#     right, bottom = win32gui.ClientToScreen(hwnd, (right, bottom))
#     width = right - left
#     height = bottom - top

#     if width <= 0 or height <= 0:
#         return None

#     hwnd_dc = win32gui.GetWindowDC(hwnd)
#     mfc_dc = win32ui.CreateDCFromHandle(hwnd_dc)
#     save_dc = mfc_dc.CreateCompatibleDC()

#     save_bitmap = win32ui.CreateBitmap()
#     save_bitmap.CreateCompatibleBitmap(mfc_dc, width, height)
#     save_dc.SelectObject(save_bitmap)

#     result = ctypes.windll.user32.PrintWindow(hwnd, save_dc.GetSafeHdc(), 2)

#     bmp_info = save_bitmap.GetInfo()
#     bmp_str = save_bitmap.GetBitmapBits(True)

#     img = np.frombuffer(bmp_str, dtype=np.uint8)
#     img.shape = (bmp_info["bmHeight"], bmp_info["bmWidth"], 4)  # BGRA

#     win32gui.DeleteObject(save_bitmap.GetHandle())
#     save_dc.DeleteDC()
#     mfc_dc.DeleteDC()
#     win32gui.ReleaseDC(hwnd, hwnd_dc)

#     if not result:
#         return None

#     # RGB, not BGR -- matches ImageGrab.grab()'s channel order, which is
#     # what the rest of the pipeline (prepare_detection_image, detection,
#     # and display) assumes.
#     return cv2.cvtColor(img, cv2.COLOR_BGRA2RGB)

def prepare_image(image=None, scale: float = 0.5, debug: bool = False):
    """Normalize input frame into RGB numpy array at requested scale."""
    if image is None:
        # Capture only the target app window (tooltip-free) instead of the
        # full screen. Falls back to the old full-screen pipeline if the
        # window capture fails for any reason (window closed/minimized/etc).
        # if not debug:
        #     image = capture_window(TARGET_WINDOW_TITLE)
        if image is None:
            image = prepare_detection_image(scale)
        else:
            image = prepare_detection_image(scale, image)
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