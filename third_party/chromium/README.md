## Notes on updating the chromium source for SCURL project

Updating the source for the project might be a lot of work. But sometimes there might be a lot of functionality
implemented in the chromium source code that we might miss if we don't update it regularly

Here are the forked repository of the base component and the url component:

+ [base-chromium](https://github.com/scrapy/base-chromium)
+ [url-chromium](https://github.com/scrapy/url-chromium)

Since base component is really large and we might not even need all of the components defined in it, there are a
few functions/files that we need to skip:

+ YieldCurrentThread
+ lock
+ platforms-related components
