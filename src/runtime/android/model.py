"""Parse measured values without turning missing data into healthy zeroes."""
import json
import re

PACKAGE_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)*$")
THERMAL_STATES = {
    0: "none",
    1: "light",
    2: "moderate",
    3: "severe",
    4: "critical",
    5: "emergency",
    6: "shutdown",
}


def memory(text):
    values = {key: int(value) * 1024 for key, value in re.findall(r"^(\w+):\s+(\d+)\s+kB\s*$", text, re.M)}
    total, available = values.get("MemTotal"), values.get("MemAvailable")
    if total is None or available is None or not 0 <= available <= total or total == 0:
        raise ValueError("Memory fields unavailable.")
    swap_total, swap_free = values.get("SwapTotal"), values.get("SwapFree")
    swap_used = swap_total - swap_free if swap_total is not None and swap_free is not None and 0 <= swap_free <= swap_total else None
    return {"totalBytes": total, "availableBytes": available, "swapUsedBytes": swap_used,
            "committedBytes": None, "commitLimitBytes": None, "commitPercent": None}


def battery(text):
    fields = dict(re.findall(r"^\s*([A-Za-z ]+):\s*(-?\d+|true|false)\s*$", text, re.M))
    def integer(key):
        value = fields.get(key)
        return int(value) if value and re.fullmatch(r"-?\d+", value) else None
    level, scale, temperature = integer("level"), integer("scale"), integer("temperature")
    percent = level / scale * 100 if level is not None and scale and 0 <= level <= scale else None
    if percent is None:
        raise ValueError("Battery level unavailable.")
    return {"chargePercent": round(percent, 1), "temperatureC": temperature / 10 if temperature is not None else None,
            "statusCode": integer("status"), "healthCode": integer("health"),
            "usbPowered": {"true": True, "false": False}.get(fields.get("USB powered"))}


def storage(text):
    for line in text.splitlines():
        match = re.fullmatch(r"\s*\S+\s+(\d+)\s+(\d+)\s+(\d+)\s+\d+%\s+(/data(?:/user/[0-9]+)?)\s*", line)
        if match:
            total, used, free = (int(value) * 1024 for value in match.groups()[:3])
            if total > 0 and 0 <= used <= total and 0 <= free <= total:
                return {"queriedPath": "/data", "mount": match[4], "sizeBytes": total, "usedBytes": used, "freeBytes": free}
    raise ValueError("Storage layout unavailable.")


def packages(text):
    values = []
    for line in text.splitlines():
        if not line.strip():
            continue
        match = re.fullmatch(r"package:([A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)*)", line.strip())
        if not match:
            raise ValueError("Package listing is incomplete or unsupported.")
        values.append(match[1])
    return sorted(set(values))


def frames(text):
    total = re.search(r"^\s*Total frames rendered:\s*(\d+)\s*$", text, re.M)
    janky = re.search(r"^\s*Janky frames:\s*(\d+)\s*\(", text, re.M)
    if not total or not janky or int(janky[1]) > int(total[1]):
        raise ValueError("Frame counters unavailable.")
    count, bad = int(total[1]), int(janky[1])
    processes = re.findall(r"Graphics info for pid (\d+) \[([^\]]+)\]", text)
    windows = re.findall(r"Stats since:\s*(\d+)ns", text)
    identified = len(processes) == len(windows) == 1
    return {"totalFrames": count, "jankyFrames": bad, "jankPercent": round(100 * bad / count, 2) if count else None,
            "sufficientFrames": count >= 120, "window": "since-app-counter-reset", "counterWindowIdentified": identified,
            "processId": int(processes[0][0]) if identified else None, "observedPackage": processes[0][1] if identified else None,
            "statsSinceNs": windows[0] if identified else None}


def frame_window(before, after, requested_seconds):
    same_origin = (
        before["counterWindowIdentified"]
        and after["counterWindowIdentified"]
        and before["processId"] == after["processId"]
        and before["statsSinceNs"] == after["statsSinceNs"]
        and before["observedPackage"] == after["observedPackage"]
        and after["totalFrames"] >= before["totalFrames"]
        and after["jankyFrames"] >= before["jankyFrames"]
    )
    if not same_origin:
        return {
            **after,
            "windowSeconds": requested_seconds,
            "windowOriginVerified": False,
            "windowTotalFrames": None,
            "windowJankyFrames": None,
            "windowJankPercent": None,
            "sufficientWindowFrames": False,
        }
    delta_total = after["totalFrames"] - before["totalFrames"]
    delta_janky = after["jankyFrames"] - before["jankyFrames"]
    if delta_janky > delta_total:
        raise ValueError("Inconsistent frame counter delta.")
    return {
        **after,
        "window": "two-point-interval-delta",
        "windowSeconds": requested_seconds,
        "windowOriginVerified": True,
        "windowTotalFrames": delta_total,
        "windowJankyFrames": delta_janky,
        "windowJankPercent": round(100 * delta_janky / delta_total, 2) if delta_total else None,
        "sufficientWindowFrames": delta_total >= 30,
    }


def cpu(text):
    match = re.search(r"^\s*([\d.]+)% TOTAL:", text, re.M)
    if not match or not 0 <= float(match[1]) <= 100:
        raise ValueError("CPU summary unavailable.")
    return {"observedPercent": float(match[1]), "window": "Android-dumpsys-window", "speedup": None}


def thermal(text):
    match = re.search(r"^\s*Thermal Status:\s*(\d+)\s*$", text, re.M)
    if not match or int(match[1]) not in THERMAL_STATES:
        raise ValueError("Thermal status unavailable.")
    code = int(match[1])
    skin_temps = [float(val) for val in re.findall(r"Temperature\{mValue=(-?[\d.]+),\s*mType=3\b", text)]
    valid_skin = [round(val, 1) for val in skin_temps if -20 <= val <= 120]
    return {
        "statusCode": code,
        "throttlingState": THERMAL_STATES[code],
        "throttlingActive": code >= 1,
        "skinTemperatureC": max(valid_skin) if valid_skin else None,
    }


def app_storage(text):
    def extract_array(label):
        found = re.search(r"^\s*" + re.escape(label) + r":\s*(\[[^\r\n]*\])\s*$", text, re.M)
        if not found:
            raise ValueError("Missing diskstats field: " + label)
        try:
            parsed = json.loads(found[1])
        except json.JSONDecodeError as error:
            raise ValueError("Malformed diskstats array: " + label) from error
        if not isinstance(parsed, list) or not parsed:
            raise ValueError("Empty diskstats array: " + label)
        return parsed

    names = extract_array("Package Names")
    app_sizes = extract_array("App Sizes")
    data_sizes = extract_array("App Data Sizes")
    cache_sizes = extract_array("Cache Sizes")
    if not (len(names) == len(app_sizes) == len(data_sizes) == len(cache_sizes)):
        raise ValueError("Mismatched diskstats array lengths.")
    rows = []
    seen = set()
    for pkg, app_b, data_b, cache_b in zip(names, app_sizes, data_sizes, cache_sizes):
        if not isinstance(pkg, str) or not PACKAGE_RE.fullmatch(pkg):
            raise ValueError("Invalid package name in diskstats.")
        if not all(type(v) is int and v >= 0 for v in (app_b, data_b, cache_b)):
            raise ValueError("Invalid byte count in diskstats.")
        if pkg in seen:
            continue
        seen.add(pkg)
        rows.append({
            "package": pkg,
            "appBytes": app_b,
            "dataBytes": data_b,
            "cacheBytes": cache_b,
            "totalBytes": app_b + data_b + cache_b,
            "recommendation": "review-only",
        })
    rows.sort(key=lambda item: (-item["totalBytes"], item["package"]))
    return rows[:25]
