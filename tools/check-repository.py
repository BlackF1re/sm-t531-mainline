#!/usr/bin/env python3
"""Check tracked source files without building or contacting the tablet."""
import ast
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]


def main():
    names = subprocess.check_output(
        ['git', 'ls-files', '-z'], cwd=ROOT
    ).decode().split('\0')
    files = [Path(name) for name in names if name]
    errors = []
    for relative in files:
        path = ROOT / relative
        if not path.is_file():
            errors.append(f'{relative}: tracked file is missing')
            continue
        if (relative.suffix in {'.o', '.ko', '.pyc', '.deb', '.so'}
                or '__pycache__' in relative.parts or '.work' in relative.parts
                or 'backup_stock' in relative.parts):
            errors.append(f'{relative}: generated artifact tracked as source')
        try:
            if path.suffix == '.py':
                ast.parse(path.read_text(), filename=str(relative))
            elif path.suffix == '.json':
                json.loads(path.read_text())
            elif path.suffix == '.sh' or path.read_bytes().startswith(
                    (b'#!/bin/bash', b'#!/usr/bin/env bash', b'#!/bin/sh')):
                shell = 'sh' if path.read_bytes().startswith(b'#!/bin/sh') else 'bash'
                subprocess.run([shell, '-n', str(path)], check=True,
                               capture_output=True, text=True)
            if path.suffix == '.md':
                for link in re.findall(r'\]\(([^\s)]+)(?:\s+[^)]*)?\)', path.read_text()):
                    target = unquote(link.strip('<>').split('#', 1)[0])
                    if not target or re.match(r'^[a-zA-Z][\w+.-]*:', target):
                        continue
                    if not (path.parent / target).exists():
                        errors.append(f'{relative}: missing local link {target}')
        except (SyntaxError, ValueError, UnicodeError) as error:
            errors.append(f'{relative}: {error}')
        except subprocess.CalledProcessError as error:
            errors.append(f'{relative}: {error.stderr.strip()}')
    diff = subprocess.run(['git', 'diff', '--check', 'HEAD'], cwd=ROOT,
                          capture_output=True, text=True)
    if diff.returncode:
        errors.append(diff.stdout.strip() or diff.stderr.strip())
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print(f'Repository checks passed ({len(files)} tracked files). No device tests run.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
