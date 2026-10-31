# Bank OLTP verilənlər modeli (PostgreSQL 18, Azərbaycan)

Universal bankın əsas bank sistemi üçün normallaşdırılmış **OLTP** verilənlər modeli: konseptual, məntiqi və
fiziki modellərin sənədləri (Markdown + Mermaid) və PostgreSQL 18 DDL skripti.

Bütün sənədlər **deterministik** Python tətbiqi ilə yaradılır: model `src/bankmodel/model/` qovluğunda
təsvir olunur (yeganə həqiqət mənbəyi), generator eyni girişdən hər dəfə bayt-bayt eyni nəticə çıxarır.

## Struktur

| Yol | Təyinat |
|---|---|
| `src/bankmodel/model/` | Model: hər domen üçün bir modul (obyektlər, əlaqələr, atributlar) |
| `src/bankmodel/meta.py` | Metamodel (Domain, Entity, Rel, Attribute) |
| `src/bankmodel/types.py` | Məntiqi tiplər və PostgreSQL tiplərinə uyğunluq |
| `src/bankmodel/validate.py` | Modelin bütövlük qaydaları |
| `src/bankmodel/render/` | Sənəd və DDL generatorları |
| `docs/01_konseptual/` | Konseptual model (yaradılır) |
| `docs/02_mentiqi/` | Məntiqi model (yaradılır) |
| `docs/03_fiziki/` | Fiziki model (yaradılır) |
| `ddl/banking_oltp_pg18.sql` | PostgreSQL 18 DDL (yaradılır) |

## İstifadə

Tələblər: [uv](https://docs.astral.sh/uv/), Docker Desktop.

```powershell
uv sync                                   # mühiti hazırla
uv run bankmodel generate                 # sənədləri və DDL-i yarat
uv run bankmodel check                    # model düzgündür və fayllar aktualdır?
uv run python -m unittest discover tests  # testlər
```

Verilənlər bazası (Docker Compose):

```powershell
Copy-Item .env.example .env               # şifrəni dəyiş
docker compose up -d                      # PostgreSQL 18
uv run bankmodel apply                    # DDL-i bazada icra et
```

5432 portu başqa xidmət tərəfindən istifadə olunursa, `.env`-də `POSTGRES_PORT` dəyərini dəyişin (məs. `5433`).

`docs/` və `ddl/` altındakı faylları əl ilə redaktə etməyin — dəyişiklikləri modeldə edin və yenidən yaradın.
