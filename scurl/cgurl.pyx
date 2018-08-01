from scurl.mozilla_url_parse cimport (ParseStandardURL, ParseFileURL, ParseMailtoURL,
                                      ParseFileSystemURL, ParsePathURL, ExtractScheme,
                                      Parsed, Component)
from scurl.chromium_gurl cimport GURL
from scurl.chromium_url_constant cimport kFileScheme, kFileSystemScheme, kMailToScheme
from scurl.chromium_url_util_internal cimport CompareSchemeComponent
from scurl.chromium_url_util cimport IsStandard
from scurl.scurl_canonicalize_helper cimport canonicalize_component

import six
from six.moves.urllib.parse import urlsplit as stdlib_urlsplit
from six.moves.urllib.parse import urljoin as stdlib_urljoin
from six.moves.urllib.parse import urlunsplit as stdlib_urlunsplit
from six.moves.urllib.parse import urlparse as stdlib_urlparse
from six.moves.urllib.parse import urlunparse as stdlib_urlunparse

from libcpp.string cimport string
from libcpp cimport bool


cdef char * uses_params[15]
uses_params[:] = ['', 'ftp', 'hdl',
                   'prospero', 'http', 'imap',
                   'https', 'shttp', 'rtsp',
                   'rtspu', 'sip', 'sips',
                   'mms', 'sftp', 'tel']

cdef bytes slice_component(char * url, Component comp):
    if comp.len <= 0:
        return b""

    return url[comp.begin:comp.begin + comp.len]

cdef bytes build_netloc(char * url, Parsed parsed):
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


cdef char * unicode_handling(str):
    """
    This function handles the unicode string and converts it to bytes
    which enables functions to receive unicode-type url as the input
    """
    cdef bytes bytes_str
    if isinstance(str, unicode):
        bytes_str = <bytes>(<unicode>str).encode('utf8')
    else:
        bytes_str = <bytes>str
    return bytes_str

cdef void parse_input_url(char * url, Component url_scheme, Parsed * parsed):
    """
    This function parses the input url using GURL url_parse
    """
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


cdef class _NetlocResultMixinBase(object):
    """Shared methods for the parsed result objects containing a netloc element"""
    __slots__ = ()

    @property
    def username(self):
        return self._userinfo[0]

    @property
    def password(self):
        return self._userinfo[1]

    @property
    def hostname(self):
        hostname = self._hostinfo[0]
        if not hostname:
            return None
        # Scoped IPv6 address may have zone info, which must not be lowercased
        # like http://[fe80::822a:a8ff:fe49:470c%tESt]:1234/keys
        separator = '%' if isinstance(hostname, str) else b'%'
        hostname, percent, zone = hostname.partition(separator)
        return hostname.lower() + percent + zone

    @property
    def port(self):
        port = self._hostinfo[1]
        if port is not None:
            try:
                port = int(port, 10)
            except ValueError:
                message = 'Port could not be cast to integer value as {}'.format(port)
                raise ValueError(message) from None
            if not ( 0 <= port <= 65535):
                raise ValueError("Port out of range 0-65535")
        return port


cdef class _NetlocResultMixinStr(_NetlocResultMixinBase):
    __slots__ = ()

    @property
    def _userinfo(self):
        netloc = self[1]
        char_at, char_colon = '@', ':'
        if isinstance(netloc, bytes):
            char_at, char_colon = b'@', b':'

        userinfo, have_info, hostinfo = netloc.rpartition(char_at)
        if have_info:
            username, have_password, password = userinfo.partition(char_colon)
            if not have_password:
                password = None
        else:
            username = password = None
        return username, password

    @property
    def _hostinfo(self):
        netloc = self[1]
        char_at, char_leftsquare, char_rightsquare, char_colon = '@', '[', ']', ':'
        if isinstance(netloc, bytes):
            char_at, char_leftsquare, char_rightsquare, char_colon = b'@', b'[', b']', b':'

        _, _, hostinfo = netloc.rpartition(char_at)
        _, have_open_br, bracketed = hostinfo.partition(char_leftsquare)
        if have_open_br:
            hostname, _, port = bracketed.partition(char_rightsquare)
            _, _, port = port.partition(char_colon)
        else:
            hostname, _, port = hostinfo.partition(char_colon)
        if not port:
            port = None
        return hostname, port


cdef class UrlsplitResultAttribute(_NetlocResultMixinStr):
    __slots__ = ()

    @property
    def scheme(self):
        return self[0]

    @property
    def netloc(self):
        return self[1]

    @property
    def path(self):
        return self[2]

    @property
    def query(self):
        return self[3]

    @property
    def fragment(self):
        return self[4]


cdef class UrlparseResultAttribute(UrlsplitResultAttribute):
    __slots__ = ()

    @property
    def path(self):
        return self[2]

    @property
    def params(self):
        return self[3]

    @property
    def query(self):
        return self[4]

    @property
    def fragment(self):
        return self[5]


class SplitResultNamedTuple(tuple, UrlsplitResultAttribute):
    __slots__ = ()

    def __new__(cls, char * url, input_scheme, decode=False):

        cdef Parsed parsed
        cdef Component url_scheme

        if not ExtractScheme(url, len(url), &url_scheme):
            original_url = url.decode('utf-8') if decode else url
            return stdlib_urlsplit(original_url, input_scheme)

        parse_input_url(url, url_scheme, &parsed)

        scheme, netloc, path, query, ref = (slice_component(url, parsed.scheme).lower(),
                                            build_netloc(url, parsed),
                                            slice_component(url, parsed.path),
                                            slice_component(url, parsed.query),
                                            slice_component(url, parsed.ref))

        if not scheme and input_scheme:
            scheme = input_scheme.encode('utf-8')

        if decode:
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


class ParsedResultNamedTuple(tuple, UrlparseResultAttribute):
    __slots__ = ()

    def __new__(cls, char * url, input_scheme,
                canonicalize, decode=False):

        cdef Parsed parsed
        cdef Component url_scheme

        if not ExtractScheme(url, len(url), &url_scheme):
            original_url = url.decode('utf-8') if decode else url
            return stdlib_urlparse(original_url, input_scheme)

        parse_input_url(url, url_scheme, &parsed)

        scheme, netloc, path, query, ref = (slice_component(url, parsed.scheme).lower(),
                                            build_netloc(url, parsed),
                                            slice_component(url, parsed.path),
                                            slice_component(url, parsed.query),
                                            slice_component(url, parsed.ref))
        if not scheme and input_scheme:
            scheme = input_scheme.encode('utf-8')

        cdef bool in_uses_params = False
        for param in uses_params:
            if param == scheme:
                in_uses_params = True
        if in_uses_params and b';' in path:
            path, params = _splitparams(path)
        else:
            params = b''

        # if canonicalize is set to true, then we will need to convert it to unicode
        if decode or canonicalize:
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


cpdef urlparse(url, scheme='', bool allow_fragments=True, bool canonicalize=False):
    """
    This function intends to replace urlparse from urllib
    using urlsplit function from scurl itself.
    Can this function be further enhanced?
    """
    decode = not isinstance(url, bytes)
    url = unicode_handling(url)
    return ParsedResultNamedTuple.__new__(ParsedResultNamedTuple, url, scheme,
                                          canonicalize, decode)

cpdef urlsplit(url, scheme='', bool allow_fragments=True):
    """
    This function intends to replace urljoin from urllib,
    which uses Urlparse class from GURL Chromium
    """
    decode = not isinstance(url, bytes)
    url = unicode_handling(url)
    return SplitResultNamedTuple.__new__(SplitResultNamedTuple, url, scheme, decode)

cpdef urljoin(base, url, bool allow_fragments=True):
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
        GURL_container = new GURL(base)
        # GURL will mark urls such as #, http:/// as invalid
        if not GURL_container.is_valid():
            fallback = stdlib_urljoin(base, url, allow_fragments=allow_fragments)
            if decode:
                return fallback.decode('utf-8')
            return fallback

        joined_url = GURL_container.Resolve(url).spec()

        if decode:
            return joined_url.decode('utf-8')
        return joined_url

    return stdlib_urljoin(base, url, allow_fragments=allow_fragments)
