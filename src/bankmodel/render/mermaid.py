"""Mermaid diagram helpers shared by all layer renderers."""

from __future__ import annotations

from bankmodel.meta import Rel

# Mermaid crow's-foot symbols: left side belongs to the parent, right side to the child.
_PARENT_SIDE = {"1": "||", "0..1": "|o"}
_CHILD_SIDE = {"1": "||", "0..1": "o|", "0..N": "o{", "1..N": "|{"}


def er_relationship(child: str, rel: Rel) -> str:
    left = _PARENT_SIDE[rel.parent_card]
    right = _CHILD_SIDE[rel.child_card]
    line = ".." if rel.optional else "--"
    return f'    {rel.parent} {left}{line}{right} {child} : "{_quote(rel.label)}"'


def er_entity(name: str, attributes: list[tuple[str, str, str]]) -> list[str]:
    """Entity block; attributes are (type, name, key markers such as "PK", "FK" or "PK, FK")."""
    lines = [f"    {name} {{"]
    for type_, attr, keys in attributes:
        lines.append(f"        {type_} {attr}" + (f" {keys}" if keys else ""))
    lines.append("    }")
    return lines


def fenced(body: list[str]) -> str:
    return "\n".join(["```mermaid", *body, "```"])


def _quote(text: str) -> str:
    return text.replace('"', "'")
