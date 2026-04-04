#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import plistlib
import re
import shlex
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PROJECT = REPO_ROOT / "Pinball App 2" / "Pinball App 2.xcodeproj"
DEFAULT_SCHEME = "PinProf"
DEFAULT_APP_NAME = "PinProf"
DEFAULT_BUNDLE_ID = "com.pillyliu.Pinball-App-2"
DEFAULT_SIMULATOR_NAME = "iPhone 17 Pro"
DEFAULT_CONFIGURATION = "Debug"
DEFAULT_DERIVED_DATA = REPO_ROOT / ".deriveddata" / "ios-sim-capture"
DEFAULT_OUTPUT_DIR = Path.home() / "Movies" / "PinProf Simulator Captures"


class ScriptError(RuntimeError):
    pass


@dataclass(order=True)
class SimulatorDevice:
    runtime_sort_key: tuple[int, ...]
    name: str
    udid: str
    runtime: str
    state: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare the iPhone simulator for promo capture and optionally record an app clip."
    )
    parser.add_argument("--clip-name", required=True, help="Human-readable clip name used in the output filename.")
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUTPUT_DIR, help="Directory for recorded MP4 files.")
    parser.add_argument("--device-name", default=DEFAULT_SIMULATOR_NAME, help="Simulator name, default: iPhone 17 Pro.")
    parser.add_argument("--device-udid", help="Explicit simulator UDID. Overrides --device-name.")
    parser.add_argument("--project", type=Path, default=DEFAULT_PROJECT, help="Xcode project path.")
    parser.add_argument("--scheme", default=DEFAULT_SCHEME, help="Xcode scheme to build and run.")
    parser.add_argument("--app-name", default=DEFAULT_APP_NAME, help="Built .app name, default: PinProf.")
    parser.add_argument("--bundle-id", default=DEFAULT_BUNDLE_ID, help="App bundle identifier.")
    parser.add_argument("--configuration", default=DEFAULT_CONFIGURATION, help="Xcode build configuration.")
    parser.add_argument("--derived-data", type=Path, default=DEFAULT_DERIVED_DATA, help="DerivedData directory for scripted builds.")
    parser.add_argument("--build", action="store_true", help="Build and install the app before capture.")
    parser.add_argument("--no-launch", action="store_true", help="Do not launch the app after prep.")
    parser.add_argument("--codec", choices=("h264", "hevc"), default="h264", help="Recording codec.")
    parser.add_argument("--duration", type=float, help="Optional recording duration in seconds. Without this, press Enter to stop.")
    parser.add_argument("--location", help="Set simulator location as LAT,LON before launch.")
    parser.add_argument("--gameroom-name", help="Set the GameRoom name in the simulator app state.")
    parser.add_argument("--status-bar-time", default="9:41", help="Status bar time override.")
    parser.add_argument("--operator-name", default="", help="Status bar carrier name override.")
    parser.add_argument("--appearance", choices=("dark", "light"), default="dark", help="Simulator appearance override.")
    parser.add_argument("--skip-status-bar", action="store_true", help="Skip clean status bar overrides.")
    parser.add_argument("--skip-dark-mode-default", action="store_true", help="Do not force the app display mode preference.")
    parser.add_argument("--show-intro", action="store_true", help="Allow the app intro overlay to appear instead of hiding it.")
    parser.add_argument("--skip-practice-name-prompt", action="store_true", help="Leave the practice name prompt untouched.")
    parser.add_argument("--no-open-simulator", action="store_true", help="Do not bring Simulator.app to the front.")
    parser.add_argument("--no-prompt", action="store_true", help="Skip the pre-record prompt and start recording immediately.")
    return parser.parse_args()


def run(
    cmd: list[str],
    *,
    capture_output: bool = True,
    check: bool = True,
    text: bool = True,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        cmd,
        capture_output=capture_output,
        text=text,
        check=False,
    )
    if check and result.returncode != 0:
        raise ScriptError(
            "Command failed:\n"
            f"  {' '.join(shlex.quote(part) for part in cmd)}\n"
            f"{result.stderr.strip() or result.stdout.strip()}"
        )
    return result


def parse_runtime_key(runtime: str) -> tuple[int, ...]:
    match = re.search(r"iOS-(\d+)(?:-(\d+))?", runtime)
    if not match:
        return (0, 0)
    major = int(match.group(1))
    minor = int(match.group(2) or 0)
    return (major, minor)


def load_available_devices() -> list[SimulatorDevice]:
    raw = run(["xcrun", "simctl", "list", "devices", "available", "-j"]).stdout
    payload = json.loads(raw)
    devices: list[SimulatorDevice] = []
    for runtime, runtime_devices in payload.get("devices", {}).items():
        if "iOS" not in runtime:
            continue
        runtime_sort_key = parse_runtime_key(runtime)
        for device in runtime_devices:
            if not device.get("isAvailable", True):
                continue
            devices.append(
                SimulatorDevice(
                    runtime_sort_key=runtime_sort_key,
                    name=device["name"],
                    udid=device["udid"],
                    runtime=runtime,
                    state=device.get("state", "Shutdown"),
                )
            )
    return devices


def resolve_device(device_name: str, device_udid: str | None) -> SimulatorDevice:
    devices = load_available_devices()
    if device_udid:
        for device in devices:
            if device.udid == device_udid:
                return device
        raise ScriptError(f"Simulator UDID not found or unavailable: {device_udid}")

    candidates = [device for device in devices if device.name == device_name]
    if not candidates:
        raise ScriptError(f"No available iOS simulator named {device_name!r} was found.")
    return max(candidates)


def boot_simulator(device: SimulatorDevice, open_simulator: bool) -> None:
    run(["xcrun", "simctl", "boot", device.udid], check=False)
    run(["xcrun", "simctl", "bootstatus", device.udid, "-b"])
    if open_simulator:
        run(["open", "-a", "Simulator"], capture_output=False)


def build_and_install_app(args: argparse.Namespace, device: SimulatorDevice) -> None:
    destination = f"platform=iOS Simulator,id={device.udid}"
    cmd = [
        "xcodebuild",
        "-project",
        str(args.project),
        "-scheme",
        args.scheme,
        "-configuration",
        args.configuration,
        "-destination",
        destination,
        "-derivedDataPath",
        str(args.derived_data),
        "build",
    ]
    print("Building app for simulator...")
    build = subprocess.run(cmd, text=True, capture_output=True, check=False)
    if build.returncode != 0:
        raise ScriptError(
            "xcodebuild failed.\n"
            f"{build.stdout[-4000:]}\n{build.stderr[-4000:]}"
        )

    app_path = args.derived_data / "Build" / "Products" / f"{args.configuration}-iphonesimulator" / f"{args.app_name}.app"
    if not app_path.exists():
        raise ScriptError(f"Built app not found at expected path: {app_path}")

    print(f"Installing {app_path.name} on {device.name}...")
    run(["xcrun", "simctl", "install", device.udid, str(app_path)])


def ensure_app_container(device: SimulatorDevice, bundle_id: str) -> Path:
    result = run(
        ["xcrun", "simctl", "get_app_container", device.udid, bundle_id, "data"],
        check=False,
    )
    if result.returncode != 0:
        raise ScriptError(
            "App data container is unavailable. Install the app first with --build "
            f"or verify the bundle id ({bundle_id})."
        )
    return Path(result.stdout.strip())


def set_simulator_appearance(device: SimulatorDevice, appearance: str) -> None:
    run(["xcrun", "simctl", "ui", device.udid, "appearance", appearance])


def set_status_bar(device: SimulatorDevice, args: argparse.Namespace) -> None:
    run(["xcrun", "simctl", "status_bar", device.udid, "clear"], check=False)
    if args.skip_status_bar:
        return

    run(
        [
            "xcrun",
            "simctl",
            "status_bar",
            device.udid,
            "override",
            "--time",
            args.status_bar_time,
            "--dataNetwork",
            "wifi",
            "--wifiMode",
            "active",
            "--wifiBars",
            "3",
            "--cellularMode",
            "active",
            "--cellularBars",
            "4",
            "--operatorName",
            args.operator_name,
            "--batteryState",
            "charged",
            "--batteryLevel",
            "100",
        ]
    )


def set_simulator_location(device: SimulatorDevice, location: str | None, bundle_id: str) -> None:
    if not location:
        return
    run(["xcrun", "simctl", "privacy", device.udid, "grant", "location", bundle_id], check=False)
    run(["xcrun", "simctl", "location", device.udid, "set", location])


def terminate_app(device: SimulatorDevice, bundle_id: str) -> None:
    run(["xcrun", "simctl", "terminate", device.udid, bundle_id], check=False)


def launch_app(device: SimulatorDevice, bundle_id: str) -> None:
    run(["xcrun", "simctl", "launch", device.udid, bundle_id])


def load_preferences(plist_path: Path) -> dict[str, Any]:
    if not plist_path.exists():
        return {}
    with plist_path.open("rb") as handle:
        payload = plistlib.load(handle)
    if not isinstance(payload, dict):
        raise ScriptError(f"Unexpected preferences format: {plist_path}")
    return payload


def save_preferences(plist_path: Path, prefs: dict[str, Any]) -> None:
    plist_path.parent.mkdir(parents=True, exist_ok=True)
    with plist_path.open("wb") as handle:
        plistlib.dump(prefs, handle, fmt=plistlib.FMT_BINARY)


def empty_gameroom_state(venue_name: str) -> dict[str, Any]:
    return {
        "schemaVersion": 2,
        "venueName": venue_name,
        "areas": [],
        "ownedMachines": [],
        "events": [],
        "issues": [],
        "attachments": [],
        "reminderConfigs": [],
        "importRecords": [],
    }


def update_gameroom_state(existing_raw: bytes | None, venue_name: str) -> bytes:
    if existing_raw:
        try:
            payload = json.loads(existing_raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ScriptError(f"Could not decode existing GameRoom state: {exc}") from exc
    else:
        payload = empty_gameroom_state(venue_name)

    if not isinstance(payload, dict):
        raise ScriptError("Existing GameRoom state is not a JSON object.")

    payload.setdefault("schemaVersion", 2)
    payload["venueName"] = venue_name
    payload.setdefault("areas", [])
    payload.setdefault("ownedMachines", [])
    payload.setdefault("events", [])
    payload.setdefault("issues", [])
    payload.setdefault("attachments", [])
    payload.setdefault("reminderConfigs", [])
    payload.setdefault("importRecords", [])
    return json.dumps(payload, separators=(",", ":"), ensure_ascii=True).encode("utf-8")


def apply_app_preferences(container_path: Path, args: argparse.Namespace) -> Path:
    plist_path = container_path / "Library" / "Preferences" / f"{args.bundle_id}.plist"
    prefs = load_preferences(plist_path)

    if not args.skip_dark_mode_default:
        prefs["app-display-mode"] = args.appearance

    if not args.show_intro:
        prefs["app-intro-seen-version"] = 1
        prefs["app-intro-show-on-next-launch"] = False

    if not args.skip_practice_name_prompt:
        prefs["practice-name-prompted"] = True

    if args.gameroom_name:
        existing = prefs.get("gameroom-state-json")
        if existing is not None and not isinstance(existing, (bytes, bytearray)):
            raise ScriptError("Expected gameroom-state-json to be stored as data bytes.")
        prefs["gameroom-state-json"] = update_gameroom_state(
            bytes(existing) if isinstance(existing, bytearray) else existing,
            args.gameroom_name,
        )

    save_preferences(plist_path, prefs)
    return plist_path


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-zA-Z0-9]+", "-", value.strip().lower()).strip("-")
    return slug or "clip"


def describe_prep(args: argparse.Namespace, device: SimulatorDevice, output_path: Path) -> str:
    lines = [
        f"Simulator: {device.name} ({device.runtime})",
        f"Output: {output_path}",
        f"Appearance: {args.appearance}",
    ]
    if not args.skip_status_bar:
        lines.append(f"Status bar: clean override at {args.status_bar_time}")
    if args.location:
        lines.append(f"Location: {args.location}")
    if args.gameroom_name:
        lines.append(f"GameRoom name: {args.gameroom_name}")
    lines.append("App intro: shown" if args.show_intro else "App intro: hidden")
    return "\n".join(lines)


def record_video(device: SimulatorDevice, output_path: Path, codec: str, duration: float | None) -> None:
    cmd = [
        "xcrun",
        "simctl",
        "io",
        device.udid,
        "recordVideo",
        f"--codec={codec}",
        "--force",
        str(output_path),
    ]
    process = subprocess.Popen(cmd)
    time.sleep(1.0)

    try:
        if duration is not None:
            time.sleep(duration)
        else:
            input("Recording. Press Enter to stop... ")
    finally:
        if process.poll() is None:
            process.send_signal(signal.SIGINT)
        process.wait(timeout=15)

    if process.returncode != 0:
        raise ScriptError(f"Video recording failed with exit code {process.returncode}.")
    if not output_path.exists():
        raise ScriptError(f"Recording finished but no output file was written: {output_path}")


def ffprobe_summary(path: Path) -> str:
    result = run(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height,r_frame_rate,duration",
            "-of",
            "default=noprint_wrappers=1",
            str(path),
        ],
        check=False,
    )
    return result.stdout.strip()


def main() -> int:
    args = parse_args()

    device = resolve_device(args.device_name, args.device_udid)
    boot_simulator(device, open_simulator=not args.no_open_simulator)

    if args.build:
        build_and_install_app(args, device)

    container_path = ensure_app_container(device, args.bundle_id)

    terminate_app(device, args.bundle_id)
    set_simulator_appearance(device, args.appearance)
    set_status_bar(device, args)
    set_simulator_location(device, args.location, args.bundle_id)
    plist_path = apply_app_preferences(container_path, args)

    if not args.no_launch:
        launch_app(device, args.bundle_id)

    timestamp = time.strftime("%Y%m%d-%H%M%S")
    output_dir = args.out_dir.expanduser()
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{timestamp}-{slugify(args.clip_name)}.mp4"

    print(describe_prep(args, device, output_path))
    print(f"Preferences updated: {plist_path}")

    if not args.no_prompt:
        input("Press Enter when the simulator is ready and the shot is framed... ")

    record_video(device, output_path, args.codec, args.duration)

    print("\nCapture complete.")
    print(output_path)
    summary = ffprobe_summary(output_path)
    if summary:
        print(summary)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
    except ScriptError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)
