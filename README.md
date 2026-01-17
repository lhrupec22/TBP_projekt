# Projekt iz kolegija Teorija baza podataka
Ovaj repozitorij sadrži implementaciju aplikacije za praćenje radnih sesija zaposlenika, upravljanje projektima te izračun i analizu troškova rada kroz vrijeme. Sustav je razvijen u sklopu projektnog zadatka iz kolegija Teorija baza podataka s ciljem demonstracije primjene temporalnih i aktivnih baza podataka u stvarnom poslovnom scenariju.

Aplikacija za skidanje i pokretanje rada se nalazi u TBP_projekt_Luka_Hrupec, unutra se nalaze i upute za pokretanje iste.

Središnji dio sustava čini relacijska baza podataka PostgreSQL, u kojoj su implementirana poslovna pravila, izračuni i ograničenja korištenjem funkcija, okidača (triggera), pogleda (viewova) i domenskih ograničenja. Poseban naglasak stavljen je na to da se ključna poslovna logika ne nalazi u aplikacijskom sloju, već izravno u bazi podataka, čime se osigurava konzistentnost podataka i neovisnost o korisničkom sučelju.

Aplikacijski dio izrađen je pomoću Python Flask okvira te služi kao prezentacijski sloj koji omogućuje korisniku unos projekata, evidenciju radnih sesija, dodavanje dodatnih troškova i pregled različitih izvještaja. Izvještaji se temelje na unaprijed definiranim SQL pogledima u bazi podataka, koji agregiraju i obrađuju podatke o troškovima rada, dodatnim troškovima, zaposlenicima i projektima.

Sustav podržava različite vrste rada (redovni, prekovremeni, noćni) s pripadajućim koeficijentima, automatski izračun trajanja rada na temelju radnih dana te zabranu unosa rada za završene projekte. Također, članstvo zaposlenika na projektima upravlja se automatski na temelju evidentiranih radnih sesija, čime se dodatno pojednostavljuje korištenje aplikacije.

Inicijalna SQL skripta (init.sql) služi za potpunu inicijalizaciju sustava – kreiranje tablica, funkcija, okidača i osnovnih šifrarnika – dok se stvarni poslovni podaci unose kroz aplikaciju. Time je omogućena jasna demonstracija funkcionalnosti sustava i ispravnosti implementirane poslovne logike.

Prilikom rada koristila se i umjetna inteligiencija ChatGPT kao promoći pri izradi rada. Linkovi na razgovore mogu se naći u nastavku: https://chatgpt.com/g/g-p-69394bd48f9c81918081baa52d46b6e8-baze/project 
