from urlparse4.mozilla_url_parse cimport *
from urlparse4.chromium_gurl cimport GURL
from urlparse4.chromium_url_constant cimport *
from urlparse4.chromium_url_util_internal cimport CompareSchemeComponent
from urlparse4.chromium_url_util cimport IsStandard, Canonicalize
from urlparse4.chromium_url_canon_stdstring cimport StdStringCanonOutput
from urlparse4.chromium_url_canon cimport CharsetConverter

import six
from six.moves.urllib.parse import (urlunsplit, urldefrag, urlencode,
                                    quote, parse_qsl, unquote)
from six.moves.urllib.parse import urlsplit as stdlib_urlsplit
from six.moves.urllib.parse import urljoin as stdlib_urljoin
from six.moves.urllib.parse import urlunsplit as stdlib_urlunsplit
from six.moves.urllib.parse import urlparse as stdlib_urlparse
from six.moves.urllib.parse import urlunparse as stdlib_urlunparse
from w3lib.util import to_bytes, to_native_str, to_unicode
import string as py_string

cimport cython
from libcpp.string cimport string
from libcpp cimport bool


uses_params = [b'', b'ftp', b'hdl',
               b'prospero', b'http', b'imap',
               b'https', b'shttp', b'rtsp',
               b'rtspu', b'sip', b'sips',
               b'mms', b'sftp', b'tel']

RFC3986_GEN_DELIMS = b':/?#[]@'
RFC3986_SUB_DELIMS = b"!$&'()*+,;="
RFC3986_RESERVED = RFC3986_GEN_DELIMS + RFC3986_SUB_DELIMS
RFC3986_UNRESERVED = (py_string.ascii_letters + py_string.digits + "-._~").encode('ascii')
EXTRA_SAFE_CHARS = b'|'  # see https://github.com/scrapy/w3lib/pull/25

_safe_chars = RFC3986_RESERVED + RFC3986_UNRESERVED + EXTRA_SAFE_CHARS + b'%'


cdef bytes slice_component(bytes pyurl, Component comp):
    if comp.len <= 0:
        return b""

    return pyurl[comp.begin:comp.begin + comp.len]


cdef bytes cslice_component(char * url, Component comp):
    if comp.len <= 0:
        return b""

    # TODO: check if std::string brings any speedups
    return url[comp.begin:comp.begin + comp.len]


cdef bytes build_netloc(bytes url, Parsed parsed):
    if parsed.host.len <= 0:
        return b""

    # Nothing at all
    elif parsed.username.len <= 0 and parsed.password.len <= 0 and parsed.port.len <= 0:
        return url[parsed.host.begin: parsed.host.begin + parsed.host.len]

    # Only port
    elif parsed.username.len <= 0 and parsed.password.len <= 0 and parsed.port.len > 0:
        return url[parsed.host.begin: parsed.host.begin + parsed.host.len + 1 + parsed.port.len]

    # Only username
    elif parsed.username.len > 0 and parsed.password.len <= 0 and parsed.port.len <= 0:
        return url[parsed.username.begin: parsed.username.begin + parsed.host.len + 1 + parsed.username.len]

    # Username + password
    elif parsed.username.len > 0 and parsed.password.len > 0 and parsed.port.len <= 0:
        return url[parsed.username.begin: parsed.username.begin + parsed.host.len + 2 + parsed.username.len + parsed.password.len]

    # Username + port
    elif parsed.username.len > 0 and parsed.password.len <= 0 and parsed.port.len > 0:
        return url[parsed.username.begin: parsed.username.begin + parsed.host.len + 2 + parsed.username.len + parsed.port.len]

    # Username + port + password
    elif parsed.username.len > 0 and parsed.password.len > 0 and parsed.port.len > 0:
        return url[parsed.username.begin: parsed.username.begin + parsed.host.len + 3 + parsed.port.len  + parsed.username.len  + parsed.password.len]

    else:
        raise ValueError


cdef bytes unicode_handling(str):
    cdef bytes bytes_str
    if isinstance(str, unicode):
        bytes_str = <bytes>(<unicode>str).encode('utf8')
    else:
        bytes_str = <bytes>str
    return bytes_str

cdef void parse_input_url(bytes url, Component url_scheme, Parsed * parsed):
    if CompareSchemeComponent(url, url_scheme, kFileScheme):
        ParseFileURL(url, len(url), parsed)
    elif CompareSchemeComponent(url, url_scheme, kFileSystemScheme):
        ParseFileSystemURL(url, len(url), parsed)
    elif IsStandard(url, url_scheme):
        ParseStandardURL(url, len(url), parsed)
    elif CompareSchemeComponent(url, url_scheme, kMailToScheme):
        """
        Discuss: Is this correct?
        """
        ParseMailtoURL(url, len(url), parsed)
    else:
        """
        TODO:
        trim or not to trim?
        """
        ParsePathURL(url, len(url), True, parsed)

cdef object extra_attr(obj, prop, bytes url, Parsed parsed, decoded, params=False):
    if prop == "scheme":
        return obj[0]
    elif prop == "netloc":
        return obj[1]
    elif prop == "path":
        return obj[2]
    elif params and prop == "params":
        return obj[3]
    elif prop == "query":
        if params:
            return obj[4]
        return obj[3]
    elif prop == "fragment":
        if params:
            return obj[5]
        return obj[4]
    elif prop == "port":
        if parsed.port.len > 0:
            port = slice_component(url, parsed.port)
            try:
                port = int(port, 10)
            except ValueError:
                message = f'Port could not be cast to integer value as {port!r}'
                raise ValueError(message) from None
            if not ( 0 <= port <= 65535):
                raise ValueError("Port out of range 0-65535")
            return port
    elif prop == "username":
        username = slice_component(url, parsed.username)
        if decoded:
            return username.decode('utf-8') or None
        return username or None
    elif prop == "password":
        password = slice_component(url, parsed.password)
        if decoded:
            return password.decode('utf-8') or None
        return password or None
    elif prop == "hostname":
        hostname = slice_component(url, parsed.host).lower()
        if len(hostname) > 0 and chr(hostname[0]) == '[':
            hostname = hostname[1:-1]
        if decoded:
            return hostname.decode('utf-8') or None
        return hostname or None

# https://github.com/python/cpython/blob/master/Lib/urllib/parse.py
cdef object _splitparams(string path):
    """
    this function can be modified to enhance the performance?
    """
    cdef char slash_char = b'/'
    cdef string slash_string = b'/'
    cdef string semcol = b';'
    cdef int i

    if path.find(slash_string) != -1:
        i = path.find(semcol, path.rfind(slash_char))
        if i < 0:
            return path, b''
    else:
        i = path.find(semcol)
    return path.substr(0, i), path.substr(i + 1)


# @cython.freelist(100)
# cdef class SplitResult:

#     cdef Parsed parsed
#     # cdef char * url
#     cdef bytes pyurl

#     def __cinit__(self, char* url):
#         # self.url = url
#         self.pyurl = url
#         if url[0:5] == b"file:":
#             ParseFileURL(url, len(url), &self.parsed)
#         else:
#             ParseStandardURL(url, len(url), &self.parsed)

#     property scheme:
#         def __get__(self):
#             return slice_component(self.pyurl, self.parsed.scheme)

#     property path:
#         def __get__(self):
#             return slice_component(self.pyurl, self.parsed.path)

#     property query:
#         def __get__(self):
#             return slice_component(self.pyurl, self.parsed.query)

#     property fragment:
#         def __get__(self):
#             return slice_component(self.pyurl, self.parsed.ref)

#     property username:
#         def __get__(self):
#             return slice_component(self.pyurl, self.parsed.username)

#     property password:
#         def __get__(self):
#             return slice_component(self.pyurl, self.parsed.password)

#     property port:
#         def __get__(self):
#             return slice_component(self.pyurl, self.parsed.port)

#     # Not in regular urlsplit() !
#     property host:
#         def __get__(self):
#             return slice_component(self.pyurl, self.parsed.host)

#     property netloc:
#         def __get__(self):
#             return build_netloc(self.pyurl, self.parsed)


class SplitResultNamedTuple(tuple):
    """
    There is some repetition in the class,
    we will need to take care of that!
    """

    __slots__ = ()

    def __new__(cls, bytes url, input_scheme, decoded=False):

        cdef Parsed parsed
        cdef Component url_scheme

        if not ExtractScheme(url, len(url), &url_scheme):
            original_url = url.decode('utf-8') if decoded else url
            return stdlib_urlsplit(original_url, input_scheme)

        parse_input_url(url, url_scheme, &parsed)

        def _get_attr(self, prop):
            return extra_attr(self, prop, url, parsed, decoded)

        cls.__getattr__ = _get_attr

        scheme, netloc, path, query, ref = (slice_component(url, parsed.scheme).lower(),
                                            build_netloc(url, parsed),
                                            slice_component(url, parsed.path),
                                            slice_component(url, parsed.query),
                                            slice_component(url, parsed.ref))
        if not scheme and input_scheme:
            scheme = input_scheme.encode('utf-8')

        if decoded:
            return tuple.__new__(cls, (
                <unicode>scheme.decode('utf-8'),
                <unicode>netloc.decode('utf-8'),
                <unicode>path.decode('utf-8'),
                <unicode>query.decode('utf-8'),
                <unicode>ref.decode('utf-8')
            ))

        return tuple.__new__(cls, (scheme, netloc, path, query, ref))

    def geturl(self):
        return stdlib_urlunsplit(self)


class ParsedResultNamedTuple(tuple):
    __slots__ = ()

    def __new__(cls, char * url, input_scheme, decoded=False):

        cdef Parsed parsed
        cdef Component url_scheme

        if not ExtractScheme(url, len(url), &url_scheme):
            original_url = url.decode('utf-8') if decoded else url
            return stdlib_urlparse(original_url, input_scheme)

        parse_input_url(url, url_scheme, &parsed)

        def _get_attr(self, prop):
            return extra_attr(self, prop, url, parsed, decoded, True)

        cls.__getattr__ = _get_attr

        scheme, netloc, path, query, ref = (slice_component(url, parsed.scheme).lower(),
                                            build_netloc(url, parsed),
                                            slice_component(url, parsed.path),
                                            slice_component(url, parsed.query),
                                            slice_component(url, parsed.ref))
        if not scheme and input_scheme:
            scheme = input_scheme.encode('utf-8')

        if scheme in uses_params and b';' in path:
            path, params = _splitparams(path)
        else:
            params = b''

        if decoded:
            return tuple.__new__(cls, (
                <unicode>scheme.decode('utf-8'),
                <unicode>netloc.decode('utf-8'),
                <unicode>path.decode('utf-8'),
                <unicode>params.decode('utf-8'),
                <unicode>query.decode('utf-8'),
                <unicode>ref.decode('utf-8')
            ))

        return tuple.__new__(cls, (scheme, netloc, path, params, query, ref))

    def geturl(self):
        return stdlib_urlunparse(self)

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

def urlparse(url, scheme='', allow_fragments=True):
    """
    This function intends to replace urlparse from urllib
    using urlsplit function from urlparse4 itself.
    Can this function be further enhanced?
    """
    decode = not isinstance(url, bytes)
    url = unicode_handling(url)
    return ParsedResultNamedTuple.__new__(ParsedResultNamedTuple, url, scheme, decode)

def urlsplit(url, scheme='', allow_fragments=True):
    """
    This function intends to replace urljoin from urllib,
    which uses Urlparse class from GURL Chromium
    """
    decode = not isinstance(url, bytes)
    url = unicode_handling(url)
    return SplitResultNamedTuple.__new__(SplitResultNamedTuple, url, scheme, decode)

def urljoin(base, url, allow_fragments=True):
    """
    This function intends to replace urljoin from urllib,
    which uses Resolve function from class GURL of GURL chromium
    """
    str_input = isinstance(base, str)
    if isinstance(url, str) != str_input:
        raise TypeError("Cannot mix str and non-str arguments")

    decode = not (isinstance(base, bytes) and isinstance(url, bytes))
    if allow_fragments and base:
        base, url = unicode_handling(base), unicode_handling(url)
        """
        this part needs to be profiled to see if creating another GURL instance
        here takes more time than expected?
        """
        if not GURL(base).is_valid():
            fallback = stdlib_urljoin(base, url, allow_fragments=allow_fragments)
            if decode:
                return fallback.decode('utf-8')
            return fallback
        joined_url = GURL(base).Resolve(url).spec()

        if decode:
            return joined_url.decode('utf-8')
        return joined_url

    return stdlib_urljoin(base, url, allow_fragments=allow_fragments)

def _safe_ParseResult(parts, encoding='utf8', path_encoding='utf8'):
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
        quote(to_bytes(parts.path, path_encoding), _safe_chars),
        quote(to_bytes(parts.params, path_encoding), _safe_chars),

        # encoding of query and fragment follows page encoding
        # or form-charset (if known and passed)
        quote(to_bytes(parts.query, encoding), _safe_chars),
        quote(to_bytes(parts.fragment, encoding), _safe_chars)
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
    """
    try:
        scheme, netloc, path, params, query, fragment = _safe_ParseResult(
            parse_url(url), encoding=encoding)
    except UnicodeEncodeError as e:
        scheme, netloc, path, params, query, fragment = _safe_ParseResult(
            parse_url(url), encoding='utf8')

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
    uqp = _unquotepath(path)
    path = quote(uqp, _safe_chars) or '/'

    fragment = '' if not keep_fragments else fragment

    # every part should be safe already
    return stdlib_urlunparse((scheme,
                       netloc.lower().rstrip(':'),
                       path,
                       params,
                       query,
                       fragment))

def parse_url(url, encoding=None):
    """Return urlparsed url from the given argument (which could be an already
    parsed url)
    """
    if isinstance(url, tuple):
        return url
    return urlparse(to_unicode(url, encoding))

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
