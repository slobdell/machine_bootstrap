# Task: turn `~/Desktop/MAKE_THIS_A_GIT_REPO` into a clean, shareable git repository

You are helping me convert a directory of machine-bootstrapping scripts and
dotfiles into a proper git repository that I can push to GitHub. The directory
lives at:

    /home/slobdell/Desktop/MAKE_THIS_A_GIT_REPO

**The whole point of this repo:** when I bring a new Ubuntu machine online I want
to `git clone` this, run a bootstrap script, and get a working dev environment
(vim + colorschemes, screen, git identity, ZeroTier, ComfyUI, arduino tooling,
etc.). So the scripts must stay *runnable* — the job is to make them clean and
parameterized, not to gut them.

**The gate: this cannot be committed until it is free of PII and secrets.** That
is the entire reason it isn't a repo yet. Do the scrub FIRST, prove it's clean,
show me a summary, and only then initialize git and make the first commit.

---

## What the directory contains (survey it yourself first)

Top-level files are my own (scrub/parameterize these):
- `bootstrap_machine.sh` — the main machine bootstrap (apt packages, arduino-cli, groups)
- `install_vim.sh`, `.vimrc`, `.screenrc` — editor/terminal dotfiles
- `setup_git.sh` — git identity + SSH key generation + a repo clone
- `zerotier.sh` — joins my ZeroTier network
- `setup_comfy.sh`, `setup_cpu_flux.sh`, `comfy_instructions.md` — ComfyUI setup
- `ComfyUI/` — a **vendored third-party checkout** (has its own `.git/`, a `venv/`,
  and `models/`, `input/`, `output/` dirs). This must NOT go into the new repo as
  content (see below).

---

## Step 1 — Scrub PII and secrets (do this before `git init`)

I already know about these specific hits. Fix every one, then grep for MORE —
treat this list as a starting point, not the full set:

| File:line | What's there | What to do |
|---|---|---|
| `setup_git.sh` | `git config --global user.email "scott.lobdell@gmail.com"` (x2, also in the `ssh-keygen -C`) | Replace with a placeholder read from a variable / prompt, e.g. `${GIT_EMAIL:?set GIT_EMAIL}`, or read interactively. Do not hardcode my email. |
| `setup_git.sh` | `git clone git@github.com:slobdell/led-drone-microcontrollers.git` | Remove or parameterize — it leaks my GitHub username and a private repo name. |
| `zerotier.sh` | `zerotier-cli join f3797ba7a8546f34` | **This network ID is effectively a secret** (anyone with it can request to join my LAN). Move it to an untracked local config value, e.g. `zerotier-cli join "${ZEROTIER_NETWORK_ID:?}"`, and document that the user supplies their own. |
| `bootstrap_machine.sh` | hardcoded `slobdell` (`usermod -a -G dialout slobdell`), `/home/slobdell/Arduino`, `/home/slobdell/.arduino15` | Use `$USER` and `$HOME` instead of the literal username/path. The file even has a comment admitting the hardcode. |
| `install_vim.sh` | `DEV_USER="slobdell"` | Default to `${DEV_USER:-$USER}`. |

Then **run a fresh secret sweep yourself** over the whole tree (excluding
`ComfyUI/`, which is third-party) and confirm it comes back empty before
committing. At minimum grep for:

```bash
grep -rInE 'slobdell|scott\.lobdell|@gmail|@[a-z]+\.(com|net|org)|api[_-]?key|secret|token|password|BEGIN [A-Z ]*PRIVATE|ssh-(rsa|ed25519) AAAA|[0-9]{1,3}(\.[0-9]{1,3}){3}' \
  --exclude-dir=ComfyUI --exclude-dir=.git .
```

Also check for actual key material that may have landed on disk (`id_ed25519`,
`id_rsa`, `*.pem`, `.env`, `.netrc`, `.git-credentials`, any AWS/HF/OpenAI token
files). `setup_git.sh` *generates* an SSH key at runtime into `~/.ssh` — make
sure no generated private key is sitting inside this directory.

**Parameterization pattern:** prefer a single `config.env.example` at the repo
root (checked in) listing every value the user must set — `GIT_NAME`,
`GIT_EMAIL`, `ZEROTIER_NETWORK_ID`, `DEV_USER`, `GITHUB_USER` — with the real
`config.env` git-ignored and `source`d by the scripts. That keeps the scripts
runnable while nothing personal is committed.

## Step 2 — Handle the vendored `ComfyUI/` checkout

`ComfyUI/` is a full upstream clone with its own `.git/`, a `venv/`, and large
`models/`/`input/`/`output/` dirs. Do **not** commit it as files (a nested `.git`
becomes a broken pseudo-submodule, and the weights/venv are huge and not mine).
Pick the cleanest option and tell me which you chose:
- **Preferred:** remove the `ComfyUI/` checkout from the working tree entirely and
  make `setup_comfy.sh` responsible for `git clone`-ing upstream ComfyUI at a
  pinned commit/tag into that path. Add `ComfyUI/` to `.gitignore`.
- **Alternative:** add ComfyUI as a real git submodule pinned to a specific
  upstream commit (only if `setup_comfy.sh` genuinely depends on a local edit).

Either way, confirm `models/`, `venv/`, `output/`, `input/` never get committed.

## Step 3 — Add a `.gitignore`

Cover at least: `ComfyUI/` (or its `venv/ models/ output/ input/` if submoduled),
`**/venv/`, `**/__pycache__/`, `*.pyc`, `config.env`, `.env`, `*.pem`,
`id_ed25519*`, `id_rsa*`, `.DS_Store`.

## Step 4 — Add a `README.md`

Short: what this repo is (personal machine bootstrap), the order to run the
scripts in, and the "copy `config.env.example` → `config.env` and fill it in"
step. Rename the directory concept away from `MAKE_THIS_A_GIT_REPO` in the README
(e.g. call it "dotfiles" / "machine-bootstrap").

## Step 5 — Initialize and verify (only after the scrub is clean)

```bash
cd /home/slobdell/Desktop/MAKE_THIS_A_GIT_REPO
git init
git add -A
git status              # eyeball: no venv, no models, no ComfyUI/.git, no secrets
git diff --cached | grep -InE 'slobdell|@gmail|f3797ba7a8546f34|BEGIN .*PRIVATE'   # must be EMPTY
```

If that grep is empty and `git status` looks clean, make the initial commit
(sign it however I normally do). **Do not push to any remote** — I'll create the
GitHub repo and push myself. Before committing, print me a summary of: every PII
change you made, how you handled `ComfyUI/`, and the final file list being
committed.

## Constraints
- Keep every script runnable — parameterize, don't delete functionality.
- Don't touch anything outside `~/Desktop/MAKE_THIS_A_GIT_REPO`.
- Do not push, do not create a GitHub repo — stop at the local initial commit.
- If you're unsure whether something is PII, treat it as PII and ask me.
