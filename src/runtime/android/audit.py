"""Android USB audit. Device commands are read-only; output remains on the host."""
from __future__ import annotations

import sys

if sys.version_info < (3, 10):
    print('{"ok": false, "error": "Python 3.10+ is required."}')
    sys.exit(2)

import argparse
import hashlib
import json
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

from adbclient import AdbClient
import model


def utc():
    return datetime.now(timezone.utc).isoformat()


def collect(client, *, session_id, include_packages=False, include_thermal=False, include_app_sizes=False, package=None, frame_window_seconds=0, context_label="", sleeper=time.sleep):
    if len(context_label) > 240 or any(ord(char) < 32 for char in context_label):
        raise ValueError("The workload description must be one line of at most 240 characters.")
    if frame_window_seconds != 0 and not 2 <= frame_window_seconds <= 30:
        raise ValueError("The frame sampling window must be 0 or between 2 and 30 seconds.")
    if frame_window_seconds != 0 and not package:
        raise ValueError("A --package name is required when --frame-window-seconds is set.")
    started = time.monotonic()
    collectors = {}

    def value(name):
        result = client.read(name)
        if result.status != "complete" or not result.text.strip() or len(result.text.strip()) > 512:
            raise ValueError("Required Android identity or readiness field unavailable: " + name)
        return result.text.strip()

    fingerprint = value("fingerprint")
    user = value("user")
    if not user.isdigit() or not 0 <= int(user) <= 2147483647 or value("boot") != "1":
        raise ValueError("The phone is not fully booted or its active user could not be verified.")
    system = {"model": value("model"), "manufacturer": value("manufacturer"), "android": value("android"), "sdk": value("sdk"), "securityPatch": value("patch"), "userId": int(user)}
    collectors["system"] = {"status": "complete", "data": [system], "errors": [], "durationMs": 0}
    base_collectors = [("memory", model.memory), ("battery", model.battery), ("storage", model.storage), ("cpu", model.cpu)]
    if include_thermal:
        base_collectors.append(("thermal", model.thermal))
    for name, parser in base_collectors:
        result = client.read(name)
        row = {"status": "unavailable", "data": [], "errors": [], "durationMs": result.duration_ms, "source": "adb:" + name}
        if result.status == "complete":
            try:
                row.update(status="complete", data=[parser(result.text)])
            except ValueError:
                row["errors"] = ["Unsupported or incomplete Android output; no value inferred."]
        else:
            row["errors"] = ["ADB collector " + result.status + "."]
        collectors[name] = row
    uptime = client.read("uptime")
    try:
        uptime_seconds = float(uptime.text.split()[0]) if uptime.status == "complete" else None
        if uptime_seconds is not None and not 0 <= uptime_seconds < 1e12:
            uptime_seconds = None
    except (ValueError, IndexError):
        uptime_seconds = None
    if include_packages:
        sets = {}
        try:
            for name in ("packages", "systemPackages", "disabledPackages"):
                result = client.read(name, user=int(user))
                if result.status != "complete":
                    raise ValueError("Package inventory unavailable.")
                sets[name] = model.packages(result.text)
            if not sets["packages"] or not set(sets["systemPackages"]) <= set(sets["packages"]) or not set(sets["disabledPackages"]) <= set(sets["packages"]):
                raise ValueError("Package inventory changed or is incomplete.")
            rows = [{"package": name, "system": name in sets["systemPackages"], "disabled": name in sets["disabledPackages"], "recommendation": "review-only"} for name in sets["packages"]]
            collectors["packages"] = {"status": "complete", "data": rows, "errors": []}
        except ValueError:
            collectors["packages"] = {"status": "unavailable", "data": [], "errors": ["Package inventory incomplete; no removal recommendation is generated."]}
    if include_app_sizes:
        disk_result = client.read("diskstats")
        if disk_result.status == "complete":
            try:
                collectors["appSizes"] = {"status": "complete", "data": model.app_storage(disk_result.text), "errors": [], "durationMs": disk_result.duration_ms, "source": "adb:diskstats"}
            except ValueError:
                collectors["appSizes"] = {"status": "unavailable", "data": [], "errors": ["Per-app storage counters unavailable or unsupported on this OEM build."], "durationMs": disk_result.duration_ms, "source": "adb:diskstats"}
        else:
            collectors["appSizes"] = {"status": "unavailable", "data": [], "errors": ["ADB collector " + disk_result.status + "."], "durationMs": disk_result.duration_ms, "source": "adb:diskstats"}
    if package:
        frame_started = utc()
        first_read = client.read("frames", package=package)
        try:
            if first_read.status != "complete":
                raise ValueError("Frame query failed.")
            first_counters = model.frames(first_read.text)
            if first_counters["observedPackage"] and first_counters["observedPackage"] != package:
                raise ValueError("Frame output identifies another app.")
            errors = []
            if frame_window_seconds >= 2:
                sleeper(frame_window_seconds)
                second_read = client.read("frames", package=package)
                if second_read.status != "complete":
                    raise ValueError("Second frame snapshot failed.")
                second_counters = model.frames(second_read.text)
                if second_counters["observedPackage"] and second_counters["observedPackage"] != package:
                    raise ValueError("Frame output identifies another app.")
                counters = model.frame_window(first_counters, second_counters, frame_window_seconds)
                complete = counters["windowOriginVerified"] and counters["sufficientWindowFrames"]
                if not counters["windowOriginVerified"]:
                    errors.append("App process or frame counter reset during the sampling window; interval delta is unavailable.")
                elif not counters["sufficientWindowFrames"]:
                    errors.append("Too few frames rendered during the sampling window; repeat while actively interacting with the app.")
            else:
                counters = first_counters
                complete = counters["sufficientFrames"] and counters["counterWindowIdentified"]
                if not counters["sufficientFrames"]:
                    errors.append("Too few frames to interpret; use the app normally and collect again.")
                if not counters["counterWindowIdentified"]:
                    errors.append("A single app process and counter start could not be identified; no interval comparison is supported.")
            collectors["frames"] = {"status": "complete" if complete else "partial", "data": [{"package": package, **counters, "contextLabel": context_label, "captureStartedUtc": frame_started, "captureFinishedUtc": utc()}], "errors": errors}
        except ValueError:
            collectors["frames"] = {"status": "unavailable", "data": [], "errors": ["Frame counters unavailable."]}
    # A transport/user change invalidates the whole snapshot, including earlier partial measurements.
    if value("fingerprint") != fingerprint or value("user") != user or value("boot") != "1":
        raise ValueError("Device identity or active user changed during collection. Start a new audit.")
    machine = hashlib.sha256(("syrin-android-v1\0" + client.serial + "\0" + fingerprint + "\0" + user).encode()).hexdigest()
    return {"schemaVersion": 1, "kind": "syrin-audit", "meta": {"sessionId": session_id, "generatedUtc": utc(), "machineId": machine, "systemDrive": None, "platform": "android", "reportMode": "simple", "scope": "health", "readOnly": True, "uptimeSeconds": uptime_seconds, "warnings": [], "warningCodes": ["android-read-only", "support-unverified"], "durationMs": round((time.monotonic() - started) * 1000)}, "collectors": collectors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", required=True)
    parser.add_argument("--serial")
    parser.add_argument("--list-devices", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--out")
    parser.add_argument("--include-packages", action="store_true")
    parser.add_argument("--include-thermal", action="store_true")
    parser.add_argument("--include-app-sizes", action="store_true")
    parser.add_argument("--package")
    parser.add_argument("--frame-window-seconds", type=int, default=0)
    parser.add_argument("--context-label", default="")
    parser.add_argument("--seconds", type=int, default=120, choices=range(30, 301), metavar="30..300")
    args = parser.parse_args()
    client = AdbClient(args.adb, seconds=args.seconds)
    if args.check:
        print(json.dumps({"ok": True, **client.readiness(args.serial)}))
        return 0
    if args.list_devices:
        print(json.dumps({"ok": True, "devices": client.devices()}))
        return 0
    if not args.serial or not args.out:
        parser.error("An exact --serial and a new --out directory are required.")
    folder = Path(args.out)
    if not folder.is_absolute() or folder.exists():
        raise ValueError("Choose a new absolute output directory. Existing audit evidence is never overwritten.")
    client.select(args.serial)
    session_id = uuid.uuid4().hex
    audit = collect(
        client,
        session_id=session_id,
        include_packages=args.include_packages,
        include_thermal=args.include_thermal,
        include_app_sizes=args.include_app_sizes,
        package=args.package,
        frame_window_seconds=args.frame_window_seconds,
        context_label=args.context_label,
    )
    folder.mkdir(parents=True, exist_ok=False)
    temporary = folder / "audit.json.tmp"
    temporary.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(folder / "audit.json")
    print(json.dumps({"ok": True, "outDir": str(folder), "sessionId": session_id, "incomplete": [name for name, row in audit["collectors"].items() if row["status"] != "complete"], "deviceChanged": False}))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError) as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        sys.exit(2)
