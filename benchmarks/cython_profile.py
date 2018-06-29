import pstats, cProfile
import tarfile
import argparse

from scrapy.http import HtmlResponse

import pyximport
pyximport.install()

import cgurl
import urlparse4

def run_canonicalize(urls):
    for url in urls:
        a = urlparse4.canonicalize_url(url)

def run_urlsplit(urls):
    for url in urls:
        a = cgurl.urlsplit(url)

def main():
    parser = argparse.ArgumentParser(description='Profile cython functions')
    parser.add_argument('--func', default='urlsplit',
                    help='name of the function to profile')
    args = parser.parse_args()

    if args.func == "canonicalize":
        tar = tarfile.open("sites.tar.gz")
        urls = []

        for member in tar.getmembers():
            f = tar.extractfile(member)
            html = f.read()
            response = HtmlResponse(url="local", body=html, encoding='utf8')

            links = response.css('a::attr(href)').extract()
            urls.extend(links)


        cProfile.runctx("run_canonicalize(urls)", globals(), locals(), "canonicalize_profile.prof")

        s = pstats.Stats("canonicalize_profile.prof")
        s.strip_dirs().sort_stats("time").print_stats()

    elif args.func == "urlsplit":
        with open('urls/chromiumUrls.txt') as f:

            cProfile.runctx("run_urlsplit(f)", globals(), locals(), "urlsplit_profile.prof")

            s = pstats.Stats("urlsplit_profile.prof")
            s.strip_dirs().sort_stats("time").print_stats()

    else:
        print('the arg is invalid, please enter the name of the function you want to profile')



if __name__ == "__main__":
    main()
