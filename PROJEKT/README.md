# Projekt Zaliczeniowy: System HIS & EDM (Oracle Database)

Projekt relacyjnej bazy danych dla szpitala – **Hospital Information System (HIS)** z modułem **Elektronicznej Dokumentacji Medycznej (EDM)**, realizowany w ramach przedmiotu **Zaawansowane Systemy Baz Danych**.

---

## 1. Uruchomienie Bazy i Modułu ETL (Docker)

Do uruchomienia projektu wymagany jest wyłącznie zainstalowany Docker oraz Docker Compose.

### Uruchomienie całego środowiska (Baza + ETL):
Przejdź do katalogu `PROJEKT` i wykonaj:
```bash
docker compose up -d
```
1. Uruchomiona zostanie baza Oracle Database 23ai Free.
2. Po osiągnięciu przez bazę statusu `healthy` kontener `etl-service` automatycznie:
   - wygeneruje zestaw danych testowych,
   - przeprowadzi walidację biznesową rekordów (PESEL, PWZ, daty),
   - załaduje poprawne dane do tabel bazy Oracle,
   - odrzuci błędne rekordy do raportu błędów,
   - zarchiwizuje przetworzone pliki w katalogu `PROJEKT/etl/data/processed/`.

### Podgląd logów:
```bash
# Logi bazy danych
docker compose logs -f oracle-db

# Logi modułu ETL
docker compose logs -f etl-service
```

### Zatrzymanie środowiska:
```bash
docker compose down
```
*(Dane bazy są bezpiecznie przechowywane w wolumenie `oracle_his_data`).*

---

## 2. Parametry Połączenia w DBeaver

W programie **DBeaver** utwórz nowe połączenie typu **Oracle**:

| Parametr | Wartość | Uwagi |
| :--- | :--- | :--- |
| **Host** | `localhost` | `127.0.0.1` |
| **Port** | `1521` | Domyślny port nasłuchu Oracle |
| **Database** | Zaznacz opcję **Service Name** (nie SID!) i wpisz: `FREEPDB1` |
| **Username** | `his_admin` | Użytkownik schematu z pełnymi prawami DBA |
| **Password** | `HisPassword123!` | Zgodne z plikiem `.env` |

---

## 3. Moduł ETL (Uruchamianie lokalne na hoście)

Moduł ETL można również uruchamiać bezpośrednio na maszynie deweloperskiej:

```bash
cd PROJEKT/etl

# Jednorazowe wygenerowanie danych i załadowanie do bazy:
./run_etl.sh --once

# Uruchomienie w trybie demona (cykliczne sprawdzanie katalogu inbox co 30s):
./run_etl.sh --daemon --interval 30

# Ponowne wygenerowanie nowej partii danych testowych:
./run_etl.sh --generate
```

### Struktura przetwarzania i archiwizacji danych:
- `data/inbox/` – katalog, do którego trafiają nowe pliki wejściowe (CSV / JSON).
- `data/processed/` – archiwum pomyślnie przetworzonych plików (z datą i godziną).
- `data/failed/` – pliki JSON zawierające szczegółowe przyczyny odrzucenia niepoprawnych rekordów (np. błąd sumy kontrolnej PESEL/PWZ).
- Wszystkie zdarzenia, ostrzeżenia i błędy ETL są równolegle rejestrowane w tabeli `LOGI_SYSTEMOWE` w bazie danych.

---

## 4. Struktura Katalogów Projektu

```text
PROJEKT/
├── docker-compose.yml       # Definicja usług: baza Oracle 23ai + kontener etl-service
├── .env                     # Zmienne środowiskowe (hasła, porty, użytkownik)
├── .env.example             # Szablon zmiennych środowiskowych
├── DECYZJE.md               # Rejestr decyzji architektonicznych i konsultacji
├── README.md                # Dokumentacja techniczna i instrukcja uruchomienia
├── init-scripts/            # Skrypty SQL uruchamiane przy starcie kontenera
│   ├── 01_struktura_ddl.sql
│   ├── 02_audyt_i_wyzwalacze.sql
│   ├── 03_pakiety_biznesowe.sql
│   └── 04_raporty_i_widoki.sql
├── sql/                     # Skrypty źródłowe DDL, DML, pakiety PL/SQL, widoki
│   ├── 01_struktura_ddl.sql
│   ├── 02_audyt_i_wyzwalacze.sql
│   ├── 03_pakiety_biznesowe.sql
│   └── 04_raporty_i_widoki.sql
├── DOKUMENTACJA.md          # Pełna dokumentacja projektu i matryca wymagań
└── etl/                     # Moduł zasilający i walidujący dane (Python)
    ├── Dockerfile
    ├── requirements.txt
    ├── config.py
    ├── validator.py
    ├── data_generator.py
    ├── etl_loader.py
    ├── run_etl.sh
    └── data/
        ├── inbox/
        ├── processed/
        └── failed/
```
