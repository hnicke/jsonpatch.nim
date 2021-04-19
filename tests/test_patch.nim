import
  jsonpatch,
  std / [unittest, json, strformat, options]

type TestCase = object
  comment: Option[string]
  doc: JsonNode
  patch: JsonNode
  expected: Option[JsonNode]
  error: Option[string]
  disabled: Option[bool]


const testDataDir = "tests/data"
proc fromFile(path: string): seq[TestCase] =
  readFile(&"{testDataDir}/{path}")
    .parseJson()
    .to(seq[TestCase])

const testFiles = ["spec_tests.json", "tests.json"]
# const testFiles = ["spec_tests.json"]
# const testFiles = ["tests.json"]
# const testFiles = ["spec_tests_dev.json"]
for file in testFiles:
  let testCases = fromFile(file)
  for testCase in testCases:
    test(testCase.comment.get("[no description]")):
      if testCase.disabled.get(false):
        skip()
      try:
        let patch = testCase.patch.to(JsonPatch)
        let actualDoc = testCase.doc.patch(patch)
        if testCase.error.isSome:
          raise newException(Defect,
            &"Should have raised error: {testCase.error.get()}, but returned result {$actualDoc}")
        if testCase.expected.isSome:
          let expected = testCase.expected.get()
          check expected == actualDoc
      except:
        if testCase.error.isNone:
          raise
