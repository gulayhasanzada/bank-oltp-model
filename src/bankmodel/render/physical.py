"""Physical model docs: PostgreSQL 18 tables, columns, constraints, indexes and partitions."""

from __future__ import annotations

import re

from bankmodel import physical as phys
from bankmodel.meta import Domain, Entity, Term, entity_index
from bankmodel.render.common import GENERATED, REF_SCHEMA, cell, code_list, file_name, layer_nav
from bankmodel.render.ddl import OUT_FILE as DDL_FILE
from bankmodel.render.mermaid import er_entity, er_relationship, fenced
from bankmodel.resolve import columns, primary_key, unique_keys
from bankmodel.types import LOGICAL_TYPES

LAYER = "03_fiziki"
OUT_DIR = f"docs/{LAYER}"


def render(domains: tuple[Domain, ...], glossary: tuple[Term, ...]) -> dict[str, str]:
    index = entity_index(domains)
    files = {f"{OUT_DIR}/index.md": _index_page(domains, index)}
    for n, d in enumerate(domains, start=1):
        files[f"{OUT_DIR}/{file_name(n, d)}"] = _domain_page(n, d, index)
    return files


def _mermaid_type(pg: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", pg).strip("_")


def _stats(domains, index) -> dict[str, int]:
    entities = [e for d in domains for e in d.entities]
    return {
        "tables": len(entities),
        "columns": sum(len(columns(e, index)) for e in entities),
        "fks": sum(len(phys.physical_foreign_keys(e, index)) for e in entities),
        "uniques": sum(len(unique_keys(e, index)) for e in entities),
        "checks": sum(1 for e in entities for k in phys.table_constraints(e, index) if k.kind == "CHECK"),
        "indexes": sum(len(phys.indexes(e, index)) for e in entities),
        "partitioned": sum(1 for e in entities if e.partition_by),
    }


def _index_page(domains, index) -> str:
    s = _stats(domains, index)
    first, last = phys.months()[0], phys.months()[-1]
    partitioned = [(d, e) for d in domains for e in d.entities if e.partition_by]
    out = [
        GENERATED,
        "",
        "# Fiziki model — PostgreSQL 18",
        "",
        layer_nav(LAYER),
        "",
        "Fiziki model məntiqi modelin PostgreSQL 18 üzərində reallaşdırılmasıdır. Tam DDL skripti: "
        f"[`{DDL_FILE}`](../../{DDL_FILE}).",
        "",
        f"**Statistika:** {len(domains)} sxem, {s['tables']} cədvəl ({s['partitioned']} bölmələnmiş), {s['columns']} sütun, "
        f"{s['fks']} xarici açar, {s['uniques']} unikal məhdudiyyət, {s['checks']} CHECK məhdudiyyəti, {s['indexes']} indeks.",
        "",
        "## Sxemlər",
        "",
        "Hər domen ayrıca PostgreSQL sxemidir.",
        "",
        "| # | Sxem | Domen | Cədvəl sayı |",
        "|---|---|---|---|",
    ]
    for n, d in enumerate(domains, start=1):
        out.append(f"| {n} | `{d.schema}` | [{d.title}]({file_name(n, d)}) | {len(d.entities)} |")
    out += [
        "",
        "## Adlandırma qaydaları",
        "",
        "| Obyekt | Qayda | Nümunə |",
        "|---|---|---|",
        "| Cədvəl, sütun | ingiliscə `snake_case`, tək halda | `account_transaction` |",
        "| Əsas açar sütunu | `<cədvəl>_id` | `account_id` |",
        "| Xarici açar sütunu | `<istinad cədvəli>_id` və ya `<rol>_id` | `debit_account_id` |",
        "| Əsas açar | `pk_<cədvəl>` | `pk_account` |",
        "| Unikal məhdudiyyət | `uq_<cədvəl>_<sütunlar>` | `uq_account_iban` |",
        "| CHECK | `ck_<cədvəl>_<sütun və ya qayda>` | `ck_account_status` |",
        "| Xarici açar | `fk_<cədvəl>_<sütun>` | `fk_account_customer_id` |",
        "| İndeks | `ix_<cədvəl>_<sütunlar>` | `ix_account_customer_id` |",
        "| Bölmə | `<cədvəl>_p<il>_<ay>`, `<cədvəl>_default` | `account_transaction_p2026_10` |",
        "",
        f"63 simvoldan uzun adlar sabit hash şəkilçisi ilə qısaldılır.",
        "",
        "## Tiplərin uyğunluğu",
        "",
        "| Məntiqi tip | PostgreSQL tipi |",
        "|---|---|",
    ]
    out += [f"| {t.title} (`{t.code}`) | `{t.pg}` |" for t in LOGICAL_TYPES.values()]
    out += [
        "",
        "## Fiziki qərarlar",
        "",
        "- **Əsas açarlar** `uuid DEFAULT uuidv7()` — PostgreSQL 18-in daxili funksiyası; zamana görə sıralanan UUID-lər "
        "B-tree indekslərində ardıcıl yazılır və təsadüfi UUIDv4-dən fərqli olaraq indeksi parçalamır.",
        "- **Məbləğlər** `numeric(19,4)` — üzən nöqtəli tiplər istifadə olunmur. Faiz dərəcələri `numeric(9,6)`, məzənnələr `numeric(18,8)`.",
        "- **Vaxt** `timestamptz` (UTC saxlanılır); bank günü və dəyər tarixi `date`.",
        "- **Kod siyahıları:** kiçik siyahılar `CHECK (sütun IN (...))`, biznes siyahıları `ref` sxemindəki cədvəllərə FK.",
        "- **Xarici açarlar** `ON DELETE NO ACTION` — kaskad silmə yoxdur; bank məlumatları silinmir, statusla bağlanır.",
        "- **FK indeksləri:** açar və ya digər indeksin başlanğıcı ilə örtülməyən hər FK üçün avtomatik indeks yaradılır.",
        "- **Audit sütunları:** `created_at DEFAULT now()`, `created_by DEFAULT current_user`; `updated_at` / `updated_by` tətbiq tərəfindən doldurulur.",
        "- **Şərhlər:** hər sxem, cədvəl və sütun üçün `COMMENT ON` (Azərbaycan dilində).",
        "",
        "## Bölmələmə (partitioning)",
        "",
        f"Yüksək həcmli cədvəllər tarix sütunu üzrə aylıq `RANGE` bölmələrinə ayrılır. DDL {first[0]}-{first[1]:02d} – "
        f"{last[0]}-{last[1]:02d} ayları üçün bölmələr və bir `DEFAULT` bölmə yaradır; sonrakı aylar üçün bölmələr "
        "ay başlamazdan əvvəl planlaşdırılmış iş (məs. pg_partman) ilə yaradılmalıdır.",
        "",
        "PostgreSQL bölmələnmiş cədvəldə əsas və unikal açarların bölmə sütununu ehtiva etməsini tələb edir. Buna görə:",
        "",
        "- bölmələnmiş cədvəlin əsas açarı `(<cədvəl>_id, <bölmə tarixi>)` cütüdür;",
        "- ona istinad edən cədvəllərdə FK kompozitdir: `<rol>_id` + `<rol>_date` (məs. `account_transaction_id`, `account_transaction_date`);",
        "- bölmələnmiş cədvəlin unikal açarlarına bölmə sütunu əlavə olunur.",
        "",
        "| Cədvəl | Bölmə sütunu |",
        "|---|---|",
    ]
    out += [f"| `{d.schema}.{e.name}` | `{e.partition_by}` |" for d, e in partitioned]
    out += [
        "",
        "## Quraşdırma",
        "",
        "```powershell",
        "Copy-Item .env.example .env    # şifrəni dəyişin",
        "docker compose up -d           # PostgreSQL 18 konteyneri",
        "uv run bankmodel apply         # DDL-i icra edir (sxemləri silib yenidən yaradır)",
        "```",
    ]
    return "\n".join(out) + "\n"


def _domain_page(n: int, d: Domain, index) -> str:
    internal = {e.name for e in d.entities}
    body = ["erDiagram"]
    edges = []
    for e in d.entities:
        pk = set(primary_key(e))
        fk_cols = {c for fk in phys.physical_foreign_keys(e, index) for c in fk.columns}
        uq_cols = {c for k in unique_keys(e, index) for c in k.columns}
        attrs = []
        for c in columns(e, index):
            if c.role == "audit":
                continue
            keys = [k for k, s in (("PK", pk), ("FK", fk_cols), ("UK", uq_cols)) if c.name in s]
            attrs.append((_mermaid_type(phys.pg_type(c.ltype)), c.name, ", ".join(keys)))
        body += er_entity(e.name, attrs)
        for r in e.rels:
            if d.schema == REF_SCHEMA or index[r.parent][0].schema != REF_SCHEMA:
                edges.append(er_relationship(e.name, r))
    externals = sorted(
        {r.parent for e in d.entities for r in e.rels if r.parent not in internal and index[r.parent][0].schema != REF_SCHEMA}
    )
    body += [f"    {x}" for x in externals]
    body += edges

    out = [
        GENERATED,
        "",
        f"# {d.title} (`{d.schema}`) — fiziki model",
        "",
        f"[← Fiziki model](index.md) | {layer_nav(LAYER, n, d)}",
        "",
        d.desc,
        "",
        "## Diaqram",
        "",
        "Audit sütunları diaqramda göstərilmir.",
        "",
        fenced(body),
        "",
        "## Cədvəllər",
    ]
    for e in d.entities:
        out += ["", *_table_section(d, e, index)]
    return "\n".join(out) + "\n"


def _table_section(d: Domain, e: Entity, index) -> list[str]:
    out = [f"### `{d.schema}.{e.name}` — {e.title}", "", e.desc, ""]
    if e.partition_by:
        out += [
            f"**Bölmələmə:** `PARTITION BY RANGE ({e.partition_by})`, aylıq bölmələr + `{e.name}_default`.",
            "",
        ]
    out += ["| # | Sütun | Tip | NULL | Default | Şərh |", "|---|---|---|---|---|---|"]
    for j, c in enumerate(columns(e, index), start=1):
        desc = c.desc + (f"<br>Dəyərlər: {code_list(c.values)}" if c.values else "")
        default = f"`{c.default}`" if c.default is not None else ""
        out.append(
            f"| {j} | `{c.name}` | `{phys.pg_type(c.ltype)}` | {'NULL' if c.optional else 'NOT NULL'} | {default} | {cell(desc)} |"
        )
    out += ["", "**Məhdudiyyətlər:**", "", "| Ad | Növ | Tərif | Təsvir |", "|---|---|---|---|"]
    for k in phys.table_constraints(e, index):
        out.append(f"| `{k.name}` | {k.kind} | `{cell(k.definition)}` | {cell(k.desc)} |")
    for fk in phys.physical_foreign_keys(e, index):
        definition = f"FOREIGN KEY ({', '.join(fk.columns)}) REFERENCES {fk.parent_table} ({', '.join(fk.parent_columns)})"
        out.append(f"| `{fk.name}` | FOREIGN KEY | `{definition}` | İstinad bütövlüyü |")
    ixs = phys.indexes(e, index)
    if ixs:
        out += ["", "**İndekslər:**", "", "| Ad | Sütunlar | Şərt | Səbəb |", "|---|---|---|---|"]
        for ix in ixs:
            where = f"`{cell(ix.where)}`" if ix.where else ""
            out.append(f"| `{ix.name}` | {code_list(ix.columns)} | {where} | {ix.reason} |")
    return out
