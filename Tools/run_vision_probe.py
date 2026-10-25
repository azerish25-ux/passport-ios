#!/usr/bin/env python3
"""Run the same real-photo Vision probe in isolated native processes.

This is diagnostic tooling, not application code or a substitute for the app's
unit/UI gates. Each mode gets its own process; all exit statuses are preserved.
"""

import argparse
import json
import platform
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("runtime", choices=["macos", "18.5", "26.2"])
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = root / "build" / "vision-probe"
    output.mkdir(parents=True, exist_ok=True)
    fixture = root / "PassportProofTests/AssessmentAssets.xcassets/FullResolutionPortrait.imageset/full-resolution-portrait.jpg"
    source = root / "Tools/VisionProbe.swift"
    executable = output / "VisionProbe"
    sdk = "macosx" if args.runtime == "macos" else "iphonesimulator"
    arch = platform.machine()
    if arch not in ("arm64", "x86_64"):
        raise SystemExit(f"Unsupported runner architecture: {arch}")
    target = f"{arch}-apple-macos14.0" if args.runtime == "macos" else f"{arch}-apple-ios17.0-simulator"
    sdk_path = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-path"], text=True).strip()
    compile_command = ["xcrun", "--sdk", sdk, "swiftc", "-parse-as-library", "-sdk", sdk_path,
                       "-target", target, str(source), "-o", str(executable)]
    with (output / "compile.log").open("w") as log:
        log.write(json.dumps({"runtime": args.runtime, "target": target, "sdk": sdk_path}) + "\n")
        log.flush()
        result = subprocess.run(compile_command, stdout=log, stderr=subprocess.STDOUT, timeout=180)
    if result.returncode:
        print((output / "compile.log").read_text(), flush=True)
        raise SystemExit(result.returncode)
    subprocess.run(["codesign", "--force", "--sign", "-", str(executable)], check=True, timeout=30)

    simulator_id = None
    try:
        if args.runtime != "macos":
            runtimes = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "-j", "runtimes"], text=True))["runtimes"]
            runtime = next((item for item in runtimes if item.get("isAvailable")
                            and item["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
                            and item["version"] == args.runtime), None)
            if runtime is None:
                raise RuntimeError(f"Required diagnostic runtime {args.runtime} is unavailable; no substitution")
            devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "-j", "devices", "available"], text=True))["devices"]
            device = next((item for item in devices.get(runtime["identifier"], [])
                           if item.get("isAvailable") and "iPhone" in item["name"]), None)
            if device is None:
                raise RuntimeError(f"No available iPhone for {runtime['identifier']}")
            simulator_id = device["udid"]
            with (output / "runtime.log").open("w") as log:
                log.write(json.dumps({"runtime": runtime, "device": device}) + "\n")
                log.flush()
                # Only a disposable hosted Actions simulator is touched.
                subprocess.run(["xcrun", "simctl", "shutdown", simulator_id], stdout=log, stderr=subprocess.STDOUT, timeout=30)
                subprocess.run(["xcrun", "simctl", "erase", simulator_id], stdout=log, stderr=subprocess.STDOUT, timeout=90, check=True)
                subprocess.run(["xcrun", "simctl", "boot", simulator_id], stdout=log, stderr=subprocess.STDOUT, timeout=90, check=True)
                subprocess.run(["xcrun", "simctl", "bootstatus", simulator_id, "-b"], stdout=log, stderr=subprocess.STDOUT, timeout=240, check=True)

        results = []
        for mode in ("direct", "explicit"):
            command = [str(executable), str(fixture), mode]
            if simulator_id:
                command = ["xcrun", "simctl", "spawn", simulator_id] + command
            path = output / f"{mode}.log"
            with path.open("w") as log:
                log.write(json.dumps({"runtime": args.runtime, "mode": mode, "command": command}) + "\n")
                log.flush()
                try:
                    result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180)
                    status = result.returncode
                except subprocess.TimeoutExpired:
                    status = 124
                    log.write("\nProbe process timed out after 180 seconds.\n")
                log.write(json.dumps({"processExitStatus": status}) + "\n")
            print(path.read_text(), flush=True)
            results.append({"mode": mode, "exitStatus": status})
        (output / "summary.log").write_text(json.dumps({"runtime": args.runtime, "results": results}, indent=2) + "\n")
        if any(item["exitStatus"] != 0 for item in results):
            raise SystemExit(1)
    finally:
        if simulator_id:
            subprocess.run(["xcrun", "simctl", "shutdown", simulator_id], timeout=30)


if __name__ == "__main__":
    main()
