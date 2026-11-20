# Rejestr Decyzji Projektowych (HIS & EDM)

Ten dokument stanowi oficjalny rejestr decyzji architektonicznych, modelowych i technologicznych podjętych podczas realizacji projektu zaliczeniowego z przedmiotu **Zaawansowane Systemy Baz Danych**.

Zgodnie z przyjętą zasadą, **każda istotna decyzja jest przed wdrożeniem konsultowana z użytkownikiem i zapisywana w niniejszym pliku**.

---

## Metryka Projektu
- **Tytuł**: Szpitalny System Informacyjny (HIS) z modułem Elektronicznej Dokumentacji Medycznej (EDM)
- **Silnik bazy danych**: Oracle Database 23ai Free (kontener Docker)
- **Przedmiot**: Zaawansowane Systemy Baz Danych

---

## Rejestr Decyzji

### Decyzja 001: Wybór tematu projektu
- **Data**: 2026-11-20
- **Status**: ZATWIERDZONA
- **Decyzja**: Realizacja projektu dla branży medycznej / szpitalnej: System HIS (*Hospital Information System*) i EDM (*Elektroniczna Dokumentacja Medyczna*).
- **Uzasadnienie**:
  - Bogata domena relacyjna (pacjenci, personel, oddziały, hospitalizacje, badania laboratoryjne, diagnozy ICD-10).
  - Możliwość wdrożenia rygorystycznych reguł walidacji (np. algorytm sprawdzania PESEL, numer PWZ lekarza, daty przyjęć/wypisów).
  - Wymóg prawny archiwizacji i audytu (niezmienność historii medycznej – archiwizacja usuniętych pobytów).
  - Zestawienia okresowe i analityka (obłożenie oddziałów, koszty leczenia, średni czas pobytu).

---

### Decyzja 002: Zasada konsultacji decyzji z użytkownikiem
- **Data**: 2026-11-20
- **Status**: ZATWIERDZONA
- **Decyzja**: Agent każdorazowo konsultuje z użytkownikiem istotne kwestie architektoniczne i modelowe przed przystąpieniem do implementacji danego etapu.
- **Uzasadnienie**: Pełna kontrola użytkownika nad architekturą i implementacją projektu.

---

### Decyzja 003: Wybór środowiska bazodanowego (Docker)
- **Data**: 2026-11-20
- **Status**: ZATWIERDZONA
- **Decyzja**: Wykorzystanie obrazu `gvenzl/oracle-free:latest` (Oracle Database 23ai Free).
- **Parametry**:
  - Service Name: `FREEPDB1`
  - Dedykowany użytkownik aplikacji: `his_admin` (hasło: `HisPassword123!`)
  - Port: `1521`
  - Wolumen trwały: `oracle_his_data`
  - Automatyczny bootstrap: `init-scripts/` zamontowane do kontenera.

---

### Decyzja 004: Zatwierdzenie modelu relacyjnego ERD (12 tabel)
- **Data**: 2026-11-20
- **Status**: ZATWIERDZONA
- **Decyzja**: Wdrożenie schematu relacyjnego składającego się z 12 tabel:
  1. `ODDZIALY` – oddziały szpitalne (piętro, ordynator).
  2. `PERSONEL` – lekarze, pielęgniarki i pracownicy szpitala (rola, nr PWZ, stawka godzinowa).
  3. `SPECJALIZACJE` – słownik specjalizacji medycznych.
  4. `PERSONEL_SPECJALIZACJE` – tabela asocjacyjna relacji N:M personel-specjalizacje (data uzyskania).
  5. `PACJENCI` – kartoteka pacjentów (PESEL, nr paszportu, dane osobowe, adres).
  6. `OSOBY_UPOWAZNIONE` – osoby kontaktowe/upoważnione przez pacjenta (relacja, telefon).
  7. `POBYTY` – rejestr hospitalizacji (pacjent, oddział, lekarz prowadzący, daty, ICD-10, koszt).
  8. `BADANIA_SLOWNIK` – definicje badań laboratoryjnych (kod badania, jednostka, normy min/max).
  9. `WYNIKI_BADAN` – zrealizowane badania laboratoryjne (wartość, norma, źródło pliku dla ETL).
  10. `POBYTY_ARCH` – tabela historii usuniętych pobytów (spełnienie wymogu archiwizacji danych usuniętych).
  11. `LOGI_SYSTEMOWE` – dedykowany rejestr audytu i logowania zdarzeń (poziom, moduł, komunikat).
  12. `PODSUMOWANIA_OKRESOWE` – struktura na zagregowane zestawienia miesięczne, kwartalne i roczne pod wykresy.
- **Wdrożenie**:
  - Utworzono skrypt DDL: `PROJEKT/sql/01_struktura_ddl.sql`.
  - Skopiowano do skryptów startowych kontenera: `PROJEKT/init-scripts/01_struktura_ddl.sql`.
  - Utworzono dedykowane indeksy dla kluczy obcych i pól wyszukiwania.


---

### Decyzja 005: Wdrożenie modułu audytu, archiwizacji i walidacji PL/SQL
- **Data**: 2026-11-20
- **Status**: ZATWIERDZONA
- **Decyzja**: Implementacja kluczowych komponentów PL/SQL w pliku `02_audyt_i_wyzwalacze.sql`:
  1. `PKG_LOGI` z `PRAGMA AUTONOMOUS_TRANSACTION` – niezależne logowanie zdarzeń (INFO, WARN, ERROR) do `LOGI_SYSTEMOWE` bez cofania logów przy rollbacku transakcji głównej.
  2. `TRG_POBYTY_ARCH_DEL` – wyzwalacz `AFTER DELETE` kopiujący usunięty pobyt do `POBYTY_ARCH` wraz z użytkownikiem i datą usunięcia.
  3. `FNC_WALIDUJ_PESEL` – funkcja walidująca sumę kontrolną oraz datę urodzenia w numerze PESEL.
  4. `FNC_WALIDUJ_PWZ` – funkcja weryfikująca poprawność 7-cyfrowego numeru PWZ lekarza według algorytmu NIL.
  5. `TRG_WYNIKI_BADAN_BIU` – automatyczna weryfikacja czy wartość badania mieści się w normie (`norma_min`, `norma_max`) i ustawianie flagi `CZY_W_NORMIE` na 'T' lub 'N'.


---

### Decyzja 006: Szczegółowa specyfikacja modułu ETL i formatów danych
- **Data**: 2026-11-20
- **Status**: ZATWIERDZONA
- **Decyzja**: Wdrożenie modułu zasilającego (ETL) w architekturze hybrydowej (Dual-Mode):
  1. **Uruchomienie**:
     - Podstawowe: Jako usługa `etl-service` w `docker-compose.yml`, która czeka na status `healthy` bazy Oracle, automatycznie generuje i ładuje dane, po czym archiwizuje pliki (rozwiązanie bezobsługowe dla osoby sprawdzającej).
     - Alternatywne: Możliwość bezpośredniego uruchomienia skryptu na hoście (`python3 etl_loader.py --once` lub `--daemon`).
  2. **Źródła danych (brak zewnętrznych API)**:
     - Pełna niezależność od sieci – dane generowane przez dedykowany moduł `data_generator.py`.
  3. **Formaty danych**:
     - Format **CSV**: dane słownikowe i kartoteki (`oddzialy.csv`, `specjalizacje.csv`, `badania_slownik.csv`, `personel.csv`, `pacjenci.csv`, `osoby_upowaznione.csv`).
     - Format **JSON**: zdarzenia medyczne (`pobyty_i_badania.json`) ze strukturami zagnieżdżonymi (pobyt $\rightarrow$ lista wykonanych badań laboratoryjnych).
  4. **Mechanizm walidacji i archiwizacji**:
     - Weryfikacja sum kontrolnych PESEL i PWZ w Pythonie przed wstawieniem.
     - Przenoszenie poprawnie załadowanych plików z `inbox/` do `processed/` ze stemplem czasu.
     - Zapis błędnych rekordów do `failed/` oraz rejestracja ostrzeżeń/błędów w tabeli `LOGI_SYSTEMOWE`.


---

### Decyzja 007: Wdrożenie pakietów biznesowych PL/SQL
- **Data**: 2026-11-20
- **Status**: ZATWIERDZONA
- **Decyzja**: Implementacja pakietów biznesowych w pliku `03_pakiety_biznesowe.sql` (bez komentarzy w kodzie):
  1. `PKG_PACJENCI`:
     - `dodaj_pacjenta` – parametry domyślne, walidacja PESEL/paszportu, wyjątki własne (`EX_PACJENT_JUZ_ISTNIEJE`, `EX_NIEPOPRAWNY_IDENTYFIKATOR`), logowanie audytowe.
     - `aktualizuj_dane` – modyfikacja danych adresowych i kontaktowych z weryfikacją istnienia pacjenta (`EX_PACJENT_NIE_ISTNIEJE`).
     - `usun_pacjenta` – usuwanie pacjenta z blokadą w przypadku aktywnej hospitalizacji (`EX_PACJENT_AKTYWNY`).
  2. `PKG_HOSPITALIZACJE`:
     - `przyjmij_pacjenta` – kontrola czy pacjent nie jest już hospitalizowany (`EX_PACJENT_JUZ_HOSPITALIZOWANY`), kontrola czy lekarz należy do oddziału (`EX_LEKARZ_NIE_NALEZY_DO_ODDZIALU`), wstawienie pobytu i logowanie zdarzenia.
     - `wypisz_pacjenta` – zamknięcie hospitalizacji, kontrola chronologii dat (`EX_NIEPOPRAWNE_DATY`), automatyczne wyliczenie kosztu całkowitego na podstawie długości pobytu i stawki lekarskiej.
     - `zlec_badanie` – zlecenie badania laboratoryjnego do pobytu z walidacją słownikową (`EX_POBYT_JUZ_ZAMKNIETY`).
     - `pobierz_ranking_kosztow` – kursor analityczny wykorzystujący zaawansowane funkcje okienkowe (`AVG() OVER (PARTITION BY ...)`, różnica od średniej oddziału, `DENSE_RANK() OVER (PARTITION BY ...)` oraz `DENSE_RANK() OVER ()`).
     - `generuj_podsumowanie_okresowe` – generowanie i zapisywanie zagregowanych metryk miesięcznych do tabeli `PODSUMOWANIA_OKRESOWE` poleceniem `MERGE`.


---

### Decyzja 008: Wdrożenie modułu analitycznego, podsumowań okresowych i widoków raportowych
- **Data**: 2026-11-20
- **Status**: ZATWIERDZONA
- **Decyzja**: Implementacja pakietu `PKG_RAPORTY`, widoków analitycznych oraz widoku zmaterializowanego w pliku `04_raporty_i_widoki.sql` (bez komentarzy w kodzie):
  1. `PKG_RAPORTY`:
     - `generuj_podsumowanie_kwartalne` – agregacja hospitalizacji per kwartał (`typ_okresu = 'KWARTALNY'`, `okres_nr = 1..4`), kalkulacja kosztów i średniego czasu pobytu, zapis poleceniem `MERGE` do `PODSUMOWANIA_OKRESOWE`.
     - `generuj_podsumowanie_roczne` – roczna agregacja statystyk hospitalizacji (`typ_okresu = 'ROCZNY'`, `okres_nr = 1`), zapis `MERGE` do `PODSUMOWANIA_OKRESOWE`.
     - `pobierz_oblozenie_oddzialu` – parametryczna funkcja zwracająca `SYS_REFCURSOR` z dziennym rozbiciem przyjęć, wypisów i kosztów dla danego oddziału i przedziału dat.
     - `pobierz_efektywnosc_lekarzy` – parametryczna funkcja analityczna zwracająca `SYS_REFCURSOR` z metrykami pracy lekarzy (liczba pobytów, średni czas pobytu, koszty, zlecone badania, odsetek wyników laboratoryjnych poza normą).
     - `pobierz_strukture_rozpoznan` – funkcja parametryczna analizująca rozkład kodów ICD-10 z wyliczaniem udziału procentowego i pozycji w rankingu częstości.
  2. Widoki analityczne przygotowane pod wykresy i narzędzia BI (DBeaver, Tableau, Superset):
     - `V_RAPORT_OBLOZENIE_ODDZIALOW` – bieżący stan oddziałów (hospitalizacje aktywne, zakończone, średni czas pobytu, wygenerowane przychody).
     - `V_RAPORT_KOSZTY_MIESIECZNE` – oś czasu dynamiki kosztów m/m z wykorzystaniem funkcji okienkowej `LAG()`.
     - `V_RAPORT_DIAGNOZY_ICD10` – rozkład rozpoznań z wykorzystaniem `SUM() OVER ()` (udział %) oraz `DENSE_RANK()`.
     - `V_RAPORT_LABORATORIUM_ANOMALIE` – statystyki badań laboratoryjnych z odsetkiem anomalii (poza normą) oraz wartościami min/avg/max.
  3. Widok zmaterializowany:
     - `MV_PODSUMOWANIE_ROCZNE` – roczne agregacje oddziałowe z odświeżaniem na żądanie (`REFRESH COMPLETE ON DEMAND`).
