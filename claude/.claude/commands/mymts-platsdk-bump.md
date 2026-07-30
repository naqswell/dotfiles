---
description: Поднять версию platsdk в mymts и подготовить MR (feature от develop, bugfix от последнего release)
argument-hint: <X.Y.Z> [TICKET|jira-url] [--type=feature|bugfix]
allowed-tools: Bash(git*), Bash(glab*), Bash(./gradlew*), Read, Edit, Grep, AskUserQuestion, mcp__atlassian__jira_get_issue
---

Ты поднимаешь версию platsdk в mymts: `~/mts/mymts/master`. Имя каталога не равно
ветке — текущую смотри `git -C '/Users/nqs-desktop/mts/mymts/master' branch --show-current`.

## Железные правила

1. **Никогда не выполняй сам:** `git push`, `glab mr create`, `glab mr merge`,
   любые `--force`. Это делает пользователь.
   Дойдя до такого шага — выведи точную команду одной строкой в блоке кода,
   скажи «выполни её через `! <команда>`» и **остановись**. Не продолжай,
   пока в контексте не появится результат её выполнения.
2. **Перед каждым вызовом Bash покажи команду в тексте ответа.**
3. Пути всегда в одинарных кавычках.
4. Никаких `Co-Authored-By` и `Generated with Claude`.

## Аргументы

- **Версия** `X.Y.Z` — та, что уже выпущена в platsdk.
- **Ключ задачи** — регуляркой `[A-Z]+-[0-9]+` из аргументов, ссылки на Jira
  или прикреплённого текста задачи. Если есть — прочитай через Atlassian MCP
  (`jira_get_issue`): заголовок пойдёт в описание MR.
- **`--type=`** — `feature` (по умолчанию) или `bugfix`. Если не указан явно,
  а тикет привязан к релизу/хотфиксу — спроси, не угадывай.

## От чего ветвимся и куда целится MR

| type | база | target MR |
|---|---|---|
| `feature` | `develop`, предварительно актуализированный | `develop` |
| `bugfix` | последняя `release/*` | та же `release/*` |

Последнюю релизную ветку определи так и **покажи кандидата на подтверждение** —
в репо есть мусорные ветки вида `release/Version-for-DK-4.9`, которые нельзя
брать в расчёт:
```
git branch -r | grep -E 'origin/release/[0-9]+\.[0-9]+(\.[0-9]+)?$' | sort -V | tail -3
```

Исторический прецедент: `bugfix/PAY-467-platsdk-update` отведён от релизного
коммита `[GITLAB] increment version code: 6.71 (9)` в `release/6.71`, не от develop.

## Именование

С тикетом:
- ветка `<type>/<TICKET>-platsdk-update`
- коммит `[<TICKET>] platsdk update`
- MR `[<TICKET>] platsdk update <version>`

Без тикета:
- ветка `<type>/platsdk-<version>`
- коммит `platsdk update <version>`
- MR `platsdk update <version>`

## Шаги

### 1. Проверить, что артефакт существует

MR на несуществующую версию упадёт в CI на резолве зависимости. Убедись, что
`ru.mts.platsdk:mts-platsdk-sdk:<version>` опубликован (тег запушен, релизная
сборка прошла, `publishRelease` выполнен). Если нет — скажи пользователю и
предложи либо подождать, либо создать MR как draft.

### 2. Разобраться с рабочим деревом

В `mymts/master` часто лежат незакоммиченные отладочные правки под локальную
сборку platsdk — `mts-plat-sdk = "X.Y.Z-SNAPSHOT"` в `mts.libraries.toml` и
`mavenLocal()` в `convention-dependency-resolution.settings.gradle.kts`.
**В MR им не место, но и терять их нельзя.**

```
cd '/Users/nqs-desktop/mts/mymts/master'
git status --short
git diff
```
Если правки есть — покажи их пользователю и убери в stash с внятным именем:
```
git stash push -m "local: platsdk SNAPSHOT + mavenLocal()" -- <файлы>
```
Предупреди, что `git stash pop` потом даст конфликт по `mts.libraries.toml`,
раз обе стороны трогают строку `mts-plat-sdk`.

### 3. Актуализировать базу и создать ветку

Для `feature` — база `develop`. В дереве может лежать чужая незавершённая ветка
(например `bugfix/...`): покажи её пользователю и спроси, прежде чем переключаться.
```
git fetch origin
git switch develop
git pull --ff-only
git switch -c <type>/<name>
```
Для `bugfix` — от релизной ветки:
```
git fetch origin
git switch -c <type>/<name> origin/release/<X.Y[.Z]>
```

### 4. Бамп

Единственное место — `infrastructure/build-settings/versions/mymts-versions/mts.libraries.toml`,
строка `mts-plat-sdk = "..."`. Проверь, что больше нигде:
```
grep -rn 'mts-plat-sdk = "' infrastructure/ --exclude-dir=build
```
Именно с кавычкой после `=` и с исключением `build/`: без них в выводе будут ещё объявление
координаты (`mts-plat-sdk = { group = ... }`) и копии из сгенерированного каталога.
Диff обязан быть ровно в одну строку — как в `[PAY-467] platsdk update`.
Если в `git status` всплыло что-то ещё — стоп, покажи пользователю.

### 5. Коммит

```
git add infrastructure/build-settings/versions/mymts-versions/mts.libraries.toml
git commit -m "<сообщение по правилу именования выше>"
```

### 6. Push и MR — руками пользователя

Выведи обе команды и **жди**:
```
cd '/Users/nqs-desktop/mts/mymts/master' && git push origin <branch>
```
```
cd '/Users/nqs-desktop/mts/mymts/master' && glab mr create --source-branch <branch> --target-branch <target> --title '<title>' --description '<описание>' --remove-source-branch
```
В описании MR: что за версия platsdk, что в неё вошло (возьми из CHANGELOG
platsdk), ссылка на тикет, если он есть. В mymts работает `glab`, не `gh`.

### 7. Итог

Скажи, что осталось: вернуть stash (`git stash pop`, будет конфликт по
`mts-plat-sdk` — разрешать в пользу нужного), проверить пайплайн MR.
