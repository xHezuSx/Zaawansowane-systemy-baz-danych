import os
import sys
import csv
import json
import time
import shutil
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, List

import oracledb

from config import (
    ORACLE_HOST, ORACLE_PORT, ORACLE_SERVICE_NAME, ORACLE_USER, ORACLE_PASSWORD,
    INBOX_DIR, PROCESSED_DIR, FAILED_DIR
)
from validator import validate_pesel, validate_pwz, validate_stay_dates
from data_generator import generate_all_datasets


def get_connection():
    """Tworzy połączenie z bazą Oracle w trybie Thin."""
    return oracledb.connect(
        user=ORACLE_USER,
        password=ORACLE_PASSWORD,
        host=ORACLE_HOST,
        port=ORACLE_PORT,
        service_name=ORACLE_SERVICE_NAME
    )


def log_to_oracle(cursor, level: str, module: str, message: str):
    """Zapisuje zdarzenie do tabeli LOGI_SYSTEMOWE."""
    try:
        cursor.execute(
            "BEGIN PKG_LOGI.log_" + level.lower() + "(:modul, :komunikat); END;",
            modul=module,
            komunikat=message[:4000]
        )
    except Exception as e:
        print(f"[!] Błąd zapisu do LOGI_SYSTEMOWE: {e}")


def load_oddzialy(cursor, file_path: Path) -> Dict[str, int]:
    """Ładuje słownik oddziałów z pliku CSV."""
    success, errors, rejected = 0, 0, []
    print(f"[*] Przetwarzanie oddziałów z: {file_path.name}")

    with open(file_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            nazwa = row.get("nazwa", "").strip()
            pietro = int(row.get("pietro", 0))

            if not nazwa:
                errors += 1
                rejected.append({"row": row, "reason": "Brak nazwy oddziału"})
                continue

            try:
                # Wstawienie jeśli nie istnieje
                cursor.execute(
                    """
                    MERGE INTO ODDZIALY o
                    USING (SELECT :nazwa AS nazwa, :pietro AS pietro FROM dual) src
                    ON (o.nazwa = src.nazwa)
                    WHEN NOT MATCHED THEN
                        INSERT (nazwa, pietro) VALUES (src.nazwa, src.pietro)
                    """,
                    nazwa=nazwa,
                    pietro=pietro
                )
                success += 1
            except Exception as e:
                errors += 1
                rejected.append({"row": row, "reason": str(e)})

    # Pobranie mapowania nazwa -> id_oddzialu
    cursor.execute("SELECT nazwa, id_oddzialu FROM ODDZIALY")
    mapping = {row[0]: row[1] for row in cursor.fetchall()}
    return {"success": success, "errors": errors, "rejected": rejected, "mapping": mapping}


def load_specjalizacje(cursor, file_path: Path) -> Dict[str, int]:
    """Ładuje słownik specjalizacji z pliku CSV."""
    success, errors, rejected = 0, 0, []
    print(f"[*] Przetwarzanie specjalizacji z: {file_path.name}")

    with open(file_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            nazwa = row.get("nazwa", "").strip()
            if not nazwa:
                errors += 1
                rejected.append({"row": row, "reason": "Brak nazwy specjalizacji"})
                continue

            try:
                cursor.execute(
                    """
                    MERGE INTO SPECJALIZACJE s
                    USING (SELECT :nazwa AS nazwa FROM dual) src
                    ON (s.nazwa = src.nazwa)
                    WHEN NOT MATCHED THEN
                        INSERT (nazwa) VALUES (src.nazwa)
                    """,
                    nazwa=nazwa
                )
                success += 1
            except Exception as e:
                errors += 1
                rejected.append({"row": row, "reason": str(e)})

    cursor.execute("SELECT nazwa, id_specjalizacji FROM SPECJALIZACJE")
    mapping = {row[0]: row[1] for row in cursor.fetchall()}
    return {"success": success, "errors": errors, "rejected": rejected, "mapping": mapping}


def load_badania_slownik(cursor, file_path: Path) -> Dict[str, int]:
    """Ładuje słownik badań laboratoryjnych z pliku CSV."""
    success, errors, rejected = 0, 0, []
    print(f"[*] Przetwarzanie słownika badań z: {file_path.name}")

    with open(file_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            kod = row.get("kod_badania", "").strip()
            nazwa = row.get("nazwa", "").strip()
            jednostka = row.get("jednostka", "").strip()
            n_min = float(row["norma_min"]) if row.get("norma_min") else None
            n_max = float(row["norma_max"]) if row.get("norma_max") else None

            if not kod or not nazwa:
                errors += 1
                rejected.append({"row": row, "reason": "Brak kodu lub nazwy badania"})
                continue

            try:
                cursor.execute(
                    """
                    MERGE INTO BADANIA_SLOWNIK b
                    USING (SELECT :kod AS kod, :nazwa AS nazwa, :jednostka AS jednostka, 
                                  :n_min AS n_min, :n_max AS n_max FROM dual) src
                    ON (b.kod_badania = src.kod)
                    WHEN NOT MATCHED THEN
                        INSERT (kod_badania, nazwa, jednostka, norma_min, norma_max)
                        VALUES (src.kod, src.nazwa, src.jednostka, src.n_min, src.n_max)
                    """,
                    kod=kod, nazwa=nazwa, jednostka=jednostka, n_min=n_min, n_max=n_max
                )
                success += 1
            except Exception as e:
                errors += 1
                rejected.append({"row": row, "reason": str(e)})

    cursor.execute("SELECT kod_badania, id_badania FROM BADANIA_SLOWNIK")
    mapping = {row[0]: row[1] for row in cursor.fetchall()}
    return {"success": success, "errors": errors, "rejected": rejected, "mapping": mapping}


def load_personel(cursor, file_path: Path, oddzialy_map: Dict[str, int], spec_map: Dict[str, int]):
    """Ładuje personel medyczny z walidacją PWZ lekarza."""
    success, errors, rejected = 0, 0, []
    print(f"[*] Przetwarzanie personelu z: {file_path.name}")

    with open(file_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            oddzial_nazwa = row.get("oddzial", "").strip()
            imie = row.get("imie", "").strip()
            nazwisko = row.get("nazwisko", "").strip()
            rola = row.get("rola", "").strip()
            pwz = row.get("nr_pwz", "").strip() or None
            stawka = float(row.get("stawka", 0.0))
            specjalizacja = row.get("specjalizacja", "").strip()

            id_oddzialu = oddzialy_map.get(oddzial_nazwa)
            if not id_oddzialu:
                errors += 1
                rejected.append({"row": row, "reason": f"Oddział '{oddzial_nazwa}' nie istnieje w bazie"})
                continue

            # Walidacja PWZ jeśli podano
            if pwz:
                is_valid, reason = validate_pwz(pwz)
                if not is_valid:
                    errors += 1
                    rejected.append({"row": row, "reason": f"Odrzucono: {reason}"})
                    log_to_oracle(cursor, "WARN", "ETL_LOADER", f"Odrzucono personel {imie} {nazwisko}: {reason}")
                    continue

            try:
                # Wstawienie personelu (zwrócenie wygenerowanego ID)
                id_personelu_var = cursor.var(int)
                cursor.execute(
                    """
                    INSERT INTO PERSONEL (id_oddzialu, imie, nazwisko, rola, nr_pwz, stawka_godzinowa)
                    VALUES (:id_oddzialu, :imie, :nazwisko, :rola, :pwz, :stawka)
                    RETURNING id_personelu INTO :id_personelu_var
                    """,
                    id_oddzialu=id_oddzialu, imie=imie, nazwisko=nazwisko,
                    rola=rola, pwz=pwz, stawka=stawka, id_personelu_var=id_personelu_var
                )
                id_personelu = id_personelu_var.getvalue()[0]

                # Przypisanie ordynatora do oddziału jeśli rola to LEKARZ i oddział nie ma ordynatora
                if rola == "LEKARZ":
                    cursor.execute(
                        """
                        UPDATE ODDZIALY 
                        SET id_ordynatora = :id_personelu 
                        WHERE id_oddzialu = :id_oddzialu AND id_ordynatora IS NULL
                        """,
                        id_personelu=id_personelu, id_oddzialu=id_oddzialu
                    )

                # Powiązanie specjalizacji
                if specjalizacja and specjalizacja in spec_map:
                    id_spec = spec_map[specjalizacja]
                    cursor.execute(
                        """
                        INSERT INTO PERSONEL_SPECJALIZACJE (id_personelu, id_specjalizacji, data_uzyskania)
                        VALUES (:id_personelu, :id_spec, SYSDATE)
                        """,
                        id_personelu=id_personelu, id_spec=id_spec
                    )

                success += 1
            except Exception as e:
                errors += 1
                rejected.append({"row": row, "reason": str(e)})

    return {"success": success, "errors": errors, "rejected": rejected}


def load_pacjenci(cursor, file_path: Path):
    """Ładuje kartotekę pacjentów z walidacją sumy kontrolnej PESEL."""
    success, errors, rejected = 0, 0, []
    print(f"[*] Przetwarzanie pacjentów z: {file_path.name}")

    with open(file_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            pesel = row.get("pesel", "").strip() or None
            paszport = row.get("nr_paszportu", "").strip() or None
            imie = row.get("imie", "").strip()
            nazwisko = row.get("nazwisko", "").strip()
            data_ur = row.get("data_urodzenia", "").strip()
            plec = row.get("plec", "").strip()
            ulica = row.get("ulica", "").strip()
            miasto = row.get("miasto", "").strip()
            kod = row.get("kod_pocztowy", "").strip()
            telefon = row.get("telefon", "").strip()

            # Walidacja PESEL
            if pesel:
                is_valid, reason = validate_pesel(pesel)
                if not is_valid:
                    errors += 1
                    rejected.append({"row": row, "reason": f"Odrzucono: {reason}"})
                    log_to_oracle(cursor, "WARN", "ETL_LOADER", f"Odrzucono pacjenta {imie} {nazwisko}: {reason}")
                    continue
            elif not paszport:
                errors += 1
                rejected.append({"row": row, "reason": "Brak zarówno PESEL, jak i numeru paszportu"})
                continue

            try:
                cursor.execute(
                    """
                    INSERT INTO PACJENCI (pesel, nr_paszportu, imie, nazwisko, data_urodzenia, plec, ulica, miasto, kod_pocztowy, telefon)
                    VALUES (:pesel, :paszport, :imie, :nazwisko, TO_DATE(:data_ur, 'YYYY-MM-DD'), :plec, :ulica, :miasto, :kod, :telefon)
                    """,
                    pesel=pesel, paszport=paszport, imie=imie, nazwisko=nazwisko,
                    data_ur=data_ur, plec=plec, ulica=ulica, miasto=miasto, kod=kod, telefon=telefon
                )
                success += 1
            except Exception as e:
                errors += 1
                rejected.append({"row": row, "reason": str(e)})

    return {"success": success, "errors": errors, "rejected": rejected}


def load_osoby_upowaznione(cursor, file_path: Path):
    """Ładuje osoby upoważnione przez pacjentów."""
    success, errors, rejected = 0, 0, []
    print(f"[*] Przetwarzanie osób upoważnionych z: {file_path.name}")

    with open(file_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            pesel = row.get("pesel_pacjenta", "").strip()
            nazwisko = row.get("imie_nazwisko", "").strip()
            relacja = row.get("relacja", "").strip()
            telefon = row.get("telefon", "").strip()

            cursor.execute("SELECT id_pacjenta FROM PACJENCI WHERE pesel = :pesel", pesel=pesel)
            res = cursor.fetchone()
            if not res:
                errors += 1
                rejected.append({"row": row, "reason": f"Pacjent o PESEL {pesel} nie istnieje w bazie"})
                continue

            id_pacjenta = res[0]
            try:
                cursor.execute(
                    """
                    INSERT INTO OSOBY_UPOWAZNIONE (id_pacjenta, imie_nazwisko, relacja, telefon)
                    VALUES (:id_pacjenta, :nazwisko, :relacja, :telefon)
                    """,
                    id_pacjenta=id_pacjenta, nazwisko=nazwisko, relacja=relacja, telefon=telefon
                )
                success += 1
            except Exception as e:
                errors += 1
                rejected.append({"row": row, "reason": str(e)})

    return {"success": success, "errors": errors, "rejected": rejected}


def load_pobyty_i_badania(cursor, file_path: Path, oddzialy_map: Dict[str, int], badania_map: Dict[str, int]):
    """Ładuje hospitalizacje oraz zagnieżdżone wyniki badań laboratoryjnych z pliku JSON."""
    success, errors, rejected = 0, 0, []
    print(f"[*] Przetwarzanie pobytów i badań z: {file_path.name}")

    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    for item in data:
        pesel = item.get("pesel_pacjenta")
        oddzial_nazwa = item.get("oddzial")
        pwz = item.get("pwz_lekarza")
        dt_adm = item.get("data_przyjecia")
        dt_dis = item.get("data_wypisu")
        icd10 = item.get("kod_icd10")
        koszt = float(item.get("koszt_leczenia", 0.0))
        badania = item.get("badania", [])

        # Walidacja dat pobytu
        is_valid, reason = validate_stay_dates(dt_adm, dt_dis)
        if not is_valid:
            errors += 1
            rejected.append({"item": item, "reason": f"Odrzucono pobyt: {reason}"})
            log_to_oracle(cursor, "WARN", "ETL_LOADER", f"Odrzucono pobyt dla PESEL {pesel}: {reason}")
            continue

        # Wyszukanie pacjenta
        cursor.execute("SELECT id_pacjenta FROM PACJENCI WHERE pesel = :pesel", pesel=pesel)
        res_pacjent = cursor.fetchone()
        if not res_pacjent:
            errors += 1
            rejected.append({"item": item, "reason": f"Brak pacjenta o PESEL {pesel}"})
            continue
        id_pacjenta = res_pacjent[0]

        # Wyszukanie oddziału
        id_oddzialu = oddzialy_map.get(oddzial_nazwa)
        if not id_oddzialu:
            errors += 1
            rejected.append({"item": item, "reason": f"Oddział '{oddzial_nazwa}' nie istnieje"})
            continue

        # Wyszukanie lekarza
        cursor.execute("SELECT id_personelu FROM PERSONEL WHERE nr_pwz = :pwz", pwz=pwz)
        res_lek = cursor.fetchone()
        if not res_lek:
            errors += 1
            rejected.append({"item": item, "reason": f"Lekarz o PWZ {pwz} nie istnieje"})
            continue
        id_lekarza = res_lek[0]

        try:
            # Wstawienie pobytu
            id_pobytu_var = cursor.var(int)
            cursor.execute(
                """
                INSERT INTO POBYTY (id_pacjenta, id_oddzialu, id_lekarza, data_przyjecia, data_wypisu, kod_icd10, koszt_leczenia)
                VALUES (:id_pacjenta, :id_oddzialu, :id_lekarza, 
                        TO_TIMESTAMP(:dt_adm, 'YYYY-MM-DD HH24:MI:SS'), 
                        CASE WHEN :dt_dis IS NOT NULL THEN TO_TIMESTAMP(:dt_dis, 'YYYY-MM-DD HH24:MI:SS') ELSE NULL END, 
                        :icd10, :koszt)
                RETURNING id_pobytu INTO :id_pobytu_var
                """,
                id_pacjenta=id_pacjenta, id_oddzialu=id_oddzialu, id_lekarza=id_lekarza,
                dt_adm=dt_adm, dt_dis=dt_dis, icd10=icd10, koszt=koszt, id_pobytu_var=id_pobytu_var
            )
            id_pobytu = id_pobytu_var.getvalue()[0]

            # Wstawienie badań laboratoryjnych wykonanych podczas pobytu
            for bad in badania:
                kod_bad = bad.get("kod_badania")
                wartosc = float(bad.get("wartosc", 0.0))
                dt_bad = bad.get("data_badania")

                id_badania = badania_map.get(kod_bad)
                if id_badania:
                    cursor.execute(
                        """
                        INSERT INTO WYNIKI_BADAN (id_pobytu, id_badania, wartosc, data_badania, zrodlo_pliku)
                        VALUES (:id_pobytu, :id_badania, :wartosc, TO_TIMESTAMP(:dt_bad, 'YYYY-MM-DD HH24:MI:SS'), :plik)
                        """,
                        id_pobytu=id_pobytu, id_badania=id_badania, wartosc=wartosc,
                        dt_bad=dt_bad, plik=file_path.name
                    )

            success += 1
        except Exception as e:
            errors += 1
            rejected.append({"item": item, "reason": str(e)})

    return {"success": success, "errors": errors, "rejected": rejected}


def archive_file(file_path: Path, status_dict: Dict[str, Any]):
    """Przenosi przetworzony plik do archiwum i zapisuje ewentualne odrzucone rekordy."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    processed_dest = PROCESSED_DIR / f"{timestamp}_{file_path.name}"
    shutil.move(str(file_path), str(processed_dest))
    print(f"[>] Zarchiwizowano: {file_path.name} -> {processed_dest.name}")

    if status_dict.get("rejected"):
        failed_dest = FAILED_DIR / f"{timestamp}_{file_path.stem}_errors.json"
        with open(failed_dest, "w", encoding="utf-8") as f:
            json.dump(status_dict["rejected"], f, indent=2, ensure_ascii=False)
        print(f"[!] Zapisano odrzucone rekordy ({len(status_dict['rejected'])}) do: {failed_dest.name}")


def process_inbox():
    """Przetwarza wszystkie pliki oczekujące w katalogu inbox."""
    inbox_files = sorted(list(INBOX_DIR.glob("*.csv")) + list(INBOX_DIR.glob("*.json")))

    if not inbox_files:
        print("[*] Brak nowych plików w katalogu inbox.")
        return

    print(f"\n========================================================")
    print(f"[*] ROZPOCZĘCIE PRZETWARZANIA ETL ({len(inbox_files)} plików w kolejce)")
    print(f"========================================================")

    try:
        conn = get_connection()
        cursor = conn.cursor()
    except Exception as e:
        print(f"[X] Błąd połączenia z bazą Oracle: {e}")
        return

    oddzialy_map = {}
    spec_map = {}
    badania_map = {}

    # Pobieramy bieżący stan słowników z bazy na wypadek, gdyby pliki słowników były już wcześniej załadowane
    try:
        cursor.execute("SELECT nazwa, id_oddzialu FROM ODDZIALY")
        oddzialy_map = {r[0]: r[1] for r in cursor.fetchall()}
        cursor.execute("SELECT nazwa, id_specjalizacji FROM SPECJALIZACJE")
        spec_map = {r[0]: r[1] for r in cursor.fetchall()}
        cursor.execute("SELECT kod_badania, id_badania FROM BADANIA_SLOWNIK")
        badania_map = {r[0]: r[1] for r in cursor.fetchall()}
    except Exception as e:
        print(f"[!] Błąd weryfikacji słowników: {e}")

    for file_path in inbox_files:
        fname = file_path.name.lower()
        res = {"success": 0, "errors": 0, "rejected": []}

        if "oddzialy" in fname:
            res = load_oddzialy(cursor, file_path)
            oddzialy_map.update(res["mapping"])
        elif "specjalizacje" in fname:
            res = load_specjalizacje(cursor, file_path)
            spec_map.update(res["mapping"])
        elif "badania_slownik" in fname:
            res = load_badania_slownik(cursor, file_path)
            badania_map.update(res["mapping"])
        elif "personel" in fname:
            res = load_personel(cursor, file_path, oddzialy_map, spec_map)
        elif "pacjenci" in fname:
            res = load_pacjenci(cursor, file_path)
        elif "osoby" in fname:
            res = load_osoby_upowaznione(cursor, file_path)
        elif "pobyty" in fname or file_path.suffix == ".json":
            res = load_pobyty_i_badania(cursor, file_path, oddzialy_map, badania_map)
        else:
            print(f"[?] Pominięto nierozpoznany plik: {file_path.name}")
            continue

        conn.commit()
        log_to_oracle(
            cursor, "INFO", "ETL_LOADER",
            f"Załadowano plik {file_path.name}: sukces={res['success']}, błędy={res['errors']}"
        )
        conn.commit()
        archive_file(file_path, res)

    cursor.close()
    conn.close()
    print(f"\n[+] Zakończono przetwarzanie kolejki ETL.")


def main():
    parser = argparse.ArgumentParser(description="HIS & EDM ETL Data Loader")
    parser.add_argument("--once", action="store_true", help="Jednorazowe przetworzenie plików")
    parser.add_argument("--daemon", action="store_true", help="Tryb ciągły (demon) sprawdzający katalog inbox")
    parser.add_argument("--interval", type=int, default=30, help="Interwał w sekundach dla trybu demona (domyślnie 30s)")
    parser.add_argument("--generate", action="store_true", help="Generuje zestaw danych testowych przed załadowaniem")

    args = parser.parse_args()

    # Jeśli podano flagę --generate lub inbox jest pusty i processed też jest puste
    inbox_files = list(INBOX_DIR.glob("*.csv")) + list(INBOX_DIR.glob("*.json"))
    processed_files = list(PROCESSED_DIR.glob("*.csv")) + list(PROCESSED_DIR.glob("*.json"))

    if args.generate or (not inbox_files and not processed_files):
        generate_all_datasets(INBOX_DIR)

    if args.daemon:
        print(f"[*] Uruchomiono ETL w trybie ciągłym (DEMON, interwał: {args.interval}s). Zatrzymanie: Ctrl+C")
        try:
            while True:
                process_inbox()
                time.sleep(args.interval)
        except KeyboardInterrupt:
            print("\n[*] Zatrzymano demona ETL.")
    else:
        # Domyślnie tryb jednorazowy
        process_inbox()


if __name__ == "__main__":
    main()
