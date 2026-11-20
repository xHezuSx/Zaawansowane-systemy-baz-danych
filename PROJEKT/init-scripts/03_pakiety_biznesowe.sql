CREATE OR REPLACE PACKAGE PKG_PACJENCI AS
    EX_PACJENT_JUZ_ISTNIEJE EXCEPTION;
    PRAGMA EXCEPTION_INIT(EX_PACJENT_JUZ_ISTNIEJE, -20001);

    EX_NIEPOPRAWNY_IDENTYFIKATOR EXCEPTION;
    PRAGMA EXCEPTION_INIT(EX_NIEPOPRAWNY_IDENTYFIKATOR, -20002);

    EX_PACJENT_NIE_ISTNIEJE EXCEPTION;
    PRAGMA EXCEPTION_INIT(EX_PACJENT_NIE_ISTNIEJE, -20003);

    EX_PACJENT_AKTYWNY EXCEPTION;
    PRAGMA EXCEPTION_INIT(EX_PACJENT_AKTYWNY, -20004);

    PROCEDURE dodaj_pacjenta(
        p_imie           IN VARCHAR2,
        p_nazwisko       IN VARCHAR2,
        p_data_urodzenia IN DATE,
        p_plec           IN CHAR,
        p_miasto         IN VARCHAR2,
        p_pesel          IN VARCHAR2 DEFAULT NULL,
        p_nr_paszportu   IN VARCHAR2 DEFAULT NULL,
        p_ulica          IN VARCHAR2 DEFAULT NULL,
        p_kod_pocztowy   IN VARCHAR2 DEFAULT NULL,
        p_kraj           IN VARCHAR2 DEFAULT 'Polska',
        p_telefon        IN VARCHAR2 DEFAULT NULL,
        p_id_pacjenta    OUT NUMBER
    );

    PROCEDURE aktualizuj_dane(
        p_id_pacjenta  IN NUMBER,
        p_ulica        IN VARCHAR2 DEFAULT NULL,
        p_miasto       IN VARCHAR2 DEFAULT NULL,
        p_kod_pocztowy IN VARCHAR2 DEFAULT NULL,
        p_telefon      IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE usun_pacjenta(
        p_id_pacjenta IN NUMBER
    );
END PKG_PACJENCI;
/

CREATE OR REPLACE PACKAGE BODY PKG_PACJENCI AS

    PROCEDURE dodaj_pacjenta(
        p_imie           IN VARCHAR2,
        p_nazwisko       IN VARCHAR2,
        p_data_urodzenia IN DATE,
        p_plec           IN CHAR,
        p_miasto         IN VARCHAR2,
        p_pesel          IN VARCHAR2 DEFAULT NULL,
        p_nr_paszportu   IN VARCHAR2 DEFAULT NULL,
        p_ulica          IN VARCHAR2 DEFAULT NULL,
        p_kod_pocztowy   IN VARCHAR2 DEFAULT NULL,
        p_kraj           IN VARCHAR2 DEFAULT 'Polska',
        p_telefon        IN VARCHAR2 DEFAULT NULL,
        p_id_pacjenta    OUT NUMBER
    ) IS
        v_count NUMBER;
    BEGIN
        IF p_pesel IS NULL AND p_nr_paszportu IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'Wymagany jest numer PESEL lub numer paszportu.');
        END IF;

        IF p_pesel IS NOT NULL AND FNC_WALIDUJ_PESEL(p_pesel) = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Niepoprawny numer PESEL.');
        END IF;

        SELECT COUNT(*)
        INTO v_count
        FROM PACJENCI
        WHERE (p_pesel IS NOT NULL AND pesel = p_pesel)
           OR (p_nr_paszportu IS NOT NULL AND nr_paszportu = p_nr_paszportu);

        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Pacjent o podanym identyfikatorze juz istnieje.');
        END IF;

        INSERT INTO PACJENCI (
            pesel, nr_paszportu, imie, nazwisko, data_urodzenia, plec, ulica, miasto, kod_pocztowy, kraj, telefon
        ) VALUES (
            p_pesel, p_nr_paszportu, p_imie, p_nazwisko, p_data_urodzenia, p_plec, p_ulica, p_miasto, p_kod_pocztowy, p_kraj, p_telefon
        ) RETURNING id_pacjenta INTO p_id_pacjenta;

        PKG_LOGI.log_info('PKG_PACJENCI', 'Dodano pacjenta ID: ' || p_id_pacjenta);
    EXCEPTION
        WHEN OTHERS THEN
            PKG_LOGI.log_error('PKG_PACJENCI', 'Blad dodawania pacjenta: ' || SQLERRM);
            RAISE;
    END dodaj_pacjenta;

    PROCEDURE aktualizuj_dane(
        p_id_pacjenta  IN NUMBER,
        p_ulica        IN VARCHAR2 DEFAULT NULL,
        p_miasto       IN VARCHAR2 DEFAULT NULL,
        p_kod_pocztowy IN VARCHAR2 DEFAULT NULL,
        p_telefon      IN VARCHAR2 DEFAULT NULL
    ) IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM PACJENCI
        WHERE id_pacjenta = p_id_pacjenta;

        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Wskazany pacjent nie istnieje.');
        END IF;

        UPDATE PACJENCI
        SET ulica = NVL(p_ulica, ulica),
            miasto = NVL(p_miasto, miasto),
            kod_pocztowy = NVL(p_kod_pocztowy, kod_pocztowy),
            telefon = NVL(p_telefon, telefon)
        WHERE id_pacjenta = p_id_pacjenta;

        PKG_LOGI.log_info('PKG_PACJENCI', 'Zaktualizowano dane pacjenta ID: ' || p_id_pacjenta);
    EXCEPTION
        WHEN OTHERS THEN
            PKG_LOGI.log_error('PKG_PACJENCI', 'Blad aktualizacji pacjenta: ' || SQLERRM);
            RAISE;
    END aktualizuj_dane;

    PROCEDURE usun_pacjenta(
        p_id_pacjenta IN NUMBER
    ) IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM PACJENCI
        WHERE id_pacjenta = p_id_pacjenta;

        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Wskazany pacjent nie istnieje.');
        END IF;

        SELECT COUNT(*)
        INTO v_count
        FROM POBYTY
        WHERE id_pacjenta = p_id_pacjenta
          AND data_wypisu IS NULL;

        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Nie mozna usunac pacjenta z aktywna hospitalizacja.');
        END IF;

        DELETE FROM PACJENCI
        WHERE id_pacjenta = p_id_pacjenta;

        PKG_LOGI.log_info('PKG_PACJENCI', 'Usunieto pacjenta ID: ' || p_id_pacjenta);
    EXCEPTION
        WHEN OTHERS THEN
            PKG_LOGI.log_error('PKG_PACJENCI', 'Blad usuwania pacjenta: ' || SQLERRM);
            RAISE;
    END usun_pacjenta;

END PKG_PACJENCI;
/


CREATE OR REPLACE PACKAGE PKG_HOSPITALIZACJE AS
    EX_PACJENT_JUZ_HOSPITALIZOWANY EXCEPTION;
    PRAGMA EXCEPTION_INIT(EX_PACJENT_JUZ_HOSPITALIZOWANY, -20010);

    EX_LEKARZ_NIE_NALEZY_DO_ODDZIALU EXCEPTION;
    PRAGMA EXCEPTION_INIT(EX_LEKARZ_NIE_NALEZY_DO_ODDZIALU, -20011);

    EX_POBYT_NIE_ISTNIEJE EXCEPTION;
    PRAGMA EXCEPTION_INIT(EX_POBYT_NIE_ISTNIEJE, -20012);

    EX_POBYT_JUZ_ZAMKNIETY EXCEPTION;
    PRAGMA EXCEPTION_INIT(EX_POBYT_JUZ_ZAMKNIETY, -20013);

    EX_NIEPOPRAWNE_DATY EXCEPTION;
    PRAGMA EXCEPTION_INIT(EX_NIEPOPRAWNE_DATY, -20014);

    PROCEDURE przyjmij_pacjenta(
        p_id_pacjenta      IN NUMBER,
        p_id_oddzialu      IN NUMBER,
        p_id_lekarza       IN NUMBER,
        p_data_przyjecia   IN TIMESTAMP DEFAULT SYSTIMESTAMP,
        p_koszt_poczatkowy IN NUMBER DEFAULT 0,
        p_id_pobytu        OUT NUMBER
    );

    PROCEDURE wypisz_pacjenta(
        p_id_pobytu       IN NUMBER,
        p_kod_icd10       IN VARCHAR2,
        p_data_wypisu     IN TIMESTAMP DEFAULT SYSTIMESTAMP,
        p_koszt_calkowity OUT NUMBER
    );

    PROCEDURE zlec_badanie(
        p_id_pobytu    IN NUMBER,
        p_kod_badania  IN VARCHAR2,
        p_wartosc      IN NUMBER,
        p_data_badania IN TIMESTAMP DEFAULT SYSTIMESTAMP,
        p_id_wyniku    OUT NUMBER
    );

    PROCEDURE pobierz_ranking_kosztow(
        p_kursor OUT SYS_REFCURSOR
    );

    PROCEDURE generuj_podsumowanie_okresowe(
        p_rok     IN NUMBER,
        p_miesiac IN NUMBER
    );
END PKG_HOSPITALIZACJE;
/

CREATE OR REPLACE PACKAGE BODY PKG_HOSPITALIZACJE AS

    PROCEDURE przyjmij_pacjenta(
        p_id_pacjenta      IN NUMBER,
        p_id_oddzialu      IN NUMBER,
        p_id_lekarza       IN NUMBER,
        p_data_przyjecia   IN TIMESTAMP DEFAULT SYSTIMESTAMP,
        p_koszt_poczatkowy IN NUMBER DEFAULT 0,
        p_id_pobytu        OUT NUMBER
    ) IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM PACJENCI
        WHERE id_pacjenta = p_id_pacjenta;

        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20012, 'Wskazany pacjent nie istnieje.');
        END IF;

        SELECT COUNT(*)
        INTO v_count
        FROM POBYTY
        WHERE id_pacjenta = p_id_pacjenta
          AND data_wypisu IS NULL;

        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20010, 'Pacjent posiada juz aktywny pobyt w szpitalu.');
        END IF;

        SELECT COUNT(*)
        INTO v_count
        FROM PERSONEL
        WHERE id_personelu = p_id_lekarza
          AND id_oddzialu = p_id_oddzialu;

        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20011, 'Lekarz nie jest przypisany do wskazanego oddzialu.');
        END IF;

        INSERT INTO POBYTY (
            id_pacjenta, id_oddzialu, id_lekarza, data_przyjecia, koszt_leczenia
        ) VALUES (
            p_id_pacjenta, p_id_oddzialu, p_id_lekarza, p_data_przyjecia, p_koszt_poczatkowy
        ) RETURNING id_pobytu INTO p_id_pobytu;

        PKG_LOGI.log_info('PKG_HOSPITALIZACJE', 'Przyjeto pacjenta ID: ' || p_id_pacjenta || ', pobyt ID: ' || p_id_pobytu);
    EXCEPTION
        WHEN OTHERS THEN
            PKG_LOGI.log_error('PKG_HOSPITALIZACJE', 'Blad przyjecia pacjenta: ' || SQLERRM);
            RAISE;
    END przyjmij_pacjenta;

    PROCEDURE wypisz_pacjenta(
        p_id_pobytu       IN NUMBER,
        p_kod_icd10       IN VARCHAR2,
        p_data_wypisu     IN TIMESTAMP DEFAULT SYSTIMESTAMP,
        p_koszt_calkowity OUT NUMBER
    ) IS
        v_data_przyjecia TIMESTAMP;
        v_data_wypisu    TIMESTAMP;
        v_id_lekarza     NUMBER;
        v_koszt_obecny   NUMBER;
        v_stawka         NUMBER;
        v_dni            NUMBER;
    BEGIN
        BEGIN
            SELECT data_przyjecia, data_wypisu, id_lekarza, koszt_leczenia
            INTO v_data_przyjecia, v_data_wypisu, v_id_lekarza, v_koszt_obecny
            FROM POBYTY
            WHERE id_pobytu = p_id_pobytu;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20012, 'Wskazany pobyt nie istnieje.');
        END;

        IF v_data_wypisu IS NOT NULL THEN
            RAISE_APPLICATION_ERROR(-20013, 'Pobyt zostal juz wczesniej zamkniety.');
        END IF;

        IF p_data_wypisu < v_data_przyjecia THEN
            RAISE_APPLICATION_ERROR(-20014, 'Data wypisu nie moze byc wczesniejsza niz data przyjecia.');
        END IF;

        SELECT stawka_godzinowa
        INTO v_stawka
        FROM PERSONEL
        WHERE id_personelu = v_id_lekarza;

        v_dni := GREATEST(1, ROUND(CAST(p_data_wypisu AS DATE) - CAST(v_data_przyjecia AS DATE)));
        p_koszt_calkowity := v_koszt_obecny + (v_dni * 250) + (v_stawka * 4);

        UPDATE POBYTY
        SET data_wypisu = p_data_wypisu,
            kod_icd10 = p_kod_icd10,
            koszt_leczenia = p_koszt_calkowity
        WHERE id_pobytu = p_id_pobytu;

        PKG_LOGI.log_info('PKG_HOSPITALIZACJE', 'Wypisano pobyt ID: ' || p_id_pobytu || ', koszt: ' || p_koszt_calkowity);
    EXCEPTION
        WHEN OTHERS THEN
            PKG_LOGI.log_error('PKG_HOSPITALIZACJE', 'Blad wypisu pacjenta: ' || SQLERRM);
            RAISE;
    END wypisz_pacjenta;

    PROCEDURE zlec_badanie(
        p_id_pobytu    IN NUMBER,
        p_kod_badania  IN VARCHAR2,
        p_wartosc      IN NUMBER,
        p_data_badania IN TIMESTAMP DEFAULT SYSTIMESTAMP,
        p_id_wyniku    OUT NUMBER
    ) IS
        v_data_wypisu TIMESTAMP;
        v_id_badania  NUMBER;
    BEGIN
        BEGIN
            SELECT data_wypisu
            INTO v_data_wypisu
            FROM POBYTY
            WHERE id_pobytu = p_id_pobytu;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20012, 'Wskazany pobyt nie istnieje.');
        END;

        IF v_data_wypisu IS NOT NULL THEN
            RAISE_APPLICATION_ERROR(-20013, 'Nie mozna zlecic badania dla zamknietego pobytu.');
        END IF;

        BEGIN
            SELECT id_badania
            INTO v_id_badania
            FROM BADANIA_SLOWNIK
            WHERE kod_badania = p_kod_badania;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20015, 'Nieznany kod badania laboratoryjnego.');
        END;

        INSERT INTO WYNIKI_BADAN (
            id_pobytu, id_badania, wartosc, data_badania, zrodlo_pliku
        ) VALUES (
            p_id_pobytu, v_id_badania, p_wartosc, p_data_badania, 'PKG_HOSPITALIZACJE'
        ) RETURNING id_wyniku INTO p_id_wyniku;

        PKG_LOGI.log_info('PKG_HOSPITALIZACJE', 'Zlecono badanie ' || p_kod_badania || ' dla pobytu ID: ' || p_id_pobytu);
    EXCEPTION
        WHEN OTHERS THEN
            PKG_LOGI.log_error('PKG_HOSPITALIZACJE', 'Blad zlecania badania: ' || SQLERRM);
            RAISE;
    END zlec_badanie;

    PROCEDURE pobierz_ranking_kosztow(
        p_kursor OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_kursor FOR
            SELECT p.id_pobytu,
                   o.nazwa AS nazwa_oddzialu,
                   pac.nazwisko || ' ' || pac.imie AS pacjent,
                   p.koszt_leczenia,
                   ROUND(AVG(p.koszt_leczenia) OVER (PARTITION BY p.id_oddzialu), 2) AS sredni_koszt_oddzialu,
                   ROUND(p.koszt_leczenia - AVG(p.koszt_leczenia) OVER (PARTITION BY p.id_oddzialu), 2) AS roznica_od_sredniej,
                   DENSE_RANK() OVER (PARTITION BY p.id_oddzialu ORDER BY p.koszt_leczenia DESC) AS pozycja_na_oddziale,
                   DENSE_RANK() OVER (ORDER BY p.koszt_leczenia DESC) AS pozycja_w_szpitalu
            FROM POBYTY p
            JOIN ODDZIALY o ON p.id_oddzialu = o.id_oddzialu
            JOIN PACJENCI pac ON p.id_pacjenta = pac.id_pacjenta
            ORDER BY p.id_oddzialu, pozycja_na_oddziale;
    END pobierz_ranking_kosztow;

    PROCEDURE generuj_podsumowanie_okresowe(
        p_rok     IN NUMBER,
        p_miesiac IN NUMBER
    ) IS
    BEGIN
        MERGE INTO PODSUMOWANIA_OKRESOWE dest
        USING (
            SELECT 'MIESIECZNY' AS typ_okresu,
                   p_rok AS rok,
                   p_miesiac AS okres_nr,
                   p.id_oddzialu,
                   COUNT(*) AS liczba_pobytow,
                   ROUND(AVG(NVL(CAST(p.data_wypisu AS DATE), TRUNC(SYSDATE)) - CAST(p.data_przyjecia AS DATE)), 2) AS sr_czas_pobytu_dni,
                   SUM(p.koszt_leczenia) AS laczny_koszt
            FROM POBYTY p
            WHERE EXTRACT(YEAR FROM p.data_przyjecia) = p_rok
              AND EXTRACT(MONTH FROM p.data_przyjecia) = p_miesiac
            GROUP BY p.id_oddzialu
        ) src
        ON (dest.typ_okresu = src.typ_okresu AND dest.rok = src.rok AND dest.okres_nr = src.okres_nr AND dest.id_oddzialu = src.id_oddzialu)
        WHEN MATCHED THEN
            UPDATE SET dest.liczba_pobytow = src.liczba_pobytow,
                       dest.sr_czas_pobytu_dni = src.sr_czas_pobytu_dni,
                       dest.laczny_koszt = src.laczny_koszt
        WHEN NOT MATCHED THEN
            INSERT (typ_okresu, rok, okres_nr, id_oddzialu, liczba_pobytow, sr_czas_pobytu_dni, laczny_koszt)
            VALUES (src.typ_okresu, src.rok, src.okres_nr, src.id_oddzialu, src.liczba_pobytow, src.sr_czas_pobytu_dni, src.laczny_koszt);

        PKG_LOGI.log_info('PKG_HOSPITALIZACJE', 'Wygenerowano podsumowanie miesieczne za ' || p_rok || '/' || p_miesiac);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            PKG_LOGI.log_error('PKG_HOSPITALIZACJE', 'Blad generowania podsumowania: ' || SQLERRM);
            ROLLBACK;
            RAISE;
    END generuj_podsumowanie_okresowe;

END PKG_HOSPITALIZACJE;
/
