-- ============================================================================
-- PROJEKT: System HIS & EDM (Hospital Information System)
-- MODUŁ: 02 - Audyt, Archiwizacja i Podstawowe Wyzwalacze
-- BAZA DANYCH: Oracle Database 23ai / 21c
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. PAKIET LOGOWANIA I AUDYTU: PKG_LOGI
-- Wykorzystuje transakcje autonomiczne (PRAGMA AUTONOMOUS_TRANSACTION), 
-- co gwarantuje zapisanie logu w tabeli LOGI_SYSTEMOWE nawet w przypadku
-- wycofania (ROLLBACK) transakcji biznesowej.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE PKG_LOGI AS
    PROCEDURE log_info(p_modul IN VARCHAR2, p_komunikat IN VARCHAR2);
    PROCEDURE log_warn(p_modul IN VARCHAR2, p_komunikat IN VARCHAR2);
    PROCEDURE log_error(p_modul IN VARCHAR2, p_komunikat IN VARCHAR2);
END PKG_LOGI;
/

CREATE OR REPLACE PACKAGE BODY PKG_LOGI AS

    PROCEDURE zapisz_log(p_poziom IN VARCHAR2, p_modul IN VARCHAR2, p_komunikat IN VARCHAR2) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO LOGI_SYSTEMOWE (data_zdarzenia, poziom, modul, komunikat)
        VALUES (SYSTIMESTAMP, p_poziom, p_modul, SUBSTR(p_komunikat, 1, 4000));
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
    END zapisz_log;

    PROCEDURE log_info(p_modul IN VARCHAR2, p_komunikat IN VARCHAR2) IS
    BEGIN
        zapisz_log('INFO', p_modul, p_komunikat);
    END log_info;

    PROCEDURE log_warn(p_modul IN VARCHAR2, p_komunikat IN VARCHAR2) IS
    BEGIN
        zapisz_log('WARN', p_modul, p_komunikat);
    END log_warn;

    PROCEDURE log_error(p_modul IN VARCHAR2, p_komunikat IN VARCHAR2) IS
    BEGIN
        zapisz_log('ERROR', p_modul, p_komunikat);
    END log_error;

END PKG_LOGI;
/


-- ----------------------------------------------------------------------------
-- 2. FUNKCJA WALIDACJI SUMY KONTROLNEJ PESEL: FNC_WALIDUJ_PESEL
-- Zwraca: 1 (PESEL poprawny), 0 (PESEL niepoprawny).
-- Weryfikuje: długość (11 cyfr), poprawność znaków, sumę kontrolną oraz datę.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION FNC_WALIDUJ_PESEL(p_pesel IN VARCHAR2) 
RETURN NUMBER IS
    v_wagi CONSTANT VARCHAR2(30) := '1379137913';
    v_suma NUMBER := 0;
    v_cyfra_kontr NUMBER;
    v_obliczona NUMBER;
    v_rok NUMBER;
    v_miesiac NUMBER;
    v_dzien NUMBER;
    v_data_test DATE;
BEGIN
    -- PESEL może być NULL (np. dla obcokrajowców posiadających paszport)
    IF p_pesel IS NULL THEN
        RETURN 1;
    END IF;

    -- Weryfikacja długości i czy zawiera tylko cyfry
    IF LENGTH(p_pesel) <> 11 OR NOT REGEXP_LIKE(p_pesel, '^[0-9]{11}$') THEN
        RETURN 0;
    END IF;

    -- Obliczenie sumy ważonej dla pierwszych 10 cyfr
    FOR i IN 1..10 LOOP
        v_suma := v_suma + TO_NUMBER(SUBSTR(p_pesel, i, 1)) * TO_NUMBER(SUBSTR(v_wagi, i, 1));
    END LOOP;

    -- Obliczenie cyfry kontrolnej
    v_obliczona := MOD(10 - MOD(v_suma, 10), 10);
    v_cyfra_kontr := TO_NUMBER(SUBSTR(p_pesel, 11, 1));

    IF v_obliczona <> v_cyfra_kontr THEN
        RETURN 0;
    END IF;

    -- Weryfikacja daty zakodowanej w numerze PESEL
    v_rok := TO_NUMBER(SUBSTR(p_pesel, 1, 2));
    v_miesiac := TO_NUMBER(SUBSTR(p_pesel, 3, 2));
    v_dzien := TO_NUMBER(SUBSTR(p_pesel, 5, 2));

    IF v_miesiac BETWEEN 1 AND 12 THEN
        v_rok := 1900 + v_rok;
    ELSIF v_miesiac BETWEEN 21 AND 32 THEN
        v_rok := 2000 + v_rok;
        v_miesiac := v_miesiac - 20;
    ELSIF v_miesiac BETWEEN 41 AND 52 THEN
        v_rok := 2100 + v_rok;
        v_miesiac := v_miesiac - 40;
    ELSIF v_miesiac BETWEEN 61 AND 72 THEN
        v_rok := 2200 + v_rok;
        v_miesiac := v_miesiac - 60;
    ELSIF v_miesiac BETWEEN 81 AND 92 THEN
        v_rok := 1800 + v_rok;
        v_miesiac := v_miesiac - 80;
    ELSE
        RETURN 0;
    END IF;

    BEGIN
        v_data_test := TO_DATE(LPAD(v_rok, 4, '0') || '-' || LPAD(v_miesiac, 2, '0') || '-' || LPAD(v_dzien, 2, '0'), 'YYYY-MM-DD');
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END;

    RETURN 1;
END FNC_WALIDUJ_PESEL;
/


-- ----------------------------------------------------------------------------
-- 3. FUNKCJA WALIDACJI NUMERU PWZ LEKARZA: FNC_WALIDUJ_PWZ
-- Zwraca: 1 (PWZ poprawny), 0 (PWZ niepoprawny).
-- Algorytm Naczelnej Izby Lekarskiej:
-- 7 cyfr, pierwsza cyfra to suma kontrolna cyfr 2..7 o wagach 1, 2, 3, 4, 5, 6 modulo 11.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION FNC_WALIDUJ_PWZ(p_pwz IN VARCHAR2) 
RETURN NUMBER IS
    v_suma NUMBER := 0;
    v_cyfra_kontr NUMBER;
    v_obliczona NUMBER;
BEGIN
    IF p_pwz IS NULL THEN
        RETURN 1;
    END IF;

    IF LENGTH(p_pwz) <> 7 OR NOT REGEXP_LIKE(p_pwz, '^[0-9]{7}$') THEN
        RETURN 0;
    END IF;

    v_cyfra_kontr := TO_NUMBER(SUBSTR(p_pwz, 1, 1));

    -- Obliczenie sumy ważonej dla cyfr od 2 do 7
    FOR i IN 1..6 LOOP
        v_suma := v_suma + TO_NUMBER(SUBSTR(p_pwz, i + 1, 1)) * i;
    END LOOP;

    v_obliczona := MOD(v_suma, 11);

    IF v_obliczona <> v_cyfra_kontr THEN
        RETURN 0;
    END IF;

    RETURN 1;
END FNC_WALIDUJ_PWZ;
/


-- ----------------------------------------------------------------------------
-- 4. WYZWALACZ ARCHIWIZACJI USUNIĘTYCH POBYTÓW: TRG_POBYTY_ARCH_DEL
-- Spełnia formalny wymóg projektu: archiwizacja usuniętych danych.
-- Kopiuje każdy usuwany wiersz z tabeli POBYTY do POBYTY_ARCH i loguje fakt usunięcia.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_POBYTY_ARCH_DEL
AFTER DELETE ON POBYTY
FOR EACH ROW
BEGIN
    INSERT INTO POBYTY_ARCH (
        id_pobytu,
        id_pacjenta,
        id_oddzialu,
        data_przyjecia,
        data_wypisu,
        data_usuniecia,
        uzytkownik_db
    ) VALUES (
        :OLD.id_pobytu,
        :OLD.id_pacjenta,
        :OLD.id_oddzialu,
        :OLD.data_przyjecia,
        :OLD.data_wypisu,
        SYSTIMESTAMP,
        USER
    );

    PKG_LOGI.log_info(
        'TRG_POBYTY_ARCH_DEL',
        'Zarchiwizowano usuniety pobyt ID=' || :OLD.id_pobytu || 
        ' dla pacjenta ID=' || :OLD.id_pacjenta || ' przez uzytkownika ' || USER
    );
END;
/


-- ----------------------------------------------------------------------------
-- 5. WYZWALACZ AUTOMATYCZNEJ OCENY WYNIKÓW BADAŃ: TRG_WYNIKI_BADAN_BIU
-- Przed wstawieniem lub aktualizacją wyniku badania automatycznie sprawdza
-- zakres normy w słowniku BADANIA_SLOWNIK i ustawia flagę CZY_W_NORMIE ('T'/'N').
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_WYNIKI_BADAN_BIU
BEFORE INSERT OR UPDATE ON WYNIKI_BADAN
FOR EACH ROW
DECLARE
    v_norma_min NUMBER(10, 3);
    v_norma_max NUMBER(10, 3);
BEGIN
    SELECT norma_min, norma_max
    INTO v_norma_min, v_norma_max
    FROM BADANIA_SLOWNIK
    WHERE id_badania = :NEW.id_badania;

    IF (v_norma_min IS NOT NULL AND :NEW.wartosc < v_norma_min) OR
       (v_norma_max IS NOT NULL AND :NEW.wartosc > v_norma_max) THEN
        :NEW.czy_w_normie := 'N';
    ELSE
        :NEW.czy_w_normie := 'T';
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        :NEW.czy_w_normie := 'T';
END;
/

COMMIT;
