# bendown agent notes

Bend 2.0.40 is installed at `~/.bend/bin/bend`; it is not on the default PATH in fresh shells.

Use these verification commands from the repo root:

```sh
BEND_NO_TELEMETRY=1 ~/.bend/bin/bend LAWS.bend
BEND_NO_TELEMETRY=1 ~/.bend/bin/bend PROOF.bend
BEND_NO_TELEMETRY=1 ~/.bend/bin/bend PROOF.bend --verdict
```

`--verdict` currently requires Lean v4.34.0 (`lean` on PATH) or `$BENDTT` pointing at a built kernel; Lean is not installed yet.

Before writing Bend code, read the local guide captured by the installation or run:

```sh
BEND_NO_TELEMETRY=1 ~/.bend/bin/bend guide
```

Important Bend constraints discovered while bootstrapping:

- A `match` cannot scrutinize a computed value. Pass the computed Boolean/value to a helper whose parameter is matched, or use nested constructor/literal patterns.
- Scrutinees in a multi-value `match` must respect binder order.
- Defs are checked in file order and mutual recursion is not allowed. Restructure recursive helpers as one self-recursive function or use decreasing fuel.
- Affine values cannot be used twice. Mark reusable `Data` parameters with `+`.
- Rewriting `%e : P` replaces the right-hand side of an equality proof with its left-hand side. Use `Equal.sym` when the needed orientation is opposite.
- Strings are linked lists of Unicode characters, not byte arrays. `src/text.bend` has `utf8_length` for byte-ceiling checks over valid UTF-8 text.
- If typechecking fails with `cannot infer` at a `Data` constructor or list cons inside a complex expression, route construction through tiny explicitly typed factory/cons helpers whose constructor arguments are simple parameters. Type ascription at the outer expression is often insufficient once Bend inlines the expression.

Cleanroom boundary: implement behavior from official specifications, Oliver's `docs/`, and test corpora. Do not inspect or copy parser implementation source from Oliver (`src/markdown.zig`, `src/textile.zig`, `src/cooklang*.zig`) or any third-party markup parser.

Reference corpora:

- `corpus/commonmark/spec-0.31.2.txt`, SHA-256 `bfef4ddc97276b6ab6c2a28ace48478e35b1c50e60cde9f517ab8ab030aa3b82`, 204857 bytes, 652 examples.
- `corpus/cooklang/canonical.yaml`, SHA-256 `e3dc4fdbc5d883add6b24a971fc5fc07e68edc26d5df5084cf849d649cda98de`, 15836 bytes, 60 tests.

The local Oliver oracle is `/Users/tbuddy/dev/oliver/zig-out/bin/oliver`; the newer development checkout is `/Users/tbuddy/dev/oliver` at commit `62503d1` as of this bootstrap.


Current verification commands:

```sh
BEND_NO_TELEMETRY=1 ~/.bend/bin/bend PROOF.bend
BEND_NO_TELEMETRY=1 ~/.bend/bin/bend test/markdown_smoke.bend
BEND_NO_TELEMETRY=1 ~/.bend/bin/bend test/render_smoke.bend
BEND_NO_TELEMETRY=1 ~/.bend/bin/bend test/cooklang_smoke.bend
BEND_NO_TELEMETRY=1 ~/.bend/bin/bend test/scale_smoke.bend
BEND_NO_TELEMETRY=1 ~/.bend/bin/bend src/main.bend -o /tmp/bendown-bin
BEND_NO_TELEMETRY=1 ~/.bend/bin/bend src/batch_cli.bend -o /tmp/bendown-batch
```

When passing program arguments through the interpreter lane, separate Bend's own CLI options with `--`, for example:

```sh
printf 'hello' | BEND_NO_TELEMETRY=1 ~/.bend/bin/bend src/main.bend -- render --from markdown
```

The compiled binary takes program arguments directly:

```sh
printf 'hello' | /tmp/bendown-bin render --from markdown
printf '%s\n' 'Add @flour{1/2%cup}.' | /tmp/bendown-bin scale --from cooklang --factor 2
/tmp/bendown-batch DIRECTORY
```

Differential harness examples:

```sh
python3 tools/differential.py commonmark --cmd /tmp/bendown-bin --timeout 5 --failures 0
python3 tools/differential.py cooklang --operation serialize --cmd '/tmp/bendown-bin serialize --from cooklang' --oracle-cmd '/Users/tbuddy/dev/oliver/zig-out/bin/oliver serialize --from cooklang'
python3 tools/differential.py cooklang --operation fixedpoint --cmd '/tmp/bendown-bin serialize --from cooklang'
python3 tools/differential.py fixtures --family textile --cmd '/tmp/bendown-bin render --from textile'
```


Batch benchmark harness:

```sh
python3 tools/benchmark_batch.py --bin /tmp/bendown-batch --runs 5 --files 64 --blocks 32
```

It generates a deterministic synthetic Markdown corpus, alternates parallel and `--seq` runs, verifies byte-identical output, counts error slots, and reports wall/CPU time medians and ranges.

Important compatibility note: deterministic Textile attribute order is `style`, `class`, `id`, `lang`, then other attributes in input order. This is pinned by Oliver's Textile fixture behavior even though older architecture prose uses `id,class,style,lang` as an example.

Native CLI split: `src/main.bend` handles single-document render/serialize/scale/menu operations, while `src/batch_cli.bend` handles directory batch processing. They are separate because linking both command surfaces into one binary currently exceeds the Bend compiler's machine stack even though each source typechecks individually.
