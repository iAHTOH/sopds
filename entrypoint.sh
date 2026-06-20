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

# Миграции
echo "Running migrations..."
python3 manage.py migrate --noinput

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

echo "Starting SOPDS server on port ${SOPDS_SERVER_PORT:-8000}..."
exec python3 manage.py sopds_server start --port ${SOPDS_SERVER_PORT:-8000}
