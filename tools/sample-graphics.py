#!/usr/bin/env python3
"""Low-rate CPU/frequency snapshots; GPU frequency is not GPU utilization."""
import glob
import json
import sys
import time

for _ in range(int(sys.argv[1])):
    row = {"time": time.monotonic()}
    row["cpu_ticks"] = list(map(int, open("/proc/stat").readline().split()[1:9]))
    row["display_irqs"] = {}
    for line in open("/proc/interrupts"):
        fields = line.split()
        if not fields or fields[-1] not in ("dsi_isr", "msm-kms"):
            continue
        counts = []
        for value in fields[1:]:
            if not value.isdecimal():
                break
            counts.append(int(value))
        row["display_irqs"][fields[-1]] = sum(counts)
    vmstat = dict(line.split() for line in open("/proc/vmstat"))
    row["oom_kill"] = int(vmstat.get("oom_kill", 0))
    meminfo = dict(line.split(":", 1) for line in open("/proc/meminfo"))
    row["mem_available_kib"] = int(meminfo["MemAvailable"].split()[0])
    for key, path in (
        ("cpu_khz", "/sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq"),
        ("gpu_hz", "/sys/class/devfreq/fdb00000.gpu/cur_freq"),
        ("axi_hz", "/sys/kernel/debug/clk/mmss_axi_clk_src/clk_rate"),
    ):
        try:
            row[key] = int(open(path).read())
        except OSError:
            row[key] = None
    # These sysfs reads do not acquire a runtime-PM reference or wake the GPU.
    row["gpu_power"] = {}
    for name in ("control", "runtime_status", "runtime_active_time",
                 "runtime_suspended_time", "autosuspend_delay_ms"):
        try:
            with open("/sys/bus/platform/devices/fdb00000.gpu/power/" + name) as power:
                row["gpu_power"][name] = power.read().strip()
        except OSError:
            row["gpu_power"][name] = None
    row["process_ticks"] = {}
    for path in glob.glob("/proc/[0-9]*/stat"):
        try:
            stat = open(path).read()
            name = stat[stat.index("(") + 1:stat.rindex(")")]
            if name in ("kwin_wayland", "plasmashell", "phoc", "phosh", "qmlscene"):
                fields = stat[stat.rindex(")") + 2:].split()
                row["process_ticks"][path.split("/")[2]] = {
                    "name": name, "ticks": int(fields[11]) + int(fields[12]),
                    "rss_pages": int(fields[21])}
        except (OSError, ValueError):
            pass
    print(json.dumps(row), flush=True)
    time.sleep(1)
