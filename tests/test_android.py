import contextlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src/runtime/android"))
from adbclient import AdbClient, Result, run_command
import audit as android_audit
import model


class AndroidTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix="syrin-android-test-")
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.adb = self.root / "adb.exe"
        self.adb.write_bytes(b"fixture; never executed")
        self.calls = []
        self.usb_serial = Result("complete", "PHONE\n", 0)
        self.listing = "List of devices attached\nPHONE device product:test transport_id:7\nOTHER device transport_id:8\n"
        self.answers = {
            ("get-state",): "device\n", ("get-devpath",): "usb:1-2\n", ("get-serialno",): "PHONE\n",
            ("shell", "getprop", "ro.build.fingerprint"): "fixture/build:1\n",
            ("shell", "getprop", "ro.product.model"): "Fixture Phone\n",
            ("shell", "getprop", "ro.product.manufacturer"): "Fixture\n",
            ("shell", "getprop", "ro.build.version.release"): "14\n",
            ("shell", "getprop", "ro.build.version.sdk"): "34\n",
            ("shell", "getprop", "ro.build.version.security_patch"): "2026-01-01\n",
            ("shell", "getprop", "sys.boot_completed"): "1\n",
            ("shell", "am", "get-current-user"): "10\n",
            ("shell", "cat", "/proc/meminfo"): "MemTotal: 8192 kB\nMemAvailable: 2048 kB\nSwapTotal: 4096 kB\nSwapFree: 1024 kB\n",
            ("shell", "cat", "/proc/uptime"): "300.5 29.0\n",
            ("shell", "dumpsys", "battery"): "Current Battery Service state:\n  level: 77\n  scale: 100\n  temperature: 340\n  USB powered: true\n",
            ("shell", "df", "-k", "/data"): "Filesystem 1K-blocks Used Available Use% Mounted on\n/dev/block/dm-1 1000 600 400 60% /data\n",
            ("shell", "dumpsys", "cpuinfo"): "  20% TOTAL: 10% user + 10% kernel\n",
            ("shell", "pm", "list", "packages", "--user", "10"): "package:com.example.notes\npackage:com.android.systemui\n",
            ("shell", "pm", "list", "packages", "--user", "10", "-s"): "package:com.android.systemui\n",
            ("shell", "pm", "list", "packages", "--user", "10", "-d"): "",
            ("shell", "dumpsys", "gfxinfo", "com.example.notes"): "Total frames rendered: 1\nJanky frames: 1 (100%)\n",
        }

    def runner(self, argv, timeout):
        self.calls.append(argv)
        self.assertEqual(argv[1:3], ["-P", "5037"])
        if argv[3:] == ["devices", "-l"]:
            return Result("complete", self.listing, 0)
        if argv[3:] == ["-d", "get-serialno"]:
            return self.usb_serial
        self.assertEqual(argv[3:5], ["-t", "7"])
        answer = self.answers[tuple(argv[5:])]
        return answer if isinstance(answer, Result) else Result("complete", answer, 0, 1)

    def client(self):
        client = AdbClient(str(self.adb), runner=self.runner)
        client.select("PHONE")
        return client

    def test_exact_transport_current_user_and_minimal_collection(self):
        audit = android_audit.collect(self.client(), session_id="a" * 32, include_packages=True, package="com.example.notes")
        self.assertEqual(audit["meta"]["platform"], "android")
        self.assertEqual(audit["collectors"]["system"]["data"][0]["userId"], 10)
        self.assertEqual(audit["collectors"]["memory"]["data"][0]["availableBytes"], 2097152)
        self.assertEqual(audit["collectors"]["storage"]["data"][0]["freeBytes"], 409600)
        self.assertEqual(audit["collectors"]["battery"]["data"][0]["temperatureC"], 34)
        self.assertEqual(audit["collectors"]["frames"]["status"], "partial")
        self.assertEqual(audit["collectors"]["packages"]["data"][1]["recommendation"], "review-only")
        self.assertNotIn("PHONE", json.dumps(audit))
        self.assertNotIn("fixture/build:1", json.dumps(audit))
        self.assertFalse(any("put" in cmd or "uninstall" in cmd or "reboot" in cmd for cmd in self.calls))

    def test_readiness_requires_explicit_phone_and_reports_distinct_states(self):
        client = AdbClient(str(self.adb), runner=self.runner)
        self.assertEqual(client.readiness()["code"], "select-device")
        self.assertIsNone(client.serial)
        self.assertFalse(any("shell" in call for call in self.calls))
        for listing, code in (("", "device-absent"), ("PHONE unauthorized transport_id:7", "device-unauthorized"), ("PHONE offline transport_id:7", "device-offline"), ("PHONE device transport_id:7\nPHONE device transport_id:8", "device-ambiguous")):
            self.listing = listing
            result = client.readiness("PHONE")
            self.assertEqual((result["ready"], result["code"]), (False, code))
        self.listing = "PHONE device transport_id:7"
        self.assertEqual(client.readiness("PHONE")["code"], "ready")
        self.answers[("shell", "getprop", "sys.boot_completed")] = "0"
        self.assertEqual(client.readiness("PHONE")["code"], "phone-not-ready")

    def test_frame_capture_preserves_workload_and_counter_provenance(self):
        key = ("shell", "dumpsys", "gfxinfo", "com.example.notes")
        self.answers[key] = "** Graphics info for pid 120 [com.example.notes] **\nStats since: 123456789ns\nTotal frames rendered: 240\nJanky frames: 12 (5%)\n"
        report = android_audit.collect(self.client(), session_id="a" * 32, package="com.example.notes", context_label="Scroll the fixture list")
        frames = report["collectors"]["frames"]
        self.assertEqual(frames["status"], "complete")
        self.assertEqual(frames["data"][0]["processId"], 120)
        self.assertEqual(frames["data"][0]["statsSinceNs"], "123456789")
        self.assertEqual(frames["data"][0]["contextLabel"], "Scroll the fixture list")
        self.answers[key] = self.answers[key].replace('[com.example.notes]', '[com.example.other]')
        mismatch = android_audit.collect(self.client(), session_id="b" * 32, package="com.example.notes")
        self.assertEqual(mismatch["collectors"]["frames"]["status"], "unavailable")
        self.answers[key] = self.answers[key].replace('[com.example.other]', '[com.example.notes]')
        self.answers[key] += "** Graphics info for pid 121 [com.example.notes:other] **\nStats since: 999ns\n"
        report = android_audit.collect(self.client(), session_id="b" * 32, package="com.example.notes")
        self.assertEqual(report["collectors"]["frames"]["status"], "partial")
        self.assertIsNone(report["collectors"]["frames"]["data"][0]["processId"])
        with self.assertRaises(ValueError):
            android_audit.collect(self.client(), session_id="a" * 32, context_label="line1\nline2")

    def test_missing_unauthorized_duplicate_and_wireless_selection(self):
        for listing in ("", "PHONE unauthorized transport_id:7\n", "PHONE offline transport_id:7\n", "PHONE device transport_id:7\nPHONE device transport_id:8\n"):
            with self.subTest(listing=listing):
                self.listing = listing
                with self.assertRaises(ValueError):
                    self.client()
        self.listing = "PHONE device transport_id:7\n"
        self.answers[("get-devpath",)] = "192.0.2.1:5555"
        with self.assertRaises(ValueError):
            self.client()

    def test_reused_transport_cannot_collect_another_phone(self):
        client = self.client()
        self.calls.clear()
        self.answers[("get-serialno",)] = "OTHER"
        self.assertEqual(client.read("memory").status, "identity-changed")
        self.assertFalse(any("shell" in call for call in self.calls))

    def test_failed_reselection_does_not_fall_back_to_previous_phone(self):
        client = self.client()
        with self.assertRaises(ValueError):
            client.select("MISSING")
        with self.assertRaises(ValueError):
            client.read("memory")

    def test_windows_missing_devpath_requires_unique_matching_usb(self):
        self.answers[("get-devpath",)] = "unknown\n"
        client = self.client()
        self.assertEqual(client.read("memory").status, "complete")
        self.usb_serial = Result("complete", "OTHER\n", 0)
        self.calls.clear()
        self.assertEqual(client.read("memory").status, "unverified-usb")
        self.assertFalse(any("shell" in call for call in self.calls))
        for result in (Result("complete", "OTHER\n", 0), Result("failed", "", 1)):
            self.usb_serial = result
            with self.assertRaises(ValueError):
                self.client()

    def test_disconnect_and_current_user_change_invalidate_snapshot(self):
        client = self.client()
        self.answers[("get-state",)] = "offline"
        with self.assertRaises(ValueError):
            android_audit.collect(client, session_id="a" * 32)
        self.answers[("get-state",)] = "device"
        original = client.read
        count = 0
        def read(name, **kwargs):
            nonlocal count
            if name == "user":
                count += 1
                return Result("complete", "10" if count == 1 else "11", 0)
            return original(name, **kwargs)
        with patch.object(client, "read", read), self.assertRaises(ValueError):
            android_audit.collect(client, session_id="a" * 32)

    def test_failures_remain_unavailable_and_package_output_is_strict(self):
        self.answers[("shell", "dumpsys", "battery")] = Result("failed", "", 1)
        self.answers[("shell", "pm", "list", "packages", "--user", "10")] = "Permission Denial: fixture"
        audit = android_audit.collect(self.client(), session_id="a" * 32, include_packages=True)
        for name in ("battery", "packages"):
            self.assertEqual(audit["collectors"][name]["status"], "unavailable")
            self.assertEqual(audit["collectors"][name]["data"], [])
        with self.assertRaises(ValueError):
            model.memory("MemTotal: 800 kB\n")
        self.assertIsNone(model.frames("Total frames rendered: 0\nJanky frames: 0 (0%)")["jankPercent"])

    def test_storage_query_preserves_android_data_bind_mount(self):
        result = model.storage('Filesystem 1K-blocks Used Available Use% Mounted on\n/dev/block/dm-1 1000 600 400 60% /data/user/0\n')
        self.assertEqual(result, {'queriedPath': '/data', 'mount': '/data/user/0', 'sizeBytes': 1024000, 'usedBytes': 614400, 'freeBytes': 409600})
        with self.assertRaises(ValueError):
            model.storage('/dev/block/dm-1 1000 600 400 60% /storage/emulated/0\n')

    def test_no_shell_injection_or_arbitrary_command(self):
        client = self.client()
        for package in ("com.example.app;reboot", "com.example.app$(id)", "-x", "com.example.app\nreboot"):
            with self.subTest(package=package), self.assertRaises(ValueError):
                client.read("frames", package=package)
        with self.assertRaises(ValueError):
            client.read("uninstall")
        with self.assertRaises(ValueError):
            client.read("packages", user=-1)

    def test_cli_creates_report_input_and_preserves_existing_evidence(self):
        out = self.root / "session"
        argv = ["audit.py", "--adb", str(self.adb), "--serial", "PHONE", "--out", str(out)]
        factory = lambda *args, **kwargs: AdbClient(str(self.adb), runner=self.runner)
        with patch.object(sys, "argv", argv), patch.object(android_audit, "AdbClient", factory), contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(android_audit.main(), 0)
            self.assertTrue(json.loads(output.getvalue())["ok"])
            original = (out / "audit.json").read_bytes()
            with self.assertRaises(ValueError):
                android_audit.main()
            self.assertEqual((out / "audit.json").read_bytes(), original)

    def test_subprocess_timeout_exit_and_output_cap(self):
        isolated = {name: str(self.root) for name in ("HOME", "USERPROFILE", "LOCALAPPDATA", "APPDATA", "TEMP", "TMP")}
        routing = ('ANDROID_SERIAL', 'ADB_SERVER_SOCKET', 'ANDROID_ADB_SERVER_PORT', 'ANDROID_ADB_SERVER_ADDRESS')
        isolated.update({name: 'fixture-remote-routing' for name in routing})
        with patch.dict(os.environ, isolated):
            probe = 'import os,json; print(json.dumps({k:os.environ.get(k) for k in ' + repr(routing) + '}))'
            routed = run_command([sys.executable, '-I', '-c', probe], 5)
            self.assertEqual((routed.status, json.loads(routed.text)), ('complete', {name: None for name in routing}))
            failed = run_command([sys.executable, "-I", "-c", "import sys; print('private',file=sys.stderr); sys.exit(4)"], 5)
            self.assertEqual((failed.status, failed.code, failed.text), ("failed", 4, ""))
            timeout = run_command([sys.executable, "-I", "-c", "import time; time.sleep(10)"], .1)
            self.assertEqual(timeout.status, "timeout")
            capped = run_command([sys.executable, "-I", "-c", "print('x'*100000)"], 5, limit=1024)
            self.assertEqual((capped.status, capped.text), ("output-limit", ""))

    def test_windows_adb_executable_rejects_batch_shims(self):
        shim = self.root / "adb.bat"
        shim.write_text("@echo off\n", encoding="utf-8")
        with patch.object(os, "name", "nt"), self.assertRaises(ValueError):
            AdbClient(str(shim), runner=self.runner)

    def test_optional_thermal_app_sizes_and_two_point_frame_window(self):
        self.answers[("shell", "dumpsys", "thermalservice")] = (
            "IsStatusOverride: false\n"
            "Current Temperatures:\n"
            "  Temperature{mValue=36.4, mType=3, mName=skin, mStatus=0}\n"
            "Thermal Status: 1\n"
        )
        self.answers[("shell", "dumpsys", "diskstats")] = (
            'Package Names: ["com.example.notes", "com.example.heavy"]\n'
            "App Sizes: [1000, 5000]\n"
            "App Data Sizes: [2000, 15000]\n"
            "Cache Sizes: [500, 4000]\n"
        )
        frame_reads = [
            "** Graphics info for pid 321 [com.example.notes] **\nStats since: 555ns\nTotal frames rendered: 100\nJanky frames: 4 (4%)\n",
            "** Graphics info for pid 321 [com.example.notes] **\nStats since: 555ns\nTotal frames rendered: 150\nJanky frames: 9 (6%)\n",
        ]
        key = ("shell", "dumpsys", "gfxinfo", "com.example.notes")
        original_runner = self.runner

        def windowed_runner(argv, timeout):
            if tuple(argv[5:]) == key:
                return Result("complete", frame_reads.pop(0), 0, 1)
            return original_runner(argv, timeout)

        client = AdbClient(str(self.adb), runner=windowed_runner)
        client.select("PHONE")
        slept = []
        report = android_audit.collect(
            client,
            session_id="e" * 32,
            include_thermal=True,
            include_app_sizes=True,
            package="com.example.notes",
            frame_window_seconds=5,
            context_label="Scroll notes feed",
            sleeper=lambda sec: slept.append(sec),
        )
        self.assertEqual(slept, [5])
        self.assertEqual(report["collectors"]["thermal"]["data"][0], {"statusCode": 1, "throttlingState": "light", "throttlingActive": True, "skinTemperatureC": 36.4})
        self.assertEqual([row["package"] for row in report["collectors"]["appSizes"]["data"]], ["com.example.heavy", "com.example.notes"])
        self.assertEqual(report["collectors"]["appSizes"]["data"][0]["totalBytes"], 24000)
        frame_row = report["collectors"]["frames"]["data"][0]
        self.assertEqual(report["collectors"]["frames"]["status"], "complete")
        self.assertTrue(frame_row["windowOriginVerified"])
        self.assertEqual((frame_row["windowTotalFrames"], frame_row["windowJankyFrames"], frame_row["windowJankPercent"]), (50, 5, 10.0))

        frame_reads[:] = [
            "** Graphics info for pid 321 [com.example.notes] **\nStats since: 555ns\nTotal frames rendered: 100\nJanky frames: 4 (4%)\n",
            "** Graphics info for pid 999 [com.example.notes] **\nStats since: 888ns\nTotal frames rendered: 40\nJanky frames: 2 (5%)\n",
        ]
        reset_report = android_audit.collect(client, session_id="f" * 32, package="com.example.notes", frame_window_seconds=5, sleeper=lambda _: None)
        self.assertEqual(reset_report["collectors"]["frames"]["status"], "partial")
        self.assertFalse(reset_report["collectors"]["frames"]["data"][0]["windowOriginVerified"])
        self.assertIsNone(reset_report["collectors"]["frames"]["data"][0]["windowTotalFrames"])
        with self.assertRaises(ValueError):
            android_audit.collect(client, session_id="a" * 32, frame_window_seconds=5, sleeper=lambda _: None)
