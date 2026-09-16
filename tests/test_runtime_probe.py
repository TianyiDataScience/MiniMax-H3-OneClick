import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location('runtime_probe', ROOT / 'runtime-probe.py')
probe = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(probe)


class RuntimeProbeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='h3-probe-test-')
        self.addCleanup(self.temporary.cleanup)
        self.comfy = Path(self.temporary.name) / 'ComfyUI'
        self.comfy.mkdir()
        (self.comfy / 'main.py').write_text('pass\n', encoding='utf-8')
        self.environment = patch.dict(os.environ, CUDA_VISIBLE_DEVICES='GPU-11111111-1111-1111-1111-111111111111')
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def test_success_uses_isolated_directories_and_selected_gpu(self):
        isolated = []

        def run(command, **options):
            self.assertIn('--quick-test-for-ci', command)
            self.assertIn('--disable-all-custom-nodes', command)
            self.assertNotIn('--auto-launch', command)
            self.assertEqual(command[command.index('--cuda-device') + 1], os.environ['CUDA_VISIBLE_DEVICES'])
            self.assertEqual(command[command.index('--database-url') + 1], 'sqlite:///:memory:')
            self.assertEqual(options['timeout'], 180)
            self.assertEqual(options['env']['PYTHONIOENCODING'], 'utf-8')
            for name in ('user', 'input', 'output', 'temp'):
                directory = Path(command[command.index(f'--{name}-directory') + 1])
                self.assertTrue(directory.is_dir())
                self.assertNotIn(self.comfy, directory.parents)
                isolated.append(directory)
            return subprocess.CompletedProcess(command, 0, 'startup complete')

        with patch.object(probe.subprocess, 'run', side_effect=run):
            self.assertTrue(probe.run_startup_check(self.comfy)['startup_ok'])
        self.assertTrue(all(not path.exists() for path in isolated))

    def test_dependency_block_is_not_success(self):
        message = 'ImportError: DLL load failed while importing _dop: application control blocked this file'
        with patch.object(probe.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, message)):
            result = probe.run_startup_check(self.comfy)
        self.assertFalse(result['startup_ok'])
        self.assertIn('_dop', result['details'])

    def test_timeout_is_not_success(self):
        with patch.object(probe.subprocess, 'run', side_effect=subprocess.TimeoutExpired([], 1, output=b'waiting')):
            result = probe.run_startup_check(self.comfy, timeout=1)
        self.assertFalse(result['startup_ok'])
        self.assertEqual(result['reason'], 'timeout')
        self.assertIn('waiting', result['details'])

    def test_launch_failure(self):
        with patch.object(probe.subprocess, 'run', side_effect=OSError('blocked executable')):
            self.assertEqual(probe.run_startup_check(self.comfy)['reason'], 'launch_error')

    def test_missing_main_and_gpu(self):
        self.assertEqual(probe.run_startup_check(self.comfy / 'missing')['reason'], 'missing_main')
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(probe.run_startup_check(self.comfy)['reason'], 'missing_gpu')

    def test_cli_success_and_failure_with_real_child(self):
        for code in (0, 7):
            (self.comfy / 'main.py').write_text(f'import sys\nprint("fixture child")\nsys.exit({code})\n', encoding='utf-8')
            result = subprocess.run([sys.executable, '-B', str(ROOT / 'runtime-probe.py'),
                                     '--comfy-root', str(self.comfy)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0 if code == 0 else 1)
            self.assertEqual(json.loads(result.stdout)['startup_ok'], code == 0)

    def test_real_child_is_stopped_on_timeout(self):
        (self.comfy / 'main.py').write_text('import time\ntime.sleep(10)\n', encoding='utf-8')
        result = probe.run_startup_check(self.comfy, timeout=0.2)
        self.assertFalse(result['startup_ok'])
        self.assertEqual(result['reason'], 'timeout')


if __name__ == '__main__':
    unittest.main()
