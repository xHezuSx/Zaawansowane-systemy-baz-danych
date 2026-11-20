CREATE OR REPLACE PACKAGE PKG_RAPORTY AS

    PROCEDURE generuj_podsumowanie_kwartalne(
        p_rok     IN NUMBER,
        p_kwartal IN NUMBER
    );

    PROCEDURE generuj_podsumowanie_roczne(
        p_rok IN NUMBER
    );

    FUNCTION pobierz_oblozenie_oddzialu(
        p_id_oddzialu IN NUMBER,
        p_data_od     IN DATE,
        p_data_do     IN DATE
    ) RETURN SYS_REFCURSOR;

    FUNCTION pobierz_efektywnosc_lekarzy(
        p_id_oddzialu IN NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR;

    FUNCTION pobierz_strukture_rozpoznan(
        p_rok IN NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR;

END PKG_RAPORTY;
/

CREATE OR REPLACE PACKAGE BODY PKG_RAPORTY AS

    PROCEDURE generuj_podsumowanie_kwartalne(
        p_rok     IN NUMBER,
        p_kwartal IN NUMBER
    ) IS
    BEGIN
        IF p_kwartal NOT BETWEEN 1 AND 4 THEN
            RAISE_APPLICATION_ERROR(-20020, 'Numer kwartalu musi zawierac sie w przedziale od 1 do 4.');
        END IF;

        MERGE INTO PODSUMOWANIA_OKRESOWE dest
        USING (
            SELECT 'KWARTALNY' AS typ_okresu,
                   p_rok AS rok,
                   p_kwartal AS okres_nr,
                   p.id_oddzialu,
                   COUNT(*) AS liczba_pobytow,
                   ROUND(AVG(NVL(CAST(p.data_wypisu AS DATE), TRUNC(SYSDATE)) - CAST(p.data_przyjecia AS DATE)), 2) AS sr_czas_pobytu_dni,
                   SUM(p.koszt_leczenia) AS laczny_koszt
            FROM POBYTY p
            WHERE EXTRACT(YEAR FROM p.data_przyjecia) = p_rok
              AND TO_NUMBER(TO_CHAR(p.data_przyjecia, 'Q')) = p_kwartal
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

        PKG_LOGI.log_info('PKG_RAPORTY', 'Wygenerowano podsumowanie kwartalne: ' || p_rok || ' Q' || p_kwartal);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            PKG_LOGI.log_error('PKG_RAPORTY', 'Blad generowania podsumowania kwartalnego: ' || SQLERRM);
            ROLLBACK;
            RAISE;
    END generuj_podsumowanie_kwartalne;

    PROCEDURE generuj_podsumowanie_roczne(
        p_rok IN NUMBER
    ) IS
    BEGIN
        MERGE INTO PODSUMOWANIA_OKRESOWE dest
        USING (
            SELECT 'ROCZNY' AS typ_okresu,
                   p_rok AS rok,
                   1 AS okres_nr,
                   p.id_oddzialu,
                   COUNT(*) AS liczba_pobytow,
                   ROUND(AVG(NVL(CAST(p.data_wypisu AS DATE), TRUNC(SYSDATE)) - CAST(p.data_przyjecia AS DATE)), 2) AS sr_czas_pobytu_dni,
                   SUM(p.koszt_leczenia) AS laczny_koszt
            FROM POBYTY p
            WHERE EXTRACT(YEAR FROM p.data_przyjecia) = p_rok
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

        PKG_LOGI.log_info('PKG_RAPORTY', 'Wygenerowano podsumowanie roczne za rok ' || p_rok);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            PKG_LOGI.log_error('PKG_RAPORTY', 'Blad generowania podsumowania rocznego: ' || SQLERRM);
            ROLLBACK;
            RAISE;
    END generuj_podsumowanie_roczne;

    FUNCTION pobierz_oblozenie_oddzialu(
        p_id_oddzialu IN NUMBER,
        p_data_od     IN DATE,
        p_data_do     IN DATE
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT 
                TRUNC(p.data_przyjecia) AS data_dnia,
                COUNT(p.id_pobytu) AS liczba_przyjec,
                COUNT(CASE WHEN p.data_wypisu IS NOT NULL AND TRUNC(CAST(p.data_wypisu AS DATE)) <= p_data_do THEN 1 END) AS liczba_wypisow,
                SUM(p.koszt_leczenia) AS suma_kosztow,
                ROUND(AVG(p.koszt_leczenia), 2) AS sredni_koszt
            FROM POBYTY p
            WHERE p.id_oddzialu = p_id_oddzialu
              AND CAST(p.data_przyjecia AS DATE) BETWEEN p_data_od AND p_data_do
            GROUP BY TRUNC(p.data_przyjecia)
            ORDER BY data_dnia;

        RETURN v_cursor;
    END pobierz_oblozenie_oddzialu;

    FUNCTION pobierz_efektywnosc_lekarzy(
        p_id_oddzialu IN NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT 
                per.id_personelu,
                per.imie || ' ' || per.nazwisko AS lekarz,
                o.nazwa AS nazwa_oddzialu,
                COUNT(DISTINCT pob.id_pobytu) AS liczba_hospitalizacji,
                NVL(ROUND(AVG(CASE WHEN pob.data_wypisu IS NOT NULL THEN CAST(pob.data_wypisu AS DATE) - CAST(pob.data_przyjecia AS DATE) END), 2), 0) AS sr_czas_pobytu_dni,
                NVL(SUM(pob.koszt_leczenia), 0) AS laczny_koszt_leczenia,
                COUNT(wb.id_wyniku) AS liczba_zleconych_badan,
                COUNT(CASE WHEN wb.czy_w_normie = 'N' THEN 1 END) AS liczba_badan_poza_norma,
                CASE 
                    WHEN COUNT(wb.id_wyniku) > 0 THEN 
                        ROUND(COUNT(CASE WHEN wb.czy_w_normie = 'N' THEN 1 END) * 100.0 / COUNT(wb.id_wyniku), 2)
                    ELSE 0 
                END AS procent_badan_poza_norma
            FROM PERSONEL per
            JOIN ODDZIALY o ON per.id_oddzialu = o.id_oddzialu
            LEFT JOIN POBYTY pob ON per.id_personelu = pob.id_lekarza
            LEFT JOIN WYNIKI_BADAN wb ON pob.id_pobytu = wb.id_pobytu
            WHERE per.rola = 'LEKARZ'
              AND (p_id_oddzialu IS NULL OR per.id_oddzialu = p_id_oddzialu)
            GROUP BY per.id_personelu, per.imie, per.nazwisko, o.nazwa
            ORDER BY laczny_koszt_leczenia DESC;

        RETURN v_cursor;
    END pobierz_efektywnosc_lekarzy;

    FUNCTION pobierz_strukture_rozpoznan(
        p_rok IN NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT 
                p.kod_icd10,
                COUNT(*) AS liczba_przypadkow,
                ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS procent_wszystkich,
                ROUND(AVG(p.koszt_leczenia), 2) AS sredni_koszt_leczenia,
                DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS pozycja_w_rankingu
            FROM POBYTY p
            WHERE p.kod_icd10 IS NOT NULL
              AND (p_rok IS NULL OR EXTRACT(YEAR FROM p.data_przyjecia) = p_rok)
            GROUP BY p.kod_icd10
            ORDER BY liczba_przypadkow DESC;

        RETURN v_cursor;
    END pobierz_strukture_rozpoznan;

END PKG_RAPORTY;
/

CREATE OR REPLACE VIEW V_RAPORT_OBLOZENIE_ODDZIALOW AS
SELECT 
    o.id_oddzialu,
    o.nazwa AS nazwa_oddzialu,
    o.pietro,
    COUNT(p.id_pobytu) AS liczba_wszystkich_hospitalizacji,
    COUNT(CASE WHEN p.data_wypisu IS NULL THEN 1 END) AS pacjenci_obecnie_hospitalizowani,
    COUNT(CASE WHEN p.data_wypisu IS NOT NULL THEN 1 END) AS hospitalizacje_zakonczone,
    ROUND(AVG(CASE WHEN p.data_wypisu IS NOT NULL THEN CAST(p.data_wypisu AS DATE) - CAST(p.data_przyjecia AS DATE) END), 2) AS sr_czas_hospitalizacji_dni,
    NVL(SUM(p.koszt_leczenia), 0) AS laczne_przychody
FROM ODDZIALY o
LEFT JOIN POBYTY p ON o.id_oddzialu = p.id_oddzialu
GROUP BY o.id_oddzialu, o.nazwa, o.pietro;

CREATE OR REPLACE VIEW V_RAPORT_KOSZTY_MIESIECZNE AS
SELECT 
    EXTRACT(YEAR FROM p.data_przyjecia) AS rok,
    EXTRACT(MONTH FROM p.data_przyjecia) AS miesiac,
    TO_CHAR(p.data_przyjecia, 'YYYY-MM') AS rok_miesiac,
    o.nazwa AS nazwa_oddzialu,
    COUNT(p.id_pobytu) AS liczba_pacjentow,
    SUM(p.koszt_leczenia) AS laczny_koszt,
    ROUND(AVG(p.koszt_leczenia), 2) AS sredni_koszt_na_pacjenta,
    LAG(SUM(p.koszt_leczenia)) OVER (
        PARTITION BY o.id_oddzialu 
        ORDER BY EXTRACT(YEAR FROM p.data_przyjecia), EXTRACT(MONTH FROM p.data_przyjecia)
    ) AS koszt_poprzedni_miesiac,
    ROUND(
        SUM(p.koszt_leczenia) - LAG(SUM(p.koszt_leczenia)) OVER (
            PARTITION BY o.id_oddzialu 
            ORDER BY EXTRACT(YEAR FROM p.data_przyjecia), EXTRACT(MONTH FROM p.data_przyjecia)
        ), 2
    ) AS dynamika_kosztow_kwota
FROM POBYTY p
JOIN ODDZIALY o ON p.id_oddzialu = o.id_oddzialu
GROUP BY EXTRACT(YEAR FROM p.data_przyjecia), EXTRACT(MONTH FROM p.data_przyjecia), TO_CHAR(p.data_przyjecia, 'YYYY-MM'), o.id_oddzialu, o.nazwa;

CREATE OR REPLACE VIEW V_RAPORT_DIAGNOZY_ICD10 AS
SELECT 
    p.kod_icd10,
    COUNT(*) AS liczba_przypadkow,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS udzial_procentowy,
    ROUND(AVG(NVL(CAST(p.data_wypisu AS DATE), TRUNC(SYSDATE)) - CAST(p.data_przyjecia AS DATE)), 2) AS sr_czas_pobytu_dni,
    ROUND(AVG(p.koszt_leczenia), 2) AS sredni_koszt,
    SUM(p.koszt_leczenia) AS laczny_koszt,
    DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS pozycja_w_rankingu
FROM POBYTY p
WHERE p.kod_icd10 IS NOT NULL
GROUP BY p.kod_icd10;

CREATE OR REPLACE VIEW V_RAPORT_LABORATORIUM_ANOMALIE AS
SELECT 
    bs.kod_badania,
    bs.nazwa AS nazwa_badania,
    bs.jednostka,
    bs.norma_min,
    bs.norma_max,
    COUNT(wb.id_wyniku) AS liczba_wykonanych_badan,
    COUNT(CASE WHEN wb.czy_w_normie = 'T' THEN 1 END) AS wyniki_w_normie,
    COUNT(CASE WHEN wb.czy_w_normie = 'N' THEN 1 END) AS wyniki_poza_norma,
    ROUND(COUNT(CASE WHEN wb.czy_w_normie = 'N' THEN 1 END) * 100.0 / NULLIF(COUNT(wb.id_wyniku), 0), 2) AS procent_anomalii,
    MIN(wb.wartosc) AS wartosc_minimalna,
    ROUND(AVG(wb.wartosc), 2) AS wartosc_srednia,
    MAX(wb.wartosc) AS wartosc_maksymalna
FROM BADANIA_SLOWNIK bs
LEFT JOIN WYNIKI_BADAN wb ON bs.id_badania = wb.id_badania
GROUP BY bs.kod_badania, bs.nazwa, bs.jednostka, bs.norma_min, bs.norma_max;

BEGIN
    EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW MV_PODSUMOWANIE_ROCZNE';
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;
/

CREATE MATERIALIZED VIEW MV_PODSUMOWANIE_ROCZNE
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT 
    EXTRACT(YEAR FROM p.data_przyjecia) AS rok,
    o.id_oddzialu,
    o.nazwa AS nazwa_oddzialu,
    COUNT(DISTINCT p.id_pobytu) AS liczba_pobytow,
    ROUND(AVG(NVL(CAST(p.data_wypisu AS DATE), TRUNC(SYSDATE)) - CAST(p.data_przyjecia AS DATE)), 2) AS sr_czas_pobytu_dni,
    SUM(p.koszt_leczenia) AS laczny_koszt,
    COUNT(wb.id_wyniku) AS liczba_badan
FROM ODDZIALY o
LEFT JOIN POBYTY p ON o.id_oddzialu = p.id_oddzialu
LEFT JOIN WYNIKI_BADAN wb ON p.id_pobytu = wb.id_pobytu
GROUP BY EXTRACT(YEAR FROM p.data_przyjecia), o.id_oddzialu, o.nazwa;
