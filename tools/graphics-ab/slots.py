#!/usr/bin/env python3
"""Coherent boot-file selection. Library: caller must validate/mount the SD device."""
import hashlib
import os
from pathlib import Path
import re
import shutil
import tempfile

FILES = ('zImage', 'initramfs.cpio.gz', 'kernel.sha256', 'kexec.cmdline')

def flush(directory):
    fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)

def verify(directory):
    directory = Path(directory)
    lines = (directory / 'kernel.sha256').read_text().splitlines()
    seen = set()
    for line in lines:
        match = re.fullmatch(r'([0-9a-f]{64})  (zImage|initramfs\.cpio\.gz)', line)
        if not match or match[2] in seen:
            raise ValueError('Invalid boot checksum manifest')
        seen.add(match[2])
        if hashlib.sha256((directory / match[2]).read_bytes()).hexdigest() != match[1]:
            raise ValueError('Boot checksum mismatch')
    if seen != {'zImage', 'initramfs.cpio.gz'}:
        raise ValueError('Incomplete boot manifest')
    if not (directory / 'kexec.cmdline').read_text().strip():
        raise ValueError('Missing boot command line')

def valid_name(name):
    if not re.fullmatch(r'[a-zA-Z0-9_-]+', name):
        raise ValueError('Invalid slot name')

def stage(root, source, name):
    root, source = Path(root), Path(source)
    valid_name(name)
    verify(source)
    slots = root / 'graphics-slots'
    slots.mkdir(exist_ok=True)
    destination = slots / name
    if destination.exists():
        verify(destination)
        if any((source / f).read_bytes() != (destination / f).read_bytes() for f in FILES):
            raise ValueError('Existing slot has different contents')
        return
    required = sum((source / f).stat().st_size for f in FILES) + 1024 * 1024
    if shutil.disk_usage(root).free < required:
        raise ValueError('Insufficient boot partition space')
    temporary = Path(tempfile.mkdtemp(prefix='.staging-', dir=slots))
    try:
        for name0 in FILES:
            shutil.copyfile(source / name0, temporary / name0)
            with (temporary / name0).open('rb') as stream:
                os.fsync(stream.fileno())
        verify(temporary)
        flush(temporary)
        os.rename(temporary, destination)
        flush(slots)
    finally:
        if temporary.exists():
            shutil.rmtree(temporary)

def link(root, name, target):
    temporary = root / (name + '.next')
    if temporary.exists() or temporary.is_symlink():
        temporary.unlink()
    temporary.symlink_to(target)
    os.replace(temporary, root / name)
    flush(root)

def initialize(root, golden, checkpoint=lambda: None):
    root = Path(root)
    stage(root, root, golden)
    # Conversion preserves the old bytes after each individual replacement.
    link(root, 'graphics-current', 'graphics-slots/' + golden)
    checkpoint()
    for name in FILES:
        link(root, name, 'graphics-current/' + name)
        checkpoint()
    verify(root)

def select(root, name):
    root = Path(root)
    valid_name(name)
    for filename in FILES:
        if not (root / filename).is_symlink() or os.readlink(root / filename) != 'graphics-current/' + filename:
            raise ValueError('Boot root is not initialized for coherent selection')
    verify(root / 'graphics-slots' / name)
    link(root, 'graphics-current', 'graphics-slots/' + name)
    verify(root)

def retire(root, name, backup):
    """Remove an unselected non-golden slot only after verifying its saved copy."""
    root, backup = Path(root), Path(backup)
    valid_name(name)
    destination = root / 'graphics-slots' / name
    if name == 'golden' or os.readlink(root / 'graphics-current') == 'graphics-slots/' + name:
        raise ValueError('Cannot retire golden or selected boot slot')
    if destination.is_symlink() or not destination.is_dir():
        raise ValueError('Slot must be a real directory')
    verify(destination)
    verify(backup)
    if any((destination / f).read_bytes() != (backup / f).read_bytes() for f in FILES):
        raise ValueError('Saved copy differs from boot slot')
    shutil.rmtree(destination)
    flush(destination.parent)
