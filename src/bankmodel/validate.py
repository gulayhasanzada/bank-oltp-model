"""Model integrity rules. Generation refuses to run while any rule is violated."""

from __future__ import annotations

import re

from bankmodel.meta import CHILD_CARDS, PARENT_CARDS, Domain, entity_index
from bankmodel.resolve import columns, unique_keys
from bankmodel.types import LOGICAL_TYPES

IDENT = re.compile(r"^[a-z][a-z0-9_]*$")
# PostgreSQL truncates identifiers longer than 63 bytes.
MAX_IDENT = 63
CODE_LENGTH = 30


def validate(domains: tuple[Domain, ...]) -> list[str]:
    errors: list[str] = []
    schemas: set[str] = set()
    owners: dict[str, str] = {}

    for d in domains:
        if d.schema in schemas:
            errors.append(f"duplicate schema '{d.schema}'")
        schemas.add(d.schema)
        _check_ident(errors, d.schema, f"schema '{d.schema}'")
        if not d.title or not d.desc:
            errors.append(f"schema '{d.schema}': missing title or description")
        if not d.entities:
            errors.append(f"schema '{d.schema}': has no entities")
        for e in d.entities:
            if e.name in owners:
                errors.append(f"entity '{e.name}' declared in both '{owners[e.name]}' and '{d.schema}'")
            owners[e.name] = d.schema
            _check_ident(errors, e.name, f"entity '{e.name}'")
            if not e.title or not e.desc:
                errors.append(f"entity '{e.name}': missing title or description")

    for d in domains:
        for e in d.entities:
            where = f"{d.schema}.{e.name}"
            for r in e.rels:
                if r.parent not in owners:
                    errors.append(f"{where}: relationship to unknown entity '{r.parent}'")
                if r.parent_card not in PARENT_CARDS:
                    errors.append(f"{where}: invalid parent cardinality '{r.parent_card}' (-> {r.parent})")
                if r.child_card not in CHILD_CARDS:
                    errors.append(f"{where}: invalid child cardinality '{r.child_card}' (-> {r.parent})")
                if not r.label:
                    errors.append(f"{where}: relationship to '{r.parent}' has no label")
            for a in e.attributes:
                if a.ltype not in LOGICAL_TYPES:
                    errors.append(f"{where}.{a.name}: unknown logical type '{a.ltype}'")
                if not a.desc:
                    errors.append(f"{where}.{a.name}: missing description")
                if a.values:
                    if a.ltype != "code":
                        errors.append(f"{where}.{a.name}: allowed values require logical type 'code'")
                    if len(set(a.values)) != len(a.values):
                        errors.append(f"{where}.{a.name}: duplicate allowed values")
                    if any(len(v) > CODE_LENGTH for v in a.values):
                        errors.append(f"{where}.{a.name}: allowed value longer than {CODE_LENGTH}")
                    if a.default and a.default.strip("'") not in a.values:
                        errors.append(f"{where}.{a.name}: default {a.default} is not an allowed value")
                if a.optional and a.default is not None:
                    errors.append(f"{where}.{a.name}: optional attribute with a default; make it mandatory")

    if errors:
        # Column resolution needs every relationship target to exist.
        return errors

    index = entity_index(domains)
    for d in domains:
        for e in d.entities:
            where = f"{d.schema}.{e.name}"
            cols = columns(e, index)
            names = [c.name for c in cols]
            for name in sorted({n for n in names if names.count(n) > 1}):
                errors.append(f"{where}: column '{name}' defined more than once; give the relationship a role name with fk=")
            for c in cols:
                _check_ident(errors, c.name, f"{where}.{c.name}")
            known = set(names)
            if e.partition_by:
                part = next((c for c in cols if c.name == e.partition_by), None)
                if part is None or part.role != "attr":
                    errors.append(f"{where}: partition column '{e.partition_by}' must be a declared attribute")
                elif part.ltype != "date" or part.optional:
                    errors.append(f"{where}: partition column '{e.partition_by}' must be a mandatory date")
            for k in unique_keys(e, index):
                missing = [c for c in k.columns if c not in known]
                if missing:
                    errors.append(f"{where}: unique key uses unknown columns {missing}")
                if e.partition_by and e.partition_by not in k.columns:
                    errors.append(f"{where}: unique key {k.columns} must include partition column '{e.partition_by}'")
            for ix in e.indexes:
                missing = [c for c in ix.columns if c not in known]
                if missing:
                    errors.append(f"{where}: index uses unknown columns {missing}")
            check_names = [c.name for c in e.checks]
            if len(set(check_names)) != len(check_names):
                errors.append(f"{where}: duplicate check names")
            for c in e.checks:
                _check_ident(errors, c.name, f"{where} check '{c.name}'")
                if not c.desc:
                    errors.append(f"{where}: check '{c.name}' has no description")
    return errors


def _check_ident(errors: list[str], name: str, what: str) -> None:
    if not IDENT.match(name):
        errors.append(f"{what}: not a lowercase snake_case identifier")
    if len(name) > MAX_IDENT:
        errors.append(f"{what}: longer than {MAX_IDENT} characters")
