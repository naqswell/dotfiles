# dotfiles

Personal macOS dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's tracked

| Package  | What it links into `~`                              |
|----------|------------------------------------------------------|
| `zsh`    | `~/.zshrc`, `~/.zprofile`                            |
| `git`    | `~/.gitconfig`, `~/.config/git/{ignore,config.mts}`  |
| `claude` | `~/.claude/settings.json` (theme, model, MTS guardrails) |
| `codex`  | `~/.codex/rules/default.rules`                       |
| `nvim`   | `~/.config/nvim/`                                    |

### How Stow lays this out

The "real" files live in `~/dotfiles/<package>/<path>`. Stow creates symlinks
at the equivalent path inside `~`, so the home dir looks normal but every
managed file is actually pointing into the git repo:

```
~/  (your $HOME)                                ~/dotfiles/  (this repo, in git)

  .zshrc                  ──symlink──►          zsh/.zshrc
  .zprofile               ──symlink──►          zsh/.zprofile
  .gitconfig              ──symlink──►          git/.gitconfig
  .config/git/
    ├ ignore              ──symlink──►          git/.config/git/ignore
    └ config.mts          ──symlink──►          git/.config/git/config.mts
  .config/nvim/           ──symlink──►          nvim/.config/nvim/
  .claude/
    └ settings.json       ──symlink──►          claude/.claude/settings.json
  .codex/rules/
    └ default.rules       ──symlink──►          codex/.codex/rules/default.rules

  .zshrc.local              (NOT a symlink, NOT in git — local secrets, chmod 600)
```

### How a new shell loads

```
new terminal opens
       │
       ▼
zsh sources ~/.zprofile  (symlink → dotfiles/zsh/.zprofile)
       │   ├─ brew shellenv → PATH
       │   ├─ mise activate zsh --shims → shims in PATH
       │   ├─ ANDROID_HOME, platform-tools, cmdline-tools, emulator
       │   └─ JAVA_HOME → mise-managed Temurin 21
       │
       ▼
zsh sources ~/.zshrc  (symlink → dotfiles/zsh/.zshrc)
       │
       ├─► line 1:  source ~/.zshrc.local           (per-machine layer)
       │             ├─ PROXY_HOME_URL, PROXY_IPHONE_URL, VPN_PROXY
       │             └─ ARTIFACTORY_USER/PASS  via  `security find-...`  ◄── Keychain
       │
       └─► rest:    aliases, functions, prompt, ZLE bindings,
                    plugins, JAVA_HOME, NO_PROXY, JetBrains, Docker
       │
       ▼
shell ready — env vars and functions in place
```

## What's NOT tracked

Kept local only — never committed:

- `~/.zshrc.local` — `VPN_PROXY` per-machine IPs, optionally Artifactory creds (or use Keychain — see below)
- `~/.codex/config.toml` — Codex CLI mutates it (project trust levels, marketplaces)
- `~/.codex/auth.json`, `~/.config/gh/` — OAuth tokens (live in Keychain via `gh`)
- `~/.ssh/*` — private keys
- `~/.zsh_history`, `~/.claude/{sessions,projects,telemetry,...}` — runtime state
- `~/bin/claude-desktop-vpn` — managed by [`claude-via-proxy`](https://github.com/naqswell/claude-via-proxy)'s `install.sh`

## Full bootstrap on a fresh Mac

End-to-end checklist for going from blank macOS to a working environment.

### 1. Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"   # add to shell for current session
```

### 2. Required CLIs

```bash
brew install stow gh
```

### 3. Authenticate gh and configure git credential helper

```bash
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
```

After this, `git push` to GitHub works without password prompts (token stored in macOS Keychain).

### 4. Clone dotfiles

```bash
git clone https://github.com/naqswell/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 5. Per-machine local file (`~/.zshrc.local`)

Copy the example and fill in real values:

```bash
cp examples/zshrc.local.example ~/.zshrc.local
chmod 600 ~/.zshrc.local
$EDITOR ~/.zshrc.local
```

At minimum, set the proxy URLs (the IPs of the device running your HTTP proxy):

```bash
export PROXY_HOME_URL='http://192.168.1.X:8080'
export PROXY_IPHONE_URL='http://172.20.10.7:8080'
export VPN_PROXY="$PROXY_HOME_URL"
```

### 6. Artifactory credentials in Keychain (recommended)

If you work with the corporate Maven/Artifactory, store creds in macOS Keychain rather than plain text in `~/.zshrc.local`:

```bash
security add-generic-password -a "$USER" -s ARTIFACTORY_USER -w 'your_user'
security add-generic-password -a "$USER" -s ARTIFACTORY_PASS -w 'your_pass_or_token'
```

Then in `~/.zshrc.local` (already in the example template):

```bash
export ARTIFACTORY_USER="$(security find-generic-password -a "$USER" -s ARTIFACTORY_USER -w 2>/dev/null)"
export ARTIFACTORY_PASS="$(security find-generic-password -a "$USER" -s ARTIFACTORY_PASS -w 2>/dev/null)"
```

### 7. Stow all packages

```bash
cd ~/dotfiles
stow zsh git claude codex nvim
```

This creates symlinks from `~/...` into `~/dotfiles/<package>/...`.

### 8. mise + Java 21

```bash
brew install mise
mise install java@temurin-21
mise use --global java@temurin-21
```

`~/.zprofile` already activates mise via `--shims` and sets `JAVA_HOME` — no extra steps needed.

To switch Java version per-project:

```bash
cd ~/my-project
mise use java@temurin-17   # writes .mise.toml, auto-activates in this dir
```

### 9. Open a new terminal

A new shell reads the linked `~/.zshrc`, sources `~/.zshrc.local`, sets `JAVA_HOME`, `ANDROID_HOME`, `VPN_PROXY`, etc.

### 10. (Optional) Sibling repos

Two related private repos work together with this dotfiles setup:

```bash
# Layered AI-agent rules for MTS workspace
git clone https://github.com/naqswell/agents-work-setup.git "$HOME/!!MTS"

# Route Claude (CLI + Desktop) through HTTP proxy on Android
git clone https://github.com/naqswell/claude-via-proxy.git ~/Documents/claude-via-proxy
~/Documents/claude-via-proxy/install.sh --home-ip <phone-ip> --port 8080   # only if needed
```

### 11. Verify

Quick smoke test in a fresh terminal:

```bash
echo "$VPN_PROXY"                            # should print http://...
security find-generic-password -a "$USER" -s ARTIFACTORY_USER -w   # should print value
ls -la ~/.zshrc                              # should be a symlink → dotfiles/zsh/.zshrc
cd ~ && git config user.email                # personal email
cd ~/!!MTS && git config user.email          # corporate email
java -version                                # should print openjdk 21
which sdkmanager emulator                    # should resolve to $ANDROID_HOME/...
```

## Identity switching

`~/.gitconfig` uses the personal identity globally. Inside `~/!!MTS/`, an `includeIf` directive switches to `~/.config/git/config.mts` automatically:

```ini
# in ~/.gitconfig
[includeIf "gitdir:~/!!MTS/"]
    path = ~/.config/git/config.mts
```

```
You run a git command in...
       │
       ├── ~/anywhere outside ~/!!MTS         ──►  user.name  = naqswell
       │                                           user.email = naqswell@gmail.com
       │
       └── ~/!!MTS/<any subproject>           ──►  user.name  = IvanovNA
                                                   user.email = ivanovna@mtsbank.ru
```

## Editing files

Edit the symlinked path directly:

```bash
$EDITOR ~/.zshrc           # edits dotfiles/zsh/.zshrc through the symlink
cd ~/dotfiles
git diff
git commit -am "add alias gw"
git push
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

## Recovery / rollback

If something goes wrong (broken symlink, bad edit, want to revert to previous setup):

### Disable a single package

```bash
cd ~/dotfiles && stow -D zsh   # removes ~/.zshrc and ~/.zprofile symlinks
```

### Disable all packages

```bash
cd ~/dotfiles && stow -D zsh git claude codex nvim
```

After this, `~` has no symlinks left from this repo. The actual files still exist in `~/dotfiles/<package>/` — nothing is deleted.

### Restore from pre-migration backup

The initial migration created backups:

```bash
ls -la ~/.zshrc.backup-* ~/.gitconfig.backup-*
```

To restore:

```bash
cd ~/dotfiles && stow -D zsh git
cp ~/.zshrc.backup-YYYYMMDD-HHMM     ~/.zshrc
cp ~/.gitconfig.backup-YYYYMMDD-HHMM ~/.gitconfig
exec zsh
```

### Verify everything is OK after recovery

```bash
type proxy-home proxy-iphone proxy-check claude-vpn   # functions/aliases defined?
echo "$VPN_PROXY"                                     # variable set?
git config user.email                                 # right identity?
```

### Re-stow after recovery

If you reverted, then later want to go back to dotfiles management:

```bash
# remove the restored files
rm ~/.zshrc ~/.gitconfig

# stow again
cd ~/dotfiles && stow zsh git
```

## Related repos

- **[agents-work-setup](https://github.com/naqswell/agents-work-setup)** — common AI-agent rules (`AGENTS.md`/`CLAUDE.md`) for MTS workspace; lives in `~/!!MTS/`
- **[claude-via-proxy](https://github.com/naqswell/claude-via-proxy)** — route Claude (CLI + Desktop) through an HTTP proxy on a dedicated Android phone (any VPN as upstream)
