from scurl.mozilla_url_parse cimport Component, Parsed, MakeRange
from scurl.chromium_url_canon_stdstring cimport StdStringCanonOutput
from scurl.chromium_url_canon cimport CanonicalizePath, CharsetConverter, CanonicalizeHost
from scurl.chromium_url_util cimport ResolveRelative

from libcpp.string cimport string
from libcpp cimport bool


cdef inline bytes slice_component(char * url, Component comp):
    if comp.len <= 0:
        return b""

    return url[comp.begin:comp.begin + comp.len]

cdef inline bytes build_netloc(char * url, Parsed parsed):
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

cdef inline string canonicalize_component(char * url, Component parsed_comp):
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


    if canonicalized_output.length() > 0 and canonicalized_output[0] == "/":
        canonicalized_output = canonicalized_output.substr(1)

    return canonicalized_output


cdef inline bool resolve_relative(char* base_spec,
                                    int base_spec_len,
                                    Parsed& base_parsed,
                                    char* relative,
                                    int relative_length,
                                    string* joined_output):
    cdef bytes netloc = build_netloc(base_spec, base_parsed)
    cdef Component netloc_comp_original = MakeRange(0, len(netloc))
    cdef Component netloc_comp
    cdef string canonicalized_netloc = string()
    cdef StdStringCanonOutput * output_netloc = new StdStringCanonOutput(&canonicalized_netloc)
    is_netloc_valid = CanonicalizeHost(netloc, netloc_comp_original, output_netloc, &netloc_comp)
    output_netloc.Complete()

    if not is_netloc_valid:
        return False

    cdef Parsed joined_output_parsed
    cdef StdStringCanonOutput * output = new StdStringCanonOutput(joined_output)

    is_valid = ResolveRelative(base_spec, base_spec_len, base_parsed, relative,
                               relative_length, NULL, output, &joined_output_parsed)

    output.Complete()

    return is_valid
