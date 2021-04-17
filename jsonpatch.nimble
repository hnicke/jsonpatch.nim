import strformat

# Package

version       = "0.1.0"
author        = "Heiko Nickerl"
description   = "Generate and aplies json patches according to RFC 6902"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.4.4"

const testDataUrl = "https://raw.githubusercontent.com/json-patch/json-patch-tests/master"
const testDataDir = "tests/data"

task fetchTestData, "Fetch the latest test data":
    mkDir testDataDir
    for file in ["tests.json", "spec_tests.json"]:
        exec &"curl {testDataUrl}/{file} > {testDataDir}/{file}"