# -*- coding: utf-8 -*-

import os
import re

from django.db.models import Q
from django.utils.translation import gettext as _, gettext_noop as _noop
from django.db import transaction, connection

from opds_catalog.models import Book, Catalog, Author, Genre, Series, bseries, bauthor, bgenre, bookshelf, Counter, LangCodes
from opds_catalog.models import SIZE_BOOK_FILENAME, SIZE_BOOK_PATH, SIZE_BOOK_FORMAT, SIZE_BOOK_DOCDATE, SIZE_BOOK_LANG, SIZE_BOOK_TITLE, SIZE_BOOK_ANNOTATION
from opds_catalog.models import SIZE_CAT_CATNAME, SIZE_CAT_PATH, SIZE_AUTHOR_NAME, SIZE_GENRE, SIZE_GENRE_SECTION, SIZE_GENRE_SUBSECTION, SIZE_SERIES

CAT_NORMAL=0
CAT_ZIP=1
CAT_INPX=2
CAT_INP=3

CMP_NONE=0
CMP_NORMAL=1
CMP_STRONG=2
CMP_CLEAR=3
CMP_TITLE_FTYPE_FSIZE=2

_author_cache = {}
_genre_cache = {}
_series_cache = {}
_cat_cache = {}
_book_exists = set()
_bulk_buffer = []
_bulk_authors = []
_bulk_genres = []
_bulk_series = []
_BULK_SIZE = 1000
_bulk_books_added = 0

def clear_caches():
    _author_cache.clear()
    _genre_cache.clear()
    _series_cache.clear()
    _cat_cache.clear()
    _book_exists.clear()
    _bulk_buffer.clear()
    _bulk_authors.clear()
    _bulk_genres.clear()
    _bulk_series.clear()
    global _bulk_books_added
    _bulk_books_added = 0

def _flush_bulk():
    global _bulk_books_added
    if not _bulk_buffer:
        return
    Book.objects.bulk_create(_bulk_buffer, ignore_conflicts=True)
    if _bulk_authors:
        bauthor.objects.bulk_create(_bulk_authors, ignore_conflicts=True)
    if _bulk_genres:
        bgenre.objects.bulk_create(_bulk_genres, ignore_conflicts=True)
    if _bulk_series:
        bseries.objects.bulk_create(_bulk_series, ignore_conflicts=True)
    _bulk_books_added += len(_bulk_buffer)
    _bulk_buffer.clear()
    _bulk_authors.clear()
    _bulk_genres.clear()
    _bulk_series.clear()

def pg_optimize(verbose=False):
    with connection.cursor() as cursor:
        cursor.execute("VACUUM ANALYZE")

def clear_all(verbose=False):
    print('Clear all.')
    clear_caches()
    bseries.objects.all().delete()
    bgenre.objects.all().delete()
    bauthor.objects.all().delete()
    Book.objects.all().delete()
    Author.objects.all().delete()
    Genre.objects.all().delete()
    Series.objects.all().delete()
    Catalog.objects.all().delete()

def clear_genres(verbose=False):
    Genre.objects.all().delete()
    _genre_cache.clear()

def p(s,size):
    return s[:size] if isinstance(s, str) else s

def getlangcode(s):
    try:
        lc = LangCodes.objects.get(code=s[:2])
        return lc.id
    except:
        return 1

def avail_check_prepare():
    Book.objects.filter(~Q(avail=0)).update(avail=1)

def books_del_logical():
    return Book.objects.filter(avail=1).update(avail=0)

def books_del_phisical():
    row_count = Book.objects.filter(avail__lte=1).delete()
    return row_count

def arc_skip(arcpath, arcsize):
    catalog = findcat(arcpath)
    if catalog is None:
        return 0
    if arcsize == catalog.cat_size:
        row_count = Book.objects.filter(path=arcpath).update(avail=2)
        return row_count
    return 0

def inp_skip(arcpath, arcsize):
    catalog = findcat(arcpath)
    if catalog is None:
        return 0
    if arcsize == catalog.cat_size:
        row_count = Book.objects.filter(catalog__parent=catalog).update(avail=2)
        return row_count
    return 0

def inpx_skip(arcpath, arcsize):
    catalog = findcat(arcpath)
    if catalog is None:
        return 0
    if arcsize == catalog.cat_size:
        row_count = Book.objects.filter(catalog__parent__parent=catalog).update(avail=2)
        return row_count
    return 0

def findcat(cat_name):
    if cat_name in _cat_cache:
        return _cat_cache[cat_name]
    (head, tail) = os.path.split(cat_name)
    try:
        catalog = Catalog.objects.get(cat_name=tail[:SIZE_CAT_CATNAME], path=cat_name[:SIZE_CAT_PATH])
        _cat_cache[cat_name] = catalog
        return catalog
    except:
        return None

def addcattree(cat_name, archive=0, size=0):
    cached = findcat(cat_name)
    if cached:
        if size and archive:
            Catalog.objects.filter(pk=cached.pk).update(cat_size=size)
        return cached
    (head, tail) = os.path.split(cat_name)
    parent = None
    if head and head != cat_name:
        parent = addcattree(head, 0, 0)
    catalog = Catalog(cat_name=tail[:SIZE_CAT_CATNAME], path=cat_name[:SIZE_CAT_PATH],
                       cat_type=archive, cat_size=size, parent=parent)
    catalog.save()
    _cat_cache[cat_name] = catalog
    return catalog

def findbook(name, path, setavail=0):
    key = (name, path)
    if key in _book_exists:
        return True
    return None

def addbook(name, path, cat, exten, title, annotation, docdate, lang, size=0, archive=0):
    key = (name, path)
    if key in _book_exists:
        return None
    book = Book(
        name=name[:SIZE_BOOK_FILENAME], path=path[:SIZE_BOOK_PATH],
        catalog=cat, format=exten[:SIZE_BOOK_FORMAT],
        title=title[:SIZE_BOOK_TITLE], annotation=annotation[:SIZE_BOOK_ANNOTATION],
        docdate=docdate[:SIZE_BOOK_DOCDATE], lang=lang[:SIZE_BOOK_LANG],
        size=size, archive=archive
    )
    _bulk_buffer.append(book)
    _book_exists.add(key)
    if len(_bulk_buffer) >= _BULK_SIZE:
        _flush_bulk()
    return book

def flush_books():
    _flush_bulk()

def get_books_added():
    global _bulk_books_added
    return _bulk_books_added

def findauthor(full_name):
    if full_name in _author_cache:
        return _author_cache[full_name]
    return None

def addauthor(full_name):
    cached = findauthor(full_name)
    if cached:
        return cached
    author = Author(name=full_name[:SIZE_AUTHOR_NAME])
    author.save()
    _author_cache[full_name] = author
    return author

def addbauthor(book, author):
    _bulk_authors.append(bauthor(book=book, author=author))

def addgenre(genre):
    if genre in _genre_cache:
        return _genre_cache[genre]
    g = Genre(name=genre[:SIZE_GENRE])
    g.save()
    _genre_cache[genre] = g
    return g

def addbgenre(book, genre):
    _bulk_genres.append(bgenre(book=book, genre=genre))

def addseries(ser):
    if ser in _series_cache:
        return _series_cache[ser]
    s = Series(name=ser[:SIZE_SERIES])
    s.save()
    _series_cache[ser] = s
    return s

def addbseries(book, ser, ser_no):
    _bulk_series.append(bseries(book=book, series=ser, ser_no=ser_no))

def set_autocommit(autocommit):
    pass

def commit():
    pass
