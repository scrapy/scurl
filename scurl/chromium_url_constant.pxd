# although this file is not needed, but having these variables is good just in case

from libcpp.string cimport string
from libcpp cimport bool
from mozilla_url_parse cimport Component, Parsed


cdef extern from "../third_party/chromium/url/url_constants.h" namespace "url":

    extern const char kAboutBlankURL[];

    extern const char kAboutScheme[];
    extern const char kBlobScheme[];

    extern const char kContentScheme[];
    extern const char kDataScheme[];
    extern const char kFileScheme[];
    extern const char kFileSystemScheme[];
    extern const char kFtpScheme[];
    extern const char kGopherScheme[];
    extern const char kHttpScheme[];
    extern const char kHttpsScheme[];
    extern const char kJavaScriptScheme[];
    extern const char kMailToScheme[];
    extern const char kWsScheme[];
    extern const char kWssScheme[];

    extern const char kStandardSchemeSeparator[];
