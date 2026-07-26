import json
import os
import sys
import traceback
import faulthandler
import threading
import time
from random import choice
from enum import Enum, auto
from pypresence import Presence


crash_log_path = os.path.join(os.getcwd(), "zCrash.log")

last_heartbeat = time.monotonic()
busy = False
CLIENT_ID = "1530071672957440051"
presence = None

def touch_heartbeat():
    global last_heartbeat
    last_heartbeat = time.monotonic()

# Watchdog thread to monitor the heartbeat and exit if no heartbeat is received for 5 seconds
def watchdog_loop():
    while True:
        time.sleep(1)

        if busy:
            continue

        if time.monotonic() - last_heartbeat > 5:
            os._exit(0)


threading.Thread(target=watchdog_loop, daemon=True).start()

def write_crash_log(message):
    try:
        with open(crash_log_path, "a", encoding="utf-8") as log_file:
            log_file.write(message)
            if not message.endswith("\n"):
                log_file.write("\n")
    except Exception:
        pass


def log_exception(exc_type, exc_value, exc_tb):
    write_crash_log("".join(traceback.format_exception(exc_type, exc_value, exc_tb)))


try:
    faulthandler.enable(all_threads=True)
except Exception:
    pass

sys.excepthook = log_exception

##############################################
# IPC Request Handling
##############################################


def handle_request(request_type_str):
    """Handles incoming IPC requests from the AHK script."""
    try:

        if request_type_str == "HEARTBEAT":
            touch_heartbeat()
            return "OK"

        touch_heartbeat()

        try:
            request_type = RequestType[request_type_str]
        except KeyError:
            return f"ERR(InvalidRequestType): {request_type_str}"

        handle_presence_request(request_type)

        return "OK"

    except Exception:
        write_crash_log("REQUEST: " + json.dumps(request_type_str, default=str, ensure_ascii=True))
        write_crash_log(traceback.format_exc())
        return "ERR(Exception)"

def run():
    """Main loop to read requests from stdin and handle them.
    Exits the loop if a request of type 'STOP' is received.
    """
    global busy
    while True:
        try:
            line = sys.stdin.readline()

            if not line:
                continue

            line = line.strip()

            if not line:
                continue

            busy = True
            
            try:
                data = json.loads(line)
            except Exception:
                write_crash_log("BAD_JSON: " + line)
                sys.stdout.write("ERR(BadJson)\n")
                sys.stdout.flush()
                continue
            
            request_type_str = data.get("request_type")
            
            if(request_type_str == "STOP"):
                presence.destroy() if presence else None
                break

            response = handle_request(request_type_str)

            sys.stdout.write(response + "\n")
            sys.stdout.flush()

        except Exception:
            write_crash_log("RUN_LOOP:\n" + traceback.format_exc())
        finally:
            busy = False

##############################################
# Presence Handling
##############################################

class RequestType(Enum):
    DISABLE = auto()
    CLEAR = auto()
    IDLE = auto()
    NO_SAVE = auto()
    FINGERPRINT = auto()
    KEYPAD = auto()
    CAYO_FINGERPRINT = auto()
    LEDGE_GRAB = auto()

def handle_presence_request(request_type: RequestType):
    """Handles presence requests based on the request type.
    Calls the appropriate method in the VaultOpsPresence class to update the Discord rich presence.
    Args:
        request_type (RequestType): The type of presence request to handle.
    """
    global presence
    
    if request_type == RequestType.DISABLE:
        destroy_presence()
        return

    if presence is None:
        presence = VaultOpsPresence()

    presence.handle_presence_request(request_type)

def destroy_presence():
    """Destroys the current presence instance, if it exists."""
    global presence
    if presence is not None:
        presence.destroy()
        presence = None
    
class VaultOpsPresence:
    global CLIENT_ID

    def __init__(self):
        self.rpc = Presence(CLIENT_ID)
        self.rpc.connect()

    def destroy(self):
        try:
            self.rpc.clear()
        finally:
            self.rpc.close()

    def clear(self):
        self.rpc.clear()
        
    
    def _update(self, large_image=None, large_text=None, **kwargs):
        self.rpc.update(
            large_image=large_image if large_image else "vaultops",
            large_text=large_text if large_text else "VaultOps",
            **kwargs,
        )

    def handle_presence_request(self, request_type: RequestType):
        """Handles the presence request based on the request type.
        Args:
            request_type (RequestType): The type of presence request to handle.
        """
            
        handlers = {
            RequestType.CLEAR: self.clear,
            RequestType.NO_SAVE: self.show_no_save_presence,
            RequestType.FINGERPRINT: self.show_fingerprint_presence,
            RequestType.KEYPAD: self.show_keypad_presence,
            RequestType.CAYO_FINGERPRINT: self.show_cayo_fingerprint_presence,
            RequestType.LEDGE_GRAB: self.show_ledge_grab_presence,
            RequestType.IDLE: self.show_idle_presence,
        }

        handlers[request_type]()
        
    def show_idle_presence(self):
        IDLE_STATES = (
            "Waiting for security to slip up",
            "Pretending to belong here",
            "Looking busy until payday",
            "Trying not to look suspicious",
            "One bad decision away from a fortune",
            "Waiting for the perfect opportunity",
            "The vault won't rob itself",
            "The cameras definitely saw nothing",
            "Security seems a little too relaxed",
            "Just another day at the office",
            "Waiting for the coast to clear",
            "Patiently casing the place",
            "Trying to blend in with the staff",
            "Looking for something expensive",
            "Waiting for someone else's mistake",
            "The guards seem underpaid",
            "Definitely here for legitimate business",
            "The loot is calling",
            "Keeping a low profile",
            "Waiting for the fun to begin",
            "The plan is somehow still working",
            "Just one step ahead of security",
            "Trying not to make eye contact",
            "Waiting for the alarm to stay silent",
            "The vault is getting nervous",
            "Nothing suspicious happening here",
            "Making security earn their paycheck",
            "Professional visitor",
            "Waiting for the stars to align",
            "Scouting the next payday",
            "The getaway vehicle is hopefully nearby",
            "Looking for highly liquid assets",
            "The insurance company won't like this",
            "About to create paperwork",
            "Casually borrowing valuables",
            "Rockstar probably wouldn't approve",
            "The accountants are about to panic",
            "The loot has already accepted its fate",
            "One more successful 'inspection'",
            "Just here for the complimentary valuables",
        )

        self._update(
            details="Following the money",
            state=choice(IDLE_STATES),
            large_image="gta_online",
            large_text="GTA V",
            small_image="vaultops",
            small_text="Idle",
        )
            
    def show_no_save_presence(self):
        NO_SAVE_STATES = (
            "One more run won't hurt",
            "Running it back",
            "The host isn't done yet",
            "Just one last payout...",
            "Preparing for another finale",
            "Turning finales into traditions",
            "Milking this heist a little longer",
            "The planning board disagrees",
            "Making every finale count",
            "Replaying like it's the first time",
            "Still getting paid somehow",
            "The vault keeps reopening",
            "The accountant looks concerned",
            "Rockstar's ledger is confused",
            "Infinite optimism. Finite setups",
        )

        self._update(
            details="Using NoSave",
            state=choice(NO_SAVE_STATES),
            small_image="nosave",
            small_text="NoSave",
        )     

    def show_keypad_presence(self):
        KEYPAD_STATES = (
            "Trusting short-term memory",
            "Blink... blink... remember",
            "Watching dots like a hawk",
            "One pattern at a time",
            "Memorizing at light speed",
            "Hopefully I wasn't blinking",
            "The dots know the answer",
            "Training my photographic memory",
            "Remember first, panic later",
            "Turning flashes into passwords",
            "Playing Simon Says",
            "Brain.exe is working overtime",
            "Please don't add another column",
            "The pattern looked easier a second ago",
            "Staring respectfully at blinking lights",
        )

        self._update(
            details="Solving a Keypad",
            state=choice(KEYPAD_STATES),

            small_image="solver",
            small_text="Keypad Solver",
        )
        
    def show_fingerprint_presence(self):
        FINGERPRINT_STATES = (
            "The vault won't open itself",
            "One scan closer to the loot",
            "Just borrowing someone's identity",
            "Access denied? Not for long",
            "These doors have trust issues",
            "Looking for a convincing fingerprint",
            "Security is merely a suggestion",
            "The scanner seems convinced",
            "The door is being difficult",
            "One fingerprint away from payday",
            "The vault's almost feeling generous",
            "Getting past 'Authorized Personnel Only'",
            "Someone left their fingerprints behind",
            "Opening doors the expensive way",
            "Identity theft, but for a good cause",
        )

        self._update(
            details="Solving Fingerprints",
            state=choice(FINGERPRINT_STATES),

            small_image="solver",
            small_text="Fingerprint Solver",
        )
        
    def show_cayo_fingerprint_presence(self):
        CAYO_FINGERPRINT_STATES = (
            "Rubio's security is trying its best",
            "El Rubio is funding another vacation",
            "The panther isn't the only thing getting stolen",
            "Just another day in Rubio's office",
            "Rubio really needs better security",
            "Taking another peek at Rubio's files",
            "The office is almost open",
            "Rubio left the scanner on",
            "Helping Rubio redistribute his wealth",
            "The gatekeeper is feeling generous",
            "Another fingerprint, another payday",
            "Rubio keeps making this too easy",
            "Borrowing access to borrow valuables",
            "Juan's gonna love this haul",
        )

        self._update(
            details="Aligning Rubio's Fingerprints",
            state=choice(CAYO_FINGERPRINT_STATES),

            small_image="solver",
            small_text="El Rubio Fingerprint Solver",
        )

    def show_ledge_grab_presence(self):
        LEDGE_GRAB_STATES = (
            "Phone out. Cover up",
            "Walls are optional",
            "Physics is negotiable",
            "Teleport pending",
        )

        self._update(
            details="Buffered Ledge Grab",
            state=choice(LEDGE_GRAB_STATES),

            small_image="ledge_grab",
            small_text="Buffered Ledge Grab",
        )
        
# if __name__ == "__main__":
#     # Debugging purposes only. Uncomment to test the presence functionality.

#     # handle_presence_request(RequestType.FINGERPRINT)
#     # handle_presence_request(RequestType.KEYPAD)
#     # handle_presence_request(RequestType.CAYO_FINGERPRINT)
#     handle_presence_request(RequestType.LEDGE_GRAB)

#     input("Presence is active. Press Enter to quit...")
#     presence.destroy()


if __name__ == "__main__":
    run()