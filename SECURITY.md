# Security policy

## Reporting

Please report vulnerabilities through GitHub's private security advisory flow
("Security" tab → "Report a vulnerability") rather than a public issue.

## Scope notes

- Parsers enforce an explicit input byte ceiling (default 64 MiB) before AST
  construction; inputs over the ceiling are rejected. Deliberately pathological
  but bounded inputs are a robustness concern, not a security boundary.
- bendown is a clean-room reimplementation experiment. It is not yet hardened
  for adversarial input the way the upstream Oliver project is, and it makes no
  memory-safety guarantees beyond what the Bend runtime provides.
- The batch CLI's directory discovery shells out to the platform `find` binary
  with a literal argv (no shell). Filenames containing newlines cannot be
  represented in that adapter.
