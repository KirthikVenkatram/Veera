# DevSecOps — Veera

How to run the local guardrails. The goal is "secrets never reach the remote",
not "every PR ships a SBOM" — Veera is a single-developer personal app.

## Pre-commit hooks (gitleaks + sanity checks)

Veera uses [pre-commit](https://pre-commit.com) to run `gitleaks` and a small
set of hygiene checks before every commit. Setup is once per clone.

```sh
# 1. Install pre-commit (one-time, machine-wide). Homebrew is the simplest path.
brew install pre-commit

# 2. From the repo root, install the git hooks.
pre-commit install

# 3. (Optional) Run all hooks against every tracked file once, to catch
#    anything that was already in history.
pre-commit run --all-files
```

After step 2, `git commit` will run the hooks automatically. To bypass on a
specific commit (use sparingly): `git commit --no-verify`.

### What runs

- **gitleaks** — scans the staged diff against the default ruleset plus
  Veera-specific allowlists in `.gitleaks.toml`. Catches API keys, tokens,
  private keys, and high-entropy strings.
- **pre-commit hygiene set** — trailing whitespace, EOF newline,
  YAML well-formedness, merge-conflict markers, and a 2 MB max-file-size
  cap (so we don't accidentally commit binary blobs).

## Dependabot

`.github/dependabot.yml` watches:
- Swift Package Manager dependencies (currently zero — runs as a guardrail).
- GitHub Actions versions used by `.github/workflows/ci.yml`.

Cadence is **weekly** on Monday morning IST. PRs land with the `dependencies`
or `ci` label; review and merge manually.

## CI

`.github/workflows/ci.yml` runs `xcodebuild build` and `xcodebuild test`, plus
`swiftlint --strict`, on every push and pull request. Future additions
(semgrep, broader OSLog coverage assertions) are tracked in CLAUDE.md
"Next work".

## What's not here yet

- **semgrep** — Phase 4 of the current roadmap. Will add Swift and
  security-audit rule packs.
- **SBOM / reproducible builds** — out of scope per `THREAT_MODEL.md`.
- **CodeQL** — Apple's toolchain doesn't support it for Swift natively;
  semgrep is the substitute.
