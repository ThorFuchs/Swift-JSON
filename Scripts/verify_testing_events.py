#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Regression probes for the exact Swift Testing event receipt reader."""
import collections
import json
from testing_events import read_events


def records():
    identifier = 'ProbeTests.value(text:)/Probe.swift:1:1'
    return [
        {'kind': 'event', 'payload': {'kind': 'runStarted'}},
        {'kind': 'test', 'payload': {'kind': 'function', 'id': identifier, 'name': 'value(text:)', 'isParameterized': True}},
        *[{'kind': 'event', 'payload': {'kind': kind, 'testID': identifier}} for kind in
          ['testStarted', 'testCaseStarted', 'testCaseEnded', 'testEnded']],
        {'kind': 'event', 'payload': {'kind': 'runEnded', 'messages': [{'text': 'Unicode \u2028 \u0085 remains inside the JSON record.'}]}},
    ]


def encode(rows):
    return ''.join(json.dumps(row, ensure_ascii=False) + '\n' for row in rows)


def main():
    original = records()
    report = read_events(encode(original))
    assert report['bundle_counts'] == [1] and report['parameter_case_invocations'] == 1
    cases = 1
    for kind in ['testStarted', 'testCaseStarted', 'testCaseEnded', 'testEnded', 'runEnded']:
        mutant = [r for r in original if r['payload']['kind'] != kind]
        try:
            read_events(encode(mutant))
        except ValueError:
            cases += 1
        else:
            raise AssertionError('Missing completion/discovery accepted: ' + kind)
    for extra in [original[1], original[2], {'kind': 'event', 'payload': {'kind': 'issueRecorded'}},
                  {'kind': 'event', 'payload': {'kind': 'testSkipped'}}]:
        try:
            read_events(encode(original + [extra]))
        except ValueError:
            cases += 1
        else:
            raise AssertionError('Duplicate, issue or skip accepted')
    try:
        read_events(encode(original) + '{')
    except ValueError:
        cases += 1
    else:
        raise AssertionError('Malformed event stream accepted')
    print('TESTING_EVENT_RECEIPTS passed cases=' + str(cases))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
