"""Check actual ComfyUI imports/startup without opening a browser or generating media."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def output_text(value):
    if isinstance(value, bytes):
        return value.decode('utf-8', errors='replace')
    return value or ''


def run_startup_check(comfy_root, timeout=180):
    if timeout <= 0:
        raise ValueError('Startup timeout must be positive')
    comfy_root = Path(comfy_root).resolve()
    if not (comfy_root / 'main.py').is_file():
        return {'startup_ok': False, 'reason': 'missing_main', 'details': 'ComfyUI main.py is missing.'}
    with tempfile.TemporaryDirectory(prefix='h3-startup-check-') as temporary:
        scratch = Path(temporary)
        command = [sys.executable, '-s', str(comfy_root / 'main.py'),
                   '--windows-standalone-build', '--quick-test-for-ci',
                   '--disable-all-custom-nodes', '--lowvram', '--reserve-vram', '1.5',
                   '--disable-pinned-memory', '--preview-method', 'none',
                   '--database-url', 'sqlite:///:memory:']
        for name in ('user', 'input', 'output', 'temp'):
            directory = scratch / name
            directory.mkdir()
            command.extend([f'--{name}-directory', str(directory)])
        gpu = os.environ.get('CUDA_VISIBLE_DEVICES')
        if not gpu:
            return {'startup_ok': False, 'reason': 'missing_gpu', 'details': 'Selected GPU environment is missing.'}
        command.extend(['--cuda-device', gpu])
        environment = dict(os.environ, PYTHONIOENCODING='utf-8', PYTHONUTF8='1')
        try:
            result = subprocess.run(command, cwd=comfy_root.parent, env=environment,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    encoding='utf-8', errors='replace', timeout=timeout,
                                    check=False)
        except subprocess.TimeoutExpired as error:
            # subprocess.run kills and waits for this child on timeout.
            return {'startup_ok': False, 'reason': 'timeout',
                    'details': f'ComfyUI startup exceeded {timeout} seconds.\n' + output_text(error.stdout)[-12000:]}
        except OSError as error:
            return {'startup_ok': False, 'reason': 'launch_error', 'details': str(error)}
        return {'startup_ok': result.returncode == 0,
                'reason': 'ok' if result.returncode == 0 else 'startup_failed',
                'exit_code': result.returncode, 'details': output_text(result.stdout)[-12000:]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--comfy-root', required=True)
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    try:
        result = run_startup_check(args.comfy_root, args.timeout)
    except Exception as error:
        result = {'startup_ok': False, 'reason': 'probe_error', 'details': str(error)}
    print(json.dumps(result, ensure_ascii=True))
    return 0 if result['startup_ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
