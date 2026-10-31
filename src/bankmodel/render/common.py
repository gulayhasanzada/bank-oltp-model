"""Shared pieces of the Markdown renderers."""

from __future__ import annotations

from bankmodel.meta import Domain

GENERATED = "<!-- Bu fayl avtomatik yaradılıb (uv run bankmodel generate). Əl ilə redaktə etməyin. -->"
REF_SCHEMA = "ref"
LAYERS = (
    ("01_konseptual", "Konseptual model"),
    ("02_mentiqi", "Məntiqi model"),
    ("03_fiziki", "Fiziki model"),
)


def file_name(n: int, d: Domain) -> str:
    return f"{n:02d}_{d.schema}.md"


def layer_nav(current: str, n: int | None = None, d: Domain | None = None) -> str:
    """Links to the same page in the other layers (or to their index pages)."""
    links = []
    for folder, title in LAYERS:
        target = file_name(n, d) if d is not None else "index.md"
        if folder == current:
            links.append(f"**{title}**")
        else:
            links.append(f"[{title}](../{folder}/{target})")
    return " · ".join(links)


def cell(text: str) -> str:
    return text.replace("|", "\\|").replace("\n", " ")


def code_list(values) -> str:
    return ", ".join(f"`{v}`" for v in values)
