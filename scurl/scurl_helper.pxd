from scurl.mozilla_url_parse cimport Component, Parsed
from scurl.chromium_url_canon_stdstring cimport StdStringCanonOutput
from scurl.chromium_url_canon cimport CanonicalizePath, CharsetConverter
from scurl.chromium_url_util cimport ResolveRelative

from libcpp.string cimport string


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


cdef inline string resolve_relative(char* base_spec,
                                    int base_spec_len,
                                    Parsed& base_parsed,
                                    char* relative,
                                    int relative_length):
    cdef Parsed joined_output_parsed
    cdef string joined_output = string()
    cdef StdStringCanonOutput * output = new StdStringCanonOutput(&joined_output)
    """
    check if base_spec is treated the same as Resolve() in GURL
    """
    is_valid = ResolveRelative(base_spec, base_spec_len, base_parsed, relative,
                               relative_length, NULL, output, &joined_output_parsed)

    output.Complete()
    return joined_output
