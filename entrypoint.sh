#!/bin/bash

set -e

cd /workspace

# Подставляем переменные окружения в settings.py
python3 << 'EOF'
import os

settings_path = '/workspace/sopds/settings.py'
with open(settings_path, 'r') as f:
    content = f.read()

# Замены БД
replacements = {
    '"HOST": "localhost"':       '"HOST": "%s"' % os.environ.get('DB_HOST', 'localhost'),
    '"PORT": "5432"':            '"PORT": "%s"' % os.environ.get('DB_PORT', '5432'),
    '"NAME": "sopds"':           '"NAME": "%s"' % os.environ.get('DB_NAME', 'sopds'),
    '"USER": "sopds"':           '"USER": "%s"' % os.environ.get('DB_USER', 'sopds'),
    '"PASSWORD": "sopds123"':    '"PASSWORD": "%s"' % os.environ.get('DB_PASS', 'sopds123'),
}

for old, new in replacements.items():
    if old in content:
        content = content.replace(old, new)
        print("Replaced: %s -> %s" % (old, new))

# CSRF_TRUSTED_ORIGINS
csrf_origins = os.environ.get('SOPDS_CSRF_TRUSTED_ORIGINS', '')
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
python3 manage.py sopds_util clear 2>/dev/null || true

# Создание суперпользователя
if [ -n "$SOPDS_SU_NAME" ] && [ -n "$SOPDS_SU_EMAIL" ] && [ -n "$SOPDS_SU_PASS" ]; then
    echo "Creating superuser..."
    python3 manage.py createsuperuser --noinput --username "$SOPDS_SU_NAME" --email "$SOPDS_SU_EMAIL" 2>/dev/null || true
    python3 manage.py shell -c "
from django.contrib.auth.models import User
user = User.objects.filter(username='$SOPDS_SU_NAME').first()
if user:
    user.set_password('$SOPDS_SU_PASS')
    user.save()
" 2>/dev/null
fi

if [ -n "$SOPDS_ROOT_LIB" ]; then
    python3 manage.py sopds_util setconf SOPDS_ROOT_LIB "$SOPDS_ROOT_LIB" 2>/dev/null || true
fi

if [ -n "$SOPDS_INPX_ENABLE" ]; then
    python3 manage.py sopds_util setconf SOPDS_INPX_ENABLE "$SOPDS_INPX_ENABLE" 2>/dev/null || true
fi

if [ -n "$SOPDS_LANGUAGE" ]; then
    python3 manage.py sopds_util setconf SOPDS_LANGUAGE "$SOPDS_LANGUAGE" 2>/dev/null || true
fi

python3 manage.py sopds_util setconf SOPDS_SERVER_PID "/workspace/opds_catalog/tmp/sopds_server.pid" 2>/dev/null || true
python3 manage.py sopds_util setconf SOPDS_SCANNER_PID "/workspace/opds_catalog/tmp/sopds_scanner.pid" 2>/dev/null || true
python3 manage.py sopds_util setconf SOPDS_SERVER_LOG "/workspace/opds_catalog/log/sopds_server.log" 2>/dev/null || true
python3 manage.py sopds_util setconf SOPDS_SCANNER_LOG "/workspace/opds_catalog/log/sopds_scanner.log" 2>/dev/null || true
python3 manage.py sopds_util setconf SOPDS_NOCOVER_PATH "/workspace/static/images/nocover.jpg" 2>/dev/null || true

# Настройка конвертера fb2cng (современный конвертер FB2)
FB2CNG_DIR="/workspace/convert/fb2cng"

# Список: параметр_конфигурации → имя_скрипта
for entry in \
    "SOPDS_FB2TOEPUB:fb2epub" \
    "SOPDS_FB2TOEPUB3:fb2epub3" \
    "SOPDS_FB2TOKEPUB:fb2kepub" \
    "SOPDS_FB2TOMOBI:fb2mobi" \
    "SOPDS_FB2TOKFX:fb2kfx" \
    "SOPDS_FB2TOPDF:fb2pdf" \
    "SOPDS_FB2TOTXT:fb2txt" \
    "SOPDS_FB2TOMD:fb2md"; do
    IFS=: read -r config_name script_name <<< "$entry"
    script_path="$FB2CNG_DIR/$script_name"
    if [ -x "$script_path" ]; then
        python3 manage.py sopds_util setconf "$config_name" "$script_path" 2>/dev/null || true
        echo "Configured $config_name -> $script_path"
    fi
done

if [ -d "/workspace/opds_catalog/tmp" ]; then
    python3 manage.py sopds_util setconf SOPDS_TEMP_DIR "/workspace/opds_catalog/tmp" 2>/dev/null || true
fi

echo "Starting SOPDS server on port ${SOPDS_SERVER_PORT:-8000}..."
exec python3 manage.py sopds_server start --port ${SOPDS_SERVER_PORT:-8000}
