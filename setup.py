from setuptools.extension import Extension
from setuptools import setup, find_packages
import os
from os.path import splitext
import logging

VERSION = "0.1.0"
ext_macros = []
logger = logging.getLogger('scurl')

try:
    from Cython.Compiler import Options as CythonOptions
except ImportError as e:
    pass

try:
    if (os.environ['TOX'] == 'true' and
        os.environ['TOX_PYPY'] != 'true'):
        # enable linetrace in Cython
        ext_macros.append(('CYTHON_TRACE', '1'))
        cython_defaults = CythonOptions.get_directive_defaults()
        cython_defaults['linetrace'] = True
        logger.warning('Warning: Enabling line tracing in Cython extension.\
                        This will make the performance of the library less effective!')
except KeyError:
    pass

extension = [
    Extension(
        name="scurl.cgurl",
        sources=["scurl/cgurl.pyx",
                 "vendor/gurl/base/third_party/icu/icu_utf.cc",
                 "vendor/gurl/base/strings/string16.cc",
                 "vendor/gurl/base/strings/string_piece.cc",
                 "vendor/gurl/base/strings/string_util.cc",
                 "vendor/gurl/base/strings/utf_string_conversions.cc",
                 "vendor/gurl/base/strings/utf_string_conversion_utils.cc",
                 "vendor/gurl/url/gurl.cc",
                 "vendor/gurl/url/url_canon_etc.cc",
                 "vendor/gurl/url/url_canon_filesystemurl.cc",
                 "vendor/gurl/url/url_canon_fileurl.cc",
                 "vendor/gurl/url/url_canon_host.cc",
                 "vendor/gurl/url/url_canon_internal.cc",
                 "vendor/gurl/url/url_canon_ip.cc",
                 "vendor/gurl/url/url_canon_mailtourl.cc",
                 "vendor/gurl/url/url_canon_path.cc",
                 "vendor/gurl/url/url_canon_pathurl.cc",
                 "vendor/gurl/url/url_canon_query.cc",
                 "vendor/gurl/url/url_canon_relative.cc",
                 "vendor/gurl/url/url_canon_stdstring.cc",
                 "vendor/gurl/url/url_canon_stdurl.cc",
                 "vendor/gurl/url/url_constants.cc",
                 "vendor/gurl/url/url_parse_file.cc",
                 "vendor/gurl/url/url_util.cc",
                 "vendor/gurl/url/third_party/mozilla/url_parse.cc"
                 ],
        language="c++",
        extra_compile_args=["-std=gnu++0x", "-I./vendor/gurl/",
                            "-fPIC", "-Ofast", "-pthread", "-w"],
        extra_link_args=["-std=gnu++0x", "-w"],
        include_dirs=['.'],
        define_macros=ext_macros
    ),
    Extension(
        name="scurl.canonicalize",
        sources=["scurl/canonicalize.pyx"],
        language="c++",
        extra_compile_args=["-std=gnu++0x", "-I./vendor/gurl/",
                            "-fPIC", "-Ofast", "-pthread", "-w"],
        extra_link_args=["-std=gnu++0x", "-w"],
        include_dirs=['.'],
        define_macros=ext_macros
    )
]


if not os.path.isfile("scurl/cgurl.cpp"):
    try:
        from Cython.Build import cythonize
        ext_modules = cythonize(extension, annotate=True)
    except:
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
