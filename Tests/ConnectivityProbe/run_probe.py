#!/usr/bin/env python3
"""Run the actual Shared sync code in two isolated simulator app containers."""
import argparse
import datetime
import hashlib
import json
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
import time


def run(command, **kwargs):
    return subprocess.run(command, check=True, text=True, capture_output=True, **kwargs)


def load_json(path):
    try:
        return json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def checkpoint(report, name):
    return next(item["snapshot"] for item in report["checkpoints"] if item["event"] == name)


def by_id(snapshot):
    return {item["id"]: item for item in snapshot["sessions"]}


def validate(phone, watch, phone_snapshot, watch_snapshot):
    assert phone["success"] and watch["success"]
    assert not phone["cloudEnabled"] and not watch["cloudEnabled"]
    assert phone["workID"] == watch["workID"]
    assert phone["studyID"] == watch["studyID"]
    work_id, study_id = phone["workID"], phone["studyID"]
    left, right = by_id(phone_snapshot), by_id(watch_snapshot)
    assert len(left) == len(right) == 2
    assert left == right, "Stored session fields differ between simulators"
    expected = [(work_id, "00000000-0000-0000-0000-000000000001", "Work", "43D10D", "iPhone"),
                (study_id, "00000000-0000-0000-0000-000000000002", "Study", "2699F5", "watch")]
    for session_id, workload_id, name, color, source in expected:
        item = left[session_id]
        assert item["workloadID"] == workload_id
        assert item["workloadName"] == name and item["colorHex"] == color
        assert item["source"] == source
        assert item.get("end") is not None and item.get("deletedAt") is None
        assert item["end"] >= item["start"]
    initial_work = by_id(checkpoint(phone, "phone-started-work"))[work_id]
    received_work = by_id(checkpoint(watch, "watch-received-work"))[work_id]
    stopped_work = by_id(checkpoint(watch, "watch-stopped-work"))[work_id]
    initial_study = by_id(checkpoint(watch, "watch-started-study"))[study_id]
    received_study = by_id(checkpoint(phone, "phone-received-ended-work-and-study"))[study_id]
    stopped_study = by_id(checkpoint(phone, "phone-stopped-study"))[study_id]
    assert initial_work == received_work, "Work changed during initial transport"
    assert initial_study == received_study, "Study changed during initial transport"
    assert left[work_id]["start"] == initial_work["start"]
    assert left[work_id]["end"] == stopped_work["end"]
    assert left[study_id]["start"] == initial_study["start"]
    assert left[study_id]["end"] == stopped_study["end"]
    assert all(item.get("end") is not None for item in left.values())
    return {"passed": True, "sessionCount": 2, "activeSessionCount": 0,
            "workID": work_id, "studyID": study_id,
            "exactFieldsValidated": ["UUID", "workloadID", "workloadName", "colorHex", "source", "start", "end", "timerBoundaries", "modifiedAt"],
            "cloudEnabled": False,
            "sequence": ["phone starts Work", "watch receives Work", "watch stops Work", "watch starts Study", "phone receives Study", "phone stops Study", "both converge"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phone", required=True, help="Booted iPhone simulator UUID")
    parser.add_argument("--watch", required=True, help="Its booted paired Watch simulator UUID")
    parser.add_argument("--repository", type=pathlib.Path, default=pathlib.Path(__file__).resolve().parents[2])
    parser.add_argument("--evidence", type=pathlib.Path, required=True)
    args = parser.parse_args()
    repository = args.repository.resolve()
    source = pathlib.Path(__file__).resolve().with_name("ProbeApp.swift")
    shared = sorted((repository / "Shared").glob("*.swift"))
    assert shared and source.is_file()
    initial_hashes = {str(path.relative_to(repository)): hashlib.sha256(path.read_bytes()).hexdigest() for path in shared}
    pairs = json.loads(run(["xcrun", "simctl", "list", "pairs", "--json"]).stdout)["pairs"]
    pair = next(pair for pair in pairs.values() if pair["phone"]["udid"] == args.phone and pair["watch"]["udid"] == args.watch)
    assert pair["phone"]["state"] == "Booted" and pair["watch"]["state"] == "Booted", "Boot the existing pair before running this probe"
    build = pathlib.Path(tempfile.mkdtemp(prefix="punchino-shared-connectivity-"))
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d%H%M%S")
    phone_bundle = "dev.codex.PunchinoSharedProbe.run" + stamp
    watch_bundle = phone_bundle + ".watchkitapp"
    phone_app = build / "SharedProbe.app"
    watch_app = phone_app / "Watch" / "SharedProbeWatch.app"
    watch_app.mkdir(parents=True)
    base = {"CFBundleExecutable": "SharedProbe", "CFBundleName": "SharedProbe", "CFBundleDisplayName": "Shared Sync Probe",
            "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "1.0", "CFBundleVersion": "1", "MinimumOSVersion": "26.0", "CloudSyncEnabled": False}
    phone_info = dict(base, CFBundleIdentifier=phone_bundle, LSRequiresIPhoneOS=True, UIDeviceFamily=[1], UILaunchScreen={}, UISupportedInterfaceOrientations=["UIInterfaceOrientationPortrait"])
    watch_info = dict(base, CFBundleIdentifier=watch_bundle, WKApplication=True, WKCompanionAppBundleIdentifier=phone_bundle, WKRunsIndependentlyOfCompanionApp=True, UIDeviceFamily=[4])
    for directory, info in [(phone_app, phone_info), (watch_app, watch_info)]:
        (directory / "Info.plist").write_bytes(plistlib.dumps(info))
    empty_entitlements = build / "empty.entitlements"
    empty_entitlements.write_bytes(plistlib.dumps({}))
    for sdk_name, target, app in [("iphonesimulator", "arm64-apple-ios26.0-simulator", phone_app), ("watchsimulator", "arm64-apple-watchos26.0-simulator", watch_app)]:
        sdk = run(["xcrun", "--sdk", sdk_name, "--show-sdk-path"]).stdout.strip()
        command = ["xcrun", "swiftc", "-parse-as-library", "-swift-version", "5", "-sdk", sdk, "-target", target] + [str(path) for path in shared] + [str(source), "-o", str(app / "SharedProbe")]
        run(command)
    for app in [watch_app, phone_app]:
        run(["codesign", "--force", "--sign", "-", "--entitlements", str(empty_entitlements), str(app)])
    installed = []
    try:
        for device, app, bundle in [(args.phone, phone_app, phone_bundle), (args.watch, watch_app, watch_bundle)]:
            run(["xcrun", "simctl", "install", device, str(app)])
            installed.append((device, bundle))
        for device, bundle in installed:
            run(["xcrun", "simctl", "launch", device, bundle])
        directories = []
        for device, bundle in installed:
            container = pathlib.Path(run(["xcrun", "simctl", "get_app_container", device, bundle, "data"]).stdout.strip())
            directories.append(container / "Library" / "Application Support" / "ConnectivityProbe")
        deadline = time.monotonic() + 100
        reports = [None, None]
        while time.monotonic() < deadline:
            reports = [load_json(directory / "report.json") for directory in directories]
            for report in reports:
                if report and report.get("error"):
                    raise RuntimeError(report["side"] + ": " + report["error"])
            if all(report and report["success"] and report["checkpoints"][-1]["event"] == "settled-final" for report in reports):
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("Probe timed out. Last reports: " + str(reports))
        snapshots = [load_json(directory / "tracking.json") for directory in directories]
        validation = validate(reports[0], reports[1], snapshots[0], snapshots[1])
        final_hashes = {str(path.relative_to(repository)): hashlib.sha256(path.read_bytes()).hexdigest() for path in shared}
        assert initial_hashes == final_hashes, "Shared sources changed during the probe. Run it again after edits stop."
        args.evidence.mkdir(parents=True, exist_ok=True)
        for side, report, snapshot in zip(["phone", "watch"], reports, snapshots):
            (args.evidence / (side + "-report.json")).write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
            (args.evidence / (side + "-snapshot.json")).write_text(json.dumps(snapshot, indent=2, sort_keys=True) + "\n")
        validation["sharedSourceSHA256"] = initial_hashes
        validation["runnerSHA256"] = hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest()
        validation["xcodeVersion"] = run(["xcodebuild", "-version"]).stdout.strip()
        validation["simulatorPair"] = {"phone": pair["phone"]["name"], "watch": pair["watch"]["name"]}
        validation["probeSourceSHA256"] = hashlib.sha256(source.read_bytes()).hexdigest()
        (args.evidence / "validation.json").write_text(json.dumps(validation, indent=2, sort_keys=True) + "\n")
        print(json.dumps({"passed": True, "sessions": 2, "active": 0, "exactSessionFieldsMatch": True, "evidence": str(args.evidence)}, sort_keys=True))
    finally:
        for device, bundle in reversed(installed):
            subprocess.run(["xcrun", "simctl", "terminate", device, bundle], capture_output=True)
            subprocess.run(["xcrun", "simctl", "uninstall", device, bundle], capture_output=True)


if __name__ == "__main__":
    main()
