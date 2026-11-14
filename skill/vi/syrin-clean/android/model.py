"""Parse measured values without turning missing data into healthy zeroes."""
import re


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


def cpu(text):
    match = re.search(r"^\s*([\d.]+)% TOTAL:", text, re.M)
    if not match or not 0 <= float(match[1]) <= 100:
        raise ValueError("CPU summary unavailable.")
    return {"observedPercent": float(match[1]), "window": "Android-dumpsys-window", "speedup": None}
