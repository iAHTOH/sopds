FROM python:3.13-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    EXT_DB=True \
    DB_HOST="" \
    DB_PORT="" \
    DB_NAME="" \
    DB_USER="" \
    DB_PASS="" \
    SOPDS_SU_NAME="" \
    SOPDS_SU_EMAIL="" \
    SOPDS_SU_PASS="" \
    SOPDS_ROOT_LIB="/library" \
    SOPDS_INPX_ENABLE=True \
    SOPDS_LANGUAGE="ru-RU" \
    SOPDS_SERVER_PORT="8000"

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl xz-utils unzip locales gettext \
    libxml2-dev libxslt1-dev libjpeg-dev zlib1g-dev libpq-dev \
    && rm -rf /var/lib/apt/lists/* \
    && localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8 \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

WORKDIR /workspace

COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir debugpy

COPY . .
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Компиляция переводов
RUN mkdir -p /workspace/sopds/locale/ru/LC_MESSAGES \
    && cp /workspace/opds_catalog/locale/ru/LC_MESSAGES/django.po /workspace/sopds/locale/ru/LC_MESSAGES/ \
    && msgfmt /workspace/sopds/locale/ru/LC_MESSAGES/django.po -o /workspace/sopds/locale/ru/LC_MESSAGES/django.mo

# Скачиваем и устанавливаем fb2cng — современный конвертер FB2 в EPUB/AZW8
# (после COPY . ., чтобы скрипты-обёртки из проекта перезаписали архивы)
RUN FB2CNG_VERSION="v1.5.3" \
    && curl -sL "https://github.com/rupor-github/fb2cng/releases/download/${FB2CNG_VERSION}/fbc-linux-amd64.zip" -o /tmp/fbc.zip \
    && mkdir -p /workspace/convert/fb2cng \
    && unzip -o /tmp/fbc.zip -d /workspace/convert/fb2cng/ \
    && chmod +x /workspace/convert/fb2cng/fbc \
    && chmod +x /workspace/convert/fb2cng/fb2epub /workspace/convert/fb2cng/fb2mobi \
    && rm -f /tmp/fbc.zip

RUN mkdir -p db opds_catalog/log opds_catalog/tmp static \
    && chmod -R 777 db opds_catalog

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]

