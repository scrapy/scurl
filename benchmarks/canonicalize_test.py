from timeit import default_timer as timer
import tarfile

import scrapy
import click
import six
from scurl import canonicalize_url
from scrapy.http import HtmlResponse


def main():
    total = 0
    time = 0
    time_canonicalize_url = 0

    tar = tarfile.open("sites.tar.gz")
    urls = []

    for member in tar.getmembers():
        f = tar.extractfile(member)
        html = f.read()
        response = HtmlResponse(url="local", body=html, encoding='utf8')

        links = response.css('a::attr(href)').extract()
        urls.extend(links)

    for url in urls:
        start_canonicalize_url = timer()
        canonicalize_url(url)
        end_canonicalize_url = timer()
        time_canonicalize_url += (end_canonicalize_url - start_canonicalize_url)
        time += (end_canonicalize_url - start_canonicalize_url)

        total += 1

    print("\nTotal number of items extracted = {0}".format(total))
    print("Time spent on canonicalize_url = {0}".format(time_canonicalize_url))
    print("Total time taken = {0}".format(time))
    click.secho("Rate of link extraction : {0} items/second\n".format(
        float(total / time)), bold=True)


if __name__ == "__main__":
    main()
