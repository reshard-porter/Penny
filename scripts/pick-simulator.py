#!/usr/bin/env python3
"""Prints the UDID of the best available iPhone simulator (newest iOS, prefers a 'Pro').

Usage: xcrun simctl list devices available -j | python3 scripts/pick-simulator.py
"""
import json
import sys


def version_of(runtime: str):
    # "com.apple.CoreSimulator.SimRuntime.iOS-18-2" -> (18, 2)
    if "iOS-" not in runtime:
        return None
    try:
        return tuple(int(part) for part in runtime.split("iOS-")[1].split("-"))
    except ValueError:
        return None


def score(name: str) -> int:
    if "Pro Max" in name:
        return 2
    if "Pro" in name:
        return 3
    if "Plus" in name or "Air" in name or "SE" in name or "mini" in name or "e" == name.split()[-1][-1:]:
        return 0
    return 1


def main() -> int:
    devices = json.load(sys.stdin).get("devices", {})
    best = None
    for runtime, entries in devices.items():
        version = version_of(runtime)
        if version is None:
            continue
        for device in entries:
            name = device.get("name", "")
            if not device.get("isAvailable", False) or not name.startswith("iPhone"):
                continue
            key = (version, score(name))
            if best is None or key > best[0]:
                best = (key, device["udid"], name)
    if best is None:
        print("No available iPhone simulator found", file=sys.stderr)
        return 1
    print(f"Using {best[2]} (iOS {'.'.join(map(str, best[0][0]))})", file=sys.stderr)
    print(best[1])
    return 0


if __name__ == "__main__":
    sys.exit(main())
