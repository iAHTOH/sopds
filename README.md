# Simple OPDS Home Library

**Version 0.47-devel** | [Инструкция на русском](README_RUS.md)

OPDS catalog for home e-book collection with web interface, Telegram bot, and online reader.

---

## Features

- **Book formats**: FB2, EPUB, MOBI, PDF, DJVU, DOC, TXT, RTF
- **FB2 conversion** to EPUB, EPUB3, KEPUB (Kobo), AZW8/MOBI (Kindle), KFX (Kindle), PDF, TXT, Markdown — powered by **fb2cng** (Go binary, zero dependencies)
- **Online reader**: paginated FB2 book reading in browser, page navigation, font size control
- **OPDS catalog**: compatible with any OPDS client (FBReader, Moon+ Reader, Librera, etc.)
- **Web interface**: search by title/author/series/genre, bookshelf, covers
- **Telegram bot**: search and download books via Telegram (including conversion)
- **Authentication**: BASIC auth for web access
- **Collection scanning**: automatic indexing from filesystem (ZIP archives and INPX supported)
- **Flexible settings** via web admin panel (django-constance)

---

## Quick Start with Docker

### docker-compose.yml

```yaml
# Simple OPDS Home Library https://github.com/iAHTOH/docker-sopds
services:
  sopds:
    image: iahtoh/sopds:latest                     # Docker Hub image
    container_name: sopds                           # Container name
    environment:
      - PUID=1002                                   # User ID for file permissions
      - PGID=100                                    # Group ID
      - EXT_DB=True                                 # Use external DB (PostgreSQL)
      - DB_HOST=10.16.88.3                          # PostgreSQL host
      - DB_PORT=5433                                # PostgreSQL port
      - DB_NAME=${DB_NAME}                          # Database name (from .env file)
      - DB_USER=${DB_USER}                          # Database user (from .env file)
      - DB_PASS=${DB_PASS}                          # Database password (from .env file)
      - SOPDS_SU_EMAIL=admin@example.com            # Superuser email
      - SOPDS_SU_NAME=${SOPDS_SU_NAME}              # Superuser name (from .env)
      - SOPDS_SU_PASS=${SOPDS_SU_PASS}              # Superuser password (from .env)
      - SOPDS_ROOT_LIB=/library                     # Books directory inside container
      - SOPDS_INPX_ENABLE=False                     # Disable INPX (used for flibusta)
      - SOPDS_LANGUAGE=ru-RU                        # Interface language: ru-RU or en-US
      - SOPDS_CSRF_TRUSTED_ORIGINS=https://ebook.iahtoh.ru,http://ebook.iahtoh.ru  # Allowed CSRF domains
      - SOPDS_CONVERT_ENABLE=False                  # Enable auto-conversion
      - SOPDS_TMBOT_ENABLE=False                    # Enable Telegram bot
      - CONV_LOG=/sopds/opds_catalog/log            # Conversion log path
    volumes:
      - /srv/dev-disk-by-uuid-.../e-Book:/library   # Mount book directory (read-only)
      - /docker/sopds/log:/sopds/opds_catalog/log   # Logs (persistent)
    ports:
      - 8199:8000                                   # Port mapping: host:container
    restart: always                                 # Auto-restart policy
```

### .env file (create next to docker-compose.yml)

```env
DB_NAME=sopds
DB_USER=sopds
DB_PASS=your_password
SOPDS_SU_NAME=admin
SOPDS_SU_PASS=your_password
```

### Launch

```bash
# Create .env file with passwords
# Then run
docker compose up -d
# Web UI:    http://your-server:8199/web/
# OPDS:      http://your-server:8199/opds/
# Admin:     http://your-server:8199/admin/
```

---

## Detailed Installation

### 1. Simple installation (SQLite)

```bash
git clone https://github.com/iAHTOH/sopds.git
cd sopds
pip install -r requirements.txt
python3 manage.py migrate
python3 manage.py sopds_util clear
python3 manage.py createsuperuser
python3 manage.py sopds_util setconf SOPDS_ROOT_LIB '/path/to/books'
python3 manage.py sopds_scanner start --daemon
python3 manage.py sopds_server start --daemon
```

### 2. Database setup

#### SQLite (default, for small collections)

Used automatically — no additional configuration needed.

#### PostgreSQL (recommended)

In `sopds/settings.py` uncomment PostgreSQL block and comment out SQLite:

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': 'sopds',
        'USER': 'sopds',
        'PASSWORD': 'sopds',
        'HOST': 'localhost',
        'PORT': '',
    }
}
```

Create database and user:

```sql
CREATE ROLE sopds WITH PASSWORD 'sopds' LOGIN;
CREATE DATABASE sopds WITH OWNER sopds;
```

#### MySQL / MariaDB

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'sopds',
        'HOST': 'localhost',
        'USER': 'sopds',
        'PASSWORD': 'sopds',
        'OPTIONS': {
            'init_command': "SET default_storage_engine=MyISAM; SET sql_mode='';"
        }
    }
}
```

#### In Docker

Database is configured via environment variables (see docker-compose.yml example).

---

### 3. FB2 to EPUB/MOBI/PDF/TXT conversion

**fb2cng v1.5.3** is a static Go binary with zero dependencies. Supported formats:

- `epub2` — EPUB 2
- `epub3` — EPUB 3
- `kepub` — Kobo EPUB
- `azw8` — Kindle AZW8/KFX
- `kfx` — Kindle KFX
- `pdf` — PDF
- `txt` — TXT
- `md` — Markdown

Configure paths (if not using Docker):

```bash
python3 manage.py sopds_util setconf SOPDS_FB2TOEPUB "/path/to/fb2conv/fb2epub"
python3 manage.py sopds_util setconf SOPDS_FB2TOEPUB3 "/path/to/fb2conv/fb2epub3"
python3 manage.py sopds_util setconf SOPDS_FB2TOMOBI "/path/to/fb2conv/fb2mobi"
python3 manage.py sopds_util setconf SOPDS_FB2TOPDF "/path/to/fb2conv/fb2pdf"
python3 manage.py sopds_util setconf SOPDS_FB2TOTXT "/path/to/fb2conv/fb2txt"
python3 manage.py sopds_util setconf SOPDS_TEMP_DIR "/path/to/tmp"
```

### 3. Online reader

Click **📖 Read** next to the book title (FB2 only).

- `/web/read/{id}/` — first page
- `/web/read/{id}/{page}/` — specific page
- Navigation: Prev/Next or ← → keys
- Font size: A−/A+ buttons

### 4. Telegram bot

```bash
python3 manage.py sopds_util setconf SOPDS_TELEBOT_API_TOKEN "<token>"
python3 manage.py sopds_telebot start --daemon
```

---

## Console commands

```bash
# Collection info
python3 manage.py sopds_util info

# Clear database
python3 manage.py sopds_util clear

# Scan books
python3 manage.py sopds_scanner scan

# Configuration
python3 manage.py sopds_util getconf
python3 manage.py sopds_util setconf SOPDS_ROOT_LIB '/path/to/books'

# Start server
python3 manage.py sopds_server start --port 8000
```

---

## Configuration options (constance)

Available via web admin `/admin/` → Constance → Settings.

| Parameter | Default | Description |
|---|---|---|
| **SOPDS_LANGUAGE** | en-US | Interface language |
| **SOPDS_ROOT_LIB** | books/ | Path to book collection |
| **SOPDS_AUTH** | True | BASIC authentication |
| **SOPDS_FB2TOEPUB** | — | FB2→EPUB converter path |
| **SOPDS_FB2TOEPUB3** | — | FB2→EPUB3 converter path |
| **SOPDS_FB2TOKEPUB** | — | FB2→KEPUB converter path |
| **SOPDS_FB2TOMOBI** | — | FB2→MOBI/AZW8 converter path |
| **SOPDS_FB2TOKFX** | — | FB2→KFX converter path |
| **SOPDS_FB2TOPDF** | — | FB2→PDF converter path |
| **SOPDS_FB2TOTXT** | — | FB2→TXT converter path |
| **SOPDS_FB2TOMD** | — | FB2→Markdown converter path |
| **SOPDS_TEMP_DIR** | tmp/ | Temporary directory for conversion |
| **SOPDS_CACHE_TIME** | 1200 | Page cache time (sec) |
| **SOPDS_SPLITITEMS** | 300 | Items per group before expanding |
| **SOPDS_MAXITEMS** | 60 | Books per page |

---

## Online reader

The built-in FB2 reader provides paginated book viewing. It:

- Parses FB2 directly (no external libraries)
- Splits into pages of ~5000 characters
- Renders headings, paragraphs, subtitles, poems
- Supports bold, italic, links
- Font size adjustment (A−/A+)
- Dark navigation bar theme
