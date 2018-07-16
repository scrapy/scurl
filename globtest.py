from glob import glob


print(glob("third_party/chromium/base/**/*.cc", recursive=True))
