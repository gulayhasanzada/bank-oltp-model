from bankmodel.meta import Attribute as A
from bankmodel.meta import Check, Domain, Entity, Rel

DOMAIN = Domain(
    schema="compliance",
    title="Uyğunluq və AML (sadələşdirilmiş)",
    desc=(
        "Cinayət yolu ilə əldə edilmiş gəlirlərin leqallaşdırılmasına qarşı mübarizə (AML): sanksiya və PEP yoxlamaları, "
        "şübhəli əməliyyat siqnalları, araşdırma işləri və Maliyyə Monitorinqi Xidmətinə (MMX) hesabatlar."
    ),
    entities=(
        Entity(
            "screening_check",
            "Sanksiya / PEP yoxlaması",
            "Tərəfin və ya ödənişin sanksiya və PEP siyahıları üzrə yoxlanılması: siyahı, uyğunluq dərəcəsi, nəticə, qərar.",
            rels=(
                Rel("party", "yoxlanılan tərəfdir", parent_card="0..1"),
                Rel("payment_order", "yoxlanılan ödənişdir", parent_card="0..1"),
            ),
            attributes=(
                A("screened_at", "timestamp", "Yoxlama anı.", default="now()"),
                A("list_name", "code", "Siyahı.", values=("UN", "EU", "OFAC", "UK_HMT", "LOCAL", "PEP")),
                A("screened_name", "text", "Yoxlanılan ad."),
                A("match_score", "percent", "Uyğunluq dərəcəsi (%).", optional=True),
                A("result", "code", "Nəticə.", values=("NO_MATCH", "POTENTIAL_MATCH", "TRUE_MATCH", "FALSE_POSITIVE")),
                A("decided_at", "timestamp", "Əməkdaşın qərar anı (potensial uyğunluqlar üçün).", optional=True),
            ),
            checks=(Check("has_subject", "num_nonnulls(party_id, payment_order_id) >= 1", "Yoxlanılan tərəf və ya ödəniş göstərilməlidir."),),
        ),
        Entity(
            "aml_case",
            "AML işi",
            "Bir və ya bir neçə siqnalın araşdırıldığı iş: məsul əməkdaş, prioritet, nəticə, MMX-yə məlumat verilib-verilməməsi.",
            rels=(
                Rel("party", "araşdırılan tərəfdir"),
                Rel("employee", "məsul əməkdaşdır", parent_card="0..1", fk="assigned_employee_id"),
            ),
            attributes=(
                A("case_number", "code", "İşin nömrəsi.", unique=True),
                A("opened_at", "timestamp", "Açılma anı.", default="now()"),
                A("closed_at", "timestamp", "Bağlanma anı.", optional=True),
                A("priority", "code", "Prioritet.", values=("LOW", "MEDIUM", "HIGH")),
                A(
                    "outcome",
                    "code",
                    "Nəticə.",
                    optional=True,
                    values=("NO_ACTION", "REPORTED_TO_FMS", "ACCOUNT_RESTRICTED", "RELATIONSHIP_TERMINATED"),
                ),
                A("status", "code", "Status.", values=("OPEN", "IN_PROGRESS", "CLOSED")),
            ),
            checks=(Check("closed_consistency", "(status = 'CLOSED') = (closed_at IS NOT NULL AND outcome IS NOT NULL)", "Bağlı işin bağlanma anı və nəticəsi olmalıdır."),),
        ),
        Entity(
            "aml_alert",
            "AML siqnalı",
            "Monitorinq qaydası və ya sanksiya yoxlaması ilə yaradılan şübhəli fəaliyyət siqnalı: qayda, risk balı, status.",
            rels=(
                Rel("party", "siqnalın tərəfidir"),
                Rel("account_transaction", "siqnala səbəb olub", parent_card="0..1"),
                Rel("screening_check", "siqnala səbəb olub", parent_card="0..1"),
                Rel("aml_case", "işə daxildir", parent_card="0..1"),
            ),
            attributes=(
                A("alert_number", "code", "Siqnalın nömrəsi.", unique=True),
                A("rule_code", "code", "Siqnalı yaradan monitorinq qaydasının kodu."),
                A("risk_score", "count", "Risk balı (0–100)."),
                A("generated_at", "timestamp", "Yaranma anı.", default="now()"),
                A("description", "text", "Təsvir.", optional=True),
                A(
                    "status",
                    "code",
                    "Status.",
                    values=("NEW", "UNDER_REVIEW", "ESCALATED", "CLOSED_FALSE_POSITIVE", "CLOSED_CONFIRMED"),
                ),
            ),
            checks=(Check("score_range", "risk_score BETWEEN 0 AND 100", "Risk balı 0–100 arasında olmalıdır."),),
        ),
        Entity(
            "regulatory_report",
            "Tənzimləyici hesabat",
            "MMX-yə (şübhəli əməliyyat, hədd məbləğini aşan əməliyyat) və AMB-yə göndərilən hesabat: növ, dövr, göndərilmə tarixi, status.",
            rels=(Rel("aml_case", "əsasında hazırlanıb", parent_card="0..1"),),
            attributes=(
                A("report_number", "code", "Hesabatın nömrəsi.", unique=True),
                A(
                    "report_type",
                    "code",
                    "Hesabatın növü: şübhəli əməliyyat, hədd məbləğini aşan əməliyyat, AMB-yə dövri hesabat.",
                    values=("SUSPICIOUS_TRANSACTION", "THRESHOLD_TRANSACTION", "CBAR_PERIODIC"),
                ),
                A("regulator", "code", "Alan orqan.", values=("FMS", "CBAR")),
                A("period_start", "date", "Hesabat dövrünün başlanğıcı.", optional=True),
                A("period_end", "date", "Hesabat dövrünün sonu.", optional=True),
                A("submitted_at", "timestamp", "Göndərilmə anı.", optional=True),
                A("regulator_reference", "code", "Orqanın qəbul nömrəsi.", optional=True),
                A("status", "code", "Status.", values=("DRAFT", "SUBMITTED", "ACCEPTED", "REJECTED")),
            ),
            checks=(Check("submitted_has_time", "status = 'DRAFT' OR submitted_at IS NOT NULL", "Göndərilmiş hesabatın göndərilmə anı olmalıdır."),),
        ),
        Entity(
            "regulatory_report_item",
            "Hesabat sətri",
            "Hesabata daxil edilən əməliyyat və ya tərəf.",
            rels=(
                Rel("regulatory_report", "sətiridir", child_card="1..N"),
                Rel("account_transaction", "hesabata daxildir", parent_card="0..1"),
                Rel("party", "hesabata daxildir", parent_card="0..1"),
            ),
            attributes=(
                A("item_number", "count", "Sətrin sıra nömrəsi."),
                A("amount_azn", "amount", "Əməliyyatın AZN ekvivalenti.", optional=True),
                A("note", "text", "Qeyd.", optional=True),
            ),
            checks=(Check("has_subject", "num_nonnulls(account_transaction_id, party_id) >= 1", "Əməliyyat və ya tərəf göstərilməlidir."),),
        ),
    ),
)
