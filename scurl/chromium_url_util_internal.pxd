from libcpp.string cimport string
from libcpp cimport bool
from mozilla_url_parse cimport Component, Parsed


cdef extern from "../third_party/chromium/url/url_util_internal.h" namespace "url":
    cdef bool CompareSchemeComponent(const char* spec,
                                     const Component& component,
                                     const char* compare_to)
