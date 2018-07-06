# cython: linetrace=True
# distutils: define_macros=CYTHON_TRACE=1

from scurl import urlparse

import string
import six
from six.moves.urllib.parse import (urlunsplit, urldefrag, urlencode,
                                    quote, parse_qsl, unquote)
from six.moves.urllib.parse import urlunparse as stdlib_urlunparse


# https://github.com/scrapy/w3lib/blob/master/w3lib/url.py
RFC3986_GEN_DELIMS = b':/?#[]@'
RFC3986_SUB_DELIMS = b"!$&'()*+,;="
RFC3986_RESERVED = RFC3986_GEN_DELIMS + RFC3986_SUB_DELIMS
RFC3986_UNRESERVED = (string.ascii_letters + string.digits + "-._~").encode('ascii')
EXTRA_SAFE_CHARS = b'|'  # see https://github.com/scrapy/w3lib/pull/25

_safe_chars = RFC3986_RESERVED + RFC3986_UNRESERVED + EXTRA_SAFE_CHARS + b'%'

if not six.PY2:
    from urllib.parse import _coerce_args, unquote_to_bytes

    def parse_qsl_to_bytes(qs, keep_blank_values=False):
        """Parse a query given as a string argument.

        Data are returned as a list of name, value pairs as bytes.

        Arguments:

        qs: percent-encoded query string to be parsed

        keep_blank_values: flag indicating whether blank values in
            percent-encoded queries should be treated as blank strings.  A
            true value indicates that blanks should be retained as blank
            strings.  The default false value indicates that blank values
            are to be ignored and treated as if they were  not included.

        """
        # This code is the same as Python3's parse_qsl()
        # (at https://hg.python.org/cpython/rev/c38ac7ab8d9a)
        # except for the unquote(s, encoding, errors) calls replaced
        # with unquote_to_bytes(s)
        qs, _coerce_result = _coerce_args(qs)
        pairs = [s2 for s1 in qs.split('&') for s2 in s1.split(';')]
        r = []
        for name_value in pairs:
            if not name_value:
                continue
            nv = name_value.split('=', 1)
            if len(nv) != 2:
                # Handle case of a control-name with no equal sign
                if keep_blank_values:
                    nv.append('')
                else:
                    continue
            if len(nv[1]) or keep_blank_values:
                name = nv[0].replace('+', ' ')
                name = unquote_to_bytes(name)
                name = _coerce_result(name)
                value = nv[1].replace('+', ' ')
                value = unquote_to_bytes(value)
                value = _coerce_result(value)
                r.append((name, value))
        return r

def _safe_ParseResult(parts, encoding='utf8', path_encoding='utf8'):
    """
    NOTE: This function is from w3lib. However, it has been modified
    to use functions from scurl instead!
    """
    # IDNA encoding can fail for too long labels (>63 characters)
    # or missing labels (e.g. http://.example.com)
    try:
        netloc = parts.netloc.encode('idna')
    except UnicodeError:
        netloc = parts.netloc

    return (
        to_native_str(parts.scheme),
        to_native_str(netloc),

        # default encoding for path component SHOULD be UTF-8
        to_native_str(parts.path, path_encoding),
        to_native_str(parts.params, path_encoding),

        # encoding of query and fragment follows page encoding
        # or form-charset (if known and passed)
        to_native_str(parts.query, encoding),
        to_native_str(parts.fragment, encoding)
    )

def canonicalize_url(url, keep_blank_values=True, keep_fragments=False,
                     encoding=None):
    r"""Canonicalize the given url by applying the following procedures:

    - sort query arguments, first by key, then by value
    - percent encode paths ; non-ASCII characters are percent-encoded
      using UTF-8 (RFC-3986)
    - percent encode query arguments ; non-ASCII characters are percent-encoded
      using passed `encoding` (UTF-8 by default)
    - normalize all spaces (in query arguments) '+' (plus symbol)
    - normalize percent encodings case (%2f -> %2F)
    - remove query arguments with blank values (unless `keep_blank_values` is True)
    - remove fragments (unless `keep_fragments` is True)

    The url passed can be bytes or unicode, while the url returned is
    always a native str (bytes in Python 2, unicode in Python 3).

    >>> import w3lib.url
    >>>
    >>> # sorting query arguments
    >>> w3lib.url.canonicalize_url('http://www.example.com/do?c=3&b=5&b=2&a=50')
    'http://www.example.com/do?a=50&b=2&b=5&c=3'
    >>>
    >>> # UTF-8 conversion + percent-encoding of non-ASCII characters
    >>> w3lib.url.canonicalize_url(u'http://www.example.com/r\u00e9sum\u00e9')
    'http://www.example.com/r%C3%A9sum%C3%A9'
    >>>

    For more examples, see the tests in `tests/test_url.py`.

    NOTE: This function is from w3lib. However, it has been modified
    to use functions from scurl instead!
    """
    try:
        scheme, netloc, path, params, query, fragment = _safe_ParseResult(
            parse_url(url, encoding), encoding=encoding)
    except UnicodeEncodeError as e:
        scheme, netloc, path, params, query, fragment = _safe_ParseResult(
            parse_url(url, encoding), encoding='utf8')

    # 1. decode query-string as UTF-8 (or keep raw bytes),
    #    sort values,
    #    and percent-encode them back
    if six.PY2:
        keyvals = parse_qsl(query, keep_blank_values)
    else:
        # Python3's urllib.parse.parse_qsl does not work as wanted
        # for percent-encoded characters that do not match passed encoding,
        # they get lost.
        #
        # e.g., 'q=b%a3' becomes [('q', 'b\ufffd')]
        # (ie. with 'REPLACEMENT CHARACTER' (U+FFFD),
        #      instead of \xa3 that you get with Python2's parse_qsl)
        #
        # what we want here is to keep raw bytes, and percent encode them
        # so as to preserve whatever encoding what originally used.
        #
        # See https://tools.ietf.org/html/rfc3987#section-6.4:
        #
        # For example, it is possible to have a URI reference of
        # "http://www.example.org/r%E9sum%E9.xml#r%C3%A9sum%C3%A9", where the
        # document name is encoded in iso-8859-1 based on server settings, but
        # where the fragment identifier is encoded in UTF-8 according to
        # [XPointer]. The IRI corresponding to the above URI would be (in XML
        # notation)
        # "http://www.example.org/r%E9sum%E9.xml#r&#xE9;sum&#xE9;".
        # Similar considerations apply to query parts.  The functionality of
        # IRIs (namely, to be able to include non-ASCII characters) can only be
        # used if the query part is encoded in UTF-8.
        keyvals = parse_qsl_to_bytes(query, keep_blank_values)
    keyvals.sort()
    query = urlencode(keyvals)

    # 2. decode percent-encoded sequences in path as UTF-8 (or keep raw bytes)
    #    and percent-encode path again (this normalizes to upper-case %XX)
    # uqp = _unquotepath(path)
    # path = quote(uqp, _safe_chars) or '/'

    fragment = '' if not keep_fragments else fragment

    # every part should be safe already
    return stdlib_urlunparse((scheme,
                               netloc.lower().rstrip(':'),
                               path,
                               params,
                               query,
                               fragment))

def parse_url(url, canonicalize_encoding='utf-8', encoding=None):
    """Return urlparsed url from the given argument (which could be an already
    parsed url)

    NOTE: This function is from w3lib. However, it has been modified
    to use functions from scurl instead!
    """
    if isinstance(url, tuple):
        return url

    if canonicalize_encoding is None:
        canonicalize_encoding = 'utf-8'
    return urlparse(to_unicode(url, encoding), canonicalize=True, canonicalize_encoding=canonicalize_encoding)

def _unquotepath(path):
    for reserved in ('2f', '2F', '3f', '3F'):
        path = path.replace('%' + reserved, '%25' + reserved.upper())

    if six.PY2:
        # in Python 2, '%a3' becomes '\xa3', which is what we want
        return unquote(path)
    else:
        # in Python 3,
        # standard lib's unquote() does not work for non-UTF-8
        # percent-escaped characters, they get lost.
        # e.g., '%a3' becomes 'REPLACEMENT CHARACTER' (U+FFFD)
        #
        # unquote_to_bytes() returns raw bytes instead
        return unquote_to_bytes(path)


# util funcs
# https://github.com/scrapy/w3lib/blob/master/w3lib/util.py

def to_unicode(text, encoding=None, errors='strict'):
    """Return the unicode representation of a bytes object `text`. If `text`
    is already an unicode object, return it as-is."""
    if isinstance(text, six.text_type):
        return text
    if not isinstance(text, (bytes, six.text_type)):
        raise TypeError('to_unicode must receive a bytes, str or unicode '
                        'object, got %s' % type(text).__name__)
    if encoding is None:
        encoding = 'utf-8'
    return text.decode(encoding, errors)

def to_bytes(text, encoding=None, errors='strict'):
    """Return the binary representation of `text`. If `text`
    is already a bytes object, return it as-is."""
    if isinstance(text, bytes):
        return text
    if not isinstance(text, six.string_types):
        raise TypeError('to_bytes must receive a unicode, str or bytes '
                        'object, got %s' % type(text).__name__)
    if encoding is None:
        encoding = 'utf-8'
    return text.encode(encoding, errors)

def to_native_str(text, encoding=None, errors='strict'):
    """ Return str representation of `text`
    (bytes in Python 2.x and unicode in Python 3.x). """
    if six.PY2:
        return to_bytes(text, encoding, errors)
    else:
        return to_unicode(text, encoding, errors)
