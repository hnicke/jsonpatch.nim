import 
    std / [unittest, json], 
    jsonpatch

test "patch must be an array of something":
  let j = %*{"not": "array"}
  expect JsonPatchParseError:
    discard j.to(JsonPatch)

test "patch operation must have required 'op' field":
  let j = %*[{"path": "/"}]
  expect JsonPatchParseError:
    discard j.to(JsonPatch)

test "patch operation must have required 'path' field":
  let j = %*[{"op": "add"}]
  expect JsonPatchParseError:
    discard j.to(JsonPatch)

test "successful unmarshal and marshal":
  let jsonPatch =  %*
    [
       { "op": "add", "path": "/a/b/c", "value": [ "foo", "bar" ] },
       { "op": "test", "path": "/a/b/c", "value": "foo" },
       { "op": "remove", "path": "/a/b/c" },
       { "op": "replace", "path": "/a/b/c", "value": 42 },
       { "op": "move", "from": "/a/b/c", "path": "/a/b/d" },
       { "op": "copy", "from": "/a/b/d", "path": "/a/b/e" }
    ]
  let patch = jsonPatch.to(JsonPatch)
  let marshalledPatch = %*patch
  check jsonPatch == marshalledPatch
