---
description: Выпуск новой версии platsdk — релизная ветка, бамп, CHANGELOG, сборка, тег, публикация, back-merge в develop
argument-hint: <patch|minor|major|X.Y.Z> [TICKET|jira-url] [--publish=local|remote|none]
allowed-tools: Bash(git*), Bash(./gradlew*), Read, Edit, Grep, AskUserQuestion, mcp__atlassian__jira_get_issue
---

Ты ведёшь релиз platsdk в `~/mts/platsdk/`. Репозиторий использует git worktrees:
контейнер `~/mts/platsdk/`, актуальный список —
`git -C '/Users/nqs-desktop/mts/platsdk/master' worktree list`.

## Железные правила

1. **Никогда не выполняй сам:** `git push`, `git tag -d`, любые `--force`,
   `./gradlew publishRelease`. Это делает пользователь.
   Дойдя до такого шага — выведи точную команду одной строкой в блоке кода,
   скажи «выполни её через `! <команда>`» и **остановись**. Не продолжай,
   пока в контексте не появится результат её выполнения.
2. **Перед каждым вызовом Bash покажи команду в тексте ответа.** Пользователь
   должен видеть, что именно исполняется, не разворачивая tool call.
3. Пути к репозиторию всегда в одинарных кавычках.
4. Никаких `Co-Authored-By` и `Generated with Claude` в коммитах и тегах.

## Аргументы

`$ARGUMENTS` разбирай так:

- **Версия.** Либо явная `X.Y.Z`, либо `patch` / `minor` / `major`.
  Базу для вычисления бери из **последнего тега**, а не из `libs.versions.toml`
  в develop: бамп живёт в релизной ветке и возвращается в develop обратным
  мерджем, поэтому TOML в develop штатно отстаёт на версию.
  ```
  git for-each-ref --sort=-creatordate --format='%(refname:short)' refs/tags | head -1
  ```
  Сортировка по дате, а не `--sort=-v:refname`: схема тегов менялась (до 8.0.5 с
  префиксом `v`, дальше без него), и version-sort поднимает старые `v`-теги наверх.
  Арифметика на примере 8.2.2: `patch` → 8.2.3 · `minor` → 8.3.0 · `major` → 9.0.0
- **Ключ задачи.** Вытащи регуляркой `[A-Z]+-[0-9]+` из аргументов, из ссылки
  на Jira или из прикреплённого пользователем текста задачи. Если ключ есть —
  прочитай задачу через Atlassian MCP (`jira_get_issue`) и используй заголовок
  при составлении CHANGELOG. Если ключа нет — это нормально, продолжай.
- **`--publish=`** — `local` / `remote` / `none` (по умолчанию `none`).

Прежде чем что-либо менять, покажи разобранные аргументы: текущая версия,
новая версия, тикет, режим публикации. Дождись подтверждения.

## Шаги

### 1. Актуализировать develop и проверить, что прошлый релиз в нём

Релиз возвращается в develop на **шаге 10 этой же команды**. Но если прошлый
релиз выпускали не через неё, back-merge мог быть забыт — так было с 8.0.4,
она пролежала невлитой девять дней, и develop всё это время считал текущей
версией 8.0.3. Поэтому проверяй, а не полагайся на то, что шаг 10 отработал.

```
cd '/Users/nqs-desktop/mts/platsdk/develop'
git status --short                      # дерево должно быть чистым; иначе спроси
git fetch --all --prune --tags
git pull --ff-only
```

Найди последнюю релизную ветку и проверь, влита ли она:
```
git branch -r | grep 'origin/release/' | sort -V | tail -1
git log --oneline <last-release>..develop    # пусто → develop содержит релиз
git log --oneline develop..<last-release>    # непусто → back-merge забыли
```
Если забыли — покажи пользователю, какие коммиты приедут, и влей по процедуре
из шага 10. Это страховка, а не штатный путь: в норме здесь ничего не должно
находиться.

### 2. Аудит того, что уходит в релиз

```
git log --oneline --no-merges origin/release/<prev>..develop
git diff --stat origin/release/<prev>..develop
```
Прочитай список глазами. Ищи мусор: коммиты не по теме релиза, закомментированный
код, чужие ветки, просочившиеся через мердж. Такое уже было — два коммита
`release: 6.1.6` от апреля закомментировали проброс `bindingId`. **Покажи находки
пользователю до того, как резать ветку.** Молча не продолжай.

### 3. Релизная ветка в отдельном worktree

```
cd '/Users/nqs-desktop/mts/platsdk/develop'
git worktree add ../release-<version> -b release/<version> develop
```

### 4. Бамп версии

Версия живёт в **двух** файлах, обновить оба:
- `gradle/libs.versions.toml` → `platsdk = "<version>"` (отсюда берётся версия артефакта)
- `version.properties` → `MAJOR_VERSION` / `MINOR_VERSION` / `PATCH_VERSION` (из этого файла
  читает fastlane)

Файлы регулярно разъезжаются — бамп обязан свести их к одной версии. `version.properties` сверяй
глазами: полной строки вида `8.2.1` там нет, поэтому grep его не найдёт. Grep нужен для другого —
показать посторонние места:
```
grep -rn '<prev-version>' --include='*.toml' --include='*.kts' --include='*.gradle' --include='*.properties' . | grep -v CHANGELOG
```
Ожидается одна строка — `gradle/libs.versions.toml`. Что-то ещё — остановись и покажи.

### 5. CHANGELOG

Собери секцию из коммитов и Jira:
```
git log --oneline --no-merges <prev-tag>..develop
```
Вытащи ключи задач, прочитай их через Atlassian MCP, посмотри диффы по существу
(что реально изменилось для пользователя, а не как назван коммит). Формат — как
в существующем файле, свежая секция сверху:

```
## [<version>] - <DD.MM.YYYY>
[TICKET] - Описание изменения на русском <br />
```

**Покажи текст пользователю и дождись правки/одобрения.** Формулировки твои —
он лучше знает, что писать.

### 6. Сборка до тега

Тег на непроверенном коммите — плохо. Из worktree релиза:
```
cd '/Users/nqs-desktop/mts/platsdk/release-<version>'
./gradlew assembleDebug detekt
```
Detekt валит сборку на любом замечании: `ignoreFailures = false` (`build.gradle.kts:26`) плюс
унаследованный `build.maxIssues: 0` (`buildUponDefaultConfig`), baseline нет. Красный результат —
стоп, не коммить.
Тесты гоняй отдельным вызовом: фейл detekt в общем вызове маскирует ошибку
компиляции тестов.

### 7. Коммит и тег

```
git add CHANGELOG.md gradle/libs.versions.toml version.properties
git commit -m "version <version>"
git tag -a <version> -m "<version>"
```
Аннотированный тег висит на коммите бампа внутри релизной ветки; в теле тега — голая версия,
при желании плюс краткое описание релиза (как у 8.2.2). Тег **без префикса `v`** — так начиная
с 8.0.6; `v`-схема осталась только в истории до 8.0.5.

### 8. Push релизной ветки и тега — руками пользователя

Если на шаге 1 сработала страховка и ты влил забытый прошлый релиз — сперва
запушить develop, иначе этот мердж уедет на сервер впервые внутри релизной
ветки. Если страховка не срабатывала — сразу релизная ветка.

```
cd '/Users/nqs-desktop/mts/platsdk/develop' && git push origin develop
```
```
cd '/Users/nqs-desktop/mts/platsdk/release-<version>' && git push origin release/<version> <version>
```

### 9. Публикация

- `--publish=local` — выполни сам, это пишет только в `~/.m2`:
  ```
  cd '/Users/nqs-desktop/mts/platsdk/release-<version>' && ./gradlew publishLocal
  ```
  Напомни: чтобы проверить сборку mymts против локального артефакта, в mymts нужны
  `mts-plat-sdk = "<version>"` — ровно та версия, что в TOML релизной ветки, суффикс
  `-SNAPSHOT` уместен только если ты сам временно проставил его в `libs.versions.toml`
  platsdk перед `publishLocal` — и `mavenLocal()` в функции `local()` файла
  `infrastructure/build-settings/versions/mymts-versions/src/main/kotlin/convention-dependency-resolution.settings.gradle.kts`.
  Эти правки в MR не идут.
- `--publish=remote` — **не выполняй**, публикация в артифактори необратима.
  Выведи команду и жди:
  ```
  cd '/Users/nqs-desktop/mts/platsdk/release-<version>' && ./gradlew publishRelease
  ```
- `--publish=none` — пропусти.

### 10. Вернуть релиз в develop

**Не пропускай этот шаг и не откладывай его на следующий релиз.** Пока он не
сделан, `develop` содержит старую версию в `libs.versions.toml` и `version.properties`,
а вычисление следующей версии по тегу расходится с тем, что видно в дереве.

Делать сразу после того, как тег запушен и артефакт опубликован — релиз к этому
моменту зафиксирован, вливать безопасно.

```
cd '/Users/nqs-desktop/mts/platsdk/develop'
git fetch origin
git pull --ff-only
git log --oneline $(git merge-base develop origin/release/<version>)..develop -- gradle/libs.versions.toml version.properties CHANGELOG.md
```
Последняя команда должна вернуть пусто — значит develop не трогал те же файлы
и конфликта не будет. Если непусто — покажи расхождение пользователю.

```
git merge --no-ff origin/release/<version> -m "Merge branch 'release/<version>' into 'develop'"
```
Затем выведи команду push и **жди**:
```
cd '/Users/nqs-desktop/mts/platsdk/develop' && git push origin develop
```

### 11. Итог

Кратко: что влито, что вошло в релиз, где ветка и тег, что осталось сделать.
Напомни убрать релизный worktree, когда всё влито и запушено:
`git -C '/Users/nqs-desktop/mts/platsdk/develop' worktree remove ../release-<version>`.
Напомни, что `/mymts-platsdk-bump <version> [TICKET]` имеет смысл запускать
только после того, как артефакт `ru.mts.platsdk:mts-platsdk-sdk:<version>`
реально опубликован — иначе пайплайн MR упадёт на резолве зависимости.
