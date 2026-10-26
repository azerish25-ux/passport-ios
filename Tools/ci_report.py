#!/usr/bin/env python3
"""Turn an xcodebuild log into GitHub Actions annotations and a short digest.

Why this exists: a red iOS run is only useful if the failure is readable
without downloading a 40 MB .xcresult. This script extracts compiler errors and
XCTest failures from the raw log, prints one ``::error`` workflow command per
distinct failure (so it appears as a pull-request annotation and in the public
Actions API), and writes a compact Markdown digest.

Usage:
    python3 Tools/ci_report.py --label unit --log build/unit-test.log
    python3 Tools/ci_report.py --label build --log build/build.log --limit 40

The script always exits 0. It reports failures; it must never change the
conclusion of the step that produced them.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

# `path:line:column: error: message` and `path:line: error: message`.
# The column is optional: clang and swiftc both emit it, while XCTest assertion
# failures usually omit it. Matching only the two-field form silently produced
# "no failure detail" for every compiler error, which is exactly the blindness
# this script exists to remove.
ERROR_RE = re.compile(
    r"^\s*(?P<file>[^:\n]+):(?P<line>\d+)(?::(?P<column>\d+))?:\s*"
    r"(?P<severity>error|fatal error):\s*(?P<message>.*)$"
)

# Anything mentioning an error, used only when the structured patterns find
# nothing. A build can fail without a single `file:line:` error (for example a
# missing destination or a linker failure), and that must still be visible.
FALLBACK_RE = re.compile(r"\berror\b[:;]?\s|\bBUILD FAILED\b|The following build commands failed", re.IGNORECASE)

# `Test Case '-[Suite testName]' failed (0.12 seconds).`
FAILED_CASE_RE = re.compile(r"Test Case '-\[(?P<suite>[^\]]+)\]' failed \((?P<seconds>[0-9.]+) seconds\)")

# `Test Suite 'PassportProofTests.xctest' failed at 2026-10-26 ...`
FAILED_SUITE_RE = re.compile(r"Test Suite '(?P<suite>[^']+)' failed")

# A duplicate-suppressing key: the same compiler error can be printed once per
# architecture.
MAX_MESSAGE = 500


def clean(message: str) -> str:
    message = re.sub(r"\s+", " ", message).strip()
    if len(message) > MAX_MESSAGE:
        message = message[:MAX_MESSAGE] + "…"
    return message


def escape(value: str) -> str:
    """Escape a GitHub workflow command argument."""
    return (
        value.replace("%", "%25")
        .replace("\r", "%0D")
        .replace("\n", "%0A")
        .replace(":", "%3A")
        .replace(",", "%2C")
    )


def annotate(level: str, message: str, file: str | None = None, line: int | None = None) -> None:
    properties = []
    if file:
        properties.append(f"file={escape(file)}")
    if line:
        properties.append(f"line={line}")
    prefix = f"::{level} " + ",".join(properties) + "::" if properties else f"::{level}::"
    print(prefix + escape(message))


def parse(log_path: Path) -> tuple[list[dict], list[dict], list[str]]:
    errors: list[dict] = []
    failed_cases: list[dict] = []
    failed_suites: list[str] = []
    seen_errors: set[tuple[str, int, str]] = set()
    seen_cases: set[str] = set()

    with log_path.open("r", encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            line = raw.rstrip("\n")

            if match := ERROR_RE.match(line):
                key = (match.group("file"), int(match.group("line")), clean(match.group("message")))
                if key in seen_errors:
                    continue
                seen_errors.add(key)
                errors.append(
                    {
                        "file": match.group("file").strip(),
                        "line": int(match.group("line")),
                        "message": clean(match.group("message")),
                    }
                )
                continue

            if match := FAILED_CASE_RE.search(line):
                name = f"[{match.group('suite')}]"
                if name in seen_cases:
                    continue
                seen_cases.add(name)
                failed_cases.append({"suite": match.group("suite"), "seconds": match.group("seconds")})
                continue

            if match := FAILED_SUITE_RE.search(line):
                failed_suites.append(match.group("suite"))

    return errors, failed_cases, failed_suites


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--label", required=True, help="Human label, e.g. unit or ui")
    parser.add_argument("--log", required=True, type=Path)
    parser.add_argument("--limit", type=int, default=25, help="Maximum annotations to print")
    args = parser.parse_args()

    if not args.log.is_file():
        print(f"No {args.label} log at {args.log}; nothing to report.")
        return 0

    errors, failed_cases, failed_suites = parse(args.log)

    if not errors and not failed_cases:
        # Fall back to raw lines that look like a failure, so an unparseable log
        # still names something instead of reporting a clean run.
        with args.log.open("r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                if FALLBACK_RE.search(line):
                    errors.append({"file": "", "line": 0, "message": clean(line)})
                    if len(errors) >= 40:
                        break

    total = len(errors)

    for entry in errors[: args.limit]:
        annotate(
            "error",
            f"{args.label}: {entry['message']}",
            file=entry["file"],
            line=entry["line"],
        )
    if total > args.limit:
        annotate("error", f"{args.label}: {total - args.limit} further failures not annotated")

    for case in failed_cases[: args.limit]:
        annotate("error", f"{args.label}: test failed {case['suite']}")

    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    digest_lines = [f"## {args.label.capitalize()} failure digest", ""]
    if not errors and not failed_cases and not failed_suites:
        digest_lines.append("No compiler errors or XCTest failures were found in the log.")
    if failed_suites:
        digest_lines.append(f"**Failed suites:** {', '.join(sorted(set(failed_suites)))}")
        digest_lines.append("")
    if failed_cases:
        digest_lines.append(f"**Failed test cases ({len(failed_cases)}):**")
        for case in failed_cases:
            digest_lines.append(f"- `{case['suite']}`")
        digest_lines.append("")
    if errors:
        digest_lines.append(f"**Distinct errors ({total}, showing up to 15):**")
        digest_lines.append("")
        digest_lines.append("```text")
        for entry in errors[:15]:
            digest_lines.append(f"{entry['file']}:{entry['line']}: {entry['message']}")
        digest_lines.append("```")

    digest = "\n".join(digest_lines)
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as handle:
            handle.write(digest + "\n")
    print(digest)

    # A failure digest that is empty is itself suspicious: the step failed but
    # nothing matched. Say so rather than reporting a clean run.
    if not errors and not failed_cases and not failed_suites:
        print("::warning title=No failure detail::The log contains no parseable error; inspect the uploaded xcresult.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
