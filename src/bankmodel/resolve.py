"""Resolve an entity into its full column list and keys: shared by the logical, physical and DDL renderers.

Column order: primary key, foreign keys (with partition-date companions), declared attributes, audit columns.
"""

from __future__ import annotations

from dataclasses import dataclass

from bankmodel.meta import Entity, Rel

AUDIT = (
    ("created_at", "timestamp", "Yazılışın yaradıldığı an.", False, "now()"),
    ("created_by", "short_text", "Yazılışı yaradan istifadəçi.", False, "current_user"),
    ("updated_at", "timestamp", "Son dəyişiklik anı.", True, None),
    ("updated_by", "short_text", "Son dəyişikliyi edən istifadəçi.", True, None),
)


@dataclass(frozen=True)
class Column:
    name: str
    ltype: str
    desc: str
    optional: bool = False
    default: str | None = None
    values: tuple[str, ...] = ()
    role: str = "attr"  # pk | fk | fk_date | attr | audit
    rel: Rel | None = None


@dataclass(frozen=True)
class ForeignKey:
    columns: tuple[str, ...]
    parent: str
    parent_columns: tuple[str, ...]
    rel: Rel


@dataclass(frozen=True)
class UniqueKey:
    columns: tuple[str, ...]
    nulls_not_distinct: bool = False


def pk_column(e: Entity) -> str:
    return f"{e.name}_id"


def primary_key(e: Entity, physical: bool = True) -> tuple[str, ...]:
    """Physically a partitioned table's PK must contain the partition column; logically it is the surrogate alone."""
    return (pk_column(e), e.partition_by) if physical and e.partition_by else (pk_column(e),)


def columns(e: Entity, index, physical: bool = True) -> list[Column]:
    cols = [Column(pk_column(e), "id", f"{e.title} — surrogat identifikator (UUIDv7).", default="uuidv7()", role="pk")]
    for r in e.rels:
        parent = index[r.parent][1]
        cols.append(Column(r.fk_column, "id", f"{parent.title} istinadı ({r.label}).", r.optional, role="fk", rel=r))
        if physical and parent.partition_by:
            cols.append(
                Column(
                    r.date_column,
                    "date",
                    f"İstinad edilən `{r.parent}` yazılışının bölmə tarixi (kompozit FK hissəsi).",
                    r.optional,
                    role="fk_date",
                    rel=r,
                )
            )
    for a in e.attributes:
        cols.append(Column(a.name, a.ltype, a.desc, a.optional, a.default, a.values))
    for name, ltype, desc, optional, default in AUDIT:
        cols.append(Column(name, ltype, desc, optional, default, role="audit"))
    return cols


def foreign_keys(e: Entity, index) -> list[ForeignKey]:
    fks = []
    for r in e.rels:
        parent = index[r.parent][1]
        if parent.partition_by:
            fks.append(ForeignKey((r.fk_column, r.date_column), r.parent, primary_key(parent), r))
        else:
            fks.append(ForeignKey((r.fk_column,), r.parent, (pk_column(parent),), r))
    return fks


def unique_keys(e: Entity, index, physical: bool = True) -> list[UniqueKey]:
    """Alternate keys: unique attributes, 1:1 relationships and declared composite keys.

    PostgreSQL requires unique keys on a partitioned table to contain the partition column,
    so physically it is appended to derived keys of partitioned entities.
    """
    keys: list[tuple[str, ...]] = []
    for fk in foreign_keys(e, index):
        if fk.rel.unique:
            keys.append(fk.columns if physical else (fk.rel.fk_column,))
    keys += [(a.name,) for a in e.attributes if a.unique]
    if physical and e.partition_by:
        keys = [k if e.partition_by in k else (*k, e.partition_by) for k in keys]
    result = [UniqueKey(k) for k in keys]
    result += [UniqueKey(u.columns, u.nulls_not_distinct) for u in e.uniques]
    return result
