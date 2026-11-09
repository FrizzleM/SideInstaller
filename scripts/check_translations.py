#!/usr/bin/env python3
"""Check that every string the app translates has a translation in each language.

The app's copy is English, passed to `L("…")` (ios-app/Localization.swift), and
each language is a `[String: String]` table keyed by that English string
(ios-app/*Strings.swift). A key a table lacks falls back to English without a
word, so nothing but this check notices it. It reports, per language:

  missing      a string the app passes to `L` that the table lacks
  stale        a table entry no `L` call uses any more (a note, not a failure)

and fails on what breaks the app whatever the coverage:

  duplicate    the same key twice in one table: Swift stops the app with
               "Dictionary literal contains duplicate keys" the first time
               that language is drawn
  placeholder  a translation whose %@ / %d / %lld… differ from its key's:
               String(format:) reads the wrong argument, or crashes
  dynamic      `L("…\\(x)…")`: the key changes with x, so no table matches it

  scripts/check_translations.py                  report; fails on the errors above
  scripts/check_translations.py --strict         also fails on any missing string
  scripts/check_translations.py --base <rev>     also fails on strings missing now
                                                 that weren't at <rev> (the PR check)

With --base, a language that already had gaps at <rev> may keep them; only new
ones fail. Strings the app translates without a literal at the call (a label
read from a value) are listed in EXTRA_KEY_SOURCES below. Writes a Markdown
summary to $GITHUB_STEP_SUMMARY and annotations when run on GitHub Actions.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIRS = ["ios-app", "ios-live-activity"]
TABLE_GLOB = "ios-app/*Strings.swift"

# Calls whose first string literal is translated later with `L(value)`:
#   ProblemReport's details    Detail(label: "Device", …), shown as L(detail.label)
#   ProblemReport.connection   connection("CoreDeviceProxy", …), a Detail label
EXTRA_KEY_SOURCES = [
    r"\bDetail\(\s*label:\s*",
    r"\bconnection\(\s*",
]
# Set literals whose entries are translated later: Engine's isideload errors,
# shown as L($0) when they're one of these.
EXTRA_KEY_SETS = [r"\bisideloadErrors\s*:\s*Set<String>\s*=\s*\["]

# Names that read the same in every language, so a table needn't repeat them.
SAME_IN_EVERY_LANGUAGE = {
    "Anisette",
    "Discord",
    "LocalDevVPN",
    "SideInstaller",
    "Wi-Fi",
    "iOS",
}

FORMAT_SPEC = re.compile(
    r"%(?:(\d+)\$)?[-+ #0']*(?:\d+|\*)?(?:\.(?:\d+|\*))?(hh|h|ll|l|q|L|z|t|j)?([@dDiuUxXoOfFeEgGaAcCsSp%])"
)


# --- Swift string literals ---------------------------------------------------


@dataclass
class Literal:
    value: str
    line: int
    interpolated: bool


def lex(text: str) -> tuple[str, list[Literal]]:
    """The code with each string literal replaced by \\x00<n>\\x00, and the
    literals. Comments are blanked, so a commented-out L("…") isn't counted."""
    out: list[str] = []
    literals: list[Literal] = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        if text.startswith("/*", i):
            depth, j = 1, i + 2
            while j < n and depth:
                if text.startswith("/*", j):
                    depth, j = depth + 1, j + 2
                elif text.startswith("*/", j):
                    depth, j = depth - 1, j + 2
                else:
                    j += 1
            out.append("\n" * text.count("\n", i, j))
            i = j
            continue
        if text.startswith("#/", i):  # a regex literal, #/…/#
            j = text.find("/#", i + 2)
            j = n if j < 0 else j + 2
            out.append(" " * (j - i))
            i = j
            continue
        m = OPENING.match(text, i) if c in '"#' else None
        if m:
            lit, end = read_literal(text, i, len(m.group(1)), m.group(2) == '"""')
            out.append(f"\x00{len(literals)}\x00")
            out.append("\n" * text.count("\n", i, end))
            literals.append(lit)
            i = end
            continue
        out.append(c)
        i += 1
    return "".join(out), literals


ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "0": "\0", "\\": "\\", '"': '"', "'": "'"}


def read_literal(text: str, start: int, hashes: int, multiline: bool) -> tuple[Literal, int]:
    line = text.count("\n", 0, start) + 1
    quote = '"""' if multiline else '"'
    close = quote + "#" * hashes
    escape = "\\" + "#" * hashes
    i = start + hashes + len(quote)
    if multiline and text.startswith("\n", i):
        i += 1
    chars: list[str] = []
    interpolated = False
    n = len(text)
    while i < n:
        if text.startswith(close, i):
            i += len(close)
            break
        if text.startswith(escape, i):
            j = i + len(escape)
            nxt = text[j] if j < n else ""
            if nxt == "(":
                interpolated = True
                chars.append("\\(…)")
                i = skip_interpolation(text, j)
                continue
            if nxt == "u" and text.startswith("{", j + 1):
                k = text.index("}", j)
                chars.append(chr(int(text[j + 2 : k], 16)))
                i = k + 1
                continue
            if multiline and nxt == "\n":  # line continuation
                i = j + 1
                continue
            chars.append(ESCAPES.get(nxt, nxt))
            i = j + 1
            continue
        chars.append(text[i])
        i += 1
    value = "".join(chars)
    if multiline:
        value = dedent_multiline(value)
    return Literal(value, line, interpolated), i


def skip_interpolation(text: str, i: int) -> int:
    """From the ( of \\( to just past its ), stepping over nested strings."""
    depth, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i + 1
        elif c == '"':
            _, i = read_literal(text, i, 0, text.startswith('"""', i))
            continue
        i += 1
    return i


def dedent_multiline(value: str) -> str:
    # The closing """'s indentation is stripped from every line; the last line
    # (that indentation) and its line break aren't part of the string.
    lines = value.split("\n")
    indent = lines[-1] if lines[-1].strip() == "" else ""
    body = lines[:-1] if indent or lines[-1] == "" else lines
    return "\n".join(l[len(indent):] if l.startswith(indent) else l for l in body)


LITERAL_REF = r"\x00(\d+)\x00"
OPENING = re.compile(r'(#*)("""|")')


# --- What the app translates, and what the tables hold -------------------------


@dataclass
class Use:
    path: str
    line: int


@dataclass
class Table:
    language: str
    path: str
    entries: dict[str, tuple[str, int]] = field(default_factory=dict)
    duplicates: list[tuple[str, int]] = field(default_factory=list)


@dataclass
class Snapshot:
    uses: dict[str, list[Use]] = field(default_factory=dict)
    dynamic: list[tuple[str, Use]] = field(default_factory=list)
    tables: list[Table] = field(default_factory=list)


def read_files(rev: str | None) -> dict[str, str]:
    """The Swift sources by path: on disk, or as they were at `rev`."""
    if rev is None:
        files = {}
        for d in SOURCE_DIRS:
            for p in sorted((ROOT / d).rglob("*.swift")):
                files[p.relative_to(ROOT).as_posix()] = p.read_text(encoding="utf-8")
        return files
    names = subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", rev, "--", *SOURCE_DIRS],
        cwd=ROOT, check=True, capture_output=True, text=True,
    ).stdout.split()
    files = {}
    for name in names:
        if name.endswith(".swift"):
            files[name] = subprocess.run(
                ["git", "show", f"{rev}:{name}"],
                cwd=ROOT, check=True, capture_output=True, text=True,
            ).stdout
    return files


def is_table(path: str) -> bool:
    return Path(path).match(TABLE_GLOB)


def snapshot(rev: str | None) -> Snapshot:
    snap = Snapshot()
    for path, text in read_files(rev).items():
        code, literals = lex(text)
        if is_table(path):
            snap.tables.append(read_table(path, code, literals))
            continue

        def use(index: str) -> None:
            lit = literals[int(index)]
            where = Use(path, lit.line)
            if lit.interpolated:
                snap.dynamic.append((lit.value, where))
            else:
                snap.uses.setdefault(lit.value, []).append(where)

        for m in re.finditer(r"(?<![\w.])L\(\s*" + LITERAL_REF + r"(?!\s*\+)", code):
            use(m.group(1))
        for pattern in EXTRA_KEY_SOURCES:
            for m in re.finditer(pattern + LITERAL_REF, code):
                use(m.group(1))
        for pattern in EXTRA_KEY_SETS:
            for m in re.finditer(pattern, code):
                body = code[m.end() : code.index("]", m.end())]
                for ref in re.finditer(LITERAL_REF, body):
                    use(ref.group(1))
    snap.tables.sort(key=lambda t: t.language)
    return snap


def read_table(path: str, code: str, literals: list[Literal]) -> Table:
    m = re.search(r"\blet\s+(\w+?)Strings\s*:\s*\[String\s*:\s*String\]\s*=\s*\[", code)
    if not m:
        sys.exit(f"error: {path} has no `let …Strings: [String: String] = [` table")
    table = Table(m.group(1).capitalize(), path)
    for pair in re.finditer(LITERAL_REF + r"\s*:\s*" + LITERAL_REF, code[m.end() :]):
        key, value = literals[int(pair.group(1))], literals[int(pair.group(2))]
        if key.value in table.entries:
            table.duplicates.append((key.value, key.line))
        table.entries[key.value] = (value.value, key.line)
    return table


def placeholders(text: str) -> list[str]:
    """The format arguments `text` reads, by position: ['@', 'lld']."""
    found: dict[int, str] = {}
    next_index = 1
    for m in FORMAT_SPEC.finditer(text):
        if m.group(3) == "%":
            continue
        if m.group(1):
            index = int(m.group(1))
        else:
            index, next_index = next_index, next_index + 1
        found[index] = (m.group(2) or "") + m.group(3)
    return [found.get(i, "?") for i in range(1, max(found, default=0) + 1)]


# --- Report --------------------------------------------------------------------


@dataclass
class Problem:
    kind: str
    message: str
    path: str
    line: int


def missing(snap: Snapshot, table: Table) -> list[str]:
    return sorted(k for k in snap.uses if k not in table.entries and k not in SAME_IN_EVERY_LANGUAGE)


def short(text: str, limit: int = 90) -> str:
    text = text.replace("\n", "\\n")
    return text if len(text) <= limit else text[: limit - 1] + "…"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--base", help="fail only on strings missing now that weren't at this revision")
    parser.add_argument("--strict", action="store_true", help="fail on any missing string")
    parser.add_argument("--list", action="store_true", help="print every missing string")
    args = parser.parse_args()

    head = snapshot(None)
    base = snapshot(args.base) if args.base else None
    errors: list[Problem] = []
    notes: list[Problem] = []

    for text, where in head.dynamic:
        errors.append(Problem("dynamic", f'L("{short(text)}") builds its key from a value, so no translation can match it; '
                              "pass a fixed string and the values as L(\"… %@ …\", value)", where.path, where.line))

    for table in head.tables:
        for key, line in table.duplicates:
            errors.append(Problem("duplicate", f'"{short(key)}" is in the {table.language} table twice; '
                                  "Swift stops the app on a duplicate dictionary key", table.path, line))
        for key, (value, line) in table.entries.items():
            want, got = placeholders(key), placeholders(value)
            if want != got:
                errors.append(Problem("placeholder", f'{table.language} "{short(value, 60)}" reads {got or "no values"}, '
                                      f'its key "{short(key, 60)}" {want or "none"}', table.path, line))

    base_missing = {t.language: set(missing(base, t)) for t in base.tables} if base else {}
    rows = []
    for table in head.tables:
        gaps = missing(head, table)
        stale = sorted(k for k in table.entries if k not in head.uses and k not in SAME_IN_EVERY_LANGUAGE)
        new = [k for k in gaps if k not in base_missing.get(table.language, set())] if base else []
        rows.append((table, gaps, new, stale))
        failing = gaps if args.strict else new
        for key in failing:
            where = head.uses[key][0]
            errors.append(Problem("missing", f'"{short(key)}" has no {table.language} translation ({table.path})',
                                  where.path, where.line))
        for key in stale:
            notes.append(Problem("stale", f'{table.language}: "{short(key)}" is no longer used', table.path,
                                 table.entries[key][1]))

    total = len([k for k in head.uses if k not in SAME_IN_EVERY_LANGUAGE])
    print(f"{total} strings translated through L(…), {len(head.tables)} languages")
    for table, gaps, new, stale in rows:
        done = total - len(gaps)
        extra = f", {len(new)} new since {args.base}" if base else ""
        print(f"  {table.language:<11} {done:>5}/{total}  {100 * done / max(total, 1):5.1f}%  "
              f"{len(gaps)} missing{extra}, {len(stale)} stale")
        if args.list:
            for key in gaps:
                print(f"      missing: {short(key, 110)}")
    if errors:
        print(f"\n{len(errors)} problem(s):")
        for p in errors:
            print(f"  {p.path}:{p.line}: {p.kind}: {p.message}")
    else:
        print("\nNo duplicate keys, placeholder mismatches or built-up keys"
              + (f"; nothing newly untranslated since {args.base}." if base else "."))

    if os.environ.get("GITHUB_ACTIONS") == "true":
        annotate(errors, notes)
        summarize(rows, total, errors, args.base)
    return 1 if errors else 0


def annotate(errors: list[Problem], notes: list[Problem]) -> None:
    def esc(s: str) -> str:
        return s.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")

    for p in errors:
        print(f"::error file={p.path},line={p.line},title=Translations: {p.kind}::{esc(p.message)}")
    # Stale entries are noise at line level; GitHub shows only the first ten anyway.
    if notes:
        print(f"::notice title=Translations::{len(notes)} table entries are no longer used (see the run summary)")


def summarize(rows, total: int, errors: list[Problem], base: str | None) -> None:
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    md = ["## Translations", "", f"{total} strings go through `L(…)`.", "",
          "| Language | Translated | Missing | " + ("New since base | " if base else "") + "Stale |",
          "|---|---:|---:|" + ("---:|" if base else "") + "---:|"]
    for table, gaps, new, stale in rows:
        done = total - len(gaps)
        cells = [table.language, f"{done}/{total} ({100 * done / max(total, 1):.1f}%)", str(len(gaps))]
        if base:
            cells.append(f"**{len(new)}**" if new else "0")
        cells.append(str(len(stale)))
        md.append("| " + " | ".join(cells) + " |")
    if errors:
        md += ["", f"### {len(errors)} problem(s)", ""]
        md += [f"- `{p.path}:{p.line}` {p.kind}: {p.message}" for p in errors]
    for table, gaps, _, _ in rows:
        if gaps:
            md += ["", f"<details><summary>{table.language}: {len(gaps)} missing</summary>", ""]
            md += ["- " + short(k, 200).replace("|", "\\|") for k in gaps]
            md += ["", "</details>"]
    with open(path, "a", encoding="utf-8") as f:
        f.write("\n".join(md) + "\n")


if __name__ == "__main__":
    sys.exit(main())
