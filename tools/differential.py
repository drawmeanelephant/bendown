#!/usr/bin/env python3
import argparse
import json
import shlex
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
OLIVER = Path("/Users/tbuddy/dev/oliver/zig-out/bin/oliver")
COMMONMARK = ROOT / "corpus/commonmark/spec-0.31.2.txt"
COOKLANG = ROOT / "corpus/cooklang/canonical.yaml"


def extract_commonmark(path):
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    out = []
    i = 0
    number = 0
    section = ""
    fence = "`" * 32 + " example"
    while i < len(lines):
        stripped = lines[i].rstrip("\n")
        if stripped.startswith("#"):
            heading = stripped.lstrip("#").strip()
            if heading:
                section = heading
        if stripped == fence:
            number += 1
            i += 1
            source_lines = []
            while i < len(lines) and lines[i].rstrip("\n") != ".":
                source_lines.append(lines[i])
                i += 1
            if i >= len(lines):
                raise ValueError(f"example {number}: missing dot separator")
            i += 1
            expected_lines = []
            while i < len(lines) and not lines[i].startswith("`" * 32):
                expected_lines.append(lines[i])
                i += 1
            if i >= len(lines):
                raise ValueError(f"example {number}: missing closing fence")
            source = "".join(source_lines).replace("→", "\t")
            expected = "".join(expected_lines).replace("→", "\t")
            out.append({"number": number, "section": section, "markdown": source, "html": expected})
        i += 1
    if number != 652:
        raise ValueError(f"expected 652 examples, found {number}")
    return out


def norm_expected(data):
    if data.endswith("\n"):
        return data[:-1]
    return data


def run_cmd(cmd, data, timeout=10):
    try:
        p = subprocess.run(cmd, input=data.encode("utf-8"), stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
        return {"status": p.returncode, "stdout": p.stdout.decode("utf-8", "replace"), "stderr": p.stderr.decode("utf-8", "replace")}
    except subprocess.TimeoutExpired:
        return {"status": 124, "stdout": "", "stderr": "timeout"}


def command_from_args(args, default):
    if args.cmd:
        return shlex.split(args.cmd)
    return shlex.split(default)


def commonmark_mode(args):
    examples = extract_commonmark(Path(args.spec))
    if args.example:
        wanted = set(args.example)
        examples = [x for x in examples if x["number"] in wanted]
    if args.limit:
        examples = examples[:args.limit]
    cmd = command_from_args(args, f"{OLIVER} render --from markdown")
    passed = 0
    failures = []
    outcomes = []
    for ex in examples:
        got = run_cmd(cmd, ex["markdown"], args.timeout)
        actual = norm_expected(got["stdout"])
        if args.oracle_cmd:
            oracle = run_cmd(shlex.split(args.oracle_cmd), ex["markdown"], args.timeout)
            expected = norm_expected(oracle["stdout"])
            ok = got["status"] == 0 and oracle["status"] == 0 and actual == norm_expected(oracle["stdout"])
        else:
            expected = norm_expected(ex["html"])
            ok = got["status"] == 0 and actual == expected
        outcomes.append((ex.get("section", ""), ok))
        if ok:
            passed += 1
        elif len(failures) < args.failures:
            failures.append({"number": ex["number"], "section": ex.get("section", ""), "input": ex["markdown"], "expected": expected, "actual": actual, "status": got["status"], "stderr": got["stderr"]})
    sections = {}
    for section, ok in outcomes:
        entry = sections.setdefault(section, {"passed": 0, "total": 0})
        entry["total"] += 1
        entry["passed"] += 1 if ok else 0
    result = {"mode": "commonmark", "passed": passed, "total": len(examples), "sections": sections, "failures": failures}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if passed == len(examples) else 1


def cooklang_sources(path):
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    return [(name, case.get("source", "")) for name, case in data["tests"].items()]


def cooklang_mode(args):
    cases = cooklang_sources(Path(args.corpus))
    if args.limit:
        cases = cases[:args.limit]
    if args.operation == "render":
        default = f"{OLIVER} render --from cooklang"
    elif args.operation == "scale":
        default = f"{OLIVER} scale --from cooklang --factor {args.factor}"
    else:
        default = f"{OLIVER} serialize --from cooklang"
    cmd = command_from_args(args, default)
    passed = 0
    failures = []
    for name, source in cases:
        got = run_cmd(cmd, source, args.timeout)
        ok = got["status"] == 0
        expected = None
        actual = got["stdout"]
        if args.operation == "fixedpoint":
            second = run_cmd(cmd, got["stdout"], args.timeout) if ok else {"status": 1, "stdout": "", "stderr": "first pass failed"}
            expected = got["stdout"]
            actual = second["stdout"]
            ok = ok and second["status"] == 0 and got["stdout"] == second["stdout"]
        elif args.oracle_cmd:
            oracle = run_cmd(shlex.split(args.oracle_cmd), source, args.timeout)
            ok = ok and oracle["status"] == 0 and got["stdout"] == oracle["stdout"]
            expected = oracle["stdout"]
        if ok:
            passed += 1
        elif len(failures) < args.failures:
            failures.append({"name": name, "input": source, "expected": expected, "actual": actual, "status": got["status"], "stderr": got["stderr"]})
    result = {"mode": "cooklang", "operation": args.operation, "passed": passed, "total": len(cases), "failures": failures}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if passed == len(cases) else 1


def run_cmd_bytes(cmd, data, timeout=10):
    try:
        p = subprocess.run(cmd, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
        return {"status": p.returncode, "stdout": p.stdout, "stderr": p.stderr}
    except subprocess.TimeoutExpired:
        return {"status": 124, "stdout": b"", "stderr": b"timeout"}


def fixture_mode(args):
    root = Path(args.fixture_root) / args.family
    extension = {"markdown": ".md", "textile": ".textile", "cooklang": ".cook"}[args.family]
    cases = sorted(root.glob("*" + extension))
    if args.core_only and args.family == "markdown":
        extension_prefixes = ("ext-", "footnote-", "wikilink-", "callout-", "highlight-", "math-", "comments-", "embed-", "smartypants-", "cross-", "frontmatter-")
        cases = [x for x in cases if not x.name.startswith(extension_prefixes)]
    if args.core_only and args.family == "textile":
        cases = [x for x in cases if not x.name.startswith("frontmatter-")]
    if args.limit:
        cases = cases[:args.limit]
    if args.cmd:
        cmd = shlex.split(args.cmd)
    else:
        cmd = shlex.split(f"{OLIVER} render --from {args.family}")
    passed = 0
    failures = []
    sections = {}
    for source_path in cases:
        expected_path = source_path.with_suffix(".html")
        if not expected_path.exists():
            continue
        name = source_path.stem
        source = source_path.read_bytes()
        expected = expected_path.read_bytes()
        got = run_cmd_bytes(cmd, source, args.timeout)
        ok = got["status"] == 0 and got["stdout"] == expected
        group = name.split("-", 1)[0]
        entry = sections.setdefault(group, {"passed": 0, "total": 0})
        entry["total"] += 1
        if ok:
            passed += 1
            entry["passed"] += 1
        elif len(failures) < args.failures:
            failures.append({
                "name": name,
                "expected": expected.decode("utf-8", "replace"),
                "actual": got["stdout"].decode("utf-8", "replace"),
                "status": got["status"],
                "stderr": got["stderr"].decode("utf-8", "replace"),
            })
    total = sum(x["total"] for x in sections.values())
    result = {"mode": "fixtures", "family": args.family, "passed": passed, "total": total, "sections": sections, "failures": failures}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if passed == total else 1


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="mode", required=True)
    for name in ("commonmark", "cooklang"):
        p = sub.add_parser(name)
        p.add_argument("--cmd")
        p.add_argument("--timeout", type=float, default=10)
        p.add_argument("--limit", type=int)
        p.add_argument("--failures", type=int, default=5)
    cm = sub.choices["commonmark"]
    cm.add_argument("--spec", default=str(COMMONMARK))
    cm.add_argument("--example", type=int, action="append")
    cm.add_argument("--oracle-cmd")
    ck = sub.choices["cooklang"]
    ck.add_argument("--corpus", default=str(COOKLANG))
    ck.add_argument("--operation", choices=("serialize", "render", "scale", "fixedpoint"), default="serialize")
    ck.add_argument("--factor", default="2")
    ck.add_argument("--oracle-cmd")
    fx = sub.add_parser("fixtures")
    fx.add_argument("--cmd")
    fx.add_argument("--timeout", type=float, default=10)
    fx.add_argument("--limit", type=int)
    fx.add_argument("--failures", type=int, default=5)
    fx.add_argument("--family", choices=("markdown", "textile", "cooklang"), required=True)
    fx.add_argument("--fixture-root", default="/Users/tbuddy/dev/oliver/tests/fixtures")
    fx.add_argument("--core-only", action="store_true")
    args = ap.parse_args()
    if args.mode == "commonmark":
        return commonmark_mode(args)
    if args.mode == "fixtures":
        return fixture_mode(args)
    return cooklang_mode(args)


if __name__ == "__main__":
    sys.exit(main())
