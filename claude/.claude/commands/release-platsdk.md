---
description: Выпуск новой версии platsdk — релизная ветка, бамп, CHANGELOG, сборка, тег, публикация, back-merge в develop
argument-hint: <patch|minor|major|X.Y.Z> [TICKET|jira-url] [--publish=local|remote|none]
allowed-tools: Bash(git*), Bash(./gradlew*), Read, Edit, Grep, AskUserQuestion
---

Ты ведёшь релиз platsdk в `~/mts/platsdk/`. Репозиторий использует git worktrees:
контейнер `~/mts/platsdk/`, внутри `master/`, `develop/`, `wip1/`, `wip2/`.

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
  git tag -l 'v[0-9]*' --sort=-v:refname | head -1
  ```
  `patch`: 8.0.5 → 8.0.6 · `minor`: 8.0.5 → 8.1.0 · `major`: 8.0.5 → 9.0.0
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

Версия должна встречаться ровно в одном месте — проверь, а не полагайся на память:
```
grep -rn '<prev-version>' --include='*.toml' --include='*.kts' --include='*.gradle' --include='*.properties' . | grep -v CHANGELOG
```
Ожидается одна строка: `gradle/libs.versions.toml` → `platsdk = "<version>"`.
Если строк больше — остановись и покажи их.

### 5. CHANGELOG

Собери секцию из коммитов и Jira:
```
git log --oneline --no-merges v<prev>..develop
```
Вытащи ключи задач, прочитай их через Atlassian MCP, посмотри диффы по существу
(что реально изменилось для пользователя, а не как назван коммит). Формат — как
в существующем файле, свежая секция сверху:

```
## [<version>]
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
Detekt настроен на `maxIssues: 0`. Красный результат — стоп, не коммить.
Тесты гоняй отдельным вызовом: фейл detekt в общем вызове маскирует ошибку
компиляции тестов.

### 7. Коммит и тег

```
git add CHANGELOG.md gradle/libs.versions.toml
git commit -m "version <version>"
git tag -a v<version> -m "version <version>"
```
Аннотированный тег, сообщение совпадает с subject коммита, висит на коммите
бампа внутри релизной ветки. Так сделаны v8.0.4 и v8.0.5.

### 8. Push релизной ветки и тега — руками пользователя

Если на шаге 1 сработала страховка и ты влил забытый прошлый релиз — сперва
запушить develop, иначе этот мердж уедет на сервер впервые внутри релизной
ветки. Если страховка не срабатывала — сразу релизная ветка.

```
cd '/Users/nqs-desktop/mts/platsdk/develop' && git push origin develop
```
```
cd '/Users/nqs-desktop/mts/platsdk/release-<version>' && git push origin release/<version> v<version>
```

### 9. Публикация

- `--publish=local` — выполни сам, это пишет только в `~/.m2`:
  ```
  cd '/Users/nqs-desktop/mts/platsdk/release-<version>' && ./gradlew publishLocal
  ```
  Напомни: чтобы проверить сборку mymts против локального артефакта, нужны
  `mts-plat-sdk = "<version>-SNAPSHOT"` и `mavenLocal()` в
  `convention-dependency-resolution.settings.gradle.kts`. Эти правки в MR не идут.
- `--publish=remote` — **не выполняй**, публикация в артифактори необратима.
  Выведи команду и жди:
  ```
  cd '/Users/nqs-desktop/mts/platsdk/release-<version>' && ./gradlew publishRelease
  ```
- `--publish=none` — пропусти.

### 10. Вернуть релиз в develop

**Не пропускай этот шаг и не откладывай его на следующий релиз.** Пока он не
сделан, `develop` содержит старую версию в `libs.versions.toml`, а вычисление
следующей версии по тегу расходится с тем, что видно в дереве.

Делать сразу после того, как тег запушен и артефакт опубликован — релиз к этому
моменту зафиксирован, вливать безопасно.

```
cd '/Users/nqs-desktop/mts/platsdk/develop'
git fetch origin
git pull --ff-only
git log --oneline $(git merge-base develop origin/release/<version>)..develop -- gradle/libs.versions.toml CHANGELOG.md
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
Напомни, что `/mymts-platsdk-bump <version> [TICKET]` имеет смысл запускать
только после того, как артефакт `ru.mts.platsdk:mts-platsdk-sdk:<version>`
реально опубликован — иначе пайплайн MR упадёт на резолве зависимости.
