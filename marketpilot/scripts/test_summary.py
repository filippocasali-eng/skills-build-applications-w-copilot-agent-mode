#!/usr/bin/env python3
"""Summarizes JUnit XML results of all modules (used by CI to produce TEST_RESULTS evidence)."""
import glob
import os
import sys
import xml.etree.ElementTree as ET

root = sys.argv[1] if len(sys.argv) > 1 else "."
rows = []
tot = {"tests": 0, "failures": 0, "errors": 0, "skipped": 0}
for path in sorted(glob.glob(os.path.join(root, "**/build/test-results/**/*.xml"), recursive=True)) + \
        sorted(glob.glob(os.path.join(root, "**/build/outputs/androidTest-results/**/*.xml"), recursive=True)):
    try:
        s = ET.parse(path).getroot()
    except ET.ParseError:
        continue
    suites = [s] if s.tag == "testsuite" else s.findall("testsuite")
    for suite in suites:
        t = {k: int(suite.get(k, 0)) for k in tot}
        for k in tot:
            tot[k] += t[k]
        module = path.split("/build/")[0].replace(root, "").strip("/")
        rows.append((module, suite.get("name", "?"), t))
        for case in suite.findall("testcase"):
            f = case.find("failure")
            if f is None:
                f = case.find("error")
            if f is not None:
                print(f"FAILED {suite.get('name')}.{case.get('name')}: {(f.get('message') or '')[:600]}")
                print((f.text or "")[:1500])
        out_el = suite.find("system-out")
        if out_el is not None and out_el.text:
            for line in out_el.text.splitlines():
                if line.startswith("LIVE["):
                    print(line[:400])
lines = ["| Modulo | Suite | Test | Falliti | Errori | Saltati |", "|---|---|---|---|---|---|"]
for module, name, t in rows:
    lines.append(f"| {module} | {name.split('.')[-1]} | {t['tests']} | {t['failures']} | {t['errors']} | {t['skipped']} |")
lines.append(f"| **Totale** | | **{tot['tests']}** | **{tot['failures']}** | **{tot['errors']}** | **{tot['skipped']}** |")
out = "\n".join(lines)
print(out)
summary = os.environ.get("GITHUB_STEP_SUMMARY")
if summary:
    with open(summary, "a") as fh:
        fh.write(out + "\n")
