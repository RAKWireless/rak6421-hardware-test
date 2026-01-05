#!/usr/bin/env python3
"""Convert shunit2 outputs into a structured JSON report."""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List


def _read_optional_file(path: str | None) -> str:
    if not path:
        return ""
    file_path = Path(path)
    if not file_path.is_file():
        return ""
    try:
        return file_path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""


def _parse_test_output(raw_output: str) -> Dict[str, List[str]]:
    if not raw_output:
        return {}
    test_output: Dict[str, List[str]] = {}
    pattern = re.compile(r"^(test\w+)$")
    current = None
    for line in raw_output.splitlines():
        stripped = line.strip()
        match = pattern.match(stripped)
        if match:
            current = match.group(1)
            test_output[current] = []
            continue
        if not current or not stripped:
            continue
        # Remove ANSI color sequences
        cleaned = re.sub(r"\x1b\[[0-9;]*m", "", stripped)
        if cleaned and not re.match(r"^(Testing|Ran|OK|FAILED)", cleaned):
            keywords = [
                "temperature",
                "humidity",
                "pressure",
                "co2",
                "voc",
                "gas index",
                "uv",
                "ambient light",
                "rtc",
                "time",
                "buzzer",
                "led",
                "current",
            ]
            lower = cleaned.lower()
            if any(keyword in lower for keyword in keywords):
                test_output.setdefault(current, []).append(cleaned)
    return test_output


def _load_stored_outputs() -> Dict[str, str]:
    encoded = os.environ.get("JSON_TEST_OUTPUTS", "")
    if not encoded:
        return {}
    outputs: Dict[str, str] = {}
    for item in encoded.split("||"):
        if "::" not in item:
            continue
        test_name, data = item.split("::", 1)
        if not test_name:
            continue
        try:
            decoded = base64.b64decode(data).decode("utf-8")
        except Exception:
            decoded = data
        outputs[test_name] = decoded
    return outputs


def _get_system_info() -> Dict[str, str]:
    info: Dict[str, str] = {
        "cpu": "Unknown",
        "cpu_serial": "Unknown",
        "memory": "Unknown",
        "storage": "Unknown",
        "os": "Unknown",
        "device_eui": "Unknown",
    }

    try:
        result = subprocess.run(
            ["lshw", "-quiet", "-json", "-c", "system"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        if result.returncode == 0 and result.stdout:
            data = json.loads(result.stdout)
            if isinstance(data, list) and data:
                info["cpu"] = data[0].get("product", info["cpu"])
                info["cpu_serial"] = data[0].get("serial", info["cpu_serial"])
    except Exception:
        pass

    try:
        result = subprocess.run(["free", "-h"], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            lines = result.stdout.splitlines()
            if len(lines) > 1:
                info["memory"] = lines[1].split()[1]
    except Exception:
        pass

    try:
        result = subprocess.run(["df", "-h", "/"], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            lines = result.stdout.splitlines()
            if len(lines) > 1:
                info["storage"] = lines[1].split()[1]
    except Exception:
        pass

    try:
        with open("/etc/os-release", encoding="utf-8") as fp:
            for line in fp:
                if line.startswith("VERSION_ID="):
                    info["os"] = line.split("=", 1)[1].strip().strip('"')
                    break
    except OSError:
        pass

    try:
        result = subprocess.run(["ip", "link", "show", "eth0"], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if "ether" in line:
                    mac = line.split()[1]
                    parts = mac.split(":")
                    if len(parts) == 6:
                        info["device_eui"] = f"{parts[0]}{parts[1]}{parts[2]}FFFE{parts[3]}{parts[4]}{parts[5]}"
                    break
    except Exception:
        pass

    return info


def _normalize_output(value: str) -> str:
    """Normalize newline and whitespace for JSON output."""
    if not value:
        return ""
    return " ".join(value.replace("\r", " ").replace("\n", " ").split())


def _build_tests_from_junit(
    junit_path: str,
    stored_outputs: Dict[str, str],
    parsed_output: Dict[str, List[str]],
) -> List[Dict[str, object]]:
    tree = None
    try:
        tree = ET.parse(junit_path)
    except Exception as exc:
        raise RuntimeError(f"Failed to parse JUnit XML: {exc}") from exc

    root = tree.getroot()
    tests: List[Dict[str, object]] = []
    for testcase in root.findall("testcase"):
        name = testcase.get("name", "")
        duration = float(testcase.get("time", "0") or 0)
        assertions = int(testcase.get("assertions", "0") or 0)
        status = "PASS"
        error_msg = None
        failure = testcase.find("failure")
        error = testcase.find("error")
        if failure is not None:
            status = "FAIL"
            error_msg = failure.get("message") or failure.text or ""
        elif error is not None:
            status = "ERROR"
            error_msg = error.get("message") or error.text or ""

        sensor_data = stored_outputs.get(name)
        if not sensor_data:
            sensor_lines = parsed_output.get(name, [])
            if sensor_lines:
                sensor_data = " ".join(line.strip() for line in sensor_lines if line.strip())

        test_info: Dict[str, object] = {
            "name": name,
            "status": status,
            "duration_seconds": duration,
            "assertions": assertions,
        }
        if error_msg:
            test_info["error"] = error_msg
        if sensor_data:
            test_info["output"] = _normalize_output(sensor_data)
        tests.append(test_info)
    return tests


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate JSON report for RAK6421 tests")
    parser.add_argument("--kit", required=True, help="Kit identifier")
    parser.add_argument("--junit", help="Path to shunit2 JUnit XML output")
    parser.add_argument("--test-output", dest="test_output", help="Captured stdout/stderr from shunit2 run")
    parser.add_argument("--duration", type=float, default=0.0, help="Fallback duration in seconds")
    parser.add_argument("--total", type=int, default=0, help="Fallback total test count")
    parser.add_argument("--passed", type=int, default=0, help="Fallback passed test count")
    parser.add_argument("--failed", type=int, default=0, help="Fallback failed test count")
    parser.add_argument("--timestamp", help="Override ISO timestamp")
    return parser.parse_args()


try:
    import xml.etree.ElementTree as ET
except ImportError as exc:  # pragma: no cover
    print(f"{{\"error\": \"Missing xml parser: {exc}\"}}", file=sys.stderr)
    sys.exit(1)


def main() -> int:
    args = parse_arguments()
    junit_exists = bool(args.junit and Path(args.junit).is_file())
    stored_outputs = _load_stored_outputs()
    parsed_output = _parse_test_output(_read_optional_file(args.test_output))
    system_info = _get_system_info()
    timestamp = args.timestamp or datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    summary = {
        "total": args.total,
        "passed": args.passed,
        "failed": args.failed,
        "status": "PASS" if args.failed == 0 else "FAIL",
    }
    duration = args.duration
    tests: List[Dict[str, object]] = []

    if junit_exists:
        try:
            tree = ET.parse(args.junit)
            root = tree.getroot()
            duration = float(root.get("time", duration) or duration)
            summary["total"] = int(root.get("tests", summary["total"]))
            summary["failed"] = int(root.get("failures", summary["failed"]))
            summary["passed"] = summary["total"] - summary["failed"]
            summary["status"] = "PASS" if summary["failed"] == 0 else "FAIL"
            tests = _build_tests_from_junit(args.junit, stored_outputs, parsed_output)
        except Exception as exc:
            print(f"{{\"error\": \"Failed to parse test results: {exc}\"}}", file=sys.stderr)
            return 1

    result = {
        "test_suite": "RAK6421 Hardware Test",
        "configuration": args.kit,
        "timestamp": timestamp,
        "duration_seconds": duration,
        "summary": summary,
        "metadata": {"system": system_info},
        "tests": tests,
    }

    json.dump(result, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())

