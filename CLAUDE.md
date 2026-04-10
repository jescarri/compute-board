# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A **KiCad 9.0** hardware project for a 4-layer PCB (controlled impedance to 50 Ω) that acts as a baseboard for an ESP32-powered compute module ecosystem. There is no firmware or application code here — it is a pure EDA project plus CI tooling.

Key files at the repo root:

- `compute-board.kicad_pro` / `.kicad_sch` / `.kicad_pcb` — the KiCad project
- `compute-board.kicad_dru` — **custom design rules**. Any DRC work must respect this file; KiBot/kicad-cli pick it up automatically when the PCB is opened.
- `kibot.yaml` — single source of truth for all CI outputs and preflights (see next section)
- `sym-lib-table` / `fp-lib-table` — project-local library tables. Symbols and footprints used by this board live under `parts/KiCad/` and are referenced via `${KIPRJMOD}/parts/KiCad/...`, so the project is self-contained and does not depend on KiCad global libraries for custom parts.
- `production/` — hand-curated fab output (gerbers zip, BOM, positions, IPC netlist). Generated via the Fabrication Toolkit plugin (config in `fabrication-toolkit-options.json`), not via CI. Do not overwrite unless the user asks.
- `compute-board-backups/` — KiCad's autosave backups, git-ignored.

## CI pipeline architecture

The CI system is the only "code" in this repo and is non-trivial. It's worth understanding as a whole before touching any single piece.

**Tool chain:** `INTI-CMNB/KiBot@v2_k9` (Docker action, pinned to the KiCad 9 image) drives `kicad-cli` to produce ERC, DRC, schematic PDF/SVG, per-layer PCB PDFs, PcbDraw stylized renders, ray-traced 3D renders, STEP file, and an HTML `navigate_results` index. All output definitions live in **`kibot.yaml`** — if you need a new artifact, add it there rather than scripting around KiBot.

**Publishing model:** outputs are published to the **`gh-pages` branch** (not via `actions/deploy-pages`) using `peaceiris/actions-gh-pages@v4` with `keep_files: true`. This is deliberate — per-PR previews must coexist with the main-branch site, which rules out the "build fresh site from scratch" flow. The site layout on `gh-pages` is:

```
/
├── index.html          auto-generated landing page (links to main + active PRs)
├── main/               latest build of the default branch
└── pr-<N>/<sha>/       per-PR, per-commit snapshots
```

Stable URLs: `https://jescarri.github.io/compute-board/main/...` for main, `.../pr-<N>/<sha>/...` for PRs. The README's auto-managed block and shields.io badges both depend on the `main/` path being stable — do not restructure it casually.

**Workflows:**

- `.github/workflows/kicad-ci.yml` runs on PRs and main pushes. Four jobs, with explicit `needs:` dependencies:
  1. `kibot` — runs KiBot, parses ERC/DRC JSON, generates shields.io badge JSON, uploads artifact, publishes to `gh-pages`. Uses `continue-on-error` so the comment can post even on failure; a trailing step re-fails the job if ERC/DRC had errors.
  2. `landing` — regenerates the root `index.html`. Runs on a `gh-pages-push` concurrency group to serialize with other gh-pages writers.
  3. `pr-comment` — on PRs, posts a sticky comment via `marocchino/sticky-pull-request-comment@v2` with header `kicad-ci`.
  4. `update-readme` — on main only, rewrites the `<!-- KICAD_CI:START --> … <!-- KICAD_CI:END -->` block in `README.md` and commits via `stefanzweifel/git-auto-commit-action@v5`.
- `.github/workflows/pr-cleanup.yml` runs on `pull_request.closed`, deletes `pr-<N>/` from `gh-pages`, regenerates the landing page.

**Loop prevention on the README auto-commit is defended in depth** — break any one of these and the CI will start looping on itself:

1. `paths-ignore: README.md` on the `push` trigger
2. `if: github.actor != 'github-actions[bot]'` on the `kibot` job
3. `[skip ci]` in the auto-commit message

**Helper scripts in `.github/scripts/`** are plain bash, kept out of the YAML for testability. They read inputs from env vars and either write to `$GITHUB_OUTPUT` or print to stdout. They are all `bash -n` clean and tested locally against fixtures. When modifying them, preserve the env-var contract — the workflow YAML passes specific names (`ERC_ERRORS`, `SITE_URL`, `COMMIT_SHA`, etc.).

## Commands

**Local KiBot dry-run** (requires the same Docker image CI uses — matches the CI environment exactly):

```bash
docker run --rm -v "$PWD:/work" -w /work ghcr.io/inti-cmnb/kicad9_auto:latest \
  kibot -c kibot.yaml -d out -e compute-board.kicad_sch -b compute-board.kicad_pcb
```

Outputs land in `./out/` (git-ignored territory — don't commit them). The `navigate_results` HTML index at `out/index.html` is the same file CI publishes; open it locally to preview what the PR comment will link to.

**Sanity-checking the CI scripts and workflows before committing:**

```bash
bash -n .github/scripts/*.sh
/usr/bin/python3 -c "import yaml; [yaml.safe_load(open(f)) for f in ['kibot.yaml', '.github/workflows/kicad-ci.yml', '.github/workflows/pr-cleanup.yml']]"
```

Note: the user's `~/.platformio/penv` Python has a broken PyYAML — use `/usr/bin/python3` explicitly.

**Dry-running individual helper scripts** (they are self-contained):

```bash
# Landing page against a fake site layout:
mkdir -p /tmp/ghp/{main,pr-5/abc1234}
bash .github/scripts/regen-landing.sh /tmp/ghp

# README block rewrite against a copy:
cp README.md /tmp/R.md && SITE_URL=https://jescarri.github.io/compute-board/main \
  COMMIT_SHA=abcdef1234 README_PATH=/tmp/R.md bash .github/scripts/update-readme.sh
```

**There is no test suite, build system, linter, or formatter** beyond the manual steps above. The "build" happens in CI.

## Rules learned from this repo

- **Do not reinvent kicad-cli in shell scripts.** `kibot.yaml` already covers ERC, DRC, schematic/PCB export, 3D rendering, STEP, and the HTML index. If you find yourself writing a loop over layer names or calling `kicad-cli` directly from a workflow, stop and add an output to `kibot.yaml` instead.
- **KiDiff is dormant** (last release April 2025); use `kibot`'s native `diff` / `kiri` outputs if a visual revision diff is needed.
- **The PCB has 4 copper layers** — `F.Cu`, `In1.Cu`, `In2.Cu`, `B.Cu`. The `pcb_print_pdf` output in `kibot.yaml` enumerates these explicitly; if the stackup changes, update the `pages:` list there.
- **Do not commit rendered previews to the repo.** An earlier `compute-board.png` was deleted precisely because it went stale the moment the board changed. The README's preview images must come from the `gh-pages` Pages URL, not from a tracked file.
- **The custom DRU file (`compute-board.kicad_dru`) is load-bearing.** DRC runs in CI will honor it automatically; do not duplicate its rules into KiBot config.
- **The `production/` directory is human-curated**, not generated by this CI pipeline. Leave it alone unless the user asks.
