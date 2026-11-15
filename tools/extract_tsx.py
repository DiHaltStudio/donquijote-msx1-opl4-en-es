#!/usr/bin/env python3
"""Lossless extraction of these TSX KCS blocks; originals remain read-only."""
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def extract(path, dest):
    raw = path.read_bytes()
    assert raw[:8] == b'ZXTape!\x1a'
    dest.mkdir(parents=True, exist_ok=True)
    p = 10
    records = []
    name = 'unnamed'
    kind = None
    cas = bytearray()
    while p < len(raw):
        start = p
        tag = raw[p]
        p += 1
        if tag == 0x35:
            size = struct.unpack_from('<I', raw, p + 16)[0]
            p += 20 + size
        elif tag == 0x32:
            size = struct.unpack_from('<H', raw, p)[0]
            p += 2 + size
        elif tag == 0x20:
            p += 2
        elif tag == 0x4b:
            size = struct.unpack_from('<I', raw, p)[0]
            assert size >= 12
            data = raw[p + 16:p + 4 + size]
            assert len(data) == size - 12
            cas.extend(bytes.fromhex('1fa6debacc137d74'))
            cas.extend(data)
            p += 4 + size
            if len(data) == 16 and data[:10] in (b'\xea'*10, b'\xd0'*10, b'\xd3'*10):
                kind = data[0]
                name = data[10:].decode('ascii').strip()
            else:
                record = dict(index=len(records), name=name, type=kind, tsx_offset=start,
                              raw_sha256=hashlib.sha256(data).hexdigest())
                stem = f'{len(records):02d}-{name}'
                (dest / (stem + '.raw')).write_bytes(data)
                if kind == 0xd0:
                    begin, end, entry = struct.unpack_from('<HHH', data)
                    assert len(data) == end - begin + 7
                    record.update(load=begin, end=end, entry=entry, bytes=len(data)-6)
                    (dest / (stem + '.bin')).write_bytes(data[6:])
                else:
                    (dest / (stem + '.txt')).write_bytes(data.rstrip(b'\x1a'))
                record['stem'] = stem
                records.append(record)
        else:
            raise ValueError(f'Unknown TSX block {tag:02x} at {start:08x}')
        assert p <= len(raw)
    (dest / 'tape.cas').write_bytes(cas)
    manifest = dict(source=path.name, sha256=hashlib.sha256(raw).hexdigest(), records=records)
    (dest / 'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    return manifest

if __name__ == '__main__':
    for side in ('A', 'B'):
        path, = (ROOT / 'original').glob(f'*Side {side}*')
        result = extract(path, ROOT / 'build/extracted' / side)
        print(side, len(result['records']), result['sha256'])
