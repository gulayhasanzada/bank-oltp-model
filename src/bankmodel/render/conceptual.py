"""Conceptual model: subject areas, business entities and relationships. No attributes."""

from __future__ import annotations

from bankmodel.meta import Domain, Entity, Rel, Term, entity_index
from bankmodel.render.common import GENERATED, REF_SCHEMA, file_name, layer_nav
from bankmodel.render.mermaid import er_relationship, fenced

LAYER = "01_konseptual"
OUT_DIR = f"docs/{LAYER}"


def render(domains: tuple[Domain, ...], glossary: tuple[Term, ...]) -> dict[str, str]:
    index = entity_index(domains)
    files = {f"{OUT_DIR}/index.md": _index_page(domains, glossary, index)}
    for n, d in enumerate(domains, start=1):
        files[f"{OUT_DIR}/{file_name(n, d)}"] = _domain_page(n, d, domains, index)
    return files


def _cardinality(rel: Rel) -> str:
    return f"{rel.parent_card} : {rel.child_card}"


def _index_page(domains, glossary, index) -> str:
    total_entities = sum(len(d.entities) for d in domains)
    total_rels = sum(len(e.rels) for d in domains for e in d.entities)
    out = [
        GENERATED,
        "",
        "# Konseptual model — Bank OLTP verilənlər modeli",
        "",
        layer_nav(LAYER),
        "",
        "## Məqsəd və əhatə dairəsi",
        "",
        "Bu sənəd Azərbaycanda fəaliyyət göstərən universal bankın əsas bank sisteminin (core banking) "
        "**OLTP** verilənlər modelinin konseptual səviyyəsini təsvir edir. Konseptual model biznes obyektlərini və onlar "
        "arasındakı əlaqələri göstərir; atributlar, açarlar və texniki detallar məntiqi və fiziki modellərdə verilir.",
        "",
        "**Əsas qərarlar:**",
        "",
        "- Model **OLTP** üçündür: normallaşdırılmış (3NF), tranzaksiya bütövlüyü və istinad bütövlüyü (FK) ilə.",
        "- Yurisdiksiya: **Azərbaycan** — AZN və digər valyutalar, AZ IBAN, FİN, VÖEN, AZIPS/XÖHKS/SWIFT, AMB, MMX, Kredit Bürosu.",
        "- Müştəri növləri: **fiziki şəxs**, **hüquqi şəxs**, **fərdi sahibkar** (vahid *tərəf* supertipi altında).",
        "- Hesablar **çoxvalyutalıdır**; valyuta mübadiləsi ayrıca obyekt kimi modelləşdirilir.",
        "- Kreditlər: istehlak, ipoteka, biznes krediti, kredit xətti; girov və zaminlik. Kartlar: debet və kredit.",
        "- Hədəf VBİS: **PostgreSQL 18**.",
        "- İstinad modeli: Databricks *lakehouse banking MVM* (OLAP) yalnız terminologiya və əhatə üçün istifadə olunub; "
        "struktur OLTP prinsiplərinə görə yenidən qurulub.",
        "",
        f"**Statistika:** {len(domains)} domen, {total_entities} obyekt, {total_rels} əlaqə.",
        "",
        "## Domenlər xəritəsi",
        "",
        "Ox asılılığı göstərir: domen oxun göstərdiyi domenin obyektlərinə istinad edir. "
        "Qırıq xətt — istinad məlumatlarına asılılıq.",
        "",
        _domain_map(domains, index),
        "",
        "## Domenlər",
        "",
        "| # | Sxem | Domen | Obyekt sayı | Təsvir |",
        "|---|---|---|---|---|",
    ]
    for n, d in enumerate(domains, start=1):
        out.append(
            f"| {n} | `{d.schema}` | [{d.title}]({file_name(n, d)}) | {len(d.entities)} | {d.desc} |"
        )
    out += [
        "",
        "## Diaqramların oxunması",
        "",
        "| İşarə | Mənası |",
        "|---|---|",
        "| `\\|\\|` | dəqiq bir |",
        "| `\\|o` / `o\\|` | sıfır və ya bir |",
        "| `o{` | sıfır və ya çox |",
        "| `\\|{` | bir və ya çox |",
        "| bütöv xətt | əsas obyekt mütləqdir (məcburi əlaqə) |",
        "| qırıq xətt | əsas obyekt məcburi deyil (könüllü əlaqə) |",
        "",
        "Əlaqənin adı əsas obyektdən (sol) asılı obyektə (sağ) doğru oxunur. "
        "Cədvəllərdə kardinallıq `əsas : asılı` şəklində verilir.",
        "",
        "## Lüğət",
        "",
        "| Termin | İzah |",
        "|---|---|",
    ]
    out += [f"| **{t.term}** | {t.definition} |" for t in glossary]
    return "\n".join(out) + "\n"


def _domain_map(domains, index) -> str:
    body = ["flowchart LR"]
    for d in domains:
        body.append(f'    {d.schema}["{d.title}<br/>({len(d.entities)} obyekt)"]')
    edges: list[tuple[str, str]] = []
    for d in domains:
        for e in d.entities:
            for r in e.rels:
                target = index[r.parent][0].schema
                if target != d.schema and (d.schema, target) not in edges:
                    edges.append((d.schema, target))
    for src, dst in edges:
        arrow = "-.->" if dst == REF_SCHEMA else "-->"
        body.append(f"    {src} {arrow} {dst}")
    return fenced(body)


def _domain_page(n: int, d: Domain, domains, index) -> str:
    internal = {e.name for e in d.entities}
    shown: list[tuple[Entity, Rel]] = []
    ref_links: list[tuple[Entity, Rel]] = []
    for e in d.entities:
        for r in e.rels:
            parent_schema = index[r.parent][0].schema
            if parent_schema == REF_SCHEMA and d.schema != REF_SCHEMA:
                ref_links.append((e, r))
            else:
                shown.append((e, r))

    body = ["erDiagram"]
    body += [f"    {e.name}" for e in d.entities]
    externals = sorted({r.parent for _, r in shown if r.parent not in internal})
    body += [f"    {name}" for name in externals]
    body += [er_relationship(e.name, r) for e, r in shown]

    out = [
        GENERATED,
        "",
        f"# {d.title} (`{d.schema}`)",
        "",
        f"[← Konseptual model](index.md) | {layer_nav(LAYER, n, d)}",
        "",
        d.desc,
        "",
        "## Diaqram",
        "",
    ]
    if externals:
        out += [
            "Digər domenlərin obyektləri: " + ", ".join(f"`{x}` ({index[x][0].title})" for x in externals) + ".",
            "",
        ]
    out += [
        fenced(body),
        "",
        "## Obyektlər",
        "",
        "| # | Obyekt | Ad | Təsvir |",
        "|---|---|---|---|",
    ]
    for i, e in enumerate(d.entities, start=1):
        out.append(f"| {i} | `{e.name}` | **{e.title}** | {e.desc} |")

    out += [
        "",
        "## Əlaqələr",
        "",
        "| Əsas obyekt | Əlaqə | Asılı obyekt | Kardinallıq |",
        "|---|---|---|---|",
    ]
    for e, r in shown:
        out.append(f"| {_entity_ref(r.parent, d, index)} | {r.label} | `{e.name}` | {_cardinality(r)} |")

    if ref_links:
        out += [
            "",
            "## İstinad məlumatlarına əlaqələr",
            "",
            "Diaqramı sadə saxlamaq üçün `ref` sxeminə olan əlaqələr yalnız burada göstərilir.",
            "",
            "| Obyekt | İstinad obyekti | Əlaqə | Kardinallıq |",
            "|---|---|---|---|",
        ]
        for e, r in ref_links:
            out.append(f"| `{e.name}` | `{r.parent}` ({index[r.parent][1].title}) | {r.label} | {_cardinality(r)} |")

    incoming = [
        (od, oe, r)
        for od in domains
        if od.schema != d.schema
        for oe in od.entities
        for r in oe.rels
        if r.parent in internal
    ]
    if incoming:
        out += [
            "",
            "## Bu domenə istinad edən digər obyektlər",
            "",
            "| Obyekt | Domen | İstinad etdiyi obyekt | Əlaqə |",
            "|---|---|---|---|",
        ]
        for od, oe, r in incoming:
            out.append(f"| `{oe.name}` | {od.title} | `{r.parent}` | {r.label} |")
    return "\n".join(out) + "\n"


def _entity_ref(name: str, current: Domain, index) -> str:
    owner = index[name][0]
    return f"`{name}`" if owner.schema == current.schema else f"`{name}` ({owner.title})"
