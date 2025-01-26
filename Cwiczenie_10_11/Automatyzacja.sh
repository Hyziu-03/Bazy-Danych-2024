#!/bin/bash

# Sparametryzowanie nazwy logu
LOG="Automatyzacja.log"

# Utworzenie pliku z logami
touch "$LOG"

# Sparametryzowanie daty wykonania skryptu
TIMESTAMP=$(date +%m%d%Y)

# Sparametryzowanie adresu URL pobranego pliku
URL=https://home.agh.edu.pl/~wsarlej/Customers_Nov2024.zip

# Pobranie pliku z internetu
echo "$TIMESTAMP" - "Pobieranie pliku z internetu" >> "$LOG"
wget "$URL" || echo "$TIMESTAMP" - "Wystąpił błąd przy pobieraniu pliku z internetu" >> "$LOG"

# Sparametryzowanie nazwy pobranego archiwum
FILENAME=$(basename "$URL")

# Rozpakowanie archiwum
echo "$TIMESTAMP" - "Rozpakowanie archiwum" >> "$LOG"
unzip "$FILENAME" || echo "$TIMESTAMP" - "Wystąpił błąd przy rozpakowaniu archiwum" >> "$LOG"

# Usunięcie archiwum
echo "$TIMESTAMP" - "Usunięcie archiwum" >> "$LOG"
rm "$FILENAME" || echo "$TIMESTAMP" - "Wystąpił błąd przy usuwaniu archiwum" >> "$LOG"

# Sparametryzowanie nazwy pobranego pliku
FILEPATH=$(echo "$FILENAME" | cut -d "." -f 1).csv

# Uzyskanie liczby wierszy w pliku pobranym z internetu
NROWS=$(cat "$FILEPATH" | wc -l)

# Sparametryzowanie nazwy pliku bez rozszerzenia
BARE=$(echo "$FILENAME" | cut -d "." -f 1)

# Utworzenie pliku z błędnymi wierszami
touch $BARE.bad_"$TIMESTAMP"

# Sparametryzowanie poprawnej liczby kolumn
NCOL=$(cat "$FILEPATH" | head -n 1 | tr -cd "," | wc -c)

# Zignorowanie pustych linii, deduplikacja, usunięcie kolumn bez wartości
echo "$TIMESTAMP" - "Walidacja pliku" >> "$LOG"
echo $(cat "$FILEPATH" | tail -n +2 | sort | uniq | grep -v ",,") > "$FILEPATH" || echo "$TIMESTAMP" - "Wystąłpił błąd przy walidacji" >> "$LOG"

# Sparametryzowanie adresu starego pliku
OLDURL=https://home.agh.edu.pl/~wsarlej/Customers_old.csv

# Pobranie starego pliku
echo "$TIMESTAMP" - "Pobranie starego pliku" >> "$LOG"
wget "$OLDURL" || echo "$TIMESTAMP" - "Wystąpił błąd przy pobraniu starego pliku" >> "$LOG"

# Sparametryzowanie nazwy starego pliku
OLDFILE=$(basename "$OLDURL")

# Porównanie starego pliku ze zwalidowanym
echo "$TIMESTAMP" - "Porównanie starego pliku ze zwalidowanym" >> "$LOG"
sdiff "$FILEPATH" "$OLDFILE" || echo "$TIMESTAMP" - "Wystąpił błąd przy porównaniu starego pliku ze zwalidowanym" >> "$LOG"

# Debugowanie zawartości pliku
# cat "$FILEPATH"

# Sparametryzowanie numeru indeksu
INDEX=416832

# Sparametryzowanie nazwy tabeli
TABLE_NAME=CUSTOMERS_"$INDEX"

# Sparametryzowanie nazwy użytkownika
DB_OWNER="postgres"

# Sparametryzowanie hasła do bazy danych
export PGPASSWORD=[postgres]

# Utworzenie tabeli w bazie danych PostgreSQL
echo "$TIMESTAMP" - "Utworzenie tabeli w PostgreSQL" >> "$LOG"
psql -U "$DB_OWNER" -d postgres -c "drop table if exists ${TABLE_NAME,,};
create table if not exists ${TABLE_NAME,,} (first_name text, last_name text, email text, lat numeric, lon numeric);" || echo "$TIMESTAMP" - "Wystąpił błąd przy tworzeniu tabeli w PostgreSQL" >> "$LOG"

# Załadowanie danych do tabeli
echo "$TIMESTAMP" - "Załadowanie danych do tabeli PostgreSQL" >> "$LOG"
psql -h 127.0.01 -U postgres -d postgres -c "\copy ${TABLE_NAME,,}
(first_name, last_name, email, lat, lon) from ${FILEPATH} with csv header;" || echo "$TIMESTAMP" - "Wystąpił błąd przy załadowaniu danych do tabeli w PostgreSQL" >> "$LOG"

# Utworzenie folderu na plik wynikowy
echo "$TIMESTAMP" - "Utworzenie folderu na plik wynikowy" >> "$LOG"
mkdir PROCESSED || echo "$TIMESTAMP" - "Wystąpił błąd przy utworzeniu folderu na plik wynikowy" >> "$LOG"

# Sparametryzowanie docelowej lokalizacji pliku wynikowego
PROCESSED_FILENAME="PROCESSED"/"$TIMESTAMP"_"$FILEPATH"

# Przeniesienie przetworzonego pliku z prefiksem
echo "$TIMESTAMP" - "Przeniesienie przetworzonego pliku" >> "$LOG"
mv "$FILEPATH" "$PROCESSED_FILENAME" || echo "$TIMESTAMP" - "Wystąpił błąd przy przenoszeniu przetworzonego pliku" >> "$LOG"

# Zliczenie liczby poprawnych wierszy po czyszczeniu`
PROCESSED_NROWS=$(cat "$PROCESSED_FILENAME" | wc -l)

# Sparametryzowanie nazwy pliku z raportem
REPORTPATH="CUSTOMERS LOAD - ${TIMESTAMP}.dat"

# Utworzenie pliku z raportem
echo "$TIMESTAMP" - "Utworzenie pliku z raportem" >> "$LOG"
touch "$REPORTPATH" || echo "$TIMESTAMP" - "Wystąpił błąd przy utworzeniu pliku z raportem"

# Zapisywanie danych do raportu
echo "$TIMESTAMP" - "Zapisywanie danych do raportu" >> "$LOG"
echo "Liczba wierszy w pliku pobranym z internetu: ${NROWS}" >> "$REPORTPATH" || echo "$TIMESTAMP" - "Wystąpił błąd przy zapisywaniu danych do rapotu" >> "$LOG"
echo "Liczba poprawnych wierszy po czyszczeniu: ${PROCESSED_NROWS}" >> "$REPORTPATH" || echo "$TIMESTAMP" - "Wystąpił błąd przy zapisywaniu danych do raportu" >> "$LOG"
