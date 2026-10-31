from bankmodel.meta import Attribute as A
from bankmodel.meta import Check, Domain, Entity, Rel, Unique

CUSTOMER_TYPES = ("INDIVIDUAL", "LEGAL_ENTITY", "INDIVIDUAL_ENTREPRENEUR", "ANY")

DOMAIN = Domain(
    schema="ref",
    title="İstinad məlumatları",
    desc=(
        "Bütün domenlərin istifadə etdiyi kataloqlar və sorğu cədvəlləri: valyutalar, ölkələr, "
        "məzənnələr, bank kataloqu, məhsul kataloqu, əməliyyat, komissiya, sənəd və girov növləri. "
        "Biznes tərəfindən idarə olunan və vaxtaşırı dəyişən kod siyahıları burada saxlanılır."
    ),
    entities=(
        Entity(
            "currency",
            "Valyuta",
            "ISO 4217 valyuta kataloqu (AZN, USD, EUR və s.).",
            attributes=(
                A("currency_code", "currency_code", "ISO 4217 hərf kodu (AZN, USD, EUR).", unique=True),
                A("numeric_code", "code", "ISO 4217 rəqəm kodu (944 — AZN).", unique=True),
                A("name", "text", "Valyutanın adı."),
                A("minor_units", "count", "Kəsr hissəsinin rəqəm sayı (AZN üçün 2).", default="2"),
                A("is_active", "flag", "Valyuta ilə əməliyyat aparılırmı.", default="true"),
            ),
            checks=(Check("minor_units_range", "minor_units BETWEEN 0 AND 4", "Kəsr rəqəmləri 0–4 arasında olmalıdır."),),
        ),
        Entity(
            "country",
            "Ölkə",
            "ISO 3166 ölkə kataloqu; rezidentlik, vətəndaşlıq, ünvan və sanksiya riskinin müəyyən edilməsi üçün.",
            attributes=(
                A("country_code", "country_code", "ISO 3166-1 alpha-2 kodu (AZ).", unique=True),
                A("alpha3_code", "code", "ISO 3166-1 alpha-3 kodu (AZE).", unique=True),
                A("name", "text", "Ölkənin adı."),
                A("is_high_risk", "flag", "FATF və ya daxili siyasət üzrə yüksək riskli ölkə.", default="false"),
                A("is_active", "flag", "Kataloqda aktivdir.", default="true"),
            ),
        ),
        Entity(
            "exchange_rate",
            "Valyuta məzənnəsi",
            "Valyuta cütü üzrə tarixə görə məzənnələr: AMB-nin rəsmi məzənnəsi və bankın nağd/nağdsız alış-satış məzənnələri.",
            rels=(
                Rel("currency", "əsas valyutasıdır", fk="base_currency_id"),
                Rel("currency", "qarşı valyutasıdır", fk="quote_currency_id"),
            ),
            attributes=(
                A(
                    "rate_type",
                    "code",
                    "Məzənnə növü: AMB rəsmi, nağd alış/satış, nağdsız alış/satış.",
                    values=("OFFICIAL_CBAR", "CASH_BUY", "CASH_SELL", "NONCASH_BUY", "NONCASH_SELL"),
                ),
                A("rate_date", "date", "Məzənnənin aid olduğu tarix."),
                A("valid_from", "timestamp", "Məzənnənin qüvvəyə mindiyi an (gün ərzində bir neçə dəfə dəyişə bilər)."),
                A("nominal", "count", "Neçə vahid əsas valyuta üçün (adətən 1).", default="1"),
                A("rate", "fx_rate", "Nominal qədər əsas valyutanın qarşı valyutada dəyəri."),
            ),
            uniques=(Unique(("base_currency_id", "quote_currency_id", "rate_type", "valid_from")),),
            checks=(
                Check("rate_positive", "rate > 0 AND nominal > 0", "Məzənnə və nominal müsbət olmalıdır."),
                Check("distinct_currencies", "base_currency_id <> quote_currency_id", "Əsas və qarşı valyuta fərqli olmalıdır."),
            ),
        ),
        Entity(
            "holiday",
            "Qeyri-iş günü",
            "Bayram və qeyri-iş günləri təqvimi; dəyər tarixi, ödəniş qrafiki və faiz hesablanması üçün istifadə olunur.",
            rels=(Rel("country", "təqvimidir"),),
            attributes=(
                A("holiday_date", "date", "Qeyri-iş günü."),
                A("name", "text", "Bayramın və ya günün adı."),
                A(
                    "holiday_type",
                    "code",
                    "Növ: dövlət bayramı, köçürülmüş istirahət günü, bankın qeyri-iş günü.",
                    values=("PUBLIC_HOLIDAY", "TRANSFERRED_DAY_OFF", "BANK_HOLIDAY"),
                ),
            ),
            uniques=(Unique(("country_id", "holiday_date")),),
        ),
        Entity(
            "bank_directory",
            "Bank kataloqu",
            "Yerli və xarici banklar: BIC/SWIFT kodu, AMB bank kodu, müxbir hesab məlumatları.",
            rels=(Rel("country", "qeydiyyat ölkəsidir"),),
            attributes=(
                A("bic", "bic", "SWIFT BIC kodu.", optional=True, unique=True),
                A("cbar_bank_code", "code", "AMB tərəfindən verilmiş 6 rəqəmli bank kodu (yerli banklar üçün).", optional=True, unique=True),
                A("name", "text", "Bankın adı."),
                A("voen", "voen", "Bankın VÖEN-i (yerli banklar üçün).", optional=True),
                A("correspondent_account", "code", "Bankın AMB-dəki müxbir hesabı.", optional=True),
                A("is_active", "flag", "Bank fəaliyyətdədir.", default="true"),
            ),
            checks=(Check("has_identifier", "num_nonnulls(bic, cbar_bank_code) >= 1", "BIC və ya AMB bank kodundan ən azı biri olmalıdır."),),
        ),
        Entity(
            "economic_activity_code",
            "İqtisadi fəaliyyət növü",
            "İqtisadi fəaliyyət növlərinin iyerarxik təsnifatı (İFNT/NACE); hüquqi şəxslər və fərdi sahibkarlar üçün.",
            rels=(
                Rel(
                    "economic_activity_code",
                    "alt bölməsidir",
                    parent_card="0..1",
                    fk="parent_economic_activity_code_id",
                ),
            ),
            attributes=(
                A("code", "code", "Təsnifat kodu.", unique=True),
                A("name", "text", "Fəaliyyət növünün adı."),
                A("level", "count", "İyerarxiya səviyyəsi (1 — bölmə, sonrakılar — alt bölmələr)."),
            ),
        ),
        Entity(
            "document_type",
            "Sənəd növü",
            "Şəxsiyyət və qeydiyyat sənədlərinin növləri: şəxsiyyət vəsiqəsi, pasport, yaşayış icazəsi, dövlət qeydiyyatı şəhadətnaməsi və s.",
            attributes=(
                A("code", "code", "Sənəd növünün kodu.", unique=True),
                A("name", "text", "Sənəd növünün adı."),
                A("applies_to", "code", "Hansı tərəf növü üçün.", values=("INDIVIDUAL", "ORGANIZATION", "ANY")),
                A("requires_expiry", "flag", "Etibarlılıq müddəti məcburidir.", default="true"),
            ),
        ),
        Entity(
            "product_category",
            "Məhsul kateqoriyası",
            "Bank məhsullarının qrupları: cari hesab, əmanət, müddətli depozit, debet kart, kredit kartı, istehlak krediti, ipoteka, biznes krediti, kredit xətti.",
            attributes=(
                A("code", "code", "Kateqoriya kodu.", unique=True),
                A("name", "text", "Kateqoriyanın adı."),
                A(
                    "product_line",
                    "code",
                    "Məhsul xətti; hansı domenin obyektləri ilə işlədiyini müəyyən edir.",
                    values=(
                        "CURRENT_ACCOUNT", "SAVINGS", "TERM_DEPOSIT", "DEBIT_CARD", "CREDIT_CARD",
                        "CONSUMER_LOAN", "MORTGAGE", "BUSINESS_LOAN", "CREDIT_LINE", "OVERDRAFT",
                    ),
                ),
            ),
        ),
        Entity(
            "product",
            "Məhsul",
            "Bankın təklif etdiyi konkret məhsul və onun ümumi parametrləri (müştəri tipi, minimal/maksimal müddət və məbləğ).",
            rels=(Rel("product_category", "aiddir"),),
            attributes=(
                A("product_code", "code", "Məhsul kodu.", unique=True),
                A("name", "text", "Məhsulun adı."),
                A("customer_type", "code", "Məhsulun hədəf müştəri növü.", values=CUSTOMER_TYPES),
                A("min_term_months", "count", "Minimal müddət (ay).", optional=True),
                A("max_term_months", "count", "Maksimal müddət (ay).", optional=True),
                A("min_amount", "amount", "Minimal məbləğ.", optional=True),
                A("max_amount", "amount", "Maksimal məbləğ.", optional=True),
                A("launch_date", "date", "Satışa çıxarılma tarixi."),
                A("withdrawal_date", "date", "Satışdan çıxarılma tarixi.", optional=True),
                A("status", "code", "Məhsulun statusu.", values=("ACTIVE", "SUSPENDED", "WITHDRAWN")),
            ),
            checks=(
                Check("term_range", "min_term_months IS NULL OR max_term_months IS NULL OR min_term_months <= max_term_months", "Minimal müddət maksimaldan böyük ola bilməz."),
                Check("amount_range", "min_amount IS NULL OR max_amount IS NULL OR min_amount <= max_amount", "Minimal məbləğ maksimaldan böyük ola bilməz."),
            ),
        ),
        Entity(
            "product_interest_rate",
            "Məhsul faiz dərəcəsi",
            "Məhsul üzrə standart illik faiz dərəcələri: valyuta, müddət və məbləğ diapazonuna görə, qüvvədə olma tarixləri ilə. "
            "Faiz faktiki/365 (actual/365) bazası ilə hesablanır.",
            rels=(
                Rel("product", "faiz dərəcəsidir"),
                Rel("currency", "valyutasıdır"),
            ),
            attributes=(
                A("rate_kind", "code", "Dərəcənin növü.", values=("DEPOSIT", "LENDING", "OVERDRAFT", "PENALTY", "CREDIT_CARD")),
                A("term_from_months", "count", "Müddət diapazonunun başlanğıcı (ay).", optional=True),
                A("term_to_months", "count", "Müddət diapazonunun sonu (ay).", optional=True),
                A("amount_from", "amount", "Məbləğ diapazonunun başlanğıcı.", optional=True),
                A("amount_to", "amount", "Məbləğ diapazonunun sonu.", optional=True),
                A("annual_rate", "rate", "İllik faiz dərəcəsi (0.125000 = 12.5%); dəbbə üçün gündəlik dərəcə."),
                A("effective_from", "date", "Qüvvəyə minmə tarixi."),
                A("effective_to", "date", "Qüvvədən düşmə tarixi.", optional=True),
            ),
            checks=(
                Check("rate_non_negative", "annual_rate >= 0", "Faiz dərəcəsi mənfi ola bilməz."),
                Check("valid_period", "effective_to IS NULL OR effective_to >= effective_from", "Bitmə tarixi başlanğıcdan əvvəl ola bilməz."),
            ),
        ),
        Entity(
            "fee_type",
            "Komissiya növü",
            "Komissiya və haqların kataloqu: hesab xidməti, köçürmə, nağdlaşdırma, kartın illik haqqı və s.",
            attributes=(
                A("code", "code", "Komissiya kodu.", unique=True),
                A("name", "text", "Komissiyanın adı."),
                A("fee_category", "code", "Komissiya qrupu.", values=("ACCOUNT_SERVICE", "TRANSFER", "CASH", "CARD", "LOAN", "OTHER")),
            ),
        ),
        Entity(
            "product_fee",
            "Məhsul komissiyası",
            "Məhsula tətbiq olunan komissiya tarifləri: sabit məbləğ və/və ya faiz, minimum/maksimum, qüvvədə olma tarixləri.",
            rels=(
                Rel("product", "tarifidir"),
                Rel("fee_type", "növüdür"),
                Rel("currency", "valyutasıdır"),
            ),
            attributes=(
                A("calculation_method", "code", "Hesablama üsulu.", values=("FIXED", "PERCENT", "FIXED_PLUS_PERCENT")),
                A("fixed_amount", "amount", "Sabit məbləğ.", optional=True),
                A("percent_rate", "rate", "Əməliyyat məbləğindən faiz (0.005000 = 0.5%).", optional=True),
                A("min_amount", "amount", "Minimal komissiya.", optional=True),
                A("max_amount", "amount", "Maksimal komissiya.", optional=True),
                A("frequency", "code", "Tutulma tezliyi.", values=("ONE_TIME", "PER_TRANSACTION", "MONTHLY", "ANNUAL")),
                A("effective_from", "date", "Qüvvəyə minmə tarixi."),
                A("effective_to", "date", "Qüvvədən düşmə tarixi.", optional=True),
            ),
            checks=(
                Check(
                    "method_fields",
                    "(calculation_method = 'FIXED' AND fixed_amount IS NOT NULL) OR "
                    "(calculation_method = 'PERCENT' AND percent_rate IS NOT NULL) OR "
                    "(calculation_method = 'FIXED_PLUS_PERCENT' AND fixed_amount IS NOT NULL AND percent_rate IS NOT NULL)",
                    "Hesablama üsuluna uyğun sabit məbləğ və/və ya faiz göstərilməlidir.",
                ),
                Check("valid_period", "effective_to IS NULL OR effective_to >= effective_from", "Bitmə tarixi başlanğıcdan əvvəl ola bilməz."),
            ),
        ),
        Entity(
            "transaction_type",
            "Əməliyyat növü",
            "Hesab əməliyyatlarının kodları və istiqaməti (mədaxil/məxaric): köçürmə, nağd mədaxil, kart əməliyyatı, faiz, komissiya, kredit ödənişi və s.",
            attributes=(
                A("code", "code", "Əməliyyat növünün kodu.", unique=True),
                A("name", "text", "Əməliyyat növünün adı."),
                A("direction", "code", "İcazə verilən istiqamət.", values=("DEBIT", "CREDIT", "BOTH")),
                A("category", "code", "Əməliyyat qrupu.", values=("TRANSFER", "CASH", "CARD", "INTEREST", "FEE", "LOAN", "FX", "ADJUSTMENT")),
                A("is_reversible", "flag", "Storno edilə bilər.", default="true"),
            ),
        ),
        Entity(
            "collateral_type",
            "Girov növü",
            "Girov predmetlərinin növləri: daşınmaz əmlak, nəqliyyat vasitəsi, depozit, qiymətli metal, avadanlıq, mal-material.",
            attributes=(
                A("code", "code", "Girov növünün kodu.", unique=True),
                A("name", "text", "Girov növünün adı."),
                A("default_haircut_percent", "percent", "Standart diskont (dəyərdən çıxılan faiz).", optional=True),
                A("requires_registration", "flag", "Dövlət reyestrində qeydiyyat tələb olunur.", default="false"),
            ),
            checks=(Check("haircut_range", "default_haircut_percent IS NULL OR default_haircut_percent BETWEEN 0 AND 100", "Diskont 0–100% arasında olmalıdır."),),
        ),
        Entity(
            "mcc",
            "Satıcı kateqoriya kodu (MCC)",
            "ISO 18245 satıcı kateqoriya kodları; kart əməliyyatlarının təsnifatı, limitlər və riskin idarə edilməsi üçün.",
            attributes=(
                A("mcc_code", "code", "4 rəqəmli MCC kodu.", unique=True),
                A("description", "text", "Kateqoriyanın təsviri."),
                A("is_high_risk", "flag", "Yüksək riskli kateqoriya (qumar, kriptovalyuta və s.).", default="false"),
            ),
            checks=(Check("mcc_format", "mcc_code ~ '^[0-9]{4}$'", "MCC 4 rəqəmdən ibarət olmalıdır."),),
        ),
    ),
)
