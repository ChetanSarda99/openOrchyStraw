#!/usr/bin/env python3
"""Verify that README.md has been updated to match the actual code.

This script checks for specific required content in the README.
Used as the test_command for the outdated-readme benchmark task.
"""

import sys


def main():
    with open("README.md") as f:
        content = f.read().lower()

    checks = [
        ("v3.2 or 3.2", lambda c: "3.2" in c),
        ("process_file function documented", lambda c: "process_file" in c),
        ("process_csv removed or marked deprecated", lambda c: "process_csv" not in c or "deprecated" in c or "replaced" in c),
        ("Python 3.7+ or higher", lambda c: "3.7" in c or "3.8" in c or "3.9" in c or "3.10" in c or "3.11" in c or "3.12" in c),
        ("JSON config (not INI)", lambda c: "json" in c and (".ini" not in c or "replaced" in c)),
        ("summary returns dict", lambda c: "dict" in c or "dictionary" in c),
        ("file_format parameter mentioned", lambda c: "file_format" in c or "format" in c),
    ]

    passed = 0
    failed = 0
    for name, check in checks:
        if check(content):
            print(f"  PASS: {name}")
            passed += 1
        else:
            print(f"  FAIL: {name}")
            failed += 1

    print(f"\n{passed}/{len(checks)} checks passed")
    if failed > 0:
        print("README is still outdated — not all required updates were made")
        sys.exit(1)
    else:
        print("README correctly updated")
        sys.exit(0)


if __name__ == "__main__":
    main()
