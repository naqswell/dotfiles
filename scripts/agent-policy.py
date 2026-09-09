#!/usr/bin/env python3
"""Client hook adapters; conservative command checks, not a shell sandbox."""
import json
import os
import re
import sys
from pathlib import Path

# Инструменты, которыми Claude поднимает подагентов и воркфлоу.
SPAWN_TOOLS = frozenset({'task', 'agent', 'workflow'})

SHELL_TOOLS = frozenset({'bash', 'shell', 'exec_command'})

# Флаг-разрешение на установку софта. Создаёт его только пользователь: команды,
# упоминающие это имя, отбиваются ниже, иначе агент разблокировал бы себя сам.
INSTALL_FLAG = 'installs-allowed'

# Скачивание, монтирование, установка и запуск чужих приложений. Причина не в
# необратимости — диалоги Gatekeeper выдёргивают пользователя из работы, а со
# стороны это неотличимо от того, что агент молча ставит софт.
INSTALL_RULES = (
    (r'\bhdiutil\s+(?:attach|mount)\b', 'монтирование образа'),
    (r'\b(?:curl|wget|aria2c)\b[^\n]*\.(?:dmg|pkg|mpkg)\b', 'скачивание .dmg/.pkg'),
    (r'\b(?:curl|wget)\b[^\n]*\|\s*(?:sudo\s+)?(?:ba|z)?sh\b', 'установка через curl | sh'),
    (r'\binstaller\s+[^\n]*-(?:pkg|package)\b', 'installer -pkg'),
    (r'\bbrew\s+(?:install|reinstall|upgrade)\b[^\n]*--cask\b', 'brew --cask'),
    (r'\bmas\s+install\b', 'mas install'),
    (r'\bxattr\b[^\n]*com\.apple\.quarantine', 'снятие карантина'),
    (r'\bspctl\b[^\n]*--(?:master|global)-disable\b', 'отключение Gatekeeper'),
    (r'\b(?:cp|mv|ditto|rsync)\b[^\n]*/Applications(?:/|\s|$)', 'запись в /Applications'),
    (r'\bopen\s+[^|;&\n]*\.(?:app|dmg|pkg)\b', 'запуск чужого приложения'),
    (r'\.app/Contents/MacOS/', 'прямой запуск бинарника приложения'),
)


def install_gate(command):
    """Пустая строка — запрета нет; иначе текст отказа."""
    if INSTALL_FLAG in command:
        return ('Флаг ' + INSTALL_FLAG + ' создаёт пользователь сам, не агент.')
    if (Path.home() / '.claude' / INSTALL_FLAG).exists():
        return ''
    for pattern, what in INSTALL_RULES:
        if re.search(pattern, command):
            return ('Запрещено агентам: ' + what + '. Софт на этой машине ставит и '
                    'запускает пользователь. Проверяй приложения по GitHub/Homebrew/'
                    'iTunes API, а чего так не выяснить — пиши «локально не проверял». '
                    'Разрешение на сессию даёт пользователь: touch ~/.claude/' + INSTALL_FLAG)
    return ''


def spawn_flag(session_id):
    """Файл-разрешение на сессию: пока он есть, спавн не переспрашивается.

    Лежит в ~/.claude, а не в TMPDIR: у хука и у оболочки пользователя TMPDIR
    может отличаться, и тогда созданный вручную флаг хук бы не увидел.
    """
    safe = re.sub(r'[^A-Za-z0-9_-]', '', session_id)[:64]
    return Path.home() / '.claude' / ('agents-allowed-' + safe)


def spawn_gate(event):
    """Пустая строка — вопроса нет; иначе текст для диалога подтверждения."""
    name = str(event.get('tool_name', event.get('toolName', ''))).lower()
    if name not in SPAWN_TOOLS:
        return ''
    session_id = str(event.get('session_id', event.get('sessionId', '')))
    if not session_id:
        return 'Запуск агентов требует разрешения (сессия не опознана).'
    flag = spawn_flag(session_id)
    if flag.exists():
        return ''
    return ('Claude хочет запустить агентов. Разрешить на всю сессию: touch ' + str(flag))


def reason(event):
    name = str(event.get('tool_name', event.get('toolName', ''))).lower()
    data = event.get('tool_input', event.get('input', {})) or {}
    if not isinstance(data, dict):
        return 'Invalid tool input'
    command = data.get('command', data.get('cmd', data.get('code', '')))
    if not isinstance(command, str):
        return ''
    if re.search(r'\bgit\b[\s\S]*\b(?:push|send-pack)\b', command):
        return 'Push запрещён агентам; команду выполняет пользователь вручную.'
    if re.search(r'\b(?:gh|glab)\s+(?:pr|mr)\s+(?:create|merge)\b', command):
        return 'Создание и merge PR/MR выполняет пользователь.'
    if re.search(r'\bgradlew\b[\s\S]*\bpublishRelease\b', command):
        return 'publishRelease выполняет пользователь.'
    if name in SHELL_TOOLS:
        blocked = install_gate(command)
        if blocked:
            return blocked
    if name in SHELL_TOOLS and re.search(r'\bgradlew\b', command):
        cwd = Path(data.get('workdir', event.get('cwd', '.'))).expanduser().resolve()
        if cwd.name == 'platsdk' and not (cwd / 'gradlew').exists():
            return 'Gradle запускается из конкретного worktree, не контейнера platsdk.'
    return ''


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else 'check'
    ask = ''
    try:
        event = json.load(sys.stdin)
        message = reason(event)
        ask = '' if message else spawn_gate(event)
    except (ValueError, TypeError) as exc:
        message = 'Invalid policy event: ' + type(exc).__name__
    if mode == 'hook':
        if message:
            print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse',
                  'permissionDecision': 'deny', 'permissionDecisionReason': message}}))
        elif ask:
            print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse',
                  'permissionDecision': 'ask', 'permissionDecisionReason': ask}},
                  ensure_ascii=False))
        return 0
    if message:
        print(message)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
