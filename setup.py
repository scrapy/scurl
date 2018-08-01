from setuptools.extension import Extension
from setuptools import setup, find_packages
import os
from os.path import splitext
import logging
import platform
from glob import glob

VERSION = "0.1.0"
ext_macros = []
logger = logging.getLogger('scurl')

try:
    from Cython.Compiler import Options as CythonOptions
except ImportError as e:
    logger.debug('Cython is not installed on your env.\
                  Please get the latest version of Cython and try again!')

if os.environ.get('CYTHON_TRACE'):
    if platform.python_implementation() != 'PyPy':
        # enable linetrace in Cython
        ext_macros.append(('CYTHON_TRACE', '1'))
        cython_defaults = CythonOptions.get_directive_defaults()
        cython_defaults['linetrace'] = True
        logger.warning('Warning: Enabling line tracing in Cython extension.\
                        This will make the performance of the library less effective!')

cgurl_ext_sources = [
    'scurl/cgurl.pyx',
    'third_party/chromium/base/callback_internal.cc',
    'third_party/chromium/base/at_exit.cc',
    'third_party/chromium/base/lazy_instance_helpers.cc',
    'third_party/chromium/base/strings/utf_string_conversion_utils.cc',
    'third_party/chromium/base/strings/string_piece.cc',
    'third_party/chromium/base/strings/string16.cc',
    'third_party/chromium/base/strings/string_util.cc',
    'third_party/chromium/base/strings/utf_string_conversions.cc',
    'third_party/chromium/base/strings/string_util_constants.cc',
    'third_party/chromium/base/third_party/icu/icu_utf.cc',
    'third_party/chromium/url/gurl.cc',
    'third_party/chromium/url/url_canon.cc',
    'third_party/chromium/url/url_canon_etc.cc',
    # 'third_party/chromium/url/url_canon_icu.cc',
    'third_party/chromium/url/url_canon_filesystemurl.cc',
    'third_party/chromium/url/url_canon_fileurl.cc',
    'third_party/chromium/url/url_canon_host.cc',
    'third_party/chromium/url/url_canon_internal.cc',
    'third_party/chromium/url/url_canon_ip.cc',
    'third_party/chromium/url/url_canon_mailtourl.cc',
    'third_party/chromium/url/url_canon_path.cc',
    'third_party/chromium/url/url_canon_pathurl.cc',
    'third_party/chromium/url/url_canon_query.cc',
    'third_party/chromium/url/url_canon_relative.cc',
    'third_party/chromium/url/url_canon_stdstring.cc',
    'third_party/chromium/url/url_canon_stdurl.cc',
    'third_party/chromium/url/url_constants.cc',
    'third_party/chromium/url/url_parse_file.cc',
    'third_party/chromium/url/url_util.cc',
    'third_party/chromium/url/third_party/mozilla/url_parse.cc',
]

canonicalize_ext_sources = [
    'scurl/canonicalize.pyx',
    'third_party/chromium/base/callback_internal.cc',
    'third_party/chromium/base/at_exit.cc',
    'third_party/chromium/base/lazy_instance_helpers.cc',
    'third_party/chromium/base/strings/utf_string_conversion_utils.cc',
    'third_party/chromium/base/strings/string_piece.cc',
    'third_party/chromium/base/strings/string16.cc',
    'third_party/chromium/base/strings/string_util.cc',
    'third_party/chromium/base/strings/utf_string_conversions.cc',
    'third_party/chromium/base/strings/string_util_constants.cc',
    'third_party/chromium/base/third_party/icu/icu_utf.cc',
    'third_party/chromium/url/url_canon.cc',
    'third_party/chromium/url/url_canon_path.cc',
    'third_party/chromium/url/url_canon_internal.cc',
    'third_party/chromium/url/url_canon_stdstring.cc',
]

extension = [
    Extension(
        name="scurl.cgurl",
        sources=cgurl_ext_sources,
        language="c++",
        extra_compile_args=["-std=gnu++14", "-I./third_party/chromium/",
                            "-fPIC", "-Ofast", "-pthread", "-w", '-DU_COMMON_IMPLEMENTATION'],
        extra_link_args=["-std=gnu++14", "-w"],
        include_dirs=['.'],
        define_macros=ext_macros
    ),
    Extension(
        name="scurl.canonicalize",
        sources=canonicalize_ext_sources,
        language="c++",
        extra_compile_args=["-std=gnu++14", "-I./third_party/chromium/",
                            "-fPIC", "-Ofast", "-pthread", "-w"],
        extra_link_args=["-std=gnu++14", "-w"],
        include_dirs=['.'],
        define_macros=ext_macros
    )
]


if not os.path.isfile("scurl/cgurl.cpp"):
    try:
        from Cython.Build import cythonize
        ext_modules = cythonize(extension, annotate=True)
    except ImportError:
        print("scurl/cgurl.cpp not found and Cython failed to run to recreate it. Please install/upgrade Cython and try again.")
        raise
else:
    ext_modules = extension
    ext_modules[0].sources[0] = "scurl/cgurl.cpp"
    ext_modules[1].sources[0] = "scurl/canonicalize.cpp"

try:
    import pypandoc
    long_description = pypandoc.convert('README.md', 'rst')
except ImportError:
    long_description = open('README.md').read()

setup(
    name="scurl",
    packages=find_packages(exclude=('tests', 'tests.*')),
    version=VERSION,
    description="",
    license="Apache License, Version 2.0",
    url="https://github.com/nctl144/scurl",
    keywords=["urlparse", "urlsplit", "urljoin", "url", "parser", "urlparser", "parsing", "gurl", "cython", "faster", "speed", "performance"],
    platforms='any',
    classifiers=[
        "Programming Language :: Python",
        'Programming Language :: Python :: 2',
        "Programming Language :: Python :: 2.7",
        "Programming Language :: Python :: 3.4",
        "Programming Language :: Python :: 3.5",
        "Programming Language :: Python :: 3.6",
        'Programming Language :: Python :: Implementation :: CPython',
        'Programming Language :: Python :: Implementation :: PyPy',
        "Intended Audience :: Developers",
        "License :: OSI Approved :: Apache Software License",
        "Operating System :: OS Independent",
        "Topic :: Software Development :: Libraries"
    ],
    long_description=long_description,
    ext_modules=ext_modules,
    include_package_data=True,
    zip_safe=False
)
