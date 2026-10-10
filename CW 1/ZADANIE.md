# Ćwiczenie 1

---

### Polecenia do wykonania

1. **Przygotowanie bazy danych na podstawie schematu:**
* Zwróć uwagę na klucze obce.
* Sam dostosuj odpowiednie typy danych do kolumn.
* Część kolumn oraz kluczy obcych dodaj za pomocą polecenia `ALTER TABLE`.
* W tabeli `JOBS` ustaw warunek (`CHECK`), taki aby `min_salary` było mniejsze od `max_salary` co najmniej o 2000.


2. **Wstawianie danych do `JOBS`:**
* Wstaw 4 rekordy do tabeli `JOBS`.


3. **Wstawianie danych do `EMPLOYEES`:**
* Wstaw 4 rekordy do tabeli `EMPLOYEES`.


4. **Aktualizacja menadżera:**
* W tabeli `EMPLOYEES` zmień menadżera pracownikom o identyfikatorach `2` i `3` na `1`.


5. **Modyfikacja wynagrodzeń:**
* Dla tabeli `JOBS` zwiększ minimalne i maksymalne wynagrodzenie o `500`, jeśli nazwa zawiera literę `'b'` lub `'s'`.


6. **Usuwanie danych:**
* Z tabeli `JOBS` usuń rekordy, dla których maksymalne zarobki są większe od `9000`.


7. **Test usuwania i odzyskiwania:**
* Usuń jedną z tabel i sprawdź, czy możesz ją odzyskać *(np. za pomocą mechanizmu `FLASHBACK TABLE ... TO BEFORE DROP` w Oracle Database)*.



---