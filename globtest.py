from glob import glob


print(glob("third_party/chromium/url/**/*.cc", recursive=True))
