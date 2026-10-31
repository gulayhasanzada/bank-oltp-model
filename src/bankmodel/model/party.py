from bankmodel.meta import Attribute as A
from bankmodel.meta import Check, Domain, Entity, Index, Rel, Unique, status_history

PARTY_STATUSES = ("PROSPECT", "ACTIVE", "INACTIVE", "BLOCKED", "DECEASED", "LIQUIDATED")

DOMAIN = Domain(
    schema="party",
    title="Tərəf və müştəri (KYC)",
    desc=(
        "Bankla münasibətdə olan bütün fiziki və hüquqi şəxslər (tərəflər), onların sənədləri, "
        "ünvanları, əlaqə vasitələri, bir-biri ilə əlaqələri, müştəri rolu və KYC yoxlamaları. "
        "Tərəf supertipdir: fiziki şəxs, hüquqi şəxs və ya fərdi sahibkar ola bilər."
    ),
    entities=(
        Entity(
            "party",
            "Tərəf",
            "Bankla münasibətdə olan istənilən şəxs (supertip). Növü: fiziki şəxs, hüquqi şəxs, fərdi sahibkar. "
            "Eyni tərəf müştəri, zamin, girov mülkiyyətçisi, benefisiar mülkiyyətçi və ya səlahiyyətli şəxs ola bilər.",
            rels=(Rel("country", "rezidentlik ölkəsidir", fk="residence_country_id"),),
            attributes=(
                A(
                    "party_type",
                    "code",
                    "Tərəfin növü (subtip diskriminatoru): fiziki şəxs, hüquqi şəxs, fərdi sahibkar.",
                    values=("INDIVIDUAL", "LEGAL_ENTITY", "INDIVIDUAL_ENTREPRENEUR"),
                ),
                A("display_name", "text", "Göstərilən ad (fiziki şəxs üçün tam ad, təşkilat üçün qısa ad)."),
                A("is_resident", "flag", "Azərbaycan Respublikasının rezidentidir."),
                A("status", "code", "Tərəfin həyat dövrü statusu.", values=PARTY_STATUSES),
            ),
        ),
        Entity(
            "individual_profile",
            "Fiziki şəxs profili",
            "Fiziki şəxsə və fərdi sahibkara aid şəxsi məlumatlar: soyad, ad, ata adı, doğum tarixi, FİN, vətəndaşlıq, PEP statusu.",
            rels=(
                Rel("party", "fiziki şəxs məlumatlarıdır", child_card="0..1"),
                Rel("country", "vətəndaşlığıdır", fk="citizenship_country_id"),
            ),
            attributes=(
                A("last_name", "short_text", "Soyad."),
                A("first_name", "short_text", "Ad."),
                A("patronymic", "short_text", "Ata adı.", optional=True),
                A("birth_date", "date", "Doğum tarixi."),
                A("birth_place", "text", "Doğum yeri.", optional=True),
                A("gender", "code", "Cins.", values=("MALE", "FEMALE")),
                A("fin", "fin", "FİN — şəxsiyyət vəsiqəsindəki 7 simvollu kod (Azərbaycan vətəndaşları və yaşayış icazəsi olanlar üçün).", optional=True, unique=True),
                A("is_pep", "flag", "Siyasi xadimdir (PEP).", default="false"),
                A("marital_status", "code", "Ailə vəziyyəti.", optional=True, values=("SINGLE", "MARRIED", "DIVORCED", "WIDOWED")),
                A(
                    "employment_status",
                    "code",
                    "Məşğulluq vəziyyəti.",
                    optional=True,
                    values=("EMPLOYED", "SELF_EMPLOYED", "UNEMPLOYED", "RETIRED", "STUDENT"),
                ),
                A("monthly_income_azn", "amount", "Bəyan edilmiş aylıq gəlir (AZN).", optional=True),
            ),
            checks=(Check("fin_format", "fin IS NULL OR fin ~ '^[0-9A-Z]{7}$'", "FİN 7 simvoldan (rəqəm və böyük latın hərfləri) ibarət olmalıdır."),),
            indexes=(Index(("last_name", "first_name", "birth_date")),),
        ),
        Entity(
            "organization_profile",
            "Təşkilat profili",
            "Hüquqi şəxsə və fərdi sahibkara aid qeydiyyat məlumatları: VÖEN, dövlət qeydiyyatı, təşkilati-hüquqi forma, fəaliyyət növü. "
            "Fərdi sahibkarın həm fiziki şəxs, həm də təşkilat profili olur.",
            rels=(
                Rel("party", "qeydiyyat məlumatlarıdır", child_card="0..1"),
                Rel("economic_activity_code", "əsas fəaliyyət növüdür"),
                Rel("country", "qeydiyyat ölkəsidir", fk="registration_country_id"),
            ),
            attributes=(
                A("legal_name", "text", "Tam rəsmi adı."),
                A("short_name", "text", "Qısa adı.", optional=True),
                A("voen", "voen", "VÖEN — 10 rəqəmli vergi ödəyicisi kodu (qeyri-rezident təşkilatlarda olmaya bilər).", optional=True, unique=True),
                A(
                    "legal_form",
                    "code",
                    "Təşkilati-hüquqi forma: MMC, ASC, QSC, tam/kommandit ortaqlıq, kooperativ, publik hüquqi şəxs, "
                    "qeyri-kommersiya təşkilatı, xarici şirkətin filialı, fərdi sahibkar.",
                    values=(
                        "LLC", "OJSC", "CJSC", "GENERAL_PARTNERSHIP", "LIMITED_PARTNERSHIP", "COOPERATIVE",
                        "PUBLIC_LEGAL_ENTITY", "NON_PROFIT", "FOREIGN_BRANCH", "INDIVIDUAL_ENTREPRENEUR",
                    ),
                ),
                A("registration_number", "short_text", "Dövlət qeydiyyat nömrəsi.", optional=True),
                A("registration_date", "date", "Dövlət qeydiyyatı tarixi."),
                A("registration_authority", "text", "Qeydiyyatı aparan orqan.", optional=True),
                A("authorized_capital", "amount", "Nizamnamə kapitalı (AZN).", optional=True),
                A("employee_count", "count", "İşçi sayı.", optional=True),
                A("annual_turnover_azn", "amount", "İllik dövriyyə (AZN).", optional=True),
                A("website", "text", "Veb sayt.", optional=True),
            ),
            checks=(Check("voen_format", "voen IS NULL OR voen ~ '^[0-9]{10}$'", "VÖEN 10 rəqəmdən ibarət olmalıdır."),),
        ),
        Entity(
            "party_identifier",
            "Tərəfin sənədi / identifikatoru",
            "Tərəfin şəxsiyyət və qeydiyyat sənədləri: şəxsiyyət vəsiqəsi, pasport, yaşayış icazəsi, şəhadətnamə; verilmə və etibarlılıq tarixləri ilə.",
            rels=(
                Rel("party", "sənədidir"),
                Rel("document_type", "növüdür"),
                Rel("country", "verən ölkədir", fk="issuing_country_id"),
            ),
            attributes=(
                A("document_series", "code", "Sənədin seriyası (AA, AZE və s.).", optional=True),
                A("document_number", "short_text", "Sənədin nömrəsi."),
                A("issue_date", "date", "Verilmə tarixi.", optional=True),
                A("expiry_date", "date", "Etibarlılıq müddətinin sonu.", optional=True),
                A("issuing_authority", "text", "Sənədi verən orqan.", optional=True),
                A("is_primary", "flag", "Əsas şəxsiyyət sənədidir.", default="false"),
                A("is_verified", "flag", "Sənəd yoxlanılıb (orijinal / dövlət reyestri).", default="false"),
            ),
            uniques=(Unique(("document_type_id", "issuing_country_id", "document_series", "document_number"), nulls_not_distinct=True),),
            checks=(Check("valid_dates", "expiry_date IS NULL OR issue_date IS NULL OR expiry_date > issue_date", "Etibarlılıq tarixi verilmə tarixindən sonra olmalıdır."),),
        ),
        Entity(
            "party_address",
            "Tərəfin ünvanı",
            "Qeydiyyat, faktiki və hüquqi ünvanlar; qüvvədə olma tarixləri ilə.",
            rels=(
                Rel("party", "ünvanıdır"),
                Rel("country", "ölkəsidir"),
            ),
            attributes=(
                A("address_type", "code", "Ünvanın növü.", values=("REGISTRATION", "ACTUAL", "LEGAL", "POSTAL")),
                A("address_line", "text", "Küçə, ev, mənzil."),
                A("city", "short_text", "Şəhər / rayon."),
                A("district", "short_text", "Rayon / qəsəbə.", optional=True),
                A("postal_code", "code", "Poçt indeksi (AZ1000).", optional=True),
                A("effective_from", "date", "Ünvanın qüvvədə olma başlanğıcı."),
                A("effective_to", "date", "Ünvanın qüvvədə olma sonu.", optional=True),
                A("is_primary", "flag", "Əsas əlaqə ünvanıdır.", default="false"),
            ),
            checks=(Check("valid_period", "effective_to IS NULL OR effective_to >= effective_from", "Bitmə tarixi başlanğıcdan əvvəl ola bilməz."),),
        ),
        Entity(
            "party_contact",
            "Əlaqə vasitəsi",
            "Telefon, e-poçt və digər əlaqə vasitələri; təsdiqlənmə statusu və üstünlük verilən vasitə əlaməti ilə.",
            rels=(Rel("party", "əlaqə vasitəsidir"),),
            attributes=(
                A("contact_type", "code", "Əlaqə vasitəsinin növü.", values=("MOBILE_PHONE", "HOME_PHONE", "WORK_PHONE", "EMAIL", "FAX")),
                A("contact_value", "text", "Telefon nömrəsi (E.164, +994...) və ya e-poçt ünvanı."),
                A("is_primary", "flag", "Üstünlük verilən vasitədir.", default="false"),
                A("is_verified", "flag", "OTP və ya digər üsulla təsdiqlənib.", default="false"),
                A("verified_at", "timestamp", "Təsdiqlənmə anı.", optional=True),
            ),
            indexes=(Index(("contact_value",)),),
        ),
        Entity(
            "party_relationship",
            "Tərəflər arası əlaqə",
            "İki tərəf arasında əlaqə: benefisiar mülkiyyətçi (UBO), direktor, təsisçi, səlahiyyətli imza sahibi, ailə üzvü; "
            "pay faizi və qüvvədə olma tarixləri ilə.",
            rels=(
                Rel("party", "əlaqənin subyektidir", fk="from_party_id"),
                Rel("party", "əlaqənin obyektidir", fk="to_party_id"),
            ),
            attributes=(
                A(
                    "relationship_type",
                    "code",
                    "Əlaqənin növü (from_party → to_party: məs. fiziki şəxs təşkilatın UBO-sudur).",
                    values=(
                        "UBO", "DIRECTOR", "FOUNDER", "AUTHORIZED_SIGNATORY", "CHIEF_ACCOUNTANT",
                        "LEGAL_REPRESENTATIVE", "SPOUSE", "PARENT", "CHILD",
                    ),
                ),
                A("ownership_percent", "percent", "Mülkiyyət payı (UBO və təsisçi üçün).", optional=True),
                A("effective_from", "date", "Əlaqənin başlanğıcı."),
                A("effective_to", "date", "Əlaqənin sonu.", optional=True),
            ),
            checks=(
                Check("distinct_parties", "from_party_id <> to_party_id", "Tərəf özü ilə əlaqədə ola bilməz."),
                Check("ownership_range", "ownership_percent IS NULL OR ownership_percent BETWEEN 0 AND 100", "Pay 0–100% arasında olmalıdır."),
                Check("valid_period", "effective_to IS NULL OR effective_to >= effective_from", "Bitmə tarixi başlanğıcdan əvvəl ola bilməz."),
            ),
        ),
        Entity(
            "segment",
            "Müştəri seqmenti",
            "Müştəri seqmentləri: kütləvi pərakəndə, premium, mikro və kiçik biznes, orta biznes, korporativ.",
            attributes=(
                A("segment_code", "code", "Seqment kodu.", unique=True),
                A("name", "text", "Seqmentin adı."),
                A("customer_group", "code", "Müştəri qrupu.", values=("RETAIL", "BUSINESS")),
            ),
        ),
        Entity(
            "customer",
            "Müştəri",
            "Tərəfin bankın müştərisi rolu: CIF nömrəsi, seqment, xidmət filialı, müştəri meneceri, münasibətin başlama və bitmə tarixi.",
            rels=(
                Rel("party", "müştəri roludur", child_card="0..1"),
                Rel("segment", "aid olduğu seqmentdir"),
                Rel("branch", "xidmət filialıdır", fk="home_branch_id"),
                Rel("employee", "müştəri meneceridir", parent_card="0..1", fk="relationship_manager_id"),
            ),
            attributes=(
                A("cif_number", "code", "CIF — bankın müştəriyə verdiyi unikal nömrə.", unique=True),
                A("customer_since", "date", "Müştəri münasibətinin başlama tarixi."),
                A("closed_date", "date", "Münasibətin bitmə tarixi.", optional=True),
                A("preferred_language", "code", "Ünsiyyət dili.", default="'AZ'", values=("AZ", "EN", "RU")),
                A("status", "code", "Müştəri statusu.", values=("ACTIVE", "DORMANT", "BLOCKED", "CLOSED")),
            ),
        ),
        Entity(
            "kyc_review",
            "KYC yoxlaması",
            "Müştərinin eyniləşdirilməsi və risk qiymətləndirilməsi (KYC/CDD/EDD): risk səviyyəsi, nəticə, növbəti yoxlama tarixi. "
            "Müştərinin cari risk səviyyəsi son təsdiqlənmiş yoxlamadır.",
            rels=(
                Rel("customer", "yoxlamasıdır"),
                Rel("employee", "yoxlamanı aparıb", parent_card="0..1", fk="reviewed_by_employee_id"),
            ),
            attributes=(
                A("review_type", "code", "Yoxlamanın səbəbi.", values=("ONBOARDING", "PERIODIC", "EVENT_DRIVEN")),
                A("due_diligence_level", "code", "Yoxlama səviyyəsi: sadələşdirilmiş, standart, gücləndirilmiş.", values=("SIMPLIFIED", "STANDARD", "ENHANCED")),
                A("risk_level", "code", "Müəyyən edilmiş AML risk səviyyəsi.", values=("LOW", "MEDIUM", "HIGH", "UNACCEPTABLE")),
                A("outcome", "code", "Nəticə.", values=("APPROVED", "REJECTED", "PENDING_INFO")),
                A("review_date", "date", "Yoxlama tarixi."),
                A("next_review_date", "date", "Növbəti yoxlama tarixi.", optional=True),
                A("source_of_funds", "text", "Vəsaitlərin mənbəyi.", optional=True),
                A("comment", "long_text", "Qeydlər.", optional=True),
            ),
            indexes=(Index(("next_review_date",)),),
        ),
        Entity(
            "consent",
            "Razılıq",
            "Tərəfin razılıqları: fərdi məlumatların emalı, Kredit Bürosuna sorğu, marketinq bildirişləri; verilmə və geri götürülmə tarixləri ilə.",
            rels=(Rel("party", "razılığıdır"),),
            attributes=(
                A(
                    "consent_type",
                    "code",
                    "Razılığın növü.",
                    values=("PERSONAL_DATA_PROCESSING", "CREDIT_BUREAU_INQUIRY", "MARKETING", "ELECTRONIC_COMMUNICATION"),
                ),
                A("granted_at", "timestamp", "Razılığın verildiyi an."),
                A("revoked_at", "timestamp", "Razılığın geri götürüldüyü an.", optional=True),
                A("document_reference", "text", "Razılıq sənədinin / elektron imzanın istinadı.", optional=True),
            ),
            checks=(Check("valid_period", "revoked_at IS NULL OR revoked_at >= granted_at", "Geri götürülmə verilmədən əvvəl ola bilməz."),),
        ),
        status_history(
            "party_status_history",
            "Tərəf statusu tarixçəsi",
            "Tərəfin həyat dövrü statusunun dəyişiklikləri (yalnız əlavə olunur, dəyişdirilmir).",
            "party",
            PARTY_STATUSES,
        ),
    ),
)
