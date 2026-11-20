import re
from datetime import datetime
from typing import Tuple, Optional


def validate_pesel(pesel: Optional[str]) -> Tuple[bool, str]:
    """
    Waliduje polski numer PESEL:
    - 11 cyfr
    - sumę kontrolną z wagami: 1, 3, 7, 9, 1, 3, 7, 9, 1, 3
    - poprawność zakodowanej daty urodzenia (z uwzględnieniem stuleci 1800-2299)
    Zwraca: (True, "") lub (False, "powód błędu")
    """
    if not pesel or pesel.strip() == "":
        return True, ""  # Dopuszczalne dla cudzoziemców posiadających paszport

    pesel = pesel.strip()

    if len(pesel) != 11:
        return False, f"Nieprawidłowa długość PESEL ({len(pesel)} zamiast 11 cyfr)"

    if not pesel.isdigit():
        return False, "PESEL może zawierać wyłącznie cyfry"

    weights = [1, 3, 7, 9, 1, 3, 7, 9, 1, 3]
    checksum = sum(int(pesel[i]) * weights[i] for i in range(10))
    expected_last_digit = (10 - (checksum % 10)) % 10

    if int(pesel[10]) != expected_last_digit:
        return False, f"Błędna cyfra kontrolna PESEL (jest: {pesel[10]}, oczekiwana: {expected_last_digit})"

    # Walidacja daty zakodowanej w PESEL
    year = int(pesel[0:2])
    month = int(pesel[2:4])
    day = int(pesel[4:6])

    if 1 <= month <= 12:
        year += 1900
    elif 21 <= month <= 32:
        year += 2000
        month -= 20
    elif 41 <= month <= 52:
        year += 2100
        month -= 40
    elif 61 <= month <= 72:
        year += 2200
        month -= 60
    elif 81 <= month <= 92:
        year += 1800
        month -= 80
    else:
        return False, f"Nieprawidłowy miesiąc zakodowany w PESEL: {month}"

    try:
        datetime(year, month, day)
    except ValueError:
        return False, f"Niepoprawna data urodzenia w PESEL: {year:04d}-{month:02d}-{day:02d}"

    return True, ""


def validate_pwz(pwz: Optional[str]) -> Tuple[bool, str]:
    """
    Waliduje numer Prawa Wykonywania Zawodu lekarza (PWZ):
    - 7 cyfr
    - pierwsza cyfra jest cyfrą kontrolną wyliczaną z cyfr 2..7 o wagach 1, 2, 3, 4, 5, 6 modulo 11
    """
    if not pwz or pwz.strip() == "":
        return True, ""  # Dopuszczalne dla pielęgniarek / personelu pomocniczego

    pwz = pwz.strip()

    if len(pwz) != 7:
        return False, f"Nieprawidłowa długość PWZ ({len(pwz)} zamiast 7 cyfr)"

    if not pwz.isdigit():
        return False, "Numer PWZ może zawierać wyłącznie cyfry"

    control_digit = int(pwz[0])
    weights = [1, 2, 3, 4, 5, 6]
    weighted_sum = sum(int(pwz[i]) * weights[i - 1] for i in range(1, 7))
    expected_control = weighted_sum % 11

    if control_digit != expected_control:
        return False, f"Błędna cyfra kontrolna PWZ (jest: {control_digit}, oczekiwana: {expected_control})"

    return True, ""


def validate_stay_dates(admission_str: str, discharge_str: Optional[str]) -> Tuple[bool, str]:
    """
    Sprawdza, czy data wypisu nie jest wcześniejsza niż data przyjęcia.
    """
    try:
        dt_adm = datetime.fromisoformat(admission_str.replace(" ", "T"))
    except Exception as e:
        return False, f"Niepoprawny format daty przyjęcia: {admission_str} ({e})"

    if discharge_str and discharge_str.strip():
        try:
            dt_dis = datetime.fromisoformat(discharge_str.replace(" ", "T"))
            if dt_dis < dt_adm:
                return False, f"Data wypisu ({discharge_str}) jest wcześniejsza niż data przyjęcia ({admission_str})"
        except Exception as e:
            return False, f"Niepoprawny format daty wypisu: {discharge_str} ({e})"

    return True, ""
