import unittest
import warnings
import pytest

from urlparse4 import canonicalize_url, parse_url
from urllib.parse import urlparse, urlsplit


class CanonicalizeUrlTest(unittest.TestCase):

    def test_canonicalize_url(self):
        # simplest case
        self.assertEqual(canonicalize_url("http://www.example.com/"),
                                          "http://www.example.com/")

    def test_return_str(self):
        assert isinstance(canonicalize_url(u"http://www.example.com"), str)
        assert isinstance(canonicalize_url(b"http://www.example.com"), str)

    def test_append_missing_path(self):
        self.assertEqual(canonicalize_url("http://www.example.com"),
                                          "http://www.example.com/")

    def test_typical_usage(self):
        self.assertEqual(canonicalize_url("http://www.example.com/do?a=1&b=2&c=3"),
                                          "http://www.example.com/do?a=1&b=2&c=3")
        self.assertEqual(canonicalize_url("http://www.example.com/do?c=1&b=2&a=3"),
                                          "http://www.example.com/do?a=3&b=2&c=1")
        self.assertEqual(canonicalize_url("http://www.example.com/do?&a=1"),
                                          "http://www.example.com/do?a=1")

    def test_port_number(self):
        self.assertEqual(canonicalize_url("http://www.example.com:8888/do?a=1&b=2&c=3"),
                                          "http://www.example.com:8888/do?a=1&b=2&c=3")
        # trailing empty ports are removed
        self.assertEqual(canonicalize_url("http://www.example.com:/do?a=1&b=2&c=3"),
                                          "http://www.example.com/do?a=1&b=2&c=3")

    def test_sorting(self):
        self.assertEqual(canonicalize_url("http://www.example.com/do?c=3&b=5&b=2&a=50"),
                                          "http://www.example.com/do?a=50&b=2&b=5&c=3")

    def test_keep_blank_values(self):
        self.assertEqual(canonicalize_url("http://www.example.com/do?b=&a=2", keep_blank_values=False),
                                          "http://www.example.com/do?a=2")
        self.assertEqual(canonicalize_url("http://www.example.com/do?b=&a=2"),
                                          "http://www.example.com/do?a=2&b=")
        self.assertEqual(canonicalize_url("http://www.example.com/do?b=&c&a=2", keep_blank_values=False),
                                          "http://www.example.com/do?a=2")
        self.assertEqual(canonicalize_url("http://www.example.com/do?b=&c&a=2"),
                                          "http://www.example.com/do?a=2&b=&c=")

        self.assertEqual(canonicalize_url(u'http://www.example.com/do?1750,4'),
                                           'http://www.example.com/do?1750%2C4=')

    def test_spaces(self):
        self.assertEqual(canonicalize_url("http://www.example.com/do?q=a space&a=1"),
                                          "http://www.example.com/do?a=1&q=a+space")
        self.assertEqual(canonicalize_url("http://www.example.com/do?q=a+space&a=1"),
                                          "http://www.example.com/do?a=1&q=a+space")
        self.assertEqual(canonicalize_url("http://www.example.com/do?q=a%20space&a=1"),
                                          "http://www.example.com/do?a=1&q=a+space")

    def test_canonicalize_url_unicode_path(self):
        self.assertEqual(canonicalize_url(u"http://www.example.com/résumé"),
                                          "http://www.example.com/r%C3%A9sum%C3%A9")

    def test_canonicalize_url_unicode_query_string(self):
        # default encoding for path and query is UTF-8
        self.assertEqual(canonicalize_url(u"http://www.example.com/résumé?q=résumé"),
                                          "http://www.example.com/r%C3%A9sum%C3%A9?q=r%C3%A9sum%C3%A9")

        # passed encoding will affect query string
        self.assertEqual(canonicalize_url(u"http://www.example.com/résumé?q=résumé", encoding='latin1'),
                                          "http://www.example.com/r%C3%A9sum%C3%A9?q=r%E9sum%E9")

        self.assertEqual(canonicalize_url(u"http://www.example.com/résumé?country=Россия", encoding='cp1251'),
                                          "http://www.example.com/r%C3%A9sum%C3%A9?country=%D0%EE%F1%F1%E8%FF")

    def test_canonicalize_url_unicode_query_string_wrong_encoding(self):
        # trying to encode with wrong encoding
        # fallback to UTF-8
        self.assertEqual(canonicalize_url(u"http://www.example.com/résumé?currency=€", encoding='latin1'),
                                          "http://www.example.com/r%C3%A9sum%C3%A9?currency=%E2%82%AC")

        self.assertEqual(canonicalize_url(u"http://www.example.com/résumé?country=Россия", encoding='latin1'),
                                          "http://www.example.com/r%C3%A9sum%C3%A9?country=%D0%A0%D0%BE%D1%81%D1%81%D0%B8%D1%8F")

    def test_normalize_percent_encoding_in_paths(self):
        self.assertEqual(canonicalize_url("http://www.example.com/r%c3%a9sum%c3%a9"),
                                          "http://www.example.com/r%C3%A9sum%C3%A9")

        # non-UTF8 encoded sequences: they should be kept untouched, only upper-cased
        # 'latin1'-encoded sequence in path
        self.assertEqual(canonicalize_url("http://www.example.com/a%a3do"),
                                          "http://www.example.com/a%A3do")

        # 'latin1'-encoded path, UTF-8 encoded query string
        self.assertEqual(canonicalize_url("http://www.example.com/a%a3do?q=r%c3%a9sum%c3%a9"),
                                          "http://www.example.com/a%A3do?q=r%C3%A9sum%C3%A9")

        # 'latin1'-encoded path and query string
        self.assertEqual(canonicalize_url("http://www.example.com/a%a3do?q=r%e9sum%e9"),
                                          "http://www.example.com/a%A3do?q=r%E9sum%E9")

    def test_normalize_percent_encoding_in_query_arguments(self):
        self.assertEqual(canonicalize_url("http://www.example.com/do?k=b%a3"),
                                          "http://www.example.com/do?k=b%A3")

        self.assertEqual(canonicalize_url("http://www.example.com/do?k=r%c3%a9sum%c3%a9"),
                                          "http://www.example.com/do?k=r%C3%A9sum%C3%A9")

    def test_non_ascii_percent_encoding_in_paths(self):
        self.assertEqual(canonicalize_url("http://www.example.com/a do?a=1"),
                                          "http://www.example.com/a%20do?a=1"),
        self.assertEqual(canonicalize_url("http://www.example.com/a %20do?a=1"),
                                          "http://www.example.com/a%20%20do?a=1"),
        self.assertEqual(canonicalize_url(u"http://www.example.com/a do£.html?a=1"),
                                          "http://www.example.com/a%20do%C2%A3.html?a=1")
        self.assertEqual(canonicalize_url(b"http://www.example.com/a do\xc2\xa3.html?a=1"),
                                          "http://www.example.com/a%20do%C2%A3.html?a=1")

    def test_non_ascii_percent_encoding_in_query_arguments(self):
        self.assertEqual(canonicalize_url(u"http://www.example.com/do?price=£500&a=5&z=3"),
                                          u"http://www.example.com/do?a=5&price=%C2%A3500&z=3")
        self.assertEqual(canonicalize_url(b"http://www.example.com/do?price=\xc2\xa3500&a=5&z=3"),
                                          "http://www.example.com/do?a=5&price=%C2%A3500&z=3")
        self.assertEqual(canonicalize_url(b"http://www.example.com/do?price(\xc2\xa3)=500&a=1"),
                                          "http://www.example.com/do?a=1&price%28%C2%A3%29=500")

    def test_urls_with_auth_and_ports(self):
        self.assertEqual(canonicalize_url(u"http://user:pass@www.example.com:81/do?now=1"),
                                          u"http://user:pass@www.example.com:81/do?now=1")

    def test_remove_fragments(self):
        self.assertEqual(canonicalize_url(u"http://user:pass@www.example.com/do?a=1#frag"),
                                          u"http://user:pass@www.example.com/do?a=1")
        self.assertEqual(canonicalize_url(u"http://user:pass@www.example.com/do?a=1#frag", keep_fragments=True),
                                          u"http://user:pass@www.example.com/do?a=1#frag")

    def test_dont_convert_safe_characters(self):
        # dont convert safe characters to percent encoding representation
        self.assertEqual(canonicalize_url(
            "http://www.simplybedrooms.com/White-Bedroom-Furniture/Bedroom-Mirror:-Josephine-Cheval-Mirror.html"),
            "http://www.simplybedrooms.com/White-Bedroom-Furniture/Bedroom-Mirror:-Josephine-Cheval-Mirror.html")

    def test_safe_characters_unicode(self):
        # urllib.quote uses a mapping cache of encoded characters. when parsing
        # an already percent-encoded url, it will fail if that url was not
        # percent-encoded as utf-8, that's why canonicalize_url must always
        # convert the urls to string. the following test asserts that
        # functionality.
        self.assertEqual(canonicalize_url(u'http://www.example.com/caf%E9-con-leche.htm'),
                                           'http://www.example.com/caf%E9-con-leche.htm')

    def test_domains_are_case_insensitive(self):
        self.assertEqual(canonicalize_url("http://www.EXAMPLE.com/"),
                                          "http://www.example.com/")

    def test_canonicalize_idns(self):
        self.assertEqual(canonicalize_url(u'http://www.bücher.de?q=bücher'),
                                           'http://www.xn--bcher-kva.de/?q=b%C3%BCcher')
        # Japanese (+ reordering query parameters)
        self.assertEqual(canonicalize_url(u'http://はじめよう.みんな/?query=サ&maxResults=5'),
                                           'http://xn--p8j9a0d9c9a.xn--q9jyb4c/?maxResults=5&query=%E3%82%B5')

    def test_quoted_slash_and_question_sign(self):
        self.assertEqual(canonicalize_url("http://foo.com/AC%2FDC+rocks%3f/?yeah=1"),
                         "http://foo.com/AC%2FDC+rocks%3F/?yeah=1")
        self.assertEqual(canonicalize_url("http://foo.com/AC%2FDC/"),
                         "http://foo.com/AC%2FDC/")

    def test_canonicalize_urlparsed(self):
        # canonicalize_url() can be passed an already urlparse'd URL
        self.assertEqual(canonicalize_url(urlparse(u"http://www.example.com/résumé?q=résumé")),
                                          "http://www.example.com/r%C3%A9sum%C3%A9?q=r%C3%A9sum%C3%A9")
        self.assertEqual(canonicalize_url(urlparse('http://www.example.com/caf%e9-con-leche.htm')),
                                          'http://www.example.com/caf%E9-con-leche.htm')
        self.assertEqual(canonicalize_url(urlparse("http://www.example.com/a%a3do?q=r%c3%a9sum%c3%a9")),
                                          "http://www.example.com/a%A3do?q=r%C3%A9sum%C3%A9")

    def test_canonicalize_parse_url(self):
        # parse_url() wraps urlparse and is used in link extractors
        self.assertEqual(canonicalize_url(parse_url(u"http://www.example.com/résumé?q=résumé")),
                                          "http://www.example.com/r%C3%A9sum%C3%A9?q=r%C3%A9sum%C3%A9")
        self.assertEqual(canonicalize_url(parse_url('http://www.example.com/caf%e9-con-leche.htm')),
                                          'http://www.example.com/caf%E9-con-leche.htm')
        self.assertEqual(canonicalize_url(parse_url("http://www.example.com/a%a3do?q=r%c3%a9sum%c3%a9")),
                                          "http://www.example.com/a%A3do?q=r%C3%A9sum%C3%A9")

    def test_canonicalize_url_idempotence(self):
        for url, enc in [(u'http://www.bücher.de/résumé?q=résumé', 'utf8'),
                         (u'http://www.example.com/résumé?q=résumé', 'latin1'),
                         (u'http://www.example.com/résumé?country=Россия', 'cp1251'),
                         (u'http://はじめよう.みんな/?query=サ&maxResults=5', 'iso2022jp')]:
            canonicalized = canonicalize_url(url, encoding=enc)

            # if we canonicalize again, we ge the same result
            self.assertEqual(canonicalize_url(canonicalized, encoding=enc), canonicalized)

            # without encoding, already canonicalized URL is canonicalized identically
            self.assertEqual(canonicalize_url(canonicalized), canonicalized)

    def test_canonicalize_url_idna_exceptions(self):
        # missing DNS label
        self.assertEqual(
            canonicalize_url(u"http://.example.com/résumé?q=résumé"),
            "http://.example.com/r%C3%A9sum%C3%A9?q=r%C3%A9sum%C3%A9")

        # DNS label too long
        self.assertEqual(
            canonicalize_url(
                u"http://www.{label}.com/résumé?q=résumé".format(
                    label=u"example"*11)),
            "http://www.{label}.com/r%C3%A9sum%C3%A9?q=r%C3%A9sum%C3%A9".format(
                    label=u"example"*11))
