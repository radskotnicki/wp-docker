# Lokalna kopia WordPressa - Instrukcja

## Co potrzebujesz z serwera produkcyjnego

| Element | Ścieżka na serwerze | Gdzie wrzucić lokalnie |
|---------|---------------------|------------------------|
| **Baza danych** | export z phpMyAdmin lub WP-CLI | `data/dump.sql` |
| **wp-content/** | `/var/www/html/wp-content/` | `data/wp-content/` |

### Szczegóły wp-content

```
wp-content/
├── themes/          # WYMAGANE - motywy (w tym aktywny)
├── plugins/         # WYMAGANE - wszystkie wtyczki
├── uploads/         # WYMAGANE - media (zdjęcia, pliki)
├── languages/       # opcjonalne - tłumaczenia
├── cache/           # POMIŃ - zostanie wygenerowany
├── upgrade/         # POMIŃ - pliki tymczasowe
└── *-cache/         # POMIŃ - cache wtyczek
```

**Nie kopiuj:** `cache/`, `upgrade/`, `w3tc-config/`, `wp-rocket-config/` i podobnych folderów cache.

---

## Krok po kroku

### 1. Przygotuj środowisko lokalne

```bash
cp .env.example .env
# Edytuj .env - ustaw hasła i port (np. 8080)
```

### 2. Eksportuj bazę danych z serwera

**Opcja A: phpMyAdmin**
1. Zaloguj się do phpMyAdmin na serwerze
2. Wybierz bazę WordPressa
3. Zakładka "Eksport" → Format: SQL → Wykonaj
4. Zapisz plik jako `data/dump.sql`

**Opcja B: WP-CLI (jeśli dostępne na serwerze)**
```bash
# Na serwerze:
cd /var/www/html
wp db export dump.sql

# Pobierz na lokalny komputer:
scp user@server:/var/www/html/dump.sql ./data/dump.sql
```

**Opcja C: mysqldump przez SSH**
```bash
ssh user@server "mysqldump -u DB_USER -p DB_NAME" > data/dump.sql
```

### 3. Skopiuj wp-content z serwera

**Opcja A: rsync (zalecane)**
```bash
rsync -avz --exclude='cache' --exclude='upgrade' \
    user@server:/var/www/html/wp-content/ ./data/wp-content/
```

**Opcja B: Ręcznie przez FTP/SFTP**
1. Połącz się z serwerem przez FileZilla/Cyberduck
2. Pobierz cały folder `wp-content/` do `data/wp-content/`
3. Możesz pominąć foldery `cache/` i `upgrade/`

**Opcja C: Archiwum ZIP**
```bash
# Na serwerze:
cd /var/www/html
zip -r wp-content.zip wp-content -x "wp-content/cache/*" -x "wp-content/upgrade/*"

# Pobierz i rozpakuj lokalnie:
scp user@server:/var/www/html/wp-content.zip .
unzip wp-content.zip -d data/
```

### 4. Uruchom kontenery

```bash
make up
# Poczekaj ~30 sekund na inicjalizację bazy
```

### 5. Zaimportuj bazę danych

```bash
make import-db
```

### 6. Zamień URLe produkcyjne na lokalne

```bash
make replace-urls OLD=https://twoja-strona.pl
# NEW domyślnie = http://localhost:8080 (z .env)
```

### 7. Gotowe!

Otwórz w przeglądarce: http://localhost:8080

---

## Rozwiązywanie problemów

### Biały ekran / błąd połączenia z bazą
```bash
make logs
# Sprawdź czy kontener db jest healthy
docker compose ps
```

### Brakujące style / zdjęcia
- Upewnij się, że `data/wp-content/` zawiera `themes/`, `plugins/`, `uploads/`
- Sprawdź uprawnienia: `chmod -R 755 data/wp-content`

### Błąd "Too many redirects"
Sprawdź czy URLe zostały zamienione:
```bash
make wp -- option get siteurl
make wp -- option get home
# Powinny pokazać http://localhost:8080
```

### Logowanie do wp-admin nie działa
```bash
# Zresetuj hasło użytkownika admin:
make wp -- user update admin --user_pass=nowehaslo
```

---

## Automatyczne pobieranie z serwera

Jeśli masz SSH i WP-CLI na serwerze:

```bash
# Pobierz wszystko jedną komendą:
make pull SERVER=user@server PATH=/var/www/html

# Potem zamień URLe:
make replace-urls OLD=https://twoja-strona.pl
```

---

## WP-CLI

Środowisko ma wbudowane WP-CLI. Wszystkie komendy uruchamiasz przez `make wp`:

```bash
# Ogólna składnia:
make wp -- <komenda>
```

### Przydatne komendy

```bash
# Informacje o WordPressie
make wp -- core version              # wersja WordPressa
make wp -- option get siteurl        # aktualny URL strony

# Zarządzanie wtyczkami
make wp -- plugin list               # lista wtyczek
make wp -- plugin activate nazwa     # aktywuj wtyczkę
make wp -- plugin deactivate nazwa   # dezaktywuj wtyczkę

# Zarządzanie użytkownikami
make wp -- user list                 # lista użytkowników
make wp -- user update admin --user_pass=nowehaslo  # reset hasła

# Baza danych
make wp -- db export - > data/backup.sql   # eksport bazy
make wp -- cache flush                     # wyczyść cache

# Wyszukaj i zamień
make wp -- search-replace "stary-tekst" "nowy-tekst" --all-tables
```

### Przykład: reset hasła admina

```bash
make wp -- user update admin --user_pass=mojhaslo123
```

---

## Composer

Środowisko ma wbudowany Composer (menedżer zależności PHP). Wszystkie komendy uruchamiasz przez `make composer`:

```bash
# Ogólna składnia:
make composer -- <komenda>
```

### Użycie z composer.json w podkatalogu

Jeśli `composer.json` znajduje się w motywie lub wtyczce, użyj `--working-dir`:

```bash
# Instalacja zależności motywu:
make composer -- install --working-dir=/var/www/html/wp-content/themes/nazwa-motywu

# Instalacja zależności wtyczki:
make composer -- install --working-dir=/var/www/html/wp-content/plugins/nazwa-wtyczki
```

### Zarządzanie pakietami WordPress przez WPackagist

Możesz używać [WPackagist](https://wpackagist.org/) do instalacji wtyczek i motywów:

```bash
# Zainstaluj wtyczkę
make composer -- require wpackagist-plugin/advanced-custom-fields

# Zainstaluj motyw
make composer -- require wpackagist-theme/flavor

# Aktualizuj zależności
make composer -- update
```

### Przydatne komendy

```bash
make composer -- install            # zainstaluj zależności z composer.lock
make composer -- update             # aktualizuj zależności
make composer -- dump-autoload      # przebuduj autoloader
make composer -- show               # pokaż zainstalowane pakiety
make composer -- --version          # sprawdź wersję Composera
```

---

## Wersja PHP

Domyślna wersja PHP to **8.2**. Aby zmienić wersję, edytuj `.env`:

```bash
PHP_VERSION=8.3
```

Dostępne wersje: `8.0`, `8.1`, `8.2`, `8.3`, `8.4`

Po zmianie przebuduj obraz i zrestartuj kontenery:

```bash
make build
make down && make up
```

---

## Struktura po konfiguracji

```
wp-docker/
├── .env                 # twoja konfiguracja (hasła, port)
├── data/
│   ├── dump.sql         # zrzut bazy (po imporcie można usunąć)
│   └── wp-content/      # themes, plugins, uploads
├── docker-compose.yml
└── Makefile
```
