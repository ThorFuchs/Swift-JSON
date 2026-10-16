#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Independent stdlib byte-transport/PRNG oracle for the public native G2 consumer."""
import argparse
import hashlib
import json
import pathlib
import struct

ROOT = pathlib.Path(__file__).resolve().parents[1]
MASK = (1 << 64) - 1


def u64(value):
    return struct.pack('>Q', value)


def field(value):
    return u64(len(value)) + value


def digest(value):
    return hashlib.sha256(value).hexdigest()


def draws(seed):
    while True:
        seed = (seed + 0x9E3779B97F4A7C15) & MASK
        z = seed
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK
        yield z ^ (z >> 31)


def vectors():
    snapshot = digest(b'SwiftJSON-schema-snapshot-v1\n' + u64(1) + b'\0' + field(b'') + field(b'true'))
    corpus = digest(b'SwiftJSON-example-corpus-v1\n' + field(b'[null,false,0,"example",[],{}]'))
    profiles = json.loads((ROOT / 'Documentation/Architecture/ResourceProfiles.json').read_text())
    metrics = sum([profiles[k] for k in ['core', 'schema', 'streaming', 'patch', 'enhancement_limits']], [])
    metrics = [dict(m, metric=m.get('metric', m.get('id'))) for m in metrics]
    assert len(metrics) == 49 and len({m['metric'] for m in metrics}) == 49
    record = u64(49) + b''.join(field(m['metric'].encode()) + u64(m['balanced']) for m in metrics)
    policy = digest(b'SwiftJSON-example-policy-v1\n' + u64(16) + record * 3 + bytes([0, 1, 0, 0]) * 2)
    result = {'snapshot': snapshot, 'corpus': corpus, 'policy': policy}
    for name, profile in [('minimal', 0), ('demonstration', 1)]:
        trace = b'SwiftJSON-example-trace-v2\n' + b''.join(field(s.encode()) for s in ['s3-candidates-v4', snapshot, corpus, policy]) + u64(42) + bytes([profile])
        events = [(1, 0, 0)]
        index = 0
        if profile:
            raw = next(draws(42))  # Bound six has threshold four; this draw is accepted.
            assert raw >= ((1 << 64) % 6)
            events += [(3, raw, 6)]
            index = raw % 6
        events += [(2, 4, index), (4, 1, 1), (5, 1, profile)]
        trace += b''.join(bytes([code]) + u64(a) + u64(b) for code, a, b in events)
        values = [b'null', b'false', b'0', b'"example"', b'[]', b'{}']
        result[name] = {'trace': digest(trace), 'events': len(events), 'draws': profile,
                        'value_hex': values[index].hex(), 'trace_bytes': len(trace)}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--consumer-log')
    args = parser.parse_args()
    expected = vectors()
    if args.consumer_log:
        lines = pathlib.Path(args.consumer_log).read_text().splitlines()
        observed = [json.loads(line.removeprefix('G2_VECTORS ')) for line in lines if line.startswith('G2_VECTORS ')]
        assert len(observed) == 1 and observed[0] == expected, (observed, expected)
        print('SCHEMA_EXAMPLES_DETERMINISM passed profiles=2 metrics=49')
    else:
        print(json.dumps(expected, sort_keys=True, indent=2))


if __name__ == '__main__':
    main()
