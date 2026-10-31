<!-- Bu fayl avtomatik yaradılıb (uv run bankmodel generate). Əl ilə redaktə etməyin. -->

# Fiziki model — PostgreSQL 18

[Konseptual model](../01_konseptual/index.md) · [Məntiqi model](../02_mentiqi/index.md) · **Fiziki model**

Fiziki model məntiqi modelin PostgreSQL 18 üzərində reallaşdırılmasıdır. Tam DDL skripti: [`ddl/banking_oltp_pg18.sql`](../../ddl/banking_oltp_pg18.sql).

**Statistika:** 9 sxem, 86 cədvəl (4 bölmələnmiş), 1150 sütun, 167 xarici açar, 67 unikal məhdudiyyət, 216 CHECK məhdudiyyəti, 150 indeks.

## Sxemlər

Hər domen ayrıca PostgreSQL sxemidir.

| # | Sxem | Domen | Cədvəl sayı |
|---|---|---|---|
| 1 | `ref` | [İstinad məlumatları](01_ref.md) | 15 |
| 2 | `org` | [Təşkilat və kanallar](02_org.md) | 4 |
| 3 | `party` | [Tərəf və müştəri (KYC)](03_party.md) | 12 |
| 4 | `account` | [Hesablar və əməliyyatlar](04_account.md) | 15 |
| 5 | `payment` | [Ödənişlər](05_payment.md) | 6 |
| 6 | `card` | [Kartlar](06_card.md) | 8 |
| 7 | `loan` | [Kreditlər](07_loan.md) | 16 |
| 8 | `ledger` | [Baş kitab (sadələşdirilmiş)](08_ledger.md) | 5 |
| 9 | `compliance` | [Uyğunluq və AML (sadələşdirilmiş)](09_compliance.md) | 5 |

## Adlandırma qaydaları

| Obyekt | Qayda | Nümunə |
|---|---|---|
| Cədvəl, sütun | ingiliscə `snake_case`, tək halda | `account_transaction` |
| Əsas açar sütunu | `<cədvəl>_id` | `account_id` |
| Xarici açar sütunu | `<istinad cədvəli>_id` və ya `<rol>_id` | `debit_account_id` |
| Əsas açar | `pk_<cədvəl>` | `pk_account` |
| Unikal məhdudiyyət | `uq_<cədvəl>_<sütunlar>` | `uq_account_iban` |
| CHECK | `ck_<cədvəl>_<sütun və ya qayda>` | `ck_account_status` |
| Xarici açar | `fk_<cədvəl>_<sütun>` | `fk_account_customer_id` |
| İndeks | `ix_<cədvəl>_<sütunlar>` | `ix_account_customer_id` |
| Bölmə | `<cədvəl>_p<il>_<ay>`, `<cədvəl>_default` | `account_transaction_p2026_10` |

63 simvoldan uzun adlar sabit hash şəkilçisi ilə qısaldılır.

## Tiplərin uyğunluğu

| Məntiqi tip | PostgreSQL tipi |
|---|---|
| İdentifikator (`id`) | `uuid` |
| Kod (`code`) | `varchar(30)` |
| Qısa mətn (`short_text`) | `varchar(100)` |
| Mətn (`text`) | `varchar(255)` |
| Uzun mətn (`long_text`) | `text` |
| Məbləğ (`amount`) | `numeric(19,4)` |
| Faiz dərəcəsi (`rate`) | `numeric(9,6)` |
| Məzənnə (`fx_rate`) | `numeric(18,8)` |
| Faiz payı (`percent`) | `numeric(5,2)` |
| Say (`count`) | `integer` |
| Tarix (`date`) | `date` |
| Tarix-vaxt (`timestamp`) | `timestamptz` |
| Bayraq (bəli/xeyr) (`flag`) | `boolean` |
| Valyuta kodu (ISO 4217) (`currency_code`) | `char(3)` |
| Ölkə kodu (ISO 3166) (`country_code`) | `char(2)` |
| IBAN (`iban`) | `varchar(34)` |
| FİN (`fin`) | `char(7)` |
| VÖEN (`voen`) | `char(10)` |
| BIC/SWIFT kodu (`bic`) | `varchar(11)` |
| Strukturlaşdırılmış məlumat (`json`) | `jsonb` |

## Fiziki qərarlar

- **Əsas açarlar** `uuid DEFAULT uuidv7()` — PostgreSQL 18-in daxili funksiyası; zamana görə sıralanan UUID-lər B-tree indekslərində ardıcıl yazılır və təsadüfi UUIDv4-dən fərqli olaraq indeksi parçalamır.
- **Məbləğlər** `numeric(19,4)` — üzən nöqtəli tiplər istifadə olunmur. Faiz dərəcələri `numeric(9,6)`, məzənnələr `numeric(18,8)`.
- **Vaxt** `timestamptz` (UTC saxlanılır); bank günü və dəyər tarixi `date`.
- **Kod siyahıları:** kiçik siyahılar `CHECK (sütun IN (...))`, biznes siyahıları `ref` sxemindəki cədvəllərə FK.
- **Xarici açarlar** `ON DELETE NO ACTION` — kaskad silmə yoxdur; bank məlumatları silinmir, statusla bağlanır.
- **FK indeksləri:** açar və ya digər indeksin başlanğıcı ilə örtülməyən hər FK üçün avtomatik indeks yaradılır.
- **Audit sütunları:** `created_at DEFAULT now()`, `created_by DEFAULT current_user`; `updated_at` / `updated_by` tətbiq tərəfindən doldurulur.
- **Şərhlər:** hər sxem, cədvəl və sütun üçün `COMMENT ON` (Azərbaycan dilində).

## Bölmələmə (partitioning)

Yüksək həcmli cədvəllər tarix sütunu üzrə aylıq `RANGE` bölmələrinə ayrılır. DDL 2026-01 – 2027-12 ayları üçün bölmələr və bir `DEFAULT` bölmə yaradır; sonrakı aylar üçün bölmələr ay başlamazdan əvvəl planlaşdırılmış iş (məs. pg_partman) ilə yaradılmalıdır.

PostgreSQL bölmələnmiş cədvəldə əsas və unikal açarların bölmə sütununu ehtiva etməsini tələb edir. Buna görə:

- bölmələnmiş cədvəlin əsas açarı `(<cədvəl>_id, <bölmə tarixi>)` cütüdür;
- ona istinad edən cədvəllərdə FK kompozitdir: `<rol>_id` + `<rol>_date` (məs. `account_transaction_id`, `account_transaction_date`);
- bölmələnmiş cədvəlin unikal açarlarına bölmə sütunu əlavə olunur.

| Cədvəl | Bölmə sütunu |
|---|---|
| `account.account_transaction` | `transaction_date` |
| `card.card_authorization` | `authorization_date` |
| `card.card_transaction` | `transaction_date` |
| `ledger.journal_entry_line` | `entry_date` |

## Quraşdırma

```powershell
Copy-Item .env.example .env    # şifrəni dəyişin
docker compose up -d           # PostgreSQL 18 konteyneri
uv run bankmodel apply         # DDL-i icra edir (sxemləri silib yenidən yaradır)
```
