from libcpp cimport bool
from mozilla_url_parse cimport Component, Parsed
from chromium_url_canon_stdstring cimport StdStringCanonOutput


cdef extern from "../third_party/chromium/url/url_canon.h" namespace "url":
    cdef cppclass CanonOutputT:
        pass

    cdef cppclass CharsetConverter:
        CharsetConverter()

    ctypedef CanonOutputT CanonOutput

    cdef bool CanonicalizeHost(const char* spec,
                               const Component& host,
                               StdStringCanonOutput* output,
                               Component* out_host);
    cdef bool CanonicalizePath(const char* spec,
                                const Component& path,
                                StdStringCanonOutput* output,
                                Component* out_path)
    cdef void CanonicalizeQuery(const char* spec,
                                const Component& query,
                                CharsetConverter* converter,
                                StdStringCanonOutput* output,
                                Component* out_query)
    cdef void CanonicalizeRef(const char* spec,
                                const Component& path,
                                StdStringCanonOutput* output,
                                Component* out_path)
