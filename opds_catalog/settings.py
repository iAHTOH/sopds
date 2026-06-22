import logging
from django.conf import settings

loglevels = {
    "debug": logging.DEBUG,
    "info": logging.INFO,
    "warning": logging.WARNING,
    "error": logging.ERROR,
    "critical": logging.CRITICAL,
    "none": logging.NOTSET,
}
NOZIP_FORMATS = ["epub", "mobi"]

VERSION = "0.47-devel"
TITLE = getattr(settings, "eopds_TITLE", "HomeLib")
SUBTITLE = getattr(
    settings, "eopds_SUBTITLE", "Домашняя библиотека Version %s." % VERSION
)
ICON = getattr(settings, "eopds_ICON", "/static/images/favicon.ico")
THUMB_SIZE = 100

loglevel = getattr(settings, "eopds_LOGLEVEL", "info")
if loglevel.lower() in loglevels:
    LOGLEVEL = loglevels[loglevel.lower()]
else:
    LOGLEVEL = logging.NOTSET

from django.dispatch import receiver
# from constance.signals import config_updated
#
# @receiver(config_updated)
# def constance_updated(sender, updated_key, new_value, **kwargs):
#    if updated_key == 'eopds_LANGUAGE':
#        translation.activate(new_value)
#        print(new_value)


def constance_update_all():
    pass


# Переопределяем некоторые функции для SQLite, которые работают неправлено
from django.db.backends.signals import connection_created


def eopds_upper(s):
    return s.upper()


def eopds_substring(s, i, l):
    i = i - 1
    return s[i : i + l]


def eopds_concat(s1="", s2="", s3=""):
    return "%s%s%s" % (s1, s2, s3)


@receiver(connection_created)
def extend_sqlite(connection=None, **kwargs):
    if connection.vendor == "sqlite":
        connection.connection.create_function("upper", 1, eopds_upper)
        connection.connection.create_function("substring", 3, eopds_substring)
        connection.connection.create_function("concat", 3, eopds_concat)
