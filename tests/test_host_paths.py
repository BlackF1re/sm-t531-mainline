"""Host path contracts: no builds, network access, or device operations."""
import json
import os
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
VARIABLES = ('WORK_DIR', 'ARTIFACTS_DIR', 'KERNEL_SRC', 'KERNEL_OUT', 'SOURCES_DIR')


def paths(profile='main', **overrides):
    env = {key: value for key, value in os.environ.items() if key not in VARIABLES}
    env.update(overrides)
    script = '''set -euo pipefail
source scripts/lib/host-paths.sh
t531_host_paths "$1"
python3 -c 'import json,os; print(json.dumps({k:os.environ[k] for k in
("WORK_DIR", "ARTIFACTS_DIR", "KERNEL_SRC", "KERNEL_OUT")}))'
'''
    result = subprocess.check_output(['bash', '-c', script, 'paths', profile],
                                     cwd=ROOT, env=env, text=True)
    return {key: Path(value).resolve() for key, value in json.loads(result).items()}


class HostPaths(unittest.TestCase):
    def test_main_defaults(self):
        result = paths()
        self.assertEqual(result['KERNEL_SRC'], ROOT.parent / 'sources/linux-mainline')
        self.assertEqual(result['KERNEL_OUT'], ROOT.parent / 'build/sm-t531/out')

    def test_bootstrap_isolated_from_main(self):
        main, bootstrap = paths(), paths('bootstrap')
        for key in ('KERNEL_SRC', 'KERNEL_OUT', 'ARTIFACTS_DIR'):
            self.assertNotEqual(main[key], bootstrap[key], key)

    def test_workspace_and_source_overrides(self):
        result = paths(WORK_DIR='/tmp/t531-path-test', SOURCES_DIR='/tmp/t531-sources')
        self.assertEqual(result['ARTIFACTS_DIR'], Path('/tmp/t531-path-test/artifacts/current'))
        self.assertEqual(result['KERNEL_SRC'], Path('/tmp/t531-sources/linux-mainline'))

    def test_explicit_paths_override_both_profiles(self):
        expected = dict(KERNEL_SRC='/tmp/t531-source', KERNEL_OUT='/tmp/t531-out',
                        ARTIFACTS_DIR='/tmp/t531-artifacts')
        for profile in ('main', 'bootstrap'):
            result = paths(profile, **expected)
            for key, value in expected.items():
                self.assertEqual(result[key], Path(value))
