"""Bounded, read-only ADB transport for the selected USB connection."""
from __future__ import annotations

import os
import re
import subprocess
import threading
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Result:
    status: str
    text: str = ""
    code: int | None = None
    duration_ms: int = 0


class DeviceError(ValueError):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


def run_command(argv: list[str], timeout: float, limit: int = 2 * 1024 * 1024) -> Result:
    env = os.environ.copy()
    for key in ("ANDROID_SERIAL", "ADB_SERVER_SOCKET", "ANDROID_ADB_SERVER_PORT", "ANDROID_ADB_SERVER_ADDRESS"):
        env.pop(key, None)
    started = time.monotonic()
    try:
        process = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, shell=False, env=env,
                                   creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    except OSError:
        return Result("unavailable")
    buffers = [bytearray(), bytearray()]
    overflow = threading.Event()

    def drain(stream, output):
        while chunk := stream.read(65536):
            if len(output) + len(chunk) > limit:
                overflow.set()
                try:
                    process.kill()
                except OSError:
                    pass
                break
            output.extend(chunk)

    readers = [threading.Thread(target=drain, args=(stream, buffers[i]), daemon=True)
               for i, stream in enumerate((process.stdout, process.stderr))]
    for reader in readers:
        reader.start()
    status = "complete"
    try:
        process.wait(timeout=max(0.1, timeout))
    except subprocess.TimeoutExpired:
        status = "timeout"
        process.kill()
        process.wait(timeout=5)
    finally:
        for reader in readers:
            reader.join(timeout=5)
        for stream in (process.stdout, process.stderr):
            stream.close()
    if overflow.is_set():
        status = "output-limit"
    elif status == "complete" and process.returncode != 0:
        status = "failed"
    text = buffers[0].decode("utf-8", errors="replace").replace("\r", "") if status == "complete" else ""
    return Result(status, text, process.returncode, round((time.monotonic() - started) * 1000))


def parse_devices(text: str) -> list[dict]:
    devices = []
    for line in text.splitlines():
        if not line.strip() or line.startswith(("List of devices", "*")):
            continue
        fields = line.split()
        if len(fields) < 2 or not re.fullmatch(r"[A-Za-z0-9_.:-]+", fields[0]):
            raise ValueError("Unrecognized ADB device list.")
        metadata = dict(field.split(":", 1) for field in fields[2:] if ":" in field)
        devices.append({"serial": fields[0], "state": fields[1], "transport": metadata.get("transport_id")})
    return devices


COMMANDS = {
    "model": ("getprop", "ro.product.model"),
    "manufacturer": ("getprop", "ro.product.manufacturer"),
    "android": ("getprop", "ro.build.version.release"),
    "sdk": ("getprop", "ro.build.version.sdk"),
    "patch": ("getprop", "ro.build.version.security_patch"),
    "fingerprint": ("getprop", "ro.build.fingerprint"),
    "boot": ("getprop", "sys.boot_completed"),
    "user": ("am", "get-current-user"),
    "memory": ("cat", "/proc/meminfo"),
    "uptime": ("cat", "/proc/uptime"),
    "battery": ("dumpsys", "battery"),
    "storage": ("df", "-k", "/data"),
    "cpu": ("dumpsys", "cpuinfo"),
    "thermal": ("dumpsys", "thermalservice"),
    "diskstats": ("dumpsys", "diskstats"),
}


class AdbClient:
    def __init__(self, executable: str, runner=run_command, seconds: int = 120):
        path = Path(executable)
        valid_name = path.name.lower() == "adb.exe" if os.name == "nt" else path.stem.lower() == "adb"
        if not path.is_absolute() or not path.is_file() or not valid_name:
            raise ValueError("Supply the absolute path to adb from Google's SDK Platform Tools.")
        self.base = [str(path.resolve()), "-P", "5037"]
        self.runner = runner
        self.deadline = time.monotonic() + seconds
        self.transport = None
        self.serial = None
        self.unique_usb_required = False

    def _run(self, args: list[str]) -> Result:
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            return Result("budget-exhausted")
        return self.runner(self.base + args, min(15, remaining))

    def devices(self) -> list[dict]:
        result = self._run(["devices", "-l"])
        if result.status != "complete":
            raise ValueError("ADB device discovery failed. Check the local SDK Platform Tools installation.")
        return parse_devices(result.text)

    def select(self, serial: str):
        self.transport = None
        self.serial = None
        self.unique_usb_required = False
        if not re.fullmatch(r"[A-Za-z0-9_.-]{1,128}", serial) or serial.startswith("emulator-"):
            raise ValueError("Choose an exact USB serial, not a network address or emulator.")
        matches = [device for device in self.devices() if device["serial"] == serial]
        if not matches:
            raise DeviceError("device-absent", "The selected phone is absent. Reconnect its USB cable and list devices again.")
        if len(matches) != 1:
            raise DeviceError("device-ambiguous", "The selected serial appears more than once. Disconnect the duplicate transport before continuing.")
        state = matches[0]["state"]
        if state == "unauthorized":
            raise DeviceError("device-unauthorized", "Unlock the selected phone and approve its USB debugging prompt, then check again.")
        if state != "device":
            raise DeviceError("device-offline", "The selected phone is offline or unavailable. Check the cable and phone; no other device was selected.")
        transport = matches[0]["transport"]
        if not transport or not re.fullmatch(r"[1-9][0-9]*", transport):
            raise ValueError("ADB did not provide a transport ID. Update SDK Platform Tools.")
        usb = self._run(["-t", transport, "get-devpath"])
        unique_usb_required = False
        if usb.status == "complete" and usb.text.strip() == "unknown":
            unique_usb_required = True
            unique = self._run(["-d", "get-serialno"])
            if unique.status != "complete" or unique.text.strip() != serial:
                raise ValueError("This ADB backend requires exactly one USB phone matching the selected serial. Review the connected USB devices.")
        elif usb.status != "complete" or not usb.text.strip().startswith("usb:"):
            raise ValueError("The selected transport is not verified as USB. Wireless devices are unsupported.")
        self.transport = transport
        self.serial = serial
        self.unique_usb_required = unique_usb_required

    def readiness(self, serial=None):
        devices = self.devices()
        result = {"kind": "syrin-android-readiness", "ready": False, "devices": devices}
        if not serial:
            code = "no-devices" if not devices else "select-device"
            message = "Connect a phone with a USB data cable and enable USB debugging." if not devices else "Choose an exact serial from this list, then run the readiness check again with --serial."
            return {**result, "code": code, "message": message}
        try:
            self.select(serial)
        except DeviceError as error:
            return {**result, "code": error.code, "message": str(error)}
        except ValueError as error:
            return {**result, "code": "usb-unverified", "message": str(error)}
        user = self.read("user")
        boot = self.read("boot")
        if user.status != "complete" or not user.text.strip().isdigit() or boot.status != "complete" or boot.text.strip() != "1":
            return {**result, "code": "phone-not-ready", "message": "Wait until the phone has finished booting and unlock it, then check again."}
        return {**result, "ready": True, "code": "ready", "message": "The selected USB phone is ready for read-only diagnostics.", "userId": int(user.text.strip())}

    def read(self, name: str, *, user: int | None = None, package: str | None = None) -> Result:
        if self.transport is None:
            raise ValueError("Select an authorized USB device first.")
        if name in COMMANDS:
            command = list(COMMANDS[name])
        elif name in ("packages", "systemPackages", "disabledPackages"):
            if type(user) is not int or not 0 <= user <= 2147483647:
                raise ValueError("A verified Android user ID is required.")
            flags = {"packages": [], "systemPackages": ["-s"], "disabledPackages": ["-d"]}
            command = ["pm", "list", "packages", "--user", str(user)] + flags[name]
        elif name == "frames":
            if not package or not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+", package):
                raise ValueError("Use an exact Android package name for frame diagnostics.")
            command = ["dumpsys", "gfxinfo", package]
        else:
            raise ValueError("Unsupported read-only Android collector.")
        state = self._run(["-t", self.transport, "get-state"])
        if state.status != "complete":
            return state
        if state.text.strip() != "device":
            return Result("disconnected")
        serial = self._run(["-t", self.transport, "get-serialno"])
        if serial.status != "complete" or serial.text.strip() != self.serial:
            return Result("identity-changed")
        if self.unique_usb_required:
            unique = self._run(["-d", "get-serialno"])
            if unique.status != "complete" or unique.text.strip() != self.serial:
                return Result("unverified-usb")
        return self._run(["-t", self.transport, "shell"] + command)
