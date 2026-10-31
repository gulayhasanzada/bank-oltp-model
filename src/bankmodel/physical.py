"""Physical design decisions shared by the physical docs and the DDL: naming, indexes, partitions."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass

from bankmodel.meta import Entity
from bankmodel.resolve import columns, foreign_keys, primary_key, unique_keys
from bankmodel.types import LOGICAL_TYPES

MAX_IDENT = 63
# Monthly partitions created up front; later months land in the DEFAULT partition until created.
PARTITION_FIRST = (2026, 1)
PARTITION_LAST = (2027, 12)


def pg_type(ltype: str) -> str:
    return LOGICAL_TYPES[ltype].pg


def ident(*parts: str) -> str:
    """Join name parts; names over PostgreSQL's 63-byte limit are shortened with a stable hash suffix."""
    name = "_".join(parts)
    if len(name) <= MAX_IDENT:
        return name
    digest = hashlib.md5(name.encode("utf-8")).hexdigest()[:8]
    return f"{name[: MAX_IDENT - 9]}_{digest}"


@dataclass(frozen=True)
class Constraint:
    name: str
    kind: str  # PRIMARY KEY | UNIQUE | CHECK
    definition: str  # SQL after "CONSTRAINT <name>"
    desc: str


@dataclass(frozen=True)
class PhysicalForeignKey:
    name: str
    columns: tuple[str, ...]
    parent_table: str  # schema-qualified
    parent_columns: tuple[str, ...]


def table_constraints(e: Entity, index) -> list[Constraint]:
    pk = primary_key(e)
    out = [Constraint(ident("pk", e.name), "PRIMARY KEY", f"PRIMARY KEY ({', '.join(pk)})", "Əsas açar")]
    for k in unique_keys(e, index):
        nnd = " NULLS NOT DISTINCT" if k.nulls_not_distinct else ""
        out.append(
            Constraint(ident("uq", e.name, *k.columns), "UNIQUE", f"UNIQUE{nnd} ({', '.join(k.columns)})", "Alternativ açar")
        )
    for c in columns(e, index):
        if c.values:
            allowed = ", ".join(f"'{v}'" for v in c.values)
            out.append(Constraint(ident("ck", e.name, c.name), "CHECK", f"CHECK ({c.name} IN ({allowed}))", "İcazəli dəyərlər"))
    for chk in e.checks:
        out.append(Constraint(ident("ck", e.name, chk.name), "CHECK", f"CHECK ({chk.expr})", chk.desc))
    return out


def physical_foreign_keys(e: Entity, index) -> list[PhysicalForeignKey]:
    out = []
    for fk in foreign_keys(e, index):
        schema = index[fk.parent][0].schema
        out.append(PhysicalForeignKey(ident("fk", e.name, fk.columns[0]), fk.columns, f"{schema}.{fk.parent}", fk.parent_columns))
    return out


@dataclass(frozen=True)
class PhysicalIndex:
    name: str
    columns: tuple[str, ...]
    where: str | None
    reason: str


def indexes(e: Entity, index) -> list[PhysicalIndex]:
    """Declared indexes plus one per foreign key not already covered by the leading columns of a key or index."""
    covered = [primary_key(e)] + [k.columns for k in unique_keys(e, index)]
    covered += [ix.columns for ix in e.indexes if ix.where is None]
    result = []
    for fk in foreign_keys(e, index):
        if any(c[: len(fk.columns)] == fk.columns for c in covered):
            continue
        covered.append(fk.columns)
        result.append(PhysicalIndex(ident("ix", e.name, *fk.columns), fk.columns, None, "FK"))
    for ix in e.indexes:
        suffix = ("partial",) if ix.where else ()
        result.append(PhysicalIndex(ident("ix", e.name, *ix.columns, *suffix), ix.columns, ix.where, "Sorğu"))
    return result


def months() -> list[tuple[int, int]]:
    year, month = PARTITION_FIRST
    out = []
    while (year, month) <= PARTITION_LAST:
        out.append((year, month))
        year, month = (year + 1, 1) if month == 12 else (year, month + 1)
    return out


def partitions(e: Entity) -> list[tuple[str, str, str]]:
    """(partition name, from date, to date) for each pre-created month."""
    out = []
    for year, month in months():
        nxt = (year + 1, 1) if month == 12 else (year, month + 1)
        out.append((f"{e.name}_p{year}_{month:02d}", f"{year}-{month:02d}-01", f"{nxt[0]}-{nxt[1]:02d}-01"))
    return out
