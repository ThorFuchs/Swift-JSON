#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Observe and replay GitHub's latest published stable release for documentation."""
import argparse
import hashlib
import json
import os
import pathlib
import re
import sys
import urllib.parse
import urllib.request

REPOSITORY = 'https://github.com/ThorFuchs/Swift-JSON'
API_URL = 'https://api.github.com/repos/ThorFuchs/Swift-JSON/releases/latest'
MAX_METADATA_BYTES = 2 * 1024 * 1024


class NoRedirect(urllib.request.HTTPRedirectHandler):
    """Keep the optional read token on the single approved GitHub API endpoint."""
    def redirect_request(self, request, response, code, message, headers, url):
        return None


def release_metadata(data):
    """Validate external metadata and advertise only an actual uploaded DocC asset."""
    if not isinstance(data, dict):
        raise ValueError('Expected a GitHub release object')
    tag = data.get('tag_name')
    if (not isinstance(tag, str) or not re.fullmatch(
            r'v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?', tag)):
        raise ValueError('Latest release must have a stable semantic version tag')
    if (data.get('draft') is not False or data.get('prerelease') is not False
            or not isinstance(data.get('published_at'), str) or not data['published_at']
            or type(data.get('id')) is not int or data['id'] <= 0):
        raise ValueError('Latest release must be published, non-draft and non-prerelease')
    encoded_tag = urllib.parse.quote(tag, safe='')
    release_url = REPOSITORY + '/releases/tag/' + encoded_tag
    if data.get('html_url') != release_url:
        raise ValueError('Release URL must belong to this repository and tag')
    version = tag.removeprefix('v')
    asset_name = 'Swift-JSON-' + version + '-DocC.tar.gz'
    assets = data.get('assets')
    if not isinstance(assets, list) or any(not isinstance(a, dict) for a in assets):
        raise ValueError('Malformed release asset inventory')
    matches = [a for a in assets if a.get('name') == asset_name]
    if len(matches) > 1:
        raise ValueError('Ambiguous compiled DocC asset')
    documentation_url = None
    if matches:
        asset = matches[0]
        expected_url = REPOSITORY + '/releases/download/' + encoded_tag + '/' + urllib.parse.quote(asset_name, safe='')
        if (asset.get('state') != 'uploaded' or type(asset.get('size')) is not int
                or asset['size'] <= 0 or asset.get('browser_download_url') != expected_url):
            raise ValueError('Compiled DocC asset is unavailable or has a foreign URL')
        documentation_url = expected_url
    return {'release_id': data['id'], 'tag': tag, 'version': version,
            'published_at': data['published_at'], 'release_url': release_url,
            'source_url': REPOSITORY + '/tree/' + encoded_tag + '/Sources',
            'documentation_url': documentation_url}


def decode_metadata(raw):
    if len(raw) > MAX_METADATA_BYTES:
        raise ValueError('Release metadata exceeds the 2 MiB build-input bound')
    result = release_metadata(json.loads(raw))
    return dict(result, api_url=API_URL, metadata_sha256=hashlib.sha256(raw).hexdigest())


def load_metadata(path):
    with pathlib.Path(path).open('rb') as stream:
        return decode_metadata(stream.read(MAX_METADATA_BYTES + 1))


def fetch_metadata(output):
    headers = {'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2026-03-10',
               'User-Agent': 'Swift-JSON-documentation-build'}
    token = os.environ.get('GITHUB_TOKEN')
    if token:
        headers['Authorization'] = 'Bearer ' + token
    request = urllib.request.Request(API_URL, headers=headers)
    with urllib.request.build_opener(NoRedirect()).open(request, timeout=30) as response:
        if response.status != 200 or response.url != API_URL:
            raise ValueError('Unexpected latest-release response or redirect')
        raw = response.read(MAX_METADATA_BYTES + 1)
    result = decode_metadata(raw)
    output = pathlib.Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(raw)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, help='Ignored JSON snapshot, retained with CI receipts')
    args = parser.parse_args()
    try:
        print(json.dumps(fetch_metadata(args.output), indent=2))
    except (OSError, ValueError) as error:
        print('DOCUMENTATION_RELEASE failed: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
