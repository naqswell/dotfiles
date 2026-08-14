# Changelog

All notable changes to this dotfiles repo. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- `claude/.claude/skills/apk-send/SKILL.md` — скилл отправки собранного APK в «Избранное» Telegram. Сам скрипт живёт в `remote-work-setup/bin/apk-send` (tdl поверх локального xray: Telegram с этой машины напрямую недоступен). Скилл нужен, чтобы агент знал про команду из любого репозитория, и запрещает вызывать `tdl` напрямую в обход предохранителей «только .apk» и «только Избранное». Плюс опциональный `pre-push` хук (`apk-send hook install`): шлёт сборку при пуше, но только если она новее последнего коммита, в фоне и никогда не отменяя push
- `claude/.claude/commands/release-platsdk.md` — слэш-команда релиза platsdk: back-merge прошлого релиза в `develop`, релизная ветка в отдельном worktree, бамп версии, CHANGELOG из git log + Jira, `assembleDebug detekt` до тега, аннотированный тег `v<version>`, `--publish=local|remote|none`
- `claude/.claude/commands/mymts-platsdk-bump.md` — слэш-команда бампа `mts-plat-sdk` в mymts и подготовки MR: `feature` от `develop`, `bugfix` от последней `release/*`, MR целится в ту же ветку, от которой отведён
- `claude/.claude/settings.json`: `deny` на `glab mr merge*`, `git tag -d*`, `./gradlew publishRelease*` — необратимые действия выполняет пользователь, не агент. `publishLocal` (пишет только в `~/.m2`) сознательно разрешён

### Changed
- `claude/.claude/settings.json`: подхвачены правки, сделанные самим Claude Code через UI — плагин `pr-review-toolkit`, `skipWorkflowUsageWarning`, `effortLevel: xhigh`
- `claude/.claude/commands/release-platsdk.md`: back-merge релиза в `develop` перенесён из начала следующего релиза в конец текущего (шаг 10, сразу после тега и публикации). В начале осталась проверка-страховка на случай релиза, выпущенного вручную. Раньше `develop` отставал на версию до самого старта следующего релиза

## [2026-05-14]

### Added
- `zsh/.zshrc`: subcommand-pattern wrappers `claude vpn / codex vpn / claudedesk vpn / codexdesk vpn / chatgpt vpn` — запуск CLI/GUI через `$VPN_PROXY`, без подкоманды `vpn` — обычный запуск
- `zsh/.zshrc`: `.mtsbank.ru` в `NO_PROXY` (CLI к банковским доменам обходит VPN-прокси, идёт через Citrix)

### Removed
- `zsh/.zshrc`: алиасы `claude-vpn`, `clv`, `claude-desktop-vpn`, `cldv` — заменены на subcommand-функции
- `zsh/.zshrc`: wrapper-функция `chatgpt vpn` — ChatGPT.app (native Swift, URLSession) игнорирует `HTTPS_PROXY` / `--proxy-server`. Для проксирования нужен системный прокси macOS или веб-версия через Zen-браузер

### Changed
- `claude/.claude/settings.json`: cosmetic JSON cleanup (Claude Code нормализовал порядок ключей, удалил недопустимые JSON-комментарии `_commentAllow` / `_commentDeny`)

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
