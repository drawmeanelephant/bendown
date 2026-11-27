#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BEND=${BEND:-$HOME/.bend/bin/bend}
BIN=${BENDOWN_BIN:-/tmp/bendown-bin}
BATCH_BIN=${BENDOWN_BATCH_BIN:-/tmp/bendown-batch}
MODE=${1:-core}

cd "$ROOT"
export BEND_NO_TELEMETRY=1

run_bend() {
  echo "== bend $1"
  "$BEND" "$1" >/tmp/bendown-verify.out 2>&1 || {
    cat /tmp/bendown-verify.out
    exit 1
  }
  tail -n 1 /tmp/bendown-verify.out || true
}

run_bend PROOF.bend
run_bend test/markdown_smoke.bend
run_bend test/textile_smoke.bend
run_bend test/render_smoke.bend
run_bend test/document_links_smoke.bend
run_bend test/cooklang_smoke.bend
run_bend test/cooklang_roundtrip_smoke.bend
run_bend test/scale_smoke.bend
run_bend src/cooklang/scaling_proof.bend
run_bend test/scaling_proof_test.bend
run_bend test/menu_smoke.bend
run_bend test/cooklang_render_smoke.bend
run_bend test/cooklang_html_fixtures.bend
run_bend test/batch_smoke.bend
run_bend test/batch_formats_smoke.bend
run_bend test/batch_multiformat_io_smoke.bend

if [ "$MODE" = core ]; then
  echo "core verification passed"
  exit 0
fi

if [ "$MODE" != full ]; then
  echo "usage: $0 [core|full]" >&2
  exit 2
fi

echo "== native single-document CLI build"
"$BEND" src/main.bend -o "$BIN" >/tmp/bendown-verify-build.out 2>&1 || {
  cat /tmp/bendown-verify-build.out
  exit 1
}

echo "== native batch CLI build"
"$BEND" src/batch_cli.bend -o "$BATCH_BIN" >/tmp/bendown-verify-batch-build.out 2>&1 || {
  cat /tmp/bendown-verify-batch-build.out
  exit 1
}

echo "== cooklang serialize oracle"
python3 tools/differential.py cooklang --operation serialize \
  --cmd "$BIN serialize --from cooklang" \
  --oracle-cmd '/Users/tbuddy/dev/oliver/zig-out/bin/oliver serialize --from cooklang' \
  --timeout 5 --failures 1 >/tmp/bendown-cooklang-verify.json
python3 - <<'PY'
import json
x=json.load(open('/tmp/bendown-cooklang-verify.json'))
print(f"{x['passed']}/{x['total']}")
raise SystemExit(0 if x['passed']==x['total'] else 1)
PY

echo "== cooklang serialize fixedpoint"
python3 tools/differential.py cooklang --operation fixedpoint \
  --cmd "$BIN serialize --from cooklang" \
  --timeout 5 --failures 1 >/tmp/bendown-cooklang-fixedpoint-verify.json
python3 - <<'PY'
import json
x=json.load(open('/tmp/bendown-cooklang-fixedpoint-verify.json'))
print(f"{x['passed']}/{x['total']}")
raise SystemExit(0 if x['passed']==x['total'] else 1)
PY

echo "== commonmark scorecard"
python3 tools/differential.py commonmark --cmd "$BIN" --timeout 5 --failures 0 >/tmp/bendown-commonmark-verify.json
python3 - <<'PY'
import json
x=json.load(open('/tmp/bendown-commonmark-verify.json'))
print(f"{x['passed']}/{x['total']}")
PY

echo "full verification completed"
