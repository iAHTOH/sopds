FROM python:3.10-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Устанавливаем системные зависимости
RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential \
    libxml2-dev \
    libxslt1-dev \
    libjpeg-dev \
    zlib1g-dev \
    libpq-dev \
    mc \
    nano \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Сначала копируем requirements и устанавливаем зависимости
COPY requirements.txt .
RUN pip install --upgrade pip setuptools wheel \
    && pip install -r requirements.txt \
    && pip install \
    black \
    ruff \
    pytest \
    ipython \
    django-debug-toolbar \
    debugpy

# Копируем весь код проекта
COPY . .

# Создаём папку для SQLite (на всякий случай)
RUN mkdir -p /workspace/db && chmod 777 /workspace/db