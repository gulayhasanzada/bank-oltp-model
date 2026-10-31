from bankmodel.meta import Attribute as A
from bankmodel.meta import Domain, Entity, Rel

DOMAIN = Domain(
    schema="org",
    title="Təşkilat və kanallar",
    desc=(
        "Bankın daxili strukturu və xidmət kanalları: filial və şöbələr, əməkdaşlar, "
        "müştərilərin banka müraciət etdiyi kanallar və bankomatlar."
    ),
    entities=(
        Entity(
            "branch",
            "Filial",
            "Bankın baş ofisi, filialları və şöbələri; şöbə filiala tabe ola bilər.",
            rels=(Rel("branch", "tabe bölməsidir", parent_card="0..1", fk="parent_branch_id"),),
            attributes=(
                A("branch_code", "code", "Bölmənin daxili kodu.", unique=True),
                A("name", "text", "Bölmənin adı."),
                A("branch_type", "code", "Bölmənin növü.", values=("HEAD_OFFICE", "BRANCH", "DIVISION")),
                A("address", "text", "Ünvan."),
                A("city", "short_text", "Şəhər / rayon."),
                A("phone", "short_text", "Əlaqə telefonu.", optional=True),
                A("opened_date", "date", "Açılış tarixi."),
                A("closed_date", "date", "Bağlanma tarixi.", optional=True),
                A("status", "code", "Status.", values=("ACTIVE", "CLOSED")),
            ),
        ),
        Entity(
            "employee",
            "Əməkdaş",
            "Bank əməkdaşları: müştəri meneceri, kredit mütəxəssisi, operator, uyğunluq (compliance) əməkdaşı və s.",
            rels=(
                Rel("branch", "işlədiyi bölmədir"),
                Rel("employee", "rəhbəridir", parent_card="0..1", fk="manager_employee_id"),
            ),
            attributes=(
                A("employee_number", "code", "Tabel nömrəsi.", unique=True),
                A("first_name", "short_text", "Ad."),
                A("last_name", "short_text", "Soyad."),
                A("position", "text", "Vəzifə."),
                A("email", "text", "Korporativ e-poçt.", optional=True, unique=True),
                A("hired_date", "date", "İşə qəbul tarixi."),
                A("terminated_date", "date", "İşdən çıxma tarixi.", optional=True),
                A("status", "code", "Status.", values=("ACTIVE", "ON_LEAVE", "TERMINATED")),
            ),
        ),
        Entity(
            "channel",
            "Xidmət kanalı",
            "Müştəriyə xidmət kanalları: filial, bankomat, internet bankçılıq, mobil bankçılıq, POS, çağrı mərkəzi, API.",
            attributes=(
                A("channel_code", "code", "Kanalın kodu.", unique=True),
                A("name", "text", "Kanalın adı."),
                A(
                    "channel_type",
                    "code",
                    "Kanalın növü.",
                    values=("BRANCH", "ATM", "INTERNET_BANKING", "MOBILE_BANKING", "POS", "CALL_CENTER", "API"),
                ),
                A("is_active", "flag", "Kanal aktivdir.", default="true"),
            ),
        ),
        Entity(
            "atm",
            "Bankomat",
            "Bankın bankomatları və özünəxidmət terminalları: yerləşmə ünvanı, imkanlar, status.",
            rels=(Rel("branch", "xidmət göstərir", parent_card="0..1"),),
            attributes=(
                A("terminal_id", "code", "Terminal identifikatoru (prosessinqdə istifadə olunan).", unique=True),
                A("address", "text", "Yerləşmə ünvanı."),
                A("city", "short_text", "Şəhər / rayon."),
                A("supports_cash_in", "flag", "Nağd mədaxil qəbul edir.", default="false"),
                A("installed_date", "date", "Quraşdırılma tarixi."),
                A("status", "code", "Status.", values=("ACTIVE", "OUT_OF_SERVICE", "DECOMMISSIONED")),
            ),
        ),
    ),
)
