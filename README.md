# SCURL

[![Build Status](https://travis-ci.org/nctl144/scurl.svg?branch=master)](https://travis-ci.org/nctl144/scurl)
[![codecov](https://codecov.io/gh/nctl144/scurl/branch/master/graph/badge.svg)](https://codecov.io/gh/nctl144/scurl)


## About SCURL

First of all, we give special thanks to urlparse4 for being the repo that this library is based on
and gurl-cython for being the inspiration library for this project!

Scurl is a library that is meant to replace some functions in urllib, such as urlparse,
urlsplit and urljoin. It is built using the Chromium urlparse source, called GURL and
Cython wrapper.

In addition, this library is built to support the Scrapy project (hence the name SCURL).
Therefore, an additional function is built, which is canonicalize_url. It uses the
canonicalize function from GURL to canonicalize the path, fragment and query of the urls.

Since the library is built based on Chromium source, the performance is greatly
increased. The performance of urlparse, urlsplit and urljoin is 2-3 times faster than
the urllib. It was faster at the beginning but we need to handle edge cases so the
library can conform to the urllib requirements (because we want it to resemble urllib as
much as we can so we don't change the nature of the Scrapy project).

At the moment, we have the tests from urllib and w3lib for all of those functions that
are supported in SCURL. Nearly all the tests from urllib have passed (we are still
working on passing all the tests), and all the tests from w3lib have passed.

Any feedback will be highly appreciated! :)


## Supported functions

Since scurl meant to replace those functions in urllib, these are supported by SCURL
+ urlparse
+ urljoin
+ urlsplit


## Installation

SCURL has not been deployed to pypi yet. Currently the only way to install SCURL is
cloning this repository

```
git clone https://github.com/nctl144/scurl
cd scurl
pip install -r requirements.txt
make clean
make build_ext
make install
```


## Notes

Some test cases from w3lib have been modified to conform to the way Chromium GURL parses
urls. In detail, url paths are usually lowercased since GURL is the urlparser of a browser.


## Profiling

Scurl repository has the built-in profiling tool, which you can turn on by adding this lines to the
top of the `*.pyx` files in `scurl/scurl`:
```
# cython: profile=True
```
Then you can run `python benchmarks/cython_profile.py --func [function-name]` to get the
cprofiling result. Currently, SCURL supports profiling `urlparse`, `urlsplit` and `canonicalize`.


## Feedback

Again, any feedback is highly appreciated :) Please feel free to submit any
error/feedback in the repository issue tab!
