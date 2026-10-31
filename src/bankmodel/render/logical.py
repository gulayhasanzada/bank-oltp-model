"""Logical model: attributes with logical types, keys, relationships and business rules. Engine independent."""

from __future__ import annotations

from bankmodel.meta import Domain, Entity, Term, entity_index
from bankmodel.render.common import GENERATED, REF_SCHEMA, cell, code_list, file_name, layer_nav
from bankmodel.render.mermaid import er_entity, er_relationship, fenced
from bankmodel.resolve import AUDIT, columns, primary_key, unique_keys
from bankmodel.types import LOGICAL_TYPES

LAYER = "02_mentiqi"
OUT_DIR = f"docs/{LAYER}"


def render(domains: tuple[Domain, ...], glossary: tuple[Term, ...]) -> dict[str, str]:
    index = entity_index(domains)
    files = {f"{OUT_DIR}/index.md": _index_page(domains, index)}
    for n, d in enumerate(domains, start=1):
        files[f"{OUT_DIR}/{file_name(n, d)}"] = _domain_page(n, d, index)
    return files


def _business_columns(e: Entity, index):
    return [c for c in columns(e, index, physical=False) if c.role != "audit"]


def _key_markers(e: Entity, index) -> dict[str, list[str]]:
    markers: dict[str, list[str]] = {}
    for name in primary_key(e, physical=False):
        markers.setdefault(name, []).append("PK")
    for c in _business_columns(e, index):
        if c.role == "fk":
            markers.setdefault(c.name, []).append("FK")
    for i, k in enumerate(unique_keys(e, index, physical=False), start=1):
        for name in k.columns:
            markers.setdefault(name, []).append(f"AK{i}")
    return markers


def _index_page(domains, index) -> str:
    n_entities = sum(len(d.entities) for d in domains)
    n_attrs = sum(len(_business_columns(e, index)) for d in domains for e in d.entities)
    out = [
        GENERATED,
        "",
        "# Məntiqi model — Bank OLTP verilənlər modeli",
        "",
        layer_nav(LAYER),
        "",
        "Məntiqi model konseptual modeldəki hər obyekti atributları, məntiqi tipləri, açarları, əlaqələri və biznes qaydaları ilə "
        "təsvir edir. Model konkret VBİS-dən asılı deyil; PostgreSQL üzrə reallaşdırma fiziki modeldədir.",
        "",
        f"**Statistika:** {len(domains)} domen, {n_entities} obyekt, {n_attrs} biznes atributu (audit atributları istisna olmaqla).",
        "",
        "## Modelləşdirmə qaydaları",
        "",
        "- **Normallaşdırma.** Model 3-cü normal formadadır (3NF): hər qeyri-açar atribut yalnız öz obyektinin açarından asılıdır, "
        "təkrarlanan qruplar ayrıca obyektlərə çıxarılıb (ünvanlar, əlaqə vasitələri, sənədlər, hesab sahibləri və s.).",
        "- **İdentifikatorlar.** Hər obyektin surrogat əsas açarı `<obyekt>_id` (UUID) var. Biznes açarları (CIF, IBAN, FİN, VÖEN, "
        "müqavilə nömrələri) alternativ açar (AK) kimi unikaldır.",
        "- **Əlaqələr.** Hər əlaqə asılı obyektdə xarici açar (FK) atributu kimi reallaşır. Eyni obyektə bir neçə əlaqə olduqda "
        "atribut rol adı daşıyır (məs. `debit_account_id`, `relationship_manager_id`).",
        "- **Supertip / subtip.** `party` supertipdir; `party_type` diskriminatordur. Fiziki şəxs → `individual_profile`, "
        "hüquqi şəxs → `organization_profile`, fərdi sahibkar → hər ikisi (1:0..1).",
        "- **Rollar.** Müştəri (`customer`), hesab sahibi (`account_holder`), zamin (`loan_guarantee`), girov mülkiyyətçisi "
        "(`collateral`) tərəfin rollarıdır; eyni şəxs bir dəfə saxlanılır.",
        "- **Kod siyahıları.** Kiçik, sistem tərəfindən idarə olunan siyahılar atributun icazəli dəyərləri kimi verilir; biznesin "
        "dəyişdirdiyi siyahılar (məhsul, əməliyyat növü, komissiya növü, sənəd növü və s.) `ref` domenində ayrıca obyektlərdir.",
        "- **Tarixçə.** Tərəf, hesab, ödəniş, kart və kredit statusları `*_status_history` obyektlərində saxlanılır (yalnız əlavə olunur). "
        "Zamanla dəyişən şərtlər (faiz dərəcələri, limitlər, ünvanlar, rollar) `effective_from` / `effective_to` ilə versiyalanır.",
        "- **Pul məbləğləri.** Məbləğ həmişə müsbətdir; istiqamət ayrıca atributla (DEBIT/CREDIT) verilir. Məbləğin valyutası "
        "obyektin öz valyuta əlaqəsindən və ya bağlı hesabın valyutasından müəyyən olunur.",
        "- **Faiz hesablanması.** Bütün faizlər faktiki/365 (actual/365) bazası ilə: gündəlik faiz = qalıq × illik dərəcə / 365. "
        "Dəbbə gündəlik dərəcə ilə hesablanır: gecikmiş məbləğ (müqavilədəki bazaya görə) × gündəlik dərəcə.",
        "",
        "### İdarə olunan denormallaşdırmalar",
        "",
        "OLTP performansı və ya hüquqi tələblər üçün aşağıdakı törəmə məlumatlar şüurlu olaraq saxlanılır və mənbə ilə eyni "
        "tranzaksiyada yenilənir:",
        "",
        "| Atribut(lar) | Mənbə | Səbəb |",
        "|---|---|---|",
        "| `account_balance.*` | `account_transaction`, `hold` | Hər əməliyyatda qalığın sürətli yoxlanılması |",
        "| `account_transaction.balance_after` | Əvvəlki qalıq + məbləğ | Çıxarış və mübahisələr üçün |",
        "| `loan.outstanding_principal`, `loan.days_past_due` | Verilmə, ödəniş, qrafik | Kredit portfelinin operativ idarəsi |",
        "| `payment_order.beneficiary_*` | `beneficiary` | Tapşırıq anındakı rekvizitlərin hüquqi qeydiyyatı |",
        "| `journal_entry_line.amount_azn` | Məbləğ × AMB məzənnəsi | Yazılış anındakı məzənnənin qeydiyyatı |",
        "",
        "### Audit atributları",
        "",
        "Aşağıdakı atributlar hər obyektdə var və obyekt cədvəllərində təkrarlanmır:",
        "",
        "| Atribut | Məntiqi tip | Məcburi | Təsvir |",
        "|---|---|---|---|",
    ]
    for name, ltype, desc, optional, _ in AUDIT:
        out.append(f"| `{name}` | {LOGICAL_TYPES[ltype].title} | {'Xeyr' if optional else 'Bəli'} | {desc} |")
    out += [
        "",
        "## Məntiqi tiplər",
        "",
        "| Kod | Məntiqi tip |",
        "|---|---|",
    ]
    out += [f"| `{t.code}` | {t.title} |" for t in LOGICAL_TYPES.values()]
    out += [
        "",
        "## Domenlər",
        "",
        "| # | Domen | Obyekt sayı | Atribut sayı |",
        "|---|---|---|---|",
    ]
    for n, d in enumerate(domains, start=1):
        attrs = sum(len(_business_columns(e, index)) for e in d.entities)
        out.append(f"| {n} | [{d.title}]({file_name(n, d)}) (`{d.schema}`) | {len(d.entities)} | {attrs} |")
    out += [
        "",
        "## Diaqramların oxunması",
        "",
        "`PK` — əsas açar, `FK` — xarici açar, `AKn` — n-ci alternativ (unikal) açar. Kardinallıq işarələri konseptual modeldəki kimidir. "
        "Diaqramlarda audit atributları göstərilmir; `ref` domeninə olan əlaqələr yalnız atribut cədvəllərində verilir.",
    ]
    return "\n".join(out) + "\n"


def _domain_page(n: int, d: Domain, index) -> str:
    internal = {e.name for e in d.entities}
    body = ["erDiagram"]
    edges = []
    for e in d.entities:
        markers = _key_markers(e, index)
        attrs = [(c.ltype, c.name, ", ".join(_mermaid_keys(markers.get(c.name, [])))) for c in _business_columns(e, index)]
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
        f"# {d.title} (`{d.schema}`) — məntiqi model",
        "",
        f"[← Məntiqi model](index.md) | {layer_nav(LAYER, n, d)}",
        "",
        d.desc,
        "",
        "## Diaqram",
        "",
        fenced(body),
        "",
        "## Obyektlər",
    ]
    for i, e in enumerate(d.entities, start=1):
        out += ["", *_entity_section(i, e, index)]
    return "\n".join(out) + "\n"


def _mermaid_keys(markers: list[str]) -> list[str]:
    # Mermaid knows PK, FK and UK; all alternate keys map to UK.
    keys = []
    for m in markers:
        k = "UK" if m.startswith("AK") else m
        if k not in keys:
            keys.append(k)
    return keys


def _entity_section(i: int, e: Entity, index) -> list[str]:
    markers = _key_markers(e, index)
    out = [
        f"### {i}. `{e.name}` — {e.title}",
        "",
        e.desc,
        "",
        "| # | Atribut | Məntiqi tip | Məcburi | Açar | Təsvir |",
        "|---|---|---|---|---|---|",
    ]
    for j, c in enumerate(_business_columns(e, index), start=1):
        desc = c.desc
        if c.values:
            desc += f"<br>Dəyərlər: {code_list(c.values)}"
        if c.default and c.role != "pk":
            desc += f"<br>Susmaya görə: `{c.default}`"
        out.append(
            f"| {j} | `{c.name}` | {LOGICAL_TYPES[c.ltype].title} | {'Xeyr' if c.optional else 'Bəli'} | "
            f"{', '.join(markers.get(c.name, []))} | {cell(desc)} |"
        )
    out += ["", f"**Əsas açar:** {code_list(primary_key(e, physical=False))}"]
    keys = unique_keys(e, index, physical=False)
    if keys:
        out += ["", "**Alternativ açarlar:**", ""]
        for k_i, k in enumerate(keys, start=1):
            note = " (boş dəyərlər də təkrarlana bilməz)" if k.nulls_not_distinct else ""
            out.append(f"- AK{k_i}: {code_list(k.columns)}{note}")
    if e.rels:
        out += ["", "**Əlaqələr:**", "", "| FK atributu | İstinad obyekti | Kardinallıq | Əlaqə |", "|---|---|---|---|"]
        for r in e.rels:
            parent_domain, parent = index[r.parent]
            out.append(
                f"| `{r.fk_column}` | `{parent_domain.schema}.{r.parent}` ({parent.title}) | "
                f"{r.parent_card} : {r.child_card} | {r.label} |"
            )
    if e.checks:
        out += ["", "**Biznes qaydaları:**", ""]
        out += [f"- {c.desc}" for c in e.checks]
    return out
