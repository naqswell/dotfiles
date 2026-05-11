# Changelog

All notable changes to this dotfiles repo. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [2026-05-11]

### Added
- `mise activate zsh --shims` in `.zprofile` — runtime version management (Java, Node, etc.)
- `JAVA_HOME` pointing to mise-managed Temurin 21.0.11
- `$ANDROID_HOME/cmdline-tools/latest/bin` in PATH — `sdkmanager` available in terminal
- `$ANDROID_HOME/emulator` in PATH — `emulator` command available in terminal
- Bootstrap step 8 in README: mise + Java 21 setup and per-project version switching

- `claude/.claude/settings.json`: `permissions.deny` blocking writes to `cacerts*`, `*.jks`, `local.properties`, `gradle/init.d/**` and bash `git push` / `glab mr create` / `gh pr create` — enforces MTS workspace rules previously documented only in `!!MTS/AGENTS.md`
- `claude/.claude/settings.json`: hooks scoped to `~/!!MTS/` workspace via `${PWD#…}` guard — `SessionStart` prints pwd + git branch; `PreToolUse` denies bare `./gradlew` from `!!MTS/platsdk` (no worktree picked); `PostToolUse` prints a detekt reminder after editing `*.kt`
- `.gitignore`: ignore `*.bak`, `*.orig`, `*.swp` (editor scratch backups)

### Changed
- `JAVA_HOME`: was Microsoft JDK 17 (manual), now Temurin 21 managed by mise
- `claude/settings.json`: removed hardcoded `"model": "opus"` — inherits from CLI default

## [2026-05-09] — initial android setup

### Added
- `ANDROID_HOME` and `platform-tools` PATH in `.zprofile`

## [2025-XX-XX] — initial commit

### Added
- GNU Stow setup: packages `zsh`, `git`, `claude`, `codex`, `nvim`
- `git/.gitconfig` with `includeIf` for MTS identity switching
- `claude/.claude/settings.json` with theme and agent settings
- Full bootstrap guide and recovery section in README
