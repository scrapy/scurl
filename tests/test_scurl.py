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


    def test_urljoin_no_canonicalize(self):
        bases = [
            'http://example.com',
            'http://example.com/',
            'http://example.com/white space',
            'http://example.com/white space/foo bar/',
            'file://example.com/white space',
            'file://example.com/'
        ]
        urls = [
            '',
            'foo/bar',
            'white space',
            'white space/foo bar',
            'http://example2.com/',
            'http://example2.com',
            'http://example2.com/white space',
            'file://a/b/c/d'
        ]

        for base in bases:
            for url in urls:
                self.assertEqual(scurl.urljoin(base, url),
                                 stdlib.urljoin(base, url))
                self.assertEqual(scurl.urljoin(url, base),
                                 stdlib.urljoin(url, base))

    def test_urljoin_invalid_host(self):
        bases = [
            'http://example].com',
            'http://[example.com'
        ]
        urls = [
            'http://[example.com/foo/bar',
            'http://example.com]/foo/bar'
        ]

        for base in bases:
            for url in urls:
                self.assertRaises(ValueError, scurl.urljoin, base, url)

if __name__ == "__main__":
    unittest.main()
