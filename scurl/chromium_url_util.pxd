from libcpp.string cimport string
from libcpp cimport bool
from mozilla_url_parse cimport Component, Parsed
from chromium_url_canon cimport CharsetConverter
from chromium_url_canon_stdstring cimport StdStringCanonOutput


cdef extern from "../third_party/chromium/url/url_util.h" namespace "url":
    cdef bool IsStandard(const char* spec, const Component& scheme)
    cdef bool Canonicalize(const char* spec,
                           int spec_len,
                           bool trim_path_end,
                           CharsetConverter* charset_converter,
                           StdStringCanonOutput* output,
                           Parsed* output_parsed)
    bool ResolveRelative(const char* base_spec,
                         int base_spec_len,
                         const Parsed& base_parsed,
                         const char* relative,
                         int relative_length,
                         CharsetConverter* charset_converter,
                         StdStringCanonOutput* output,
                         Parsed* output_parsed);
