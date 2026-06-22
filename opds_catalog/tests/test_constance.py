import os
from io import StringIO
from opds_catalog.management.commands import eopds_util
from constance import config

from django.core.management import call_command
from django.test import TestCase

from opds_catalog import zipf as zipfile

class constanceTestCase(TestCase):
    test_module_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    test_ROOTLIB = os.path.join(test_module_path, 'tests/data')

    def setUp(self):
        pass

    def test_constance_attributes_count(self):
        out = StringIO()
        call_command('constance', 'list', stdout=out)
        out.seek(0)
        self.assertEquals(out.getvalue().count('\n'), 37)
        out.close()

    def test_constance_set_get_attr(self):
        conf_value = 'test_temp_dir'
        call_command('constance', 'set', 'EOPDS_TEMP_DIR', conf_value)
        self.assertEquals(config.EOPDS_TEMP_DIR, conf_value)
        out = StringIO()
        call_command('constance', 'get', 'eopds_TEMP_DIR', stdout=out)
        out.seek(0)
        self.assertEquals(out.getvalue().strip(), conf_value)
        out.close()

