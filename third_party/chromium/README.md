## How do we update Chromium source for the Scurl project?

Scurl is built based on Chromium source. Therefore, updating the Chromium source is
sometimes required since there might be some significant changes coming from the
Chromium community.

It might be a lot of work, but this README serves as the notes on how to do it easily.

Here are the forked repository of the base component and the url component:

+ [base-chromium](https://github.com/scrapy/base-chromium)
+ [url-chromium](https://github.com/scrapy/url-chromium)

Since base component is really large and we might not even need all of the components
defined in it, there are a few functions/files that we need to skip:

+ YieldCurrentThread
+ lock
+ platforms-related components


When updating the Chromium source, we will need to start with the **url-chromium**
repository first. For each of the **.cc** file, we will need to include it in
**setup.py**, under the ext_source of **canonicalize** and **cgurl** (this
depends on what kind of functions that **canonicalize** or **cgurl** uses.

For example, if canonicalize_url uses functions from the **url_canon**, and **url_canon**
uses functions from **string16.cc** from **base** component, then you will need to include
all the **.cc** files where those function are defined in the **ext_source**)

This might sound a little bit challenging since how would a person know all the functions
from the **.cc** source files that we need to include in **setup.py**? Fortunately,
there is a way to know which functions that we have not included in **setup.py**.

After compiling the library with `make clean`, `make build_ext`. We will check if Scurl
can be imported successfully with `python -c "import scurl"`. If it fails, the traceback
will tell us what we are missing. Under the `undefined symbol`, it will tell us the name
of the function that we have not defined yet. Usually it will be mixed with some
random characters. It might look something like this `Zxdasdqwbaseaweqstring16awqeqc16len`.
You will see that it has `base`, `string16` and `c16len` keywords. Do a little bit
of searching in `base` component, you will find where that function is defined!

## Customized functions

For the sake of this project, some functions are modified so that Scurl is compatible
with `urllib.parse`. The only point that is worth noticing for now is that `urljoin`
returns the canonicalized result in GURL, and we don't want to do that since `urllib.parse`
urljoin does not canonicalize the result by default.

Therefore, these functions have been modified so that we don't canonicalize the output
of `urljoin`:

+ CanonicalizePartialPath
+ DoResolveRelative
+ DoResolveRelativePath
+ DoPartialPath

In addition, these functions have been added so that we don't have to modify more
functions in GURL (we don't want to mess with that a lot). They are based on the function
`DoCanonicalize` and `DoCanonicalize` is used in a lot of places in GURL code base.

+ ParseInputURL
+ DoCanonicalizeResolveRelative

It will be necessary to notice these functions when we update the Chromium source!

Happy coding! :)
