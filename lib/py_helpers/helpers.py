import os
import sys


def runtime_dir():
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(__file__)


def resolve_dump_dir():
    return os.path.abspath(os.path.join(runtime_dir(), "..", "dump"))