from bankmodel.meta import Attribute as A
from bankmodel.meta import Check, Domain, Entity, Index, Rel, Unique, status_history

CARD_STATUSES = ("ISSUED", "ACTIVE", "BLOCKED", "LOST", "STOLEN", "EXPIRED", "CLOSED")
CARD_TXN_KINDS = ("PURCHASE", "CASH_WITHDRAWAL", "ECOMMERCE", "REFUND", "BALANCE_INQUIRY", "P2P")

DOMAIN = Domain(
    schema="card",
    title="Kartlar",
    desc=(
        "Debet və kredit kartları, onların limitləri, kredit kartı xətti və hesablaşma çıxarışları, "
        "real vaxt avtorizasiyaları və ödəniş sistemindən gələn klirinq əməliyyatları. "
        "Avtorizasiya bankın öz prosessinq sistemi tərəfindən aparılır. "
        "Kart həmişə hesaba bağlıdır: debet kart cari/kart hesabına, kredit kartı kredit xətti olan kart hesabına. "
        "Tam PAN, CVV və PIN bu bazada saxlanılmır (PCI DSS) — yalnız token və maskalanmış nömrə."
    ),
    entities=(
        Entity(
            "merchant",
            "Satıcı (ticarət obyekti)",
            "Kartla ödəniş qəbul edən ticarət obyekti: ad, MCC, ölkə, şəhər; avtorizasiya məlumatından yaradılır.",
            rels=(
                Rel("mcc", "kateqoriyasıdır"),
                Rel("country", "ölkəsidir"),
            ),
            attributes=(
                A("acquirer_id", "code", "Ekvayer bankın identifikatoru."),
                A("merchant_code", "code", "Ekvayerin verdiyi satıcı identifikatoru (MID)."),
                A("name", "text", "Satıcının adı (çeklərdə göstərilən)."),
                A("city", "short_text", "Şəhər.", optional=True),
            ),
            uniques=(Unique(("acquirer_id", "merchant_code")),),
        ),
        Entity(
            "card",
            "Kart",
            "Debet və ya kredit kartı: token, maskalanmış PAN, ödəniş sistemi (Visa/Mastercard), növ (fiziki/virtual), "
            "etibarlılıq müddəti, kart sahibi, bağlı hesab, status.",
            rels=(
                Rel("account", "kartıdır"),
                Rel("party", "kart sahibidir", fk="cardholder_party_id"),
                Rel("product", "məhsuludur"),
                Rel("card", "yenisi ilə əvəzlənib", parent_card="0..1", child_card="0..1", fk="replaced_card_id"),
            ),
            attributes=(
                A("card_token", "code", "Kart tokeni (tam PAN təhlükəsiz kart anbarında saxlanılır).", unique=True),
                A("masked_pan", "short_text", "Maskalanmış kart nömrəsi (416973******1234)."),
                A("card_scheme", "code", "Ödəniş sistemi.", values=("VISA", "MASTERCARD")),
                A("card_kind", "code", "Kartın növü.", values=("DEBIT", "CREDIT")),
                A("form_factor", "code", "Fiziki və ya virtual kart.", values=("PHYSICAL", "VIRTUAL")),
                A("embossed_name", "text", "Kartın üzərindəki ad.", optional=True),
                A("expiry_date", "date", "Etibarlılıq müddətinin sonu (ayın son günü)."),
                A("issued_date", "date", "Buraxılış tarixi."),
                A("activated_at", "timestamp", "Aktivləşmə anı.", optional=True),
                A("is_primary", "flag", "Əsas kartdır (əlavə kart deyil).", default="true"),
                A("status", "code", "Kartın statusu.", values=CARD_STATUSES),
            ),
            checks=(Check("expiry_after_issue", "expiry_date > issued_date", "Etibarlılıq tarixi buraxılış tarixindən sonra olmalıdır."),),
        ),
        status_history(
            "card_status_history",
            "Kart statusu tarixçəsi",
            "Kart statusunun dəyişiklikləri: buraxılış, aktivləşmə, bloklama, itki/oğurluq, bağlanma (yalnız əlavə olunur).",
            "card",
            CARD_STATUSES,
        ),
        Entity(
            "card_limit",
            "Kart limiti",
            "Kart üzrə limitlər: gündəlik nağdlaşdırma, POS, internet əməliyyatları, aylıq ümumi, tək əməliyyat.",
            rels=(Rel("card", "limitidir"),),
            attributes=(
                A(
                    "limit_type",
                    "code",
                    "Limitin növü.",
                    values=("DAILY_CASH", "DAILY_PURCHASE", "DAILY_ECOMMERCE", "MONTHLY_TOTAL", "SINGLE_TRANSACTION"),
                ),
                A("limit_amount", "amount", "Limit məbləği (hesab valyutasında)."),
                A("max_count", "count", "Əməliyyat sayı limiti.", optional=True),
                A("effective_from", "date", "Qüvvəyə minmə tarixi."),
                A("effective_to", "date", "Qüvvədən düşmə tarixi.", optional=True),
            ),
            uniques=(Unique(("card_id", "limit_type", "effective_from")),),
            checks=(
                Check("limit_non_negative", "limit_amount >= 0", "Limit mənfi ola bilməz."),
                Check("valid_period", "effective_to IS NULL OR effective_to >= effective_from", "Bitmə tarixi başlanğıcdan əvvəl ola bilməz."),
            ),
        ),
        Entity(
            "card_credit_line",
            "Kredit kartı xətti",
            "Kart hesabının kredit limiti və şərtləri: hesablaşma dövrü günü, güzəşt müddəti, minimal ödəniş faizi, illik faiz dərəcəsi (actual/365).",
            rels=(Rel("account", "kredit xəttidir", child_card="0..1"),),
            attributes=(
                A("credit_limit", "amount", "Kredit limiti."),
                A("annual_rate", "rate", "İllik faiz dərəcəsi."),
                A("billing_day", "count", "Hesablaşma dövrünün bağlandığı gün (1–28)."),
                A("grace_period_days", "count", "Güzəşt müddəti (gün)."),
                A("min_payment_percent", "percent", "Minimal ödəniş — borcun faizi."),
                A("effective_from", "date", "Qüvvəyə minmə tarixi."),
                A("status", "code", "Status.", values=("ACTIVE", "SUSPENDED", "CLOSED")),
            ),
            checks=(
                Check("billing_day_range", "billing_day BETWEEN 1 AND 28", "Hesablaşma günü 1–28 arasında olmalıdır."),
                Check("limit_positive", "credit_limit > 0", "Kredit limiti müsbət olmalıdır."),
                Check("min_payment_range", "min_payment_percent > 0 AND min_payment_percent <= 100", "Minimal ödəniş faizi 0–100% arasında olmalıdır."),
            ),
        ),
        Entity(
            "card_authorization",
            "Kart avtorizasiyası",
            "Bankın prosessinq sistemində kart əməliyyatı üçün real vaxt avtorizasiya sorğusu və cavabı (təsdiq/imtina): "
            "məbləğ, valyuta, satıcı/bankomat, cavab kodu, RRN, STAN. Yüksək həcmli cədvəldir, aylar üzrə bölmələnir.",
            rels=(
                Rel("card", "avtorizasiyasıdır"),
                Rel("currency", "əməliyyat valyutasıdır"),
                Rel("merchant", "satıcıdır", parent_card="0..1"),
                Rel("atm", "bankomatdır", parent_card="0..1"),
            ),
            attributes=(
                A("authorization_date", "date", "Avtorizasiyanın bank günü (bölmə açarı)."),
                A("authorized_at", "timestamp", "Sorğunun anı."),
                A("transaction_kind", "code", "Əməliyyatın növü.", values=CARD_TXN_KINDS),
                A("amount", "amount", "Əməliyyat valyutasında məbləğ."),
                A("billing_amount", "amount", "Hesab valyutasında məbləğ (bloklanan)."),
                A("entry_mode", "code", "Kart məlumatının daxil edilmə üsulu.", values=("CHIP", "CONTACTLESS", "MAGSTRIPE", "ECOMMERCE", "MANUAL")),
                A("terminal_id", "code", "Terminalın identifikatoru.", optional=True),
                A("rrn", "code", "Retrieval Reference Number — əməliyyatın istinad nömrəsi."),
                A("stan", "code", "System Trace Audit Number."),
                A("auth_code", "code", "Təsdiq kodu (təsdiq edilmiş əməliyyatlar üçün).", optional=True),
                A("response_code", "code", "Cavab kodu (ISO 8583, 00 — təsdiq)."),
                A("decision", "code", "Qərar.", values=("APPROVED", "DECLINED")),
                A("decline_reason", "text", "İmtinanın səbəbi.", optional=True),
                A("is_reversed", "flag", "Avtorizasiya ləğv edilib (reversal).", default="false"),
            ),
            checks=(
                Check("approved_has_code", "decision <> 'APPROVED' OR auth_code IS NOT NULL", "Təsdiq edilmiş avtorizasiyanın təsdiq kodu olmalıdır."),
                Check("amount_non_negative", "amount >= 0 AND billing_amount >= 0", "Məbləğ mənfi ola bilməz."),
            ),
            indexes=(Index(("rrn",)), Index(("card_id", "authorization_date"))),
            partition_by="authorization_date",
        ),
        Entity(
            "card_transaction",
            "Kart əməliyyatı (klirinq)",
            "Ödəniş sisteminin klirinq/hesablaşma faylı ilə təsdiqlənmiş kart əməliyyatı: əməliyyat və hesablaşma məbləği, valyutası, komissiya. "
            "Yüksək həcmli cədvəldir, aylar üzrə bölmələnir.",
            rels=(
                Rel("card", "əməliyyatıdır"),
                Rel("currency", "əməliyyat valyutasıdır"),
                Rel("card_authorization", "klirinqidir", parent_card="0..1"),
                Rel("merchant", "satıcıdır", parent_card="0..1"),
            ),
            attributes=(
                A("transaction_date", "date", "Əməliyyatın tarixi (bölmə açarı)."),
                A("clearing_date", "date", "Klirinq faylının tarixi."),
                A("settlement_date", "date", "Hesablaşma tarixi.", optional=True),
                A("transaction_kind", "code", "Əməliyyatın növü.", values=CARD_TXN_KINDS),
                A("amount", "amount", "Əməliyyat valyutasında məbləğ."),
                A("billing_amount", "amount", "Hesab valyutasında məbləğ."),
                A("interchange_fee", "amount", "İnterçeync komissiyası.", optional=True),
                A("rrn", "code", "Retrieval Reference Number."),
                A("arn", "code", "Acquirer Reference Number.", optional=True),
                A("status", "code", "Status.", values=("CLEARED", "POSTED", "DISPUTED", "REVERSED")),
            ),
            checks=(Check("amount_non_negative", "amount >= 0 AND billing_amount >= 0", "Məbləğ mənfi ola bilməz."),),
            indexes=(Index(("rrn",)), Index(("card_id", "transaction_date"))),
            partition_by="transaction_date",
        ),
        Entity(
            "card_billing_statement",
            "Kredit kartı çıxarışı",
            "Kredit kartı üzrə hesablaşma dövrü çıxarışı: ümumi borc, minimal ödəniş, son ödəniş tarixi, ödənilmə vəziyyəti.",
            rels=(Rel("card_credit_line", "çıxarışıdır"),),
            attributes=(
                A("period_start", "date", "Dövrün başlanğıcı."),
                A("period_end", "date", "Dövrün sonu."),
                A("due_date", "date", "Minimal ödənişin son tarixi."),
                A("opening_balance", "amount", "Dövrün əvvəlinə borc."),
                A("total_purchases", "amount", "Dövr ərzində xərclər."),
                A("total_payments", "amount", "Dövr ərzində ödənişlər."),
                A("interest_charged", "amount", "Hesablanmış faiz.", default="0"),
                A("closing_balance", "amount", "Dövrün sonuna ümumi borc."),
                A("minimum_payment", "amount", "Minimal ödəniş məbləği."),
                A("paid_amount", "amount", "Son tarixədək ödənilmiş məbləğ.", default="0"),
                A("status", "code", "Status.", values=("OPEN", "PAID", "PARTIALLY_PAID", "OVERDUE")),
            ),
            uniques=(Unique(("card_credit_line_id", "period_start")),),
            checks=(
                Check("valid_period", "period_end >= period_start AND due_date >= period_end", "Dövr tarixləri ardıcıl olmalıdır."),
                Check("minimum_le_balance", "minimum_payment <= GREATEST(closing_balance, 0)", "Minimal ödəniş ümumi borcdan çox ola bilməz."),
            ),
        ),
    ),
)
