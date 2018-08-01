import pstats, cProfile
import tarfile
import argparse

from scrapy.http import HtmlResponse

import pyximport
pyximport.install()

import scurl

def run_urlparse(urls):
    for url in urls:
        a = scurl.urlparse(url)

def run_canonicalize(urls):
    for url in urls:
        a = scurl.canonicalize_url(url)

def run_urlsplit(urls):
    for url in urls:
        a = scurl.urlsplit(url)

def main():
    parser = argparse.ArgumentParser(description='Profile cython functions')
    parser.add_argument('--func', default='urlsplit',
                    help='name of the function to profile')
    args = parser.parse_args()

    if args.func == "canonicalize":
        with open('benchmarks/urls/chromiumUrls.txt') as f:

            cProfile.runctx("run_canonicalize(f)", globals(), locals(), "canonicalize_profile.prof")

            s = pstats.Stats("canonicalize_profile.prof")
            s.strip_dirs().sort_stats("time").print_stats()

    elif args.func == "urlsplit":
        with open('benchmarks/urls/chromiumUrls.txt') as f:

            cProfile.runctx("run_urlsplit(f)", globals(), locals(), "urlsplit_profile.prof")

            s = pstats.Stats("urlsplit_profile.prof")
            s.strip_dirs().sort_stats("time").print_stats()

    elif args.func == "urlparse":
        with open('benchmarks/urls/chromiumUrls.txt') as f:

            cProfile.runctx("run_urlparse(f)", globals(), locals(), "urlparse_profile.prof")

            s = pstats.Stats("urlparse_profile.prof")
            s.strip_dirs().sort_stats("time").print_stats()
    else:
        print('the arg is invalid, please enter the name of the function you want to profile')



if __name__ == "__main__":
    main()
