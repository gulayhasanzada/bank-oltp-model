from bankmodel.meta import Attribute as A
from bankmodel.meta import Check, Domain, Entity, Rel, Unique

DOMAIN = Domain(
    schema="ledger",
    title="Baş kitab (sadələşdirilmiş)",
    desc=(
        "Əməliyyatların mühasibat uçotunda əks olunması üçün sadələşdirilmiş baş kitab: baş kitab hesabları, "
        "mühasibat dövrləri, yazılış qaydaları və ikili yazılışlar (debet = kredit). AMB hesablar planının tam iyerarxiyası "
        "modelləşdirilmir; hesablar valideyn hesab vasitəsilə qruplaşdırılır."
    ),
    entities=(
        Entity(
            "gl_account",
            "Baş kitab hesabı",
            "Balans və balansdankənar baş kitab hesabları; qrup hesabları və yazılış aparılan hesablar.",
            rels=(Rel("gl_account", "alt hesabıdır", parent_card="0..1", fk="parent_gl_account_id"),),
            attributes=(
                A("account_code", "code", "Hesabın kodu.", unique=True),
                A("name", "text", "Hesabın adı."),
                A("account_class", "code", "Hesab sinfi.", values=("ASSET", "LIABILITY", "EQUITY", "INCOME", "EXPENSE", "OFF_BALANCE")),
                A("normal_balance", "code", "Normal qalıq tərəfi.", values=("DEBIT", "CREDIT")),
                A("is_postable", "flag", "Bu hesaba yazılış aparıla bilər (qrup hesabı deyil).", default="true"),
                A("is_active", "flag", "Hesab aktivdir.", default="true"),
            ),
        ),
        Entity(
            "accounting_period",
            "Mühasibat dövrü",
            "Aylıq mühasibat dövrləri və onların statusu (açıq, bağlanır, bağlı). Bağlı dövrə yazılış aparılmır.",
            attributes=(
                A("period_code", "code", "Dövrün kodu (2026-10).", unique=True),
                A("start_date", "date", "Dövrün başlanğıcı."),
                A("end_date", "date", "Dövrün sonu."),
                A("status", "code", "Status.", values=("OPEN", "CLOSING", "CLOSED")),
                A("closed_at", "timestamp", "Bağlanma anı.", optional=True),
            ),
            checks=(Check("valid_period", "end_date >= start_date", "Dövrün sonu başlanğıcdan əvvəl ola bilməz."),),
        ),
        Entity(
            "posting_rule",
            "Yazılış qaydası",
            "Məhsul və əməliyyat növünə görə debet və kredit baş kitab hesablarının müəyyən edilməsi qaydası; "
            "məhsul göstərilməyibsə qayda bütün məhsullara aiddir.",
            rels=(
                Rel("transaction_type", "qaydasıdır"),
                Rel("product", "qaydasıdır", parent_card="0..1"),
                Rel("gl_account", "debet hesabıdır", fk="debit_gl_account_id"),
                Rel("gl_account", "kredit hesabıdır", fk="credit_gl_account_id"),
            ),
            attributes=(
                A("effective_from", "date", "Qüvvəyə minmə tarixi."),
                A("effective_to", "date", "Qüvvədən düşmə tarixi.", optional=True),
                A("description", "text", "Qaydanın izahı.", optional=True),
            ),
            uniques=(Unique(("transaction_type_id", "product_id", "effective_from"), nulls_not_distinct=True),),
            checks=(
                Check("distinct_accounts", "debit_gl_account_id <> credit_gl_account_id", "Debet və kredit hesabları fərqli olmalıdır."),
                Check("valid_period", "effective_to IS NULL OR effective_to >= effective_from", "Bitmə tarixi başlanğıcdan əvvəl ola bilməz."),
            ),
        ),
        Entity(
            "journal_entry",
            "Mühasibat yazılışı",
            "Mühasibat yazılışının başlığı: yazılış tarixi, dövr, mənbə hesab əməliyyatı, təsvir, status (qaralama/yazılıb/storno).",
            rels=(
                Rel("accounting_period", "dövrün yazılışıdır"),
                Rel("account_transaction", "mühasibat əksidir", parent_card="0..1"),
            ),
            attributes=(
                A("entry_number", "code", "Yazılışın nömrəsi.", unique=True),
                A("entry_date", "date", "Yazılış tarixi."),
                A("description", "text", "Təsvir."),
                A("status", "code", "Status.", values=("DRAFT", "POSTED", "REVERSED")),
                A("posted_at", "timestamp", "Yazılış anı.", optional=True),
            ),
            checks=(Check("posted_has_time", "status = 'DRAFT' OR posted_at IS NOT NULL", "Yazılmış yazılışın yazılış anı olmalıdır."),),
        ),
        Entity(
            "journal_entry_line",
            "Yazılış sətri",
            "Yazılışın debet və kredit sətirləri; hər yazılış üzrə AZN ekvivalentində debet və kredit cəmi bərabər olmalıdır "
            "(tətbiq səviyyəsində yazılış zamanı yoxlanılır). Yüksək həcmli cədvəldir, aylar üzrə bölmələnir.",
            rels=(
                Rel("journal_entry", "sətiridir", child_card="1..N"),
                Rel("gl_account", "hesabıdır"),
                Rel("currency", "valyutasıdır"),
                Rel("branch", "bölməsidir"),
            ),
            attributes=(
                A("entry_date", "date", "Yazılış tarixi (bölmə açarı)."),
                A("line_number", "count", "Sətrin sıra nömrəsi."),
                A("side", "code", "Debet və ya kredit.", values=("DEBIT", "CREDIT")),
                A("amount", "amount", "Sətrin valyutasında məbləğ."),
                A("amount_azn", "amount", "AZN ekvivalenti (AMB rəsmi məzənnəsi ilə)."),
            ),
            uniques=(Unique(("journal_entry_id", "line_number", "entry_date")),),
            checks=(Check("amounts_positive", "amount > 0 AND amount_azn > 0", "Məbləğlər müsbət olmalıdır."),),
            partition_by="entry_date",
        ),
    ),
)
