# dotfiles

Personal macOS dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's tracked

| Package  | What it links into `~`                  |
|----------|------------------------------------------|
| `zsh`    | `~/.zshrc`, `~/.zprofile`                |
| `git`    | `~/.gitconfig`, `~/.config/git/{ignore,config.mts}` |
| `claude` | `~/.claude/settings.json`                |
| `nvim`   | `~/.config/nvim/`                        |

## Install on a fresh Mac

```bash
brew install stow
git clone git@github.com:naqswell/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Per-machine secrets (NOT in git) — copy and edit
cp examples/zshrc.local.example ~/.zshrc.local
chmod 600 ~/.zshrc.local
$EDITOR ~/.zshrc.local

# Create symlinks
stow zsh git claude nvim
```

Open a new shell — environment is restored.

## What's NOT tracked

Files deliberately excluded (kept local only):

- `~/.zshrc.local` — Artifactory creds, Amnezia proxy IPs, anything secret/per-machine
- `~/.codex/config.toml` — Codex CLI mutates it (project trust levels, marketplaces)
- `~/.codex/auth.json`, `~/.config/gh/` — OAuth tokens
- `~/.ssh/*` — private keys
- `~/.zsh_history`, `~/.claude/{sessions,projects,telemetry,...}` — runtime state
- `~/bin/claude-desktop-vpn` — managed by `~/Documents/claude-via-amnezia/install.sh`

## Identity switching

`~/.gitconfig` sets the personal identity globally. For corporate work inside `~/!!MTS/`, an `includeIf` directive switches to `~/.config/git/config.mts` automatically:

```ini
# in ~/.gitconfig
[includeIf "gitdir:~/!!MTS/"]
    path = ~/.config/git/config.mts
```

Verify after install:

```bash
cd ~/             && git config --get user.email   # → personal
cd ~/!!MTS/<any>  && git config --get user.email   # → corporate
```

## Adding a new package

```bash
mkdir -p ~/dotfiles/<name>/<path-relative-to-home>
mv ~/<original-file> ~/dotfiles/<name>/<...>/<original-file>
cd ~/dotfiles && stow <name>
```

## Removing a package (uninstall its symlinks)

```bash
cd ~/dotfiles && stow -D <name>
```

## After editing files

Edit the symlinked file directly — actual write goes into `~/dotfiles/<package>/...`. Then commit.
