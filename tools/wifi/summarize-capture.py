#!/usr/bin/env python3
"""Summarize a radiotap PCAP without publishing addresses or payloads.

TX radiotap records are counted separately from received frames. Extended-IV
checks are structural evidence, not decryption or FCS validation. Classic PCAP
does not contain tcpdump's kernel-drop statistics; retain those separately.
"""
import argparse
import collections
import hashlib
import json
import struct
from pathlib import Path


def summarize(path):
    data = path.read_bytes()
    formats = {
        b'\xd4\xc3\xb2\xa1': ('<', 1_000_000),
        b'\xa1\xb2\xc3\xd4': ('>', 1_000_000),
        b'\x4d\x3c\xb2\xa1': ('<', 1_000_000_000),
        b'\xa1\xb2\x3c\x4d': ('>', 1_000_000_000),
    }
    if len(data) < 24 or data[:4] not in formats:
        raise ValueError('Expected classic PCAP, not PCAPNG')
    endian, scale = formats[data[:4]]
    if struct.unpack_from(endian + 'I', data, 20)[0] != 127:
        raise ValueError('Expected IEEE802_11_RADIO link type')
    counts = collections.Counter()
    subtypes = collections.Counter()
    times = []
    offset = 24
    while offset < len(data):
        if offset + 16 > len(data):
            raise ValueError('Truncated PCAP record header')
        sec, fraction, size, original = struct.unpack_from(endian + 'IIII', data, offset)
        offset += 16
        if offset + size > len(data):
            raise ValueError('Truncated PCAP record')
        packet = data[offset:offset + size]
        offset += size
        counts['records'] += 1
        counts['snaplen_truncated'] += size < original
        times.append(sec + fraction / scale)
        if len(packet) < 8:
            counts['invalid_radiotap'] += 1
            continue
        version, _, rtlen, present = struct.unpack_from('<BBHI', packet)
        if version or not 8 <= rtlen <= len(packet):
            counts['invalid_radiotap'] += 1
            continue
        # TX_FLAGS belongs to word zero, even with extended presence words.
        if present & (1 << 15):
            counts['tx_radiotap_records'] += 1
            continue
        frame = packet[rtlen:]
        if len(frame) < 2:
            counts['short_mac_header'] += 1
            continue
        fc = int.from_bytes(frame[:2], 'little')
        kind, subtype = (fc >> 2) & 3, (fc >> 4) & 15
        counts['rx_records'] += 1
        subtypes[f'{kind}:{subtype}'] += 1
        if kind != 2 or subtype & 4:
            continue
        header = 24 + (6 if fc & 0x0300 == 0x0300 else 0)
        if subtype & 8:
            header += 2 + (4 if fc & 0x8000 else 0)
        if len(frame) <= header:
            counts['data_without_payload'] += 1
            continue
        counts['payload_data_rx'] += 1
        if not fc & 0x4000:
            counts['unprotected_payload_rx'] += 1
            continue
        counts['protected_payload_rx'] += 1
        counts['protected_unicast_rx'] += not bool(frame[4] & 1)
        body = frame[header:]
        if len(body) >= 8 and body[3] & 0x20:
            counts['protected_extended_iv_present'] += 1
        if body.startswith(b'\xaa\xaa\x03'):
            counts['protected_but_plain_llc'] += 1
    return {
        'file': path.name,
        'sha256': hashlib.sha256(data).hexdigest(),
        'duration_s': round(max(times) - min(times), 6) if times else 0,
        'counts': dict(sorted(counts.items())),
        'rx_type_subtype': dict(sorted(subtypes.items())),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pcap', type=Path, nargs='+')
    args = parser.parse_args()
    try:
        print(json.dumps([summarize(path) for path in args.pcap], indent=2))
    except (ValueError, OSError) as exc:
        parser.exit(1, f'{exc}\n')


if __name__ == '__main__':
    main()
