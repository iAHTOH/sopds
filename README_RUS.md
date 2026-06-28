# Simple OPDS Домашняя библиотека

**Версия 0.47-devel** | [English README](README.md)

![Скриншот](Screenshot.webp)

OPDS-каталог для домашней коллекции электронных книг с веб-интерфейсом, Telegram-ботом и онлайн-читалкой.

---

## Возможности

- **Форматы книг**: FB2, EPUB, MOBI, PDF, DJVU, DOC, TXT, RTF
- **Конвертация FB2** в EPUB, EPUB3, KEPUB (Kobo), AZW8/MOBI (Kindle), KFX (Kindle), PDF, TXT, Markdown — осуществляется современным конвертером **fb2cng** (Go-бинарник, без зависимостей)
- **Онлайн-читалка**: постраничный просмотр книг FB2 прямо в браузере, навигация по страницам, регулировка шрифта
- **OPDS-каталог**: доступен для любых OPDS-совместимых приложений (FBReader, Moon+ Reader, Librera и др.)
- **Веб-интерфейс**: поиск по названию, автору, серии, жанру; книжная полка; обложки
- **Telegram-бот**: поиск и скачивание книг через Telegram (включая конвертацию)
- **Авторизация**: BASIC-аутентификация для веб-доступа
- **Сканирование коллекции**: автоматическое индексирование книг из файловой системы (включая ZIP-архивы и INPX)
- **Гибкие настройки** через веб-админку (django-constance)

---

## Быстрый старт с Docker

### docker-compose.yml

```yaml
# Simple OPDS Домашняя библиотека https://github.com/iAHTOH/docker-eopds
services:
  eopds:
    image: iahtoh/eopds:latest                     # Образ с Docker Hub
    container_name: eopds                           # Имя контейнера
    environment:
      - eopds_ROOT_LIB=/library                     # Путь к каталогу с книгами
      - eopds_LANGUAGE=ru-RU                        # Язык интерфейса
      - eopds_SU_NAME=admin                         # Имя суперпользователя
      - eopds_SU_PASS=admin123                      # Пароль суперпользователя
      - eopds_SU_EMAIL=admin@example.com            # Email суперпользователя
      - eopds_INPX_ENABLE=False                     # Отключить INPX
      - eopds_CSRF_TRUSTED_ORIGINS=https://example.com  # Разрешённые домены
    volumes:
      - /путь/к/вашим/книгам:/library:ro            # Каталог с книгами (read-only)
    ports:
      - 8080:8000                                   # Проброс порта
    restart: always                                 # Автоперезапуск
```

### Запуск

```bash
# Создать .env файл с паролями
# Запустить
docker compose up -d
# Сервис будет доступен на http://ваш_сервер:8000/
# Веб-интерфейс: http://ваш_сервер:8000/web/
# OPDS-каталог:  http://ваш_сервер:8000/opds/
# Админка:       http://ваш_сервер:8000/admin/
```

---

## Подробная установка

### 1. Простая установка (SQLite)

```bash
git clone https://github.com/iAHTOH/eopds.git
cd eopds
pip install -r requirements.txt
python3 manage.py migrate
python3 manage.py eopds_util clear
python3 manage.py createsuperuser
python3 manage.py eopds_util setconf eopds_ROOT_LIB 'путь/к/книгам'
python3 manage.py eopds_scanner start --daemon
python3 manage.py eopds_server start --daemon
```

### 2. Настройка базы данных

#### SQLite (по умолчанию, для небольших коллекций)

Используется автоматически — дополнительных настроек не требуется.

#### PostgreSQL (рекомендуется)

В `eopds/settings.py` раскомментируйте блок PostgreSQL и закомментируйте SQLite:

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': 'eopds',
        'USER': 'eopds',
        'PASSWORD': 'eopds',
        'HOST': 'localhost',
        'PORT': '',
    }
}
```

Создайте БД и пользователя:

```sql
CREATE ROLE eopds WITH PASSWORD 'eopds' LOGIN;
CREATE DATABASE eopds WITH OWNER eopds;
```

#### MySQL / MariaDB

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'eopds',
        'HOST': 'localhost',
        'USER': 'eopds',
        'PASSWORD': 'eopds',
        'OPTIONS': {
            'init_command': "SET default_storage_engine=MyISAM; SET sql_mode='';"
        }
    }
}
```

#### В Docker

Настройки БД задаются через переменные окружения (см. пример docker-compose.yml).

---

### 3. Конвертация FB2 в EPUB/MOBI/PDF/TXT

Установлен **fb2cng v1.5.3** — статический Go-бинарник, не требует зависимостей. Поддерживает:

- `epub2` — EPUB 2
- `epub3` — EPUB 3
- `kepub` — Kobo EPUB
- `azw8` — Kindle AZW8/KFX
- `kfx` — Kindle KFX
- `pdf` — PDF
- `txt` — TXT
- `md` — Markdown

Настройка путей (если запуск не через Docker):

```bash
python3 manage.py eopds_util setconf eopds_FB2TOEPUB "/путь/к/fb2conv/fb2epub"
python3 manage.py eopds_util setconf eopds_FB2TOEPUB3 "/путь/к/fb2conv/fb2epub3"
python3 manage.py eopds_util setconf eopds_FB2TOMOBI "/путь/к/fb2conv/fb2mobi"
python3 manage.py eopds_util setconf eopds_FB2TOPDF "/путь/к/fb2conv/fb2pdf"
python3 manage.py eopds_util setconf eopds_FB2TOTXT "/путь/к/fb2conv/fb2txt"
python3 manage.py eopds_util setconf eopds_TEMP_DIR "/путь/к/tmp"
```

### 3. Онлайн-читалка

Доступна по кнопке **📖 Читать** рядом с названием книги (только для FB2).

- `/web/read/{id}/` — первая страница
- `/web/read/{id}/{page}/` — конкретная страница
- Навигация: Prev/Next или клавиши ← →
- Регулировка шрифта: кнопки A−/A+

### 4. Telegram-бот

```bash
python3 manage.py eopds_util setconf eopds_TELEBOT_API_TOKEN "<token>"
python3 manage.py eopds_telebot start --daemon
```

---


## Поддержка

- **Форум**: [https://eopds.ru](https://eopds.ru) — поддержка проекта, обсуждения, вопросы и обратная связь
- **GitHub**: [https://github.com/iAHTOH/eopds](https://github.com/iAHTOH/eopds) — исходный код и issues

## Консольные команды

```bash
# Информация о коллекции
python3 manage.py eopds_util info

# Очистка БД
python3 manage.py eopds_util clear

# Запуск сканирования
python3 manage.py eopds_scanner scan

# Управление настройками
python3 manage.py eopds_util getconf
python3 manage.py eopds_util setconf eopds_ROOT_LIB '/путь/к/книгам'

# Запуск сервера
python3 manage.py eopds_server start --port 8000
```

---

## Параметры конфигурации (constance)

Доступны через веб-админку `/admin/` → Constance → Настройки.

| Параметр | По умолчанию | Описание |
|---|---|---|
| **eopds_LANGUAGE** | en-US | Язык интерфейса |
| **eopds_ROOT_LIB** | books/ | Путь к каталогу с книгами |
| **eopds_AUTH** | True | BASIC-аутентификация |
| **eopds_FB2TOEPUB** | — | Путь к конвертеру FB2→EPUB |
| **eopds_FB2TOEPUB3** | — | Путь к конвертеру FB2→EPUB3 |
| **eopds_FB2TOKEPUB** | — | Путь к конвертеру FB2→KEPUB |
| **eopds_FB2TOMOBI** | — | Путь к конвертеру FB2→MOBI/AZW8 |
| **eopds_FB2TOKFX** | — | Путь к конвертеру FB2→KFX |
| **eopds_FB2TOPDF** | — | Путь к конвертеру FB2→PDF |
| **eopds_FB2TOTXT** | — | Путь к конвертеру FB2→TXT |
| **eopds_FB2TOMD** | — | Путь к конвертеру FB2→Markdown |
| **eopds_TEMP_DIR** | tmp/ | Временная директория для конвертации |
| **eopds_CACHE_TIME** | 1200 | Время кэширования страниц (сек) |
| **eopds_SPLITITEMS** | 300 | Элементов в группе до раскрытия |
| **eopds_MAXITEMS** | 60 | Книг на страницу |

---

## Онлайн-читалка

Система включает встроенную постраничную читалку для книг FB2. Она:

- Парсит FB2 напрямую (без внешних библиотек)
- Разбивает на страницы по 5000 символов
- Отображает заголовки, параграфы, подзаголовки, стихи
- Поддерживает жирный текст, курсив, ссылки
- Позволяет менять размер шрифта (A−/A+)
- Тёмная тема навигационной панели

### Скриншот

```
Название книги
[‹ Назад] [Стр. 3 / 36] [Далее ›]  [A−] [A+]

  Текст книги с параграфами,
  заголовками и форматированием...

[‹ Назад] [Стр. 3 / 36] [Далее ›]
```
