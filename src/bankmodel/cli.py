"""Command line entry point: uv run bankmodel generate | check | apply."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from bankmodel.model import DOMAINS, GLOSSARY
from bankmodel.render import render_all
from bankmodel.validate import validate

DDL_FILE = "ddl/banking_oltp_pg18.sql"


def build() -> dict[str, str]:
    errors = validate(DOMAINS)
    if errors:
        raise SystemExit("Model validation failed:\n  " + "\n  ".join(errors))
    return render_all(DOMAINS, GLOSSARY)


def _managed_dirs(files: dict[str, str]) -> set[str]:
    return {path.rsplit("/", 1)[0] for path in files}


def _stale(root: Path, files: dict[str, str]) -> list[Path]:
    """Generated-type files on disk inside managed directories that the model no longer produces."""
    stale = []
    for rel_dir in sorted(_managed_dirs(files)):
        directory = root / rel_dir
        if directory.is_dir():
            for p in sorted(directory.iterdir()):
                rel = p.relative_to(root).as_posix()
                if p.is_file() and p.suffix in (".md", ".sql") and rel not in files:
                    stale.append(p)
    return stale


def generate(root: Path) -> int:
    files = build()
    for p in _stale(root, files):
        p.unlink()
        print(f"removed  {p.relative_to(root).as_posix()}")
    for rel, content in files.items():
        target = root / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and target.read_bytes() == content.encode("utf-8"):
            continue
        target.write_bytes(content.encode("utf-8"))
        print(f"written  {rel}")
    print(f"{len(files)} files up to date")
    return 0


def check(root: Path) -> int:
    files = build()
    problems = [f"stale    {p.relative_to(root).as_posix()}" for p in _stale(root, files)]
    for rel, content in files.items():
        target = root / rel
        if not target.exists():
            problems.append(f"missing  {rel}")
        elif target.read_bytes() != content.encode("utf-8"):
            problems.append(f"outdated {rel}")
    if problems:
        print("\n".join(problems))
        print("Run: uv run bankmodel generate")
        return 1
    print(f"Model valid; {len(files)} generated files match")
    return 0


def apply(root: Path) -> int:
    if not (root / DDL_FILE).exists():
        print(f"{DDL_FILE} not found; run: uv run bankmodel generate")
        return 1
    cmd = [
        "docker", "compose", "exec", "-T", "postgres",
        "sh", "-c", 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /' + DDL_FILE,
    ]
    return subprocess.run(cmd, cwd=root).returncode


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="bankmodel", description="Bank OLTP data model generator")
    parser.add_argument("command", choices=("generate", "check", "apply"))
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="project root (default: current directory)")
    args = parser.parse_args(argv)
    action = {"generate": generate, "check": check, "apply": apply}[args.command]
    return action(args.root.resolve())


if __name__ == "__main__":
    sys.exit(main())
