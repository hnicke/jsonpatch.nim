import
  unittest,
  json,
  jsonpatch,
  strformat,
  options

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


for file in ["spec_tests.json", "tests.json"]:
  let testCases = fromFile(file)
  for testCase in testCases:
    test(testCase.comment.get("[no description]")):
      if testCase.disabled.get(false):
        skip()
      check testCase.expected.isSome == testCase.error.isNone
      try:
        let patch = testCase.patch.to(JsonPatch)
        let patchedDoc = testCase.doc.applyPatch(patch)
        if testCase.error.isSome or testCase.expected.isNone:
          raise newException(Defect,
            &"Should have raised error: {testCase.error.get()}, but returned result {$patchedDoc}")
        let expected = testCase.expected.get()
        check expected == patchedDoc
      except:
        if testCase.error.isNone:
          raise
