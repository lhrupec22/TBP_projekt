from flask import Flask, render_template
import psycopg2
from flask import Flask, render_template, request, redirect, url_for
from datetime import date


app = Flask(__name__)

def get_db_connection():
    return psycopg2.connect(
        host="localhost",
        port=5434, 
        database="TBP_projekt",   
        user="postgres",
        password="postgres"    
    )

@app.route("/")
def projekti():
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("SELECT id, naziv, datum_pocetka, datum_zavrsetka, status FROM projekti ORDER BY id;")
    projekti = cur.fetchall()

    cur.close()
    conn.close()

    return render_template("projekti.html", projekti=projekti)
#--------------------------------------------------------------------------
@app.route("/promijeni_status", methods=["POST"])
def promijeni_status():
    projekt_id = request.form["projekt_id"]
    novi_status = request.form["novi_status"]

    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute(
        "CALL promijeni_status_projekta(%s, %s);",
        (projekt_id, novi_status)
    )

    conn.commit()
    cur.close()
    conn.close()

    return redirect(url_for("projekti"))
#--------------------------------------------------------------------------
@app.route("/dodaj_projekt", methods=["POST"])
def dodaj_projekt():
    naziv = request.form["naziv"]
    datum_pocetka = request.form["datum_pocetka"]
    datum_zavrsetka = request.form["datum_zavrsetka"]
    predvideni_broj_radnika = request.form["predvideni_broj_radnika"]
    status = request.form["status"]
    budzet_buffer = request.form["budzet_buffer"]

    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO projekti
        (naziv, datum_pocetka, datum_zavrsetka, predvideni_broj_radnika, status, budzet_buffer)
        VALUES (%s, %s, %s, %s, %s, %s)
    """, (naziv, datum_pocetka, datum_zavrsetka, predvideni_broj_radnika, status, budzet_buffer))

    conn.commit()
    cur.close()
    conn.close()

    return redirect(url_for("projekti"))
#--------------------------------------------------------------------------
@app.route("/radne_sesije")
def radne_sesije():
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("SELECT id, ime, prezime FROM zaposlenici;")
    zaposlenici = cur.fetchall()

    cur.execute("SELECT id, naziv FROM projekti;")
    projekti = cur.fetchall()

    cur.execute("SELECT id, naziv FROM vrste_rada;")
    vrste_rada = cur.fetchall()

    cur.execute("""
        SELECT
            z.ime || ' ' || z.prezime,
            p.naziv,
            vr.naziv,
            rs.trajanje_sati,
            rs.trosak
        FROM radne_sesije rs
        JOIN zaposlenici z ON z.id = rs.zaposlenik_id
        JOIN projekti p ON p.id = rs.projekt_id
        JOIN vrste_rada vr ON vr.id = rs.vrsta_rada_id
        ORDER BY rs.id DESC;
    """)
    radne_sesije = cur.fetchall()

    cur.close()
    conn.close()

    return render_template(
        "radne_sesije.html",
        zaposlenici=zaposlenici,
        projekti=projekti,
        vrste_rada=vrste_rada,
        radne_sesije=radne_sesije
    )
#--------------------------------------------------------------------------
@app.route("/dodaj_radnu_sesiju", methods=["POST"])
def dodaj_radnu_sesiju():
    zaposlenik_id = request.form["zaposlenik_id"]
    projekt_id = request.form["projekt_id"]
    vrsta_rada_id = request.form["vrsta_rada_id"]
    pocetak = request.form["pocetak"]
    kraj = request.form["kraj"]

    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO radne_sesije
        (zaposlenik_id, projekt_id, vrsta_rada_id, pocetak, kraj)
        VALUES (%s, %s, %s, %s, %s)
    """, (zaposlenik_id, projekt_id, vrsta_rada_id, pocetak, kraj))

    conn.commit()
    cur.close()
    conn.close()

    return redirect(url_for("radne_sesije"))
#--------------------------------------------------------------------------
@app.route("/api/projekt_datumi/<int:projekt_id>")
def projekt_datumi(projekt_id):
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        SELECT datum_pocetka, datum_zavrsetka
        FROM projekti
        WHERE id = %s
    """, (projekt_id,))

    row = cur.fetchone()
    cur.close()
    conn.close()

    if row is None:
        return {"error": "Projekt ne postoji"}, 404

    datum_pocetka, datum_zavrsetka = row

    danas = date.today()

    if danas < datum_pocetka:
        pocetak = datum_pocetka
    else:
        pocetak = danas

    return {
        "pocetak": pocetak.isoformat(),
        "kraj": datum_zavrsetka.isoformat()
    }
#--------------------------------------------------------------------------
@app.route("/izvjestaji")
def izvjestaji():
    conn = get_db_connection()
    cur = conn.cursor()

    # Financijski pregled projekata
    cur.execute("""
        SELECT *
        FROM v_financijski_pregled_projekta
        ORDER BY naziv_projekta;
    """)
    financijski_pregled = cur.fetchall()

    # Trošak po zaposleniku
    cur.execute("""
        SELECT *
        FROM v_trosak_po_zaposleniku
        ORDER BY zaposlenik_id;
    """)
    trosak_po_zaposleniku = cur.fetchall()

    # Trošak rada po projektu
    cur.execute("""
        SELECT *
        FROM v_trosak_rada_po_projektu
        ORDER BY naziv_projekta;
    """)
    trosak_po_projektu = cur.fetchall()

    cur.close()
    conn.close()

    return render_template(
        "izvjestaji.html",
        financijski_pregled=financijski_pregled,
        trosak_po_zaposleniku=trosak_po_zaposleniku,
        trosak_po_projektu=trosak_po_projektu
    )
#--------------------------------------------------------------------------
@app.route("/dodaj_dodatni_trosak", methods=["POST"])
def dodaj_dodatni_trosak():
    projekt_id = request.form["projekt_id"]
    opis = request.form["opis"]
    iznos = request.form["iznos"]

    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO dodatni_troskovi (projekt_id, opis, iznos, datum)
        VALUES (%s, %s, %s, CURRENT_DATE)
    """, (projekt_id, opis, iznos))

    conn.commit()
    cur.close()
    conn.close()

    return redirect(url_for("projekti"))
#--------------------------------------------------------------------------
if __name__ == "__main__":
    app.run(debug=True)
