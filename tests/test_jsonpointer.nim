import
    std / [unittest, json, options],
    jsonpatch / jpointer

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

test "resolve parent":
    let parent = %* {"a": {"b": "c"}}
    let root = parent
    let actualParent = root.resolveParent("/a".toJsonPointer()).get
    check parent == actualParent

test "resolve parent":
   let parent = %* {"b": {"c": "d"}}
   let root = %* {"a": parent}
   let actualParent = root.resolveParent("/a/b".toJsonPointer()).get
   check parent == actualParent

test "root":
    let parent = %* {"a": {"b": "c"}}
    let root = parent
    let actualParent = root.resolveParent("".toJsonPointer()).get
    check parent == actualParent

test "resolve parent with array access":
   let parent = %* {"b": {"c": "d"}}
   let root = %* {"a": [parent]}
   let actualParent = root.resolveParent("/a/0/b".toJsonPointer()).get
   check parent == actualParent

test "resolve parent with non-existing array index":
   let parent = %* {"b": {"c": "d"}}
   let root = %* {"a": [parent]}
   check root.resolveParent("/a/1/b".toJsonPointer()).isNone

test "resolve parent with non-integer array index":
   let parent = %* {"b": {"c": "d"}}
   let root = %* {"a": [parent]}
   expect JsonPointerResolveError:
    discard root.resolveParent("/a/n/b".toJsonPointer()).isNone

test "resolve parent using '-' as array index":
   let parent = %* {"b": {"c": "d"}}
   let root = %* {"a": [0, parent]}
   check parent == root.resolveParent("/a/-/b".toJsonPointer()).get


test "resolve parent using '-' as array index, but array is empty":
   let root = %* {"a": []}
   check root.resolveParent("/a/-/b".toJsonPointer()).isNone

test "resolve parent of":
   let root = %* {}
   check root.resolveParent("".toJsonPointer()).isNone
