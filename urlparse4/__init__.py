import six

if six.PY2:
    from urlparse import *
else:
    from urllib.parse import *


_original_urlsplit = urlsplit
_original_urljoin = urljoin
_original_urlparse = urlparse

from cgurl import urlsplit, urljoin, urlparse
"""
TODO: find some way to import parse_url
"""
from canonicalize import canonicalize_url, parse_url
