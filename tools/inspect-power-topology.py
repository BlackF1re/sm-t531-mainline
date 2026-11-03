#!/usr/bin/python3
# SPDX-License-Identifier: MIT
"""Export sleep-related DT configuration without probing hardware or battery.

Requires python3-libfdt. Inputs are DTB files; configuration is not proof that
the described sleep states were actually entered.
"""
import argparse
import hashlib
import json
import pathlib
import struct

import libfdt


def properties(fdt, offset):
    result = {}
    prop = fdt.first_property_offset(offset, quiet=(libfdt.NOTFOUND,))
    while prop >= 0:
        value = fdt.get_property_by_offset(prop)
        result[value.name] = bytes(value)
        prop = fdt.next_property_offset(prop, quiet=(libfdt.NOTFOUND,))
    return result


def decode(value):
    if not value:
        return True
    if value[0] != 0 and value.endswith(b'\0') and all(c == 0 or 32 <= c < 127 for c in value):
        return value.decode().split('\0')[:-1]
    if len(value) % 4 == 0:
        return list(struct.unpack('>' + 'I' * (len(value) // 4), value))
    return {'bytes_hex': value.hex()}


def inspect(path):
    data = pathlib.Path(path).read_bytes()
    fdt = libfdt.Fdt(data)
    nodes = {}
    offset, depth = -1, 0
    while True:
        offset, depth = fdt.next_node(offset, depth, quiet=(libfdt.NOTFOUND,))
        if offset < 0 or depth < 0:
            break
        nodes[fdt.get_path(offset)] = properties(fdt, offset)
    handles = {
        struct.unpack('>I', props['phandle'])[0]: name
        for name, props in nodes.items() if 'phandle' in props
    }
    exported = {}
    for name, props in nodes.items():
        compat = props.get('compatible', b'').split(b'\0')
        controller = any(any(word in c for word in (
            b'spm', b'saw2', b'lpm-levels', b'cpu-modes', b'system-modes',
            b'cpu-idle', b'idle-state', b'mpm', b'rpmpd', b'gdsc',
            b'cpr-regulator', b'rpm-regulator', b'pm-boot',
        )) for c in compat)
        if not (controller or name.startswith('/cpus/') or
                name.startswith('/opp-table') or 'power-domains' in props or
                '/qcom,lpm-levels/' in name):
            continue
        selected = {}
        for key, value in props.items():
            if key in ('compatible', 'status', 'reg', 'regulator-name',
                       'power-domains', '#power-domain-cells', 'required-opps',
                       'cpu-idle-states', 'operating-points-v2', 'opp-hz',
                       'opp-suspend', 'opp-level', 'enable-method') or (
                    key in ('interrupts', 'interrupt-parent', 'mboxes',
                            'qcom,gic-map', 'qcom,gpio-map', 'qcom,mpm-pin-map',
                            'qcom,mpm-pin-count', 'qcom,ipc-bit-offset')) or (
                    key.startswith('qcom,') and any(word in key for word in (
                        'saw2', 'spm', 'mode', 'latency', 'overhead', 'l2',
                        'sync', 'rpm', 'core-id', 'set', 'resource', 'voltage',
                        'consumer-supplies', 'broadcast', 'vctl', 'port'))):
                selected[key] = ({'bytes_hex': value.hex()}
                                 if 'spm-cmd-' in key else decode(value))
            if key.endswith('-supply') or key in ('required-opps',
                    'cpu-idle-states', 'operating-points-v2', 'power-domains'):
                cells = decode(value)
                if isinstance(cells, list):
                    selected[key + ':references'] = [
                        handles[c] for c in cells if isinstance(c, int) and c in handles
                    ] if key != 'power-domains' else domain_refs(cells, handles, nodes)
        if selected:
            exported[name] = selected
    return {'dtb_sha256': hashlib.sha256(data).hexdigest(),
            'configuration_only': True, 'nodes': exported}


def domain_refs(cells, handles, nodes):
    result = []
    index = 0
    while index < len(cells):
        provider = handles[cells[index]]
        count = struct.unpack('>I', nodes[provider]['#power-domain-cells'])[0]
        if index + 1 + count > len(cells):
            raise ValueError('Truncated power-domains property')
        result.append({'provider': provider, 'args': cells[index + 1:index + 1 + count]})
        index += 1 + count
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('dtb')
    args = parser.parse_args()
    print(json.dumps(inspect(args.dtb), ensure_ascii=False, indent=2))
