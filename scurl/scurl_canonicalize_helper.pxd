from scurl.mozilla_url_parse cimport Component
from scurl.chromium_url_canon_stdstring cimport StdStringCanonOutput
from scurl.chromium_url_canon cimport CanonicalizePath

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
