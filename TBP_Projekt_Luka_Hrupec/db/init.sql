CREATE TABLE zaposlenici (
    id SERIAL PRIMARY KEY,
    ime TEXT NOT NULL,
    prezime TEXT NOT NULL,
    satnica NUMERIC(10,2) NOT NULL CHECK (satnica > 0),
    aktivan BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE projekti (
    id SERIAL PRIMARY KEY,
    naziv TEXT NOT NULL,
    opis TEXT,
    datum_pocetka DATE NOT NULL,
    datum_zavrsetka DATE NOT NULL,
    status TEXT NOT NULL CHECK (
        status IN ('planiran', 'u_izradi', 'zavrsen')
    ),
    budzet_buffer NUMERIC(12,2) NOT NULL DEFAULT 0,
    CHECK (datum_zavrsetka >= datum_pocetka)
);

ALTER TABLE projekti
ADD COLUMN predvideni_broj_radnika INT NOT NULL CHECK (predvideni_broj_radnika > 0),
ADD COLUMN planirani_trosak NUMERIC(12,2);

CREATE TABLE clanovi_projekta (
    projekt_id INT NOT NULL REFERENCES projekti(id) ON DELETE CASCADE,
    zaposlenik_id INT NOT NULL REFERENCES zaposlenici(id) ON DELETE CASCADE,
    uloga TEXT NOT NULL CHECK (uloga IN ('voditelj', 'clan')),
    PRIMARY KEY (projekt_id, zaposlenik_id)
);

CREATE TABLE vrste_rada (
    id SERIAL PRIMARY KEY,
    naziv TEXT NOT NULL UNIQUE,
    koeficijent NUMERIC(4,2) NOT NULL CHECK (koeficijent > 0)
);

INSERT INTO vrste_rada (naziv, koeficijent) VALUES
('redovni', 1.0),
('prekovremeni', 1.5),
('nocni', 1.3);

CREATE TABLE radne_sesije (
    id SERIAL PRIMARY KEY,
    zaposlenik_id INT NOT NULL REFERENCES zaposlenici(id),
    projekt_id INT NOT NULL REFERENCES projekti(id),
    vrsta_rada_id INT NOT NULL REFERENCES vrste_rada(id),
    pocetak TIMESTAMP NOT NULL,
    kraj TIMESTAMP NOT NULL,
    trajanje_sati NUMERIC(6,2),
    trosak NUMERIC(12,2),
    CHECK (kraj > pocetak)
);


CREATE TABLE dodatni_troskovi (
    id SERIAL PRIMARY KEY,
    projekt_id INT NOT NULL REFERENCES projekti(id) ON DELETE CASCADE,
    opis TEXT NOT NULL,
    iznos NUMERIC(12,2) NOT NULL CHECK (iznos > 0),
    datum DATE NOT NULL DEFAULT CURRENT_DATE
);

-- Zaposlenik
INSERT INTO zaposlenici (ime, prezime, satnica) VALUES
('Ivan', 'Horvat', 10.00),
('Ana', 'Kovač', 11.50),
('Marko', 'Babić', 12.00),
('Petra', 'Novak', 10.50),
('Luka', 'Marić', 13.00);


SELECT
    p.id AS projekt_id,
    p.naziv AS projekt,
    SUM(rs.trosak) AS ukupni_trosak_rada
FROM projekti p
LEFT JOIN radne_sesije rs ON rs.projekt_id = p.id
GROUP BY p.id, p.naziv
ORDER BY ukupni_trosak_rada DESC;

SELECT
    p.id AS projekt_id,
    p.naziv AS projekt,
    SUM(dt.iznos) AS dodatni_troskovi
FROM projekti p
LEFT JOIN dodatni_troskovi dt ON dt.projekt_id = p.id
GROUP BY p.id, p.naziv;

SELECT
    p.id AS projekt_id,
    p.naziv AS projekt,
    COALESCE(SUM(rs.trosak), 0) +
    COALESCE(SUM(dt.iznos), 0) AS ukupni_stvarni_trosak
FROM projekti p
LEFT JOIN radne_sesije rs ON rs.projekt_id = p.id
LEFT JOIN dodatni_troskovi dt ON dt.projekt_id = p.id
GROUP BY p.id, p.naziv;

SELECT
    p.id AS projekt_id,
    p.naziv AS projekt,
    ROUND(
        COUNT(cp.zaposlenik_id) *
        (p.datum_zavrsetka - p.datum_pocetka + 1) *
        8 *
        AVG(z.satnica),
        2
    ) AS planirani_trosak
FROM projekti p
JOIN clanovi_projekta cp ON cp.projekt_id = p.id
JOIN zaposlenici z ON z.id = cp.zaposlenik_id
GROUP BY
    p.id,
    p.naziv,
    p.datum_pocetka,
    p.datum_zavrsetka;

SELECT
    p.naziv AS projekt,
    p.budzet_buffer,

    ROUND(
        COUNT(cp.zaposlenik_id) *
        (p.datum_zavrsetka - p.datum_pocetka + 1) *
        8 *
        AVG(z.satnica),
        2
    ) AS planirani_trosak,

    ROUND(
        COALESCE(SUM(rs.trosak), 0) +
        COALESCE(SUM(dt.iznos), 0),
        2
    ) AS stvarni_trosak,

    ROUND(
        (
            COUNT(cp.zaposlenik_id) *
            (p.datum_zavrsetka - p.datum_pocetka + 1) *
            8 *
            AVG(z.satnica)
            + p.budzet_buffer
        )
        -
        (
            COALESCE(SUM(rs.trosak), 0) +
            COALESCE(SUM(dt.iznos), 0)
        ),
        2
    ) AS preostali_budzet
FROM projekti p
JOIN clanovi_projekta cp ON cp.projekt_id = p.id
JOIN zaposlenici z ON z.id = cp.zaposlenik_id
LEFT JOIN radne_sesije rs ON rs.projekt_id = p.id
LEFT JOIN dodatni_troskovi dt ON dt.projekt_id = p.id
GROUP BY
    p.id,
    p.naziv,
    p.budzet_buffer,
    p.datum_pocetka,
    p.datum_zavrsetka;


SELECT
    z.ime,
    z.prezime,
    SUM(rs.trosak) AS ukupni_trosak
FROM zaposlenici z
JOIN radne_sesije rs ON rs.zaposlenik_id = z.id
GROUP BY z.id, z.ime, z.prezime
ORDER BY ukupni_trosak DESC;

SELECT
    vr.naziv AS vrsta_rada,
    SUM(rs.trajanje_sati) AS ukupno_sati,
    SUM(rs.trosak) AS ukupni_trosak
FROM vrste_rada vr
JOIN radne_sesije rs ON rs.vrsta_rada_id = vr.id
GROUP BY vr.naziv;

CREATE OR REPLACE VIEW v_financijski_pregled_projekta AS
SELECT
    p.id AS projekt_id,
    p.naziv AS naziv_projekta,
    p.budzet_buffer,
    p.planirani_trosak,

    -- da HTML r[4] bude "Dodatni troškovi"
    ROUND(COALESCE(d.ukupni_dodatni_troskovi, 0), 2) AS dodatni_troskovi,

    -- da HTML r[5] bude "Stvarni trošak" (rad + dodatni)
    ROUND(
        COALESCE(r.ukupni_trosak_rada, 0) +
        COALESCE(d.ukupni_dodatni_troskovi, 0),
        2
    ) AS stvarni_trosak,

    -- da HTML r[6] bude "Preostali budžet"
    ROUND(
        COALESCE(p.planirani_trosak, 0) + p.budzet_buffer
        -
        (
            COALESCE(r.ukupni_trosak_rada, 0) +
            COALESCE(d.ukupni_dodatni_troskovi, 0)
        ),
        2
    ) AS preostali_budzet
FROM projekti p
LEFT JOIN (
    SELECT projekt_id, SUM(COALESCE(trosak, 0)) AS ukupni_trosak_rada
    FROM radne_sesije
    GROUP BY projekt_id
) r ON r.projekt_id = p.id
LEFT JOIN (
    SELECT projekt_id, SUM(COALESCE(iznos, 0)) AS ukupni_dodatni_troskovi
    FROM dodatni_troskovi
    GROUP BY projekt_id
) d ON d.projekt_id = p.id;




CREATE VIEW v_trosak_rada_po_projektu AS
SELECT
    p.id AS projekt_id,
    p.naziv AS naziv_projekta,
    ROUND(
        COALESCE(r.ukupni_trosak_rada, 0) +
        COALESCE(d.ukupni_dodatni_troskovi, 0),
        2
    ) AS trosak_rada
FROM projekti p
LEFT JOIN (
    SELECT projekt_id, SUM(trosak) AS ukupni_trosak_rada
    FROM radne_sesije
    GROUP BY projekt_id
) r ON r.projekt_id = p.id
LEFT JOIN (
    SELECT projekt_id, SUM(iznos) AS ukupni_dodatni_troskovi
    FROM dodatni_troskovi
    GROUP BY projekt_id
) d ON d.projekt_id = p.id;


CREATE OR REPLACE VIEW v_trosak_po_zaposleniku AS
SELECT
    z.id AS zaposlenik_id,
    z.ime,
    z.prezime,
    ROUND(COALESCE(SUM(rs.trajanje_sati), 0), 2) AS ukupno_sati,
    ROUND(COALESCE(SUM(COALESCE(rs.trosak, 0)), 0), 2) AS ukupni_trosak
FROM zaposlenici z
LEFT JOIN radne_sesije rs
    ON rs.zaposlenik_id = z.id
GROUP BY z.id, z.ime, z.prezime;


CREATE OR REPLACE FUNCTION zabrani_rad_za_zavrsen_projekt()
RETURNS TRIGGER AS $$
DECLARE
    v_status TEXT;
BEGIN
    SELECT status INTO v_status
    FROM projekti
    WHERE id = NEW.projekt_id;

    IF v_status = 'zavrsen' THEN
        RAISE EXCEPTION 'Nije dopušten unos rada za završen projekt.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_zabrani_rad_za_zavrsen_projekt
BEFORE INSERT ON radne_sesije
FOR EACH ROW
EXECUTE FUNCTION zabrani_rad_za_zavrsen_projekt();

CREATE OR REPLACE PROCEDURE promijeni_status_projekta(
    p_projekt_id INT,
    p_novi_status TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE projekti
    SET status = p_novi_status
    WHERE id = p_projekt_id;
END;
$$;

CREATE OR REPLACE FUNCTION izracunaj_trosak_radne_sesije()
RETURNS TRIGGER AS $$
DECLARE
    v_satnica NUMERIC;
    v_koeficijent NUMERIC;
    v_radni_dani INT;
    v_datum_pocetka DATE;
    v_datum_zavrsetka DATE;
BEGIN
    -- Satnica zaposlenika
    SELECT satnica INTO v_satnica
    FROM zaposlenici
    WHERE id = NEW.zaposlenik_id;

    -- Koeficijent vrste rada
    SELECT koeficijent INTO v_koeficijent
    FROM vrste_rada
    WHERE id = NEW.vrsta_rada_id;

    -- Datumi projekta
    SELECT datum_pocetka, datum_zavrsetka
    INTO v_datum_pocetka, v_datum_zavrsetka
    FROM projekti
    WHERE id = NEW.projekt_id;

    -- REDOVNI RAD = CIJELI PROJEKT
    IF NEW.vrsta_rada_id = (
        SELECT id FROM vrste_rada WHERE naziv = 'redovni'
    ) THEN
        NEW.pocetak := v_datum_pocetka;
        NEW.kraj := v_datum_zavrsetka;
    END IF;

    -- Broj radnih dana (pon–pet)
    v_radni_dani := izracunaj_radne_dane(
        NEW.pocetak::date,
        NEW.kraj::date
    );

    -- 8 sati po radnom danu
    NEW.trajanje_sati := v_radni_dani * 8;

    -- Trošak
    NEW.trosak := NEW.trajanje_sati * v_satnica * v_koeficijent;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_izracunaj_trosak
BEFORE INSERT ON radne_sesije
FOR EACH ROW
EXECUTE FUNCTION izracunaj_trosak_radne_sesije();


CREATE OR REPLACE FUNCTION dodaj_clana_projekta_ako_ne_postoji()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO clanovi_projekta (projekt_id, zaposlenik_id, uloga)
    VALUES (NEW.projekt_id, NEW.zaposlenik_id, 'clan')
    ON CONFLICT (projekt_id, zaposlenik_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_dodaj_clana_projekta
BEFORE INSERT ON radne_sesije
FOR EACH ROW
EXECUTE FUNCTION dodaj_clana_projekta_ako_ne_postoji();


CREATE OR REPLACE FUNCTION izracunaj_radne_dane(
    p_pocetak DATE,
    p_kraj DATE
)
RETURNS INT AS $$
DECLARE
    d DATE;
    cnt INT := 0;
BEGIN
    d := p_pocetak;
    WHILE d <= p_kraj LOOP
        IF EXTRACT(ISODOW FROM d) < 6 THEN
            cnt := cnt + 1;
        END IF;
        d := d + INTERVAL '1 day';
    END LOOP;

    RETURN cnt;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION izracunaj_planirani_trosak(
    p_datum_pocetka DATE,
    p_datum_zavrsetka DATE,
    p_broj_radnika INT
)
RETURNS NUMERIC AS $$
DECLARE
    radni_dani INT;
    prosjecna_satnica NUMERIC;
BEGIN
    radni_dani := izracunaj_radne_dane(p_datum_pocetka, p_datum_zavrsetka);

    SELECT AVG(satnica)
    INTO prosjecna_satnica
    FROM zaposlenici;

    IF prosjecna_satnica IS NULL THEN
        prosjecna_satnica := 0;
    END IF;

    RETURN radni_dani * 8 * p_broj_radnika * prosjecna_satnica;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION trg_izracunaj_planirani_trosak()
RETURNS TRIGGER AS $$
BEGIN
    NEW.planirani_trosak :=
        izracunaj_planirani_trosak(
            NEW.datum_pocetka,
            NEW.datum_zavrsetka,
            NEW.predvideni_broj_radnika
        );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_izracunaj_planirani_trosak
BEFORE INSERT ON projekti
FOR EACH ROW
EXECUTE FUNCTION trg_izracunaj_planirani_trosak();


CREATE DOMAIN status_projekta_domain TEXT
CHECK (VALUE IN ('planiran', 'u_izradi', 'zavrsen'));

ALTER TABLE projekti
ALTER COLUMN status
TYPE status_projekta_domain;

