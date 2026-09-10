# Changelog

All notable changes to this dotfiles repo. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed
- `scripts/agent-setup.py`: скилл, входящий в какой-нибудь плагин, больше не раскатывается плоским симлинком в `~/.claude/skills` — иначе Claude показывает его дважды и дважды платит за него контекстом. Членство в плагине читается из самого плагина, отдельного списка нет. Снятие устаревшего симлинка проведено через новую функцию `unlink` с `APPLY`/`CHANGES`/бэкапом: первая версия правки удаляла симлинк даже в режиме `plan`, который менять состояние не должен. `check()` теперь пропускает каталоги плагинов — своего `SKILL.md` у них нет, и он засчитывал их в ошибки
- `zsh/.zshrc`: обычный `codex` теперь запускается через `$VPN_PROXY`; вызов `codex vpn` сохранён для совместимости.

### Added
- `claude/.claude/skills/nqs/` — локальный плагин Claude Code, собирающий скиллы доставки в одно семейство: вызов выглядит как `nqs:report-qa`. Внутри только манифест и симлинки, сами каталоги остаются в `agents/skills` и раскатываются плоско в `~/.agents/skills`. Так сделано потому, что плагин понимает один Claude Code: omp читает `~/.agents/skills` и держит провайдер `claude-plugins` в opt-out, `~/.pi/agent/skills` и `~/.factory/skills` — симлинки туда же, Codex читает свой `~/.codex/skills`, а Orca скиллы не читает, а раздаёт в `~/.agents/skills` и ведёт учёт в `~/.agents/.skill-lock.json`. Переезд целиком в плагин отнял бы скиллы у всех, кроме Claude. Обоснование целиком: `remote-work-setup/docs/adr/0001-plagin-i-ploskie-skilly.md`
- `agents/skills/send-gallery/SKILL.md` — отправка галереи скриншотов platsdk в «Избранное»: целиком через `packScreenshots` либо срезом только из изменившихся кадров через `platsdk-baseline` и `gallery-diff`
- `agents/skills/report-ui/SKILL.md` — отчёт о UI-изменениях для автора правки: пары кадров «до/после» по одному на затронутый экран, сводка расхождений и дельта находок автопроверки
- `agents/skills/report-qa/SKILL.md` — отчёт для мануального тестировщика: сборка и текст без единой отсылки к коду, тремя разделами «что изменилось», «как проверить» и «чего проверить нельзя». Третий раздел обязателен: часть диффа наружу через интерфейс не выходит, и молчать об этом значит либо потерять её, либо выдать ненаблюдаемое за проверяемое
- `agents/skills/report-design/SKILL.md` — отчёт для дизайнера: срез галереи, по кадру на затронутый экран и блок «чего на картинках не увидеть» — экраны, тронутые в коде, но не покрытые матрицей. Три отчёта отличаются линзой, а не адресатом: приходят все в «Избранное» автора. Единственный источник фактов во всех трёх — git; память сессии фактом не считается, потому что за сессию бывает три подхода к задаче, два из которых откачены

Выбор скилла проверен headless-вызовом в новой сессии на восьми формулировках: «скинь сборку» → `nqs:apk-send`, «отчёт для тестировщика» и «что тестировать в этой сборке» → `nqs:report-qa`, «покажи что поменялось в UI» → `nqs:report-ui`, «отчёт для дизайнера» → `nqs:report-design`, «отправь zip галереи» → `nqs:send-gallery`, «покажи файл с макбука» → `gimme`. Отдельно проверена ловушка «скинь эту сборку **тестировщику**»: уходит в `report-qa`, а не в `apk-send`, хотя описание последнего содержит слово «тестировщику»
- `scripts/agent-policy.py`: запрет агентам скачивать, монтировать, ставить и запускать чужие приложения — `hdiutil attach`, `curl`/`wget` за `.dmg`/`.pkg`, `curl | sh`, `installer -pkg`, `brew --cask`, `mas install`, снятие `com.apple.quarantine`, `spctl --master-disable`, запись в `/Applications`, `open` для `.app`/`.dmg`/`.pkg`, прямой запуск `*.app/Contents/MacOS/*`. Повод: разведка аналогов Haptyk 09.09.2026 — подагенты скачали и смонтировали десяток DMG и прогнали по ним Gatekeeper-проверки, пользователь в это время отклонял поток системных диалогов и решил, что ему молча ставят софт. Ничего установлено не было, но работа прерывалась многократно. Проверять приложения полагается по GitHub/Homebrew/iTunes API, а чего так не выяснить — писать «локально не проверял». Правило висит на `matcher: "*"`, то есть накрывает и подагентов. Разрешение на сессию даёт только пользователь: `touch ~/.claude/installs-allowed`; команды, упоминающие это имя, отбиваются отдельно, иначе агент разблокировал бы себя сам. `git clone` сознательно не блокируется — он не дёргает диалогов и ломал бы обычную работу
- `zsh/.zshrc`: функции `orcaemu` + обёртка `miniemu` — Android-эмулятор, который физически крутится на Mac mini, на экране этого макбука одной командой. Цепочка: `ssh -L <lport>:127.0.0.1:5555 mac-mini` → `adb connect localhost:<lport>` → `scrcpy`. Туннель делает удалённый эмулятор **локальным** adb-девайсом — поэтому его видит и Orca (`--orca`), у которой remote/SSH device control официально out of scope. Дефолт — окно scrcpy: оно не зависит от worktree Orca и даёт контроль нагрузки (`--fps`, `--bitrate`, `--maxsize`), тогда как панель Orca привязана к worktree вкладки и из чужой вкладки отвечает `selector_not_found`. `--light`/`--native` (`wm size 540x960` / reset) — даунскейл самого эмулятора, единственный рычаг в режиме Orca, где fps и битрейт зашиты во внутренние дефолты. Только на макбуке: guard `$USER != nqs-desktop`
- `zsh/.zshrc`: `miniemu coldboot` (`orcaemu --cold`) — гасит эмулятор на хосте (`adb emu kill`), ждёт освобождения порта, поднимает AVD с `-no-snapshot` и ждёт `boot_completed`. Нужен, когда снапшот протаскивает сломанное состояние из прошлой сессии
- `zsh/.zshrc`: `miniemu status` и `orcaemu --help` / `miniemu --help` — диагностика по слоям (эмулятор на mini, ssh-туннель, локальный adb, окно scrcpy) плюс хвост `/tmp/emu-5554.log`. Появились после разбора «miniemu молча не показывает экран»: слои ломаются независимо, а способа увидеть, какой именно, не было
- `claude/.claude/settings.json`: блок `env` с `HTTPS_PROXY`/`HTTP_PROXY` на локальный xray и `NO_PROXY`. Обёртка `claude vpn` ставила прокси только тому процессу, который запущена руками из интерактивного zsh; сессии, которые поднимает Orca (а также launchd и background-supervisor), шли мимо неё и умирали на `api.anthropic.com`. `env` из settings.json читается при любом запуске бинаря и перекрывает переменные шелла — то есть `proxy-iphone` на claude больше не влияет (на `codex`/`builder` влияет по-прежнему). `NO_PROXY` продублирован из `zsh/.zshrc` — держать значения в синхроне, иначе корп-домены уйдут в xray в сессиях без шелла
- `claude/.claude/skills/apk-send/SKILL.md` — скилл отправки собранного APK в «Избранное» Telegram. Сам скрипт живёт в `remote-work-setup/bin/apk-send` (tdl поверх локального xray: Telegram с этой машины напрямую недоступен). Скилл нужен, чтобы агент знал про команду из любого репозитория, и запрещает вызывать `tdl` напрямую в обход предохранителей «только .apk» и «только Избранное». Плюс опциональный `pre-push` хук (`apk-send hook install`): шлёт сборку при пуше, но только если она новее последнего коммита, в фоне и никогда не отменяя push
- `claude/.claude/commands/release-platsdk.md` — слэш-команда релиза platsdk: back-merge прошлого релиза в `develop`, релизная ветка в отдельном worktree, бамп версии, CHANGELOG из git log + Jira, `assembleDebug detekt` до тега, аннотированный тег `v<version>`, `--publish=local|remote|none`
- `claude/.claude/commands/mymts-platsdk-bump.md` — слэш-команда бампа `mts-plat-sdk` в mymts и подготовки MR: `feature` от `develop`, `bugfix` от последней `release/*`, MR целится в ту же ветку, от которой отведён
- `claude/.claude/settings.json`: `deny` на `glab mr merge*`, `git tag -d*`, `./gradlew publishRelease*` — необратимые действия выполняет пользователь, не агент. `publishLocal` (пишет только в `~/.m2`) сознательно разрешён

### Changed
- `zsh/.zshrc`: старт AVD на хосте больше не вложен в проверку ssh-туннеля — залипший туннель маскировал мёртвый эмулятор (локально порт открыт, за ним пусто), и весь блок авто-старта молча пропускался. Залипший туннель теперь опознаётся по `adb get-state` и пересоздаётся; `unauthorized` после wipe или пересоздания AVD чинится сам (`uiautomator dump` по ssh → тап по «Always allow from this computer»), потому что локальный adb в этот момент бесправен и сделать это может только хост; scrcpy не стартует вслепую — при `state != device` печатает причину и возвращает 1
- `claude/.claude/settings.json`: подхвачены правки, сделанные самим Claude Code через UI — плагин `pr-review-toolkit`, `skipWorkflowUsageWarning`, `effortLevel: xhigh`
- `claude/.claude/commands/release-platsdk.md`: back-merge релиза в `develop` перенесён из начала следующего релиза в конец текущего (шаг 10, сразу после тега и публикации). В начале осталась проверка-страховка на случай релиза, выпущенного вручную. Раньше `develop` отставал на версию до самого старта следующего релиза

### Fixed
- `zsh/.zshrc`: `miniemu` не показывал экран — на mini не осталось AVD `small_phone_api36` (его место занял `mts_mitm_api36`), а живой эмулятор слушал console 5556 / adb 5557, тогда как `miniemu` жёстко ходил в 5555. Дефолтный AVD обновлён; adb-порт больше не зашит — `orcaemu` спрашивает его у хоста (`adb devices` → `emulator-<console>` → console+1) и берёт, если `--rport` не задан явно. `miniemu` сознательно **не** передаёт `--rport`: явный флаг выключил бы автоопределение и вернул ту же поломку при следующем сдвиге порта (5554 занят → инстанс уезжает на 5556). Явный `--rport` остаётся способом дотянуться до конкретного эмулятора из нескольких
- `zsh/.zshrc`: отсутствующий на хосте AVD теперь виден сразу — `_orcaemu_check_avd` печатает «нет AVD X, есть: …» и возвращает 1 перед стартом. Раньше `emulator` тихо падал в `/tmp/emu-*.log` с `Unknown AVD name`, а команда рапортовала «headless-старт…» и висела на `wait-for-device`; причину было видно только в хвосте лога через `miniemu status`
- `zsh/.zshrc`: `miniemu status` считает порт по тому же правилу (вычисляет удалённая сторона в том же единственном ssh) — с хардкодом 5555 он рапортовал «эмулятор НЕ ЗАПУЩЕН» про живой эмулятор на 5556 и тянул хвост не того лога

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
