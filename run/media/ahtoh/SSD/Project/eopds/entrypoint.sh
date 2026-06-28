#!/bin/bash

set -e

cd /workspace

INIT_FLAG="/workspace/.initialized"

if [ ! -f "$INIT_FLAG" ]; then
    echo "First run — initializing..."

    python3 << 'PYEOF'
import os

settings_path = '/workspace/eopds/settings.py'
with open(settings_path, 'r') as f:
    content = f.read()

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
PYEOF

    echo "Running migrations..."
    python3 manage.py migrate --noinput

    python3 manage.py eopds_util clear 2>/dev/null || true

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

    for s in \
        "EOPDS_ROOT_LIB:$EOPDS_ROOT_LIB" \
        "EOPDS_INPX_ENABLE:$EOPDS_INPX_ENABLE" \
        "EOPDS_LANGUAGE:$EOPDS_LANGUAGE" \
        "EOPDS_SERVER_PID:/workspace/opds_catalog/tmp/eopds_server.pid" \
        "EOPDS_SCANNER_PID:/workspace/opds_catalog/tmp/eopds_scanner.pid" \
        "EOPDS_SERVER_LOG:/workspace/opds_catalog/log/eopds_server.log" \
        "EOPDS_SCANNER_LOG:/workspace/opds_catalog/log/eopds_scanner.log" \
        "EOPDS_NOCOVER_PATH:/workspace/static/images/nocover.jpg" \
        "EOPDS_TEMP_DIR:/workspace/opds_catalog/tmp"; do
        IFS=: read -r k v <<< "$s"
        [ -n "$v" ] && python3 manage.py eopds_util setconf "$k" "$v" 2>/dev/null || true
    done

    FB2CNG_DIR="/workspace/convert/fb2cng"
    for e in \
        "EOPDS_FB2TOEPUB:fb2epub" \
        "EOPDS_FB2TOEPUB3:fb2epub3" \
        "EOPDS_FB2TOKEPUB:fb2kepub" \
        "EOPDS_FB2TOMOBI:fb2mobi" \
        "EOPDS_FB2TOKFX:fb2kfx" \
        "EOPDS_FB2TOPDF:fb2pdf" \
        "EOPDS_FB2TOTXT:fb2txt" \
        "EOPDS_FB2TOMD:fb2md"; do
        IFS=: read -r c s <<< "$e"
        p="$FB2CNG_DIR/$s"
        if [ -x "$p" ]; then
            python3 manage.py eopds_util setconf "$c" "$p" 2>/dev/null || true
            echo "Configured $c -> $p"
        fi
    done

    touch "$INIT_FLAG"
    echo "Initialization complete."
else
    echo "Already initialized, skipping setup."
fi

echo "Starting eopds server on port ${EOPDS_SERVER_PORT:-8000}..."
exec python3 manage.py eopds_server start --port ${EOPDS_SERVER_PORT:-8000}
