#!/bin/bash

echo "=== Instalacija aplikacije ==="

DB_NAME="TBP_projekt"
DB_USER="postgres"

echo "1) Kreiranje baze podataka..."
psql -U $DB_USER -tc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 || \
psql -U $DB_USER -c "CREATE DATABASE $DB_NAME;"

echo "2) Inicijalizacija baze (tablice, triggeri, view-ovi)..."
psql -U $DB_USER -d $DB_NAME -f db/init.sql

echo "3) Instalacija Python ovisnosti..."
pip install -r app/requirements.txt

echo "=== Instalacija završena ==="
echo "Pokretanje aplikacije: python app/app.py"
