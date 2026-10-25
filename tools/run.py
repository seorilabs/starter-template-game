#!/usr/bin/env python3
"""Import local Godot assets before launching the game, including on a fresh clone."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys

ERROR = re.compile(r'^(?:SCRIPT ERROR|ERROR:)', re.M)

def has_errors(log):
    return bool(ERROR.search(re.sub(r'\x1b\[[0-9;]*m', '', log)))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1] / 'godot')
    args, extra = parser.parse_known_args()
    project = args.project.resolve()
    if not (project / 'project.godot').is_file(): parser.error('Godot project not found')
    godot = os.environ.get('GODOT', 'godot')
    imported = subprocess.run([godot, '--headless', '--path', str(project), '--import', '--quit-after', '2'], capture_output=True, text=True, timeout=180)
    log = imported.stdout + imported.stderr
    if imported.returncode or has_errors(log):
        sys.stderr.write(log)
        return imported.returncode or 1
    failed = False
    with subprocess.Popen([godot, '--path', str(project), *extra], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as process:
        try:
            for line in process.stdout:
                print(line, end='', flush=True)
                failed |= has_errors(line)
            code = process.wait()
        except KeyboardInterrupt:
            process.terminate(); process.wait()
            return 130
    return code or int(failed)

if __name__ == '__main__':
    try: raise SystemExit(main())
    except (OSError, subprocess.SubprocessError) as error: raise SystemExit(str(error))
