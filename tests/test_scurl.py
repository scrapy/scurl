from test import test_support
import unittest
import scurl
import six
import pytest
if six.PY2:
    import urlparse as stdlib
else:
    import urllib.parse as stdlib


class UrljoinTestCase(unittest.TestCase):
    def test_check_invalid_urls(self):
        invalid_urls = [
            'foo//example.com/',
            'bar//example.com/',
            'foobar//example.com/',
            'foobar',
            '#'
        ]

        invalid_urls_2 = [
            'foobar',
            'foo/bar',
            'foo/bar/../2'
        ]
        for invalid_url in invalid_urls:
            for invalid_url_2 in invalid_urls_2:
                self.assertEqual(scurl.urljoin(invalid_url, invalid_url_2),
                                 stdlib.urljoin(invalid_url, invalid_url_2))


    def test_urljoin_no_path(self):
        self.assertEqual(scurl.urljoin('http://example.com', 'foo.html'),
                         stdlib.urljoin('http://example.com', 'foo.html'))


if __name__ == "__main__":
    unittest.main()
