#!/usr/bin/env python3
"""Install the shared agent kit. Existing files are backed up, never discarded."""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / 'agents'
HOME_DIR = Path.home()
BACKUP = HOME_DIR / '.local/state/agent-setup/backups' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
APPLY = False
CHANGES = []


def physical(path):
    return path.parent.resolve() / path.name


def backup(path):
    if path.exists() or path.is_symlink():
        dest = BACKUP / path.relative_to(HOME_DIR)
        dest.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        if path.is_symlink():
            dest.symlink_to(os.readlink(path))
        elif path.is_dir():
            shutil.copytree(path, dest, symlinks=True)
        else:
            shutil.copy2(path, dest)


def write(path, content, mode=0o644):
    path = physical(path)
    if path.is_file() and not path.is_symlink() and path.read_text() == content:
        return
    CHANGES.append(str(path))
    if not APPLY:
        return
    backup(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + '.agent-setup-tmp')
    with open(temp, 'w') as f:
        os.chmod(temp, mode)
        f.write(content)
    os.replace(temp, path)


def link(path, target):
    path = physical(path)
    target = target.resolve()
    if path.is_symlink() and path.resolve() == target:
        return
    CHANGES.append(str(path))
    if not APPLY:
        return
    backup(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    elif path.exists() or path.is_symlink():
        path.unlink()
    path.symlink_to(os.path.relpath(target, path.parent))


def merge_json(path, change):
    if path.is_symlink():
        path = path.resolve()
    data = json.loads(path.read_text()) if path.exists() else {}
    change(data)
    write(path, json.dumps(data, ensure_ascii=False, indent=2) + '\n')


def unlink(path):
    path = physical(path)
    if not path.is_symlink():
        return
    CHANGES.append(str(path))
    if not APPLY:
        return
    backup(path)
    path.unlink()


def install():
    manifest = json.loads((KIT / 'manifest.json').read_text())
    for dest in manifest['instructionTargets']:
        link(HOME_DIR / dest, KIT / 'AGENTS.md')
    link(HOME_DIR / '.agents/context', KIT / 'context')
    memory = HOME_DIR / '.local/share/agent-memory'
    if memory.exists():
        link(HOME_DIR / '.agents/memory', memory)
    # Скиллы, собранные в плагин, Claude получает через него — плоский симлинк
    # рядом показал бы их в списке сессии дважды. Остальные клиенты про плагины
    # не знают, поэтому плоская раскатка в ~/.agents/skills остаётся каноном.
    in_plugin = set()
    for plugin_json in (HOME_DIR / '.claude/skills').glob('*/.claude-plugin/plugin.json'):
        skills = plugin_json.parent.parent / 'skills'
        if skills.is_dir():
            in_plugin |= {s.name for s in skills.iterdir() if (s / 'SKILL.md').exists()}
    for path in sorted((KIT / 'skills').iterdir()):
        if (path / 'SKILL.md').exists():
            link(HOME_DIR / '.agents/skills' / path.name, path)
            if path.name in in_plugin:
                flat = physical(HOME_DIR / '.claude/skills' / path.name)
                if flat.exists() and not flat.is_symlink():
                    print('WARN дубль: ' + str(flat) + ' — настоящий каталог, '
                          'скилл будет показан дважды. Уберите его руками')
                else:
                    unlink(flat)
            else:
                link(HOME_DIR / '.claude/skills' / path.name, path)
    link(HOME_DIR / '.codex/rules/default.rules', KIT / 'adapters/codex.rules')
    link(HOME_DIR / '.omp/agent/extensions/agent-policy.ts', KIT / 'adapters/omp-policy.ts')
    hook = {'type': 'command', 'command': '/usr/bin/python3 ' +
            "'" + str(ROOT / 'scripts/agent-policy.py') + "' hook", 'timeout': 5}

    def add_hook(data):
        entries = data.setdefault('hooks', {}).setdefault('PreToolUse', [])
        if not any('agent-policy.py' in h.get('command', '') for e in entries for h in e.get('hooks', [])):
            entries.append({'matcher': '*', 'hooks': [hook]})

    def claude(data):
        add_hook(data)
        perms = data.setdefault('permissions', {})
        for rule in ['Bash(git push*)', 'Bash(git send-pack*)', 'Bash(git * push*)', 'Bash(git * send-pack*)']:
            if rule not in perms.setdefault('deny', []):
                perms['deny'].append(rule)
        if 'Bash(git commit*)' not in perms.setdefault('allow', []):
            perms['allow'].append('Bash(git commit*)')

    merge_json(HOME_DIR / '.claude/settings.json', claude)
    merge_json(HOME_DIR / '.codex/hooks.json', add_hook)
    # OMP accepts JSON as YAML; preserve all unrelated user configuration.
    omp_config = HOME_DIR / '.omp/agent/config.yml'
    if omp_config.exists():
        raw = omp_config.read_text()
        try:
            data = json.loads(raw)
        except ValueError:
            if raw.strip() == 'setupVersion: 2':
                data = {'setupVersion': 2}
            else:
                raise SystemExit('OMP YAML changed: merge it explicitly before applying')
    else:
        data = {}
    data.setdefault('tools', {})['approvalMode'] = 'write'
    data['tools'].setdefault('approval', {}).update({'eval': 'prompt', 'python': 'prompt'})
    patterns = data.setdefault('bash', {}).setdefault('patterns', [])
    for pattern in ['*git*push*', '*git*send-pack*', '*gradlew*publishRelease*', '*gh pr create*', '*gh pr merge*', '*glab mr create*', '*glab mr merge*']:
        rule = {'match': pattern, 'approval': 'deny'}
        if rule not in patterns:
            patterns.insert(0, rule)
    for pattern in ['git add*', 'git commit*', 'git -C * add*', 'git -C * commit*']:
        rule = {'match': pattern, 'approval': 'allow'}
        if rule not in patterns:
            patterns.append(rule)
    data.setdefault('skills', {}).update({'enableAgentsUser': True, 'enableAgentsProject': True,
                                        'enableClaudeUser': False, 'enableClaudeProject': False})
    data.setdefault('commands', {}).update({'enableClaudeUser': False, 'enableClaudeProject': False})
    write(omp_config, json.dumps(data, ensure_ascii=False, indent=2) + '\n', 0o600)
    registry = json.loads((KIT / 'mcp.json').read_text())['mcpServers']
    mcp = {}
    for name, spec in registry.items():
        if spec.get('type') == 'http':
            mcp[name] = {'type': 'http', 'url': spec['url']}
        else:
            mcp[name] = {'command': '/usr/bin/python3', 'args': [str(ROOT / 'scripts/agent-mcp.py'), name]}
    merge_json(HOME_DIR / '.omp/agent/mcp.json', lambda data: data.setdefault('mcpServers', {}).update(mcp))
    codex = HOME_DIR / '.codex/config.toml'
    content = codex.read_text() if codex.exists() else ''
    start, end = '# BEGIN agent-setup MCP', '# END agent-setup MCP'
    if start in content:
        before, rest = content.split(start, 1)
        _, after = rest.split(end, 1)
        content = before.rstrip() + '\n' + after.lstrip('\n')
    for name in mcp:
        if '[mcp_servers.' + name + ']' in content or '[mcp_servers."' + name + '"]' in content:
            raise SystemExit('Existing unmanaged Codex MCP server: ' + name)
    lines = [start]
    for name, spec in mcp.items():
        lines.append('[mcp_servers.' + json.dumps(name) + ']')
        for key in ['url', 'command', 'args']:
            if key in spec:
                lines.append(key + ' = ' + json.dumps(spec[key]))
        lines.append('')
    lines.append(end)
    write(codex, content.rstrip() + '\n\n' + '\n'.join(lines) + '\n', 0o600)


def check():
    manifest = json.loads((KIT / 'manifest.json').read_text())
    failures = []
    for dest in manifest['instructionTargets']:
        path = HOME_DIR / dest
        ok = path.exists() and path.resolve() == (KIT / 'AGENTS.md').resolve()
        print(('OK ' if ok else 'FAIL ') + dest)
        if not ok:
            failures.append(dest)
    for base in [HOME_DIR / '.agents/skills', HOME_DIR / '.claude/skills']:
        if not base.is_dir():
            failures.append('нет каталога ' + str(base))
            continue
        for path in base.iterdir():
            # Каталог плагина скиллы держит внутри, своего SKILL.md у него нет.
            # Обычные файлы (.DS_Store и прочий сор) скиллами не притворяются.
            if not path.is_dir() or (path / '.claude-plugin/plugin.json').exists():
                continue
            if not (path / 'SKILL.md').exists():
                failures.append(str(path))
    for source in manifest['preserved']:
        path = HOME_DIR / source['path']
        if not path.is_file():
            failures.append('preserved missing: ' + source['path'])
        elif hashlib.sha256(path.read_bytes()).hexdigest() != source['sha256']:
            failures.append('preserved changed: ' + source['path'])
    print('Skills:', len(list((HOME_DIR / '.agents/skills').glob('*/SKILL.md'))))
    print('Failures:', failures)
    return bool(failures)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['plan', 'apply', 'check'])
    args = parser.parse_args()
    if args.action == 'check':
        raise SystemExit(check())
    APPLY = args.action == 'apply'
    install()
    print(json.dumps({'applied': APPLY, 'changes': CHANGES, 'backup': str(BACKUP) if APPLY and CHANGES else None}, ensure_ascii=False, indent=2))
