import 
  std / [unittest, json],
  jsonpatch

test "patch must be an array of something":
  let j = %*{"not": "array"}
  expect JsonPatchError:
    discard j.to(JsonPatch)

test "valid 'add' operation":
  let j = %*{"op": "add", "path": "/", "value": "foo"}
  let op = AddOperation(j.to(Operation))
  check op.path == "/".toJsonPointer
  check op.value == %* "foo"

test "valid 'remove' operation":
  let j = %*{"op": "remove", "path": "/foo"}
  let op = RemoveOperation(j.to(Operation))
  check op.path == "/foo".toJsonPointer

test "valid 'move' operation":
  let j = %*{"op": "move", "path": "/", "from": "/foo"}
  let op = MoveOperation(j.to(Operation))
  check op.path == "/".toJsonPointer
  check op.fromPath == "/foo".toJsonPointer

test "valid 'copy' operation":
  let j = %*{"op": "copy", "path": "/", "from": "/foo"}
  let op = CopyOperation(j.to(Operation))
  check op.path == "/".toJsonPointer
  check op.fromPath == "/foo".toJsonPointer

test "valid 'replace' operation":
  let j = %*{"op": "copy", "path": "/", "from": "/foo"}
  let op = CopyOperation(j.to(Operation))
  check op.path == "/".toJsonPointer
  check op.fromPath == "/foo".toJsonPointer

test "valid 'test' operation":
  let j = %*{"op": "test", "path": "/", "value": "foo"}
  let op = TestOperation(j.to(Operation))
  check op.path == "/".toJsonPointer
  check op.value == %* "foo"


test "operation must have required 'op' field":
  let j = %*[{"path": "/", "value": "foo"}]
  expect JsonPatchError:
    discard j.to(JsonPatch)

test "invalid 'op' field":
  let j = %*[{"op": "invalid", "path": "/", "value": "add"}]
  expect JsonPatchError:
    discard j.to(JsonPatch)


test "operation must have required 'path' field":
  let j = %*[{"op": "add"}]
  expect JsonPatchError:
    discard j.to(JsonPatch)

test "add operation must have required 'value' field":
  let j = %*[{"op": "add", "path": ""}]
  expect JsonPatchError:
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
