import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1] / 'tools/summarize-presentation-critical.py'

class PresentationCriticalTests(unittest.TestCase):
    def run_trace(self, text):
        with tempfile.TemporaryDirectory() as directory:
            trace = Path(directory) / 'events.txt'
            trace.write_text(text)
            return subprocess.run([sys.executable, str(TOOL), str(trace)], text=True, capture_output=True)

    def test_pending_job_and_unflushed_late_interval(self):
        trace = '''swapper 0 [000] 1.000000: drm:drm_vblank_event_delivered: crtc=0
QSGRenderThread 10 [001] 1.001000: drm_msm_gpu:msm_gpu_submit: id=1 pid=10
worker 20 [000] 1.025000: drm_msm_gpu:msm_gpu_submit_retired: id=1 pid=10
worker 20 [000] 1.030000: drm_msm_atomic:msm_atomic_flush_commit: crtc_mask=1
swapper 0 [000] 1.033333: drm:drm_vblank_event_delivered: crtc=0
'''
        result = self.run_trace(trace)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data['late']['frames'], 1)
        self.assertEqual(data['late']['pending_gpu_frames'], 1)
        self.assertEqual(data['late']['flushed_by_deadline'], 0)
        self.assertEqual(data['short']['frames'], 0)
        self.assertEqual(data['unretired'], 0)

    def test_lost_trace_rejected(self):
        self.assertNotEqual(self.run_trace('PERF_RECORD_LOST 10').returncode, 0)

    def test_empty_trace_rejected(self):
        self.assertNotEqual(self.run_trace('').returncode, 0)

if __name__ == '__main__':
    unittest.main()
