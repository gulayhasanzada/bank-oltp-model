"""PostgreSQL 18 DDL: schemas, tables with inline keys and checks, partitions, foreign keys, indexes, comments."""

from __future__ import annotations

from bankmodel.meta import Domain, Term, entity_index
from bankmodel.physical import indexes, partitions, pg_type, physical_foreign_keys, table_constraints
from bankmodel.resolve import columns

OUT_FILE = "ddl/banking_oltp_pg18.sql"


def render(domains: tuple[Domain, ...], glossary: tuple[Term, ...]) -> dict[str, str]:
    index = entity_index(domains)
    out = [
        "-- Bank OLTP verilənlər modeli — PostgreSQL 18 DDL",
        "-- Bu fayl avtomatik yaradılıb (uv run bankmodel generate). Əl ilə redaktə etməyin.",
        "-- Diqqət: skript mövcud sxemləri silib yenidən yaradır (yalnız inkişaf/yoxlama bazası üçün).",
        "",
        "\\set ON_ERROR_STOP on",
        "BEGIN;",
        "",
        f"DROP SCHEMA IF EXISTS {', '.join(d.schema for d in reversed(domains))} CASCADE;",
        "",
        "-- ============================================================",
        "-- Sxemlər",
        "-- ============================================================",
    ]
    for d in domains:
        out.append(f"CREATE SCHEMA {d.schema};")
        out.append(f"COMMENT ON SCHEMA {d.schema} IS {_literal(f'{d.title}. {d.desc}')};")

    for d in domains:
        out += ["", "-- ============================================================", f"-- {d.schema}: {d.title}",
                "-- ============================================================"]
        for e in d.entities:
            out += ["", *_create_table(d, e, index)]

    out += ["", "-- ============================================================", "-- Xarici açarlar",
            "-- ============================================================"]
    for d in domains:
        for e in d.entities:
            for fk in physical_foreign_keys(e, index):
                out.append(
                    f"ALTER TABLE {d.schema}.{e.name} ADD CONSTRAINT {fk.name} "
                    f"FOREIGN KEY ({', '.join(fk.columns)}) REFERENCES {fk.parent_table} ({', '.join(fk.parent_columns)});"
                )

    out += ["", "-- ============================================================", "-- İndekslər",
            "-- ============================================================"]
    for d in domains:
        for e in d.entities:
            for ix in indexes(e, index):
                where = f" WHERE {ix.where}" if ix.where else ""
                out.append(f"CREATE INDEX {ix.name} ON {d.schema}.{e.name} ({', '.join(ix.columns)}){where};")

    out += ["", "-- ============================================================", "-- Şərhlər",
            "-- ============================================================"]
    for d in domains:
        for e in d.entities:
            out.append(f"COMMENT ON TABLE {d.schema}.{e.name} IS {_literal(f'{e.title}. {e.desc}')};")
            for c in columns(e, index):
                text = c.desc + (f" Dəyərlər: {', '.join(c.values)}." if c.values else "")
                out.append(f"COMMENT ON COLUMN {d.schema}.{e.name}.{c.name} IS {_literal(text)};")
    out += ["", "COMMIT;"]
    return {OUT_FILE: "\n".join(out) + "\n"}


def _create_table(d: Domain, e, index) -> list[str]:
    lines = []
    for c in columns(e, index):
        line = f"    {c.name} {pg_type(c.ltype)}"
        if not c.optional:
            line += " NOT NULL"
        if c.default is not None:
            line += f" DEFAULT {c.default}"
        lines.append(line)
    lines += [f"    CONSTRAINT {k.name} {k.definition}" for k in table_constraints(e, index)]
    tail = f") PARTITION BY RANGE ({e.partition_by});" if e.partition_by else ");"
    out = [f"CREATE TABLE {d.schema}.{e.name} (", ",\n".join(lines), tail]
    if e.partition_by:
        for name, start, end in partitions(e):
            out.append(f"CREATE TABLE {d.schema}.{name} PARTITION OF {d.schema}.{e.name} FOR VALUES FROM ('{start}') TO ('{end}');")
        out.append(f"CREATE TABLE {d.schema}.{e.name}_default PARTITION OF {d.schema}.{e.name} DEFAULT;")
    return out


def _literal(text: str) -> str:
    return "'" + text.replace("'", "''") + "'"
