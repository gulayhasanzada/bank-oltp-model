from bankmodel.meta import Attribute as A
from bankmodel.meta import Check, Domain, Entity, Index, Rel, Unique, status_history

ACCOUNT_STATUSES = ("PENDING", "ACTIVE", "DORMANT", "FROZEN", "CLOSED")
VALID_PERIOD = Check("valid_period", "effective_to IS NULL OR effective_to >= effective_from", "Bitmə tarixi başlanğıcdan əvvəl ola bilməz.")

DOMAIN = Domain(
    schema="account",
    title="Hesablar və əməliyyatlar",
    desc=(
        "Müştəri hesabları (cari, əmanət, müddətli depozit, kart hesabı), hesab sahibləri, qalıqlar, "
        "hesab əməliyyatları, bloklamalar, komissiyalar, faiz hesablanması, limitlər, daimi tapşırıqlar və çıxarışlar. "
        "Hesablar çoxvalyutalıdır: hər hesab bir valyutada açılır, müştərinin müxtəlif valyutalarda hesabları ola bilər."
    ),
    entities=(
        Entity(
            "account",
            "Hesab",
            "Müştəri hesabı: cari, əmanət, müddətli depozit və ya kart hesabı. AZ IBAN, valyuta, məhsul, xidmət filialı, status.",
            rels=(
                Rel("customer", "hesabıdır"),
                Rel("product", "məhsuludur"),
                Rel("currency", "valyutasıdır"),
                Rel("branch", "hesabın filialıdır"),
            ),
            attributes=(
                A("account_number", "code", "Bankdaxili hesab nömrəsi (IBAN-ın 20 simvollu hissəsi).", unique=True),
                A("iban", "iban", "AZ IBAN — 28 simvol: AZ + 2 yoxlama rəqəmi + 4 simvollu bank kodu + 20 simvollu hesab nömrəsi.", unique=True),
                A("account_type", "code", "Hesabın növü.", values=("CURRENT", "SAVINGS", "TERM_DEPOSIT", "CARD")),
                A("account_name", "text", "Müştərinin hesaba verdiyi ad.", optional=True),
                A("opened_date", "date", "Açılış tarixi."),
                A("closed_date", "date", "Bağlanma tarixi.", optional=True),
                A("is_joint", "flag", "Birgə hesabdır (bir neçə sahib).", default="false"),
                A("status", "code", "Hesabın statusu.", values=ACCOUNT_STATUSES),
            ),
            checks=(
                Check("iban_format", "iban ~ '^AZ[0-9]{2}[A-Z]{4}[A-Z0-9]{20}$'", "IBAN Azərbaycan formatına (28 simvol) uyğun olmalıdır."),
                Check("closed_consistency", "(status = 'CLOSED') = (closed_date IS NOT NULL)", "Bağlanma tarixi yalnız bağlı hesabda və mütləq olmalıdır."),
            ),
        ),
        Entity(
            "account_holder",
            "Hesab sahibi / səlahiyyətli şəxs",
            "Hesab ilə tərəf arasında rol: əsas sahib, birgə sahib, səlahiyyətli imza sahibi, etibarnamə üzrə nümayəndə; qüvvədə olma tarixləri ilə.",
            rels=(
                Rel("account", "sahibləridir", child_card="1..N"),
                Rel("party", "hesab üzrə roludur"),
            ),
            attributes=(
                A(
                    "holder_role",
                    "code",
                    "Tərəfin hesab üzrə rolu.",
                    values=("PRIMARY_OWNER", "JOINT_OWNER", "AUTHORIZED_SIGNATORY", "POWER_OF_ATTORNEY", "TRUSTEE"),
                ),
                A("signing_rule", "code", "İmza qaydası: tək, istənilən iki, hamısı birlikdə.", optional=True, values=("SOLE", "ANY_TWO", "ALL")),
                A("power_of_attorney_number", "short_text", "Etibarnamənin nömrəsi.", optional=True),
                A("effective_from", "date", "Rolun başlanğıcı."),
                A("effective_to", "date", "Rolun sonu.", optional=True),
            ),
            uniques=(Unique(("account_id", "party_id", "holder_role", "effective_from")),),
            checks=(VALID_PERIOD,),
        ),
        Entity(
            "account_balance",
            "Hesab qalığı (cari)",
            "Hesabın cari qalıqları: mühasibat qalığı, istifadəyə yararlı qalıq, bloklanmış məbləğ. Hər əməliyyatla eyni tranzaksiyada yenilənir "
            "(performans üçün idarə olunan denormallaşdırma; mənbə — hesab əməliyyatları və bloklamalar).",
            rels=(Rel("account", "cari qalığıdır", child_card="1"),),
            attributes=(
                A("ledger_balance", "amount", "Mühasibat qalığı.", default="0"),
                A("blocked_amount", "amount", "Aktiv bloklamaların cəmi.", default="0"),
                A("available_balance", "amount", "İstifadəyə yararlı qalıq (qalıq − bloklama + overdraft limiti).", default="0"),
                A("last_transaction_at", "timestamp", "Son əməliyyatın anı.", optional=True),
            ),
            checks=(Check("blocked_non_negative", "blocked_amount >= 0", "Bloklanmış məbləğ mənfi ola bilməz."),),
        ),
        Entity(
            "account_balance_daily",
            "Gün sonu qalığı",
            "Hər iş günü sonunda hesab qalığının snapşotu; faiz hesablanması, çıxarış və hesabatlar üçün.",
            rels=(Rel("account", "gün sonu qalığıdır"),),
            attributes=(
                A("balance_date", "date", "Bank günü."),
                A("ledger_balance", "amount", "Gün sonu mühasibat qalığı."),
                A("available_balance", "amount", "Gün sonu istifadəyə yararlı qalıq."),
                A("debit_turnover", "amount", "Gün ərzində debet dövriyyəsi.", default="0"),
                A("credit_turnover", "amount", "Gün ərzində kredit dövriyyəsi.", default="0"),
            ),
            uniques=(Unique(("account_id", "balance_date")),),
        ),
        Entity(
            "account_transaction",
            "Hesab əməliyyatı",
            "Hesab üzrə mədaxil/məxaric yazılışı: məbləğ, əməliyyat və dəyər tarixi, mənbə (ödəniş, kart, kredit), storno əlaqəsi. "
            "Yüksək həcmli cədvəldir, aylar üzrə bölmələnir. Yazılış dəyişdirilmir — düzəliş storno ilə edilir.",
            rels=(
                Rel("account", "əməliyyatıdır"),
                Rel("transaction_type", "növüdür"),
                Rel("channel", "kanalıdır", parent_card="0..1"),
                Rel("currency", "orijinal valyutadır", parent_card="0..1", fk="original_currency_id"),
                Rel("payment_order", "nəticəsidir", parent_card="0..1"),
                Rel("card_transaction", "nəticəsidir", parent_card="0..1"),
                Rel("loan_disbursement", "nəticəsidir", parent_card="0..1"),
                Rel("loan_repayment", "nəticəsidir", parent_card="0..1"),
                Rel(
                    "account_transaction",
                    "stornosudur",
                    parent_card="0..1",
                    child_card="0..1",
                    fk="reversed_account_transaction_id",
                ),
            ),
            attributes=(
                A("transaction_date", "date", "Əməliyyatın bank günü (bölmə açarı)."),
                A("value_date", "date", "Dəyər tarixi."),
                A("posted_at", "timestamp", "Hesabda əks olunduğu an.", default="now()"),
                A("direction", "code", "İstiqamət: məxaric (debet) və ya mədaxil (kredit).", values=("DEBIT", "CREDIT")),
                A("amount", "amount", "Hesab valyutasında məbləğ (həmişə müsbət; işarə istiqamətlə verilir)."),
                A("original_amount", "amount", "Orijinal valyutada məbləğ (konversiya olduqda).", optional=True),
                A("balance_after", "amount", "Əməliyyatdan sonrakı mühasibat qalığı."),
                A("reference_number", "code", "Əməliyyatın istinad nömrəsi."),
                A("narrative", "text", "Təyinat / təsvir.", optional=True),
                A("status", "code", "Status.", default="'POSTED'", values=("POSTED", "REVERSED")),
            ),
            checks=(
                Check("amount_positive", "amount > 0", "Məbləğ müsbət olmalıdır."),
                Check(
                    "single_source",
                    "num_nonnulls(payment_order_id, card_transaction_id, loan_disbursement_id, loan_repayment_id) <= 1",
                    "Əməliyyatın ən çoxu bir mənbəyi ola bilər (ödəniş, kart əməliyyatı, kreditin verilməsi və ya ödənişi).",
                ),
                Check(
                    "original_pair",
                    "(original_currency_id IS NULL) = (original_amount IS NULL)",
                    "Orijinal valyuta və orijinal məbləğ birlikdə göstərilməlidir.",
                ),
            ),
            indexes=(Index(("account_id", "transaction_date")), Index(("reference_number",))),
            partition_by="transaction_date",
        ),
        Entity(
            "hold",
            "Bloklama",
            "Hesab vəsaitlərinin bloklanması: kart avtorizasiyası, məhkəmə qərarı, vergi orqanının sərəncamı, girov; bloklama və azad edilmə tarixləri ilə.",
            rels=(
                Rel("account", "bloklamasıdır"),
                Rel("card_authorization", "bloklamaya səbəb olub", parent_card="0..1", child_card="0..1"),
            ),
            attributes=(
                A(
                    "hold_type",
                    "code",
                    "Bloklamanın növü.",
                    values=("CARD_AUTHORIZATION", "COURT_ORDER", "TAX_AUTHORITY", "COLLATERAL", "BANK_INTERNAL"),
                ),
                A("amount", "amount", "Bloklanmış məbləğ (hesab valyutasında)."),
                A("placed_at", "timestamp", "Bloklama anı.", default="now()"),
                A("expires_at", "timestamp", "Avtomatik azad olunma anı.", optional=True),
                A("released_at", "timestamp", "Faktiki azad olunma anı.", optional=True),
                A("legal_document_reference", "text", "Qərarın / sərəncamın nömrəsi və tarixi.", optional=True),
                A("reason", "text", "Səbəb.", optional=True),
                A("status", "code", "Status.", values=("ACTIVE", "RELEASED", "EXPIRED", "CAPTURED")),
            ),
            checks=(
                Check("amount_positive", "amount > 0", "Məbləğ müsbət olmalıdır."),
                Check(
                    "card_hold_source",
                    "(hold_type = 'CARD_AUTHORIZATION') = (card_authorization_id IS NOT NULL)",
                    "Kart bloklaması avtorizasiyaya, digər bloklamalar isə avtorizasiyasız olmalıdır.",
                ),
            ),
            indexes=(Index(("account_id",), where="status = 'ACTIVE'"),),
        ),
        Entity(
            "account_fee_charge",
            "Tutulmuş komissiya",
            "Hesabdan tutulan, güzəşt edilən və ya geri qaytarılan komissiyalar.",
            rels=(
                Rel("account", "komissiyasıdır"),
                Rel("fee_type", "növüdür"),
                Rel("account_transaction", "tutulma yazılışıdır", parent_card="0..1", child_card="0..1"),
            ),
            attributes=(
                A("charge_date", "date", "Hesablanma tarixi."),
                A("amount", "amount", "Komissiya məbləği."),
                A("waiver_reason", "text", "Güzəştin səbəbi.", optional=True),
                A("status", "code", "Status.", values=("PENDING", "CHARGED", "WAIVED", "REFUNDED")),
            ),
            checks=(Check("amount_non_negative", "amount >= 0", "Məbləğ mənfi ola bilməz."),),
        ),
        Entity(
            "interest_accrual",
            "Faiz hesablanması",
            "Hesab üzrə gündəlik faiz hesablanması, kapitallaşma və ödənilmə; ödəmə mənbəyində tutulan vergi ilə. "
            "Gündəlik faiz = qalıq × illik dərəcə / 365 (actual/365).",
            rels=(Rel("account", "hesablanmış faizidir"),),
            attributes=(
                A("accrual_date", "date", "Hesablama günü."),
                A("balance_base", "amount", "Faizin hesablandığı qalıq."),
                A("annual_rate", "rate", "Tətbiq olunan illik dərəcə."),
                A("accrued_amount", "amount", "Hesablanmış faiz."),
                A("withholding_tax_amount", "amount", "Ödəmə mənbəyində tutulan vergi.", default="0"),
                A("is_capitalized", "flag", "Faiz hesaba əlavə edilib (kapitallaşıb).", default="false"),
            ),
            uniques=(Unique(("account_id", "accrual_date")),),
        ),
        Entity(
            "account_interest_rate",
            "Hesab faiz dərəcəsi",
            "Hesaba tətbiq olunan faiz dərəcəsi, qüvvədə olma tarixləri ilə; məhsulun standart dərəcəsi və ya fərdi dərəcə.",
            rels=(
                Rel("account", "faiz dərəcəsidir"),
                Rel("product_interest_rate", "əsas götürülüb", parent_card="0..1"),
            ),
            attributes=(
                A("annual_rate", "rate", "İllik faiz dərəcəsi."),
                A("effective_from", "date", "Qüvvəyə minmə tarixi."),
                A("effective_to", "date", "Qüvvədən düşmə tarixi.", optional=True),
            ),
            uniques=(Unique(("account_id", "effective_from")),),
            checks=(VALID_PERIOD, Check("rate_non_negative", "annual_rate >= 0", "Faiz dərəcəsi mənfi ola bilməz.")),
        ),
        Entity(
            "term_deposit_term",
            "Müddətli depozit şərtləri",
            "Müddətli depozitin şərtləri: müddət, bitmə tarixi, avtomatik uzadılma, faizin ödənilmə qaydası, vaxtından əvvəl çıxarma şərtləri.",
            rels=(
                Rel("account", "depozit şərtləridir", child_card="0..1"),
                Rel("account", "faiz ödəniş hesabıdır", parent_card="0..1", fk="payout_account_id"),
            ),
            attributes=(
                A("term_months", "count", "Müddət (ay)."),
                A("start_date", "date", "Başlama tarixi."),
                A("maturity_date", "date", "Bitmə tarixi."),
                A("interest_payment_frequency", "code", "Faizin ödənilmə tezliyi.", values=("MONTHLY", "QUARTERLY", "AT_MATURITY")),
                A("auto_rollover", "flag", "Müddət bitdikdə avtomatik uzadılır.", default="false"),
                A("allows_top_up", "flag", "Əlavə vəsait qəbul edilir.", default="false"),
                A("allows_partial_withdrawal", "flag", "Qismən çıxarışa icazə verilir.", default="false"),
                A("early_withdrawal_rate", "rate", "Vaxtından əvvəl çıxarışda tətbiq olunan dərəcə.", optional=True),
            ),
            checks=(
                Check("maturity_after_start", "maturity_date > start_date", "Bitmə tarixi başlama tarixindən sonra olmalıdır."),
                Check("term_positive", "term_months > 0", "Müddət müsbət olmalıdır."),
            ),
        ),
        Entity(
            "overdraft_facility",
            "Overdraft",
            "Cari hesab üzrə overdraft limiti və şərtləri: limit, faiz dərəcəsi, qüvvədə olma tarixləri.",
            rels=(Rel("account", "overdraftıdır"),),
            attributes=(
                A("limit_amount", "amount", "Overdraft limiti."),
                A("annual_rate", "rate", "İstifadə olunan məbləğə illik faiz dərəcəsi."),
                A("effective_from", "date", "Qüvvəyə minmə tarixi."),
                A("effective_to", "date", "Qüvvədən düşmə tarixi.", optional=True),
                A("status", "code", "Status.", values=("ACTIVE", "SUSPENDED", "CLOSED")),
            ),
            checks=(VALID_PERIOD, Check("limit_positive", "limit_amount > 0", "Limit müsbət olmalıdır.")),
        ),
        Entity(
            "standing_order",
            "Daimi tapşırıq",
            "Müştərinin müntəzəm köçürmə tapşırığı: məbləğ, tezlik, növbəti icra tarixi, başlama və bitmə tarixləri.",
            rels=(
                Rel("account", "debet hesabıdır", fk="debit_account_id"),
                Rel("beneficiary", "alanıdır"),
            ),
            attributes=(
                A("amount", "amount", "Köçürmə məbləği (debet hesabının valyutasında)."),
                A("frequency", "code", "Tezlik.", values=("WEEKLY", "MONTHLY", "QUARTERLY")),
                A("execution_day", "count", "İcra günü (ayın günü və ya həftənin günü).", optional=True),
                A("start_date", "date", "Başlama tarixi."),
                A("end_date", "date", "Bitmə tarixi.", optional=True),
                A("next_execution_date", "date", "Növbəti icra tarixi.", optional=True),
                A("purpose", "text", "Ödənişin təyinatı."),
                A("status", "code", "Status.", values=("ACTIVE", "PAUSED", "CANCELLED", "COMPLETED")),
            ),
            checks=(
                Check("amount_positive", "amount > 0", "Məbləğ müsbət olmalıdır."),
                Check("valid_period", "end_date IS NULL OR end_date >= start_date", "Bitmə tarixi başlanğıcdan əvvəl ola bilməz."),
            ),
            indexes=(Index(("next_execution_date",), where="status = 'ACTIVE'"),),
        ),
        Entity(
            "account_limit",
            "Hesab limiti",
            "Hesab üzrə əməliyyat limitləri: gündəlik və aylıq məxaric, tək əməliyyat, kanal üzrə məhdudiyyətlər.",
            rels=(
                Rel("account", "limitidir"),
                Rel("channel", "limitin kanalıdır", parent_card="0..1"),
            ),
            attributes=(
                A("limit_type", "code", "Limitin növü.", values=("DAILY_DEBIT", "MONTHLY_DEBIT", "SINGLE_TRANSACTION")),
                A("limit_amount", "amount", "Limit məbləği."),
                A("effective_from", "date", "Qüvvəyə minmə tarixi."),
                A("effective_to", "date", "Qüvvədən düşmə tarixi.", optional=True),
            ),
            uniques=(Unique(("account_id", "channel_id", "limit_type", "effective_from"), nulls_not_distinct=True),),
            checks=(VALID_PERIOD, Check("limit_non_negative", "limit_amount >= 0", "Limit mənfi ola bilməz.")),
        ),
        Entity(
            "statement",
            "Hesabdan çıxarış",
            "Dövr üzrə hesab çıxarışı: açılış və bağlanış qalığı, debet və kredit dövriyyələri, çatdırılma kanalı.",
            rels=(Rel("account", "çıxarışıdır"),),
            attributes=(
                A("period_start", "date", "Dövrün başlanğıcı."),
                A("period_end", "date", "Dövrün sonu."),
                A("opening_balance", "amount", "Açılış qalığı."),
                A("closing_balance", "amount", "Bağlanış qalığı."),
                A("total_debit", "amount", "Debet dövriyyəsi."),
                A("total_credit", "amount", "Kredit dövriyyəsi."),
                A("generated_at", "timestamp", "Hazırlanma anı.", default="now()"),
                A("delivery_channel", "code", "Çatdırılma kanalı.", values=("EMAIL", "INTERNET_BANKING", "BRANCH", "POST")),
            ),
            uniques=(Unique(("account_id", "period_start", "period_end")),),
            checks=(Check("valid_period", "period_end >= period_start", "Dövrün sonu başlanğıcdan əvvəl ola bilməz."),),
        ),
        status_history(
            "account_status_history",
            "Hesab statusu tarixçəsi",
            "Hesab statusunun dəyişiklikləri: açılış, dondurma, passiv (dormant), bağlanma; səbəb və icraçı ilə (yalnız əlavə olunur).",
            "account",
            ACCOUNT_STATUSES,
        ),
    ),
)
