import
  unittest,
  json,
  jsonpatch,
  strformat,
  options

type TestCase = object
  comment: Option[string]
  doc: JsonNode
  patch: JsonPatch
  expected: Option[JsonNode]
  error: Option[string]
  disabled: Option[bool]


const testDataDir = "tests/data"
# TODO run the test from the tests.json file aswell
proc fromFile(path: string): seq[TestCase] =
  readFile(&"{testDataDir}/{path}")
    .parseJson()
    .to(seq[TestCase])


for file in ["spec_tests.json", "tests.json"]:
  let testCases = fromFile(file)
  for testCase in testCases:
    if testCase.disabled.get(false):
      continue
    test(testCase.comment.get("[no description]")):
      check testCase.expected.isSome == testCase.error.isNone
      try:
        let patchedDoc = testCase.doc.applyPatch(testCase.patch)
        if testCase.error.isSome or testCase.expected.isNone:
          raise newException(Defect,
            &"Should have raised error: {testCase.error.get()}, but returned result {$patchedDoc}")
        let expected = testCase.expected.get()
        check expected == patchedDoc
      except JsonPatchError:
        if testCase.error.isNone:
          raise
