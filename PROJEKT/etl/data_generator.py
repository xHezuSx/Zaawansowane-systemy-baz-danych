import csv
import json
import random
from datetime import datetime, timedelta
from pathlib import Path
from config import INBOX_DIR


def generate_valid_pesel(birth_date: datetime, gender: str, seq: int = 1) -> str:
    """Generuje w pełni poprawny matematycznie numer PESEL."""
    y = birth_date.year
    m = birth_date.month
    d = birth_date.day

    if 1900 <= y <= 1999:
        encoded_m = m
    elif 2000 <= y <= 2099:
        encoded_m = m + 20
    elif 1800 <= y <= 1899:
        encoded_m = m + 80
    else:
        encoded_m = m

    # 4 cyfry: 3 porządkowe + płeć (parzysta dla K, nieparzysta dla M)
    p_digit = (seq * 2) if gender == 'K' else (seq * 2 - 1)
    base = f"{y % 100:02d}{encoded_m:02d}{d:02d}{seq:03d}{p_digit % 10}"

    weights = [1, 3, 7, 9, 1, 3, 7, 9, 1, 3]
    checksum = sum(int(base[i]) * weights[i] for i in range(10))
    ctrl = (10 - (checksum % 10)) % 10
    return f"{base}{ctrl}"


def generate_valid_pwz(digits_str: str) -> str:
    """Generuje 7-cyfrowy numer PWZ z poprawną cyfrą kontrolną."""
    digits = [int(c) for c in f"{int(digits_str):06d}"]
    weights = [1, 2, 3, 4, 5, 6]
    ctrl = sum(d * w for d, w in zip(digits, weights)) % 11
    if ctrl == 10:
        # Zmiana ostatniej cyfry, aby uniknąć dwucyfrowej sumy kontrolnej
        digits[-1] = (digits[-1] + 1) % 10
        ctrl = sum(d * w for d, w in zip(digits, weights)) % 11
    return f"{ctrl}{''.join(map(str, digits))}"


def generate_all_datasets(target_dir: Path = INBOX_DIR):
    """Generuje zestaw plików testowych CSV i JSON w katalogu inbox."""
    target_dir.mkdir(parents=True, exist_ok=True)
    print(f"[*] Generowanie zestawu danych testowych do katalogu: {target_dir}")

    # 1. ODDZIAŁY (CSV)
    oddzialy_data = [
        {"nazwa": "Kardiologia", "pietro": 1},
        {"nazwa": "Chirurgia Ogólna", "pietro": 2},
        {"nazwa": "Neurologia", "pietro": 3},
        {"nazwa": "Pediatria", "pietro": 1},
        {"nazwa": "Ortopedia i Traumatologia", "pietro": 4},
        {"nazwa": "Okulistyka", "pietro": 2},
        {"nazwa": "Anestezjologia i Intensywna Terapia", "pietro": 3},
        {"nazwa": "Szpitalny Oddział Ratunkowy (SOR)", "pietro": 0},
    ]
    with open(target_dir / "01_oddzialy.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["nazwa", "pietro"])
        writer.writeheader()
        writer.writerows(oddzialy_data)

    # 2. SPECJALIZACJE (CSV)
    specjalizacje_data = [
        {"nazwa": "Kardiologia"},
        {"nazwa": "Chirurgia ogólna"},
        {"nazwa": "Neurologia"},
        {"nazwa": "Pediatria"},
        {"nazwa": "Ortopedia i traumatologia"},
        {"nazwa": "Okulistyka"},
        {"nazwa": "Anestezjologia i intensywna terapia"},
        {"nazwa": "Medycyna ratunkowa"},
        {"nazwa": "Choroby wewnętrzne"},
        {"nazwa": "Pielęgniarstwo internistyczne"},
    ]
    with open(target_dir / "02_specjalizacje.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["nazwa"])
        writer.writeheader()
        writer.writerows(specjalizacje_data)

    # 3. BADANIA_SLOWNIK (CSV)
    badania_data = [
        {"kod_badania": "GLU", "nazwa": "Glukoza na czczo", "jednostka": "mg/dl", "norma_min": 70.0, "norma_max": 99.0},
        {"kod_badania": "HGB", "nazwa": "Hemoglobina", "jednostka": "g/dl", "norma_min": 12.0, "norma_max": 17.5},
        {"kod_badania": "WBC", "nazwa": "Leukocyty (krwinki białe)", "jednostka": "tys/ul", "norma_min": 4.0, "norma_max": 10.0},
        {"kod_badania": "CRP", "nazwa": "Białko C-reaktywne", "jednostka": "mg/l", "norma_min": 0.0, "norma_max": 5.0},
        {"kod_badania": "K", "nazwa": "Potas w surowicy", "jednostka": "mmol/l", "norma_min": 3.5, "norma_max": 5.1},
        {"kod_badania": "NA", "nazwa": "Sód w surowicy", "jednostka": "mmol/l", "norma_min": 135.0, "norma_max": 145.0},
        {"kod_badania": "CREA", "nazwa": "Kreatynina", "jednostka": "mg/dl", "norma_min": 0.7, "norma_max": 1.2},
        {"kod_badania": "TROP", "nazwa": "Troponina sercowa T", "jednostka": "ng/l", "norma_min": 0.0, "norma_max": 14.0},
    ]
    with open(target_dir / "03_badania_slownik.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["kod_badania", "nazwa", "jednostka", "norma_min", "norma_max"])
        writer.writeheader()
        writer.writerows(badania_data)

    # 4. PERSONEL (CSV)
    # Generujemy kadrę lekarską i pielęgniarską oraz celowo 1 błędny rekord z niepoprawnym PWZ
    personel_data = [
        {"oddzial": "Kardiologia", "imie": "Jan", "nazwisko": "Kowalski", "rola": "LEKARZ", "nr_pwz": generate_valid_pwz("123456"), "stawka": 150.00, "specjalizacja": "Kardiologia"},
        {"oddzial": "Kardiologia", "imie": "Anna", "nazwisko": "Nowak", "rola": "PIELEGNIARKA", "nr_pwz": "", "stawka": 65.00, "specjalizacja": "Pielęgniarstwo internistyczne"},
        {"oddzial": "Chirurgia Ogólna", "imie": "Piotr", "nazwisko": "Zieliński", "rola": "LEKARZ", "nr_pwz": generate_valid_pwz("234567"), "stawka": 160.00, "specjalizacja": "Chirurgia ogólna"},
        {"oddzial": "Chirurgia Ogólna", "imie": "Marek", "nazwisko": "Wójcik", "rola": "LEKARZ", "nr_pwz": generate_valid_pwz("345678"), "stawka": 140.00, "specjalizacja": "Chirurgia ogólna"},
        {"oddzial": "Neurologia", "imie": "Katarzyna", "nazwisko": "Szymańska", "rola": "LEKARZ", "nr_pwz": generate_valid_pwz("456789"), "stawka": 155.00, "specjalizacja": "Neurologia"},
        {"oddzial": "Pediatria", "imie": "Tomasz", "nazwisko": "Dąbrowski", "rola": "LEKARZ", "nr_pwz": generate_valid_pwz("567890"), "stawka": 145.00, "specjalizacja": "Pediatria"},
        {"oddzial": "Szpitalny Oddział Ratunkowy (SOR)", "imie": "Krzysztof", "nazwisko": "Kozłowski", "rola": "LEKARZ", "nr_pwz": generate_valid_pwz("678901"), "stawka": 170.00, "specjalizacja": "Medycyna ratunkowa"},
        {"oddzial": "Ortopedia i Traumatologia", "imie": "Ewa", "nazwisko": "Jankowska", "rola": "LEKARZ", "nr_pwz": generate_valid_pwz("789012"), "stawka": 150.00, "specjalizacja": "Ortopedia i traumatologia"},
        {"oddzial": "Anestezjologia i Intensywna Terapia", "imie": "Michał", "nazwisko": "Mazur", "rola": "LEKARZ", "nr_pwz": generate_valid_pwz("890123"), "stawka": 180.00, "specjalizacja": "Anestezjologia i intensywna terapia"},
        # REKORD TESTOWY BŁĘDU: Niepoprawny numer PWZ (błędna cyfra kontrolna)
        {"oddzial": "Kardiologia", "imie": "Oskar", "nazwisko": "Niepoprawny", "rola": "LEKARZ", "nr_pwz": "9999999", "stawka": 100.00, "specjalizacja": "Kardiologia"},
    ]
    with open(target_dir / "04_personel.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["oddzial", "imie", "nazwisko", "rola", "nr_pwz", "stawka", "specjalizacja"])
        writer.writeheader()
        writer.writerows(personel_data)

    # 5. PACJENCI (CSV)
    # Generujemy 15 pacjentów, w tym:
    # - pacjentów z poprawnym PESEL
    # - 1 obcokrajowca z paszportem (bez PESEL)
    # - 2 rekordy celowo błędne (zły PESEL i zła data) do weryfikacji walidacji ETL
    pacjenci_data = [
        {"pesel": generate_valid_pesel(datetime(1985, 3, 15), "M", 1), "nr_paszportu": "", "imie": "Andrzej", "nazwisko": "Grabowski", "data_urodzenia": "1985-03-15", "plec": "M", "ulica": "Polna 4", "miasto": "Warszawa", "kod_pocztowy": "00-001", "telefon": "501111222"},
        {"pesel": generate_valid_pesel(datetime(1992, 7, 24), "K", 1), "nr_paszportu": "", "imie": "Magdalena", "nazwisko": "Pawlak", "data_urodzenia": "1992-07-24", "plec": "K", "ulica": "Leśna 12", "miasto": "Kraków", "kod_pocztowy": "30-002", "telefon": "502222333"},
        {"pesel": generate_valid_pesel(datetime(1978, 11, 5), "M", 1), "nr_paszportu": "", "imie": "Stanisław", "nazwisko": "Michalak", "data_urodzenia": "1978-11-05", "plec": "M", "ulica": "Słoneczna 1", "miasto": "Wrocław", "kod_pocztowy": "50-003", "telefon": "503333444"},
        {"pesel": generate_valid_pesel(datetime(2002, 1, 19), "K", 1), "nr_paszportu": "", "imie": "Julia", "nazwisko": "Czarnecka", "data_urodzenia": "2002-01-19", "plec": "K", "ulica": "Kwiatowa 8", "miasto": "Poznań", "kod_pocztowy": "60-004", "telefon": "504444555"},
        {"pesel": generate_valid_pesel(datetime(1965, 5, 30), "M", 1), "nr_paszportu": "", "imie": "Tadeusz", "nazwisko": "Włodarczyk", "data_urodzenia": "1965-05-30", "plec": "M", "ulica": "Lipowa 15", "miasto": "Gdańsk", "kod_pocztowy": "80-005", "telefon": "505555666"},
        {"pesel": generate_valid_pesel(datetime(1989, 9, 12), "K", 1), "nr_paszportu": "", "imie": "Karolina", "nazwisko": "Lis", "data_urodzenia": "1989-09-12", "plec": "K", "ulica": "Brzozowa 3", "miasto": "Łódź", "kod_pocztowy": "90-006", "telefon": "506666777"},
        {"pesel": generate_valid_pesel(datetime(1954, 12, 3), "M", 1), "nr_paszportu": "", "imie": "Marian", "nazwisko": "Cieślak", "data_urodzenia": "1954-12-03", "plec": "M", "ulica": "Klonowa 7", "miasto": "Szczecin", "kod_pocztowy": "70-007", "telefon": "507777888"},
        {"pesel": generate_valid_pesel(datetime(2010, 4, 18), "K", 1), "nr_paszportu": "", "imie": "Zofia", "nazwisko": "Borkowska", "data_urodzenia": "2010-04-18", "plec": "K", "ulica": "Ogrodowa 9", "miasto": "Lublin", "kod_pocztowy": "20-008", "telefon": "508888999"},
        # Pacjent zagraniczny: brak PESEL, posiada nr paszportu
        {"pesel": "", "nr_paszportu": "GB987654321", "imie": "John", "nazwisko": "Smith", "data_urodzenia": "1980-06-15", "plec": "M", "ulica": "Parkowa 20", "miasto": "Warszawa", "kod_pocztowy": "00-010", "telefon": "509999000"},
        # REKORD TESTOWY BŁĘDU 1: Błędna suma kontrolna PESEL
        {"pesel": "85031512349", "nr_paszportu": "", "imie": "Zły", "nazwisko": "Peselowski", "data_urodzenia": "1985-03-15", "plec": "M", "ulica": "Błędna 1", "miasto": "Warszawa", "kod_pocztowy": "00-000", "telefon": "500000000"},
        # REKORD TESTOWY BŁĘDU 2: Błędna długość PESEL (10 cyfr)
        {"pesel": "1234567890", "nr_paszportu": "", "imie": "Krótki", "nazwisko": "Pesel", "data_urodzenia": "1990-01-01", "plec": "M", "ulica": "Krótka 2", "miasto": "Kraków", "kod_pocztowy": "30-000", "telefon": "511111111"},
    ]

    # Poprawka wywołań dat dla generate_valid_pesel
    corrected_pacjenci = []
    for p in pacjenci_data:
        if isinstance(p["pesel"], str):
            corrected_pacjenci.append(p)
        else:
            # fallback gdyby przekazano argumenty liczbowe
            corrected_pacjenci.append(p)

    with open(target_dir / "05_pacjenci.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["pesel", "nr_paszportu", "imie", "nazwisko", "data_urodzenia", "plec", "ulica", "miasto", "kod_pocztowy", "telefon"])
        writer.writeheader()
        writer.writerows(pacjenci_data)

    # 6. OSOBY UPOWAŻNIONE (CSV)
    osoby_data = [
        {"pesel_pacjenta": pacjenci_data[0]["pesel"], "imie_nazwisko": "Krystyna Grabowska", "relacja": "ŻONA", "telefon": "601111222"},
        {"pesel_pacjenta": pacjenci_data[1]["pesel"], "imie_nazwisko": "Marek Pawlak", "relacja": "MĄŻ", "telefon": "602222333"},
        {"pesel_pacjenta": pacjenci_data[2]["pesel"], "imie_nazwisko": "Agnieszka Michalak", "relacja": "CÓRKA", "telefon": "603333444"},
        {"pesel_pacjenta": pacjenci_data[7]["pesel"], "imie_nazwisko": "Anna Borkowska", "relacja": "MATKA", "telefon": "608888999"},
    ]
    with open(target_dir / "06_osoby_upowaznione.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["pesel_pacjenta", "imie_nazwisko", "relacja", "telefon"])
        writer.writeheader()
        writer.writerows(osoby_data)

    # 7. POBYTY I WYNIKI BADAŃ (JSON)
    # Złożona struktura relacyjna: pobyt ze skojarzonymi badaniami laboratoryjnymi
    pobyty_json = [
        {
            "pesel_pacjenta": pacjenci_data[0]["pesel"],
            "oddzial": "Kardiologia",
            "pwz_lekarza": personel_data[0]["nr_pwz"],
            "data_przyjecia": "2026-10-01 08:30:00",
            "data_wypisu": "2026-10-08 13:00:00",
            "kod_icd10": "I20.0",
            "koszt_leczenia": 4500.00,
            "badania": [
                {"kod_badania": "GLU", "wartosc": 92.4, "data_badania": "2026-10-01 09:15:00"},
                {"kod_badania": "TROP", "wartosc": 18.5, "data_badania": "2026-10-01 09:30:00"}, # poza normą (norma max 14)
                {"kod_badania": "CRP", "wartosc": 4.1, "data_badania": "2026-10-02 08:00:00"},
            ]
        },
        {
            "pesel_pacjenta": pacjenci_data[1]["pesel"],
            "oddzial": "Chirurgia Ogólna",
            "pwz_lekarza": personel_data[2]["nr_pwz"],
            "data_przyjecia": "2026-10-05 10:00:00",
            "data_wypisu": "2026-10-10 11:30:00",
            "kod_icd10": "K35.8",
            "koszt_leczenia": 6200.00,
            "badania": [
                {"kod_badania": "WBC", "wartosc": 14.8, "data_badania": "2026-10-05 10:30:00"}, # podwyższone
                {"kod_badania": "CRP", "wartosc": 45.0, "data_badania": "2026-10-05 10:30:00"}, # stan zapalny
                {"kod_badania": "HGB", "wartosc": 13.2, "data_badania": "2026-10-06 08:00:00"},
            ]
        },
        {
            "pesel_pacjenta": pacjenci_data[2]["pesel"],
            "oddzial": "Neurologia",
            "pwz_lekarza": personel_data[4]["nr_pwz"],
            "data_przyjecia": "2026-10-12 14:20:00",
            "data_wypisu": "2026-10-20 12:00:00",
            "kod_icd10": "G40.9",
            "koszt_leczenia": 3800.00,
            "badania": [
                {"kod_badania": "K", "wartosc": 4.2, "data_badania": "2026-10-12 15:00:00"},
                {"kod_badania": "NA", "wartosc": 139.0, "data_badania": "2026-10-12 15:00:00"},
            ]
        },
        {
            "pesel_pacjenta": pacjenci_data[3]["pesel"],
            "oddzial": "Ortopedia i Traumatologia",
            "pwz_lekarza": personel_data[7]["nr_pwz"],
            "data_przyjecia": "2026-10-15 09:00:00",
            "data_wypisu": "2026-10-18 15:00:00",
            "kod_icd10": "S82.1",
            "koszt_leczenia": 5100.00,
            "badania": [
                {"kod_badania": "HGB", "wartosc": 11.5, "data_badania": "2026-10-15 09:40:00"},
            ]
        },
        {
            "pesel_pacjenta": pacjenci_data[4]["pesel"],
            "oddzial": "Kardiologia",
            "pwz_lekarza": personel_data[0]["nr_pwz"],
            "data_przyjecia": "2026-10-22 18:00:00",
            "data_wypisu": None, # Pacjent aktualnie hospitalizowany!
            "kod_icd10": "I50.9",
            "koszt_leczenia": 2900.00,
            "badania": [
                {"kod_badania": "CREA", "wartosc": 1.45, "data_badania": "2026-10-22 18:30:00"},
                {"kod_badania": "K", "wartosc": 5.4, "data_badania": "2026-10-23 08:00:00"},
            ]
        },
        # REKORD TESTOWY BŁĘDU: Data wypisu wcześniejsza niż data przyjęcia
        {
            "pesel_pacjenta": pacjenci_data[5]["pesel"],
            "oddzial": "Neurologia",
            "pwz_lekarza": personel_data[4]["nr_pwz"],
            "data_przyjecia": "2026-10-25 12:00:00",
            "data_wypisu": "2026-10-20 10:00:00", # BŁĄD!
            "kod_icd10": "G43.0",
            "koszt_leczenia": 1200.00,
            "badania": []
        }
    ]

    with open(target_dir / "07_pobyty_i_badania.json", "w", encoding="utf-8") as f:
        json.dump(pobyty_json, f, indent=2, ensure_ascii=False)

    print(f"[+] Pomyślnie wygenerowano pliki danych testowych:")
    print(f"    - 01_oddzialy.csv")
    print(f"    - 02_specjalizacje.csv")
    print(f"    - 03_badania_slownik.csv")
    print(f"    - 04_personel.csv (w tym 1 z błędnym PWZ do testu walidacji)")
    print(f"    - 05_pacjenci.csv (w tym 2 z błędnym PESEL i 1 paszport)")
    print(f"    - 06_osoby_upowaznione.csv")
    print(f"    - 07_pobyty_i_badania.json (w tym 1 z nielogiczną datą wypisu)")


if __name__ == "__main__":
    generate_all_datasets()
