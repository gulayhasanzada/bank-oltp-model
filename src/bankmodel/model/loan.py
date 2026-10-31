from bankmodel.meta import Attribute as A
from bankmodel.meta import Check, Domain, Entity, Index, Rel, Unique, exactly_one, status_history

LOAN_STATUSES = ("APPROVED", "ACTIVE", "OVERDUE", "RESTRUCTURED", "WRITTEN_OFF", "CLOSED")
VALID_PERIOD = Check("valid_period", "effective_to IS NULL OR effective_to >= effective_from", "Bitmə tarixi başlanğıcdan əvvəl ola bilməz.")
LOAN_OR_FACILITY = Check(
    "loan_or_facility",
    exactly_one("loan_id", "credit_facility_id"),
    "Ya kreditə, ya da kredit xəttinə (yalnız birinə) aid olmalıdır.",
)

DOMAIN = Domain(
    schema="loan",
    title="Kreditlər",
    desc=(
        "Kredit həyat dövrü: müraciət, Kredit Bürosu yoxlaması, kredit xətti (biznes), kredit müqaviləsi "
        "(istehlak, ipoteka, biznes krediti), kreditin verilməsi, ödəniş qrafiki, ödənişlər və onların bölüşdürülməsi, "
        "dəbbə (gündəlik dərəcə ilə cərimə), girov və zaminlik, kovenantlar, restrukturizasiya. "
        "Faizlər faktiki/365 (actual/365) bazası ilə hesablanır."
    ),
    entities=(
        Entity(
            "credit_application",
            "Kredit müraciəti",
            "Kredit müraciəti: məhsul, istənilən məbləğ, valyuta və müddət, məqsəd, qərar, təsdiq edilmiş şərtlər.",
            rels=(
                Rel("customer", "müraciətidir"),
                Rel("product", "istənilən məhsuldur"),
                Rel("currency", "istənilən valyutadır"),
                Rel("branch", "qəbul edən filialdır"),
                Rel("employee", "kredit mütəxəssisidir", parent_card="0..1", fk="loan_officer_id"),
            ),
            attributes=(
                A("application_number", "code", "Müraciətin nömrəsi.", unique=True),
                A("requested_amount", "amount", "İstənilən məbləğ."),
                A("requested_term_months", "count", "İstənilən müddət (ay)."),
                A("purpose", "text", "Kreditin məqsədi."),
                A("submitted_at", "timestamp", "Müraciət anı.", default="now()"),
                A("decision_at", "timestamp", "Qərar anı.", optional=True),
                A("approved_amount", "amount", "Təsdiq edilmiş məbləğ.", optional=True),
                A("approved_term_months", "count", "Təsdiq edilmiş müddət (ay).", optional=True),
                A("approved_rate", "rate", "Təsdiq edilmiş illik faiz dərəcəsi.", optional=True),
                A("rejection_reason", "text", "İmtinanın səbəbi.", optional=True),
                A(
                    "status",
                    "code",
                    "Müraciətin statusu.",
                    values=("DRAFT", "SUBMITTED", "UNDER_REVIEW", "APPROVED", "REJECTED", "CANCELLED", "CONTRACTED"),
                ),
            ),
            checks=(
                Check("amount_positive", "requested_amount > 0 AND requested_term_months > 0", "Məbləğ və müddət müsbət olmalıdır."),
                Check(
                    "approved_terms",
                    "status NOT IN ('APPROVED', 'CONTRACTED') OR (approved_amount IS NOT NULL AND approved_term_months IS NOT NULL AND approved_rate IS NOT NULL)",
                    "Təsdiq edilmiş müraciətdə təsdiq olunan şərtlər göstərilməlidir.",
                ),
            ),
        ),
        Entity(
            "credit_bureau_check",
            "Kredit Bürosu sorğusu",
            "Azərbaycan Kredit Bürosuna sorğu və nəticəsi: kredit skoru, mövcud öhdəliklər, gecikmələr; tərəfin razılığı əsasında.",
            rels=(
                Rel("party", "yoxlanılan tərəfdir"),
                Rel("credit_application", "sorğusudur", parent_card="0..1"),
            ),
            attributes=(
                A("requested_at", "timestamp", "Sorğu anı.", default="now()"),
                A("bureau_reference", "code", "Büronun hesabat istinadı.", optional=True),
                A("credit_score", "count", "Kredit skoru.", optional=True),
                A("total_outstanding_debt", "amount", "Bütün banklar üzrə qalıq borc (AZN).", optional=True),
                A("active_loan_count", "count", "Aktiv kreditlərin sayı.", optional=True),
                A("max_days_past_due", "count", "Maksimal gecikmə günləri.", optional=True),
                A("result", "code", "Sorğunun nəticəsi.", values=("SUCCESS", "NO_HIT", "ERROR")),
                A("report", "json", "Büronun hesabatı (strukturlaşdırılmış).", optional=True),
            ),
        ),
        Entity(
            "credit_facility",
            "Kredit xətti",
            "Biznes müştəriləri üçün kredit xətti (bərpa olunan və ya olunmayan): ümumi limit, valyuta, istifadə müddəti. "
            "Xətt üzrə bir neçə kredit (tranş) verilə bilər; istifadə olunmuş məbləğ tranşların qalıqlarının cəmidir.",
            rels=(
                Rel("customer", "kredit xəttidir"),
                Rel("credit_application", "əsasında açılıb", parent_card="0..1", child_card="0..1"),
                Rel("currency", "valyutasıdır"),
            ),
            attributes=(
                A("facility_number", "code", "Kredit xətti müqaviləsinin nömrəsi.", unique=True),
                A("facility_type", "code", "Bərpa olunan və ya olunmayan.", values=("REVOLVING", "NON_REVOLVING")),
                A("limit_amount", "amount", "Ümumi limit."),
                A("available_from", "date", "İstifadənin başlanğıcı."),
                A("available_until", "date", "Yeni tranş götürmək üçün son tarix."),
                A("maturity_date", "date", "Xəttin son ödəniş tarixi."),
                A("commitment_fee_rate", "rate", "İstifadə olunmamış limitə illik komissiya dərəcəsi.", optional=True),
                A("status", "code", "Status.", values=("ACTIVE", "SUSPENDED", "EXPIRED", "CLOSED")),
            ),
            checks=(
                Check("limit_positive", "limit_amount > 0", "Limit müsbət olmalıdır."),
                Check("date_order", "available_from <= available_until AND available_until <= maturity_date", "Tarixlər ardıcıl olmalıdır."),
            ),
        ),
        Entity(
            "loan",
            "Kredit",
            "Kredit müqaviləsi və kredit hesabı: növ (istehlak, ipoteka, biznes, xətt üzrə tranş), məbləğ, valyuta, faiz dərəcəsi, müddət, "
            "ödəniş metodu (annuitet/diferensial), dəbbə şərtləri, qalıq borc, gecikmə günləri, status. "
            "Qalıq borc və gecikmə günləri əməliyyatlarla yenilənən idarə olunan denormallaşdırmadır.",
            rels=(
                Rel("customer", "kreditidir"),
                Rel("product", "məhsuludur"),
                Rel("currency", "valyutasıdır"),
                Rel("credit_application", "əsasında verilib", parent_card="0..1", child_card="0..1"),
                Rel("credit_facility", "tranşıdır", parent_card="0..1"),
                Rel("account", "hesablaşma hesabıdır", fk="settlement_account_id"),
                Rel("branch", "kreditin filialıdır"),
            ),
            attributes=(
                A("loan_number", "code", "Kredit müqaviləsinin nömrəsi.", unique=True),
                A("loan_type", "code", "Kreditin növü.", values=("CONSUMER", "MORTGAGE", "BUSINESS", "FACILITY_TRANCHE")),
                A("principal_amount", "amount", "Kreditin məbləği."),
                A("annual_rate", "rate", "İllik faiz dərəcəsi (actual/365)."),
                A("rate_type", "code", "Sabit və ya üzən dərəcə.", values=("FIXED", "FLOATING")),
                A("term_months", "count", "Müddət (ay)."),
                A("contract_date", "date", "Müqavilə tarixi."),
                A("start_date", "date", "Faiz hesablanmasının başlanğıcı."),
                A("maturity_date", "date", "Son ödəniş tarixi."),
                A("repayment_method", "code", "Ödəniş metodu.", values=("ANNUITY", "DIFFERENTIATED", "BULLET")),
                A("payment_day", "count", "Aylıq ödəniş günü (1–28)."),
                A("penalty_daily_rate", "rate", "Dəbbənin gündəlik dərəcəsi (0.001000 = gündə 0.1%)."),
                A(
                    "penalty_base",
                    "code",
                    "Dəbbənin hesablandığı baza (müqavilə ilə müəyyən olunur): gecikmiş əsas borc və ya gecikmiş əsas borc + faiz.",
                    values=("OVERDUE_PRINCIPAL", "OVERDUE_PRINCIPAL_AND_INTEREST"),
                ),
                A("outstanding_principal", "amount", "Qalıq əsas borc."),
                A("days_past_due", "count", "Cari gecikmə günləri.", default="0"),
                A("status", "code", "Kreditin statusu.", values=LOAN_STATUSES),
            ),
            checks=(
                Check("amounts_valid", "principal_amount > 0 AND outstanding_principal >= 0 AND outstanding_principal <= principal_amount", "Məbləğ müsbət, qalıq borc isə 0 ilə kredit məbləği arasında olmalıdır."),
                Check("date_order", "contract_date <= start_date AND start_date < maturity_date", "Tarixlər ardıcıl olmalıdır."),
                Check("payment_day_range", "payment_day BETWEEN 1 AND 28", "Ödəniş günü 1–28 arasında olmalıdır."),
                Check("tranche_has_facility", "(loan_type = 'FACILITY_TRANCHE') = (credit_facility_id IS NOT NULL)", "Tranş kredit xəttinə, digər kreditlər isə xəttsiz olmalıdır."),
                Check("rates_non_negative", "annual_rate >= 0 AND penalty_daily_rate >= 0", "Dərəcələr mənfi ola bilməz."),
            ),
            indexes=(Index(("status", "days_past_due"), where="days_past_due > 0"),),
        ),
        Entity(
            "loan_disbursement",
            "Kreditin verilməsi",
            "Kredit məbləğinin (və ya onun bir hissəsinin) müştəri hesabına köçürülməsi.",
            rels=(
                Rel("loan", "verilməsidir", child_card="1..N"),
                Rel("account", "köçürüldüyü hesabdır", fk="target_account_id"),
            ),
            attributes=(
                A("disbursement_date", "date", "Verilmə tarixi."),
                A("amount", "amount", "Verilən məbləğ."),
                A("status", "code", "Status.", values=("PENDING", "COMPLETED", "CANCELLED")),
            ),
            checks=(Check("amount_positive", "amount > 0", "Məbləğ müsbət olmalıdır."),),
        ),
        Entity(
            "repayment_schedule",
            "Ödəniş qrafiki",
            "Kreditin ödəniş qrafiki: hər ödəniş tarixi üzrə əsas borc, faiz və komissiya məbləğləri, ödənilmiş hissələr. "
            "Restrukturizasiya zamanı yeni qrafik versiyası yaradılır, köhnə sətirlər SUPERSEDED olur.",
            rels=(Rel("loan", "ödəniş qrafikidir", child_card="1..N"),),
            attributes=(
                A("schedule_version", "count", "Qrafikin versiyası.", default="1"),
                A("installment_number", "count", "Ödənişin sıra nömrəsi."),
                A("due_date", "date", "Ödəniş tarixi."),
                A("principal_due", "amount", "Ödənilməli əsas borc."),
                A("interest_due", "amount", "Ödənilməli faiz."),
                A("fee_due", "amount", "Ödənilməli komissiya.", default="0"),
                A("principal_paid", "amount", "Ödənilmiş əsas borc.", default="0"),
                A("interest_paid", "amount", "Ödənilmiş faiz.", default="0"),
                A("fee_paid", "amount", "Ödənilmiş komissiya.", default="0"),
                A("status", "code", "Status.", values=("PENDING", "PARTIALLY_PAID", "PAID", "OVERDUE", "SUPERSEDED")),
            ),
            uniques=(Unique(("loan_id", "schedule_version", "installment_number")),),
            checks=(
                Check("paid_le_due", "principal_paid <= principal_due AND interest_paid <= interest_due AND fee_paid <= fee_due", "Ödənilmiş məbləğ ödənilməli məbləğdən çox ola bilməz."),
                Check("amounts_non_negative", "principal_due >= 0 AND interest_due >= 0 AND fee_due >= 0", "Məbləğlər mənfi ola bilməz."),
            ),
            indexes=(Index(("due_date",), where="status IN ('PENDING', 'PARTIALLY_PAID', 'OVERDUE')"),),
        ),
        Entity(
            "loan_repayment",
            "Kredit ödənişi",
            "Müştərinin kredit üzrə etdiyi ödəniş: məbləğ, tarix, mənbə hesab, vaxtından əvvəl ödəniş əlaməti.",
            rels=(
                Rel("loan", "ödənişidir"),
                Rel("account", "mənbə hesabdır", parent_card="0..1", fk="source_account_id"),
            ),
            attributes=(
                A("payment_date", "date", "Ödəniş tarixi."),
                A("value_date", "date", "Dəyər tarixi."),
                A("amount", "amount", "Ödənilən məbləğ (kredit valyutasında)."),
                A("is_early_repayment", "flag", "Vaxtından əvvəl ödənişdir.", default="false"),
                A("status", "code", "Status.", values=("POSTED", "REVERSED")),
            ),
            checks=(Check("amount_positive", "amount > 0", "Məbləğ müsbət olmalıdır."),),
        ),
        Entity(
            "repayment_allocation",
            "Ödənişin bölüşdürülməsi",
            "Ödənişin qrafik üzrə ödənişlərə və komponentlərə bölüşdürülməsi. Növbəlilik: dəbbə → faiz → əsas borc → komissiya.",
            rels=(
                Rel("loan_repayment", "bölüşdürülməsidir", child_card="1..N"),
                Rel("repayment_schedule", "örtülən ödənişdir", parent_card="0..1"),
            ),
            attributes=(
                A("component", "code", "Komponent.", values=("PENALTY", "INTEREST", "PRINCIPAL", "FEE")),
                A("amount", "amount", "Bu komponentə yönəldilən məbləğ."),
            ),
            checks=(Check("amount_positive", "amount > 0", "Məbləğ müsbət olmalıdır."),),
        ),
        Entity(
            "loan_penalty_charge",
            "Dəbbə (cərimə)",
            "Gecikmiş qrafik ödənişinə görə hər gün hesablanan dəbbə: gecikmiş məbləğ (kreditin dəbbə bazasına görə) × gündəlik dərəcə.",
            rels=(Rel("repayment_schedule", "gecikmiş ödənişdir"),),
            attributes=(
                A("penalty_date", "date", "Hesablama günü."),
                A("overdue_amount", "amount", "Həmin gün gecikmiş məbləğ (dəbbə bazası)."),
                A("daily_rate", "rate", "Tətbiq olunan gündəlik dərəcə."),
                A("penalty_amount", "amount", "Hesablanmış dəbbə."),
                A("paid_amount", "amount", "Ödənilmiş hissə.", default="0"),
                A("status", "code", "Status.", values=("ACCRUED", "PAID", "WAIVED")),
            ),
            uniques=(Unique(("repayment_schedule_id", "penalty_date")),),
            checks=(Check("amounts_valid", "overdue_amount > 0 AND penalty_amount >= 0 AND paid_amount <= penalty_amount", "Məbləğlər düzgün olmalıdır."),),
        ),
        Entity(
            "collateral",
            "Girov",
            "Girov predmeti: növ, təsvir, mülkiyyətçi, reyestr qeydiyyatı (daşınmaz əmlak çıxarışı, nəqliyyat vasitəsinin qeydiyyatı), "
            "girov qoyulmuş depozit hesabı.",
            rels=(
                Rel("collateral_type", "növüdür"),
                Rel("party", "mülkiyyətçisidir", fk="owner_party_id"),
                Rel("currency", "dəyərin valyutasıdır"),
                Rel("account", "girov qoyulmuş depozitdir", parent_card="0..1", fk="pledged_account_id"),
            ),
            attributes=(
                A("description", "long_text", "Girov predmetinin təsviri."),
                A("registry_number", "short_text", "Dövlət reyestrində qeydiyyat nömrəsi.", optional=True),
                A("registry_authority", "text", "Reyestri aparan orqan.", optional=True),
                A("location_address", "text", "Yerləşmə ünvanı.", optional=True),
                A("initial_value", "amount", "İlkin razılaşdırılmış dəyər."),
                A("status", "code", "Status.", values=("ACTIVE", "RELEASED", "FORECLOSED")),
            ),
            checks=(Check("value_positive", "initial_value > 0", "Dəyər müsbət olmalıdır."),),
        ),
        Entity(
            "collateral_valuation",
            "Girovun qiymətləndirilməsi",
            "Girovun bazar və likvid dəyərinin qiymətləndirilməsi: tarix, qiymətləndirici, məbləğ (girovun valyutasında).",
            rels=(Rel("collateral", "qiymətləndirilməsidir"),),
            attributes=(
                A("valuation_date", "date", "Qiymətləndirmə tarixi."),
                A("market_value", "amount", "Bazar dəyəri."),
                A("liquidation_value", "amount", "Likvid (məcburi satış) dəyəri."),
                A("valuation_method", "code", "Qiymətləndirmə üsulu.", values=("MARKET", "INCOME", "COST")),
                A("valuer_name", "text", "Qiymətləndirici (şirkət və ya şəxs)."),
                A("next_valuation_date", "date", "Növbəti qiymətləndirmə tarixi.", optional=True),
            ),
            uniques=(Unique(("collateral_id", "valuation_date")),),
            checks=(Check("values_valid", "market_value > 0 AND liquidation_value > 0 AND liquidation_value <= market_value", "Likvid dəyər müsbət olmalı və bazar dəyərini aşmamalıdır."),),
        ),
        Entity(
            "loan_collateral",
            "Kreditin girovu",
            "Kredit və ya kredit xətti ilə girov arasında əlaqə: təminat məbləği, girov müqaviləsi nömrəsi, prioritet, qüvvədə olma tarixləri.",
            rels=(
                Rel("collateral", "təminatdır"),
                Rel("loan", "təmin edilən kreditdir", parent_card="0..1"),
                Rel("credit_facility", "təmin edilən xətdir", parent_card="0..1"),
            ),
            attributes=(
                A("pledge_agreement_number", "code", "Girov müqaviləsinin nömrəsi."),
                A("secured_amount", "amount", "Bu girovla təmin edilən məbləğ."),
                A("priority_rank", "count", "Girovun növbəliliyi (1 — birinci növbəli).", default="1"),
                A("effective_from", "date", "Qüvvəyə minmə tarixi."),
                A("effective_to", "date", "Qüvvədən düşmə tarixi.", optional=True),
            ),
            checks=(LOAN_OR_FACILITY, VALID_PERIOD, Check("amount_positive", "secured_amount > 0", "Məbləğ müsbət olmalıdır.")),
        ),
        Entity(
            "loan_guarantee",
            "Zaminlik",
            "Kredit və ya kredit xətti üzrə zamin (fiziki və ya hüquqi şəxs) və zaminlik müqaviləsi: zəmanət məbləği, qüvvədə olma tarixləri.",
            rels=(
                Rel("party", "zamindir", fk="guarantor_party_id"),
                Rel("loan", "zəmanət verilən kreditdir", parent_card="0..1"),
                Rel("credit_facility", "zəmanət verilən xətdir", parent_card="0..1"),
            ),
            attributes=(
                A("guarantee_agreement_number", "code", "Zaminlik müqaviləsinin nömrəsi."),
                A("guaranteed_amount", "amount", "Zəmanət məbləği."),
                A("effective_from", "date", "Qüvvəyə minmə tarixi."),
                A("effective_to", "date", "Qüvvədən düşmə tarixi.", optional=True),
                A("status", "code", "Status.", values=("ACTIVE", "RELEASED", "CALLED")),
            ),
            checks=(LOAN_OR_FACILITY, VALID_PERIOD, Check("amount_positive", "guaranteed_amount > 0", "Məbləğ müsbət olmalıdır.")),
        ),
        Entity(
            "covenant",
            "Kovenant",
            "Biznes krediti üzrə maliyyə və qeyri-maliyyə şərtləri (məs. borc/EBITDA həddi) və onların yerinə yetirilməsinin yoxlanması.",
            rels=(
                Rel("loan", "şərtidir", parent_card="0..1"),
                Rel("credit_facility", "şərtidir", parent_card="0..1"),
            ),
            attributes=(
                A("covenant_type", "code", "Növ.", values=("FINANCIAL", "NON_FINANCIAL")),
                A("description", "long_text", "Şərtin mətni."),
                A("metric", "short_text", "Ölçülən göstərici (maliyyə kovenantları üçün).", optional=True),
                A("threshold_operator", "code", "Müqayisə operatoru.", optional=True, values=("LT", "LE", "GT", "GE", "EQ")),
                A("threshold_value", "fx_rate", "Hədd dəyəri.", optional=True),
                A("test_frequency", "code", "Yoxlama tezliyi.", values=("MONTHLY", "QUARTERLY", "ANNUAL")),
                A("last_tested_date", "date", "Son yoxlama tarixi.", optional=True),
                A("last_test_result", "code", "Son yoxlamanın nəticəsi.", optional=True, values=("MET", "BREACHED", "WAIVED")),
                A("status", "code", "Status.", values=("ACTIVE", "CLOSED")),
            ),
            checks=(
                LOAN_OR_FACILITY,
                Check(
                    "financial_threshold",
                    "covenant_type <> 'FINANCIAL' OR (metric IS NOT NULL AND threshold_operator IS NOT NULL AND threshold_value IS NOT NULL)",
                    "Maliyyə kovenantında göstərici, operator və hədd məcburidir.",
                ),
            ),
        ),
        Entity(
            "loan_restructuring",
            "Restrukturizasiya",
            "Kredit şərtlərinin dəyişdirilməsi: müddət, faiz, ödəniş qrafiki; səbəb, təsdiq edən və qüvvəyə minmə tarixi.",
            rels=(
                Rel("loan", "restrukturizasiyasıdır"),
                Rel("employee", "təsdiq edib", parent_card="0..1", fk="approved_by_employee_id"),
            ),
            attributes=(
                A("effective_date", "date", "Yeni şərtlərin qüvvəyə minmə tarixi."),
                A("reason", "text", "Səbəb."),
                A("old_annual_rate", "rate", "Əvvəlki illik dərəcə."),
                A("new_annual_rate", "rate", "Yeni illik dərəcə."),
                A("old_maturity_date", "date", "Əvvəlki son ödəniş tarixi."),
                A("new_maturity_date", "date", "Yeni son ödəniş tarixi."),
                A("new_schedule_version", "count", "Yaradılan yeni qrafik versiyası."),
                A("status", "code", "Status.", values=("PROPOSED", "APPROVED", "APPLIED", "REJECTED")),
            ),
        ),
        status_history(
            "loan_status_history",
            "Kredit statusu tarixçəsi",
            "Kredit statusunun dəyişiklikləri: aktiv, gecikmədə, restrukturizasiya, silinmiş, bağlanmış (yalnız əlavə olunur).",
            "loan",
            LOAN_STATUSES,
        ),
    ),
)
