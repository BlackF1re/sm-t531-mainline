#!/usr/bin/env python3
"""Bounded radiotap probe-request check against a specified test AP.

Uses the current station source address by default. Observe responses separately;
a successful send() is not proof that the radio transmitted a frame.
"""
import argparse
import socket
import struct
import time
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--interface', required=True)
p.add_argument('--station', default='wlan0')
p.add_argument('--bssid', required=True)
p.add_argument('--ssid', required=True)
p.add_argument('--count', type=int, default=3)
p.add_argument('--source')
a = p.parse_args()
if not 1 <= a.count <= 5:
    p.error('count must be between 1 and 5')
ssid = a.ssid.encode()
if not 1 <= len(ssid) <= 32:
    p.error('SSID must contain 1..32 bytes')

def mac(text):
    value = bytes.fromhex(text.replace(':', ''))
    if len(value) != 6 or value[0] & 1:
        p.error('a unicast six-byte address is required')
    return value

source = mac(a.source or Path('/sys/class/net', a.station, 'address').read_text().strip())
bssid = mac(a.bssid)
# TX_FLAGS: keep the supplied sequence number; use normal ACK handling.
radiotap = struct.pack('<BBHIH', 0, 0, 10, 1 << 15, 0x0010)
rates = bytes([1, 8, 0x82, 0x84, 0x8b, 0x96, 0x0c, 0x12, 0x18, 0x24])
with socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3)) as s:
    s.bind((a.interface, 0))
    for n in range(a.count):
        header = struct.pack('<HH', 0x0040, 0) + bssid + source + bssid + struct.pack('<H', (0x531 + n) << 4)
        frame = radiotap + header + bytes([0, len(ssid)]) + ssid + rates
        sent = s.send(frame)
        print(f'monotonic={time.monotonic():.6f} seq={0x531+n} accepted_bytes={sent}', flush=True)
        time.sleep(0.5)
