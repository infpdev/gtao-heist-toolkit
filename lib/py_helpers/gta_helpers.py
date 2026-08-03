import os
from time import monotonic

import win32api
import win32con
import win32gui
import win32process

GTA_HWND = None
GTA_NAME = None
GTA_LAST_REFRESH = 0.0

TARGET_EXES = {
    "GTA5_Enhanced.exe": "enhanced",
    "GTA5_Enhanced": "enhanced",
    "GTA5.exe": "legacy",
}


def invalidate_gta_cache():
    global GTA_HWND, GTA_NAME, GTA_LAST_REFRESH
    GTA_HWND = None
    GTA_NAME = None
    GTA_LAST_REFRESH = 0.0


def get_gta():
    """Returns (hwnd, game_type), where game_type is 'enhanced', 'legacy', or None."""
    global GTA_HWND, GTA_NAME

    if monotonic() - GTA_LAST_REFRESH > 60:  # Refresh the cache every 60 seconds
        invalidate_gta_cache()

    # Check if the cached window handle is still valid
    if GTA_HWND and win32gui.IsWindow(GTA_HWND) and win32gui.IsWindowVisible(GTA_HWND):
        return GTA_HWND, GTA_NAME

    GTA_HWND = None
    GTA_NAME = None

    def enum_handler(h, _):
        global GTA_HWND, GTA_NAME, GTA_LAST_REFRESH

        if GTA_HWND:
            return

        if not win32gui.IsWindowVisible(h):
            return

        try:
            _, pid = win32process.GetWindowThreadProcessId(h)
            hproc = win32api.OpenProcess(
                win32con.PROCESS_QUERY_LIMITED_INFORMATION,
                False,
                pid,
            )

            try:
                exe = os.path.basename(win32process.GetModuleFileNameEx(hproc, 0))
            finally:
                win32api.CloseHandle(hproc)

            if exe in TARGET_EXES:
                GTA_HWND = h
                GTA_NAME = TARGET_EXES[exe]
                GTA_LAST_REFRESH = monotonic()

        except Exception as e:  # noqa: BLE001
            write_debug_log(f"get_gta() enum_handler exception: {e}")

    win32gui.EnumWindows(enum_handler, None)
    # write_debug_log(f"get_gta() -> {GTA_HWND}, {GTA_NAME}") # Debugging line, uncomment if needed
    return GTA_HWND, GTA_NAME


debug_log_path = os.path.join(os.getcwd(), "zDebug.log")


def write_debug_log(message):
    try:
        with open(debug_log_path, "a", encoding="utf-8") as log_file:
            log_file.write(f"[DEBUG] {message}")
            if not message.endswith("\n"):
                log_file.write("\n")
    except Exception:  # noqa: BLE001, S110
        pass


crash_log_path = os.path.join(os.getcwd(), "zCrash.log")


def write_crash_log(message):
    try:
        with open(crash_log_path, "a", encoding="utf-8") as log_file:
            log_file.write(message)
            if not message.endswith("\n"):
                log_file.write("\n")
    except Exception:  # noqa: BLE001, S110
        pass
