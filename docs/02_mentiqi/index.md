<!-- Bu fayl avtomatik yaradılıb (uv run bankmodel generate). Əl ilə redaktə etməyin. -->

# Məntiqi model — Bank OLTP verilənlər modeli

[Konseptual model](../01_konseptual/index.md) · **Məntiqi model** · [Fiziki model](../03_fiziki/index.md)

Məntiqi model konseptual modeldəki hər obyekti atributları, məntiqi tipləri, açarları, əlaqələri və biznes qaydaları ilə təsvir edir. Model konkret VBİS-dən asılı deyil; PostgreSQL üzrə reallaşdırma fiziki modeldədir.

**Statistika:** 9 domen, 86 obyekt, 798 biznes atributu (audit atributları istisna olmaqla).

## Modelləşdirmə qaydaları

- **Normallaşdırma.** Model 3-cü normal formadadır (3NF): hər qeyri-açar atribut yalnız öz obyektinin açarından asılıdır, təkrarlanan qruplar ayrıca obyektlərə çıxarılıb (ünvanlar, əlaqə vasitələri, sənədlər, hesab sahibləri və s.).
- **İdentifikatorlar.** Hər obyektin surrogat əsas açarı `<obyekt>_id` (UUID) var. Biznes açarları (CIF, IBAN, FİN, VÖEN, müqavilə nömrələri) alternativ açar (AK) kimi unikaldır.
- **Əlaqələr.** Hər əlaqə asılı obyektdə xarici açar (FK) atributu kimi reallaşır. Eyni obyektə bir neçə əlaqə olduqda atribut rol adı daşıyır (məs. `debit_account_id`, `relationship_manager_id`).
- **Supertip / subtip.** `party` supertipdir; `party_type` diskriminatordur. Fiziki şəxs → `individual_profile`, hüquqi şəxs → `organization_profile`, fərdi sahibkar → hər ikisi (1:0..1).
- **Rollar.** Müştəri (`customer`), hesab sahibi (`account_holder`), zamin (`loan_guarantee`), girov mülkiyyətçisi (`collateral`) tərəfin rollarıdır; eyni şəxs bir dəfə saxlanılır.
- **Kod siyahıları.** Kiçik, sistem tərəfindən idarə olunan siyahılar atributun icazəli dəyərləri kimi verilir; biznesin dəyişdirdiyi siyahılar (məhsul, əməliyyat növü, komissiya növü, sənəd növü və s.) `ref` domenində ayrıca obyektlərdir.
- **Tarixçə.** Tərəf, hesab, ödəniş, kart və kredit statusları `*_status_history` obyektlərində saxlanılır (yalnız əlavə olunur). Zamanla dəyişən şərtlər (faiz dərəcələri, limitlər, ünvanlar, rollar) `effective_from` / `effective_to` ilə versiyalanır.
- **Pul məbləğləri.** Məbləğ həmişə müsbətdir; istiqamət ayrıca atributla (DEBIT/CREDIT) verilir. Məbləğin valyutası obyektin öz valyuta əlaqəsindən və ya bağlı hesabın valyutasından müəyyən olunur.
- **Faiz hesablanması.** Bütün faizlər faktiki/365 (actual/365) bazası ilə: gündəlik faiz = qalıq × illik dərəcə / 365. Dəbbə gündəlik dərəcə ilə hesablanır: gecikmiş məbləğ (müqavilədəki bazaya görə) × gündəlik dərəcə.

### İdarə olunan denormallaşdırmalar

OLTP performansı və ya hüquqi tələblər üçün aşağıdakı törəmə məlumatlar şüurlu olaraq saxlanılır və mənbə ilə eyni tranzaksiyada yenilənir:

| Atribut(lar) | Mənbə | Səbəb |
|---|---|---|
| `account_balance.*` | `account_transaction`, `hold` | Hər əməliyyatda qalığın sürətli yoxlanılması |
| `account_transaction.balance_after` | Əvvəlki qalıq + məbləğ | Çıxarış və mübahisələr üçün |
| `loan.outstanding_principal`, `loan.days_past_due` | Verilmə, ödəniş, qrafik | Kredit portfelinin operativ idarəsi |
| `payment_order.beneficiary_*` | `beneficiary` | Tapşırıq anındakı rekvizitlərin hüquqi qeydiyyatı |
| `journal_entry_line.amount_azn` | Məbləğ × AMB məzənnəsi | Yazılış anındakı məzənnənin qeydiyyatı |

### Audit atributları

Aşağıdakı atributlar hər obyektdə var və obyekt cədvəllərində təkrarlanmır:

| Atribut | Məntiqi tip | Məcburi | Təsvir |
|---|---|---|---|
| `created_at` | Tarix-vaxt | Bəli | Yazılışın yaradıldığı an. |
| `created_by` | Qısa mətn | Bəli | Yazılışı yaradan istifadəçi. |
| `updated_at` | Tarix-vaxt | Xeyr | Son dəyişiklik anı. |
| `updated_by` | Qısa mətn | Xeyr | Son dəyişikliyi edən istifadəçi. |

## Məntiqi tiplər

| Kod | Məntiqi tip |
|---|---|
| `id` | İdentifikator |
| `code` | Kod |
| `short_text` | Qısa mətn |
| `text` | Mətn |
| `long_text` | Uzun mətn |
| `amount` | Məbləğ |
| `rate` | Faiz dərəcəsi |
| `fx_rate` | Məzənnə |
| `percent` | Faiz payı |
| `count` | Say |
| `date` | Tarix |
| `timestamp` | Tarix-vaxt |
| `flag` | Bayraq (bəli/xeyr) |
| `currency_code` | Valyuta kodu (ISO 4217) |
| `country_code` | Ölkə kodu (ISO 3166) |
| `iban` | IBAN |
| `fin` | FİN |
| `voen` | VÖEN |
| `bic` | BIC/SWIFT kodu |
| `json` | Strukturlaşdırılmış məlumat |

## Domenlər

| # | Domen | Obyekt sayı | Atribut sayı |
|---|---|---|---|
| 1 | [İstinad məlumatları](01_ref.md) (`ref`) | 15 | 101 |
| 2 | [Təşkilat və kanallar](02_org.md) (`org`) | 4 | 35 |
| 3 | [Tərəf və müştəri (KYC)](03_party.md) (`party`) | 12 | 109 |
| 4 | [Hesablar və əməliyyatlar](04_account.md) (`account`) | 15 | 140 |
| 5 | [Ödənişlər](05_payment.md) (`payment`) | 6 | 64 |
| 6 | [Kartlar](06_card.md) (`card`) | 8 | 93 |
| 7 | [Kreditlər](07_loan.md) (`loan`) | 16 | 170 |
| 8 | [Baş kitab (sadələşdirilmiş)](08_ledger.md) (`ledger`) | 5 | 40 |
| 9 | [Uyğunluq və AML (sadələşdirilmiş)](09_compliance.md) (`compliance`) | 5 | 46 |

## Diaqramların oxunması

`PK` — əsas açar, `FK` — xarici açar, `AKn` — n-ci alternativ (unikal) açar. Kardinallıq işarələri konseptual modeldəki kimidir. Diaqramlarda audit atributları göstərilmir; `ref` domeninə olan əlaqələr yalnız atribut cədvəllərində verilir.
