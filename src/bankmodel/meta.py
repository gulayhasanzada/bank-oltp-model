"""Metamodel: the building blocks every domain module uses to describe the bank model.

One declaration drives all three layers:
- Domain / Entity / Rel  -> conceptual model (subject areas, entities, relationships)
- Attribute, Unique, Check (+ Rel FKs) -> logical model (attributes, keys, cardinality, business rules)
- types.py mapping, Index, partition_by -> physical model and DDL
"""

from __future__ import annotations

from dataclasses import dataclass, field

# Cardinality vocabulary, written as UML-style multiplicities.
PARENT_CARDS = ("1", "0..1")
CHILD_CARDS = ("1", "0..1", "0..N", "1..N")


@dataclass(frozen=True)
class Rel:
    """Relationship declared on the child entity, pointing at its parent.

    The label reads parent -> child, e.g. party "ünvanıdır" party_address.
    In the logical layer each Rel becomes a foreign key column on the child.
    """

    parent: str
    label: str
    parent_card: str = "1"
    child_card: str = "0..N"
    fk: str | None = None

    @property
    def fk_column(self) -> str:
        return self.fk or f"{self.parent}_id"

    @property
    def date_column(self) -> str:
        """Companion column carrying the parent's partition date (FKs to partitioned tables are composite)."""
        return self.fk_column.removesuffix("_id") + "_date"

    @property
    def optional(self) -> bool:
        return self.parent_card == "0..1"

    @property
    def unique(self) -> bool:
        return self.child_card in ("1", "0..1")


@dataclass(frozen=True)
class Attribute:
    name: str
    ltype: str
    desc: str
    optional: bool = False
    unique: bool = False
    default: str | None = None
    values: tuple[str, ...] = ()


@dataclass(frozen=True)
class Unique:
    columns: tuple[str, ...]
    nulls_not_distinct: bool = False


@dataclass(frozen=True)
class Check:
    """Business rule. `name` becomes ck_<table>_<name>; `expr` is the PostgreSQL expression."""

    name: str
    expr: str
    desc: str


@dataclass(frozen=True)
class Index:
    columns: tuple[str, ...]
    where: str | None = None


@dataclass(frozen=True)
class Entity:
    name: str
    title: str
    desc: str
    rels: tuple[Rel, ...] = ()
    attributes: tuple[Attribute, ...] = ()
    uniques: tuple[Unique, ...] = ()
    checks: tuple[Check, ...] = ()
    indexes: tuple[Index, ...] = ()
    partition_by: str | None = None


@dataclass(frozen=True)
class Domain:
    schema: str
    title: str
    desc: str
    entities: tuple[Entity, ...] = field(default_factory=tuple)


@dataclass(frozen=True)
class Term:
    term: str
    definition: str


def entity_index(domains: tuple[Domain, ...]) -> dict[str, tuple[Domain, Entity]]:
    """Map entity name -> (owning domain, entity). Entity names are unique across the model."""
    return {e.name: (d, e) for d in domains for e in d.entities}


def status_history(name: str, title: str, desc: str, parent: str, statuses: tuple[str, ...]) -> Entity:
    """Append-only status history entity; one shape shared by party, account, payment, card and loan."""
    return Entity(
        name,
        title,
        desc,
        rels=(Rel(parent, "status tarixçəsidir"),),
        attributes=(
            Attribute("from_status", "code", "Əvvəlki status (ilk yazılışda boş).", optional=True, values=statuses),
            Attribute("to_status", "code", "Yeni status.", values=statuses),
            Attribute("changed_at", "timestamp", "Statusun dəyişdiyi an.", default="now()"),
            Attribute("reason_code", "code", "Dəyişikliyin səbəb kodu.", optional=True),
            Attribute("comment", "long_text", "Əlavə izah.", optional=True),
        ),
        checks=(Check("status_changed", "from_status IS DISTINCT FROM to_status", "Yeni status əvvəlkindən fərqli olmalıdır."),),
    )


def exactly_one(*columns: str) -> str:
    return f"num_nonnulls({', '.join(columns)}) = 1"
