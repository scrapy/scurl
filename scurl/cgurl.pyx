from scurl.mozilla_url_parse cimport *
from scurl.chromium_gurl cimport GURL
from scurl.chromium_url_constant cimport *
from scurl.chromium_url_util_internal cimport CompareSchemeComponent
from scurl.chromium_url_util cimport IsStandard, Canonicalize
from scurl.chromium_url_canon cimport CanonicalizePath
from scurl.chromium_url_canon_stdstring cimport StdStringCanonOutput

import six
from six.moves.urllib.parse import urlsplit as stdlib_urlsplit
from six.moves.urllib.parse import urljoin as stdlib_urljoin
from six.moves.urllib.parse import urlunsplit as stdlib_urlunsplit
from six.moves.urllib.parse import urlparse as stdlib_urlparse
from six.moves.urllib.parse import urlunparse as stdlib_urlunparse
import logging

cimport cython
from libcpp.string cimport string
from libcpp cimport bool


logger = logging.getLogger('scurl')

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

cdef string canonicalize_component(char * url, Component parsed_comp, comp_type):
    """
    This function canonicalizes the components of the urls
    Using Chromium GURL canonicalize func
    """
    cdef Component output_comp
    cdef string canonicalized_output = string()
    cdef StdStringCanonOutput * output = new StdStringCanonOutput(&canonicalized_output)
    # CanonicalizeQuery has different way of canonicalize encoded urls
    # so we will use canonicalizePath for now!
    # CanonicalizeQuery(query, query_comp, NULL, output, &out_query)
    is_valid = CanonicalizePath(url, parsed_comp, output, &output_comp)
    output.Complete()

    if comp_type in ('ref', 'query'):
        if canonicalized_output.length() > 0 and canonicalized_output[0] == "/":
            canonicalized_output = canonicalized_output.substr(1)

    return canonicalized_output


cdef class UrlsplitResultAttribute:
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

    @property
    def port(self):
        if not self.port_component:
            return None
        port = self.port_component
        try:
            port = int(self.port_component, 10)
        except ValueError:
            # change to format() to support pypy
            message = 'Port could not be cast to integer value as {}'.format(repr(port))
            raise ValueError(message) from None
        if not ( 0 <= port <= 65535):
            raise ValueError("Port out of range 0-65535")
        return port

    @property
    def username(self):
        if not self.username_component:
            return None
        if self.decode_component:
            return self.username_component.decode('utf-8')
        return self.username_component

    @property
    def password(self):
        if not self.password_component:
            return None
        if self.decode_component:
            return self.password_component.decode('utf-8')
        return self.password_component

    @property
    def hostname(self):
        if not self.hostname_component:
            return None
        hostname = self.hostname_component.lower()
        if len(hostname) > 0 and hostname[:1] == b'[':
            hostname = hostname[1:-1]
        if self.decode_component:
            return hostname.decode('utf-8') or None
        return hostname


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
    """
    There is some repetition in the class,
    we will need to take care of that!
    """

    __slots__ = ()

    def __new__(cls, char * url, input_scheme, decode=False):

        cdef Parsed parsed
        cdef Component url_scheme

        if not ExtractScheme(url, len(url), &url_scheme):
            original_url = url.decode('utf-8') if decode else url
            return stdlib_urlsplit(original_url, input_scheme)

        parse_input_url(url, url_scheme, &parsed)

        # extra attributes for the class
        cls.port_component = slice_component(url, parsed.port)
        cls.username_component = slice_component(url, parsed.username)
        cls.password_component = slice_component(url, parsed.password)
        cls.hostname_component = slice_component(url, parsed.host)
        cls.decode_component = decode


        # scheme needs to be lowered
        # create a func that lowercase all the letters
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
                canonicalize, canonicalize_encoding, decode=False):

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

        # extra attributes for the class
        cls.port_component = slice_component(url, parsed.port)
        cls.username_component = slice_component(url, parsed.username)
        cls.password_component = slice_component(url, parsed.password)
        cls.hostname_component = slice_component(url, parsed.host)
        cls.decode_component = decode

        # encode based on the encoding input
        if canonicalize and canonicalize_encoding != 'utf-8':
            if query:
                try:
                    query = query.decode('utf-8').encode(canonicalize_encoding)
                except UnicodeEncodeError as e:
                    logger.debug('Failed to encode query to the selected encoding!')
            if ref:
                try:
                    ref = ref.decode('utf-8').encode(canonicalize_encoding)
                except UnicodeEncodeError as e:
                    logger.debug('Failed to encode query to the selected encoding!')

        # cdef var cannot be wrapped inside if statement
        cdef Component query_comp = MakeRange(0, len(query))
        cdef Component ref_comp = MakeRange(0, len(ref))
        if canonicalize:
            path = canonicalize_component(url, parsed.path, 'path')
            query = canonicalize_component(query, query_comp, 'query')
            fragment = canonicalize_component(ref, ref_comp, 'ref')

        if decode:
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


cpdef urlparse(url, scheme='', bool allow_fragments=True, bool canonicalize=False,
             canonicalize_encoding='utf-8'):
    """
    This function intends to replace urlparse from urllib
    using urlsplit function from scurl itself.
    Can this function be further enhanced?
    """
    decode = not isinstance(url, bytes)
    url = unicode_handling(url)
    return ParsedResultNamedTuple.__new__(ParsedResultNamedTuple, url, scheme,
                                          canonicalize, canonicalize_encoding, decode)

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
