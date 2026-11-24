#!/usr/bin/env python3
"""Prints the UDID of an available iPhone simulator on the newest iOS runtime.

Simulator names change with every Xcode release, so CI picks whichever iPhone
the machine has instead of hard-coding one. Used by both GitHub Actions and GitLab CI.
"""
import json
import subprocess
import sys

out = subprocess.run(
    ["xcrun", "simctl", "list", "devices", "available", "--json"],
    check=True, capture_output=True, text=True,
).stdout
runtimes = json.loads(out)["devices"]
for runtime in sorted((r for r in runtimes if "iOS" in r), reverse=True):
    for device in runtimes[runtime]:
        if device["name"].startswith("iPhone"):
            print(device["udid"])
            sys.exit()
sys.exit("no iPhone simulator found")
