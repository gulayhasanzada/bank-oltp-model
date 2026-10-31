from bankmodel.meta import Attribute as A
from bankmodel.meta import Check, Domain, Entity, Index, Rel, Unique, status_history

PAYMENT_STATUSES = (
    "CREATED", "PENDING_APPROVAL", "SCREENING", "SENT", "EXECUTED", "REJECTED", "CANCELLED", "RETURNED",
)
PAYMENT_SYSTEMS = ("AZIPS", "XOHKS", "SWIFT")

DOMAIN = Domain(
    schema="payment",
    title="Ödənişlər",
    desc=(
        "Müştərilərin köçürmə tapşırıqları və onların icrası: daxili köçürmələr, yerli ödəniş sistemləri "
        "(AZIPS — iri məbləğli real vaxt, XÖHKS — kütləvi ödənişlər), beynəlxalq SWIFT köçürmələri, "
        "büdcə ödənişləri, qaytarılmalar və valyuta mübadiləsi."
    ),
    entities=(
        Entity(
            "beneficiary",
            "Benefisiar (alan)",
            "Müştərinin yadda saxladığı köçürmə alanı: ad, IBAN/hesab nömrəsi, VÖEN/FİN, alan bank.",
            rels=(
                Rel("customer", "şablonudur"),
                Rel("bank_directory", "alan bankdır", parent_card="0..1"),
            ),
            attributes=(
                A("beneficiary_name", "text", "Alanın adı."),
                A("iban", "iban", "Alanın IBAN-ı.", optional=True),
                A("account_number", "short_text", "Alanın hesab nömrəsi (IBAN olmayan ölkələr üçün).", optional=True),
                A("tax_id", "short_text", "Alanın VÖEN-i və ya FİN-i.", optional=True),
                A("alias", "short_text", "Müştərinin verdiyi qısa ad.", optional=True),
                A("is_active", "flag", "Şablon aktivdir.", default="true"),
            ),
            checks=(Check("has_account", "num_nonnulls(iban, account_number) >= 1", "IBAN və ya hesab nömrəsi göstərilməlidir."),),
        ),
        Entity(
            "payment_order",
            "Ödəniş tapşırığı",
            "Müştərinin köçürmə tapşırığı: növü (daxili, AZIPS, XÖHKS, SWIFT, büdcə), məbləğ, valyuta, təyinat, büdcə təsnifat kodu, dəyər tarixi, status. "
            "Alanın rekvizitləri tapşırıq anındakı vəziyyətlə saxlanılır (şablon sonradan dəyişsə də tapşırıq dəyişməz).",
            rels=(
                Rel("account", "debet hesabıdır", fk="debit_account_id"),
                Rel("beneficiary", "alanıdır", parent_card="0..1"),
                Rel("bank_directory", "alan bankdır", parent_card="0..1", fk="beneficiary_bank_id"),
                Rel("currency", "valyutasıdır"),
                Rel("channel", "qəbul kanalıdır"),
            ),
            attributes=(
                A("order_number", "code", "Tapşırığın unikal nömrəsi.", unique=True),
                A("payment_type", "code", "Ödənişin növü.", values=("INTERNAL", "AZIPS", "XOHKS", "SWIFT", "BUDGET")),
                A("amount", "amount", "Köçürmə məbləği (tapşırığın valyutasında)."),
                A("value_date", "date", "İstənilən dəyər tarixi."),
                A("purpose", "text", "Ödənişin təyinatı."),
                A("budget_classification_code", "code", "Büdcə təsnifatı kodu (büdcə ödənişləri üçün).", optional=True),
                A("budget_level_code", "code", "Büdcə səviyyəsinin kodu (büdcə ödənişləri üçün).", optional=True),
                A("beneficiary_name", "text", "Alanın adı (tapşırıq anında)."),
                A("beneficiary_iban", "iban", "Alanın IBAN-ı (tapşırıq anında).", optional=True),
                A("beneficiary_account_number", "short_text", "Alanın hesab nömrəsi (IBAN olmadıqda).", optional=True),
                A("beneficiary_tax_id", "short_text", "Alanın VÖEN-i / FİN-i.", optional=True),
                A("charge_bearer", "code", "SWIFT komissiyasını kim ödəyir.", optional=True, values=("OUR", "SHA", "BEN")),
                A("priority", "code", "Prioritet.", default="'NORMAL'", values=("NORMAL", "URGENT")),
                A("submitted_at", "timestamp", "Tapşırığın qəbul edildiyi an.", default="now()"),
                A("executed_at", "timestamp", "İcra anı.", optional=True),
                A("status", "code", "Tapşırığın statusu.", values=PAYMENT_STATUSES),
            ),
            checks=(
                Check("amount_positive", "amount > 0", "Məbləğ müsbət olmalıdır."),
                Check("has_beneficiary_account", "num_nonnulls(beneficiary_iban, beneficiary_account_number) >= 1", "Alanın IBAN-ı və ya hesab nömrəsi olmalıdır."),
                Check(
                    "budget_fields",
                    "payment_type <> 'BUDGET' OR (budget_classification_code IS NOT NULL AND budget_level_code IS NOT NULL)",
                    "Büdcə ödənişində büdcə təsnifatı və səviyyə kodları məcburidir.",
                ),
                Check("swift_charges", "payment_type <> 'SWIFT' OR charge_bearer IS NOT NULL", "SWIFT köçürməsində komissiya ödəyicisi göstərilməlidir."),
            ),
            indexes=(Index(("status", "value_date"), where="status NOT IN ('EXECUTED', 'REJECTED', 'CANCELLED', 'RETURNED')"),),
        ),
        status_history(
            "payment_status_history",
            "Ödəniş statusu tarixçəsi",
            "Ödəniş tapşırığının statuslarının dəyişikliyi: qəbul, yoxlama, göndərilmə, icra, rədd (yalnız əlavə olunur).",
            "payment_order",
            PAYMENT_STATUSES,
        ),
        Entity(
            "payment_message",
            "Ödəniş mesajı",
            "Ödəniş sistemlərinə göndərilən və onlardan alınan mesajlar (AZIPS, XÖHKS, SWIFT MT / ISO 20022): istiqamət, mesaj tipi, istinad, status.",
            rels=(Rel("payment_order", "mesajıdır", parent_card="0..1"),),
            attributes=(
                A("direction", "code", "İstiqamət.", values=("OUTBOUND", "INBOUND")),
                A("payment_system", "code", "Ödəniş sistemi.", values=PAYMENT_SYSTEMS),
                A("message_type", "code", "Mesaj tipi (MT103, pacs.008 və s.)."),
                A("message_reference", "code", "Mesajın sistemdəki istinadı."),
                A("exchanged_at", "timestamp", "Göndərilmə / qəbul anı."),
                A("status", "code", "Mesajın statusu.", values=("QUEUED", "SENT", "ACKNOWLEDGED", "REJECTED", "RECEIVED", "PROCESSED")),
                A("payload", "json", "Mesajın strukturlaşdırılmış məzmunu.", optional=True),
            ),
            uniques=(Unique(("payment_system", "direction", "message_reference")),),
        ),
        Entity(
            "payment_return",
            "Ödəniş qaytarılması",
            "Qaytarılmış və ya rədd edilmiş ödənişlər: səbəb kodu, qaytarılan məbləğ, tarix.",
            rels=(Rel("payment_order", "qaytarılmasıdır"),),
            attributes=(
                A("return_reason_code", "code", "Qaytarılma səbəbinin kodu."),
                A("return_reason", "text", "Səbəbin izahı.", optional=True),
                A("returned_amount", "amount", "Qaytarılan məbləğ."),
                A("return_date", "date", "Qaytarılma tarixi."),
            ),
            checks=(Check("amount_positive", "returned_amount > 0", "Məbləğ müsbət olmalıdır."),),
        ),
        Entity(
            "fx_deal",
            "Valyuta mübadiləsi",
            "Müştərinin hesabları arasında valyuta alqı-satqısı (konversiya): satılan və alınan məbləğ, tətbiq olunan məzənnə. "
            "Valyutalar hesablardan müəyyən olunur.",
            rels=(
                Rel("customer", "mübadiləsidir"),
                Rel("account", "satılan valyuta hesabıdır", fk="sell_account_id"),
                Rel("account", "alınan valyuta hesabıdır", fk="buy_account_id"),
                Rel("exchange_rate", "tətbiq olunan məzənnədir", parent_card="0..1"),
            ),
            attributes=(
                A("deal_number", "code", "Əqdin nömrəsi.", unique=True),
                A("sell_amount", "amount", "Satılan məbləğ."),
                A("buy_amount", "amount", "Alınan məbləğ."),
                A("applied_rate", "fx_rate", "Faktiki tətbiq olunan məzənnə (fərdi məzənnə ola bilər)."),
                A("deal_at", "timestamp", "Əqdin anı.", default="now()"),
                A("status", "code", "Status.", values=("EXECUTED", "CANCELLED")),
            ),
            checks=(
                Check("distinct_accounts", "sell_account_id <> buy_account_id", "Satış və alış hesabları fərqli olmalıdır."),
                Check("amounts_positive", "sell_amount > 0 AND buy_amount > 0 AND applied_rate > 0", "Məbləğlər və məzənnə müsbət olmalıdır."),
            ),
        ),
    ),
)
