#!/bin/bash

set -e

cd /workspace

# Подставляем переменные окружения в settings.py
python3 << 'EOF'
import os

settings_path = '/workspace/eopds/settings.py'
with open(settings_path, 'r') as f:
    content = f.read()

# Замены БД
replacements = {
    '"HOST": "localhost"':       '"HOST": "%s"' % os.environ.get('DB_HOST', 'localhost'),
    '"PORT": "5432"':            '"PORT": "%s"' % os.environ.get('DB_PORT', '5432'),
    '"NAME": "eopds"':           '"NAME": "%s"' % os.environ.get('DB_NAME', 'eopds'),
    '"USER": "eopds"':           '"USER": "%s"' % os.environ.get('DB_USER', 'eopds'),
    '"PASSWORD": "eopds123"':    '"PASSWORD": "%s"' % os.environ.get('DB_PASS', 'eopds123'),
}

for old, new in replacements.items():
    if old in content:
        content = content.replace(old, new)
        print("Replaced: %s -> %s" % (old, new))

# CSRF_TRUSTED_ORIGINS
csrf_origins = os.environ.get('EOPDS_CSRF_TRUSTED_ORIGINS', '')
if csrf_origins:
    origins_list = ["'%s'" % o.strip() for o in csrf_origins.split(',') if o.strip()]
    if origins_list:
        csrf_line = '\nCSRF_TRUSTED_ORIGINS = [%s]\n' % ', '.join(origins_list)
        if 'CSRF_TRUSTED_ORIGINS' not in content:
            content += csrf_line
            print("Added CSRF_TRUSTED_ORIGINS: %s" % csrf_origins)

with open(settings_path, 'w') as f:
    f.write(content)
EOF

# Миграции (создание таблиц, если их нет)
echo "Running migrations..."
python3 manage.py migrate --noinput

# Инициализация справочника жанров (только при первом запуске)
python3 manage.py eopds_util clear 2>/dev/null || true

# Создание суперпользователя
if [ -n "$EOPDS_SU_NAME" ] && [ -n "$EOPDS_SU_EMAIL" ] && [ -n "$EOPDS_SU_PASS" ]; then
    echo "Creating superuser..."
    python3 manage.py createsuperuser --noinput --username "$EOPDS_SU_NAME" --email "$EOPDS_SU_EMAIL" 2>/dev/null || true
    python3 manage.py shell -c "
from django.contrib.auth.models import User
user = User.objects.filter(username='$EOPDS_SU_NAME').first()
if user:
    user.set_password('$EOPDS_SU_PASS')
    user.save()
" 2>/dev/null
fi

if [ -n "$EOPDS_ROOT_LIB" ]; then
    python3 manage.py eopds_util setconf EOPDS_ROOT_LIB "$EOPDS_ROOT_LIB" 2>/dev/null || true
fi

if [ -n "$EOPDS_INPX_ENABLE" ]; then
    python3 manage.py eopds_util setconf EOPDS_INPX_ENABLE "$EOPDS_INPX_ENABLE" 2>/dev/null || true
fi

if [ -n "$EOPDS_LANGUAGE" ]; then
    python3 manage.py eopds_util setconf EOPDS_LANGUAGE "$EOPDS_LANGUAGE" 2>/dev/null || true
fi

python3 manage.py eopds_util setconf EOPDS_SERVER_PID "/workspace/opds_catalog/tmp/eopds_server.pid" 2>/dev/null || true
python3 manage.py eopds_util setconf EOPDS_SCANNER_PID "/workspace/opds_catalog/tmp/eopds_scanner.pid" 2>/dev/null || true
python3 manage.py eopds_util setconf EOPDS_SERVER_LOG "/workspace/opds_catalog/log/eopds_server.log" 2>/dev/null || true
python3 manage.py eopds_util setconf EOPDS_SCANNER_LOG "/workspace/opds_catalog/log/eopds_scanner.log" 2>/dev/null || true
python3 manage.py eopds_util setconf EOPDS_NOCOVER_PATH "/workspace/static/images/nocover.jpg" 2>/dev/null || true

# Настройка конвертера fb2cng (современный конвертер FB2)
FB2CNG_DIR="/workspace/convert/fb2cng"

# Список: параметр_конфигурации → имя_скрипта
for entry in \
    "EOPDS_FB2TOEPUB:fb2epub" \
    "EOPDS_FB2TOEPUB3:fb2epub3" \
    "EOPDS_FB2TOKEPUB:fb2kepub" \
    "EOPDS_FB2TOMOBI:fb2mobi" \
    "EOPDS_FB2TOKFX:fb2kfx" \
    "EOPDS_FB2TOPDF:fb2pdf" \
    "EOPDS_FB2TOTXT:fb2txt" \
    "EOPDS_FB2TOMD:fb2md"; do
    IFS=: read -r config_name script_name <<< "$entry"
    script_path="$FB2CNG_DIR/$script_name"
    if [ -x "$script_path" ]; then
        python3 manage.py eopds_util setconf "$config_name" "$script_path" 2>/dev/null || true
        echo "Configured $config_name -> $script_path"
    fi
done

if [ -d "/workspace/opds_catalog/tmp" ]; then
    python3 manage.py eopds_util setconf EOPDS_TEMP_DIR "/workspace/opds_catalog/tmp" 2>/dev/null || true
fi

echo "Starting eopds server on port ${EOPDS_SERVER_PORT:-8000}..."
exec python3 manage.py eopds_server start --port ${EOPDS_SERVER_PORT:-8000}
