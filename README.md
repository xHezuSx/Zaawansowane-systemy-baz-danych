# Zaawansowane systemy baz danych
Zaawansowane systemy baz danych

# Połączenie

Podłącz się do serwera Oracle za pomocą SQL Developera. 
Hostname: 213.184.8.44
Port: 1521
username: nstmsu_nazwisko + pierwsza litera imienia (np. nstmsu_drozdap)
password: imie
Service Name: orcl
Zmień swoje hasło!!!!

--- 
# Wymagania dotyczące projektu zaliczeniowego

---

### Organizacja i terminy

* **Repozytorium Git:** Stworzenie repozytorium w pierwszym tygodniu oraz przesłanie linku
* **Wybór tematu:** do **8 listopada 2026**
* **Ostateczny termin (deadline):** do końca zajęć **30 stycznia 2027**

---

### Zakres projektu

#### 1. Przygotowanie struktury bazy danych

Opracowanie odpowiedniej struktury relacyjnej dla wybranego zagadnienia.

**Przykładowe tematy:**

* Firma produkcyjna
* Firma sprzedażowa
* Sieć kin
* Obsługa ligi piłkarskiej
* Firma bukmacherska
* Agencja nieruchomości
* Obsługa giełdy papierów wartościowych
* System prognozy pogody
* *(inny własny temat)*

#### 2. Skrypt zasilający bazę danymi (ETL / Data Loader)

* **Źródła i automatyzacja:** Pobieranie danych z zewnętrznych serwisów (np. web scraping, API) lub ładowanie z plików (`.csv`, `.json`). Realizacja w formie procesu cyklicznego (demon, zadanie `cron`, harmonogram itp.).
* **Walidacja:** Weryfikacja spójności i poprawności importowanych rekordów.
* **Utrzymanie danych:** Gromadzenie oraz archiwizacja przetworzonych i załadowanych danych.

#### 3. Logika biznesowa w bazie danych (Procedury, Funkcje, Wyzwalacze, Pakiety)

Grupowanie powiązanych obiektów w pakiety bazodanowe:

* **Operacje DML:** Procedury do wstawiania, modyfikacji oraz usuwania rekordów.
* **Audyt i historia:**
* Archiwizacja usuniętych danych (soft delete / tabele historyczne).
* Dedykowana tabela logów i rejestrowanie kluczowych zdarzeń.


* **Niezawodność:** Obsługa wyjątków systemowych oraz definiowanie własnych wyjątków biznesowych (*user-defined exceptions*).
* **Zaawansowany kod PL/SQL:**
* Parametryzacja procedur i funkcji (w tym parametry z wartościami domyślnymi).
* Zastosowanie analitycznych funkcji okienkowych (*window functions*).


* **Walidacja reguł biznesowych:** Mechanizmy sprawdzające poprawność wprowadzanych danych (np. algorytm weryfikujący poprawność numeru PESEL).

#### 4. Moduł analityczny i raportowy

Tworzenie agregacji danych zoptymalizowanych pod kątem wizualizacji:

* Podsumowania w ujęciu czasowym: miesięczne, kwartalne oraz roczne.
* Zestawienia wielowymiarowe zależne od parametrów wejściowych.
* Zapis zagregowanych wyników w bazie danych w strukturach gotowych do bezpośredniego zasilenia wykresów lub dashboardów.