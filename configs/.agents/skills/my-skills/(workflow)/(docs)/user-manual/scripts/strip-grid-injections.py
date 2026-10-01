#!/usr/bin/env python3
"""Removes the scripts Grid injects when it serves a document, so a downloaded `/raw` can be re-uploaded.

Grid adds them on every request (state API, popup allowlist, URL sync). Uploading them back stores
duplicates that pile up version after version.

    python3 strip-grid-injections.py downloaded.html clean.html
"""
import re
import sys
from pathlib import Path

GRID_SCRIPT_MARKERS = (
    'function _ok(r,onOk)',
    'window.GRID=',
    '/* Grid: only allow approved Grid domains',
    '/* Grid: sync iframe URL mutations',
)


def strip_grid_injections(html: str) -> tuple[str, int]:
    """Returns the HTML without Grid-injected scripts and how many were removed."""
    removed = 0

    def drop_if_injected(match: re.Match) -> str:
        nonlocal removed
        if any(marker in match.group(0) for marker in GRID_SCRIPT_MARKERS):
            removed += 1
            return ''
        return match.group(0)

    cleaned = re.sub(r'<script>.*?</script>\s*', drop_if_injected, html, flags=re.S)
    return cleaned, removed


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit('Usage: strip-grid-injections.py <downloaded.html> <clean.html>')
    source, target = Path(sys.argv[1]), Path(sys.argv[2])
    cleaned, removed = strip_grid_injections(source.read_text())
    if any(marker in cleaned for marker in GRID_SCRIPT_MARKERS):
        raise SystemExit(f'strip-grid-injections: Grid markers still present in {source}')
    target.write_text(cleaned)
    print(f'strip-grid-injections: removed {removed} Grid scripts -> {target}')


if __name__ == '__main__':
    main()
