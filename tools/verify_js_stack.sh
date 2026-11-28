#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BEND=${BEND:-$HOME/.bend/bin/bend}
OUT=${BENDOWN_JS_STACK_OUT:-/tmp/bendown-js-stack-repro.mjs}

cd "$ROOT"
export BEND_NO_TELEMETRY=1

if ! command -v node >/dev/null 2>&1; then
  echo "node not found; JavaScript stack regression skipped" >&2
  exit 1
fi

"$BEND" test/js_stack_repro.bend -o "$OUT" >/tmp/bendown-js-stack-build.out 2>&1 || {
  cat /tmp/bendown-js-stack-build.out
  exit 1
}

CHECK=/tmp/bendown-js-stack-check.mjs
cat > "$CHECK" <<'NODEEOF'
const mod = await import('file://' + process.env.BENDOWN_JS_STACK_OUT);
const parseOk = mod.default.parse_ok;
function heading(n) { return '# ' + 'a'.repeat(Math.max(0, n - 3)) + '\n'; }
function shortLines(n) {
  const unit = 'alpha beta gamma\n';
  return unit.repeat(Math.ceil(n / unit.length)).slice(0, n);
}
function sections(n) {
  const unit = '## section\n\nalpha beta gamma\n\n';
  return unit.repeat(Math.ceil(n / unit.length)).slice(0, n);
}
function mixed(n) {
  const unit = '## h\n\n- one\n- two `code` [link](https://e.test)\n\npara *em* text\n\n';
  return unit.repeat(Math.ceil(n / unit.length)).slice(0, n);
}
let count = 0;
for (const [name, make] of [['heading', heading], ['short-lines', shortLines], ['sections', sections], ['mixed', mixed]]) {
  for (const n of [1024, 4096, 8192, 24000]) {
    let value;
    try {
      value = parseOk(make(n));
    } catch (error) {
      throw new Error(`${name}/${n}: ${error && error.message}`);
    }
    if (!value) throw new Error(`${name}/${n}: parser returned false`);
    count += 1;
  }
}
console.log(`javascript stack regression passed (${count} cases)`);
NODEEOF

BENDOWN_JS_STACK_OUT="$OUT" node "$CHECK"
