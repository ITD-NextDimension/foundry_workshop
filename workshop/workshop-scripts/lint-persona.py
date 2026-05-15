"""Persona linter — validate frontmatter, includes, and basic structure.

Usage:
    python workshop-scripts/lint-persona.py <persona-file.md> [...more]
Exits non-zero if any persona fails.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

_FM_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
_INCLUDE_RE = re.compile(r"\{\{include:\s*([^\}]+?)\s*\}\}")

REQUIRED_FRONTMATTER = ("agent", "version", "owner")
REQUIRED_SECTIONS = ("# Role",)


def _parse_frontmatter(text: str) -> dict[str, str] | None:
    m = _FM_RE.match(text)
    if not m:
        return None
    body = m.group(1)
    out: dict[str, str] = {}
    current_key: str | None = None
    for line in body.splitlines():
        if not line.strip():
            continue
        if line.startswith(("- ", "  ")):
            if current_key:
                out[current_key] = out.get(current_key, "") + line.strip() + ";"
            continue
        if ":" in line:
            key, _, val = line.partition(":")
            out[key.strip()] = val.strip()
            current_key = key.strip()
    return out


def lint(path: Path) -> tuple[bool, list[str]]:
    errors: list[str] = []
    if not path.exists():
        return False, [f"file not found: {path}"]

    text = path.read_text(encoding="utf-8")

    # Skip shared snippets (they have shared:true frontmatter)
    fm = _parse_frontmatter(text)
    if fm is None:
        errors.append("missing or malformed YAML frontmatter (--- ... ---)")
        return False, errors

    if fm.get("shared", "").lower() == "true":
        # shared snippet — different rules
        if not fm.get("version"):
            errors.append("shared snippet missing 'version' field")
        return (not errors), errors

    # Template files (*.template.md) are not deployed as-is; they get copied
    # into personas/ and edited. Skip include resolution.
    is_template = path.name.endswith(".template.md")

    # Normal agent persona checks
    for key in REQUIRED_FRONTMATTER:
        if not fm.get(key):
            errors.append(f"missing frontmatter field: {key}")

    for sec in REQUIRED_SECTIONS:
        if sec not in text:
            errors.append(f"missing section heading: {sec}")

    if is_template:
        # Skip include resolution for templates.
        return (not errors), errors

    # Include references must resolve
    personas_root = path.parent
    # If the file is under personas/, climb to personas dir; otherwise relative to file dir
    if personas_root.name != "personas":
        # try walking up to find a personas dir
        for p in [path.parent, *path.parents]:
            if (p / "shared").is_dir() or p.name == "personas":
                personas_root = p
                break

    for include in _INCLUDE_RE.findall(text):
        target = (personas_root / include).resolve()
        if not target.exists():
            errors.append(f"unresolved include: {{{{include: {include}}}}} -> {target}")

    return (not errors), errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args(argv)

    failed = 0
    for s in args.paths:
        p = Path(s)
        ok, errs = lint(p)
        if ok:
            fm = _parse_frontmatter(p.read_text(encoding="utf-8")) or {}
            extends = fm.get("extends", "")
            version = fm.get("version", "?")
            tag = "template" if p.name.endswith(".template.md") else ""
            tag_str = f" [{tag}]" if tag else ""
            print(f"✅ persona {p.name}{tag_str} OK · extends=[{extends}] · version={version}")
        else:
            failed += 1
            print(f"❌ persona {p}:")
            for e in errs:
                print(f"   - {e}")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
