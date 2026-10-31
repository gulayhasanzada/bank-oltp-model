"""Logical data types and their PostgreSQL 18 physical mapping.

Logical names are Azerbaijani (used in the logical model docs); the mapping is used by the
physical model and the DDL renderer.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class LogicalType:
    code: str
    title: str
    pg: str


LOGICAL_TYPES: dict[str, LogicalType] = {
    t.code: t
    for t in (
        LogicalType("id", "İdentifikator", "uuid"),
        LogicalType("code", "Kod", "varchar(30)"),
        LogicalType("short_text", "Qısa mətn", "varchar(100)"),
        LogicalType("text", "Mətn", "varchar(255)"),
        LogicalType("long_text", "Uzun mətn", "text"),
        LogicalType("amount", "Məbləğ", "numeric(19,4)"),
        LogicalType("rate", "Faiz dərəcəsi", "numeric(9,6)"),
        LogicalType("fx_rate", "Məzənnə", "numeric(18,8)"),
        LogicalType("percent", "Faiz payı", "numeric(5,2)"),
        LogicalType("count", "Say", "integer"),
        LogicalType("date", "Tarix", "date"),
        LogicalType("timestamp", "Tarix-vaxt", "timestamptz"),
        LogicalType("flag", "Bayraq (bəli/xeyr)", "boolean"),
        LogicalType("currency_code", "Valyuta kodu (ISO 4217)", "char(3)"),
        LogicalType("country_code", "Ölkə kodu (ISO 3166)", "char(2)"),
        LogicalType("iban", "IBAN", "varchar(34)"),
        LogicalType("fin", "FİN", "char(7)"),
        LogicalType("voen", "VÖEN", "char(10)"),
        LogicalType("bic", "BIC/SWIFT kodu", "varchar(11)"),
        LogicalType("json", "Strukturlaşdırılmış məlumat", "jsonb"),
    )
}
