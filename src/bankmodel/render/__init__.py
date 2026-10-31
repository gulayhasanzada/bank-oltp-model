"""Renderers turn the model into files: each returns {relative posix path: file content}."""

from __future__ import annotations

from bankmodel.meta import Domain, Term
from bankmodel.render import conceptual, ddl, logical, physical

RENDERERS = (conceptual, logical, physical, ddl)


def render_all(domains: tuple[Domain, ...], glossary: tuple[Term, ...]) -> dict[str, str]:
    files: dict[str, str] = {}
    for renderer in RENDERERS:
        files.update(renderer.render(domains, glossary))
    return files
