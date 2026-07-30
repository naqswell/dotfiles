# dotfiles — правила для AI-агентов

Репозиторий `~/dotfiles/` — GNU Stow, личный конфиг macOS. Поведение агента (язык, запрет
автокоммитов и автоподписей, показ команд) задано в `~/.claude/CLAUDE.md`; здесь только то,
что специфично для этого репозитория.

---

## Контекст

- Реальные файлы в `~/dotfiles/<package>/`, симлинки в `~` — правь реальный путь, не симлинк.
- Remote: `github.com/naqswell/dotfiles` (private). Push идёт через `gh` credential helper:
  токен берётся из Keychain, прокси не нужен.
- Перед `brew install` — `unset HTTP_PROXY HTTPS_PROXY`.

## Гочи

- `.zprofile`, `.zshrc` и `.zshrc.local` включают друг друга перекрёстно — прежде чем менять
  порядок загрузки, читай все три целиком.
- `~/.zshrc.local` не в git и не редактируется: там локальные секреты и прокси-URL.

## CHANGELOG и README

- `CHANGELOG.md` в корне, формат [Keep a Changelog](https://keepachangelog.com/en/1.1.0/):
  изменение → запись в `[Unreleased]`, при коммите переносится под дату `[YYYY-MM-DD]`.
- `README.md` описывает загрузку шелла и bootstrap на чистом Mac; чеклист «Full bootstrap» должен
  оставаться воспроизводимым. Правка `.zprofile` или структуры пакетов расходится с README и
  диаграммой «How a new shell loads» — обновляй их вместе.
