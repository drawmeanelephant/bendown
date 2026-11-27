#!/usr/bin/env python3
"""Deterministic bendown-batch par/seq benchmark.

The generated corpus is synthetic but representative Markdown: headings,
paragraphs, inline emphasis/links, lists, code spans, and code blocks.  Both
modes use the same native binary, directory discovery, and concurrent file-read
stage; `--seq` changes only the pure per-document transformation to sequential
mapping.  The script verifies byte-identical outputs and counts error slots.
"""

import argparse
import hashlib
import json
import os
import resource
import statistics
import subprocess
import sys
import tempfile
import time


def dataset_text(i: int, blocks: int) -> str:
    parts = []
    for j in range(blocks):
        parts.append(
            f"# Document {i} block {j}\n\n"
            f"A paragraph with *emphasis*, **strong text**, `code span`, "
            f"and [link {j}](target-{i}-{j}.md) plus <https://example.test/{i}/{j}>.\n\n"
            f"- first **bold** item with [inner](inner-{j}.md)\n"
            f"- second *emphasized* item\n"
            f"- third item with `code`\n\n"
            f"1. ordered [reference][r{j}]\n"
            f"2. ordered continuation\n\n"
            f"[r{j}]: /reference/{i}/{j} \"Title\"\n\n"
            f"```text\nfenced code {i} {j} *not emphasis* [not a link]\n```\n\n"
        )
    return "".join(parts)


def write_dataset(root: str, files: int, blocks: int) -> None:
    for i in range(files):
        with open(os.path.join(root, f"doc-{i:03d}.md"), "w", encoding="utf-8") as f:
            f.write(dataset_text(i, blocks))


def child_cpu_seconds() -> float:
    r = resource.getrusage(resource.RUSAGE_CHILDREN)
    return r.ru_utime + r.ru_stime


def run_once(binary: str, root: str, sequential: bool):
    cmd = [binary]
    if sequential:
        cmd.append("--seq")
    cmd.append(root)
    cpu0 = child_cpu_seconds()
    t0 = time.perf_counter()
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=300)
    wall = time.perf_counter() - t0
    cpu = child_cpu_seconds() - cpu0
    out = p.stdout
    return {
        "returncode": p.returncode,
        "wall": wall,
        "cpu": cpu,
        "stdout_bytes": len(out),
        "stderr": p.stderr.decode("utf-8", "replace"),
        "digest": hashlib.sha256(out).hexdigest(),
        "errors": out.count(b"ERROR:"),
        "document_sections": out.count(b"\x3d\x3d "),
        "headings": out.count(b"<h1>Document"),
    }


def summarize(rows):
    walls = [r["wall"] for r in rows]
    cpus = [r["cpu"] for r in rows]
    return {
        "runs": len(rows),
        "wall_median": statistics.median(walls),
        "wall_min": min(walls),
        "wall_max": max(walls),
        "cpu_median": statistics.median(cpus),
        "cpu_min": min(cpus),
        "cpu_max": max(cpus),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--bin", default="/tmp/bendown-batch")
    ap.add_argument("--files", type=int, default=32)
    ap.add_argument("--blocks", type=int, default=8)
    ap.add_argument("--runs", type=int, default=5, help="timed runs per side")
    ap.add_argument("--json", default="")
    args = ap.parse_args()

    if args.runs < 1:
        raise SystemExit("--runs must be positive")

    with tempfile.TemporaryDirectory(prefix="bendown-batch-bench.") as root:
        write_dataset(root, args.files, args.blocks)
        input_bytes = sum(os.path.getsize(os.path.join(root, n)) for n in os.listdir(root))

        # Warm the binary/runtime and filesystem cache once; not counted.
        warm = run_once(args.bin, root, False)
        par_rows = []
        seq_rows = []
        # Interleave sides so drift and background load affect both similarly.
        for _ in range(args.runs):
            par_rows.append(run_once(args.bin, root, False))
            seq_rows.append(run_once(args.bin, root, True))

    all_rows = [warm] + par_rows + seq_rows
    digests = sorted({r["digest"] for r in par_rows + seq_rows})
    result = {
        "binary": os.path.realpath(args.bin),
        "files": args.files,
        "blocks_per_file": args.blocks,
        "input_bytes": input_bytes,
        "warmup": warm,
        "parallel": summarize(par_rows),
        "sequential": summarize(seq_rows),
        "outputs_identical": len(digests) == 1,
        "digests": digests,
        "returncodes": sorted({r["returncode"] for r in all_rows}),
        "error_slots": sum(r["errors"] for r in par_rows + seq_rows),
        "document_sections_each": sorted({r["document_sections"] for r in par_rows + seq_rows}),
        "headings_each": sorted({r["headings"] for r in par_rows + seq_rows}),
        "expected_documents": args.files,
        "expected_headings": args.files * args.blocks,
        "stderr_nonempty": sum(bool(r["stderr"]) for r in all_rows),
    }
    sp = result["sequential"]["wall_median"] / result["parallel"]["wall_median"]
    result["wall_speedup_seq_over_par"] = sp
    text = json.dumps(result, indent=2, sort_keys=True)
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            f.write(text + "\n")
    print(text)
    ok = (
        result["outputs_identical"]
        and result["returncodes"] == [0]
        and result["error_slots"] == 0
        and result["document_sections_each"] == [args.files + 1]  # documents plus == links
        and result["headings_each"] == [args.files * args.blocks]
        and result["stderr_nonempty"] == 0
    )
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
