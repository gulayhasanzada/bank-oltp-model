-- Bank OLTP verilənlər modeli — PostgreSQL 18 DDL
-- Bu fayl avtomatik yaradılıb (uv run bankmodel generate). Əl ilə redaktə etməyin.
-- Diqqət: skript mövcud sxemləri silib yenidən yaradır (yalnız inkişaf/yoxlama bazası üçün).

\set ON_ERROR_STOP on
BEGIN;

DROP SCHEMA IF EXISTS compliance, ledger, loan, card, payment, account, party, org, ref CASCADE;

-- ============================================================
-- Sxemlər
-- ============================================================
CREATE SCHEMA ref;
COMMENT ON SCHEMA ref IS 'İstinad məlumatları. Bütün domenlərin istifadə etdiyi kataloqlar və sorğu cədvəlləri: valyutalar, ölkələr, məzənnələr, bank kataloqu, məhsul kataloqu, əməliyyat, komissiya, sənəd və girov növləri. Biznes tərəfindən idarə olunan və vaxtaşırı dəyişən kod siyahıları burada saxlanılır.';
CREATE SCHEMA org;
COMMENT ON SCHEMA org IS 'Təşkilat və kanallar. Bankın daxili strukturu və xidmət kanalları: filial və şöbələr, əməkdaşlar, müştərilərin banka müraciət etdiyi kanallar və bankomatlar.';
CREATE SCHEMA party;
COMMENT ON SCHEMA party IS 'Tərəf və müştəri (KYC). Bankla münasibətdə olan bütün fiziki və hüquqi şəxslər (tərəflər), onların sənədləri, ünvanları, əlaqə vasitələri, bir-biri ilə əlaqələri, müştəri rolu və KYC yoxlamaları. Tərəf supertipdir: fiziki şəxs, hüquqi şəxs və ya fərdi sahibkar ola bilər.';
CREATE SCHEMA account;
COMMENT ON SCHEMA account IS 'Hesablar və əməliyyatlar. Müştəri hesabları (cari, əmanət, müddətli depozit, kart hesabı), hesab sahibləri, qalıqlar, hesab əməliyyatları, bloklamalar, komissiyalar, faiz hesablanması, limitlər, daimi tapşırıqlar və çıxarışlar. Hesablar çoxvalyutalıdır: hər hesab bir valyutada açılır, müştərinin müxtəlif valyutalarda hesabları ola bilər.';
CREATE SCHEMA payment;
COMMENT ON SCHEMA payment IS 'Ödənişlər. Müştərilərin köçürmə tapşırıqları və onların icrası: daxili köçürmələr, yerli ödəniş sistemləri (AZIPS — iri məbləğli real vaxt, XÖHKS — kütləvi ödənişlər), beynəlxalq SWIFT köçürmələri, büdcə ödənişləri, qaytarılmalar və valyuta mübadiləsi.';
CREATE SCHEMA card;
COMMENT ON SCHEMA card IS 'Kartlar. Debet və kredit kartları, onların limitləri, kredit kartı xətti və hesablaşma çıxarışları, real vaxt avtorizasiyaları və ödəniş sistemindən gələn klirinq əməliyyatları. Avtorizasiya bankın öz prosessinq sistemi tərəfindən aparılır. Kart həmişə hesaba bağlıdır: debet kart cari/kart hesabına, kredit kartı kredit xətti olan kart hesabına. Tam PAN, CVV və PIN bu bazada saxlanılmır (PCI DSS) — yalnız token və maskalanmış nömrə.';
CREATE SCHEMA loan;
COMMENT ON SCHEMA loan IS 'Kreditlər. Kredit həyat dövrü: müraciət, Kredit Bürosu yoxlaması, kredit xətti (biznes), kredit müqaviləsi (istehlak, ipoteka, biznes krediti), kreditin verilməsi, ödəniş qrafiki, ödənişlər və onların bölüşdürülməsi, dəbbə (gündəlik dərəcə ilə cərimə), girov və zaminlik, kovenantlar, restrukturizasiya. Faizlər faktiki/365 (actual/365) bazası ilə hesablanır.';
CREATE SCHEMA ledger;
COMMENT ON SCHEMA ledger IS 'Baş kitab (sadələşdirilmiş). Əməliyyatların mühasibat uçotunda əks olunması üçün sadələşdirilmiş baş kitab: baş kitab hesabları, mühasibat dövrləri, yazılış qaydaları və ikili yazılışlar (debet = kredit). AMB hesablar planının tam iyerarxiyası modelləşdirilmir; hesablar valideyn hesab vasitəsilə qruplaşdırılır.';
CREATE SCHEMA compliance;
COMMENT ON SCHEMA compliance IS 'Uyğunluq və AML (sadələşdirilmiş). Cinayət yolu ilə əldə edilmiş gəlirlərin leqallaşdırılmasına qarşı mübarizə (AML): sanksiya və PEP yoxlamaları, şübhəli əməliyyat siqnalları, araşdırma işləri və Maliyyə Monitorinqi Xidmətinə (MMX) hesabatlar.';

-- ============================================================
-- ref: İstinad məlumatları
-- ============================================================

CREATE TABLE ref.currency (
    currency_id uuid NOT NULL DEFAULT uuidv7(),
    currency_code char(3) NOT NULL,
    numeric_code varchar(30) NOT NULL,
    name varchar(255) NOT NULL,
    minor_units integer NOT NULL DEFAULT 2,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_currency PRIMARY KEY (currency_id),
    CONSTRAINT uq_currency_currency_code UNIQUE (currency_code),
    CONSTRAINT uq_currency_numeric_code UNIQUE (numeric_code),
    CONSTRAINT ck_currency_minor_units_range CHECK (minor_units BETWEEN 0 AND 4)
);

CREATE TABLE ref.country (
    country_id uuid NOT NULL DEFAULT uuidv7(),
    country_code char(2) NOT NULL,
    alpha3_code varchar(30) NOT NULL,
    name varchar(255) NOT NULL,
    is_high_risk boolean NOT NULL DEFAULT false,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_country PRIMARY KEY (country_id),
    CONSTRAINT uq_country_country_code UNIQUE (country_code),
    CONSTRAINT uq_country_alpha3_code UNIQUE (alpha3_code)
);

CREATE TABLE ref.exchange_rate (
    exchange_rate_id uuid NOT NULL DEFAULT uuidv7(),
    base_currency_id uuid NOT NULL,
    quote_currency_id uuid NOT NULL,
    rate_type varchar(30) NOT NULL,
    rate_date date NOT NULL,
    valid_from timestamptz NOT NULL,
    nominal integer NOT NULL DEFAULT 1,
    rate numeric(18,8) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_exchange_rate PRIMARY KEY (exchange_rate_id),
    CONSTRAINT uq_exchange_rate_base_currency_id_quote_currency_id_ra_27883c42 UNIQUE (base_currency_id, quote_currency_id, rate_type, valid_from),
    CONSTRAINT ck_exchange_rate_rate_type CHECK (rate_type IN ('OFFICIAL_CBAR', 'CASH_BUY', 'CASH_SELL', 'NONCASH_BUY', 'NONCASH_SELL')),
    CONSTRAINT ck_exchange_rate_rate_positive CHECK (rate > 0 AND nominal > 0),
    CONSTRAINT ck_exchange_rate_distinct_currencies CHECK (base_currency_id <> quote_currency_id)
);

CREATE TABLE ref.holiday (
    holiday_id uuid NOT NULL DEFAULT uuidv7(),
    country_id uuid NOT NULL,
    holiday_date date NOT NULL,
    name varchar(255) NOT NULL,
    holiday_type varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_holiday PRIMARY KEY (holiday_id),
    CONSTRAINT uq_holiday_country_id_holiday_date UNIQUE (country_id, holiday_date),
    CONSTRAINT ck_holiday_holiday_type CHECK (holiday_type IN ('PUBLIC_HOLIDAY', 'TRANSFERRED_DAY_OFF', 'BANK_HOLIDAY'))
);

CREATE TABLE ref.bank_directory (
    bank_directory_id uuid NOT NULL DEFAULT uuidv7(),
    country_id uuid NOT NULL,
    bic varchar(11),
    cbar_bank_code varchar(30),
    name varchar(255) NOT NULL,
    voen char(10),
    correspondent_account varchar(30),
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_bank_directory PRIMARY KEY (bank_directory_id),
    CONSTRAINT uq_bank_directory_bic UNIQUE (bic),
    CONSTRAINT uq_bank_directory_cbar_bank_code UNIQUE (cbar_bank_code),
    CONSTRAINT ck_bank_directory_has_identifier CHECK (num_nonnulls(bic, cbar_bank_code) >= 1)
);

CREATE TABLE ref.economic_activity_code (
    economic_activity_code_id uuid NOT NULL DEFAULT uuidv7(),
    parent_economic_activity_code_id uuid,
    code varchar(30) NOT NULL,
    name varchar(255) NOT NULL,
    level integer NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_economic_activity_code PRIMARY KEY (economic_activity_code_id),
    CONSTRAINT uq_economic_activity_code_code UNIQUE (code)
);

CREATE TABLE ref.document_type (
    document_type_id uuid NOT NULL DEFAULT uuidv7(),
    code varchar(30) NOT NULL,
    name varchar(255) NOT NULL,
    applies_to varchar(30) NOT NULL,
    requires_expiry boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_document_type PRIMARY KEY (document_type_id),
    CONSTRAINT uq_document_type_code UNIQUE (code),
    CONSTRAINT ck_document_type_applies_to CHECK (applies_to IN ('INDIVIDUAL', 'ORGANIZATION', 'ANY'))
);

CREATE TABLE ref.product_category (
    product_category_id uuid NOT NULL DEFAULT uuidv7(),
    code varchar(30) NOT NULL,
    name varchar(255) NOT NULL,
    product_line varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_product_category PRIMARY KEY (product_category_id),
    CONSTRAINT uq_product_category_code UNIQUE (code),
    CONSTRAINT ck_product_category_product_line CHECK (product_line IN ('CURRENT_ACCOUNT', 'SAVINGS', 'TERM_DEPOSIT', 'DEBIT_CARD', 'CREDIT_CARD', 'CONSUMER_LOAN', 'MORTGAGE', 'BUSINESS_LOAN', 'CREDIT_LINE', 'OVERDRAFT'))
);

CREATE TABLE ref.product (
    product_id uuid NOT NULL DEFAULT uuidv7(),
    product_category_id uuid NOT NULL,
    product_code varchar(30) NOT NULL,
    name varchar(255) NOT NULL,
    customer_type varchar(30) NOT NULL,
    min_term_months integer,
    max_term_months integer,
    min_amount numeric(19,4),
    max_amount numeric(19,4),
    launch_date date NOT NULL,
    withdrawal_date date,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_product PRIMARY KEY (product_id),
    CONSTRAINT uq_product_product_code UNIQUE (product_code),
    CONSTRAINT ck_product_customer_type CHECK (customer_type IN ('INDIVIDUAL', 'LEGAL_ENTITY', 'INDIVIDUAL_ENTREPRENEUR', 'ANY')),
    CONSTRAINT ck_product_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'WITHDRAWN')),
    CONSTRAINT ck_product_term_range CHECK (min_term_months IS NULL OR max_term_months IS NULL OR min_term_months <= max_term_months),
    CONSTRAINT ck_product_amount_range CHECK (min_amount IS NULL OR max_amount IS NULL OR min_amount <= max_amount)
);

CREATE TABLE ref.product_interest_rate (
    product_interest_rate_id uuid NOT NULL DEFAULT uuidv7(),
    product_id uuid NOT NULL,
    currency_id uuid NOT NULL,
    rate_kind varchar(30) NOT NULL,
    term_from_months integer,
    term_to_months integer,
    amount_from numeric(19,4),
    amount_to numeric(19,4),
    annual_rate numeric(9,6) NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_product_interest_rate PRIMARY KEY (product_interest_rate_id),
    CONSTRAINT ck_product_interest_rate_rate_kind CHECK (rate_kind IN ('DEPOSIT', 'LENDING', 'OVERDRAFT', 'PENALTY', 'CREDIT_CARD')),
    CONSTRAINT ck_product_interest_rate_rate_non_negative CHECK (annual_rate >= 0),
    CONSTRAINT ck_product_interest_rate_valid_period CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE TABLE ref.fee_type (
    fee_type_id uuid NOT NULL DEFAULT uuidv7(),
    code varchar(30) NOT NULL,
    name varchar(255) NOT NULL,
    fee_category varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_fee_type PRIMARY KEY (fee_type_id),
    CONSTRAINT uq_fee_type_code UNIQUE (code),
    CONSTRAINT ck_fee_type_fee_category CHECK (fee_category IN ('ACCOUNT_SERVICE', 'TRANSFER', 'CASH', 'CARD', 'LOAN', 'OTHER'))
);

CREATE TABLE ref.product_fee (
    product_fee_id uuid NOT NULL DEFAULT uuidv7(),
    product_id uuid NOT NULL,
    fee_type_id uuid NOT NULL,
    currency_id uuid NOT NULL,
    calculation_method varchar(30) NOT NULL,
    fixed_amount numeric(19,4),
    percent_rate numeric(9,6),
    min_amount numeric(19,4),
    max_amount numeric(19,4),
    frequency varchar(30) NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_product_fee PRIMARY KEY (product_fee_id),
    CONSTRAINT ck_product_fee_calculation_method CHECK (calculation_method IN ('FIXED', 'PERCENT', 'FIXED_PLUS_PERCENT')),
    CONSTRAINT ck_product_fee_frequency CHECK (frequency IN ('ONE_TIME', 'PER_TRANSACTION', 'MONTHLY', 'ANNUAL')),
    CONSTRAINT ck_product_fee_method_fields CHECK ((calculation_method = 'FIXED' AND fixed_amount IS NOT NULL) OR (calculation_method = 'PERCENT' AND percent_rate IS NOT NULL) OR (calculation_method = 'FIXED_PLUS_PERCENT' AND fixed_amount IS NOT NULL AND percent_rate IS NOT NULL)),
    CONSTRAINT ck_product_fee_valid_period CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE TABLE ref.transaction_type (
    transaction_type_id uuid NOT NULL DEFAULT uuidv7(),
    code varchar(30) NOT NULL,
    name varchar(255) NOT NULL,
    direction varchar(30) NOT NULL,
    category varchar(30) NOT NULL,
    is_reversible boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_transaction_type PRIMARY KEY (transaction_type_id),
    CONSTRAINT uq_transaction_type_code UNIQUE (code),
    CONSTRAINT ck_transaction_type_direction CHECK (direction IN ('DEBIT', 'CREDIT', 'BOTH')),
    CONSTRAINT ck_transaction_type_category CHECK (category IN ('TRANSFER', 'CASH', 'CARD', 'INTEREST', 'FEE', 'LOAN', 'FX', 'ADJUSTMENT'))
);

CREATE TABLE ref.collateral_type (
    collateral_type_id uuid NOT NULL DEFAULT uuidv7(),
    code varchar(30) NOT NULL,
    name varchar(255) NOT NULL,
    default_haircut_percent numeric(5,2),
    requires_registration boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_collateral_type PRIMARY KEY (collateral_type_id),
    CONSTRAINT uq_collateral_type_code UNIQUE (code),
    CONSTRAINT ck_collateral_type_haircut_range CHECK (default_haircut_percent IS NULL OR default_haircut_percent BETWEEN 0 AND 100)
);

CREATE TABLE ref.mcc (
    mcc_id uuid NOT NULL DEFAULT uuidv7(),
    mcc_code varchar(30) NOT NULL,
    description varchar(255) NOT NULL,
    is_high_risk boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_mcc PRIMARY KEY (mcc_id),
    CONSTRAINT uq_mcc_mcc_code UNIQUE (mcc_code),
    CONSTRAINT ck_mcc_mcc_format CHECK (mcc_code ~ '^[0-9]{4}$')
);

-- ============================================================
-- org: Təşkilat və kanallar
-- ============================================================

CREATE TABLE org.branch (
    branch_id uuid NOT NULL DEFAULT uuidv7(),
    parent_branch_id uuid,
    branch_code varchar(30) NOT NULL,
    name varchar(255) NOT NULL,
    branch_type varchar(30) NOT NULL,
    address varchar(255) NOT NULL,
    city varchar(100) NOT NULL,
    phone varchar(100),
    opened_date date NOT NULL,
    closed_date date,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_branch PRIMARY KEY (branch_id),
    CONSTRAINT uq_branch_branch_code UNIQUE (branch_code),
    CONSTRAINT ck_branch_branch_type CHECK (branch_type IN ('HEAD_OFFICE', 'BRANCH', 'DIVISION')),
    CONSTRAINT ck_branch_status CHECK (status IN ('ACTIVE', 'CLOSED'))
);

CREATE TABLE org.employee (
    employee_id uuid NOT NULL DEFAULT uuidv7(),
    branch_id uuid NOT NULL,
    manager_employee_id uuid,
    employee_number varchar(30) NOT NULL,
    first_name varchar(100) NOT NULL,
    last_name varchar(100) NOT NULL,
    position varchar(255) NOT NULL,
    email varchar(255),
    hired_date date NOT NULL,
    terminated_date date,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_employee PRIMARY KEY (employee_id),
    CONSTRAINT uq_employee_employee_number UNIQUE (employee_number),
    CONSTRAINT uq_employee_email UNIQUE (email),
    CONSTRAINT ck_employee_status CHECK (status IN ('ACTIVE', 'ON_LEAVE', 'TERMINATED'))
);

CREATE TABLE org.channel (
    channel_id uuid NOT NULL DEFAULT uuidv7(),
    channel_code varchar(30) NOT NULL,
    name varchar(255) NOT NULL,
    channel_type varchar(30) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_channel PRIMARY KEY (channel_id),
    CONSTRAINT uq_channel_channel_code UNIQUE (channel_code),
    CONSTRAINT ck_channel_channel_type CHECK (channel_type IN ('BRANCH', 'ATM', 'INTERNET_BANKING', 'MOBILE_BANKING', 'POS', 'CALL_CENTER', 'API'))
);

CREATE TABLE org.atm (
    atm_id uuid NOT NULL DEFAULT uuidv7(),
    branch_id uuid,
    terminal_id varchar(30) NOT NULL,
    address varchar(255) NOT NULL,
    city varchar(100) NOT NULL,
    supports_cash_in boolean NOT NULL DEFAULT false,
    installed_date date NOT NULL,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_atm PRIMARY KEY (atm_id),
    CONSTRAINT uq_atm_terminal_id UNIQUE (terminal_id),
    CONSTRAINT ck_atm_status CHECK (status IN ('ACTIVE', 'OUT_OF_SERVICE', 'DECOMMISSIONED'))
);

-- ============================================================
-- party: Tərəf və müştəri (KYC)
-- ============================================================

CREATE TABLE party.party (
    party_id uuid NOT NULL DEFAULT uuidv7(),
    residence_country_id uuid NOT NULL,
    party_type varchar(30) NOT NULL,
    display_name varchar(255) NOT NULL,
    is_resident boolean NOT NULL,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_party PRIMARY KEY (party_id),
    CONSTRAINT ck_party_party_type CHECK (party_type IN ('INDIVIDUAL', 'LEGAL_ENTITY', 'INDIVIDUAL_ENTREPRENEUR')),
    CONSTRAINT ck_party_status CHECK (status IN ('PROSPECT', 'ACTIVE', 'INACTIVE', 'BLOCKED', 'DECEASED', 'LIQUIDATED'))
);

CREATE TABLE party.individual_profile (
    individual_profile_id uuid NOT NULL DEFAULT uuidv7(),
    party_id uuid NOT NULL,
    citizenship_country_id uuid NOT NULL,
    last_name varchar(100) NOT NULL,
    first_name varchar(100) NOT NULL,
    patronymic varchar(100),
    birth_date date NOT NULL,
    birth_place varchar(255),
    gender varchar(30) NOT NULL,
    fin char(7),
    is_pep boolean NOT NULL DEFAULT false,
    marital_status varchar(30),
    employment_status varchar(30),
    monthly_income_azn numeric(19,4),
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_individual_profile PRIMARY KEY (individual_profile_id),
    CONSTRAINT uq_individual_profile_party_id UNIQUE (party_id),
    CONSTRAINT uq_individual_profile_fin UNIQUE (fin),
    CONSTRAINT ck_individual_profile_gender CHECK (gender IN ('MALE', 'FEMALE')),
    CONSTRAINT ck_individual_profile_marital_status CHECK (marital_status IN ('SINGLE', 'MARRIED', 'DIVORCED', 'WIDOWED')),
    CONSTRAINT ck_individual_profile_employment_status CHECK (employment_status IN ('EMPLOYED', 'SELF_EMPLOYED', 'UNEMPLOYED', 'RETIRED', 'STUDENT')),
    CONSTRAINT ck_individual_profile_fin_format CHECK (fin IS NULL OR fin ~ '^[0-9A-Z]{7}$')
);

CREATE TABLE party.organization_profile (
    organization_profile_id uuid NOT NULL DEFAULT uuidv7(),
    party_id uuid NOT NULL,
    economic_activity_code_id uuid NOT NULL,
    registration_country_id uuid NOT NULL,
    legal_name varchar(255) NOT NULL,
    short_name varchar(255),
    voen char(10),
    legal_form varchar(30) NOT NULL,
    registration_number varchar(100),
    registration_date date NOT NULL,
    registration_authority varchar(255),
    authorized_capital numeric(19,4),
    employee_count integer,
    annual_turnover_azn numeric(19,4),
    website varchar(255),
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_organization_profile PRIMARY KEY (organization_profile_id),
    CONSTRAINT uq_organization_profile_party_id UNIQUE (party_id),
    CONSTRAINT uq_organization_profile_voen UNIQUE (voen),
    CONSTRAINT ck_organization_profile_legal_form CHECK (legal_form IN ('LLC', 'OJSC', 'CJSC', 'GENERAL_PARTNERSHIP', 'LIMITED_PARTNERSHIP', 'COOPERATIVE', 'PUBLIC_LEGAL_ENTITY', 'NON_PROFIT', 'FOREIGN_BRANCH', 'INDIVIDUAL_ENTREPRENEUR')),
    CONSTRAINT ck_organization_profile_voen_format CHECK (voen IS NULL OR voen ~ '^[0-9]{10}$')
);

CREATE TABLE party.party_identifier (
    party_identifier_id uuid NOT NULL DEFAULT uuidv7(),
    party_id uuid NOT NULL,
    document_type_id uuid NOT NULL,
    issuing_country_id uuid NOT NULL,
    document_series varchar(30),
    document_number varchar(100) NOT NULL,
    issue_date date,
    expiry_date date,
    issuing_authority varchar(255),
    is_primary boolean NOT NULL DEFAULT false,
    is_verified boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_party_identifier PRIMARY KEY (party_identifier_id),
    CONSTRAINT uq_party_identifier_document_type_id_issuing_country_i_68a43b09 UNIQUE NULLS NOT DISTINCT (document_type_id, issuing_country_id, document_series, document_number),
    CONSTRAINT ck_party_identifier_valid_dates CHECK (expiry_date IS NULL OR issue_date IS NULL OR expiry_date > issue_date)
);

CREATE TABLE party.party_address (
    party_address_id uuid NOT NULL DEFAULT uuidv7(),
    party_id uuid NOT NULL,
    country_id uuid NOT NULL,
    address_type varchar(30) NOT NULL,
    address_line varchar(255) NOT NULL,
    city varchar(100) NOT NULL,
    district varchar(100),
    postal_code varchar(30),
    effective_from date NOT NULL,
    effective_to date,
    is_primary boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_party_address PRIMARY KEY (party_address_id),
    CONSTRAINT ck_party_address_address_type CHECK (address_type IN ('REGISTRATION', 'ACTUAL', 'LEGAL', 'POSTAL')),
    CONSTRAINT ck_party_address_valid_period CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE TABLE party.party_contact (
    party_contact_id uuid NOT NULL DEFAULT uuidv7(),
    party_id uuid NOT NULL,
    contact_type varchar(30) NOT NULL,
    contact_value varchar(255) NOT NULL,
    is_primary boolean NOT NULL DEFAULT false,
    is_verified boolean NOT NULL DEFAULT false,
    verified_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_party_contact PRIMARY KEY (party_contact_id),
    CONSTRAINT ck_party_contact_contact_type CHECK (contact_type IN ('MOBILE_PHONE', 'HOME_PHONE', 'WORK_PHONE', 'EMAIL', 'FAX'))
);

CREATE TABLE party.party_relationship (
    party_relationship_id uuid NOT NULL DEFAULT uuidv7(),
    from_party_id uuid NOT NULL,
    to_party_id uuid NOT NULL,
    relationship_type varchar(30) NOT NULL,
    ownership_percent numeric(5,2),
    effective_from date NOT NULL,
    effective_to date,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_party_relationship PRIMARY KEY (party_relationship_id),
    CONSTRAINT ck_party_relationship_relationship_type CHECK (relationship_type IN ('UBO', 'DIRECTOR', 'FOUNDER', 'AUTHORIZED_SIGNATORY', 'CHIEF_ACCOUNTANT', 'LEGAL_REPRESENTATIVE', 'SPOUSE', 'PARENT', 'CHILD')),
    CONSTRAINT ck_party_relationship_distinct_parties CHECK (from_party_id <> to_party_id),
    CONSTRAINT ck_party_relationship_ownership_range CHECK (ownership_percent IS NULL OR ownership_percent BETWEEN 0 AND 100),
    CONSTRAINT ck_party_relationship_valid_period CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE TABLE party.segment (
    segment_id uuid NOT NULL DEFAULT uuidv7(),
    segment_code varchar(30) NOT NULL,
    name varchar(255) NOT NULL,
    customer_group varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_segment PRIMARY KEY (segment_id),
    CONSTRAINT uq_segment_segment_code UNIQUE (segment_code),
    CONSTRAINT ck_segment_customer_group CHECK (customer_group IN ('RETAIL', 'BUSINESS'))
);

CREATE TABLE party.customer (
    customer_id uuid NOT NULL DEFAULT uuidv7(),
    party_id uuid NOT NULL,
    segment_id uuid NOT NULL,
    home_branch_id uuid NOT NULL,
    relationship_manager_id uuid,
    cif_number varchar(30) NOT NULL,
    customer_since date NOT NULL,
    closed_date date,
    preferred_language varchar(30) NOT NULL DEFAULT 'AZ',
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_customer PRIMARY KEY (customer_id),
    CONSTRAINT uq_customer_party_id UNIQUE (party_id),
    CONSTRAINT uq_customer_cif_number UNIQUE (cif_number),
    CONSTRAINT ck_customer_preferred_language CHECK (preferred_language IN ('AZ', 'EN', 'RU')),
    CONSTRAINT ck_customer_status CHECK (status IN ('ACTIVE', 'DORMANT', 'BLOCKED', 'CLOSED'))
);

CREATE TABLE party.kyc_review (
    kyc_review_id uuid NOT NULL DEFAULT uuidv7(),
    customer_id uuid NOT NULL,
    reviewed_by_employee_id uuid,
    review_type varchar(30) NOT NULL,
    due_diligence_level varchar(30) NOT NULL,
    risk_level varchar(30) NOT NULL,
    outcome varchar(30) NOT NULL,
    review_date date NOT NULL,
    next_review_date date,
    source_of_funds varchar(255),
    comment text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_kyc_review PRIMARY KEY (kyc_review_id),
    CONSTRAINT ck_kyc_review_review_type CHECK (review_type IN ('ONBOARDING', 'PERIODIC', 'EVENT_DRIVEN')),
    CONSTRAINT ck_kyc_review_due_diligence_level CHECK (due_diligence_level IN ('SIMPLIFIED', 'STANDARD', 'ENHANCED')),
    CONSTRAINT ck_kyc_review_risk_level CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH', 'UNACCEPTABLE')),
    CONSTRAINT ck_kyc_review_outcome CHECK (outcome IN ('APPROVED', 'REJECTED', 'PENDING_INFO'))
);

CREATE TABLE party.consent (
    consent_id uuid NOT NULL DEFAULT uuidv7(),
    party_id uuid NOT NULL,
    consent_type varchar(30) NOT NULL,
    granted_at timestamptz NOT NULL,
    revoked_at timestamptz,
    document_reference varchar(255),
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_consent PRIMARY KEY (consent_id),
    CONSTRAINT ck_consent_consent_type CHECK (consent_type IN ('PERSONAL_DATA_PROCESSING', 'CREDIT_BUREAU_INQUIRY', 'MARKETING', 'ELECTRONIC_COMMUNICATION')),
    CONSTRAINT ck_consent_valid_period CHECK (revoked_at IS NULL OR revoked_at >= granted_at)
);

CREATE TABLE party.party_status_history (
    party_status_history_id uuid NOT NULL DEFAULT uuidv7(),
    party_id uuid NOT NULL,
    from_status varchar(30),
    to_status varchar(30) NOT NULL,
    changed_at timestamptz NOT NULL DEFAULT now(),
    reason_code varchar(30),
    comment text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_party_status_history PRIMARY KEY (party_status_history_id),
    CONSTRAINT ck_party_status_history_from_status CHECK (from_status IN ('PROSPECT', 'ACTIVE', 'INACTIVE', 'BLOCKED', 'DECEASED', 'LIQUIDATED')),
    CONSTRAINT ck_party_status_history_to_status CHECK (to_status IN ('PROSPECT', 'ACTIVE', 'INACTIVE', 'BLOCKED', 'DECEASED', 'LIQUIDATED')),
    CONSTRAINT ck_party_status_history_status_changed CHECK (from_status IS DISTINCT FROM to_status)
);

-- ============================================================
-- account: Hesablar və əməliyyatlar
-- ============================================================

CREATE TABLE account.account (
    account_id uuid NOT NULL DEFAULT uuidv7(),
    customer_id uuid NOT NULL,
    product_id uuid NOT NULL,
    currency_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    account_number varchar(30) NOT NULL,
    iban varchar(34) NOT NULL,
    account_type varchar(30) NOT NULL,
    account_name varchar(255),
    opened_date date NOT NULL,
    closed_date date,
    is_joint boolean NOT NULL DEFAULT false,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_account PRIMARY KEY (account_id),
    CONSTRAINT uq_account_account_number UNIQUE (account_number),
    CONSTRAINT uq_account_iban UNIQUE (iban),
    CONSTRAINT ck_account_account_type CHECK (account_type IN ('CURRENT', 'SAVINGS', 'TERM_DEPOSIT', 'CARD')),
    CONSTRAINT ck_account_status CHECK (status IN ('PENDING', 'ACTIVE', 'DORMANT', 'FROZEN', 'CLOSED')),
    CONSTRAINT ck_account_iban_format CHECK (iban ~ '^AZ[0-9]{2}[A-Z]{4}[A-Z0-9]{20}$'),
    CONSTRAINT ck_account_closed_consistency CHECK ((status = 'CLOSED') = (closed_date IS NOT NULL))
);

CREATE TABLE account.account_holder (
    account_holder_id uuid NOT NULL DEFAULT uuidv7(),
    account_id uuid NOT NULL,
    party_id uuid NOT NULL,
    holder_role varchar(30) NOT NULL,
    signing_rule varchar(30),
    power_of_attorney_number varchar(100),
    effective_from date NOT NULL,
    effective_to date,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_account_holder PRIMARY KEY (account_holder_id),
    CONSTRAINT uq_account_holder_account_id_party_id_holder_role_effe_ab07aa10 UNIQUE (account_id, party_id, holder_role, effective_from),
    CONSTRAINT ck_account_holder_holder_role CHECK (holder_role IN ('PRIMARY_OWNER', 'JOINT_OWNER', 'AUTHORIZED_SIGNATORY', 'POWER_OF_ATTORNEY', 'TRUSTEE')),
    CONSTRAINT ck_account_holder_signing_rule CHECK (signing_rule IN ('SOLE', 'ANY_TWO', 'ALL')),
    CONSTRAINT ck_account_holder_valid_period CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE TABLE account.account_balance (
    account_balance_id uuid NOT NULL DEFAULT uuidv7(),
    account_id uuid NOT NULL,
    ledger_balance numeric(19,4) NOT NULL DEFAULT 0,
    blocked_amount numeric(19,4) NOT NULL DEFAULT 0,
    available_balance numeric(19,4) NOT NULL DEFAULT 0,
    last_transaction_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_account_balance PRIMARY KEY (account_balance_id),
    CONSTRAINT uq_account_balance_account_id UNIQUE (account_id),
    CONSTRAINT ck_account_balance_blocked_non_negative CHECK (blocked_amount >= 0)
);

CREATE TABLE account.account_balance_daily (
    account_balance_daily_id uuid NOT NULL DEFAULT uuidv7(),
    account_id uuid NOT NULL,
    balance_date date NOT NULL,
    ledger_balance numeric(19,4) NOT NULL,
    available_balance numeric(19,4) NOT NULL,
    debit_turnover numeric(19,4) NOT NULL DEFAULT 0,
    credit_turnover numeric(19,4) NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_account_balance_daily PRIMARY KEY (account_balance_daily_id),
    CONSTRAINT uq_account_balance_daily_account_id_balance_date UNIQUE (account_id, balance_date)
);

CREATE TABLE account.account_transaction (
    account_transaction_id uuid NOT NULL DEFAULT uuidv7(),
    account_id uuid NOT NULL,
    transaction_type_id uuid NOT NULL,
    channel_id uuid,
    original_currency_id uuid,
    payment_order_id uuid,
    card_transaction_id uuid,
    card_transaction_date date,
    loan_disbursement_id uuid,
    loan_repayment_id uuid,
    reversed_account_transaction_id uuid,
    reversed_account_transaction_date date,
    transaction_date date NOT NULL,
    value_date date NOT NULL,
    posted_at timestamptz NOT NULL DEFAULT now(),
    direction varchar(30) NOT NULL,
    amount numeric(19,4) NOT NULL,
    original_amount numeric(19,4),
    balance_after numeric(19,4) NOT NULL,
    reference_number varchar(30) NOT NULL,
    narrative varchar(255),
    status varchar(30) NOT NULL DEFAULT 'POSTED',
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_account_transaction PRIMARY KEY (account_transaction_id, transaction_date),
    CONSTRAINT uq_account_transaction_reversed_account_transaction_id_7d624dfe UNIQUE (reversed_account_transaction_id, reversed_account_transaction_date, transaction_date),
    CONSTRAINT ck_account_transaction_direction CHECK (direction IN ('DEBIT', 'CREDIT')),
    CONSTRAINT ck_account_transaction_status CHECK (status IN ('POSTED', 'REVERSED')),
    CONSTRAINT ck_account_transaction_amount_positive CHECK (amount > 0),
    CONSTRAINT ck_account_transaction_single_source CHECK (num_nonnulls(payment_order_id, card_transaction_id, loan_disbursement_id, loan_repayment_id) <= 1),
    CONSTRAINT ck_account_transaction_original_pair CHECK ((original_currency_id IS NULL) = (original_amount IS NULL))
) PARTITION BY RANGE (transaction_date);
CREATE TABLE account.account_transaction_p2026_01 PARTITION OF account.account_transaction FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE account.account_transaction_p2026_02 PARTITION OF account.account_transaction FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE account.account_transaction_p2026_03 PARTITION OF account.account_transaction FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE account.account_transaction_p2026_04 PARTITION OF account.account_transaction FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE account.account_transaction_p2026_05 PARTITION OF account.account_transaction FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE account.account_transaction_p2026_06 PARTITION OF account.account_transaction FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE account.account_transaction_p2026_07 PARTITION OF account.account_transaction FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE account.account_transaction_p2026_08 PARTITION OF account.account_transaction FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE account.account_transaction_p2026_09 PARTITION OF account.account_transaction FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE account.account_transaction_p2026_10 PARTITION OF account.account_transaction FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE account.account_transaction_p2026_11 PARTITION OF account.account_transaction FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE account.account_transaction_p2026_12 PARTITION OF account.account_transaction FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE account.account_transaction_p2027_01 PARTITION OF account.account_transaction FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');
CREATE TABLE account.account_transaction_p2027_02 PARTITION OF account.account_transaction FOR VALUES FROM ('2027-02-01') TO ('2027-03-01');
CREATE TABLE account.account_transaction_p2027_03 PARTITION OF account.account_transaction FOR VALUES FROM ('2027-03-01') TO ('2027-04-01');
CREATE TABLE account.account_transaction_p2027_04 PARTITION OF account.account_transaction FOR VALUES FROM ('2027-04-01') TO ('2027-05-01');
CREATE TABLE account.account_transaction_p2027_05 PARTITION OF account.account_transaction FOR VALUES FROM ('2027-05-01') TO ('2027-06-01');
CREATE TABLE account.account_transaction_p2027_06 PARTITION OF account.account_transaction FOR VALUES FROM ('2027-06-01') TO ('2027-07-01');
CREATE TABLE account.account_transaction_p2027_07 PARTITION OF account.account_transaction FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');
CREATE TABLE account.account_transaction_p2027_08 PARTITION OF account.account_transaction FOR VALUES FROM ('2027-08-01') TO ('2027-09-01');
CREATE TABLE account.account_transaction_p2027_09 PARTITION OF account.account_transaction FOR VALUES FROM ('2027-09-01') TO ('2027-10-01');
CREATE TABLE account.account_transaction_p2027_10 PARTITION OF account.account_transaction FOR VALUES FROM ('2027-10-01') TO ('2027-11-01');
CREATE TABLE account.account_transaction_p2027_11 PARTITION OF account.account_transaction FOR VALUES FROM ('2027-11-01') TO ('2027-12-01');
CREATE TABLE account.account_transaction_p2027_12 PARTITION OF account.account_transaction FOR VALUES FROM ('2027-12-01') TO ('2028-01-01');
CREATE TABLE account.account_transaction_default PARTITION OF account.account_transaction DEFAULT;

CREATE TABLE account.hold (
    hold_id uuid NOT NULL DEFAULT uuidv7(),
    account_id uuid NOT NULL,
    card_authorization_id uuid,
    card_authorization_date date,
    hold_type varchar(30) NOT NULL,
    amount numeric(19,4) NOT NULL,
    placed_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz,
    released_at timestamptz,
    legal_document_reference varchar(255),
    reason varchar(255),
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_hold PRIMARY KEY (hold_id),
    CONSTRAINT uq_hold_card_authorization_id_card_authorization_date UNIQUE (card_authorization_id, card_authorization_date),
    CONSTRAINT ck_hold_hold_type CHECK (hold_type IN ('CARD_AUTHORIZATION', 'COURT_ORDER', 'TAX_AUTHORITY', 'COLLATERAL', 'BANK_INTERNAL')),
    CONSTRAINT ck_hold_status CHECK (status IN ('ACTIVE', 'RELEASED', 'EXPIRED', 'CAPTURED')),
    CONSTRAINT ck_hold_amount_positive CHECK (amount > 0),
    CONSTRAINT ck_hold_card_hold_source CHECK ((hold_type = 'CARD_AUTHORIZATION') = (card_authorization_id IS NOT NULL))
);

CREATE TABLE account.account_fee_charge (
    account_fee_charge_id uuid NOT NULL DEFAULT uuidv7(),
    account_id uuid NOT NULL,
    fee_type_id uuid NOT NULL,
    account_transaction_id uuid,
    account_transaction_date date,
    charge_date date NOT NULL,
    amount numeric(19,4) NOT NULL,
    waiver_reason varchar(255),
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_account_fee_charge PRIMARY KEY (account_fee_charge_id),
    CONSTRAINT uq_account_fee_charge_account_transaction_id_account_t_8e5020b1 UNIQUE (account_transaction_id, account_transaction_date),
    CONSTRAINT ck_account_fee_charge_status CHECK (status IN ('PENDING', 'CHARGED', 'WAIVED', 'REFUNDED')),
    CONSTRAINT ck_account_fee_charge_amount_non_negative CHECK (amount >= 0)
);

CREATE TABLE account.interest_accrual (
    interest_accrual_id uuid NOT NULL DEFAULT uuidv7(),
    account_id uuid NOT NULL,
    accrual_date date NOT NULL,
    balance_base numeric(19,4) NOT NULL,
    annual_rate numeric(9,6) NOT NULL,
    accrued_amount numeric(19,4) NOT NULL,
    withholding_tax_amount numeric(19,4) NOT NULL DEFAULT 0,
    is_capitalized boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_interest_accrual PRIMARY KEY (interest_accrual_id),
    CONSTRAINT uq_interest_accrual_account_id_accrual_date UNIQUE (account_id, accrual_date)
);

CREATE TABLE account.account_interest_rate (
    account_interest_rate_id uuid NOT NULL DEFAULT uuidv7(),
    account_id uuid NOT NULL,
    product_interest_rate_id uuid,
    annual_rate numeric(9,6) NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_account_interest_rate PRIMARY KEY (account_interest_rate_id),
    CONSTRAINT uq_account_interest_rate_account_id_effective_from UNIQUE (account_id, effective_from),
    CONSTRAINT ck_account_interest_rate_valid_period CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT ck_account_interest_rate_rate_non_negative CHECK (annual_rate >= 0)
);

CREATE TABLE account.term_deposit_term (
    term_deposit_term_id uuid NOT NULL DEFAULT uuidv7(),
    account_id uuid NOT NULL,
    payout_account_id uuid,
    term_months integer NOT NULL,
    start_date date NOT NULL,
    maturity_date date NOT NULL,
    interest_payment_frequency varchar(30) NOT NULL,
    auto_rollover boolean NOT NULL DEFAULT false,
    allows_top_up boolean NOT NULL DEFAULT false,
    allows_partial_withdrawal boolean NOT NULL DEFAULT false,
    early_withdrawal_rate numeric(9,6),
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_term_deposit_term PRIMARY KEY (term_deposit_term_id),
    CONSTRAINT uq_term_deposit_term_account_id UNIQUE (account_id),
    CONSTRAINT ck_term_deposit_term_interest_payment_frequency CHECK (interest_payment_frequency IN ('MONTHLY', 'QUARTERLY', 'AT_MATURITY')),
    CONSTRAINT ck_term_deposit_term_maturity_after_start CHECK (maturity_date > start_date),
    CONSTRAINT ck_term_deposit_term_term_positive CHECK (term_months > 0)
);

CREATE TABLE account.overdraft_facility (
    overdraft_facility_id uuid NOT NULL DEFAULT uuidv7(),
    account_id uuid NOT NULL,
    limit_amount numeric(19,4) NOT NULL,
    annual_rate numeric(9,6) NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_overdraft_facility PRIMARY KEY (overdraft_facility_id),
    CONSTRAINT ck_overdraft_facility_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'CLOSED')),
    CONSTRAINT ck_overdraft_facility_valid_period CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT ck_overdraft_facility_limit_positive CHECK (limit_amount > 0)
);

CREATE TABLE account.standing_order (
    standing_order_id uuid NOT NULL DEFAULT uuidv7(),
    debit_account_id uuid NOT NULL,
    beneficiary_id uuid NOT NULL,
    amount numeric(19,4) NOT NULL,
    frequency varchar(30) NOT NULL,
    execution_day integer,
    start_date date NOT NULL,
    end_date date,
    next_execution_date date,
    purpose varchar(255) NOT NULL,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_standing_order PRIMARY KEY (standing_order_id),
    CONSTRAINT ck_standing_order_frequency CHECK (frequency IN ('WEEKLY', 'MONTHLY', 'QUARTERLY')),
    CONSTRAINT ck_standing_order_status CHECK (status IN ('ACTIVE', 'PAUSED', 'CANCELLED', 'COMPLETED')),
    CONSTRAINT ck_standing_order_amount_positive CHECK (amount > 0),
    CONSTRAINT ck_standing_order_valid_period CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE TABLE account.account_limit (
    account_limit_id uuid NOT NULL DEFAULT uuidv7(),
    account_id uuid NOT NULL,
    channel_id uuid,
    limit_type varchar(30) NOT NULL,
    limit_amount numeric(19,4) NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_account_limit PRIMARY KEY (account_limit_id),
    CONSTRAINT uq_account_limit_account_id_channel_id_limit_type_effe_5a8e9787 UNIQUE NULLS NOT DISTINCT (account_id, channel_id, limit_type, effective_from),
    CONSTRAINT ck_account_limit_limit_type CHECK (limit_type IN ('DAILY_DEBIT', 'MONTHLY_DEBIT', 'SINGLE_TRANSACTION')),
    CONSTRAINT ck_account_limit_valid_period CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT ck_account_limit_limit_non_negative CHECK (limit_amount >= 0)
);

CREATE TABLE account.statement (
    statement_id uuid NOT NULL DEFAULT uuidv7(),
    account_id uuid NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL,
    opening_balance numeric(19,4) NOT NULL,
    closing_balance numeric(19,4) NOT NULL,
    total_debit numeric(19,4) NOT NULL,
    total_credit numeric(19,4) NOT NULL,
    generated_at timestamptz NOT NULL DEFAULT now(),
    delivery_channel varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_statement PRIMARY KEY (statement_id),
    CONSTRAINT uq_statement_account_id_period_start_period_end UNIQUE (account_id, period_start, period_end),
    CONSTRAINT ck_statement_delivery_channel CHECK (delivery_channel IN ('EMAIL', 'INTERNET_BANKING', 'BRANCH', 'POST')),
    CONSTRAINT ck_statement_valid_period CHECK (period_end >= period_start)
);

CREATE TABLE account.account_status_history (
    account_status_history_id uuid NOT NULL DEFAULT uuidv7(),
    account_id uuid NOT NULL,
    from_status varchar(30),
    to_status varchar(30) NOT NULL,
    changed_at timestamptz NOT NULL DEFAULT now(),
    reason_code varchar(30),
    comment text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_account_status_history PRIMARY KEY (account_status_history_id),
    CONSTRAINT ck_account_status_history_from_status CHECK (from_status IN ('PENDING', 'ACTIVE', 'DORMANT', 'FROZEN', 'CLOSED')),
    CONSTRAINT ck_account_status_history_to_status CHECK (to_status IN ('PENDING', 'ACTIVE', 'DORMANT', 'FROZEN', 'CLOSED')),
    CONSTRAINT ck_account_status_history_status_changed CHECK (from_status IS DISTINCT FROM to_status)
);

-- ============================================================
-- payment: Ödənişlər
-- ============================================================

CREATE TABLE payment.beneficiary (
    beneficiary_id uuid NOT NULL DEFAULT uuidv7(),
    customer_id uuid NOT NULL,
    bank_directory_id uuid,
    beneficiary_name varchar(255) NOT NULL,
    iban varchar(34),
    account_number varchar(100),
    tax_id varchar(100),
    alias varchar(100),
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_beneficiary PRIMARY KEY (beneficiary_id),
    CONSTRAINT ck_beneficiary_has_account CHECK (num_nonnulls(iban, account_number) >= 1)
);

CREATE TABLE payment.payment_order (
    payment_order_id uuid NOT NULL DEFAULT uuidv7(),
    debit_account_id uuid NOT NULL,
    beneficiary_id uuid,
    beneficiary_bank_id uuid,
    currency_id uuid NOT NULL,
    channel_id uuid NOT NULL,
    order_number varchar(30) NOT NULL,
    payment_type varchar(30) NOT NULL,
    amount numeric(19,4) NOT NULL,
    value_date date NOT NULL,
    purpose varchar(255) NOT NULL,
    budget_classification_code varchar(30),
    budget_level_code varchar(30),
    beneficiary_name varchar(255) NOT NULL,
    beneficiary_iban varchar(34),
    beneficiary_account_number varchar(100),
    beneficiary_tax_id varchar(100),
    charge_bearer varchar(30),
    priority varchar(30) NOT NULL DEFAULT 'NORMAL',
    submitted_at timestamptz NOT NULL DEFAULT now(),
    executed_at timestamptz,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_payment_order PRIMARY KEY (payment_order_id),
    CONSTRAINT uq_payment_order_order_number UNIQUE (order_number),
    CONSTRAINT ck_payment_order_payment_type CHECK (payment_type IN ('INTERNAL', 'AZIPS', 'XOHKS', 'SWIFT', 'BUDGET')),
    CONSTRAINT ck_payment_order_charge_bearer CHECK (charge_bearer IN ('OUR', 'SHA', 'BEN')),
    CONSTRAINT ck_payment_order_priority CHECK (priority IN ('NORMAL', 'URGENT')),
    CONSTRAINT ck_payment_order_status CHECK (status IN ('CREATED', 'PENDING_APPROVAL', 'SCREENING', 'SENT', 'EXECUTED', 'REJECTED', 'CANCELLED', 'RETURNED')),
    CONSTRAINT ck_payment_order_amount_positive CHECK (amount > 0),
    CONSTRAINT ck_payment_order_has_beneficiary_account CHECK (num_nonnulls(beneficiary_iban, beneficiary_account_number) >= 1),
    CONSTRAINT ck_payment_order_budget_fields CHECK (payment_type <> 'BUDGET' OR (budget_classification_code IS NOT NULL AND budget_level_code IS NOT NULL)),
    CONSTRAINT ck_payment_order_swift_charges CHECK (payment_type <> 'SWIFT' OR charge_bearer IS NOT NULL)
);

CREATE TABLE payment.payment_status_history (
    payment_status_history_id uuid NOT NULL DEFAULT uuidv7(),
    payment_order_id uuid NOT NULL,
    from_status varchar(30),
    to_status varchar(30) NOT NULL,
    changed_at timestamptz NOT NULL DEFAULT now(),
    reason_code varchar(30),
    comment text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_payment_status_history PRIMARY KEY (payment_status_history_id),
    CONSTRAINT ck_payment_status_history_from_status CHECK (from_status IN ('CREATED', 'PENDING_APPROVAL', 'SCREENING', 'SENT', 'EXECUTED', 'REJECTED', 'CANCELLED', 'RETURNED')),
    CONSTRAINT ck_payment_status_history_to_status CHECK (to_status IN ('CREATED', 'PENDING_APPROVAL', 'SCREENING', 'SENT', 'EXECUTED', 'REJECTED', 'CANCELLED', 'RETURNED')),
    CONSTRAINT ck_payment_status_history_status_changed CHECK (from_status IS DISTINCT FROM to_status)
);

CREATE TABLE payment.payment_message (
    payment_message_id uuid NOT NULL DEFAULT uuidv7(),
    payment_order_id uuid,
    direction varchar(30) NOT NULL,
    payment_system varchar(30) NOT NULL,
    message_type varchar(30) NOT NULL,
    message_reference varchar(30) NOT NULL,
    exchanged_at timestamptz NOT NULL,
    status varchar(30) NOT NULL,
    payload jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_payment_message PRIMARY KEY (payment_message_id),
    CONSTRAINT uq_payment_message_payment_system_direction_message_reference UNIQUE (payment_system, direction, message_reference),
    CONSTRAINT ck_payment_message_direction CHECK (direction IN ('OUTBOUND', 'INBOUND')),
    CONSTRAINT ck_payment_message_payment_system CHECK (payment_system IN ('AZIPS', 'XOHKS', 'SWIFT')),
    CONSTRAINT ck_payment_message_status CHECK (status IN ('QUEUED', 'SENT', 'ACKNOWLEDGED', 'REJECTED', 'RECEIVED', 'PROCESSED'))
);

CREATE TABLE payment.payment_return (
    payment_return_id uuid NOT NULL DEFAULT uuidv7(),
    payment_order_id uuid NOT NULL,
    return_reason_code varchar(30) NOT NULL,
    return_reason varchar(255),
    returned_amount numeric(19,4) NOT NULL,
    return_date date NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_payment_return PRIMARY KEY (payment_return_id),
    CONSTRAINT ck_payment_return_amount_positive CHECK (returned_amount > 0)
);

CREATE TABLE payment.fx_deal (
    fx_deal_id uuid NOT NULL DEFAULT uuidv7(),
    customer_id uuid NOT NULL,
    sell_account_id uuid NOT NULL,
    buy_account_id uuid NOT NULL,
    exchange_rate_id uuid,
    deal_number varchar(30) NOT NULL,
    sell_amount numeric(19,4) NOT NULL,
    buy_amount numeric(19,4) NOT NULL,
    applied_rate numeric(18,8) NOT NULL,
    deal_at timestamptz NOT NULL DEFAULT now(),
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_fx_deal PRIMARY KEY (fx_deal_id),
    CONSTRAINT uq_fx_deal_deal_number UNIQUE (deal_number),
    CONSTRAINT ck_fx_deal_status CHECK (status IN ('EXECUTED', 'CANCELLED')),
    CONSTRAINT ck_fx_deal_distinct_accounts CHECK (sell_account_id <> buy_account_id),
    CONSTRAINT ck_fx_deal_amounts_positive CHECK (sell_amount > 0 AND buy_amount > 0 AND applied_rate > 0)
);

-- ============================================================
-- card: Kartlar
-- ============================================================

CREATE TABLE card.merchant (
    merchant_id uuid NOT NULL DEFAULT uuidv7(),
    mcc_id uuid NOT NULL,
    country_id uuid NOT NULL,
    acquirer_id varchar(30) NOT NULL,
    merchant_code varchar(30) NOT NULL,
    name varchar(255) NOT NULL,
    city varchar(100),
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_merchant PRIMARY KEY (merchant_id),
    CONSTRAINT uq_merchant_acquirer_id_merchant_code UNIQUE (acquirer_id, merchant_code)
);

CREATE TABLE card.card (
    card_id uuid NOT NULL DEFAULT uuidv7(),
    account_id uuid NOT NULL,
    cardholder_party_id uuid NOT NULL,
    product_id uuid NOT NULL,
    replaced_card_id uuid,
    card_token varchar(30) NOT NULL,
    masked_pan varchar(100) NOT NULL,
    card_scheme varchar(30) NOT NULL,
    card_kind varchar(30) NOT NULL,
    form_factor varchar(30) NOT NULL,
    embossed_name varchar(255),
    expiry_date date NOT NULL,
    issued_date date NOT NULL,
    activated_at timestamptz,
    is_primary boolean NOT NULL DEFAULT true,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_card PRIMARY KEY (card_id),
    CONSTRAINT uq_card_replaced_card_id UNIQUE (replaced_card_id),
    CONSTRAINT uq_card_card_token UNIQUE (card_token),
    CONSTRAINT ck_card_card_scheme CHECK (card_scheme IN ('VISA', 'MASTERCARD')),
    CONSTRAINT ck_card_card_kind CHECK (card_kind IN ('DEBIT', 'CREDIT')),
    CONSTRAINT ck_card_form_factor CHECK (form_factor IN ('PHYSICAL', 'VIRTUAL')),
    CONSTRAINT ck_card_status CHECK (status IN ('ISSUED', 'ACTIVE', 'BLOCKED', 'LOST', 'STOLEN', 'EXPIRED', 'CLOSED')),
    CONSTRAINT ck_card_expiry_after_issue CHECK (expiry_date > issued_date)
);

CREATE TABLE card.card_status_history (
    card_status_history_id uuid NOT NULL DEFAULT uuidv7(),
    card_id uuid NOT NULL,
    from_status varchar(30),
    to_status varchar(30) NOT NULL,
    changed_at timestamptz NOT NULL DEFAULT now(),
    reason_code varchar(30),
    comment text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_card_status_history PRIMARY KEY (card_status_history_id),
    CONSTRAINT ck_card_status_history_from_status CHECK (from_status IN ('ISSUED', 'ACTIVE', 'BLOCKED', 'LOST', 'STOLEN', 'EXPIRED', 'CLOSED')),
    CONSTRAINT ck_card_status_history_to_status CHECK (to_status IN ('ISSUED', 'ACTIVE', 'BLOCKED', 'LOST', 'STOLEN', 'EXPIRED', 'CLOSED')),
    CONSTRAINT ck_card_status_history_status_changed CHECK (from_status IS DISTINCT FROM to_status)
);

CREATE TABLE card.card_limit (
    card_limit_id uuid NOT NULL DEFAULT uuidv7(),
    card_id uuid NOT NULL,
    limit_type varchar(30) NOT NULL,
    limit_amount numeric(19,4) NOT NULL,
    max_count integer,
    effective_from date NOT NULL,
    effective_to date,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_card_limit PRIMARY KEY (card_limit_id),
    CONSTRAINT uq_card_limit_card_id_limit_type_effective_from UNIQUE (card_id, limit_type, effective_from),
    CONSTRAINT ck_card_limit_limit_type CHECK (limit_type IN ('DAILY_CASH', 'DAILY_PURCHASE', 'DAILY_ECOMMERCE', 'MONTHLY_TOTAL', 'SINGLE_TRANSACTION')),
    CONSTRAINT ck_card_limit_limit_non_negative CHECK (limit_amount >= 0),
    CONSTRAINT ck_card_limit_valid_period CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE TABLE card.card_credit_line (
    card_credit_line_id uuid NOT NULL DEFAULT uuidv7(),
    account_id uuid NOT NULL,
    credit_limit numeric(19,4) NOT NULL,
    annual_rate numeric(9,6) NOT NULL,
    billing_day integer NOT NULL,
    grace_period_days integer NOT NULL,
    min_payment_percent numeric(5,2) NOT NULL,
    effective_from date NOT NULL,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_card_credit_line PRIMARY KEY (card_credit_line_id),
    CONSTRAINT uq_card_credit_line_account_id UNIQUE (account_id),
    CONSTRAINT ck_card_credit_line_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'CLOSED')),
    CONSTRAINT ck_card_credit_line_billing_day_range CHECK (billing_day BETWEEN 1 AND 28),
    CONSTRAINT ck_card_credit_line_limit_positive CHECK (credit_limit > 0),
    CONSTRAINT ck_card_credit_line_min_payment_range CHECK (min_payment_percent > 0 AND min_payment_percent <= 100)
);

CREATE TABLE card.card_authorization (
    card_authorization_id uuid NOT NULL DEFAULT uuidv7(),
    card_id uuid NOT NULL,
    currency_id uuid NOT NULL,
    merchant_id uuid,
    atm_id uuid,
    authorization_date date NOT NULL,
    authorized_at timestamptz NOT NULL,
    transaction_kind varchar(30) NOT NULL,
    amount numeric(19,4) NOT NULL,
    billing_amount numeric(19,4) NOT NULL,
    entry_mode varchar(30) NOT NULL,
    terminal_id varchar(30),
    rrn varchar(30) NOT NULL,
    stan varchar(30) NOT NULL,
    auth_code varchar(30),
    response_code varchar(30) NOT NULL,
    decision varchar(30) NOT NULL,
    decline_reason varchar(255),
    is_reversed boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_card_authorization PRIMARY KEY (card_authorization_id, authorization_date),
    CONSTRAINT ck_card_authorization_transaction_kind CHECK (transaction_kind IN ('PURCHASE', 'CASH_WITHDRAWAL', 'ECOMMERCE', 'REFUND', 'BALANCE_INQUIRY', 'P2P')),
    CONSTRAINT ck_card_authorization_entry_mode CHECK (entry_mode IN ('CHIP', 'CONTACTLESS', 'MAGSTRIPE', 'ECOMMERCE', 'MANUAL')),
    CONSTRAINT ck_card_authorization_decision CHECK (decision IN ('APPROVED', 'DECLINED')),
    CONSTRAINT ck_card_authorization_approved_has_code CHECK (decision <> 'APPROVED' OR auth_code IS NOT NULL),
    CONSTRAINT ck_card_authorization_amount_non_negative CHECK (amount >= 0 AND billing_amount >= 0)
) PARTITION BY RANGE (authorization_date);
CREATE TABLE card.card_authorization_p2026_01 PARTITION OF card.card_authorization FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE card.card_authorization_p2026_02 PARTITION OF card.card_authorization FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE card.card_authorization_p2026_03 PARTITION OF card.card_authorization FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE card.card_authorization_p2026_04 PARTITION OF card.card_authorization FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE card.card_authorization_p2026_05 PARTITION OF card.card_authorization FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE card.card_authorization_p2026_06 PARTITION OF card.card_authorization FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE card.card_authorization_p2026_07 PARTITION OF card.card_authorization FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE card.card_authorization_p2026_08 PARTITION OF card.card_authorization FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE card.card_authorization_p2026_09 PARTITION OF card.card_authorization FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE card.card_authorization_p2026_10 PARTITION OF card.card_authorization FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE card.card_authorization_p2026_11 PARTITION OF card.card_authorization FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE card.card_authorization_p2026_12 PARTITION OF card.card_authorization FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE card.card_authorization_p2027_01 PARTITION OF card.card_authorization FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');
CREATE TABLE card.card_authorization_p2027_02 PARTITION OF card.card_authorization FOR VALUES FROM ('2027-02-01') TO ('2027-03-01');
CREATE TABLE card.card_authorization_p2027_03 PARTITION OF card.card_authorization FOR VALUES FROM ('2027-03-01') TO ('2027-04-01');
CREATE TABLE card.card_authorization_p2027_04 PARTITION OF card.card_authorization FOR VALUES FROM ('2027-04-01') TO ('2027-05-01');
CREATE TABLE card.card_authorization_p2027_05 PARTITION OF card.card_authorization FOR VALUES FROM ('2027-05-01') TO ('2027-06-01');
CREATE TABLE card.card_authorization_p2027_06 PARTITION OF card.card_authorization FOR VALUES FROM ('2027-06-01') TO ('2027-07-01');
CREATE TABLE card.card_authorization_p2027_07 PARTITION OF card.card_authorization FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');
CREATE TABLE card.card_authorization_p2027_08 PARTITION OF card.card_authorization FOR VALUES FROM ('2027-08-01') TO ('2027-09-01');
CREATE TABLE card.card_authorization_p2027_09 PARTITION OF card.card_authorization FOR VALUES FROM ('2027-09-01') TO ('2027-10-01');
CREATE TABLE card.card_authorization_p2027_10 PARTITION OF card.card_authorization FOR VALUES FROM ('2027-10-01') TO ('2027-11-01');
CREATE TABLE card.card_authorization_p2027_11 PARTITION OF card.card_authorization FOR VALUES FROM ('2027-11-01') TO ('2027-12-01');
CREATE TABLE card.card_authorization_p2027_12 PARTITION OF card.card_authorization FOR VALUES FROM ('2027-12-01') TO ('2028-01-01');
CREATE TABLE card.card_authorization_default PARTITION OF card.card_authorization DEFAULT;

CREATE TABLE card.card_transaction (
    card_transaction_id uuid NOT NULL DEFAULT uuidv7(),
    card_id uuid NOT NULL,
    currency_id uuid NOT NULL,
    card_authorization_id uuid,
    card_authorization_date date,
    merchant_id uuid,
    transaction_date date NOT NULL,
    clearing_date date NOT NULL,
    settlement_date date,
    transaction_kind varchar(30) NOT NULL,
    amount numeric(19,4) NOT NULL,
    billing_amount numeric(19,4) NOT NULL,
    interchange_fee numeric(19,4),
    rrn varchar(30) NOT NULL,
    arn varchar(30),
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_card_transaction PRIMARY KEY (card_transaction_id, transaction_date),
    CONSTRAINT ck_card_transaction_transaction_kind CHECK (transaction_kind IN ('PURCHASE', 'CASH_WITHDRAWAL', 'ECOMMERCE', 'REFUND', 'BALANCE_INQUIRY', 'P2P')),
    CONSTRAINT ck_card_transaction_status CHECK (status IN ('CLEARED', 'POSTED', 'DISPUTED', 'REVERSED')),
    CONSTRAINT ck_card_transaction_amount_non_negative CHECK (amount >= 0 AND billing_amount >= 0)
) PARTITION BY RANGE (transaction_date);
CREATE TABLE card.card_transaction_p2026_01 PARTITION OF card.card_transaction FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE card.card_transaction_p2026_02 PARTITION OF card.card_transaction FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE card.card_transaction_p2026_03 PARTITION OF card.card_transaction FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE card.card_transaction_p2026_04 PARTITION OF card.card_transaction FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE card.card_transaction_p2026_05 PARTITION OF card.card_transaction FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE card.card_transaction_p2026_06 PARTITION OF card.card_transaction FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE card.card_transaction_p2026_07 PARTITION OF card.card_transaction FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE card.card_transaction_p2026_08 PARTITION OF card.card_transaction FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE card.card_transaction_p2026_09 PARTITION OF card.card_transaction FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE card.card_transaction_p2026_10 PARTITION OF card.card_transaction FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE card.card_transaction_p2026_11 PARTITION OF card.card_transaction FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE card.card_transaction_p2026_12 PARTITION OF card.card_transaction FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE card.card_transaction_p2027_01 PARTITION OF card.card_transaction FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');
CREATE TABLE card.card_transaction_p2027_02 PARTITION OF card.card_transaction FOR VALUES FROM ('2027-02-01') TO ('2027-03-01');
CREATE TABLE card.card_transaction_p2027_03 PARTITION OF card.card_transaction FOR VALUES FROM ('2027-03-01') TO ('2027-04-01');
CREATE TABLE card.card_transaction_p2027_04 PARTITION OF card.card_transaction FOR VALUES FROM ('2027-04-01') TO ('2027-05-01');
CREATE TABLE card.card_transaction_p2027_05 PARTITION OF card.card_transaction FOR VALUES FROM ('2027-05-01') TO ('2027-06-01');
CREATE TABLE card.card_transaction_p2027_06 PARTITION OF card.card_transaction FOR VALUES FROM ('2027-06-01') TO ('2027-07-01');
CREATE TABLE card.card_transaction_p2027_07 PARTITION OF card.card_transaction FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');
CREATE TABLE card.card_transaction_p2027_08 PARTITION OF card.card_transaction FOR VALUES FROM ('2027-08-01') TO ('2027-09-01');
CREATE TABLE card.card_transaction_p2027_09 PARTITION OF card.card_transaction FOR VALUES FROM ('2027-09-01') TO ('2027-10-01');
CREATE TABLE card.card_transaction_p2027_10 PARTITION OF card.card_transaction FOR VALUES FROM ('2027-10-01') TO ('2027-11-01');
CREATE TABLE card.card_transaction_p2027_11 PARTITION OF card.card_transaction FOR VALUES FROM ('2027-11-01') TO ('2027-12-01');
CREATE TABLE card.card_transaction_p2027_12 PARTITION OF card.card_transaction FOR VALUES FROM ('2027-12-01') TO ('2028-01-01');
CREATE TABLE card.card_transaction_default PARTITION OF card.card_transaction DEFAULT;

CREATE TABLE card.card_billing_statement (
    card_billing_statement_id uuid NOT NULL DEFAULT uuidv7(),
    card_credit_line_id uuid NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL,
    due_date date NOT NULL,
    opening_balance numeric(19,4) NOT NULL,
    total_purchases numeric(19,4) NOT NULL,
    total_payments numeric(19,4) NOT NULL,
    interest_charged numeric(19,4) NOT NULL DEFAULT 0,
    closing_balance numeric(19,4) NOT NULL,
    minimum_payment numeric(19,4) NOT NULL,
    paid_amount numeric(19,4) NOT NULL DEFAULT 0,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_card_billing_statement PRIMARY KEY (card_billing_statement_id),
    CONSTRAINT uq_card_billing_statement_card_credit_line_id_period_start UNIQUE (card_credit_line_id, period_start),
    CONSTRAINT ck_card_billing_statement_status CHECK (status IN ('OPEN', 'PAID', 'PARTIALLY_PAID', 'OVERDUE')),
    CONSTRAINT ck_card_billing_statement_valid_period CHECK (period_end >= period_start AND due_date >= period_end),
    CONSTRAINT ck_card_billing_statement_minimum_le_balance CHECK (minimum_payment <= GREATEST(closing_balance, 0))
);

-- ============================================================
-- loan: Kreditlər
-- ============================================================

CREATE TABLE loan.credit_application (
    credit_application_id uuid NOT NULL DEFAULT uuidv7(),
    customer_id uuid NOT NULL,
    product_id uuid NOT NULL,
    currency_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    loan_officer_id uuid,
    application_number varchar(30) NOT NULL,
    requested_amount numeric(19,4) NOT NULL,
    requested_term_months integer NOT NULL,
    purpose varchar(255) NOT NULL,
    submitted_at timestamptz NOT NULL DEFAULT now(),
    decision_at timestamptz,
    approved_amount numeric(19,4),
    approved_term_months integer,
    approved_rate numeric(9,6),
    rejection_reason varchar(255),
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_credit_application PRIMARY KEY (credit_application_id),
    CONSTRAINT uq_credit_application_application_number UNIQUE (application_number),
    CONSTRAINT ck_credit_application_status CHECK (status IN ('DRAFT', 'SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'CANCELLED', 'CONTRACTED')),
    CONSTRAINT ck_credit_application_amount_positive CHECK (requested_amount > 0 AND requested_term_months > 0),
    CONSTRAINT ck_credit_application_approved_terms CHECK (status NOT IN ('APPROVED', 'CONTRACTED') OR (approved_amount IS NOT NULL AND approved_term_months IS NOT NULL AND approved_rate IS NOT NULL))
);

CREATE TABLE loan.credit_bureau_check (
    credit_bureau_check_id uuid NOT NULL DEFAULT uuidv7(),
    party_id uuid NOT NULL,
    credit_application_id uuid,
    requested_at timestamptz NOT NULL DEFAULT now(),
    bureau_reference varchar(30),
    credit_score integer,
    total_outstanding_debt numeric(19,4),
    active_loan_count integer,
    max_days_past_due integer,
    result varchar(30) NOT NULL,
    report jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_credit_bureau_check PRIMARY KEY (credit_bureau_check_id),
    CONSTRAINT ck_credit_bureau_check_result CHECK (result IN ('SUCCESS', 'NO_HIT', 'ERROR'))
);

CREATE TABLE loan.credit_facility (
    credit_facility_id uuid NOT NULL DEFAULT uuidv7(),
    customer_id uuid NOT NULL,
    credit_application_id uuid,
    currency_id uuid NOT NULL,
    facility_number varchar(30) NOT NULL,
    facility_type varchar(30) NOT NULL,
    limit_amount numeric(19,4) NOT NULL,
    available_from date NOT NULL,
    available_until date NOT NULL,
    maturity_date date NOT NULL,
    commitment_fee_rate numeric(9,6),
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_credit_facility PRIMARY KEY (credit_facility_id),
    CONSTRAINT uq_credit_facility_credit_application_id UNIQUE (credit_application_id),
    CONSTRAINT uq_credit_facility_facility_number UNIQUE (facility_number),
    CONSTRAINT ck_credit_facility_facility_type CHECK (facility_type IN ('REVOLVING', 'NON_REVOLVING')),
    CONSTRAINT ck_credit_facility_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'EXPIRED', 'CLOSED')),
    CONSTRAINT ck_credit_facility_limit_positive CHECK (limit_amount > 0),
    CONSTRAINT ck_credit_facility_date_order CHECK (available_from <= available_until AND available_until <= maturity_date)
);

CREATE TABLE loan.loan (
    loan_id uuid NOT NULL DEFAULT uuidv7(),
    customer_id uuid NOT NULL,
    product_id uuid NOT NULL,
    currency_id uuid NOT NULL,
    credit_application_id uuid,
    credit_facility_id uuid,
    settlement_account_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    loan_number varchar(30) NOT NULL,
    loan_type varchar(30) NOT NULL,
    principal_amount numeric(19,4) NOT NULL,
    annual_rate numeric(9,6) NOT NULL,
    rate_type varchar(30) NOT NULL,
    term_months integer NOT NULL,
    contract_date date NOT NULL,
    start_date date NOT NULL,
    maturity_date date NOT NULL,
    repayment_method varchar(30) NOT NULL,
    payment_day integer NOT NULL,
    penalty_daily_rate numeric(9,6) NOT NULL,
    penalty_base varchar(30) NOT NULL,
    outstanding_principal numeric(19,4) NOT NULL,
    days_past_due integer NOT NULL DEFAULT 0,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_loan PRIMARY KEY (loan_id),
    CONSTRAINT uq_loan_credit_application_id UNIQUE (credit_application_id),
    CONSTRAINT uq_loan_loan_number UNIQUE (loan_number),
    CONSTRAINT ck_loan_loan_type CHECK (loan_type IN ('CONSUMER', 'MORTGAGE', 'BUSINESS', 'FACILITY_TRANCHE')),
    CONSTRAINT ck_loan_rate_type CHECK (rate_type IN ('FIXED', 'FLOATING')),
    CONSTRAINT ck_loan_repayment_method CHECK (repayment_method IN ('ANNUITY', 'DIFFERENTIATED', 'BULLET')),
    CONSTRAINT ck_loan_penalty_base CHECK (penalty_base IN ('OVERDUE_PRINCIPAL', 'OVERDUE_PRINCIPAL_AND_INTEREST')),
    CONSTRAINT ck_loan_status CHECK (status IN ('APPROVED', 'ACTIVE', 'OVERDUE', 'RESTRUCTURED', 'WRITTEN_OFF', 'CLOSED')),
    CONSTRAINT ck_loan_amounts_valid CHECK (principal_amount > 0 AND outstanding_principal >= 0 AND outstanding_principal <= principal_amount),
    CONSTRAINT ck_loan_date_order CHECK (contract_date <= start_date AND start_date < maturity_date),
    CONSTRAINT ck_loan_payment_day_range CHECK (payment_day BETWEEN 1 AND 28),
    CONSTRAINT ck_loan_tranche_has_facility CHECK ((loan_type = 'FACILITY_TRANCHE') = (credit_facility_id IS NOT NULL)),
    CONSTRAINT ck_loan_rates_non_negative CHECK (annual_rate >= 0 AND penalty_daily_rate >= 0)
);

CREATE TABLE loan.loan_disbursement (
    loan_disbursement_id uuid NOT NULL DEFAULT uuidv7(),
    loan_id uuid NOT NULL,
    target_account_id uuid NOT NULL,
    disbursement_date date NOT NULL,
    amount numeric(19,4) NOT NULL,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_loan_disbursement PRIMARY KEY (loan_disbursement_id),
    CONSTRAINT ck_loan_disbursement_status CHECK (status IN ('PENDING', 'COMPLETED', 'CANCELLED')),
    CONSTRAINT ck_loan_disbursement_amount_positive CHECK (amount > 0)
);

CREATE TABLE loan.repayment_schedule (
    repayment_schedule_id uuid NOT NULL DEFAULT uuidv7(),
    loan_id uuid NOT NULL,
    schedule_version integer NOT NULL DEFAULT 1,
    installment_number integer NOT NULL,
    due_date date NOT NULL,
    principal_due numeric(19,4) NOT NULL,
    interest_due numeric(19,4) NOT NULL,
    fee_due numeric(19,4) NOT NULL DEFAULT 0,
    principal_paid numeric(19,4) NOT NULL DEFAULT 0,
    interest_paid numeric(19,4) NOT NULL DEFAULT 0,
    fee_paid numeric(19,4) NOT NULL DEFAULT 0,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_repayment_schedule PRIMARY KEY (repayment_schedule_id),
    CONSTRAINT uq_repayment_schedule_loan_id_schedule_version_install_fd0a8e19 UNIQUE (loan_id, schedule_version, installment_number),
    CONSTRAINT ck_repayment_schedule_status CHECK (status IN ('PENDING', 'PARTIALLY_PAID', 'PAID', 'OVERDUE', 'SUPERSEDED')),
    CONSTRAINT ck_repayment_schedule_paid_le_due CHECK (principal_paid <= principal_due AND interest_paid <= interest_due AND fee_paid <= fee_due),
    CONSTRAINT ck_repayment_schedule_amounts_non_negative CHECK (principal_due >= 0 AND interest_due >= 0 AND fee_due >= 0)
);

CREATE TABLE loan.loan_repayment (
    loan_repayment_id uuid NOT NULL DEFAULT uuidv7(),
    loan_id uuid NOT NULL,
    source_account_id uuid,
    payment_date date NOT NULL,
    value_date date NOT NULL,
    amount numeric(19,4) NOT NULL,
    is_early_repayment boolean NOT NULL DEFAULT false,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_loan_repayment PRIMARY KEY (loan_repayment_id),
    CONSTRAINT ck_loan_repayment_status CHECK (status IN ('POSTED', 'REVERSED')),
    CONSTRAINT ck_loan_repayment_amount_positive CHECK (amount > 0)
);

CREATE TABLE loan.repayment_allocation (
    repayment_allocation_id uuid NOT NULL DEFAULT uuidv7(),
    loan_repayment_id uuid NOT NULL,
    repayment_schedule_id uuid,
    component varchar(30) NOT NULL,
    amount numeric(19,4) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_repayment_allocation PRIMARY KEY (repayment_allocation_id),
    CONSTRAINT ck_repayment_allocation_component CHECK (component IN ('PENALTY', 'INTEREST', 'PRINCIPAL', 'FEE')),
    CONSTRAINT ck_repayment_allocation_amount_positive CHECK (amount > 0)
);

CREATE TABLE loan.loan_penalty_charge (
    loan_penalty_charge_id uuid NOT NULL DEFAULT uuidv7(),
    repayment_schedule_id uuid NOT NULL,
    penalty_date date NOT NULL,
    overdue_amount numeric(19,4) NOT NULL,
    daily_rate numeric(9,6) NOT NULL,
    penalty_amount numeric(19,4) NOT NULL,
    paid_amount numeric(19,4) NOT NULL DEFAULT 0,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_loan_penalty_charge PRIMARY KEY (loan_penalty_charge_id),
    CONSTRAINT uq_loan_penalty_charge_repayment_schedule_id_penalty_date UNIQUE (repayment_schedule_id, penalty_date),
    CONSTRAINT ck_loan_penalty_charge_status CHECK (status IN ('ACCRUED', 'PAID', 'WAIVED')),
    CONSTRAINT ck_loan_penalty_charge_amounts_valid CHECK (overdue_amount > 0 AND penalty_amount >= 0 AND paid_amount <= penalty_amount)
);

CREATE TABLE loan.collateral (
    collateral_id uuid NOT NULL DEFAULT uuidv7(),
    collateral_type_id uuid NOT NULL,
    owner_party_id uuid NOT NULL,
    currency_id uuid NOT NULL,
    pledged_account_id uuid,
    description text NOT NULL,
    registry_number varchar(100),
    registry_authority varchar(255),
    location_address varchar(255),
    initial_value numeric(19,4) NOT NULL,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_collateral PRIMARY KEY (collateral_id),
    CONSTRAINT ck_collateral_status CHECK (status IN ('ACTIVE', 'RELEASED', 'FORECLOSED')),
    CONSTRAINT ck_collateral_value_positive CHECK (initial_value > 0)
);

CREATE TABLE loan.collateral_valuation (
    collateral_valuation_id uuid NOT NULL DEFAULT uuidv7(),
    collateral_id uuid NOT NULL,
    valuation_date date NOT NULL,
    market_value numeric(19,4) NOT NULL,
    liquidation_value numeric(19,4) NOT NULL,
    valuation_method varchar(30) NOT NULL,
    valuer_name varchar(255) NOT NULL,
    next_valuation_date date,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_collateral_valuation PRIMARY KEY (collateral_valuation_id),
    CONSTRAINT uq_collateral_valuation_collateral_id_valuation_date UNIQUE (collateral_id, valuation_date),
    CONSTRAINT ck_collateral_valuation_valuation_method CHECK (valuation_method IN ('MARKET', 'INCOME', 'COST')),
    CONSTRAINT ck_collateral_valuation_values_valid CHECK (market_value > 0 AND liquidation_value > 0 AND liquidation_value <= market_value)
);

CREATE TABLE loan.loan_collateral (
    loan_collateral_id uuid NOT NULL DEFAULT uuidv7(),
    collateral_id uuid NOT NULL,
    loan_id uuid,
    credit_facility_id uuid,
    pledge_agreement_number varchar(30) NOT NULL,
    secured_amount numeric(19,4) NOT NULL,
    priority_rank integer NOT NULL DEFAULT 1,
    effective_from date NOT NULL,
    effective_to date,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_loan_collateral PRIMARY KEY (loan_collateral_id),
    CONSTRAINT ck_loan_collateral_loan_or_facility CHECK (num_nonnulls(loan_id, credit_facility_id) = 1),
    CONSTRAINT ck_loan_collateral_valid_period CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT ck_loan_collateral_amount_positive CHECK (secured_amount > 0)
);

CREATE TABLE loan.loan_guarantee (
    loan_guarantee_id uuid NOT NULL DEFAULT uuidv7(),
    guarantor_party_id uuid NOT NULL,
    loan_id uuid,
    credit_facility_id uuid,
    guarantee_agreement_number varchar(30) NOT NULL,
    guaranteed_amount numeric(19,4) NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_loan_guarantee PRIMARY KEY (loan_guarantee_id),
    CONSTRAINT ck_loan_guarantee_status CHECK (status IN ('ACTIVE', 'RELEASED', 'CALLED')),
    CONSTRAINT ck_loan_guarantee_loan_or_facility CHECK (num_nonnulls(loan_id, credit_facility_id) = 1),
    CONSTRAINT ck_loan_guarantee_valid_period CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT ck_loan_guarantee_amount_positive CHECK (guaranteed_amount > 0)
);

CREATE TABLE loan.covenant (
    covenant_id uuid NOT NULL DEFAULT uuidv7(),
    loan_id uuid,
    credit_facility_id uuid,
    covenant_type varchar(30) NOT NULL,
    description text NOT NULL,
    metric varchar(100),
    threshold_operator varchar(30),
    threshold_value numeric(18,8),
    test_frequency varchar(30) NOT NULL,
    last_tested_date date,
    last_test_result varchar(30),
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_covenant PRIMARY KEY (covenant_id),
    CONSTRAINT ck_covenant_covenant_type CHECK (covenant_type IN ('FINANCIAL', 'NON_FINANCIAL')),
    CONSTRAINT ck_covenant_threshold_operator CHECK (threshold_operator IN ('LT', 'LE', 'GT', 'GE', 'EQ')),
    CONSTRAINT ck_covenant_test_frequency CHECK (test_frequency IN ('MONTHLY', 'QUARTERLY', 'ANNUAL')),
    CONSTRAINT ck_covenant_last_test_result CHECK (last_test_result IN ('MET', 'BREACHED', 'WAIVED')),
    CONSTRAINT ck_covenant_status CHECK (status IN ('ACTIVE', 'CLOSED')),
    CONSTRAINT ck_covenant_loan_or_facility CHECK (num_nonnulls(loan_id, credit_facility_id) = 1),
    CONSTRAINT ck_covenant_financial_threshold CHECK (covenant_type <> 'FINANCIAL' OR (metric IS NOT NULL AND threshold_operator IS NOT NULL AND threshold_value IS NOT NULL))
);

CREATE TABLE loan.loan_restructuring (
    loan_restructuring_id uuid NOT NULL DEFAULT uuidv7(),
    loan_id uuid NOT NULL,
    approved_by_employee_id uuid,
    effective_date date NOT NULL,
    reason varchar(255) NOT NULL,
    old_annual_rate numeric(9,6) NOT NULL,
    new_annual_rate numeric(9,6) NOT NULL,
    old_maturity_date date NOT NULL,
    new_maturity_date date NOT NULL,
    new_schedule_version integer NOT NULL,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_loan_restructuring PRIMARY KEY (loan_restructuring_id),
    CONSTRAINT ck_loan_restructuring_status CHECK (status IN ('PROPOSED', 'APPROVED', 'APPLIED', 'REJECTED'))
);

CREATE TABLE loan.loan_status_history (
    loan_status_history_id uuid NOT NULL DEFAULT uuidv7(),
    loan_id uuid NOT NULL,
    from_status varchar(30),
    to_status varchar(30) NOT NULL,
    changed_at timestamptz NOT NULL DEFAULT now(),
    reason_code varchar(30),
    comment text,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_loan_status_history PRIMARY KEY (loan_status_history_id),
    CONSTRAINT ck_loan_status_history_from_status CHECK (from_status IN ('APPROVED', 'ACTIVE', 'OVERDUE', 'RESTRUCTURED', 'WRITTEN_OFF', 'CLOSED')),
    CONSTRAINT ck_loan_status_history_to_status CHECK (to_status IN ('APPROVED', 'ACTIVE', 'OVERDUE', 'RESTRUCTURED', 'WRITTEN_OFF', 'CLOSED')),
    CONSTRAINT ck_loan_status_history_status_changed CHECK (from_status IS DISTINCT FROM to_status)
);

-- ============================================================
-- ledger: Baş kitab (sadələşdirilmiş)
-- ============================================================

CREATE TABLE ledger.gl_account (
    gl_account_id uuid NOT NULL DEFAULT uuidv7(),
    parent_gl_account_id uuid,
    account_code varchar(30) NOT NULL,
    name varchar(255) NOT NULL,
    account_class varchar(30) NOT NULL,
    normal_balance varchar(30) NOT NULL,
    is_postable boolean NOT NULL DEFAULT true,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_gl_account PRIMARY KEY (gl_account_id),
    CONSTRAINT uq_gl_account_account_code UNIQUE (account_code),
    CONSTRAINT ck_gl_account_account_class CHECK (account_class IN ('ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE', 'OFF_BALANCE')),
    CONSTRAINT ck_gl_account_normal_balance CHECK (normal_balance IN ('DEBIT', 'CREDIT'))
);

CREATE TABLE ledger.accounting_period (
    accounting_period_id uuid NOT NULL DEFAULT uuidv7(),
    period_code varchar(30) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    status varchar(30) NOT NULL,
    closed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_accounting_period PRIMARY KEY (accounting_period_id),
    CONSTRAINT uq_accounting_period_period_code UNIQUE (period_code),
    CONSTRAINT ck_accounting_period_status CHECK (status IN ('OPEN', 'CLOSING', 'CLOSED')),
    CONSTRAINT ck_accounting_period_valid_period CHECK (end_date >= start_date)
);

CREATE TABLE ledger.posting_rule (
    posting_rule_id uuid NOT NULL DEFAULT uuidv7(),
    transaction_type_id uuid NOT NULL,
    product_id uuid,
    debit_gl_account_id uuid NOT NULL,
    credit_gl_account_id uuid NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    description varchar(255),
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_posting_rule PRIMARY KEY (posting_rule_id),
    CONSTRAINT uq_posting_rule_transaction_type_id_product_id_effective_from UNIQUE NULLS NOT DISTINCT (transaction_type_id, product_id, effective_from),
    CONSTRAINT ck_posting_rule_distinct_accounts CHECK (debit_gl_account_id <> credit_gl_account_id),
    CONSTRAINT ck_posting_rule_valid_period CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE TABLE ledger.journal_entry (
    journal_entry_id uuid NOT NULL DEFAULT uuidv7(),
    accounting_period_id uuid NOT NULL,
    account_transaction_id uuid,
    account_transaction_date date,
    entry_number varchar(30) NOT NULL,
    entry_date date NOT NULL,
    description varchar(255) NOT NULL,
    status varchar(30) NOT NULL,
    posted_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_journal_entry PRIMARY KEY (journal_entry_id),
    CONSTRAINT uq_journal_entry_entry_number UNIQUE (entry_number),
    CONSTRAINT ck_journal_entry_status CHECK (status IN ('DRAFT', 'POSTED', 'REVERSED')),
    CONSTRAINT ck_journal_entry_posted_has_time CHECK (status = 'DRAFT' OR posted_at IS NOT NULL)
);

CREATE TABLE ledger.journal_entry_line (
    journal_entry_line_id uuid NOT NULL DEFAULT uuidv7(),
    journal_entry_id uuid NOT NULL,
    gl_account_id uuid NOT NULL,
    currency_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    entry_date date NOT NULL,
    line_number integer NOT NULL,
    side varchar(30) NOT NULL,
    amount numeric(19,4) NOT NULL,
    amount_azn numeric(19,4) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_journal_entry_line PRIMARY KEY (journal_entry_line_id, entry_date),
    CONSTRAINT uq_journal_entry_line_journal_entry_id_line_number_entry_date UNIQUE (journal_entry_id, line_number, entry_date),
    CONSTRAINT ck_journal_entry_line_side CHECK (side IN ('DEBIT', 'CREDIT')),
    CONSTRAINT ck_journal_entry_line_amounts_positive CHECK (amount > 0 AND amount_azn > 0)
) PARTITION BY RANGE (entry_date);
CREATE TABLE ledger.journal_entry_line_p2026_01 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE ledger.journal_entry_line_p2026_02 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE ledger.journal_entry_line_p2026_03 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE ledger.journal_entry_line_p2026_04 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE ledger.journal_entry_line_p2026_05 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE ledger.journal_entry_line_p2026_06 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE ledger.journal_entry_line_p2026_07 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE ledger.journal_entry_line_p2026_08 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE ledger.journal_entry_line_p2026_09 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE ledger.journal_entry_line_p2026_10 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE ledger.journal_entry_line_p2026_11 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE ledger.journal_entry_line_p2026_12 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE ledger.journal_entry_line_p2027_01 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');
CREATE TABLE ledger.journal_entry_line_p2027_02 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2027-02-01') TO ('2027-03-01');
CREATE TABLE ledger.journal_entry_line_p2027_03 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2027-03-01') TO ('2027-04-01');
CREATE TABLE ledger.journal_entry_line_p2027_04 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2027-04-01') TO ('2027-05-01');
CREATE TABLE ledger.journal_entry_line_p2027_05 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2027-05-01') TO ('2027-06-01');
CREATE TABLE ledger.journal_entry_line_p2027_06 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2027-06-01') TO ('2027-07-01');
CREATE TABLE ledger.journal_entry_line_p2027_07 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');
CREATE TABLE ledger.journal_entry_line_p2027_08 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2027-08-01') TO ('2027-09-01');
CREATE TABLE ledger.journal_entry_line_p2027_09 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2027-09-01') TO ('2027-10-01');
CREATE TABLE ledger.journal_entry_line_p2027_10 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2027-10-01') TO ('2027-11-01');
CREATE TABLE ledger.journal_entry_line_p2027_11 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2027-11-01') TO ('2027-12-01');
CREATE TABLE ledger.journal_entry_line_p2027_12 PARTITION OF ledger.journal_entry_line FOR VALUES FROM ('2027-12-01') TO ('2028-01-01');
CREATE TABLE ledger.journal_entry_line_default PARTITION OF ledger.journal_entry_line DEFAULT;

-- ============================================================
-- compliance: Uyğunluq və AML (sadələşdirilmiş)
-- ============================================================

CREATE TABLE compliance.screening_check (
    screening_check_id uuid NOT NULL DEFAULT uuidv7(),
    party_id uuid,
    payment_order_id uuid,
    screened_at timestamptz NOT NULL DEFAULT now(),
    list_name varchar(30) NOT NULL,
    screened_name varchar(255) NOT NULL,
    match_score numeric(5,2),
    result varchar(30) NOT NULL,
    decided_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_screening_check PRIMARY KEY (screening_check_id),
    CONSTRAINT ck_screening_check_list_name CHECK (list_name IN ('UN', 'EU', 'OFAC', 'UK_HMT', 'LOCAL', 'PEP')),
    CONSTRAINT ck_screening_check_result CHECK (result IN ('NO_MATCH', 'POTENTIAL_MATCH', 'TRUE_MATCH', 'FALSE_POSITIVE')),
    CONSTRAINT ck_screening_check_has_subject CHECK (num_nonnulls(party_id, payment_order_id) >= 1)
);

CREATE TABLE compliance.aml_case (
    aml_case_id uuid NOT NULL DEFAULT uuidv7(),
    party_id uuid NOT NULL,
    assigned_employee_id uuid,
    case_number varchar(30) NOT NULL,
    opened_at timestamptz NOT NULL DEFAULT now(),
    closed_at timestamptz,
    priority varchar(30) NOT NULL,
    outcome varchar(30),
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_aml_case PRIMARY KEY (aml_case_id),
    CONSTRAINT uq_aml_case_case_number UNIQUE (case_number),
    CONSTRAINT ck_aml_case_priority CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH')),
    CONSTRAINT ck_aml_case_outcome CHECK (outcome IN ('NO_ACTION', 'REPORTED_TO_FMS', 'ACCOUNT_RESTRICTED', 'RELATIONSHIP_TERMINATED')),
    CONSTRAINT ck_aml_case_status CHECK (status IN ('OPEN', 'IN_PROGRESS', 'CLOSED')),
    CONSTRAINT ck_aml_case_closed_consistency CHECK ((status = 'CLOSED') = (closed_at IS NOT NULL AND outcome IS NOT NULL))
);

CREATE TABLE compliance.aml_alert (
    aml_alert_id uuid NOT NULL DEFAULT uuidv7(),
    party_id uuid NOT NULL,
    account_transaction_id uuid,
    account_transaction_date date,
    screening_check_id uuid,
    aml_case_id uuid,
    alert_number varchar(30) NOT NULL,
    rule_code varchar(30) NOT NULL,
    risk_score integer NOT NULL,
    generated_at timestamptz NOT NULL DEFAULT now(),
    description varchar(255),
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_aml_alert PRIMARY KEY (aml_alert_id),
    CONSTRAINT uq_aml_alert_alert_number UNIQUE (alert_number),
    CONSTRAINT ck_aml_alert_status CHECK (status IN ('NEW', 'UNDER_REVIEW', 'ESCALATED', 'CLOSED_FALSE_POSITIVE', 'CLOSED_CONFIRMED')),
    CONSTRAINT ck_aml_alert_score_range CHECK (risk_score BETWEEN 0 AND 100)
);

CREATE TABLE compliance.regulatory_report (
    regulatory_report_id uuid NOT NULL DEFAULT uuidv7(),
    aml_case_id uuid,
    report_number varchar(30) NOT NULL,
    report_type varchar(30) NOT NULL,
    regulator varchar(30) NOT NULL,
    period_start date,
    period_end date,
    submitted_at timestamptz,
    regulator_reference varchar(30),
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_regulatory_report PRIMARY KEY (regulatory_report_id),
    CONSTRAINT uq_regulatory_report_report_number UNIQUE (report_number),
    CONSTRAINT ck_regulatory_report_report_type CHECK (report_type IN ('SUSPICIOUS_TRANSACTION', 'THRESHOLD_TRANSACTION', 'CBAR_PERIODIC')),
    CONSTRAINT ck_regulatory_report_regulator CHECK (regulator IN ('FMS', 'CBAR')),
    CONSTRAINT ck_regulatory_report_status CHECK (status IN ('DRAFT', 'SUBMITTED', 'ACCEPTED', 'REJECTED')),
    CONSTRAINT ck_regulatory_report_submitted_has_time CHECK (status = 'DRAFT' OR submitted_at IS NOT NULL)
);

CREATE TABLE compliance.regulatory_report_item (
    regulatory_report_item_id uuid NOT NULL DEFAULT uuidv7(),
    regulatory_report_id uuid NOT NULL,
    account_transaction_id uuid,
    account_transaction_date date,
    party_id uuid,
    item_number integer NOT NULL,
    amount_azn numeric(19,4),
    note varchar(255),
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(100) NOT NULL DEFAULT current_user,
    updated_at timestamptz,
    updated_by varchar(100),
    CONSTRAINT pk_regulatory_report_item PRIMARY KEY (regulatory_report_item_id),
    CONSTRAINT ck_regulatory_report_item_has_subject CHECK (num_nonnulls(account_transaction_id, party_id) >= 1)
);

-- ============================================================
-- Xarici açarlar
-- ============================================================
ALTER TABLE ref.exchange_rate ADD CONSTRAINT fk_exchange_rate_base_currency_id FOREIGN KEY (base_currency_id) REFERENCES ref.currency (currency_id);
ALTER TABLE ref.exchange_rate ADD CONSTRAINT fk_exchange_rate_quote_currency_id FOREIGN KEY (quote_currency_id) REFERENCES ref.currency (currency_id);
ALTER TABLE ref.holiday ADD CONSTRAINT fk_holiday_country_id FOREIGN KEY (country_id) REFERENCES ref.country (country_id);
ALTER TABLE ref.bank_directory ADD CONSTRAINT fk_bank_directory_country_id FOREIGN KEY (country_id) REFERENCES ref.country (country_id);
ALTER TABLE ref.economic_activity_code ADD CONSTRAINT fk_economic_activity_code_parent_economic_activity_code_id FOREIGN KEY (parent_economic_activity_code_id) REFERENCES ref.economic_activity_code (economic_activity_code_id);
ALTER TABLE ref.product ADD CONSTRAINT fk_product_product_category_id FOREIGN KEY (product_category_id) REFERENCES ref.product_category (product_category_id);
ALTER TABLE ref.product_interest_rate ADD CONSTRAINT fk_product_interest_rate_product_id FOREIGN KEY (product_id) REFERENCES ref.product (product_id);
ALTER TABLE ref.product_interest_rate ADD CONSTRAINT fk_product_interest_rate_currency_id FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id);
ALTER TABLE ref.product_fee ADD CONSTRAINT fk_product_fee_product_id FOREIGN KEY (product_id) REFERENCES ref.product (product_id);
ALTER TABLE ref.product_fee ADD CONSTRAINT fk_product_fee_fee_type_id FOREIGN KEY (fee_type_id) REFERENCES ref.fee_type (fee_type_id);
ALTER TABLE ref.product_fee ADD CONSTRAINT fk_product_fee_currency_id FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id);
ALTER TABLE org.branch ADD CONSTRAINT fk_branch_parent_branch_id FOREIGN KEY (parent_branch_id) REFERENCES org.branch (branch_id);
ALTER TABLE org.employee ADD CONSTRAINT fk_employee_branch_id FOREIGN KEY (branch_id) REFERENCES org.branch (branch_id);
ALTER TABLE org.employee ADD CONSTRAINT fk_employee_manager_employee_id FOREIGN KEY (manager_employee_id) REFERENCES org.employee (employee_id);
ALTER TABLE org.atm ADD CONSTRAINT fk_atm_branch_id FOREIGN KEY (branch_id) REFERENCES org.branch (branch_id);
ALTER TABLE party.party ADD CONSTRAINT fk_party_residence_country_id FOREIGN KEY (residence_country_id) REFERENCES ref.country (country_id);
ALTER TABLE party.individual_profile ADD CONSTRAINT fk_individual_profile_party_id FOREIGN KEY (party_id) REFERENCES party.party (party_id);
ALTER TABLE party.individual_profile ADD CONSTRAINT fk_individual_profile_citizenship_country_id FOREIGN KEY (citizenship_country_id) REFERENCES ref.country (country_id);
ALTER TABLE party.organization_profile ADD CONSTRAINT fk_organization_profile_party_id FOREIGN KEY (party_id) REFERENCES party.party (party_id);
ALTER TABLE party.organization_profile ADD CONSTRAINT fk_organization_profile_economic_activity_code_id FOREIGN KEY (economic_activity_code_id) REFERENCES ref.economic_activity_code (economic_activity_code_id);
ALTER TABLE party.organization_profile ADD CONSTRAINT fk_organization_profile_registration_country_id FOREIGN KEY (registration_country_id) REFERENCES ref.country (country_id);
ALTER TABLE party.party_identifier ADD CONSTRAINT fk_party_identifier_party_id FOREIGN KEY (party_id) REFERENCES party.party (party_id);
ALTER TABLE party.party_identifier ADD CONSTRAINT fk_party_identifier_document_type_id FOREIGN KEY (document_type_id) REFERENCES ref.document_type (document_type_id);
ALTER TABLE party.party_identifier ADD CONSTRAINT fk_party_identifier_issuing_country_id FOREIGN KEY (issuing_country_id) REFERENCES ref.country (country_id);
ALTER TABLE party.party_address ADD CONSTRAINT fk_party_address_party_id FOREIGN KEY (party_id) REFERENCES party.party (party_id);
ALTER TABLE party.party_address ADD CONSTRAINT fk_party_address_country_id FOREIGN KEY (country_id) REFERENCES ref.country (country_id);
ALTER TABLE party.party_contact ADD CONSTRAINT fk_party_contact_party_id FOREIGN KEY (party_id) REFERENCES party.party (party_id);
ALTER TABLE party.party_relationship ADD CONSTRAINT fk_party_relationship_from_party_id FOREIGN KEY (from_party_id) REFERENCES party.party (party_id);
ALTER TABLE party.party_relationship ADD CONSTRAINT fk_party_relationship_to_party_id FOREIGN KEY (to_party_id) REFERENCES party.party (party_id);
ALTER TABLE party.customer ADD CONSTRAINT fk_customer_party_id FOREIGN KEY (party_id) REFERENCES party.party (party_id);
ALTER TABLE party.customer ADD CONSTRAINT fk_customer_segment_id FOREIGN KEY (segment_id) REFERENCES party.segment (segment_id);
ALTER TABLE party.customer ADD CONSTRAINT fk_customer_home_branch_id FOREIGN KEY (home_branch_id) REFERENCES org.branch (branch_id);
ALTER TABLE party.customer ADD CONSTRAINT fk_customer_relationship_manager_id FOREIGN KEY (relationship_manager_id) REFERENCES org.employee (employee_id);
ALTER TABLE party.kyc_review ADD CONSTRAINT fk_kyc_review_customer_id FOREIGN KEY (customer_id) REFERENCES party.customer (customer_id);
ALTER TABLE party.kyc_review ADD CONSTRAINT fk_kyc_review_reviewed_by_employee_id FOREIGN KEY (reviewed_by_employee_id) REFERENCES org.employee (employee_id);
ALTER TABLE party.consent ADD CONSTRAINT fk_consent_party_id FOREIGN KEY (party_id) REFERENCES party.party (party_id);
ALTER TABLE party.party_status_history ADD CONSTRAINT fk_party_status_history_party_id FOREIGN KEY (party_id) REFERENCES party.party (party_id);
ALTER TABLE account.account ADD CONSTRAINT fk_account_customer_id FOREIGN KEY (customer_id) REFERENCES party.customer (customer_id);
ALTER TABLE account.account ADD CONSTRAINT fk_account_product_id FOREIGN KEY (product_id) REFERENCES ref.product (product_id);
ALTER TABLE account.account ADD CONSTRAINT fk_account_currency_id FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id);
ALTER TABLE account.account ADD CONSTRAINT fk_account_branch_id FOREIGN KEY (branch_id) REFERENCES org.branch (branch_id);
ALTER TABLE account.account_holder ADD CONSTRAINT fk_account_holder_account_id FOREIGN KEY (account_id) REFERENCES account.account (account_id);
ALTER TABLE account.account_holder ADD CONSTRAINT fk_account_holder_party_id FOREIGN KEY (party_id) REFERENCES party.party (party_id);
ALTER TABLE account.account_balance ADD CONSTRAINT fk_account_balance_account_id FOREIGN KEY (account_id) REFERENCES account.account (account_id);
ALTER TABLE account.account_balance_daily ADD CONSTRAINT fk_account_balance_daily_account_id FOREIGN KEY (account_id) REFERENCES account.account (account_id);
ALTER TABLE account.account_transaction ADD CONSTRAINT fk_account_transaction_account_id FOREIGN KEY (account_id) REFERENCES account.account (account_id);
ALTER TABLE account.account_transaction ADD CONSTRAINT fk_account_transaction_transaction_type_id FOREIGN KEY (transaction_type_id) REFERENCES ref.transaction_type (transaction_type_id);
ALTER TABLE account.account_transaction ADD CONSTRAINT fk_account_transaction_channel_id FOREIGN KEY (channel_id) REFERENCES org.channel (channel_id);
ALTER TABLE account.account_transaction ADD CONSTRAINT fk_account_transaction_original_currency_id FOREIGN KEY (original_currency_id) REFERENCES ref.currency (currency_id);
ALTER TABLE account.account_transaction ADD CONSTRAINT fk_account_transaction_payment_order_id FOREIGN KEY (payment_order_id) REFERENCES payment.payment_order (payment_order_id);
ALTER TABLE account.account_transaction ADD CONSTRAINT fk_account_transaction_card_transaction_id FOREIGN KEY (card_transaction_id, card_transaction_date) REFERENCES card.card_transaction (card_transaction_id, transaction_date);
ALTER TABLE account.account_transaction ADD CONSTRAINT fk_account_transaction_loan_disbursement_id FOREIGN KEY (loan_disbursement_id) REFERENCES loan.loan_disbursement (loan_disbursement_id);
ALTER TABLE account.account_transaction ADD CONSTRAINT fk_account_transaction_loan_repayment_id FOREIGN KEY (loan_repayment_id) REFERENCES loan.loan_repayment (loan_repayment_id);
ALTER TABLE account.account_transaction ADD CONSTRAINT fk_account_transaction_reversed_account_transaction_id FOREIGN KEY (reversed_account_transaction_id, reversed_account_transaction_date) REFERENCES account.account_transaction (account_transaction_id, transaction_date);
ALTER TABLE account.hold ADD CONSTRAINT fk_hold_account_id FOREIGN KEY (account_id) REFERENCES account.account (account_id);
ALTER TABLE account.hold ADD CONSTRAINT fk_hold_card_authorization_id FOREIGN KEY (card_authorization_id, card_authorization_date) REFERENCES card.card_authorization (card_authorization_id, authorization_date);
ALTER TABLE account.account_fee_charge ADD CONSTRAINT fk_account_fee_charge_account_id FOREIGN KEY (account_id) REFERENCES account.account (account_id);
ALTER TABLE account.account_fee_charge ADD CONSTRAINT fk_account_fee_charge_fee_type_id FOREIGN KEY (fee_type_id) REFERENCES ref.fee_type (fee_type_id);
ALTER TABLE account.account_fee_charge ADD CONSTRAINT fk_account_fee_charge_account_transaction_id FOREIGN KEY (account_transaction_id, account_transaction_date) REFERENCES account.account_transaction (account_transaction_id, transaction_date);
ALTER TABLE account.interest_accrual ADD CONSTRAINT fk_interest_accrual_account_id FOREIGN KEY (account_id) REFERENCES account.account (account_id);
ALTER TABLE account.account_interest_rate ADD CONSTRAINT fk_account_interest_rate_account_id FOREIGN KEY (account_id) REFERENCES account.account (account_id);
ALTER TABLE account.account_interest_rate ADD CONSTRAINT fk_account_interest_rate_product_interest_rate_id FOREIGN KEY (product_interest_rate_id) REFERENCES ref.product_interest_rate (product_interest_rate_id);
ALTER TABLE account.term_deposit_term ADD CONSTRAINT fk_term_deposit_term_account_id FOREIGN KEY (account_id) REFERENCES account.account (account_id);
ALTER TABLE account.term_deposit_term ADD CONSTRAINT fk_term_deposit_term_payout_account_id FOREIGN KEY (payout_account_id) REFERENCES account.account (account_id);
ALTER TABLE account.overdraft_facility ADD CONSTRAINT fk_overdraft_facility_account_id FOREIGN KEY (account_id) REFERENCES account.account (account_id);
ALTER TABLE account.standing_order ADD CONSTRAINT fk_standing_order_debit_account_id FOREIGN KEY (debit_account_id) REFERENCES account.account (account_id);
ALTER TABLE account.standing_order ADD CONSTRAINT fk_standing_order_beneficiary_id FOREIGN KEY (beneficiary_id) REFERENCES payment.beneficiary (beneficiary_id);
ALTER TABLE account.account_limit ADD CONSTRAINT fk_account_limit_account_id FOREIGN KEY (account_id) REFERENCES account.account (account_id);
ALTER TABLE account.account_limit ADD CONSTRAINT fk_account_limit_channel_id FOREIGN KEY (channel_id) REFERENCES org.channel (channel_id);
ALTER TABLE account.statement ADD CONSTRAINT fk_statement_account_id FOREIGN KEY (account_id) REFERENCES account.account (account_id);
ALTER TABLE account.account_status_history ADD CONSTRAINT fk_account_status_history_account_id FOREIGN KEY (account_id) REFERENCES account.account (account_id);
ALTER TABLE payment.beneficiary ADD CONSTRAINT fk_beneficiary_customer_id FOREIGN KEY (customer_id) REFERENCES party.customer (customer_id);
ALTER TABLE payment.beneficiary ADD CONSTRAINT fk_beneficiary_bank_directory_id FOREIGN KEY (bank_directory_id) REFERENCES ref.bank_directory (bank_directory_id);
ALTER TABLE payment.payment_order ADD CONSTRAINT fk_payment_order_debit_account_id FOREIGN KEY (debit_account_id) REFERENCES account.account (account_id);
ALTER TABLE payment.payment_order ADD CONSTRAINT fk_payment_order_beneficiary_id FOREIGN KEY (beneficiary_id) REFERENCES payment.beneficiary (beneficiary_id);
ALTER TABLE payment.payment_order ADD CONSTRAINT fk_payment_order_beneficiary_bank_id FOREIGN KEY (beneficiary_bank_id) REFERENCES ref.bank_directory (bank_directory_id);
ALTER TABLE payment.payment_order ADD CONSTRAINT fk_payment_order_currency_id FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id);
ALTER TABLE payment.payment_order ADD CONSTRAINT fk_payment_order_channel_id FOREIGN KEY (channel_id) REFERENCES org.channel (channel_id);
ALTER TABLE payment.payment_status_history ADD CONSTRAINT fk_payment_status_history_payment_order_id FOREIGN KEY (payment_order_id) REFERENCES payment.payment_order (payment_order_id);
ALTER TABLE payment.payment_message ADD CONSTRAINT fk_payment_message_payment_order_id FOREIGN KEY (payment_order_id) REFERENCES payment.payment_order (payment_order_id);
ALTER TABLE payment.payment_return ADD CONSTRAINT fk_payment_return_payment_order_id FOREIGN KEY (payment_order_id) REFERENCES payment.payment_order (payment_order_id);
ALTER TABLE payment.fx_deal ADD CONSTRAINT fk_fx_deal_customer_id FOREIGN KEY (customer_id) REFERENCES party.customer (customer_id);
ALTER TABLE payment.fx_deal ADD CONSTRAINT fk_fx_deal_sell_account_id FOREIGN KEY (sell_account_id) REFERENCES account.account (account_id);
ALTER TABLE payment.fx_deal ADD CONSTRAINT fk_fx_deal_buy_account_id FOREIGN KEY (buy_account_id) REFERENCES account.account (account_id);
ALTER TABLE payment.fx_deal ADD CONSTRAINT fk_fx_deal_exchange_rate_id FOREIGN KEY (exchange_rate_id) REFERENCES ref.exchange_rate (exchange_rate_id);
ALTER TABLE card.merchant ADD CONSTRAINT fk_merchant_mcc_id FOREIGN KEY (mcc_id) REFERENCES ref.mcc (mcc_id);
ALTER TABLE card.merchant ADD CONSTRAINT fk_merchant_country_id FOREIGN KEY (country_id) REFERENCES ref.country (country_id);
ALTER TABLE card.card ADD CONSTRAINT fk_card_account_id FOREIGN KEY (account_id) REFERENCES account.account (account_id);
ALTER TABLE card.card ADD CONSTRAINT fk_card_cardholder_party_id FOREIGN KEY (cardholder_party_id) REFERENCES party.party (party_id);
ALTER TABLE card.card ADD CONSTRAINT fk_card_product_id FOREIGN KEY (product_id) REFERENCES ref.product (product_id);
ALTER TABLE card.card ADD CONSTRAINT fk_card_replaced_card_id FOREIGN KEY (replaced_card_id) REFERENCES card.card (card_id);
ALTER TABLE card.card_status_history ADD CONSTRAINT fk_card_status_history_card_id FOREIGN KEY (card_id) REFERENCES card.card (card_id);
ALTER TABLE card.card_limit ADD CONSTRAINT fk_card_limit_card_id FOREIGN KEY (card_id) REFERENCES card.card (card_id);
ALTER TABLE card.card_credit_line ADD CONSTRAINT fk_card_credit_line_account_id FOREIGN KEY (account_id) REFERENCES account.account (account_id);
ALTER TABLE card.card_authorization ADD CONSTRAINT fk_card_authorization_card_id FOREIGN KEY (card_id) REFERENCES card.card (card_id);
ALTER TABLE card.card_authorization ADD CONSTRAINT fk_card_authorization_currency_id FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id);
ALTER TABLE card.card_authorization ADD CONSTRAINT fk_card_authorization_merchant_id FOREIGN KEY (merchant_id) REFERENCES card.merchant (merchant_id);
ALTER TABLE card.card_authorization ADD CONSTRAINT fk_card_authorization_atm_id FOREIGN KEY (atm_id) REFERENCES org.atm (atm_id);
ALTER TABLE card.card_transaction ADD CONSTRAINT fk_card_transaction_card_id FOREIGN KEY (card_id) REFERENCES card.card (card_id);
ALTER TABLE card.card_transaction ADD CONSTRAINT fk_card_transaction_currency_id FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id);
ALTER TABLE card.card_transaction ADD CONSTRAINT fk_card_transaction_card_authorization_id FOREIGN KEY (card_authorization_id, card_authorization_date) REFERENCES card.card_authorization (card_authorization_id, authorization_date);
ALTER TABLE card.card_transaction ADD CONSTRAINT fk_card_transaction_merchant_id FOREIGN KEY (merchant_id) REFERENCES card.merchant (merchant_id);
ALTER TABLE card.card_billing_statement ADD CONSTRAINT fk_card_billing_statement_card_credit_line_id FOREIGN KEY (card_credit_line_id) REFERENCES card.card_credit_line (card_credit_line_id);
ALTER TABLE loan.credit_application ADD CONSTRAINT fk_credit_application_customer_id FOREIGN KEY (customer_id) REFERENCES party.customer (customer_id);
ALTER TABLE loan.credit_application ADD CONSTRAINT fk_credit_application_product_id FOREIGN KEY (product_id) REFERENCES ref.product (product_id);
ALTER TABLE loan.credit_application ADD CONSTRAINT fk_credit_application_currency_id FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id);
ALTER TABLE loan.credit_application ADD CONSTRAINT fk_credit_application_branch_id FOREIGN KEY (branch_id) REFERENCES org.branch (branch_id);
ALTER TABLE loan.credit_application ADD CONSTRAINT fk_credit_application_loan_officer_id FOREIGN KEY (loan_officer_id) REFERENCES org.employee (employee_id);
ALTER TABLE loan.credit_bureau_check ADD CONSTRAINT fk_credit_bureau_check_party_id FOREIGN KEY (party_id) REFERENCES party.party (party_id);
ALTER TABLE loan.credit_bureau_check ADD CONSTRAINT fk_credit_bureau_check_credit_application_id FOREIGN KEY (credit_application_id) REFERENCES loan.credit_application (credit_application_id);
ALTER TABLE loan.credit_facility ADD CONSTRAINT fk_credit_facility_customer_id FOREIGN KEY (customer_id) REFERENCES party.customer (customer_id);
ALTER TABLE loan.credit_facility ADD CONSTRAINT fk_credit_facility_credit_application_id FOREIGN KEY (credit_application_id) REFERENCES loan.credit_application (credit_application_id);
ALTER TABLE loan.credit_facility ADD CONSTRAINT fk_credit_facility_currency_id FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id);
ALTER TABLE loan.loan ADD CONSTRAINT fk_loan_customer_id FOREIGN KEY (customer_id) REFERENCES party.customer (customer_id);
ALTER TABLE loan.loan ADD CONSTRAINT fk_loan_product_id FOREIGN KEY (product_id) REFERENCES ref.product (product_id);
ALTER TABLE loan.loan ADD CONSTRAINT fk_loan_currency_id FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id);
ALTER TABLE loan.loan ADD CONSTRAINT fk_loan_credit_application_id FOREIGN KEY (credit_application_id) REFERENCES loan.credit_application (credit_application_id);
ALTER TABLE loan.loan ADD CONSTRAINT fk_loan_credit_facility_id FOREIGN KEY (credit_facility_id) REFERENCES loan.credit_facility (credit_facility_id);
ALTER TABLE loan.loan ADD CONSTRAINT fk_loan_settlement_account_id FOREIGN KEY (settlement_account_id) REFERENCES account.account (account_id);
ALTER TABLE loan.loan ADD CONSTRAINT fk_loan_branch_id FOREIGN KEY (branch_id) REFERENCES org.branch (branch_id);
ALTER TABLE loan.loan_disbursement ADD CONSTRAINT fk_loan_disbursement_loan_id FOREIGN KEY (loan_id) REFERENCES loan.loan (loan_id);
ALTER TABLE loan.loan_disbursement ADD CONSTRAINT fk_loan_disbursement_target_account_id FOREIGN KEY (target_account_id) REFERENCES account.account (account_id);
ALTER TABLE loan.repayment_schedule ADD CONSTRAINT fk_repayment_schedule_loan_id FOREIGN KEY (loan_id) REFERENCES loan.loan (loan_id);
ALTER TABLE loan.loan_repayment ADD CONSTRAINT fk_loan_repayment_loan_id FOREIGN KEY (loan_id) REFERENCES loan.loan (loan_id);
ALTER TABLE loan.loan_repayment ADD CONSTRAINT fk_loan_repayment_source_account_id FOREIGN KEY (source_account_id) REFERENCES account.account (account_id);
ALTER TABLE loan.repayment_allocation ADD CONSTRAINT fk_repayment_allocation_loan_repayment_id FOREIGN KEY (loan_repayment_id) REFERENCES loan.loan_repayment (loan_repayment_id);
ALTER TABLE loan.repayment_allocation ADD CONSTRAINT fk_repayment_allocation_repayment_schedule_id FOREIGN KEY (repayment_schedule_id) REFERENCES loan.repayment_schedule (repayment_schedule_id);
ALTER TABLE loan.loan_penalty_charge ADD CONSTRAINT fk_loan_penalty_charge_repayment_schedule_id FOREIGN KEY (repayment_schedule_id) REFERENCES loan.repayment_schedule (repayment_schedule_id);
ALTER TABLE loan.collateral ADD CONSTRAINT fk_collateral_collateral_type_id FOREIGN KEY (collateral_type_id) REFERENCES ref.collateral_type (collateral_type_id);
ALTER TABLE loan.collateral ADD CONSTRAINT fk_collateral_owner_party_id FOREIGN KEY (owner_party_id) REFERENCES party.party (party_id);
ALTER TABLE loan.collateral ADD CONSTRAINT fk_collateral_currency_id FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id);
ALTER TABLE loan.collateral ADD CONSTRAINT fk_collateral_pledged_account_id FOREIGN KEY (pledged_account_id) REFERENCES account.account (account_id);
ALTER TABLE loan.collateral_valuation ADD CONSTRAINT fk_collateral_valuation_collateral_id FOREIGN KEY (collateral_id) REFERENCES loan.collateral (collateral_id);
ALTER TABLE loan.loan_collateral ADD CONSTRAINT fk_loan_collateral_collateral_id FOREIGN KEY (collateral_id) REFERENCES loan.collateral (collateral_id);
ALTER TABLE loan.loan_collateral ADD CONSTRAINT fk_loan_collateral_loan_id FOREIGN KEY (loan_id) REFERENCES loan.loan (loan_id);
ALTER TABLE loan.loan_collateral ADD CONSTRAINT fk_loan_collateral_credit_facility_id FOREIGN KEY (credit_facility_id) REFERENCES loan.credit_facility (credit_facility_id);
ALTER TABLE loan.loan_guarantee ADD CONSTRAINT fk_loan_guarantee_guarantor_party_id FOREIGN KEY (guarantor_party_id) REFERENCES party.party (party_id);
ALTER TABLE loan.loan_guarantee ADD CONSTRAINT fk_loan_guarantee_loan_id FOREIGN KEY (loan_id) REFERENCES loan.loan (loan_id);
ALTER TABLE loan.loan_guarantee ADD CONSTRAINT fk_loan_guarantee_credit_facility_id FOREIGN KEY (credit_facility_id) REFERENCES loan.credit_facility (credit_facility_id);
ALTER TABLE loan.covenant ADD CONSTRAINT fk_covenant_loan_id FOREIGN KEY (loan_id) REFERENCES loan.loan (loan_id);
ALTER TABLE loan.covenant ADD CONSTRAINT fk_covenant_credit_facility_id FOREIGN KEY (credit_facility_id) REFERENCES loan.credit_facility (credit_facility_id);
ALTER TABLE loan.loan_restructuring ADD CONSTRAINT fk_loan_restructuring_loan_id FOREIGN KEY (loan_id) REFERENCES loan.loan (loan_id);
ALTER TABLE loan.loan_restructuring ADD CONSTRAINT fk_loan_restructuring_approved_by_employee_id FOREIGN KEY (approved_by_employee_id) REFERENCES org.employee (employee_id);
ALTER TABLE loan.loan_status_history ADD CONSTRAINT fk_loan_status_history_loan_id FOREIGN KEY (loan_id) REFERENCES loan.loan (loan_id);
ALTER TABLE ledger.gl_account ADD CONSTRAINT fk_gl_account_parent_gl_account_id FOREIGN KEY (parent_gl_account_id) REFERENCES ledger.gl_account (gl_account_id);
ALTER TABLE ledger.posting_rule ADD CONSTRAINT fk_posting_rule_transaction_type_id FOREIGN KEY (transaction_type_id) REFERENCES ref.transaction_type (transaction_type_id);
ALTER TABLE ledger.posting_rule ADD CONSTRAINT fk_posting_rule_product_id FOREIGN KEY (product_id) REFERENCES ref.product (product_id);
ALTER TABLE ledger.posting_rule ADD CONSTRAINT fk_posting_rule_debit_gl_account_id FOREIGN KEY (debit_gl_account_id) REFERENCES ledger.gl_account (gl_account_id);
ALTER TABLE ledger.posting_rule ADD CONSTRAINT fk_posting_rule_credit_gl_account_id FOREIGN KEY (credit_gl_account_id) REFERENCES ledger.gl_account (gl_account_id);
ALTER TABLE ledger.journal_entry ADD CONSTRAINT fk_journal_entry_accounting_period_id FOREIGN KEY (accounting_period_id) REFERENCES ledger.accounting_period (accounting_period_id);
ALTER TABLE ledger.journal_entry ADD CONSTRAINT fk_journal_entry_account_transaction_id FOREIGN KEY (account_transaction_id, account_transaction_date) REFERENCES account.account_transaction (account_transaction_id, transaction_date);
ALTER TABLE ledger.journal_entry_line ADD CONSTRAINT fk_journal_entry_line_journal_entry_id FOREIGN KEY (journal_entry_id) REFERENCES ledger.journal_entry (journal_entry_id);
ALTER TABLE ledger.journal_entry_line ADD CONSTRAINT fk_journal_entry_line_gl_account_id FOREIGN KEY (gl_account_id) REFERENCES ledger.gl_account (gl_account_id);
ALTER TABLE ledger.journal_entry_line ADD CONSTRAINT fk_journal_entry_line_currency_id FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id);
ALTER TABLE ledger.journal_entry_line ADD CONSTRAINT fk_journal_entry_line_branch_id FOREIGN KEY (branch_id) REFERENCES org.branch (branch_id);
ALTER TABLE compliance.screening_check ADD CONSTRAINT fk_screening_check_party_id FOREIGN KEY (party_id) REFERENCES party.party (party_id);
ALTER TABLE compliance.screening_check ADD CONSTRAINT fk_screening_check_payment_order_id FOREIGN KEY (payment_order_id) REFERENCES payment.payment_order (payment_order_id);
ALTER TABLE compliance.aml_case ADD CONSTRAINT fk_aml_case_party_id FOREIGN KEY (party_id) REFERENCES party.party (party_id);
ALTER TABLE compliance.aml_case ADD CONSTRAINT fk_aml_case_assigned_employee_id FOREIGN KEY (assigned_employee_id) REFERENCES org.employee (employee_id);
ALTER TABLE compliance.aml_alert ADD CONSTRAINT fk_aml_alert_party_id FOREIGN KEY (party_id) REFERENCES party.party (party_id);
ALTER TABLE compliance.aml_alert ADD CONSTRAINT fk_aml_alert_account_transaction_id FOREIGN KEY (account_transaction_id, account_transaction_date) REFERENCES account.account_transaction (account_transaction_id, transaction_date);
ALTER TABLE compliance.aml_alert ADD CONSTRAINT fk_aml_alert_screening_check_id FOREIGN KEY (screening_check_id) REFERENCES compliance.screening_check (screening_check_id);
ALTER TABLE compliance.aml_alert ADD CONSTRAINT fk_aml_alert_aml_case_id FOREIGN KEY (aml_case_id) REFERENCES compliance.aml_case (aml_case_id);
ALTER TABLE compliance.regulatory_report ADD CONSTRAINT fk_regulatory_report_aml_case_id FOREIGN KEY (aml_case_id) REFERENCES compliance.aml_case (aml_case_id);
ALTER TABLE compliance.regulatory_report_item ADD CONSTRAINT fk_regulatory_report_item_regulatory_report_id FOREIGN KEY (regulatory_report_id) REFERENCES compliance.regulatory_report (regulatory_report_id);
ALTER TABLE compliance.regulatory_report_item ADD CONSTRAINT fk_regulatory_report_item_account_transaction_id FOREIGN KEY (account_transaction_id, account_transaction_date) REFERENCES account.account_transaction (account_transaction_id, transaction_date);
ALTER TABLE compliance.regulatory_report_item ADD CONSTRAINT fk_regulatory_report_item_party_id FOREIGN KEY (party_id) REFERENCES party.party (party_id);

-- ============================================================
-- İndekslər
-- ============================================================
CREATE INDEX ix_exchange_rate_quote_currency_id ON ref.exchange_rate (quote_currency_id);
CREATE INDEX ix_bank_directory_country_id ON ref.bank_directory (country_id);
CREATE INDEX ix_economic_activity_code_parent_economic_activity_code_id ON ref.economic_activity_code (parent_economic_activity_code_id);
CREATE INDEX ix_product_product_category_id ON ref.product (product_category_id);
CREATE INDEX ix_product_interest_rate_product_id ON ref.product_interest_rate (product_id);
CREATE INDEX ix_product_interest_rate_currency_id ON ref.product_interest_rate (currency_id);
CREATE INDEX ix_product_fee_product_id ON ref.product_fee (product_id);
CREATE INDEX ix_product_fee_fee_type_id ON ref.product_fee (fee_type_id);
CREATE INDEX ix_product_fee_currency_id ON ref.product_fee (currency_id);
CREATE INDEX ix_branch_parent_branch_id ON org.branch (parent_branch_id);
CREATE INDEX ix_employee_branch_id ON org.employee (branch_id);
CREATE INDEX ix_employee_manager_employee_id ON org.employee (manager_employee_id);
CREATE INDEX ix_atm_branch_id ON org.atm (branch_id);
CREATE INDEX ix_party_residence_country_id ON party.party (residence_country_id);
CREATE INDEX ix_individual_profile_citizenship_country_id ON party.individual_profile (citizenship_country_id);
CREATE INDEX ix_individual_profile_last_name_first_name_birth_date ON party.individual_profile (last_name, first_name, birth_date);
CREATE INDEX ix_organization_profile_economic_activity_code_id ON party.organization_profile (economic_activity_code_id);
CREATE INDEX ix_organization_profile_registration_country_id ON party.organization_profile (registration_country_id);
CREATE INDEX ix_party_identifier_party_id ON party.party_identifier (party_id);
CREATE INDEX ix_party_identifier_issuing_country_id ON party.party_identifier (issuing_country_id);
CREATE INDEX ix_party_address_party_id ON party.party_address (party_id);
CREATE INDEX ix_party_address_country_id ON party.party_address (country_id);
CREATE INDEX ix_party_contact_party_id ON party.party_contact (party_id);
CREATE INDEX ix_party_contact_contact_value ON party.party_contact (contact_value);
CREATE INDEX ix_party_relationship_from_party_id ON party.party_relationship (from_party_id);
CREATE INDEX ix_party_relationship_to_party_id ON party.party_relationship (to_party_id);
CREATE INDEX ix_customer_segment_id ON party.customer (segment_id);
CREATE INDEX ix_customer_home_branch_id ON party.customer (home_branch_id);
CREATE INDEX ix_customer_relationship_manager_id ON party.customer (relationship_manager_id);
CREATE INDEX ix_kyc_review_customer_id ON party.kyc_review (customer_id);
CREATE INDEX ix_kyc_review_reviewed_by_employee_id ON party.kyc_review (reviewed_by_employee_id);
CREATE INDEX ix_kyc_review_next_review_date ON party.kyc_review (next_review_date);
CREATE INDEX ix_consent_party_id ON party.consent (party_id);
CREATE INDEX ix_party_status_history_party_id ON party.party_status_history (party_id);
CREATE INDEX ix_account_customer_id ON account.account (customer_id);
CREATE INDEX ix_account_product_id ON account.account (product_id);
CREATE INDEX ix_account_currency_id ON account.account (currency_id);
CREATE INDEX ix_account_branch_id ON account.account (branch_id);
CREATE INDEX ix_account_holder_party_id ON account.account_holder (party_id);
CREATE INDEX ix_account_transaction_transaction_type_id ON account.account_transaction (transaction_type_id);
CREATE INDEX ix_account_transaction_channel_id ON account.account_transaction (channel_id);
CREATE INDEX ix_account_transaction_original_currency_id ON account.account_transaction (original_currency_id);
CREATE INDEX ix_account_transaction_payment_order_id ON account.account_transaction (payment_order_id);
CREATE INDEX ix_account_transaction_card_transaction_id_card_transa_39416005 ON account.account_transaction (card_transaction_id, card_transaction_date);
CREATE INDEX ix_account_transaction_loan_disbursement_id ON account.account_transaction (loan_disbursement_id);
CREATE INDEX ix_account_transaction_loan_repayment_id ON account.account_transaction (loan_repayment_id);
CREATE INDEX ix_account_transaction_account_id_transaction_date ON account.account_transaction (account_id, transaction_date);
CREATE INDEX ix_account_transaction_reference_number ON account.account_transaction (reference_number);
CREATE INDEX ix_hold_account_id ON account.hold (account_id);
CREATE INDEX ix_hold_account_id_partial ON account.hold (account_id) WHERE status = 'ACTIVE';
CREATE INDEX ix_account_fee_charge_account_id ON account.account_fee_charge (account_id);
CREATE INDEX ix_account_fee_charge_fee_type_id ON account.account_fee_charge (fee_type_id);
CREATE INDEX ix_account_interest_rate_product_interest_rate_id ON account.account_interest_rate (product_interest_rate_id);
CREATE INDEX ix_term_deposit_term_payout_account_id ON account.term_deposit_term (payout_account_id);
CREATE INDEX ix_overdraft_facility_account_id ON account.overdraft_facility (account_id);
CREATE INDEX ix_standing_order_debit_account_id ON account.standing_order (debit_account_id);
CREATE INDEX ix_standing_order_beneficiary_id ON account.standing_order (beneficiary_id);
CREATE INDEX ix_standing_order_next_execution_date_partial ON account.standing_order (next_execution_date) WHERE status = 'ACTIVE';
CREATE INDEX ix_account_limit_channel_id ON account.account_limit (channel_id);
CREATE INDEX ix_account_status_history_account_id ON account.account_status_history (account_id);
CREATE INDEX ix_beneficiary_customer_id ON payment.beneficiary (customer_id);
CREATE INDEX ix_beneficiary_bank_directory_id ON payment.beneficiary (bank_directory_id);
CREATE INDEX ix_payment_order_debit_account_id ON payment.payment_order (debit_account_id);
CREATE INDEX ix_payment_order_beneficiary_id ON payment.payment_order (beneficiary_id);
CREATE INDEX ix_payment_order_beneficiary_bank_id ON payment.payment_order (beneficiary_bank_id);
CREATE INDEX ix_payment_order_currency_id ON payment.payment_order (currency_id);
CREATE INDEX ix_payment_order_channel_id ON payment.payment_order (channel_id);
CREATE INDEX ix_payment_order_status_value_date_partial ON payment.payment_order (status, value_date) WHERE status NOT IN ('EXECUTED', 'REJECTED', 'CANCELLED', 'RETURNED');
CREATE INDEX ix_payment_status_history_payment_order_id ON payment.payment_status_history (payment_order_id);
CREATE INDEX ix_payment_message_payment_order_id ON payment.payment_message (payment_order_id);
CREATE INDEX ix_payment_return_payment_order_id ON payment.payment_return (payment_order_id);
CREATE INDEX ix_fx_deal_customer_id ON payment.fx_deal (customer_id);
CREATE INDEX ix_fx_deal_sell_account_id ON payment.fx_deal (sell_account_id);
CREATE INDEX ix_fx_deal_buy_account_id ON payment.fx_deal (buy_account_id);
CREATE INDEX ix_fx_deal_exchange_rate_id ON payment.fx_deal (exchange_rate_id);
CREATE INDEX ix_merchant_mcc_id ON card.merchant (mcc_id);
CREATE INDEX ix_merchant_country_id ON card.merchant (country_id);
CREATE INDEX ix_card_account_id ON card.card (account_id);
CREATE INDEX ix_card_cardholder_party_id ON card.card (cardholder_party_id);
CREATE INDEX ix_card_product_id ON card.card (product_id);
CREATE INDEX ix_card_status_history_card_id ON card.card_status_history (card_id);
CREATE INDEX ix_card_authorization_currency_id ON card.card_authorization (currency_id);
CREATE INDEX ix_card_authorization_merchant_id ON card.card_authorization (merchant_id);
CREATE INDEX ix_card_authorization_atm_id ON card.card_authorization (atm_id);
CREATE INDEX ix_card_authorization_rrn ON card.card_authorization (rrn);
CREATE INDEX ix_card_authorization_card_id_authorization_date ON card.card_authorization (card_id, authorization_date);
CREATE INDEX ix_card_transaction_currency_id ON card.card_transaction (currency_id);
CREATE INDEX ix_card_transaction_card_authorization_id_card_authori_599dc545 ON card.card_transaction (card_authorization_id, card_authorization_date);
CREATE INDEX ix_card_transaction_merchant_id ON card.card_transaction (merchant_id);
CREATE INDEX ix_card_transaction_rrn ON card.card_transaction (rrn);
CREATE INDEX ix_card_transaction_card_id_transaction_date ON card.card_transaction (card_id, transaction_date);
CREATE INDEX ix_credit_application_customer_id ON loan.credit_application (customer_id);
CREATE INDEX ix_credit_application_product_id ON loan.credit_application (product_id);
CREATE INDEX ix_credit_application_currency_id ON loan.credit_application (currency_id);
CREATE INDEX ix_credit_application_branch_id ON loan.credit_application (branch_id);
CREATE INDEX ix_credit_application_loan_officer_id ON loan.credit_application (loan_officer_id);
CREATE INDEX ix_credit_bureau_check_party_id ON loan.credit_bureau_check (party_id);
CREATE INDEX ix_credit_bureau_check_credit_application_id ON loan.credit_bureau_check (credit_application_id);
CREATE INDEX ix_credit_facility_customer_id ON loan.credit_facility (customer_id);
CREATE INDEX ix_credit_facility_currency_id ON loan.credit_facility (currency_id);
CREATE INDEX ix_loan_customer_id ON loan.loan (customer_id);
CREATE INDEX ix_loan_product_id ON loan.loan (product_id);
CREATE INDEX ix_loan_currency_id ON loan.loan (currency_id);
CREATE INDEX ix_loan_credit_facility_id ON loan.loan (credit_facility_id);
CREATE INDEX ix_loan_settlement_account_id ON loan.loan (settlement_account_id);
CREATE INDEX ix_loan_branch_id ON loan.loan (branch_id);
CREATE INDEX ix_loan_status_days_past_due_partial ON loan.loan (status, days_past_due) WHERE days_past_due > 0;
CREATE INDEX ix_loan_disbursement_loan_id ON loan.loan_disbursement (loan_id);
CREATE INDEX ix_loan_disbursement_target_account_id ON loan.loan_disbursement (target_account_id);
CREATE INDEX ix_repayment_schedule_due_date_partial ON loan.repayment_schedule (due_date) WHERE status IN ('PENDING', 'PARTIALLY_PAID', 'OVERDUE');
CREATE INDEX ix_loan_repayment_loan_id ON loan.loan_repayment (loan_id);
CREATE INDEX ix_loan_repayment_source_account_id ON loan.loan_repayment (source_account_id);
CREATE INDEX ix_repayment_allocation_loan_repayment_id ON loan.repayment_allocation (loan_repayment_id);
CREATE INDEX ix_repayment_allocation_repayment_schedule_id ON loan.repayment_allocation (repayment_schedule_id);
CREATE INDEX ix_collateral_collateral_type_id ON loan.collateral (collateral_type_id);
CREATE INDEX ix_collateral_owner_party_id ON loan.collateral (owner_party_id);
CREATE INDEX ix_collateral_currency_id ON loan.collateral (currency_id);
CREATE INDEX ix_collateral_pledged_account_id ON loan.collateral (pledged_account_id);
CREATE INDEX ix_loan_collateral_collateral_id ON loan.loan_collateral (collateral_id);
CREATE INDEX ix_loan_collateral_loan_id ON loan.loan_collateral (loan_id);
CREATE INDEX ix_loan_collateral_credit_facility_id ON loan.loan_collateral (credit_facility_id);
CREATE INDEX ix_loan_guarantee_guarantor_party_id ON loan.loan_guarantee (guarantor_party_id);
CREATE INDEX ix_loan_guarantee_loan_id ON loan.loan_guarantee (loan_id);
CREATE INDEX ix_loan_guarantee_credit_facility_id ON loan.loan_guarantee (credit_facility_id);
CREATE INDEX ix_covenant_loan_id ON loan.covenant (loan_id);
CREATE INDEX ix_covenant_credit_facility_id ON loan.covenant (credit_facility_id);
CREATE INDEX ix_loan_restructuring_loan_id ON loan.loan_restructuring (loan_id);
CREATE INDEX ix_loan_restructuring_approved_by_employee_id ON loan.loan_restructuring (approved_by_employee_id);
CREATE INDEX ix_loan_status_history_loan_id ON loan.loan_status_history (loan_id);
CREATE INDEX ix_gl_account_parent_gl_account_id ON ledger.gl_account (parent_gl_account_id);
CREATE INDEX ix_posting_rule_product_id ON ledger.posting_rule (product_id);
CREATE INDEX ix_posting_rule_debit_gl_account_id ON ledger.posting_rule (debit_gl_account_id);
CREATE INDEX ix_posting_rule_credit_gl_account_id ON ledger.posting_rule (credit_gl_account_id);
CREATE INDEX ix_journal_entry_accounting_period_id ON ledger.journal_entry (accounting_period_id);
CREATE INDEX ix_journal_entry_account_transaction_id_account_transa_8f0da3f1 ON ledger.journal_entry (account_transaction_id, account_transaction_date);
CREATE INDEX ix_journal_entry_line_gl_account_id ON ledger.journal_entry_line (gl_account_id);
CREATE INDEX ix_journal_entry_line_currency_id ON ledger.journal_entry_line (currency_id);
CREATE INDEX ix_journal_entry_line_branch_id ON ledger.journal_entry_line (branch_id);
CREATE INDEX ix_screening_check_party_id ON compliance.screening_check (party_id);
CREATE INDEX ix_screening_check_payment_order_id ON compliance.screening_check (payment_order_id);
CREATE INDEX ix_aml_case_party_id ON compliance.aml_case (party_id);
CREATE INDEX ix_aml_case_assigned_employee_id ON compliance.aml_case (assigned_employee_id);
CREATE INDEX ix_aml_alert_party_id ON compliance.aml_alert (party_id);
CREATE INDEX ix_aml_alert_account_transaction_id_account_transaction_date ON compliance.aml_alert (account_transaction_id, account_transaction_date);
CREATE INDEX ix_aml_alert_screening_check_id ON compliance.aml_alert (screening_check_id);
CREATE INDEX ix_aml_alert_aml_case_id ON compliance.aml_alert (aml_case_id);
CREATE INDEX ix_regulatory_report_aml_case_id ON compliance.regulatory_report (aml_case_id);
CREATE INDEX ix_regulatory_report_item_regulatory_report_id ON compliance.regulatory_report_item (regulatory_report_id);
CREATE INDEX ix_regulatory_report_item_account_transaction_id_accou_c27dfe1b ON compliance.regulatory_report_item (account_transaction_id, account_transaction_date);
CREATE INDEX ix_regulatory_report_item_party_id ON compliance.regulatory_report_item (party_id);

-- ============================================================
-- Şərhlər
-- ============================================================
COMMENT ON TABLE ref.currency IS 'Valyuta. ISO 4217 valyuta kataloqu (AZN, USD, EUR və s.).';
COMMENT ON COLUMN ref.currency.currency_id IS 'Valyuta — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ref.currency.currency_code IS 'ISO 4217 hərf kodu (AZN, USD, EUR).';
COMMENT ON COLUMN ref.currency.numeric_code IS 'ISO 4217 rəqəm kodu (944 — AZN).';
COMMENT ON COLUMN ref.currency.name IS 'Valyutanın adı.';
COMMENT ON COLUMN ref.currency.minor_units IS 'Kəsr hissəsinin rəqəm sayı (AZN üçün 2).';
COMMENT ON COLUMN ref.currency.is_active IS 'Valyuta ilə əməliyyat aparılırmı.';
COMMENT ON COLUMN ref.currency.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ref.currency.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ref.currency.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ref.currency.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ref.country IS 'Ölkə. ISO 3166 ölkə kataloqu; rezidentlik, vətəndaşlıq, ünvan və sanksiya riskinin müəyyən edilməsi üçün.';
COMMENT ON COLUMN ref.country.country_id IS 'Ölkə — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ref.country.country_code IS 'ISO 3166-1 alpha-2 kodu (AZ).';
COMMENT ON COLUMN ref.country.alpha3_code IS 'ISO 3166-1 alpha-3 kodu (AZE).';
COMMENT ON COLUMN ref.country.name IS 'Ölkənin adı.';
COMMENT ON COLUMN ref.country.is_high_risk IS 'FATF və ya daxili siyasət üzrə yüksək riskli ölkə.';
COMMENT ON COLUMN ref.country.is_active IS 'Kataloqda aktivdir.';
COMMENT ON COLUMN ref.country.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ref.country.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ref.country.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ref.country.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ref.exchange_rate IS 'Valyuta məzənnəsi. Valyuta cütü üzrə tarixə görə məzənnələr: AMB-nin rəsmi məzənnəsi və bankın nağd/nağdsız alış-satış məzənnələri.';
COMMENT ON COLUMN ref.exchange_rate.exchange_rate_id IS 'Valyuta məzənnəsi — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ref.exchange_rate.base_currency_id IS 'Valyuta istinadı (əsas valyutasıdır).';
COMMENT ON COLUMN ref.exchange_rate.quote_currency_id IS 'Valyuta istinadı (qarşı valyutasıdır).';
COMMENT ON COLUMN ref.exchange_rate.rate_type IS 'Məzənnə növü: AMB rəsmi, nağd alış/satış, nağdsız alış/satış. Dəyərlər: OFFICIAL_CBAR, CASH_BUY, CASH_SELL, NONCASH_BUY, NONCASH_SELL.';
COMMENT ON COLUMN ref.exchange_rate.rate_date IS 'Məzənnənin aid olduğu tarix.';
COMMENT ON COLUMN ref.exchange_rate.valid_from IS 'Məzənnənin qüvvəyə mindiyi an (gün ərzində bir neçə dəfə dəyişə bilər).';
COMMENT ON COLUMN ref.exchange_rate.nominal IS 'Neçə vahid əsas valyuta üçün (adətən 1).';
COMMENT ON COLUMN ref.exchange_rate.rate IS 'Nominal qədər əsas valyutanın qarşı valyutada dəyəri.';
COMMENT ON COLUMN ref.exchange_rate.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ref.exchange_rate.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ref.exchange_rate.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ref.exchange_rate.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ref.holiday IS 'Qeyri-iş günü. Bayram və qeyri-iş günləri təqvimi; dəyər tarixi, ödəniş qrafiki və faiz hesablanması üçün istifadə olunur.';
COMMENT ON COLUMN ref.holiday.holiday_id IS 'Qeyri-iş günü — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ref.holiday.country_id IS 'Ölkə istinadı (təqvimidir).';
COMMENT ON COLUMN ref.holiday.holiday_date IS 'Qeyri-iş günü.';
COMMENT ON COLUMN ref.holiday.name IS 'Bayramın və ya günün adı.';
COMMENT ON COLUMN ref.holiday.holiday_type IS 'Növ: dövlət bayramı, köçürülmüş istirahət günü, bankın qeyri-iş günü. Dəyərlər: PUBLIC_HOLIDAY, TRANSFERRED_DAY_OFF, BANK_HOLIDAY.';
COMMENT ON COLUMN ref.holiday.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ref.holiday.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ref.holiday.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ref.holiday.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ref.bank_directory IS 'Bank kataloqu. Yerli və xarici banklar: BIC/SWIFT kodu, AMB bank kodu, müxbir hesab məlumatları.';
COMMENT ON COLUMN ref.bank_directory.bank_directory_id IS 'Bank kataloqu — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ref.bank_directory.country_id IS 'Ölkə istinadı (qeydiyyat ölkəsidir).';
COMMENT ON COLUMN ref.bank_directory.bic IS 'SWIFT BIC kodu.';
COMMENT ON COLUMN ref.bank_directory.cbar_bank_code IS 'AMB tərəfindən verilmiş 6 rəqəmli bank kodu (yerli banklar üçün).';
COMMENT ON COLUMN ref.bank_directory.name IS 'Bankın adı.';
COMMENT ON COLUMN ref.bank_directory.voen IS 'Bankın VÖEN-i (yerli banklar üçün).';
COMMENT ON COLUMN ref.bank_directory.correspondent_account IS 'Bankın AMB-dəki müxbir hesabı.';
COMMENT ON COLUMN ref.bank_directory.is_active IS 'Bank fəaliyyətdədir.';
COMMENT ON COLUMN ref.bank_directory.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ref.bank_directory.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ref.bank_directory.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ref.bank_directory.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ref.economic_activity_code IS 'İqtisadi fəaliyyət növü. İqtisadi fəaliyyət növlərinin iyerarxik təsnifatı (İFNT/NACE); hüquqi şəxslər və fərdi sahibkarlar üçün.';
COMMENT ON COLUMN ref.economic_activity_code.economic_activity_code_id IS 'İqtisadi fəaliyyət növü — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ref.economic_activity_code.parent_economic_activity_code_id IS 'İqtisadi fəaliyyət növü istinadı (alt bölməsidir).';
COMMENT ON COLUMN ref.economic_activity_code.code IS 'Təsnifat kodu.';
COMMENT ON COLUMN ref.economic_activity_code.name IS 'Fəaliyyət növünün adı.';
COMMENT ON COLUMN ref.economic_activity_code.level IS 'İyerarxiya səviyyəsi (1 — bölmə, sonrakılar — alt bölmələr).';
COMMENT ON COLUMN ref.economic_activity_code.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ref.economic_activity_code.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ref.economic_activity_code.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ref.economic_activity_code.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ref.document_type IS 'Sənəd növü. Şəxsiyyət və qeydiyyat sənədlərinin növləri: şəxsiyyət vəsiqəsi, pasport, yaşayış icazəsi, dövlət qeydiyyatı şəhadətnaməsi və s.';
COMMENT ON COLUMN ref.document_type.document_type_id IS 'Sənəd növü — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ref.document_type.code IS 'Sənəd növünün kodu.';
COMMENT ON COLUMN ref.document_type.name IS 'Sənəd növünün adı.';
COMMENT ON COLUMN ref.document_type.applies_to IS 'Hansı tərəf növü üçün. Dəyərlər: INDIVIDUAL, ORGANIZATION, ANY.';
COMMENT ON COLUMN ref.document_type.requires_expiry IS 'Etibarlılıq müddəti məcburidir.';
COMMENT ON COLUMN ref.document_type.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ref.document_type.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ref.document_type.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ref.document_type.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ref.product_category IS 'Məhsul kateqoriyası. Bank məhsullarının qrupları: cari hesab, əmanət, müddətli depozit, debet kart, kredit kartı, istehlak krediti, ipoteka, biznes krediti, kredit xətti.';
COMMENT ON COLUMN ref.product_category.product_category_id IS 'Məhsul kateqoriyası — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ref.product_category.code IS 'Kateqoriya kodu.';
COMMENT ON COLUMN ref.product_category.name IS 'Kateqoriyanın adı.';
COMMENT ON COLUMN ref.product_category.product_line IS 'Məhsul xətti; hansı domenin obyektləri ilə işlədiyini müəyyən edir. Dəyərlər: CURRENT_ACCOUNT, SAVINGS, TERM_DEPOSIT, DEBIT_CARD, CREDIT_CARD, CONSUMER_LOAN, MORTGAGE, BUSINESS_LOAN, CREDIT_LINE, OVERDRAFT.';
COMMENT ON COLUMN ref.product_category.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ref.product_category.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ref.product_category.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ref.product_category.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ref.product IS 'Məhsul. Bankın təklif etdiyi konkret məhsul və onun ümumi parametrləri (müştəri tipi, minimal/maksimal müddət və məbləğ).';
COMMENT ON COLUMN ref.product.product_id IS 'Məhsul — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ref.product.product_category_id IS 'Məhsul kateqoriyası istinadı (aiddir).';
COMMENT ON COLUMN ref.product.product_code IS 'Məhsul kodu.';
COMMENT ON COLUMN ref.product.name IS 'Məhsulun adı.';
COMMENT ON COLUMN ref.product.customer_type IS 'Məhsulun hədəf müştəri növü. Dəyərlər: INDIVIDUAL, LEGAL_ENTITY, INDIVIDUAL_ENTREPRENEUR, ANY.';
COMMENT ON COLUMN ref.product.min_term_months IS 'Minimal müddət (ay).';
COMMENT ON COLUMN ref.product.max_term_months IS 'Maksimal müddət (ay).';
COMMENT ON COLUMN ref.product.min_amount IS 'Minimal məbləğ.';
COMMENT ON COLUMN ref.product.max_amount IS 'Maksimal məbləğ.';
COMMENT ON COLUMN ref.product.launch_date IS 'Satışa çıxarılma tarixi.';
COMMENT ON COLUMN ref.product.withdrawal_date IS 'Satışdan çıxarılma tarixi.';
COMMENT ON COLUMN ref.product.status IS 'Məhsulun statusu. Dəyərlər: ACTIVE, SUSPENDED, WITHDRAWN.';
COMMENT ON COLUMN ref.product.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ref.product.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ref.product.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ref.product.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ref.product_interest_rate IS 'Məhsul faiz dərəcəsi. Məhsul üzrə standart illik faiz dərəcələri: valyuta, müddət və məbləğ diapazonuna görə, qüvvədə olma tarixləri ilə. Faiz faktiki/365 (actual/365) bazası ilə hesablanır.';
COMMENT ON COLUMN ref.product_interest_rate.product_interest_rate_id IS 'Məhsul faiz dərəcəsi — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ref.product_interest_rate.product_id IS 'Məhsul istinadı (faiz dərəcəsidir).';
COMMENT ON COLUMN ref.product_interest_rate.currency_id IS 'Valyuta istinadı (valyutasıdır).';
COMMENT ON COLUMN ref.product_interest_rate.rate_kind IS 'Dərəcənin növü. Dəyərlər: DEPOSIT, LENDING, OVERDRAFT, PENALTY, CREDIT_CARD.';
COMMENT ON COLUMN ref.product_interest_rate.term_from_months IS 'Müddət diapazonunun başlanğıcı (ay).';
COMMENT ON COLUMN ref.product_interest_rate.term_to_months IS 'Müddət diapazonunun sonu (ay).';
COMMENT ON COLUMN ref.product_interest_rate.amount_from IS 'Məbləğ diapazonunun başlanğıcı.';
COMMENT ON COLUMN ref.product_interest_rate.amount_to IS 'Məbləğ diapazonunun sonu.';
COMMENT ON COLUMN ref.product_interest_rate.annual_rate IS 'İllik faiz dərəcəsi (0.125000 = 12.5%); dəbbə üçün gündəlik dərəcə.';
COMMENT ON COLUMN ref.product_interest_rate.effective_from IS 'Qüvvəyə minmə tarixi.';
COMMENT ON COLUMN ref.product_interest_rate.effective_to IS 'Qüvvədən düşmə tarixi.';
COMMENT ON COLUMN ref.product_interest_rate.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ref.product_interest_rate.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ref.product_interest_rate.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ref.product_interest_rate.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ref.fee_type IS 'Komissiya növü. Komissiya və haqların kataloqu: hesab xidməti, köçürmə, nağdlaşdırma, kartın illik haqqı və s.';
COMMENT ON COLUMN ref.fee_type.fee_type_id IS 'Komissiya növü — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ref.fee_type.code IS 'Komissiya kodu.';
COMMENT ON COLUMN ref.fee_type.name IS 'Komissiyanın adı.';
COMMENT ON COLUMN ref.fee_type.fee_category IS 'Komissiya qrupu. Dəyərlər: ACCOUNT_SERVICE, TRANSFER, CASH, CARD, LOAN, OTHER.';
COMMENT ON COLUMN ref.fee_type.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ref.fee_type.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ref.fee_type.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ref.fee_type.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ref.product_fee IS 'Məhsul komissiyası. Məhsula tətbiq olunan komissiya tarifləri: sabit məbləğ və/və ya faiz, minimum/maksimum, qüvvədə olma tarixləri.';
COMMENT ON COLUMN ref.product_fee.product_fee_id IS 'Məhsul komissiyası — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ref.product_fee.product_id IS 'Məhsul istinadı (tarifidir).';
COMMENT ON COLUMN ref.product_fee.fee_type_id IS 'Komissiya növü istinadı (növüdür).';
COMMENT ON COLUMN ref.product_fee.currency_id IS 'Valyuta istinadı (valyutasıdır).';
COMMENT ON COLUMN ref.product_fee.calculation_method IS 'Hesablama üsulu. Dəyərlər: FIXED, PERCENT, FIXED_PLUS_PERCENT.';
COMMENT ON COLUMN ref.product_fee.fixed_amount IS 'Sabit məbləğ.';
COMMENT ON COLUMN ref.product_fee.percent_rate IS 'Əməliyyat məbləğindən faiz (0.005000 = 0.5%).';
COMMENT ON COLUMN ref.product_fee.min_amount IS 'Minimal komissiya.';
COMMENT ON COLUMN ref.product_fee.max_amount IS 'Maksimal komissiya.';
COMMENT ON COLUMN ref.product_fee.frequency IS 'Tutulma tezliyi. Dəyərlər: ONE_TIME, PER_TRANSACTION, MONTHLY, ANNUAL.';
COMMENT ON COLUMN ref.product_fee.effective_from IS 'Qüvvəyə minmə tarixi.';
COMMENT ON COLUMN ref.product_fee.effective_to IS 'Qüvvədən düşmə tarixi.';
COMMENT ON COLUMN ref.product_fee.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ref.product_fee.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ref.product_fee.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ref.product_fee.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ref.transaction_type IS 'Əməliyyat növü. Hesab əməliyyatlarının kodları və istiqaməti (mədaxil/məxaric): köçürmə, nağd mədaxil, kart əməliyyatı, faiz, komissiya, kredit ödənişi və s.';
COMMENT ON COLUMN ref.transaction_type.transaction_type_id IS 'Əməliyyat növü — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ref.transaction_type.code IS 'Əməliyyat növünün kodu.';
COMMENT ON COLUMN ref.transaction_type.name IS 'Əməliyyat növünün adı.';
COMMENT ON COLUMN ref.transaction_type.direction IS 'İcazə verilən istiqamət. Dəyərlər: DEBIT, CREDIT, BOTH.';
COMMENT ON COLUMN ref.transaction_type.category IS 'Əməliyyat qrupu. Dəyərlər: TRANSFER, CASH, CARD, INTEREST, FEE, LOAN, FX, ADJUSTMENT.';
COMMENT ON COLUMN ref.transaction_type.is_reversible IS 'Storno edilə bilər.';
COMMENT ON COLUMN ref.transaction_type.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ref.transaction_type.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ref.transaction_type.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ref.transaction_type.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ref.collateral_type IS 'Girov növü. Girov predmetlərinin növləri: daşınmaz əmlak, nəqliyyat vasitəsi, depozit, qiymətli metal, avadanlıq, mal-material.';
COMMENT ON COLUMN ref.collateral_type.collateral_type_id IS 'Girov növü — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ref.collateral_type.code IS 'Girov növünün kodu.';
COMMENT ON COLUMN ref.collateral_type.name IS 'Girov növünün adı.';
COMMENT ON COLUMN ref.collateral_type.default_haircut_percent IS 'Standart diskont (dəyərdən çıxılan faiz).';
COMMENT ON COLUMN ref.collateral_type.requires_registration IS 'Dövlət reyestrində qeydiyyat tələb olunur.';
COMMENT ON COLUMN ref.collateral_type.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ref.collateral_type.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ref.collateral_type.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ref.collateral_type.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ref.mcc IS 'Satıcı kateqoriya kodu (MCC). ISO 18245 satıcı kateqoriya kodları; kart əməliyyatlarının təsnifatı, limitlər və riskin idarə edilməsi üçün.';
COMMENT ON COLUMN ref.mcc.mcc_id IS 'Satıcı kateqoriya kodu (MCC) — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ref.mcc.mcc_code IS '4 rəqəmli MCC kodu.';
COMMENT ON COLUMN ref.mcc.description IS 'Kateqoriyanın təsviri.';
COMMENT ON COLUMN ref.mcc.is_high_risk IS 'Yüksək riskli kateqoriya (qumar, kriptovalyuta və s.).';
COMMENT ON COLUMN ref.mcc.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ref.mcc.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ref.mcc.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ref.mcc.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE org.branch IS 'Filial. Bankın baş ofisi, filialları və şöbələri; şöbə filiala tabe ola bilər.';
COMMENT ON COLUMN org.branch.branch_id IS 'Filial — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN org.branch.parent_branch_id IS 'Filial istinadı (tabe bölməsidir).';
COMMENT ON COLUMN org.branch.branch_code IS 'Bölmənin daxili kodu.';
COMMENT ON COLUMN org.branch.name IS 'Bölmənin adı.';
COMMENT ON COLUMN org.branch.branch_type IS 'Bölmənin növü. Dəyərlər: HEAD_OFFICE, BRANCH, DIVISION.';
COMMENT ON COLUMN org.branch.address IS 'Ünvan.';
COMMENT ON COLUMN org.branch.city IS 'Şəhər / rayon.';
COMMENT ON COLUMN org.branch.phone IS 'Əlaqə telefonu.';
COMMENT ON COLUMN org.branch.opened_date IS 'Açılış tarixi.';
COMMENT ON COLUMN org.branch.closed_date IS 'Bağlanma tarixi.';
COMMENT ON COLUMN org.branch.status IS 'Status. Dəyərlər: ACTIVE, CLOSED.';
COMMENT ON COLUMN org.branch.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN org.branch.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN org.branch.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN org.branch.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE org.employee IS 'Əməkdaş. Bank əməkdaşları: müştəri meneceri, kredit mütəxəssisi, operator, uyğunluq (compliance) əməkdaşı və s.';
COMMENT ON COLUMN org.employee.employee_id IS 'Əməkdaş — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN org.employee.branch_id IS 'Filial istinadı (işlədiyi bölmədir).';
COMMENT ON COLUMN org.employee.manager_employee_id IS 'Əməkdaş istinadı (rəhbəridir).';
COMMENT ON COLUMN org.employee.employee_number IS 'Tabel nömrəsi.';
COMMENT ON COLUMN org.employee.first_name IS 'Ad.';
COMMENT ON COLUMN org.employee.last_name IS 'Soyad.';
COMMENT ON COLUMN org.employee.position IS 'Vəzifə.';
COMMENT ON COLUMN org.employee.email IS 'Korporativ e-poçt.';
COMMENT ON COLUMN org.employee.hired_date IS 'İşə qəbul tarixi.';
COMMENT ON COLUMN org.employee.terminated_date IS 'İşdən çıxma tarixi.';
COMMENT ON COLUMN org.employee.status IS 'Status. Dəyərlər: ACTIVE, ON_LEAVE, TERMINATED.';
COMMENT ON COLUMN org.employee.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN org.employee.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN org.employee.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN org.employee.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE org.channel IS 'Xidmət kanalı. Müştəriyə xidmət kanalları: filial, bankomat, internet bankçılıq, mobil bankçılıq, POS, çağrı mərkəzi, API.';
COMMENT ON COLUMN org.channel.channel_id IS 'Xidmət kanalı — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN org.channel.channel_code IS 'Kanalın kodu.';
COMMENT ON COLUMN org.channel.name IS 'Kanalın adı.';
COMMENT ON COLUMN org.channel.channel_type IS 'Kanalın növü. Dəyərlər: BRANCH, ATM, INTERNET_BANKING, MOBILE_BANKING, POS, CALL_CENTER, API.';
COMMENT ON COLUMN org.channel.is_active IS 'Kanal aktivdir.';
COMMENT ON COLUMN org.channel.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN org.channel.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN org.channel.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN org.channel.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE org.atm IS 'Bankomat. Bankın bankomatları və özünəxidmət terminalları: yerləşmə ünvanı, imkanlar, status.';
COMMENT ON COLUMN org.atm.atm_id IS 'Bankomat — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN org.atm.branch_id IS 'Filial istinadı (xidmət göstərir).';
COMMENT ON COLUMN org.atm.terminal_id IS 'Terminal identifikatoru (prosessinqdə istifadə olunan).';
COMMENT ON COLUMN org.atm.address IS 'Yerləşmə ünvanı.';
COMMENT ON COLUMN org.atm.city IS 'Şəhər / rayon.';
COMMENT ON COLUMN org.atm.supports_cash_in IS 'Nağd mədaxil qəbul edir.';
COMMENT ON COLUMN org.atm.installed_date IS 'Quraşdırılma tarixi.';
COMMENT ON COLUMN org.atm.status IS 'Status. Dəyərlər: ACTIVE, OUT_OF_SERVICE, DECOMMISSIONED.';
COMMENT ON COLUMN org.atm.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN org.atm.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN org.atm.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN org.atm.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE party.party IS 'Tərəf. Bankla münasibətdə olan istənilən şəxs (supertip). Növü: fiziki şəxs, hüquqi şəxs, fərdi sahibkar. Eyni tərəf müştəri, zamin, girov mülkiyyətçisi, benefisiar mülkiyyətçi və ya səlahiyyətli şəxs ola bilər.';
COMMENT ON COLUMN party.party.party_id IS 'Tərəf — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN party.party.residence_country_id IS 'Ölkə istinadı (rezidentlik ölkəsidir).';
COMMENT ON COLUMN party.party.party_type IS 'Tərəfin növü (subtip diskriminatoru): fiziki şəxs, hüquqi şəxs, fərdi sahibkar. Dəyərlər: INDIVIDUAL, LEGAL_ENTITY, INDIVIDUAL_ENTREPRENEUR.';
COMMENT ON COLUMN party.party.display_name IS 'Göstərilən ad (fiziki şəxs üçün tam ad, təşkilat üçün qısa ad).';
COMMENT ON COLUMN party.party.is_resident IS 'Azərbaycan Respublikasının rezidentidir.';
COMMENT ON COLUMN party.party.status IS 'Tərəfin həyat dövrü statusu. Dəyərlər: PROSPECT, ACTIVE, INACTIVE, BLOCKED, DECEASED, LIQUIDATED.';
COMMENT ON COLUMN party.party.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN party.party.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN party.party.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN party.party.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE party.individual_profile IS 'Fiziki şəxs profili. Fiziki şəxsə və fərdi sahibkara aid şəxsi məlumatlar: soyad, ad, ata adı, doğum tarixi, FİN, vətəndaşlıq, PEP statusu.';
COMMENT ON COLUMN party.individual_profile.individual_profile_id IS 'Fiziki şəxs profili — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN party.individual_profile.party_id IS 'Tərəf istinadı (fiziki şəxs məlumatlarıdır).';
COMMENT ON COLUMN party.individual_profile.citizenship_country_id IS 'Ölkə istinadı (vətəndaşlığıdır).';
COMMENT ON COLUMN party.individual_profile.last_name IS 'Soyad.';
COMMENT ON COLUMN party.individual_profile.first_name IS 'Ad.';
COMMENT ON COLUMN party.individual_profile.patronymic IS 'Ata adı.';
COMMENT ON COLUMN party.individual_profile.birth_date IS 'Doğum tarixi.';
COMMENT ON COLUMN party.individual_profile.birth_place IS 'Doğum yeri.';
COMMENT ON COLUMN party.individual_profile.gender IS 'Cins. Dəyərlər: MALE, FEMALE.';
COMMENT ON COLUMN party.individual_profile.fin IS 'FİN — şəxsiyyət vəsiqəsindəki 7 simvollu kod (Azərbaycan vətəndaşları və yaşayış icazəsi olanlar üçün).';
COMMENT ON COLUMN party.individual_profile.is_pep IS 'Siyasi xadimdir (PEP).';
COMMENT ON COLUMN party.individual_profile.marital_status IS 'Ailə vəziyyəti. Dəyərlər: SINGLE, MARRIED, DIVORCED, WIDOWED.';
COMMENT ON COLUMN party.individual_profile.employment_status IS 'Məşğulluq vəziyyəti. Dəyərlər: EMPLOYED, SELF_EMPLOYED, UNEMPLOYED, RETIRED, STUDENT.';
COMMENT ON COLUMN party.individual_profile.monthly_income_azn IS 'Bəyan edilmiş aylıq gəlir (AZN).';
COMMENT ON COLUMN party.individual_profile.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN party.individual_profile.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN party.individual_profile.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN party.individual_profile.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE party.organization_profile IS 'Təşkilat profili. Hüquqi şəxsə və fərdi sahibkara aid qeydiyyat məlumatları: VÖEN, dövlət qeydiyyatı, təşkilati-hüquqi forma, fəaliyyət növü. Fərdi sahibkarın həm fiziki şəxs, həm də təşkilat profili olur.';
COMMENT ON COLUMN party.organization_profile.organization_profile_id IS 'Təşkilat profili — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN party.organization_profile.party_id IS 'Tərəf istinadı (qeydiyyat məlumatlarıdır).';
COMMENT ON COLUMN party.organization_profile.economic_activity_code_id IS 'İqtisadi fəaliyyət növü istinadı (əsas fəaliyyət növüdür).';
COMMENT ON COLUMN party.organization_profile.registration_country_id IS 'Ölkə istinadı (qeydiyyat ölkəsidir).';
COMMENT ON COLUMN party.organization_profile.legal_name IS 'Tam rəsmi adı.';
COMMENT ON COLUMN party.organization_profile.short_name IS 'Qısa adı.';
COMMENT ON COLUMN party.organization_profile.voen IS 'VÖEN — 10 rəqəmli vergi ödəyicisi kodu (qeyri-rezident təşkilatlarda olmaya bilər).';
COMMENT ON COLUMN party.organization_profile.legal_form IS 'Təşkilati-hüquqi forma: MMC, ASC, QSC, tam/kommandit ortaqlıq, kooperativ, publik hüquqi şəxs, qeyri-kommersiya təşkilatı, xarici şirkətin filialı, fərdi sahibkar. Dəyərlər: LLC, OJSC, CJSC, GENERAL_PARTNERSHIP, LIMITED_PARTNERSHIP, COOPERATIVE, PUBLIC_LEGAL_ENTITY, NON_PROFIT, FOREIGN_BRANCH, INDIVIDUAL_ENTREPRENEUR.';
COMMENT ON COLUMN party.organization_profile.registration_number IS 'Dövlət qeydiyyat nömrəsi.';
COMMENT ON COLUMN party.organization_profile.registration_date IS 'Dövlət qeydiyyatı tarixi.';
COMMENT ON COLUMN party.organization_profile.registration_authority IS 'Qeydiyyatı aparan orqan.';
COMMENT ON COLUMN party.organization_profile.authorized_capital IS 'Nizamnamə kapitalı (AZN).';
COMMENT ON COLUMN party.organization_profile.employee_count IS 'İşçi sayı.';
COMMENT ON COLUMN party.organization_profile.annual_turnover_azn IS 'İllik dövriyyə (AZN).';
COMMENT ON COLUMN party.organization_profile.website IS 'Veb sayt.';
COMMENT ON COLUMN party.organization_profile.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN party.organization_profile.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN party.organization_profile.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN party.organization_profile.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE party.party_identifier IS 'Tərəfin sənədi / identifikatoru. Tərəfin şəxsiyyət və qeydiyyat sənədləri: şəxsiyyət vəsiqəsi, pasport, yaşayış icazəsi, şəhadətnamə; verilmə və etibarlılıq tarixləri ilə.';
COMMENT ON COLUMN party.party_identifier.party_identifier_id IS 'Tərəfin sənədi / identifikatoru — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN party.party_identifier.party_id IS 'Tərəf istinadı (sənədidir).';
COMMENT ON COLUMN party.party_identifier.document_type_id IS 'Sənəd növü istinadı (növüdür).';
COMMENT ON COLUMN party.party_identifier.issuing_country_id IS 'Ölkə istinadı (verən ölkədir).';
COMMENT ON COLUMN party.party_identifier.document_series IS 'Sənədin seriyası (AA, AZE və s.).';
COMMENT ON COLUMN party.party_identifier.document_number IS 'Sənədin nömrəsi.';
COMMENT ON COLUMN party.party_identifier.issue_date IS 'Verilmə tarixi.';
COMMENT ON COLUMN party.party_identifier.expiry_date IS 'Etibarlılıq müddətinin sonu.';
COMMENT ON COLUMN party.party_identifier.issuing_authority IS 'Sənədi verən orqan.';
COMMENT ON COLUMN party.party_identifier.is_primary IS 'Əsas şəxsiyyət sənədidir.';
COMMENT ON COLUMN party.party_identifier.is_verified IS 'Sənəd yoxlanılıb (orijinal / dövlət reyestri).';
COMMENT ON COLUMN party.party_identifier.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN party.party_identifier.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN party.party_identifier.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN party.party_identifier.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE party.party_address IS 'Tərəfin ünvanı. Qeydiyyat, faktiki və hüquqi ünvanlar; qüvvədə olma tarixləri ilə.';
COMMENT ON COLUMN party.party_address.party_address_id IS 'Tərəfin ünvanı — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN party.party_address.party_id IS 'Tərəf istinadı (ünvanıdır).';
COMMENT ON COLUMN party.party_address.country_id IS 'Ölkə istinadı (ölkəsidir).';
COMMENT ON COLUMN party.party_address.address_type IS 'Ünvanın növü. Dəyərlər: REGISTRATION, ACTUAL, LEGAL, POSTAL.';
COMMENT ON COLUMN party.party_address.address_line IS 'Küçə, ev, mənzil.';
COMMENT ON COLUMN party.party_address.city IS 'Şəhər / rayon.';
COMMENT ON COLUMN party.party_address.district IS 'Rayon / qəsəbə.';
COMMENT ON COLUMN party.party_address.postal_code IS 'Poçt indeksi (AZ1000).';
COMMENT ON COLUMN party.party_address.effective_from IS 'Ünvanın qüvvədə olma başlanğıcı.';
COMMENT ON COLUMN party.party_address.effective_to IS 'Ünvanın qüvvədə olma sonu.';
COMMENT ON COLUMN party.party_address.is_primary IS 'Əsas əlaqə ünvanıdır.';
COMMENT ON COLUMN party.party_address.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN party.party_address.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN party.party_address.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN party.party_address.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE party.party_contact IS 'Əlaqə vasitəsi. Telefon, e-poçt və digər əlaqə vasitələri; təsdiqlənmə statusu və üstünlük verilən vasitə əlaməti ilə.';
COMMENT ON COLUMN party.party_contact.party_contact_id IS 'Əlaqə vasitəsi — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN party.party_contact.party_id IS 'Tərəf istinadı (əlaqə vasitəsidir).';
COMMENT ON COLUMN party.party_contact.contact_type IS 'Əlaqə vasitəsinin növü. Dəyərlər: MOBILE_PHONE, HOME_PHONE, WORK_PHONE, EMAIL, FAX.';
COMMENT ON COLUMN party.party_contact.contact_value IS 'Telefon nömrəsi (E.164, +994...) və ya e-poçt ünvanı.';
COMMENT ON COLUMN party.party_contact.is_primary IS 'Üstünlük verilən vasitədir.';
COMMENT ON COLUMN party.party_contact.is_verified IS 'OTP və ya digər üsulla təsdiqlənib.';
COMMENT ON COLUMN party.party_contact.verified_at IS 'Təsdiqlənmə anı.';
COMMENT ON COLUMN party.party_contact.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN party.party_contact.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN party.party_contact.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN party.party_contact.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE party.party_relationship IS 'Tərəflər arası əlaqə. İki tərəf arasında əlaqə: benefisiar mülkiyyətçi (UBO), direktor, təsisçi, səlahiyyətli imza sahibi, ailə üzvü; pay faizi və qüvvədə olma tarixləri ilə.';
COMMENT ON COLUMN party.party_relationship.party_relationship_id IS 'Tərəflər arası əlaqə — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN party.party_relationship.from_party_id IS 'Tərəf istinadı (əlaqənin subyektidir).';
COMMENT ON COLUMN party.party_relationship.to_party_id IS 'Tərəf istinadı (əlaqənin obyektidir).';
COMMENT ON COLUMN party.party_relationship.relationship_type IS 'Əlaqənin növü (from_party → to_party: məs. fiziki şəxs təşkilatın UBO-sudur). Dəyərlər: UBO, DIRECTOR, FOUNDER, AUTHORIZED_SIGNATORY, CHIEF_ACCOUNTANT, LEGAL_REPRESENTATIVE, SPOUSE, PARENT, CHILD.';
COMMENT ON COLUMN party.party_relationship.ownership_percent IS 'Mülkiyyət payı (UBO və təsisçi üçün).';
COMMENT ON COLUMN party.party_relationship.effective_from IS 'Əlaqənin başlanğıcı.';
COMMENT ON COLUMN party.party_relationship.effective_to IS 'Əlaqənin sonu.';
COMMENT ON COLUMN party.party_relationship.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN party.party_relationship.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN party.party_relationship.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN party.party_relationship.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE party.segment IS 'Müştəri seqmenti. Müştəri seqmentləri: kütləvi pərakəndə, premium, mikro və kiçik biznes, orta biznes, korporativ.';
COMMENT ON COLUMN party.segment.segment_id IS 'Müştəri seqmenti — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN party.segment.segment_code IS 'Seqment kodu.';
COMMENT ON COLUMN party.segment.name IS 'Seqmentin adı.';
COMMENT ON COLUMN party.segment.customer_group IS 'Müştəri qrupu. Dəyərlər: RETAIL, BUSINESS.';
COMMENT ON COLUMN party.segment.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN party.segment.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN party.segment.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN party.segment.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE party.customer IS 'Müştəri. Tərəfin bankın müştərisi rolu: CIF nömrəsi, seqment, xidmət filialı, müştəri meneceri, münasibətin başlama və bitmə tarixi.';
COMMENT ON COLUMN party.customer.customer_id IS 'Müştəri — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN party.customer.party_id IS 'Tərəf istinadı (müştəri roludur).';
COMMENT ON COLUMN party.customer.segment_id IS 'Müştəri seqmenti istinadı (aid olduğu seqmentdir).';
COMMENT ON COLUMN party.customer.home_branch_id IS 'Filial istinadı (xidmət filialıdır).';
COMMENT ON COLUMN party.customer.relationship_manager_id IS 'Əməkdaş istinadı (müştəri meneceridir).';
COMMENT ON COLUMN party.customer.cif_number IS 'CIF — bankın müştəriyə verdiyi unikal nömrə.';
COMMENT ON COLUMN party.customer.customer_since IS 'Müştəri münasibətinin başlama tarixi.';
COMMENT ON COLUMN party.customer.closed_date IS 'Münasibətin bitmə tarixi.';
COMMENT ON COLUMN party.customer.preferred_language IS 'Ünsiyyət dili. Dəyərlər: AZ, EN, RU.';
COMMENT ON COLUMN party.customer.status IS 'Müştəri statusu. Dəyərlər: ACTIVE, DORMANT, BLOCKED, CLOSED.';
COMMENT ON COLUMN party.customer.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN party.customer.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN party.customer.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN party.customer.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE party.kyc_review IS 'KYC yoxlaması. Müştərinin eyniləşdirilməsi və risk qiymətləndirilməsi (KYC/CDD/EDD): risk səviyyəsi, nəticə, növbəti yoxlama tarixi. Müştərinin cari risk səviyyəsi son təsdiqlənmiş yoxlamadır.';
COMMENT ON COLUMN party.kyc_review.kyc_review_id IS 'KYC yoxlaması — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN party.kyc_review.customer_id IS 'Müştəri istinadı (yoxlamasıdır).';
COMMENT ON COLUMN party.kyc_review.reviewed_by_employee_id IS 'Əməkdaş istinadı (yoxlamanı aparıb).';
COMMENT ON COLUMN party.kyc_review.review_type IS 'Yoxlamanın səbəbi. Dəyərlər: ONBOARDING, PERIODIC, EVENT_DRIVEN.';
COMMENT ON COLUMN party.kyc_review.due_diligence_level IS 'Yoxlama səviyyəsi: sadələşdirilmiş, standart, gücləndirilmiş. Dəyərlər: SIMPLIFIED, STANDARD, ENHANCED.';
COMMENT ON COLUMN party.kyc_review.risk_level IS 'Müəyyən edilmiş AML risk səviyyəsi. Dəyərlər: LOW, MEDIUM, HIGH, UNACCEPTABLE.';
COMMENT ON COLUMN party.kyc_review.outcome IS 'Nəticə. Dəyərlər: APPROVED, REJECTED, PENDING_INFO.';
COMMENT ON COLUMN party.kyc_review.review_date IS 'Yoxlama tarixi.';
COMMENT ON COLUMN party.kyc_review.next_review_date IS 'Növbəti yoxlama tarixi.';
COMMENT ON COLUMN party.kyc_review.source_of_funds IS 'Vəsaitlərin mənbəyi.';
COMMENT ON COLUMN party.kyc_review.comment IS 'Qeydlər.';
COMMENT ON COLUMN party.kyc_review.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN party.kyc_review.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN party.kyc_review.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN party.kyc_review.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE party.consent IS 'Razılıq. Tərəfin razılıqları: fərdi məlumatların emalı, Kredit Bürosuna sorğu, marketinq bildirişləri; verilmə və geri götürülmə tarixləri ilə.';
COMMENT ON COLUMN party.consent.consent_id IS 'Razılıq — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN party.consent.party_id IS 'Tərəf istinadı (razılığıdır).';
COMMENT ON COLUMN party.consent.consent_type IS 'Razılığın növü. Dəyərlər: PERSONAL_DATA_PROCESSING, CREDIT_BUREAU_INQUIRY, MARKETING, ELECTRONIC_COMMUNICATION.';
COMMENT ON COLUMN party.consent.granted_at IS 'Razılığın verildiyi an.';
COMMENT ON COLUMN party.consent.revoked_at IS 'Razılığın geri götürüldüyü an.';
COMMENT ON COLUMN party.consent.document_reference IS 'Razılıq sənədinin / elektron imzanın istinadı.';
COMMENT ON COLUMN party.consent.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN party.consent.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN party.consent.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN party.consent.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE party.party_status_history IS 'Tərəf statusu tarixçəsi. Tərəfin həyat dövrü statusunun dəyişiklikləri (yalnız əlavə olunur, dəyişdirilmir).';
COMMENT ON COLUMN party.party_status_history.party_status_history_id IS 'Tərəf statusu tarixçəsi — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN party.party_status_history.party_id IS 'Tərəf istinadı (status tarixçəsidir).';
COMMENT ON COLUMN party.party_status_history.from_status IS 'Əvvəlki status (ilk yazılışda boş). Dəyərlər: PROSPECT, ACTIVE, INACTIVE, BLOCKED, DECEASED, LIQUIDATED.';
COMMENT ON COLUMN party.party_status_history.to_status IS 'Yeni status. Dəyərlər: PROSPECT, ACTIVE, INACTIVE, BLOCKED, DECEASED, LIQUIDATED.';
COMMENT ON COLUMN party.party_status_history.changed_at IS 'Statusun dəyişdiyi an.';
COMMENT ON COLUMN party.party_status_history.reason_code IS 'Dəyişikliyin səbəb kodu.';
COMMENT ON COLUMN party.party_status_history.comment IS 'Əlavə izah.';
COMMENT ON COLUMN party.party_status_history.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN party.party_status_history.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN party.party_status_history.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN party.party_status_history.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE account.account IS 'Hesab. Müştəri hesabı: cari, əmanət, müddətli depozit və ya kart hesabı. AZ IBAN, valyuta, məhsul, xidmət filialı, status.';
COMMENT ON COLUMN account.account.account_id IS 'Hesab — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN account.account.customer_id IS 'Müştəri istinadı (hesabıdır).';
COMMENT ON COLUMN account.account.product_id IS 'Məhsul istinadı (məhsuludur).';
COMMENT ON COLUMN account.account.currency_id IS 'Valyuta istinadı (valyutasıdır).';
COMMENT ON COLUMN account.account.branch_id IS 'Filial istinadı (hesabın filialıdır).';
COMMENT ON COLUMN account.account.account_number IS 'Bankdaxili hesab nömrəsi (IBAN-ın 20 simvollu hissəsi).';
COMMENT ON COLUMN account.account.iban IS 'AZ IBAN — 28 simvol: AZ + 2 yoxlama rəqəmi + 4 simvollu bank kodu + 20 simvollu hesab nömrəsi.';
COMMENT ON COLUMN account.account.account_type IS 'Hesabın növü. Dəyərlər: CURRENT, SAVINGS, TERM_DEPOSIT, CARD.';
COMMENT ON COLUMN account.account.account_name IS 'Müştərinin hesaba verdiyi ad.';
COMMENT ON COLUMN account.account.opened_date IS 'Açılış tarixi.';
COMMENT ON COLUMN account.account.closed_date IS 'Bağlanma tarixi.';
COMMENT ON COLUMN account.account.is_joint IS 'Birgə hesabdır (bir neçə sahib).';
COMMENT ON COLUMN account.account.status IS 'Hesabın statusu. Dəyərlər: PENDING, ACTIVE, DORMANT, FROZEN, CLOSED.';
COMMENT ON COLUMN account.account.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN account.account.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN account.account.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN account.account.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE account.account_holder IS 'Hesab sahibi / səlahiyyətli şəxs. Hesab ilə tərəf arasında rol: əsas sahib, birgə sahib, səlahiyyətli imza sahibi, etibarnamə üzrə nümayəndə; qüvvədə olma tarixləri ilə.';
COMMENT ON COLUMN account.account_holder.account_holder_id IS 'Hesab sahibi / səlahiyyətli şəxs — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN account.account_holder.account_id IS 'Hesab istinadı (sahibləridir).';
COMMENT ON COLUMN account.account_holder.party_id IS 'Tərəf istinadı (hesab üzrə roludur).';
COMMENT ON COLUMN account.account_holder.holder_role IS 'Tərəfin hesab üzrə rolu. Dəyərlər: PRIMARY_OWNER, JOINT_OWNER, AUTHORIZED_SIGNATORY, POWER_OF_ATTORNEY, TRUSTEE.';
COMMENT ON COLUMN account.account_holder.signing_rule IS 'İmza qaydası: tək, istənilən iki, hamısı birlikdə. Dəyərlər: SOLE, ANY_TWO, ALL.';
COMMENT ON COLUMN account.account_holder.power_of_attorney_number IS 'Etibarnamənin nömrəsi.';
COMMENT ON COLUMN account.account_holder.effective_from IS 'Rolun başlanğıcı.';
COMMENT ON COLUMN account.account_holder.effective_to IS 'Rolun sonu.';
COMMENT ON COLUMN account.account_holder.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN account.account_holder.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN account.account_holder.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN account.account_holder.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE account.account_balance IS 'Hesab qalığı (cari). Hesabın cari qalıqları: mühasibat qalığı, istifadəyə yararlı qalıq, bloklanmış məbləğ. Hər əməliyyatla eyni tranzaksiyada yenilənir (performans üçün idarə olunan denormallaşdırma; mənbə — hesab əməliyyatları və bloklamalar).';
COMMENT ON COLUMN account.account_balance.account_balance_id IS 'Hesab qalığı (cari) — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN account.account_balance.account_id IS 'Hesab istinadı (cari qalığıdır).';
COMMENT ON COLUMN account.account_balance.ledger_balance IS 'Mühasibat qalığı.';
COMMENT ON COLUMN account.account_balance.blocked_amount IS 'Aktiv bloklamaların cəmi.';
COMMENT ON COLUMN account.account_balance.available_balance IS 'İstifadəyə yararlı qalıq (qalıq − bloklama + overdraft limiti).';
COMMENT ON COLUMN account.account_balance.last_transaction_at IS 'Son əməliyyatın anı.';
COMMENT ON COLUMN account.account_balance.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN account.account_balance.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN account.account_balance.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN account.account_balance.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE account.account_balance_daily IS 'Gün sonu qalığı. Hər iş günü sonunda hesab qalığının snapşotu; faiz hesablanması, çıxarış və hesabatlar üçün.';
COMMENT ON COLUMN account.account_balance_daily.account_balance_daily_id IS 'Gün sonu qalığı — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN account.account_balance_daily.account_id IS 'Hesab istinadı (gün sonu qalığıdır).';
COMMENT ON COLUMN account.account_balance_daily.balance_date IS 'Bank günü.';
COMMENT ON COLUMN account.account_balance_daily.ledger_balance IS 'Gün sonu mühasibat qalığı.';
COMMENT ON COLUMN account.account_balance_daily.available_balance IS 'Gün sonu istifadəyə yararlı qalıq.';
COMMENT ON COLUMN account.account_balance_daily.debit_turnover IS 'Gün ərzində debet dövriyyəsi.';
COMMENT ON COLUMN account.account_balance_daily.credit_turnover IS 'Gün ərzində kredit dövriyyəsi.';
COMMENT ON COLUMN account.account_balance_daily.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN account.account_balance_daily.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN account.account_balance_daily.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN account.account_balance_daily.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE account.account_transaction IS 'Hesab əməliyyatı. Hesab üzrə mədaxil/məxaric yazılışı: məbləğ, əməliyyat və dəyər tarixi, mənbə (ödəniş, kart, kredit), storno əlaqəsi. Yüksək həcmli cədvəldir, aylar üzrə bölmələnir. Yazılış dəyişdirilmir — düzəliş storno ilə edilir.';
COMMENT ON COLUMN account.account_transaction.account_transaction_id IS 'Hesab əməliyyatı — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN account.account_transaction.account_id IS 'Hesab istinadı (əməliyyatıdır).';
COMMENT ON COLUMN account.account_transaction.transaction_type_id IS 'Əməliyyat növü istinadı (növüdür).';
COMMENT ON COLUMN account.account_transaction.channel_id IS 'Xidmət kanalı istinadı (kanalıdır).';
COMMENT ON COLUMN account.account_transaction.original_currency_id IS 'Valyuta istinadı (orijinal valyutadır).';
COMMENT ON COLUMN account.account_transaction.payment_order_id IS 'Ödəniş tapşırığı istinadı (nəticəsidir).';
COMMENT ON COLUMN account.account_transaction.card_transaction_id IS 'Kart əməliyyatı (klirinq) istinadı (nəticəsidir).';
COMMENT ON COLUMN account.account_transaction.card_transaction_date IS 'İstinad edilən `card_transaction` yazılışının bölmə tarixi (kompozit FK hissəsi).';
COMMENT ON COLUMN account.account_transaction.loan_disbursement_id IS 'Kreditin verilməsi istinadı (nəticəsidir).';
COMMENT ON COLUMN account.account_transaction.loan_repayment_id IS 'Kredit ödənişi istinadı (nəticəsidir).';
COMMENT ON COLUMN account.account_transaction.reversed_account_transaction_id IS 'Hesab əməliyyatı istinadı (stornosudur).';
COMMENT ON COLUMN account.account_transaction.reversed_account_transaction_date IS 'İstinad edilən `account_transaction` yazılışının bölmə tarixi (kompozit FK hissəsi).';
COMMENT ON COLUMN account.account_transaction.transaction_date IS 'Əməliyyatın bank günü (bölmə açarı).';
COMMENT ON COLUMN account.account_transaction.value_date IS 'Dəyər tarixi.';
COMMENT ON COLUMN account.account_transaction.posted_at IS 'Hesabda əks olunduğu an.';
COMMENT ON COLUMN account.account_transaction.direction IS 'İstiqamət: məxaric (debet) və ya mədaxil (kredit). Dəyərlər: DEBIT, CREDIT.';
COMMENT ON COLUMN account.account_transaction.amount IS 'Hesab valyutasında məbləğ (həmişə müsbət; işarə istiqamətlə verilir).';
COMMENT ON COLUMN account.account_transaction.original_amount IS 'Orijinal valyutada məbləğ (konversiya olduqda).';
COMMENT ON COLUMN account.account_transaction.balance_after IS 'Əməliyyatdan sonrakı mühasibat qalığı.';
COMMENT ON COLUMN account.account_transaction.reference_number IS 'Əməliyyatın istinad nömrəsi.';
COMMENT ON COLUMN account.account_transaction.narrative IS 'Təyinat / təsvir.';
COMMENT ON COLUMN account.account_transaction.status IS 'Status. Dəyərlər: POSTED, REVERSED.';
COMMENT ON COLUMN account.account_transaction.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN account.account_transaction.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN account.account_transaction.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN account.account_transaction.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE account.hold IS 'Bloklama. Hesab vəsaitlərinin bloklanması: kart avtorizasiyası, məhkəmə qərarı, vergi orqanının sərəncamı, girov; bloklama və azad edilmə tarixləri ilə.';
COMMENT ON COLUMN account.hold.hold_id IS 'Bloklama — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN account.hold.account_id IS 'Hesab istinadı (bloklamasıdır).';
COMMENT ON COLUMN account.hold.card_authorization_id IS 'Kart avtorizasiyası istinadı (bloklamaya səbəb olub).';
COMMENT ON COLUMN account.hold.card_authorization_date IS 'İstinad edilən `card_authorization` yazılışının bölmə tarixi (kompozit FK hissəsi).';
COMMENT ON COLUMN account.hold.hold_type IS 'Bloklamanın növü. Dəyərlər: CARD_AUTHORIZATION, COURT_ORDER, TAX_AUTHORITY, COLLATERAL, BANK_INTERNAL.';
COMMENT ON COLUMN account.hold.amount IS 'Bloklanmış məbləğ (hesab valyutasında).';
COMMENT ON COLUMN account.hold.placed_at IS 'Bloklama anı.';
COMMENT ON COLUMN account.hold.expires_at IS 'Avtomatik azad olunma anı.';
COMMENT ON COLUMN account.hold.released_at IS 'Faktiki azad olunma anı.';
COMMENT ON COLUMN account.hold.legal_document_reference IS 'Qərarın / sərəncamın nömrəsi və tarixi.';
COMMENT ON COLUMN account.hold.reason IS 'Səbəb.';
COMMENT ON COLUMN account.hold.status IS 'Status. Dəyərlər: ACTIVE, RELEASED, EXPIRED, CAPTURED.';
COMMENT ON COLUMN account.hold.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN account.hold.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN account.hold.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN account.hold.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE account.account_fee_charge IS 'Tutulmuş komissiya. Hesabdan tutulan, güzəşt edilən və ya geri qaytarılan komissiyalar.';
COMMENT ON COLUMN account.account_fee_charge.account_fee_charge_id IS 'Tutulmuş komissiya — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN account.account_fee_charge.account_id IS 'Hesab istinadı (komissiyasıdır).';
COMMENT ON COLUMN account.account_fee_charge.fee_type_id IS 'Komissiya növü istinadı (növüdür).';
COMMENT ON COLUMN account.account_fee_charge.account_transaction_id IS 'Hesab əməliyyatı istinadı (tutulma yazılışıdır).';
COMMENT ON COLUMN account.account_fee_charge.account_transaction_date IS 'İstinad edilən `account_transaction` yazılışının bölmə tarixi (kompozit FK hissəsi).';
COMMENT ON COLUMN account.account_fee_charge.charge_date IS 'Hesablanma tarixi.';
COMMENT ON COLUMN account.account_fee_charge.amount IS 'Komissiya məbləği.';
COMMENT ON COLUMN account.account_fee_charge.waiver_reason IS 'Güzəştin səbəbi.';
COMMENT ON COLUMN account.account_fee_charge.status IS 'Status. Dəyərlər: PENDING, CHARGED, WAIVED, REFUNDED.';
COMMENT ON COLUMN account.account_fee_charge.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN account.account_fee_charge.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN account.account_fee_charge.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN account.account_fee_charge.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE account.interest_accrual IS 'Faiz hesablanması. Hesab üzrə gündəlik faiz hesablanması, kapitallaşma və ödənilmə; ödəmə mənbəyində tutulan vergi ilə. Gündəlik faiz = qalıq × illik dərəcə / 365 (actual/365).';
COMMENT ON COLUMN account.interest_accrual.interest_accrual_id IS 'Faiz hesablanması — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN account.interest_accrual.account_id IS 'Hesab istinadı (hesablanmış faizidir).';
COMMENT ON COLUMN account.interest_accrual.accrual_date IS 'Hesablama günü.';
COMMENT ON COLUMN account.interest_accrual.balance_base IS 'Faizin hesablandığı qalıq.';
COMMENT ON COLUMN account.interest_accrual.annual_rate IS 'Tətbiq olunan illik dərəcə.';
COMMENT ON COLUMN account.interest_accrual.accrued_amount IS 'Hesablanmış faiz.';
COMMENT ON COLUMN account.interest_accrual.withholding_tax_amount IS 'Ödəmə mənbəyində tutulan vergi.';
COMMENT ON COLUMN account.interest_accrual.is_capitalized IS 'Faiz hesaba əlavə edilib (kapitallaşıb).';
COMMENT ON COLUMN account.interest_accrual.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN account.interest_accrual.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN account.interest_accrual.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN account.interest_accrual.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE account.account_interest_rate IS 'Hesab faiz dərəcəsi. Hesaba tətbiq olunan faiz dərəcəsi, qüvvədə olma tarixləri ilə; məhsulun standart dərəcəsi və ya fərdi dərəcə.';
COMMENT ON COLUMN account.account_interest_rate.account_interest_rate_id IS 'Hesab faiz dərəcəsi — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN account.account_interest_rate.account_id IS 'Hesab istinadı (faiz dərəcəsidir).';
COMMENT ON COLUMN account.account_interest_rate.product_interest_rate_id IS 'Məhsul faiz dərəcəsi istinadı (əsas götürülüb).';
COMMENT ON COLUMN account.account_interest_rate.annual_rate IS 'İllik faiz dərəcəsi.';
COMMENT ON COLUMN account.account_interest_rate.effective_from IS 'Qüvvəyə minmə tarixi.';
COMMENT ON COLUMN account.account_interest_rate.effective_to IS 'Qüvvədən düşmə tarixi.';
COMMENT ON COLUMN account.account_interest_rate.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN account.account_interest_rate.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN account.account_interest_rate.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN account.account_interest_rate.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE account.term_deposit_term IS 'Müddətli depozit şərtləri. Müddətli depozitin şərtləri: müddət, bitmə tarixi, avtomatik uzadılma, faizin ödənilmə qaydası, vaxtından əvvəl çıxarma şərtləri.';
COMMENT ON COLUMN account.term_deposit_term.term_deposit_term_id IS 'Müddətli depozit şərtləri — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN account.term_deposit_term.account_id IS 'Hesab istinadı (depozit şərtləridir).';
COMMENT ON COLUMN account.term_deposit_term.payout_account_id IS 'Hesab istinadı (faiz ödəniş hesabıdır).';
COMMENT ON COLUMN account.term_deposit_term.term_months IS 'Müddət (ay).';
COMMENT ON COLUMN account.term_deposit_term.start_date IS 'Başlama tarixi.';
COMMENT ON COLUMN account.term_deposit_term.maturity_date IS 'Bitmə tarixi.';
COMMENT ON COLUMN account.term_deposit_term.interest_payment_frequency IS 'Faizin ödənilmə tezliyi. Dəyərlər: MONTHLY, QUARTERLY, AT_MATURITY.';
COMMENT ON COLUMN account.term_deposit_term.auto_rollover IS 'Müddət bitdikdə avtomatik uzadılır.';
COMMENT ON COLUMN account.term_deposit_term.allows_top_up IS 'Əlavə vəsait qəbul edilir.';
COMMENT ON COLUMN account.term_deposit_term.allows_partial_withdrawal IS 'Qismən çıxarışa icazə verilir.';
COMMENT ON COLUMN account.term_deposit_term.early_withdrawal_rate IS 'Vaxtından əvvəl çıxarışda tətbiq olunan dərəcə.';
COMMENT ON COLUMN account.term_deposit_term.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN account.term_deposit_term.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN account.term_deposit_term.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN account.term_deposit_term.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE account.overdraft_facility IS 'Overdraft. Cari hesab üzrə overdraft limiti və şərtləri: limit, faiz dərəcəsi, qüvvədə olma tarixləri.';
COMMENT ON COLUMN account.overdraft_facility.overdraft_facility_id IS 'Overdraft — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN account.overdraft_facility.account_id IS 'Hesab istinadı (overdraftıdır).';
COMMENT ON COLUMN account.overdraft_facility.limit_amount IS 'Overdraft limiti.';
COMMENT ON COLUMN account.overdraft_facility.annual_rate IS 'İstifadə olunan məbləğə illik faiz dərəcəsi.';
COMMENT ON COLUMN account.overdraft_facility.effective_from IS 'Qüvvəyə minmə tarixi.';
COMMENT ON COLUMN account.overdraft_facility.effective_to IS 'Qüvvədən düşmə tarixi.';
COMMENT ON COLUMN account.overdraft_facility.status IS 'Status. Dəyərlər: ACTIVE, SUSPENDED, CLOSED.';
COMMENT ON COLUMN account.overdraft_facility.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN account.overdraft_facility.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN account.overdraft_facility.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN account.overdraft_facility.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE account.standing_order IS 'Daimi tapşırıq. Müştərinin müntəzəm köçürmə tapşırığı: məbləğ, tezlik, növbəti icra tarixi, başlama və bitmə tarixləri.';
COMMENT ON COLUMN account.standing_order.standing_order_id IS 'Daimi tapşırıq — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN account.standing_order.debit_account_id IS 'Hesab istinadı (debet hesabıdır).';
COMMENT ON COLUMN account.standing_order.beneficiary_id IS 'Benefisiar (alan) istinadı (alanıdır).';
COMMENT ON COLUMN account.standing_order.amount IS 'Köçürmə məbləği (debet hesabının valyutasında).';
COMMENT ON COLUMN account.standing_order.frequency IS 'Tezlik. Dəyərlər: WEEKLY, MONTHLY, QUARTERLY.';
COMMENT ON COLUMN account.standing_order.execution_day IS 'İcra günü (ayın günü və ya həftənin günü).';
COMMENT ON COLUMN account.standing_order.start_date IS 'Başlama tarixi.';
COMMENT ON COLUMN account.standing_order.end_date IS 'Bitmə tarixi.';
COMMENT ON COLUMN account.standing_order.next_execution_date IS 'Növbəti icra tarixi.';
COMMENT ON COLUMN account.standing_order.purpose IS 'Ödənişin təyinatı.';
COMMENT ON COLUMN account.standing_order.status IS 'Status. Dəyərlər: ACTIVE, PAUSED, CANCELLED, COMPLETED.';
COMMENT ON COLUMN account.standing_order.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN account.standing_order.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN account.standing_order.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN account.standing_order.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE account.account_limit IS 'Hesab limiti. Hesab üzrə əməliyyat limitləri: gündəlik və aylıq məxaric, tək əməliyyat, kanal üzrə məhdudiyyətlər.';
COMMENT ON COLUMN account.account_limit.account_limit_id IS 'Hesab limiti — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN account.account_limit.account_id IS 'Hesab istinadı (limitidir).';
COMMENT ON COLUMN account.account_limit.channel_id IS 'Xidmət kanalı istinadı (limitin kanalıdır).';
COMMENT ON COLUMN account.account_limit.limit_type IS 'Limitin növü. Dəyərlər: DAILY_DEBIT, MONTHLY_DEBIT, SINGLE_TRANSACTION.';
COMMENT ON COLUMN account.account_limit.limit_amount IS 'Limit məbləği.';
COMMENT ON COLUMN account.account_limit.effective_from IS 'Qüvvəyə minmə tarixi.';
COMMENT ON COLUMN account.account_limit.effective_to IS 'Qüvvədən düşmə tarixi.';
COMMENT ON COLUMN account.account_limit.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN account.account_limit.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN account.account_limit.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN account.account_limit.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE account.statement IS 'Hesabdan çıxarış. Dövr üzrə hesab çıxarışı: açılış və bağlanış qalığı, debet və kredit dövriyyələri, çatdırılma kanalı.';
COMMENT ON COLUMN account.statement.statement_id IS 'Hesabdan çıxarış — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN account.statement.account_id IS 'Hesab istinadı (çıxarışıdır).';
COMMENT ON COLUMN account.statement.period_start IS 'Dövrün başlanğıcı.';
COMMENT ON COLUMN account.statement.period_end IS 'Dövrün sonu.';
COMMENT ON COLUMN account.statement.opening_balance IS 'Açılış qalığı.';
COMMENT ON COLUMN account.statement.closing_balance IS 'Bağlanış qalığı.';
COMMENT ON COLUMN account.statement.total_debit IS 'Debet dövriyyəsi.';
COMMENT ON COLUMN account.statement.total_credit IS 'Kredit dövriyyəsi.';
COMMENT ON COLUMN account.statement.generated_at IS 'Hazırlanma anı.';
COMMENT ON COLUMN account.statement.delivery_channel IS 'Çatdırılma kanalı. Dəyərlər: EMAIL, INTERNET_BANKING, BRANCH, POST.';
COMMENT ON COLUMN account.statement.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN account.statement.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN account.statement.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN account.statement.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE account.account_status_history IS 'Hesab statusu tarixçəsi. Hesab statusunun dəyişiklikləri: açılış, dondurma, passiv (dormant), bağlanma; səbəb və icraçı ilə (yalnız əlavə olunur).';
COMMENT ON COLUMN account.account_status_history.account_status_history_id IS 'Hesab statusu tarixçəsi — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN account.account_status_history.account_id IS 'Hesab istinadı (status tarixçəsidir).';
COMMENT ON COLUMN account.account_status_history.from_status IS 'Əvvəlki status (ilk yazılışda boş). Dəyərlər: PENDING, ACTIVE, DORMANT, FROZEN, CLOSED.';
COMMENT ON COLUMN account.account_status_history.to_status IS 'Yeni status. Dəyərlər: PENDING, ACTIVE, DORMANT, FROZEN, CLOSED.';
COMMENT ON COLUMN account.account_status_history.changed_at IS 'Statusun dəyişdiyi an.';
COMMENT ON COLUMN account.account_status_history.reason_code IS 'Dəyişikliyin səbəb kodu.';
COMMENT ON COLUMN account.account_status_history.comment IS 'Əlavə izah.';
COMMENT ON COLUMN account.account_status_history.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN account.account_status_history.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN account.account_status_history.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN account.account_status_history.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE payment.beneficiary IS 'Benefisiar (alan). Müştərinin yadda saxladığı köçürmə alanı: ad, IBAN/hesab nömrəsi, VÖEN/FİN, alan bank.';
COMMENT ON COLUMN payment.beneficiary.beneficiary_id IS 'Benefisiar (alan) — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN payment.beneficiary.customer_id IS 'Müştəri istinadı (şablonudur).';
COMMENT ON COLUMN payment.beneficiary.bank_directory_id IS 'Bank kataloqu istinadı (alan bankdır).';
COMMENT ON COLUMN payment.beneficiary.beneficiary_name IS 'Alanın adı.';
COMMENT ON COLUMN payment.beneficiary.iban IS 'Alanın IBAN-ı.';
COMMENT ON COLUMN payment.beneficiary.account_number IS 'Alanın hesab nömrəsi (IBAN olmayan ölkələr üçün).';
COMMENT ON COLUMN payment.beneficiary.tax_id IS 'Alanın VÖEN-i və ya FİN-i.';
COMMENT ON COLUMN payment.beneficiary.alias IS 'Müştərinin verdiyi qısa ad.';
COMMENT ON COLUMN payment.beneficiary.is_active IS 'Şablon aktivdir.';
COMMENT ON COLUMN payment.beneficiary.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN payment.beneficiary.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN payment.beneficiary.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN payment.beneficiary.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE payment.payment_order IS 'Ödəniş tapşırığı. Müştərinin köçürmə tapşırığı: növü (daxili, AZIPS, XÖHKS, SWIFT, büdcə), məbləğ, valyuta, təyinat, büdcə təsnifat kodu, dəyər tarixi, status. Alanın rekvizitləri tapşırıq anındakı vəziyyətlə saxlanılır (şablon sonradan dəyişsə də tapşırıq dəyişməz).';
COMMENT ON COLUMN payment.payment_order.payment_order_id IS 'Ödəniş tapşırığı — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN payment.payment_order.debit_account_id IS 'Hesab istinadı (debet hesabıdır).';
COMMENT ON COLUMN payment.payment_order.beneficiary_id IS 'Benefisiar (alan) istinadı (alanıdır).';
COMMENT ON COLUMN payment.payment_order.beneficiary_bank_id IS 'Bank kataloqu istinadı (alan bankdır).';
COMMENT ON COLUMN payment.payment_order.currency_id IS 'Valyuta istinadı (valyutasıdır).';
COMMENT ON COLUMN payment.payment_order.channel_id IS 'Xidmət kanalı istinadı (qəbul kanalıdır).';
COMMENT ON COLUMN payment.payment_order.order_number IS 'Tapşırığın unikal nömrəsi.';
COMMENT ON COLUMN payment.payment_order.payment_type IS 'Ödənişin növü. Dəyərlər: INTERNAL, AZIPS, XOHKS, SWIFT, BUDGET.';
COMMENT ON COLUMN payment.payment_order.amount IS 'Köçürmə məbləği (tapşırığın valyutasında).';
COMMENT ON COLUMN payment.payment_order.value_date IS 'İstənilən dəyər tarixi.';
COMMENT ON COLUMN payment.payment_order.purpose IS 'Ödənişin təyinatı.';
COMMENT ON COLUMN payment.payment_order.budget_classification_code IS 'Büdcə təsnifatı kodu (büdcə ödənişləri üçün).';
COMMENT ON COLUMN payment.payment_order.budget_level_code IS 'Büdcə səviyyəsinin kodu (büdcə ödənişləri üçün).';
COMMENT ON COLUMN payment.payment_order.beneficiary_name IS 'Alanın adı (tapşırıq anında).';
COMMENT ON COLUMN payment.payment_order.beneficiary_iban IS 'Alanın IBAN-ı (tapşırıq anında).';
COMMENT ON COLUMN payment.payment_order.beneficiary_account_number IS 'Alanın hesab nömrəsi (IBAN olmadıqda).';
COMMENT ON COLUMN payment.payment_order.beneficiary_tax_id IS 'Alanın VÖEN-i / FİN-i.';
COMMENT ON COLUMN payment.payment_order.charge_bearer IS 'SWIFT komissiyasını kim ödəyir. Dəyərlər: OUR, SHA, BEN.';
COMMENT ON COLUMN payment.payment_order.priority IS 'Prioritet. Dəyərlər: NORMAL, URGENT.';
COMMENT ON COLUMN payment.payment_order.submitted_at IS 'Tapşırığın qəbul edildiyi an.';
COMMENT ON COLUMN payment.payment_order.executed_at IS 'İcra anı.';
COMMENT ON COLUMN payment.payment_order.status IS 'Tapşırığın statusu. Dəyərlər: CREATED, PENDING_APPROVAL, SCREENING, SENT, EXECUTED, REJECTED, CANCELLED, RETURNED.';
COMMENT ON COLUMN payment.payment_order.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN payment.payment_order.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN payment.payment_order.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN payment.payment_order.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE payment.payment_status_history IS 'Ödəniş statusu tarixçəsi. Ödəniş tapşırığının statuslarının dəyişikliyi: qəbul, yoxlama, göndərilmə, icra, rədd (yalnız əlavə olunur).';
COMMENT ON COLUMN payment.payment_status_history.payment_status_history_id IS 'Ödəniş statusu tarixçəsi — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN payment.payment_status_history.payment_order_id IS 'Ödəniş tapşırığı istinadı (status tarixçəsidir).';
COMMENT ON COLUMN payment.payment_status_history.from_status IS 'Əvvəlki status (ilk yazılışda boş). Dəyərlər: CREATED, PENDING_APPROVAL, SCREENING, SENT, EXECUTED, REJECTED, CANCELLED, RETURNED.';
COMMENT ON COLUMN payment.payment_status_history.to_status IS 'Yeni status. Dəyərlər: CREATED, PENDING_APPROVAL, SCREENING, SENT, EXECUTED, REJECTED, CANCELLED, RETURNED.';
COMMENT ON COLUMN payment.payment_status_history.changed_at IS 'Statusun dəyişdiyi an.';
COMMENT ON COLUMN payment.payment_status_history.reason_code IS 'Dəyişikliyin səbəb kodu.';
COMMENT ON COLUMN payment.payment_status_history.comment IS 'Əlavə izah.';
COMMENT ON COLUMN payment.payment_status_history.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN payment.payment_status_history.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN payment.payment_status_history.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN payment.payment_status_history.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE payment.payment_message IS 'Ödəniş mesajı. Ödəniş sistemlərinə göndərilən və onlardan alınan mesajlar (AZIPS, XÖHKS, SWIFT MT / ISO 20022): istiqamət, mesaj tipi, istinad, status.';
COMMENT ON COLUMN payment.payment_message.payment_message_id IS 'Ödəniş mesajı — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN payment.payment_message.payment_order_id IS 'Ödəniş tapşırığı istinadı (mesajıdır).';
COMMENT ON COLUMN payment.payment_message.direction IS 'İstiqamət. Dəyərlər: OUTBOUND, INBOUND.';
COMMENT ON COLUMN payment.payment_message.payment_system IS 'Ödəniş sistemi. Dəyərlər: AZIPS, XOHKS, SWIFT.';
COMMENT ON COLUMN payment.payment_message.message_type IS 'Mesaj tipi (MT103, pacs.008 və s.).';
COMMENT ON COLUMN payment.payment_message.message_reference IS 'Mesajın sistemdəki istinadı.';
COMMENT ON COLUMN payment.payment_message.exchanged_at IS 'Göndərilmə / qəbul anı.';
COMMENT ON COLUMN payment.payment_message.status IS 'Mesajın statusu. Dəyərlər: QUEUED, SENT, ACKNOWLEDGED, REJECTED, RECEIVED, PROCESSED.';
COMMENT ON COLUMN payment.payment_message.payload IS 'Mesajın strukturlaşdırılmış məzmunu.';
COMMENT ON COLUMN payment.payment_message.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN payment.payment_message.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN payment.payment_message.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN payment.payment_message.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE payment.payment_return IS 'Ödəniş qaytarılması. Qaytarılmış və ya rədd edilmiş ödənişlər: səbəb kodu, qaytarılan məbləğ, tarix.';
COMMENT ON COLUMN payment.payment_return.payment_return_id IS 'Ödəniş qaytarılması — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN payment.payment_return.payment_order_id IS 'Ödəniş tapşırığı istinadı (qaytarılmasıdır).';
COMMENT ON COLUMN payment.payment_return.return_reason_code IS 'Qaytarılma səbəbinin kodu.';
COMMENT ON COLUMN payment.payment_return.return_reason IS 'Səbəbin izahı.';
COMMENT ON COLUMN payment.payment_return.returned_amount IS 'Qaytarılan məbləğ.';
COMMENT ON COLUMN payment.payment_return.return_date IS 'Qaytarılma tarixi.';
COMMENT ON COLUMN payment.payment_return.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN payment.payment_return.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN payment.payment_return.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN payment.payment_return.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE payment.fx_deal IS 'Valyuta mübadiləsi. Müştərinin hesabları arasında valyuta alqı-satqısı (konversiya): satılan və alınan məbləğ, tətbiq olunan məzənnə. Valyutalar hesablardan müəyyən olunur.';
COMMENT ON COLUMN payment.fx_deal.fx_deal_id IS 'Valyuta mübadiləsi — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN payment.fx_deal.customer_id IS 'Müştəri istinadı (mübadiləsidir).';
COMMENT ON COLUMN payment.fx_deal.sell_account_id IS 'Hesab istinadı (satılan valyuta hesabıdır).';
COMMENT ON COLUMN payment.fx_deal.buy_account_id IS 'Hesab istinadı (alınan valyuta hesabıdır).';
COMMENT ON COLUMN payment.fx_deal.exchange_rate_id IS 'Valyuta məzənnəsi istinadı (tətbiq olunan məzənnədir).';
COMMENT ON COLUMN payment.fx_deal.deal_number IS 'Əqdin nömrəsi.';
COMMENT ON COLUMN payment.fx_deal.sell_amount IS 'Satılan məbləğ.';
COMMENT ON COLUMN payment.fx_deal.buy_amount IS 'Alınan məbləğ.';
COMMENT ON COLUMN payment.fx_deal.applied_rate IS 'Faktiki tətbiq olunan məzənnə (fərdi məzənnə ola bilər).';
COMMENT ON COLUMN payment.fx_deal.deal_at IS 'Əqdin anı.';
COMMENT ON COLUMN payment.fx_deal.status IS 'Status. Dəyərlər: EXECUTED, CANCELLED.';
COMMENT ON COLUMN payment.fx_deal.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN payment.fx_deal.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN payment.fx_deal.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN payment.fx_deal.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE card.merchant IS 'Satıcı (ticarət obyekti). Kartla ödəniş qəbul edən ticarət obyekti: ad, MCC, ölkə, şəhər; avtorizasiya məlumatından yaradılır.';
COMMENT ON COLUMN card.merchant.merchant_id IS 'Satıcı (ticarət obyekti) — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN card.merchant.mcc_id IS 'Satıcı kateqoriya kodu (MCC) istinadı (kateqoriyasıdır).';
COMMENT ON COLUMN card.merchant.country_id IS 'Ölkə istinadı (ölkəsidir).';
COMMENT ON COLUMN card.merchant.acquirer_id IS 'Ekvayer bankın identifikatoru.';
COMMENT ON COLUMN card.merchant.merchant_code IS 'Ekvayerin verdiyi satıcı identifikatoru (MID).';
COMMENT ON COLUMN card.merchant.name IS 'Satıcının adı (çeklərdə göstərilən).';
COMMENT ON COLUMN card.merchant.city IS 'Şəhər.';
COMMENT ON COLUMN card.merchant.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN card.merchant.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN card.merchant.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN card.merchant.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE card.card IS 'Kart. Debet və ya kredit kartı: token, maskalanmış PAN, ödəniş sistemi (Visa/Mastercard), növ (fiziki/virtual), etibarlılıq müddəti, kart sahibi, bağlı hesab, status.';
COMMENT ON COLUMN card.card.card_id IS 'Kart — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN card.card.account_id IS 'Hesab istinadı (kartıdır).';
COMMENT ON COLUMN card.card.cardholder_party_id IS 'Tərəf istinadı (kart sahibidir).';
COMMENT ON COLUMN card.card.product_id IS 'Məhsul istinadı (məhsuludur).';
COMMENT ON COLUMN card.card.replaced_card_id IS 'Kart istinadı (yenisi ilə əvəzlənib).';
COMMENT ON COLUMN card.card.card_token IS 'Kart tokeni (tam PAN təhlükəsiz kart anbarında saxlanılır).';
COMMENT ON COLUMN card.card.masked_pan IS 'Maskalanmış kart nömrəsi (416973******1234).';
COMMENT ON COLUMN card.card.card_scheme IS 'Ödəniş sistemi. Dəyərlər: VISA, MASTERCARD.';
COMMENT ON COLUMN card.card.card_kind IS 'Kartın növü. Dəyərlər: DEBIT, CREDIT.';
COMMENT ON COLUMN card.card.form_factor IS 'Fiziki və ya virtual kart. Dəyərlər: PHYSICAL, VIRTUAL.';
COMMENT ON COLUMN card.card.embossed_name IS 'Kartın üzərindəki ad.';
COMMENT ON COLUMN card.card.expiry_date IS 'Etibarlılıq müddətinin sonu (ayın son günü).';
COMMENT ON COLUMN card.card.issued_date IS 'Buraxılış tarixi.';
COMMENT ON COLUMN card.card.activated_at IS 'Aktivləşmə anı.';
COMMENT ON COLUMN card.card.is_primary IS 'Əsas kartdır (əlavə kart deyil).';
COMMENT ON COLUMN card.card.status IS 'Kartın statusu. Dəyərlər: ISSUED, ACTIVE, BLOCKED, LOST, STOLEN, EXPIRED, CLOSED.';
COMMENT ON COLUMN card.card.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN card.card.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN card.card.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN card.card.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE card.card_status_history IS 'Kart statusu tarixçəsi. Kart statusunun dəyişiklikləri: buraxılış, aktivləşmə, bloklama, itki/oğurluq, bağlanma (yalnız əlavə olunur).';
COMMENT ON COLUMN card.card_status_history.card_status_history_id IS 'Kart statusu tarixçəsi — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN card.card_status_history.card_id IS 'Kart istinadı (status tarixçəsidir).';
COMMENT ON COLUMN card.card_status_history.from_status IS 'Əvvəlki status (ilk yazılışda boş). Dəyərlər: ISSUED, ACTIVE, BLOCKED, LOST, STOLEN, EXPIRED, CLOSED.';
COMMENT ON COLUMN card.card_status_history.to_status IS 'Yeni status. Dəyərlər: ISSUED, ACTIVE, BLOCKED, LOST, STOLEN, EXPIRED, CLOSED.';
COMMENT ON COLUMN card.card_status_history.changed_at IS 'Statusun dəyişdiyi an.';
COMMENT ON COLUMN card.card_status_history.reason_code IS 'Dəyişikliyin səbəb kodu.';
COMMENT ON COLUMN card.card_status_history.comment IS 'Əlavə izah.';
COMMENT ON COLUMN card.card_status_history.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN card.card_status_history.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN card.card_status_history.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN card.card_status_history.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE card.card_limit IS 'Kart limiti. Kart üzrə limitlər: gündəlik nağdlaşdırma, POS, internet əməliyyatları, aylıq ümumi, tək əməliyyat.';
COMMENT ON COLUMN card.card_limit.card_limit_id IS 'Kart limiti — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN card.card_limit.card_id IS 'Kart istinadı (limitidir).';
COMMENT ON COLUMN card.card_limit.limit_type IS 'Limitin növü. Dəyərlər: DAILY_CASH, DAILY_PURCHASE, DAILY_ECOMMERCE, MONTHLY_TOTAL, SINGLE_TRANSACTION.';
COMMENT ON COLUMN card.card_limit.limit_amount IS 'Limit məbləği (hesab valyutasında).';
COMMENT ON COLUMN card.card_limit.max_count IS 'Əməliyyat sayı limiti.';
COMMENT ON COLUMN card.card_limit.effective_from IS 'Qüvvəyə minmə tarixi.';
COMMENT ON COLUMN card.card_limit.effective_to IS 'Qüvvədən düşmə tarixi.';
COMMENT ON COLUMN card.card_limit.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN card.card_limit.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN card.card_limit.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN card.card_limit.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE card.card_credit_line IS 'Kredit kartı xətti. Kart hesabının kredit limiti və şərtləri: hesablaşma dövrü günü, güzəşt müddəti, minimal ödəniş faizi, illik faiz dərəcəsi (actual/365).';
COMMENT ON COLUMN card.card_credit_line.card_credit_line_id IS 'Kredit kartı xətti — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN card.card_credit_line.account_id IS 'Hesab istinadı (kredit xəttidir).';
COMMENT ON COLUMN card.card_credit_line.credit_limit IS 'Kredit limiti.';
COMMENT ON COLUMN card.card_credit_line.annual_rate IS 'İllik faiz dərəcəsi.';
COMMENT ON COLUMN card.card_credit_line.billing_day IS 'Hesablaşma dövrünün bağlandığı gün (1–28).';
COMMENT ON COLUMN card.card_credit_line.grace_period_days IS 'Güzəşt müddəti (gün).';
COMMENT ON COLUMN card.card_credit_line.min_payment_percent IS 'Minimal ödəniş — borcun faizi.';
COMMENT ON COLUMN card.card_credit_line.effective_from IS 'Qüvvəyə minmə tarixi.';
COMMENT ON COLUMN card.card_credit_line.status IS 'Status. Dəyərlər: ACTIVE, SUSPENDED, CLOSED.';
COMMENT ON COLUMN card.card_credit_line.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN card.card_credit_line.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN card.card_credit_line.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN card.card_credit_line.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE card.card_authorization IS 'Kart avtorizasiyası. Bankın prosessinq sistemində kart əməliyyatı üçün real vaxt avtorizasiya sorğusu və cavabı (təsdiq/imtina): məbləğ, valyuta, satıcı/bankomat, cavab kodu, RRN, STAN. Yüksək həcmli cədvəldir, aylar üzrə bölmələnir.';
COMMENT ON COLUMN card.card_authorization.card_authorization_id IS 'Kart avtorizasiyası — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN card.card_authorization.card_id IS 'Kart istinadı (avtorizasiyasıdır).';
COMMENT ON COLUMN card.card_authorization.currency_id IS 'Valyuta istinadı (əməliyyat valyutasıdır).';
COMMENT ON COLUMN card.card_authorization.merchant_id IS 'Satıcı (ticarət obyekti) istinadı (satıcıdır).';
COMMENT ON COLUMN card.card_authorization.atm_id IS 'Bankomat istinadı (bankomatdır).';
COMMENT ON COLUMN card.card_authorization.authorization_date IS 'Avtorizasiyanın bank günü (bölmə açarı).';
COMMENT ON COLUMN card.card_authorization.authorized_at IS 'Sorğunun anı.';
COMMENT ON COLUMN card.card_authorization.transaction_kind IS 'Əməliyyatın növü. Dəyərlər: PURCHASE, CASH_WITHDRAWAL, ECOMMERCE, REFUND, BALANCE_INQUIRY, P2P.';
COMMENT ON COLUMN card.card_authorization.amount IS 'Əməliyyat valyutasında məbləğ.';
COMMENT ON COLUMN card.card_authorization.billing_amount IS 'Hesab valyutasında məbləğ (bloklanan).';
COMMENT ON COLUMN card.card_authorization.entry_mode IS 'Kart məlumatının daxil edilmə üsulu. Dəyərlər: CHIP, CONTACTLESS, MAGSTRIPE, ECOMMERCE, MANUAL.';
COMMENT ON COLUMN card.card_authorization.terminal_id IS 'Terminalın identifikatoru.';
COMMENT ON COLUMN card.card_authorization.rrn IS 'Retrieval Reference Number — əməliyyatın istinad nömrəsi.';
COMMENT ON COLUMN card.card_authorization.stan IS 'System Trace Audit Number.';
COMMENT ON COLUMN card.card_authorization.auth_code IS 'Təsdiq kodu (təsdiq edilmiş əməliyyatlar üçün).';
COMMENT ON COLUMN card.card_authorization.response_code IS 'Cavab kodu (ISO 8583, 00 — təsdiq).';
COMMENT ON COLUMN card.card_authorization.decision IS 'Qərar. Dəyərlər: APPROVED, DECLINED.';
COMMENT ON COLUMN card.card_authorization.decline_reason IS 'İmtinanın səbəbi.';
COMMENT ON COLUMN card.card_authorization.is_reversed IS 'Avtorizasiya ləğv edilib (reversal).';
COMMENT ON COLUMN card.card_authorization.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN card.card_authorization.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN card.card_authorization.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN card.card_authorization.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE card.card_transaction IS 'Kart əməliyyatı (klirinq). Ödəniş sisteminin klirinq/hesablaşma faylı ilə təsdiqlənmiş kart əməliyyatı: əməliyyat və hesablaşma məbləği, valyutası, komissiya. Yüksək həcmli cədvəldir, aylar üzrə bölmələnir.';
COMMENT ON COLUMN card.card_transaction.card_transaction_id IS 'Kart əməliyyatı (klirinq) — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN card.card_transaction.card_id IS 'Kart istinadı (əməliyyatıdır).';
COMMENT ON COLUMN card.card_transaction.currency_id IS 'Valyuta istinadı (əməliyyat valyutasıdır).';
COMMENT ON COLUMN card.card_transaction.card_authorization_id IS 'Kart avtorizasiyası istinadı (klirinqidir).';
COMMENT ON COLUMN card.card_transaction.card_authorization_date IS 'İstinad edilən `card_authorization` yazılışının bölmə tarixi (kompozit FK hissəsi).';
COMMENT ON COLUMN card.card_transaction.merchant_id IS 'Satıcı (ticarət obyekti) istinadı (satıcıdır).';
COMMENT ON COLUMN card.card_transaction.transaction_date IS 'Əməliyyatın tarixi (bölmə açarı).';
COMMENT ON COLUMN card.card_transaction.clearing_date IS 'Klirinq faylının tarixi.';
COMMENT ON COLUMN card.card_transaction.settlement_date IS 'Hesablaşma tarixi.';
COMMENT ON COLUMN card.card_transaction.transaction_kind IS 'Əməliyyatın növü. Dəyərlər: PURCHASE, CASH_WITHDRAWAL, ECOMMERCE, REFUND, BALANCE_INQUIRY, P2P.';
COMMENT ON COLUMN card.card_transaction.amount IS 'Əməliyyat valyutasında məbləğ.';
COMMENT ON COLUMN card.card_transaction.billing_amount IS 'Hesab valyutasında məbləğ.';
COMMENT ON COLUMN card.card_transaction.interchange_fee IS 'İnterçeync komissiyası.';
COMMENT ON COLUMN card.card_transaction.rrn IS 'Retrieval Reference Number.';
COMMENT ON COLUMN card.card_transaction.arn IS 'Acquirer Reference Number.';
COMMENT ON COLUMN card.card_transaction.status IS 'Status. Dəyərlər: CLEARED, POSTED, DISPUTED, REVERSED.';
COMMENT ON COLUMN card.card_transaction.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN card.card_transaction.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN card.card_transaction.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN card.card_transaction.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE card.card_billing_statement IS 'Kredit kartı çıxarışı. Kredit kartı üzrə hesablaşma dövrü çıxarışı: ümumi borc, minimal ödəniş, son ödəniş tarixi, ödənilmə vəziyyəti.';
COMMENT ON COLUMN card.card_billing_statement.card_billing_statement_id IS 'Kredit kartı çıxarışı — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN card.card_billing_statement.card_credit_line_id IS 'Kredit kartı xətti istinadı (çıxarışıdır).';
COMMENT ON COLUMN card.card_billing_statement.period_start IS 'Dövrün başlanğıcı.';
COMMENT ON COLUMN card.card_billing_statement.period_end IS 'Dövrün sonu.';
COMMENT ON COLUMN card.card_billing_statement.due_date IS 'Minimal ödənişin son tarixi.';
COMMENT ON COLUMN card.card_billing_statement.opening_balance IS 'Dövrün əvvəlinə borc.';
COMMENT ON COLUMN card.card_billing_statement.total_purchases IS 'Dövr ərzində xərclər.';
COMMENT ON COLUMN card.card_billing_statement.total_payments IS 'Dövr ərzində ödənişlər.';
COMMENT ON COLUMN card.card_billing_statement.interest_charged IS 'Hesablanmış faiz.';
COMMENT ON COLUMN card.card_billing_statement.closing_balance IS 'Dövrün sonuna ümumi borc.';
COMMENT ON COLUMN card.card_billing_statement.minimum_payment IS 'Minimal ödəniş məbləği.';
COMMENT ON COLUMN card.card_billing_statement.paid_amount IS 'Son tarixədək ödənilmiş məbləğ.';
COMMENT ON COLUMN card.card_billing_statement.status IS 'Status. Dəyərlər: OPEN, PAID, PARTIALLY_PAID, OVERDUE.';
COMMENT ON COLUMN card.card_billing_statement.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN card.card_billing_statement.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN card.card_billing_statement.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN card.card_billing_statement.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE loan.credit_application IS 'Kredit müraciəti. Kredit müraciəti: məhsul, istənilən məbləğ, valyuta və müddət, məqsəd, qərar, təsdiq edilmiş şərtlər.';
COMMENT ON COLUMN loan.credit_application.credit_application_id IS 'Kredit müraciəti — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN loan.credit_application.customer_id IS 'Müştəri istinadı (müraciətidir).';
COMMENT ON COLUMN loan.credit_application.product_id IS 'Məhsul istinadı (istənilən məhsuldur).';
COMMENT ON COLUMN loan.credit_application.currency_id IS 'Valyuta istinadı (istənilən valyutadır).';
COMMENT ON COLUMN loan.credit_application.branch_id IS 'Filial istinadı (qəbul edən filialdır).';
COMMENT ON COLUMN loan.credit_application.loan_officer_id IS 'Əməkdaş istinadı (kredit mütəxəssisidir).';
COMMENT ON COLUMN loan.credit_application.application_number IS 'Müraciətin nömrəsi.';
COMMENT ON COLUMN loan.credit_application.requested_amount IS 'İstənilən məbləğ.';
COMMENT ON COLUMN loan.credit_application.requested_term_months IS 'İstənilən müddət (ay).';
COMMENT ON COLUMN loan.credit_application.purpose IS 'Kreditin məqsədi.';
COMMENT ON COLUMN loan.credit_application.submitted_at IS 'Müraciət anı.';
COMMENT ON COLUMN loan.credit_application.decision_at IS 'Qərar anı.';
COMMENT ON COLUMN loan.credit_application.approved_amount IS 'Təsdiq edilmiş məbləğ.';
COMMENT ON COLUMN loan.credit_application.approved_term_months IS 'Təsdiq edilmiş müddət (ay).';
COMMENT ON COLUMN loan.credit_application.approved_rate IS 'Təsdiq edilmiş illik faiz dərəcəsi.';
COMMENT ON COLUMN loan.credit_application.rejection_reason IS 'İmtinanın səbəbi.';
COMMENT ON COLUMN loan.credit_application.status IS 'Müraciətin statusu. Dəyərlər: DRAFT, SUBMITTED, UNDER_REVIEW, APPROVED, REJECTED, CANCELLED, CONTRACTED.';
COMMENT ON COLUMN loan.credit_application.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN loan.credit_application.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN loan.credit_application.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN loan.credit_application.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE loan.credit_bureau_check IS 'Kredit Bürosu sorğusu. Azərbaycan Kredit Bürosuna sorğu və nəticəsi: kredit skoru, mövcud öhdəliklər, gecikmələr; tərəfin razılığı əsasında.';
COMMENT ON COLUMN loan.credit_bureau_check.credit_bureau_check_id IS 'Kredit Bürosu sorğusu — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN loan.credit_bureau_check.party_id IS 'Tərəf istinadı (yoxlanılan tərəfdir).';
COMMENT ON COLUMN loan.credit_bureau_check.credit_application_id IS 'Kredit müraciəti istinadı (sorğusudur).';
COMMENT ON COLUMN loan.credit_bureau_check.requested_at IS 'Sorğu anı.';
COMMENT ON COLUMN loan.credit_bureau_check.bureau_reference IS 'Büronun hesabat istinadı.';
COMMENT ON COLUMN loan.credit_bureau_check.credit_score IS 'Kredit skoru.';
COMMENT ON COLUMN loan.credit_bureau_check.total_outstanding_debt IS 'Bütün banklar üzrə qalıq borc (AZN).';
COMMENT ON COLUMN loan.credit_bureau_check.active_loan_count IS 'Aktiv kreditlərin sayı.';
COMMENT ON COLUMN loan.credit_bureau_check.max_days_past_due IS 'Maksimal gecikmə günləri.';
COMMENT ON COLUMN loan.credit_bureau_check.result IS 'Sorğunun nəticəsi. Dəyərlər: SUCCESS, NO_HIT, ERROR.';
COMMENT ON COLUMN loan.credit_bureau_check.report IS 'Büronun hesabatı (strukturlaşdırılmış).';
COMMENT ON COLUMN loan.credit_bureau_check.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN loan.credit_bureau_check.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN loan.credit_bureau_check.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN loan.credit_bureau_check.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE loan.credit_facility IS 'Kredit xətti. Biznes müştəriləri üçün kredit xətti (bərpa olunan və ya olunmayan): ümumi limit, valyuta, istifadə müddəti. Xətt üzrə bir neçə kredit (tranş) verilə bilər; istifadə olunmuş məbləğ tranşların qalıqlarının cəmidir.';
COMMENT ON COLUMN loan.credit_facility.credit_facility_id IS 'Kredit xətti — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN loan.credit_facility.customer_id IS 'Müştəri istinadı (kredit xəttidir).';
COMMENT ON COLUMN loan.credit_facility.credit_application_id IS 'Kredit müraciəti istinadı (əsasında açılıb).';
COMMENT ON COLUMN loan.credit_facility.currency_id IS 'Valyuta istinadı (valyutasıdır).';
COMMENT ON COLUMN loan.credit_facility.facility_number IS 'Kredit xətti müqaviləsinin nömrəsi.';
COMMENT ON COLUMN loan.credit_facility.facility_type IS 'Bərpa olunan və ya olunmayan. Dəyərlər: REVOLVING, NON_REVOLVING.';
COMMENT ON COLUMN loan.credit_facility.limit_amount IS 'Ümumi limit.';
COMMENT ON COLUMN loan.credit_facility.available_from IS 'İstifadənin başlanğıcı.';
COMMENT ON COLUMN loan.credit_facility.available_until IS 'Yeni tranş götürmək üçün son tarix.';
COMMENT ON COLUMN loan.credit_facility.maturity_date IS 'Xəttin son ödəniş tarixi.';
COMMENT ON COLUMN loan.credit_facility.commitment_fee_rate IS 'İstifadə olunmamış limitə illik komissiya dərəcəsi.';
COMMENT ON COLUMN loan.credit_facility.status IS 'Status. Dəyərlər: ACTIVE, SUSPENDED, EXPIRED, CLOSED.';
COMMENT ON COLUMN loan.credit_facility.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN loan.credit_facility.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN loan.credit_facility.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN loan.credit_facility.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE loan.loan IS 'Kredit. Kredit müqaviləsi və kredit hesabı: növ (istehlak, ipoteka, biznes, xətt üzrə tranş), məbləğ, valyuta, faiz dərəcəsi, müddət, ödəniş metodu (annuitet/diferensial), dəbbə şərtləri, qalıq borc, gecikmə günləri, status. Qalıq borc və gecikmə günləri əməliyyatlarla yenilənən idarə olunan denormallaşdırmadır.';
COMMENT ON COLUMN loan.loan.loan_id IS 'Kredit — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN loan.loan.customer_id IS 'Müştəri istinadı (kreditidir).';
COMMENT ON COLUMN loan.loan.product_id IS 'Məhsul istinadı (məhsuludur).';
COMMENT ON COLUMN loan.loan.currency_id IS 'Valyuta istinadı (valyutasıdır).';
COMMENT ON COLUMN loan.loan.credit_application_id IS 'Kredit müraciəti istinadı (əsasında verilib).';
COMMENT ON COLUMN loan.loan.credit_facility_id IS 'Kredit xətti istinadı (tranşıdır).';
COMMENT ON COLUMN loan.loan.settlement_account_id IS 'Hesab istinadı (hesablaşma hesabıdır).';
COMMENT ON COLUMN loan.loan.branch_id IS 'Filial istinadı (kreditin filialıdır).';
COMMENT ON COLUMN loan.loan.loan_number IS 'Kredit müqaviləsinin nömrəsi.';
COMMENT ON COLUMN loan.loan.loan_type IS 'Kreditin növü. Dəyərlər: CONSUMER, MORTGAGE, BUSINESS, FACILITY_TRANCHE.';
COMMENT ON COLUMN loan.loan.principal_amount IS 'Kreditin məbləği.';
COMMENT ON COLUMN loan.loan.annual_rate IS 'İllik faiz dərəcəsi (actual/365).';
COMMENT ON COLUMN loan.loan.rate_type IS 'Sabit və ya üzən dərəcə. Dəyərlər: FIXED, FLOATING.';
COMMENT ON COLUMN loan.loan.term_months IS 'Müddət (ay).';
COMMENT ON COLUMN loan.loan.contract_date IS 'Müqavilə tarixi.';
COMMENT ON COLUMN loan.loan.start_date IS 'Faiz hesablanmasının başlanğıcı.';
COMMENT ON COLUMN loan.loan.maturity_date IS 'Son ödəniş tarixi.';
COMMENT ON COLUMN loan.loan.repayment_method IS 'Ödəniş metodu. Dəyərlər: ANNUITY, DIFFERENTIATED, BULLET.';
COMMENT ON COLUMN loan.loan.payment_day IS 'Aylıq ödəniş günü (1–28).';
COMMENT ON COLUMN loan.loan.penalty_daily_rate IS 'Dəbbənin gündəlik dərəcəsi (0.001000 = gündə 0.1%).';
COMMENT ON COLUMN loan.loan.penalty_base IS 'Dəbbənin hesablandığı baza (müqavilə ilə müəyyən olunur): gecikmiş əsas borc və ya gecikmiş əsas borc + faiz. Dəyərlər: OVERDUE_PRINCIPAL, OVERDUE_PRINCIPAL_AND_INTEREST.';
COMMENT ON COLUMN loan.loan.outstanding_principal IS 'Qalıq əsas borc.';
COMMENT ON COLUMN loan.loan.days_past_due IS 'Cari gecikmə günləri.';
COMMENT ON COLUMN loan.loan.status IS 'Kreditin statusu. Dəyərlər: APPROVED, ACTIVE, OVERDUE, RESTRUCTURED, WRITTEN_OFF, CLOSED.';
COMMENT ON COLUMN loan.loan.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN loan.loan.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN loan.loan.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN loan.loan.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE loan.loan_disbursement IS 'Kreditin verilməsi. Kredit məbləğinin (və ya onun bir hissəsinin) müştəri hesabına köçürülməsi.';
COMMENT ON COLUMN loan.loan_disbursement.loan_disbursement_id IS 'Kreditin verilməsi — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN loan.loan_disbursement.loan_id IS 'Kredit istinadı (verilməsidir).';
COMMENT ON COLUMN loan.loan_disbursement.target_account_id IS 'Hesab istinadı (köçürüldüyü hesabdır).';
COMMENT ON COLUMN loan.loan_disbursement.disbursement_date IS 'Verilmə tarixi.';
COMMENT ON COLUMN loan.loan_disbursement.amount IS 'Verilən məbləğ.';
COMMENT ON COLUMN loan.loan_disbursement.status IS 'Status. Dəyərlər: PENDING, COMPLETED, CANCELLED.';
COMMENT ON COLUMN loan.loan_disbursement.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN loan.loan_disbursement.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN loan.loan_disbursement.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN loan.loan_disbursement.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE loan.repayment_schedule IS 'Ödəniş qrafiki. Kreditin ödəniş qrafiki: hər ödəniş tarixi üzrə əsas borc, faiz və komissiya məbləğləri, ödənilmiş hissələr. Restrukturizasiya zamanı yeni qrafik versiyası yaradılır, köhnə sətirlər SUPERSEDED olur.';
COMMENT ON COLUMN loan.repayment_schedule.repayment_schedule_id IS 'Ödəniş qrafiki — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN loan.repayment_schedule.loan_id IS 'Kredit istinadı (ödəniş qrafikidir).';
COMMENT ON COLUMN loan.repayment_schedule.schedule_version IS 'Qrafikin versiyası.';
COMMENT ON COLUMN loan.repayment_schedule.installment_number IS 'Ödənişin sıra nömrəsi.';
COMMENT ON COLUMN loan.repayment_schedule.due_date IS 'Ödəniş tarixi.';
COMMENT ON COLUMN loan.repayment_schedule.principal_due IS 'Ödənilməli əsas borc.';
COMMENT ON COLUMN loan.repayment_schedule.interest_due IS 'Ödənilməli faiz.';
COMMENT ON COLUMN loan.repayment_schedule.fee_due IS 'Ödənilməli komissiya.';
COMMENT ON COLUMN loan.repayment_schedule.principal_paid IS 'Ödənilmiş əsas borc.';
COMMENT ON COLUMN loan.repayment_schedule.interest_paid IS 'Ödənilmiş faiz.';
COMMENT ON COLUMN loan.repayment_schedule.fee_paid IS 'Ödənilmiş komissiya.';
COMMENT ON COLUMN loan.repayment_schedule.status IS 'Status. Dəyərlər: PENDING, PARTIALLY_PAID, PAID, OVERDUE, SUPERSEDED.';
COMMENT ON COLUMN loan.repayment_schedule.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN loan.repayment_schedule.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN loan.repayment_schedule.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN loan.repayment_schedule.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE loan.loan_repayment IS 'Kredit ödənişi. Müştərinin kredit üzrə etdiyi ödəniş: məbləğ, tarix, mənbə hesab, vaxtından əvvəl ödəniş əlaməti.';
COMMENT ON COLUMN loan.loan_repayment.loan_repayment_id IS 'Kredit ödənişi — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN loan.loan_repayment.loan_id IS 'Kredit istinadı (ödənişidir).';
COMMENT ON COLUMN loan.loan_repayment.source_account_id IS 'Hesab istinadı (mənbə hesabdır).';
COMMENT ON COLUMN loan.loan_repayment.payment_date IS 'Ödəniş tarixi.';
COMMENT ON COLUMN loan.loan_repayment.value_date IS 'Dəyər tarixi.';
COMMENT ON COLUMN loan.loan_repayment.amount IS 'Ödənilən məbləğ (kredit valyutasında).';
COMMENT ON COLUMN loan.loan_repayment.is_early_repayment IS 'Vaxtından əvvəl ödənişdir.';
COMMENT ON COLUMN loan.loan_repayment.status IS 'Status. Dəyərlər: POSTED, REVERSED.';
COMMENT ON COLUMN loan.loan_repayment.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN loan.loan_repayment.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN loan.loan_repayment.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN loan.loan_repayment.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE loan.repayment_allocation IS 'Ödənişin bölüşdürülməsi. Ödənişin qrafik üzrə ödənişlərə və komponentlərə bölüşdürülməsi. Növbəlilik: dəbbə → faiz → əsas borc → komissiya.';
COMMENT ON COLUMN loan.repayment_allocation.repayment_allocation_id IS 'Ödənişin bölüşdürülməsi — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN loan.repayment_allocation.loan_repayment_id IS 'Kredit ödənişi istinadı (bölüşdürülməsidir).';
COMMENT ON COLUMN loan.repayment_allocation.repayment_schedule_id IS 'Ödəniş qrafiki istinadı (örtülən ödənişdir).';
COMMENT ON COLUMN loan.repayment_allocation.component IS 'Komponent. Dəyərlər: PENALTY, INTEREST, PRINCIPAL, FEE.';
COMMENT ON COLUMN loan.repayment_allocation.amount IS 'Bu komponentə yönəldilən məbləğ.';
COMMENT ON COLUMN loan.repayment_allocation.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN loan.repayment_allocation.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN loan.repayment_allocation.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN loan.repayment_allocation.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE loan.loan_penalty_charge IS 'Dəbbə (cərimə). Gecikmiş qrafik ödənişinə görə hər gün hesablanan dəbbə: gecikmiş məbləğ (kreditin dəbbə bazasına görə) × gündəlik dərəcə.';
COMMENT ON COLUMN loan.loan_penalty_charge.loan_penalty_charge_id IS 'Dəbbə (cərimə) — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN loan.loan_penalty_charge.repayment_schedule_id IS 'Ödəniş qrafiki istinadı (gecikmiş ödənişdir).';
COMMENT ON COLUMN loan.loan_penalty_charge.penalty_date IS 'Hesablama günü.';
COMMENT ON COLUMN loan.loan_penalty_charge.overdue_amount IS 'Həmin gün gecikmiş məbləğ (dəbbə bazası).';
COMMENT ON COLUMN loan.loan_penalty_charge.daily_rate IS 'Tətbiq olunan gündəlik dərəcə.';
COMMENT ON COLUMN loan.loan_penalty_charge.penalty_amount IS 'Hesablanmış dəbbə.';
COMMENT ON COLUMN loan.loan_penalty_charge.paid_amount IS 'Ödənilmiş hissə.';
COMMENT ON COLUMN loan.loan_penalty_charge.status IS 'Status. Dəyərlər: ACCRUED, PAID, WAIVED.';
COMMENT ON COLUMN loan.loan_penalty_charge.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN loan.loan_penalty_charge.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN loan.loan_penalty_charge.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN loan.loan_penalty_charge.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE loan.collateral IS 'Girov. Girov predmeti: növ, təsvir, mülkiyyətçi, reyestr qeydiyyatı (daşınmaz əmlak çıxarışı, nəqliyyat vasitəsinin qeydiyyatı), girov qoyulmuş depozit hesabı.';
COMMENT ON COLUMN loan.collateral.collateral_id IS 'Girov — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN loan.collateral.collateral_type_id IS 'Girov növü istinadı (növüdür).';
COMMENT ON COLUMN loan.collateral.owner_party_id IS 'Tərəf istinadı (mülkiyyətçisidir).';
COMMENT ON COLUMN loan.collateral.currency_id IS 'Valyuta istinadı (dəyərin valyutasıdır).';
COMMENT ON COLUMN loan.collateral.pledged_account_id IS 'Hesab istinadı (girov qoyulmuş depozitdir).';
COMMENT ON COLUMN loan.collateral.description IS 'Girov predmetinin təsviri.';
COMMENT ON COLUMN loan.collateral.registry_number IS 'Dövlət reyestrində qeydiyyat nömrəsi.';
COMMENT ON COLUMN loan.collateral.registry_authority IS 'Reyestri aparan orqan.';
COMMENT ON COLUMN loan.collateral.location_address IS 'Yerləşmə ünvanı.';
COMMENT ON COLUMN loan.collateral.initial_value IS 'İlkin razılaşdırılmış dəyər.';
COMMENT ON COLUMN loan.collateral.status IS 'Status. Dəyərlər: ACTIVE, RELEASED, FORECLOSED.';
COMMENT ON COLUMN loan.collateral.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN loan.collateral.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN loan.collateral.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN loan.collateral.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE loan.collateral_valuation IS 'Girovun qiymətləndirilməsi. Girovun bazar və likvid dəyərinin qiymətləndirilməsi: tarix, qiymətləndirici, məbləğ (girovun valyutasında).';
COMMENT ON COLUMN loan.collateral_valuation.collateral_valuation_id IS 'Girovun qiymətləndirilməsi — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN loan.collateral_valuation.collateral_id IS 'Girov istinadı (qiymətləndirilməsidir).';
COMMENT ON COLUMN loan.collateral_valuation.valuation_date IS 'Qiymətləndirmə tarixi.';
COMMENT ON COLUMN loan.collateral_valuation.market_value IS 'Bazar dəyəri.';
COMMENT ON COLUMN loan.collateral_valuation.liquidation_value IS 'Likvid (məcburi satış) dəyəri.';
COMMENT ON COLUMN loan.collateral_valuation.valuation_method IS 'Qiymətləndirmə üsulu. Dəyərlər: MARKET, INCOME, COST.';
COMMENT ON COLUMN loan.collateral_valuation.valuer_name IS 'Qiymətləndirici (şirkət və ya şəxs).';
COMMENT ON COLUMN loan.collateral_valuation.next_valuation_date IS 'Növbəti qiymətləndirmə tarixi.';
COMMENT ON COLUMN loan.collateral_valuation.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN loan.collateral_valuation.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN loan.collateral_valuation.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN loan.collateral_valuation.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE loan.loan_collateral IS 'Kreditin girovu. Kredit və ya kredit xətti ilə girov arasında əlaqə: təminat məbləği, girov müqaviləsi nömrəsi, prioritet, qüvvədə olma tarixləri.';
COMMENT ON COLUMN loan.loan_collateral.loan_collateral_id IS 'Kreditin girovu — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN loan.loan_collateral.collateral_id IS 'Girov istinadı (təminatdır).';
COMMENT ON COLUMN loan.loan_collateral.loan_id IS 'Kredit istinadı (təmin edilən kreditdir).';
COMMENT ON COLUMN loan.loan_collateral.credit_facility_id IS 'Kredit xətti istinadı (təmin edilən xətdir).';
COMMENT ON COLUMN loan.loan_collateral.pledge_agreement_number IS 'Girov müqaviləsinin nömrəsi.';
COMMENT ON COLUMN loan.loan_collateral.secured_amount IS 'Bu girovla təmin edilən məbləğ.';
COMMENT ON COLUMN loan.loan_collateral.priority_rank IS 'Girovun növbəliliyi (1 — birinci növbəli).';
COMMENT ON COLUMN loan.loan_collateral.effective_from IS 'Qüvvəyə minmə tarixi.';
COMMENT ON COLUMN loan.loan_collateral.effective_to IS 'Qüvvədən düşmə tarixi.';
COMMENT ON COLUMN loan.loan_collateral.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN loan.loan_collateral.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN loan.loan_collateral.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN loan.loan_collateral.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE loan.loan_guarantee IS 'Zaminlik. Kredit və ya kredit xətti üzrə zamin (fiziki və ya hüquqi şəxs) və zaminlik müqaviləsi: zəmanət məbləği, qüvvədə olma tarixləri.';
COMMENT ON COLUMN loan.loan_guarantee.loan_guarantee_id IS 'Zaminlik — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN loan.loan_guarantee.guarantor_party_id IS 'Tərəf istinadı (zamindir).';
COMMENT ON COLUMN loan.loan_guarantee.loan_id IS 'Kredit istinadı (zəmanət verilən kreditdir).';
COMMENT ON COLUMN loan.loan_guarantee.credit_facility_id IS 'Kredit xətti istinadı (zəmanət verilən xətdir).';
COMMENT ON COLUMN loan.loan_guarantee.guarantee_agreement_number IS 'Zaminlik müqaviləsinin nömrəsi.';
COMMENT ON COLUMN loan.loan_guarantee.guaranteed_amount IS 'Zəmanət məbləği.';
COMMENT ON COLUMN loan.loan_guarantee.effective_from IS 'Qüvvəyə minmə tarixi.';
COMMENT ON COLUMN loan.loan_guarantee.effective_to IS 'Qüvvədən düşmə tarixi.';
COMMENT ON COLUMN loan.loan_guarantee.status IS 'Status. Dəyərlər: ACTIVE, RELEASED, CALLED.';
COMMENT ON COLUMN loan.loan_guarantee.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN loan.loan_guarantee.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN loan.loan_guarantee.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN loan.loan_guarantee.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE loan.covenant IS 'Kovenant. Biznes krediti üzrə maliyyə və qeyri-maliyyə şərtləri (məs. borc/EBITDA həddi) və onların yerinə yetirilməsinin yoxlanması.';
COMMENT ON COLUMN loan.covenant.covenant_id IS 'Kovenant — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN loan.covenant.loan_id IS 'Kredit istinadı (şərtidir).';
COMMENT ON COLUMN loan.covenant.credit_facility_id IS 'Kredit xətti istinadı (şərtidir).';
COMMENT ON COLUMN loan.covenant.covenant_type IS 'Növ. Dəyərlər: FINANCIAL, NON_FINANCIAL.';
COMMENT ON COLUMN loan.covenant.description IS 'Şərtin mətni.';
COMMENT ON COLUMN loan.covenant.metric IS 'Ölçülən göstərici (maliyyə kovenantları üçün).';
COMMENT ON COLUMN loan.covenant.threshold_operator IS 'Müqayisə operatoru. Dəyərlər: LT, LE, GT, GE, EQ.';
COMMENT ON COLUMN loan.covenant.threshold_value IS 'Hədd dəyəri.';
COMMENT ON COLUMN loan.covenant.test_frequency IS 'Yoxlama tezliyi. Dəyərlər: MONTHLY, QUARTERLY, ANNUAL.';
COMMENT ON COLUMN loan.covenant.last_tested_date IS 'Son yoxlama tarixi.';
COMMENT ON COLUMN loan.covenant.last_test_result IS 'Son yoxlamanın nəticəsi. Dəyərlər: MET, BREACHED, WAIVED.';
COMMENT ON COLUMN loan.covenant.status IS 'Status. Dəyərlər: ACTIVE, CLOSED.';
COMMENT ON COLUMN loan.covenant.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN loan.covenant.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN loan.covenant.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN loan.covenant.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE loan.loan_restructuring IS 'Restrukturizasiya. Kredit şərtlərinin dəyişdirilməsi: müddət, faiz, ödəniş qrafiki; səbəb, təsdiq edən və qüvvəyə minmə tarixi.';
COMMENT ON COLUMN loan.loan_restructuring.loan_restructuring_id IS 'Restrukturizasiya — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN loan.loan_restructuring.loan_id IS 'Kredit istinadı (restrukturizasiyasıdır).';
COMMENT ON COLUMN loan.loan_restructuring.approved_by_employee_id IS 'Əməkdaş istinadı (təsdiq edib).';
COMMENT ON COLUMN loan.loan_restructuring.effective_date IS 'Yeni şərtlərin qüvvəyə minmə tarixi.';
COMMENT ON COLUMN loan.loan_restructuring.reason IS 'Səbəb.';
COMMENT ON COLUMN loan.loan_restructuring.old_annual_rate IS 'Əvvəlki illik dərəcə.';
COMMENT ON COLUMN loan.loan_restructuring.new_annual_rate IS 'Yeni illik dərəcə.';
COMMENT ON COLUMN loan.loan_restructuring.old_maturity_date IS 'Əvvəlki son ödəniş tarixi.';
COMMENT ON COLUMN loan.loan_restructuring.new_maturity_date IS 'Yeni son ödəniş tarixi.';
COMMENT ON COLUMN loan.loan_restructuring.new_schedule_version IS 'Yaradılan yeni qrafik versiyası.';
COMMENT ON COLUMN loan.loan_restructuring.status IS 'Status. Dəyərlər: PROPOSED, APPROVED, APPLIED, REJECTED.';
COMMENT ON COLUMN loan.loan_restructuring.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN loan.loan_restructuring.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN loan.loan_restructuring.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN loan.loan_restructuring.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE loan.loan_status_history IS 'Kredit statusu tarixçəsi. Kredit statusunun dəyişiklikləri: aktiv, gecikmədə, restrukturizasiya, silinmiş, bağlanmış (yalnız əlavə olunur).';
COMMENT ON COLUMN loan.loan_status_history.loan_status_history_id IS 'Kredit statusu tarixçəsi — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN loan.loan_status_history.loan_id IS 'Kredit istinadı (status tarixçəsidir).';
COMMENT ON COLUMN loan.loan_status_history.from_status IS 'Əvvəlki status (ilk yazılışda boş). Dəyərlər: APPROVED, ACTIVE, OVERDUE, RESTRUCTURED, WRITTEN_OFF, CLOSED.';
COMMENT ON COLUMN loan.loan_status_history.to_status IS 'Yeni status. Dəyərlər: APPROVED, ACTIVE, OVERDUE, RESTRUCTURED, WRITTEN_OFF, CLOSED.';
COMMENT ON COLUMN loan.loan_status_history.changed_at IS 'Statusun dəyişdiyi an.';
COMMENT ON COLUMN loan.loan_status_history.reason_code IS 'Dəyişikliyin səbəb kodu.';
COMMENT ON COLUMN loan.loan_status_history.comment IS 'Əlavə izah.';
COMMENT ON COLUMN loan.loan_status_history.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN loan.loan_status_history.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN loan.loan_status_history.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN loan.loan_status_history.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ledger.gl_account IS 'Baş kitab hesabı. Balans və balansdankənar baş kitab hesabları; qrup hesabları və yazılış aparılan hesablar.';
COMMENT ON COLUMN ledger.gl_account.gl_account_id IS 'Baş kitab hesabı — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ledger.gl_account.parent_gl_account_id IS 'Baş kitab hesabı istinadı (alt hesabıdır).';
COMMENT ON COLUMN ledger.gl_account.account_code IS 'Hesabın kodu.';
COMMENT ON COLUMN ledger.gl_account.name IS 'Hesabın adı.';
COMMENT ON COLUMN ledger.gl_account.account_class IS 'Hesab sinfi. Dəyərlər: ASSET, LIABILITY, EQUITY, INCOME, EXPENSE, OFF_BALANCE.';
COMMENT ON COLUMN ledger.gl_account.normal_balance IS 'Normal qalıq tərəfi. Dəyərlər: DEBIT, CREDIT.';
COMMENT ON COLUMN ledger.gl_account.is_postable IS 'Bu hesaba yazılış aparıla bilər (qrup hesabı deyil).';
COMMENT ON COLUMN ledger.gl_account.is_active IS 'Hesab aktivdir.';
COMMENT ON COLUMN ledger.gl_account.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ledger.gl_account.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ledger.gl_account.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ledger.gl_account.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ledger.accounting_period IS 'Mühasibat dövrü. Aylıq mühasibat dövrləri və onların statusu (açıq, bağlanır, bağlı). Bağlı dövrə yazılış aparılmır.';
COMMENT ON COLUMN ledger.accounting_period.accounting_period_id IS 'Mühasibat dövrü — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ledger.accounting_period.period_code IS 'Dövrün kodu (2026-10).';
COMMENT ON COLUMN ledger.accounting_period.start_date IS 'Dövrün başlanğıcı.';
COMMENT ON COLUMN ledger.accounting_period.end_date IS 'Dövrün sonu.';
COMMENT ON COLUMN ledger.accounting_period.status IS 'Status. Dəyərlər: OPEN, CLOSING, CLOSED.';
COMMENT ON COLUMN ledger.accounting_period.closed_at IS 'Bağlanma anı.';
COMMENT ON COLUMN ledger.accounting_period.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ledger.accounting_period.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ledger.accounting_period.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ledger.accounting_period.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ledger.posting_rule IS 'Yazılış qaydası. Məhsul və əməliyyat növünə görə debet və kredit baş kitab hesablarının müəyyən edilməsi qaydası; məhsul göstərilməyibsə qayda bütün məhsullara aiddir.';
COMMENT ON COLUMN ledger.posting_rule.posting_rule_id IS 'Yazılış qaydası — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ledger.posting_rule.transaction_type_id IS 'Əməliyyat növü istinadı (qaydasıdır).';
COMMENT ON COLUMN ledger.posting_rule.product_id IS 'Məhsul istinadı (qaydasıdır).';
COMMENT ON COLUMN ledger.posting_rule.debit_gl_account_id IS 'Baş kitab hesabı istinadı (debet hesabıdır).';
COMMENT ON COLUMN ledger.posting_rule.credit_gl_account_id IS 'Baş kitab hesabı istinadı (kredit hesabıdır).';
COMMENT ON COLUMN ledger.posting_rule.effective_from IS 'Qüvvəyə minmə tarixi.';
COMMENT ON COLUMN ledger.posting_rule.effective_to IS 'Qüvvədən düşmə tarixi.';
COMMENT ON COLUMN ledger.posting_rule.description IS 'Qaydanın izahı.';
COMMENT ON COLUMN ledger.posting_rule.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ledger.posting_rule.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ledger.posting_rule.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ledger.posting_rule.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ledger.journal_entry IS 'Mühasibat yazılışı. Mühasibat yazılışının başlığı: yazılış tarixi, dövr, mənbə hesab əməliyyatı, təsvir, status (qaralama/yazılıb/storno).';
COMMENT ON COLUMN ledger.journal_entry.journal_entry_id IS 'Mühasibat yazılışı — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ledger.journal_entry.accounting_period_id IS 'Mühasibat dövrü istinadı (dövrün yazılışıdır).';
COMMENT ON COLUMN ledger.journal_entry.account_transaction_id IS 'Hesab əməliyyatı istinadı (mühasibat əksidir).';
COMMENT ON COLUMN ledger.journal_entry.account_transaction_date IS 'İstinad edilən `account_transaction` yazılışının bölmə tarixi (kompozit FK hissəsi).';
COMMENT ON COLUMN ledger.journal_entry.entry_number IS 'Yazılışın nömrəsi.';
COMMENT ON COLUMN ledger.journal_entry.entry_date IS 'Yazılış tarixi.';
COMMENT ON COLUMN ledger.journal_entry.description IS 'Təsvir.';
COMMENT ON COLUMN ledger.journal_entry.status IS 'Status. Dəyərlər: DRAFT, POSTED, REVERSED.';
COMMENT ON COLUMN ledger.journal_entry.posted_at IS 'Yazılış anı.';
COMMENT ON COLUMN ledger.journal_entry.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ledger.journal_entry.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ledger.journal_entry.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ledger.journal_entry.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE ledger.journal_entry_line IS 'Yazılış sətri. Yazılışın debet və kredit sətirləri; hər yazılış üzrə AZN ekvivalentində debet və kredit cəmi bərabər olmalıdır (tətbiq səviyyəsində yazılış zamanı yoxlanılır). Yüksək həcmli cədvəldir, aylar üzrə bölmələnir.';
COMMENT ON COLUMN ledger.journal_entry_line.journal_entry_line_id IS 'Yazılış sətri — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN ledger.journal_entry_line.journal_entry_id IS 'Mühasibat yazılışı istinadı (sətiridir).';
COMMENT ON COLUMN ledger.journal_entry_line.gl_account_id IS 'Baş kitab hesabı istinadı (hesabıdır).';
COMMENT ON COLUMN ledger.journal_entry_line.currency_id IS 'Valyuta istinadı (valyutasıdır).';
COMMENT ON COLUMN ledger.journal_entry_line.branch_id IS 'Filial istinadı (bölməsidir).';
COMMENT ON COLUMN ledger.journal_entry_line.entry_date IS 'Yazılış tarixi (bölmə açarı).';
COMMENT ON COLUMN ledger.journal_entry_line.line_number IS 'Sətrin sıra nömrəsi.';
COMMENT ON COLUMN ledger.journal_entry_line.side IS 'Debet və ya kredit. Dəyərlər: DEBIT, CREDIT.';
COMMENT ON COLUMN ledger.journal_entry_line.amount IS 'Sətrin valyutasında məbləğ.';
COMMENT ON COLUMN ledger.journal_entry_line.amount_azn IS 'AZN ekvivalenti (AMB rəsmi məzənnəsi ilə).';
COMMENT ON COLUMN ledger.journal_entry_line.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN ledger.journal_entry_line.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN ledger.journal_entry_line.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN ledger.journal_entry_line.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE compliance.screening_check IS 'Sanksiya / PEP yoxlaması. Tərəfin və ya ödənişin sanksiya və PEP siyahıları üzrə yoxlanılması: siyahı, uyğunluq dərəcəsi, nəticə, qərar.';
COMMENT ON COLUMN compliance.screening_check.screening_check_id IS 'Sanksiya / PEP yoxlaması — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN compliance.screening_check.party_id IS 'Tərəf istinadı (yoxlanılan tərəfdir).';
COMMENT ON COLUMN compliance.screening_check.payment_order_id IS 'Ödəniş tapşırığı istinadı (yoxlanılan ödənişdir).';
COMMENT ON COLUMN compliance.screening_check.screened_at IS 'Yoxlama anı.';
COMMENT ON COLUMN compliance.screening_check.list_name IS 'Siyahı. Dəyərlər: UN, EU, OFAC, UK_HMT, LOCAL, PEP.';
COMMENT ON COLUMN compliance.screening_check.screened_name IS 'Yoxlanılan ad.';
COMMENT ON COLUMN compliance.screening_check.match_score IS 'Uyğunluq dərəcəsi (%).';
COMMENT ON COLUMN compliance.screening_check.result IS 'Nəticə. Dəyərlər: NO_MATCH, POTENTIAL_MATCH, TRUE_MATCH, FALSE_POSITIVE.';
COMMENT ON COLUMN compliance.screening_check.decided_at IS 'Əməkdaşın qərar anı (potensial uyğunluqlar üçün).';
COMMENT ON COLUMN compliance.screening_check.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN compliance.screening_check.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN compliance.screening_check.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN compliance.screening_check.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE compliance.aml_case IS 'AML işi. Bir və ya bir neçə siqnalın araşdırıldığı iş: məsul əməkdaş, prioritet, nəticə, MMX-yə məlumat verilib-verilməməsi.';
COMMENT ON COLUMN compliance.aml_case.aml_case_id IS 'AML işi — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN compliance.aml_case.party_id IS 'Tərəf istinadı (araşdırılan tərəfdir).';
COMMENT ON COLUMN compliance.aml_case.assigned_employee_id IS 'Əməkdaş istinadı (məsul əməkdaşdır).';
COMMENT ON COLUMN compliance.aml_case.case_number IS 'İşin nömrəsi.';
COMMENT ON COLUMN compliance.aml_case.opened_at IS 'Açılma anı.';
COMMENT ON COLUMN compliance.aml_case.closed_at IS 'Bağlanma anı.';
COMMENT ON COLUMN compliance.aml_case.priority IS 'Prioritet. Dəyərlər: LOW, MEDIUM, HIGH.';
COMMENT ON COLUMN compliance.aml_case.outcome IS 'Nəticə. Dəyərlər: NO_ACTION, REPORTED_TO_FMS, ACCOUNT_RESTRICTED, RELATIONSHIP_TERMINATED.';
COMMENT ON COLUMN compliance.aml_case.status IS 'Status. Dəyərlər: OPEN, IN_PROGRESS, CLOSED.';
COMMENT ON COLUMN compliance.aml_case.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN compliance.aml_case.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN compliance.aml_case.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN compliance.aml_case.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE compliance.aml_alert IS 'AML siqnalı. Monitorinq qaydası və ya sanksiya yoxlaması ilə yaradılan şübhəli fəaliyyət siqnalı: qayda, risk balı, status.';
COMMENT ON COLUMN compliance.aml_alert.aml_alert_id IS 'AML siqnalı — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN compliance.aml_alert.party_id IS 'Tərəf istinadı (siqnalın tərəfidir).';
COMMENT ON COLUMN compliance.aml_alert.account_transaction_id IS 'Hesab əməliyyatı istinadı (siqnala səbəb olub).';
COMMENT ON COLUMN compliance.aml_alert.account_transaction_date IS 'İstinad edilən `account_transaction` yazılışının bölmə tarixi (kompozit FK hissəsi).';
COMMENT ON COLUMN compliance.aml_alert.screening_check_id IS 'Sanksiya / PEP yoxlaması istinadı (siqnala səbəb olub).';
COMMENT ON COLUMN compliance.aml_alert.aml_case_id IS 'AML işi istinadı (işə daxildir).';
COMMENT ON COLUMN compliance.aml_alert.alert_number IS 'Siqnalın nömrəsi.';
COMMENT ON COLUMN compliance.aml_alert.rule_code IS 'Siqnalı yaradan monitorinq qaydasının kodu.';
COMMENT ON COLUMN compliance.aml_alert.risk_score IS 'Risk balı (0–100).';
COMMENT ON COLUMN compliance.aml_alert.generated_at IS 'Yaranma anı.';
COMMENT ON COLUMN compliance.aml_alert.description IS 'Təsvir.';
COMMENT ON COLUMN compliance.aml_alert.status IS 'Status. Dəyərlər: NEW, UNDER_REVIEW, ESCALATED, CLOSED_FALSE_POSITIVE, CLOSED_CONFIRMED.';
COMMENT ON COLUMN compliance.aml_alert.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN compliance.aml_alert.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN compliance.aml_alert.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN compliance.aml_alert.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE compliance.regulatory_report IS 'Tənzimləyici hesabat. MMX-yə (şübhəli əməliyyat, hədd məbləğini aşan əməliyyat) və AMB-yə göndərilən hesabat: növ, dövr, göndərilmə tarixi, status.';
COMMENT ON COLUMN compliance.regulatory_report.regulatory_report_id IS 'Tənzimləyici hesabat — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN compliance.regulatory_report.aml_case_id IS 'AML işi istinadı (əsasında hazırlanıb).';
COMMENT ON COLUMN compliance.regulatory_report.report_number IS 'Hesabatın nömrəsi.';
COMMENT ON COLUMN compliance.regulatory_report.report_type IS 'Hesabatın növü: şübhəli əməliyyat, hədd məbləğini aşan əməliyyat, AMB-yə dövri hesabat. Dəyərlər: SUSPICIOUS_TRANSACTION, THRESHOLD_TRANSACTION, CBAR_PERIODIC.';
COMMENT ON COLUMN compliance.regulatory_report.regulator IS 'Alan orqan. Dəyərlər: FMS, CBAR.';
COMMENT ON COLUMN compliance.regulatory_report.period_start IS 'Hesabat dövrünün başlanğıcı.';
COMMENT ON COLUMN compliance.regulatory_report.period_end IS 'Hesabat dövrünün sonu.';
COMMENT ON COLUMN compliance.regulatory_report.submitted_at IS 'Göndərilmə anı.';
COMMENT ON COLUMN compliance.regulatory_report.regulator_reference IS 'Orqanın qəbul nömrəsi.';
COMMENT ON COLUMN compliance.regulatory_report.status IS 'Status. Dəyərlər: DRAFT, SUBMITTED, ACCEPTED, REJECTED.';
COMMENT ON COLUMN compliance.regulatory_report.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN compliance.regulatory_report.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN compliance.regulatory_report.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN compliance.regulatory_report.updated_by IS 'Son dəyişikliyi edən istifadəçi.';
COMMENT ON TABLE compliance.regulatory_report_item IS 'Hesabat sətri. Hesabata daxil edilən əməliyyat və ya tərəf.';
COMMENT ON COLUMN compliance.regulatory_report_item.regulatory_report_item_id IS 'Hesabat sətri — surrogat identifikator (UUIDv7).';
COMMENT ON COLUMN compliance.regulatory_report_item.regulatory_report_id IS 'Tənzimləyici hesabat istinadı (sətiridir).';
COMMENT ON COLUMN compliance.regulatory_report_item.account_transaction_id IS 'Hesab əməliyyatı istinadı (hesabata daxildir).';
COMMENT ON COLUMN compliance.regulatory_report_item.account_transaction_date IS 'İstinad edilən `account_transaction` yazılışının bölmə tarixi (kompozit FK hissəsi).';
COMMENT ON COLUMN compliance.regulatory_report_item.party_id IS 'Tərəf istinadı (hesabata daxildir).';
COMMENT ON COLUMN compliance.regulatory_report_item.item_number IS 'Sətrin sıra nömrəsi.';
COMMENT ON COLUMN compliance.regulatory_report_item.amount_azn IS 'Əməliyyatın AZN ekvivalenti.';
COMMENT ON COLUMN compliance.regulatory_report_item.note IS 'Qeyd.';
COMMENT ON COLUMN compliance.regulatory_report_item.created_at IS 'Yazılışın yaradıldığı an.';
COMMENT ON COLUMN compliance.regulatory_report_item.created_by IS 'Yazılışı yaradan istifadəçi.';
COMMENT ON COLUMN compliance.regulatory_report_item.updated_at IS 'Son dəyişiklik anı.';
COMMENT ON COLUMN compliance.regulatory_report_item.updated_by IS 'Son dəyişikliyi edən istifadəçi.';

COMMIT;
