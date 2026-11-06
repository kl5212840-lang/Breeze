#!/usr/bin/env python3
"""Small offline documentation gate for the native-video work area.

Checks formatting, closed fences, local link destinations, and the current
bounded task list. It does not certify UI quality or real-site acceptance.
Run explicitly before closeout; it does not replace or modify local git hooks.
"""

from pathlib import Path
import re
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[2]
FILES = [
    ROOT / "AGENTS.md",
    *(ROOT / "docs" / name for name in [
        "hanime_native_video_taskbook.md",
        "hanime_handoff_2026-10-23.md",
        "hanime_completion_audit.md",
        "video_settings_scope.md",
    ]),
]
LINK = re.compile(r"(?<!!)\[[^\]\n]+\]\(([^\s)]+)(?:\s+\"[^\"]*\")?\)")


def main() -> int:
    errors = []
    for path in FILES:
        text = path.read_text(encoding="utf-8")
        fence = None
        if not text.endswith("\n"):
            errors.append(f"{path.name}: missing final newline")
        for number, line in enumerate(text.splitlines(), 1):
            if line != line.rstrip():
                errors.append(f"{path.name}:{number}: trailing whitespace")
            marker = re.match(r"^\s*(`{3,}|~{3,})", line)
            if marker:
                token = marker[1][0]
                fence = None if fence == token else token if fence is None else fence
                continue
            if fence:
                continue
            for match in LINK.finditer(line):
                target = match[1].strip("<>")
                if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("#"):
                    continue
                target = unquote(target.split("#", 1)[0])
                target = re.sub(r":\d+$", "", target)
                if target and not (path.parent / target).exists():
                    errors.append(f"{path.name}:{number}: missing local destination {target}")
        if fence:
            errors.append(f"{path.name}: unclosed code fence")
    taskbook = FILES[1].read_text(encoding="utf-8")
    ids = re.findall(r"^\| (U\d{2}) \|", taskbook, re.M)
    expected = [f"U{i:02}" for i in range(1, 9)]
    if ids != expected:
        errors.append("taskbook: U01–U08 must occur once and in order in the task table")
    for error in errors:
        print(error)
    if errors:
        return 1
    print("Video UI docs: 5 files, local destinations and U01–U08 order checked.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
