#!/usr/bin/env python3
"""Turn the release-sideinstaller workflow's changelog input into Markdown.

The Run workflow form on GitHub has a one-line box for it, so a line break is
typed as \\n (\\n\\n for a blank line). Everything else is kept as typed:
# / ## / ### headings, **bold**, *italic*, - lists, `code`, links. Notes sent
from the command line or the API can hold real line breaks instead, and those
stay too.

  CHANGELOG="### Fixed\\n- **Sign-in** works" scripts/release_notes.py notes.md

Writes the notes to the path given (stdout without one). A literal backslash-n
is typed \\\\n. Exits non-zero when the notes come out empty.
"""

import os
import re
import sys


def decode(raw: str) -> str:
    text = raw.replace("\r\n", "\n").replace("\r", "\n")
    # \n -> line break, \\n -> a literal \n.
    text = re.sub(r"\\(\\n|n)", lambda m: "\\n" if m.group(1) == "\\n" else "\n", text)
    # Trailing spaces would turn into Markdown hard breaks nobody typed.
    lines = [line.rstrip() for line in text.split("\n")]
    return "\n".join(lines).strip("\n") + "\n"


def main() -> int:
    notes = decode(os.environ.get("CHANGELOG", ""))
    if not notes.strip():
        print("error: the changelog is empty", file=sys.stderr)
        return 1
    if len(sys.argv) > 1:
        with open(sys.argv[1], "w", encoding="utf-8") as f:
            f.write(notes)
    else:
        sys.stdout.write(notes)
    return 0


if __name__ == "__main__":
    sys.exit(main())
