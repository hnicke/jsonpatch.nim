import strformat

# Package

version = "0.1.0"
author = "Heiko Nickerl"
description = "Generate and apply json patches according to RFC 6902"
license = "MIT"
srcDir = "src"


# Dependencies

requires "nim >= 1.4.6"

const testDataUrl = "https://raw.githubusercontent.com/json-patch/json-patch-tests/master"
const testDataDir = "tests/data"

task updateTestData, "Fetch the latest test data":
  mkDir testDataDir
  for file in ["tests.json", "spec_tests.json"]:
    exec &"curl {testDataUrl}/{file} > {testDataDir}/{file}"

task fmt, "format the codebase":
  exec r"git ls-files . | grep '\.nim$' | xargs nimpretty"
  echo "Formatted source code"

