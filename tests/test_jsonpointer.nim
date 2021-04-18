import
  std / [unittest, json, options],
  jsonpatch / jsonpointer

test "get parent":
  let child = "/a/b".toJsonPointer()
  let parent = "/a".toJsonPointer()
  check parent == child.parent.get

test "get parent":
  let child = "/a".toJsonPointer()
  let parent = "".toJsonPointer()
  check parent == child.parent.get

test "parent of root doesn't exist":
  check "".toJsonPointer().parent.isNone()

test "resolve":
  let expected = %* {"b": "c"}
  let root = %* {"a": expected}
  check expected == root.resolve("/a").get

test "resolve":
  let expected = %* {"c": "d"}
  let root = %* {"a": {"b": expected}}
  check expected == root.resolve("/a/b").get

test "resolve - missing key":
  let root = %* {"a": "b"}
  check root.resolve("/b").isNone

test "resolve root":
  let expected = %* {"a": {"b": "c"}}
  check expected == expected.resolve("").get

test "resolve with array access":
  let expected = %* {"c": "d"}
  let root = %* {"a": [{"b": expected}]}
  check expected == root.resolve("/a/0/b").get

test "resolve with non-existing array index":
  let root = %* {"a": [{"b": "d"}]}
  check root.resolve("/a/1/b").isNone

test "resolve with non-integer array index":
  let root = %* {"a": [{"b": "c"}]}
  expect JsonPointerResolveError:
    discard root.resolve("/a/n/b").isNone

test "resolve using '-' as array index":
  let expected = %* {"b": "c"}
  let root = %* {"a": [0, expected]}
  check expected == root.resolve("/a/-").get


test "resolve parent using '-' as array index, but array is empty":
   let root = %* {"a": []}
   check root.resolve("/a/-/b").isNone
