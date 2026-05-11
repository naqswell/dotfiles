# dotfiles — rules for AI coding agents

Применяется к репо `~/dotfiles/` (GNU Stow, personal macOS config).

---

## Контекст

- Файлы управляются через GNU Stow: реальные файлы в `~/dotfiles/<package>/`, симлинки в `~`.
- Remote: `github.com/naqswell/dotfiles` (private). Push через `gh` credential helper.
- Без прокси для brew: `unset HTTP_PROXY HTTPS_PROXY` перед `brew install`.

## Конвенции работы

### Редактирование файлов
- Всегда редактируй реальный путь в `~/dotfiles/`, не симлинк в `~`.
- Перед правкой — читай файл целиком; `.zprofile` и `.zshrc` могут включать друг друга через `.zshrc.local`.
- Не трогай `~/.zshrc.local` — он локальный, не в git.

### CHANGELOG
- Файл: `CHANGELOG.md` в корне репо, формат [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
- Любое изменение → запись в `[Unreleased]` (Added / Changed / Removed / Fixed).
- При коммите → переносим `[Unreleased]` под дату `[YYYY-MM-DD]`.

### README
- Обновляй `README.md` при каждом изменении `.zprofile` или структуры пакетов.
- Диаграмма "How a new shell loads" должна отражать актуальный `.zprofile`.
- Bootstrap-чеклист (секция "Full bootstrap") должен быть воспроизводим на чистом Mac.

### Коммиты и push
- Не коммитить и не пушить автоматически — только по явной просьбе.
- Без `Co-Authored-By` и автоподписей агента.
- Push: `git push` (gh credential helper подхватывает токен из Keychain, прокси не нужен).

### Команды
- Всегда показывай конкретную команду перед запуском.
