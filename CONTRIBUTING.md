# Contributing to bendown

## Ground rules

1. **Clean-room, always.** Implement from published specifications, the
   vendored corpora, and documented behavior. Never consult or copy Oliver's
   implementation sources (`src/*.zig`) or third-party Markdown/Textile/
   Cooklang implementations. See `AGENTS.md` for the exact boundary.
2. **Corpus counts are the evidence.** Markdown parse changes must report the
   CommonMark corpus score; the CI ratchet floor only moves up, and moving it
   is a deliberate, stated part of the change. Cooklang changes must keep the
   fixedpoint corpus at 60/60.
3. **Proofs before done.** `sh tools/verify.sh core` must pass. `LAWS.bend` /
   `PROOF.bend` changes must keep `bend PROOF.bend` at `ALL PROOFS CHECK`.

## Workflow

- Branch off `main`, open a PR. Direct pushes to `main` are blocked.
- Both CI checks (`verify-core`, `native-conformance`) must be green.
- Merge is by merge commit; head branches are deleted automatically.
- Keep Bend toolchain assumptions pinned: Bend 2.0.40, `BEND_NO_TELEMETRY=1`.

## Local verification

```sh
sh tools/verify.sh core                    # proofs, smokes, batch IO tests
sh tools/verify.sh full                    # + native builds and differential oracles
python3 tools/differential.py commonmark --cmd /tmp/bendown-bin --timeout 5
```

The full differential comparison against Oliver requires a local Oliver binary
and is not part of CI; the corpus ratchets in CI are self-contained.
