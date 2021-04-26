##[
This module implements JSON Patch according to [RFC 6902](https://tools.ietf.org/html/rfc6902).
]##

import
  jsonpatch / jsonpointer,
  std / [json, options, strformat, sequtils, strutils, sets]

export
  jsonpointer.JsonPointerError,
  jsonpointer.toJsonPointer

type
  JsonPatchError* = object of CatchableError

  OperationKind* {.pure.} = enum
    Add = "add"
    Remove = "remove"
    Replace = "replace"
    Move = "move"
    Copy = "copy"
    Test = "test"


#------------- BASE OPERATION ------------------------#
type Operation* = ref object of RootObj
  kind*: OperationKind
  path*: JsonPointer

method apply(op: Operation, doc: JsonNode): JsonNode {.base,
    locks: "unknown".} =
  assert false, "missing impl: abstract base method"

func patch*(doc: JsonNode, op: Operation): JsonNode =
  ## Apply patch `operation` to source document `doc`.
  runnableExamples:
    import json
    let src = %* {"foo": "bar"}
    let operation = newReplaceOperation("/foo".toJsonPointer, %* "baz")
    let dst = %* {"foo": "baz"}
    assert dst == src.patch(operation)
  result = op.apply(doc)
  assert result != nil

proc abort(op: Operation, msg: string) =
  raise newException(JsonPatchError, &"Failed to apply operation {op[]}: {msg}")

#------------- ADD OPERATION ------------------------#
type AddOperation* = ref object of Operation
  value*: JsonNode

proc newAddOperation*(path: JsonPointer, value: JsonNode): AddOperation =
  new result
  result.kind = Add
  result.path = path
  result.value = value

method apply(op: AddOperation, doc: JsonNode): JsonNode =
  result = doc
  if op.path.isRoot:
    return op.value
  let parent = doc.resolve(op.path.parent.get)
  if parent.isSome:
    let key = parent.get.parseChildKey(op.path.leafSegment.get)
    case key.kind
    of JsonArray:
      if key.idx <= parent.get.elems.len:
        parent.get.elems.insert(op.value, key.idx)
      else:
        op.abort(&"Invalid array index '{key.idx}'")
    of JsonObject:
      parent.get.add(key.member, op.value)
  else:
    op.abort("Path does not exist")


#------------- REMOVE OPERATION ------------------------#
type RemoveOperation* = ref object of Operation

proc newRemoveOperation*(path: JsonPointer): RemoveOperation =
  if path.isRoot:
    raise newException(JsonPatchError, "path of remove operation must not point to root")
  new result
  result.kind = Remove
  result.path = path

method apply(op: RemoveOperation, doc: JsonNode): JsonNode =
  result = doc
  if op.path.isRoot:
    op.abort("Can not remove top level node")
  let parent = doc.resolve(op.path.parent.get)
  if parent.isSome:
    let key = parent.get.parseChildKey(op.path.leafSegment.get)
    case key.kind
    of JsonObject:
      try:
        parent.get.delete(key.member)
      except KeyError:
        op.abort("Trying to remove nonexistent key")
    of JsonArray:
      if key.idx < parent.get.elems.len:
        parent.get.elems.delete(key.idx)
      else:
        op.abort(&"Trying to remove nonexistent index ${key.idx}")
  else:
    op.abort("node at path does not exist")


#------------- REPLACE OPERATION ------------------------#
type ReplaceOperation* = ref object of Operation
  value*: JsonNode

proc newReplaceOperation*(path: JsonPointer,
    value: JsonNode): ReplaceOperation =
  new result
  result.kind = Replace
  result.path = path
  result.value = value

method apply(op: ReplaceOperation, doc: JsonNode): JsonNode =
  if op.path.isRoot:
    return op.value
  else:
    return doc
      .patch(newRemoveOperation(path = op.path))
      .patch(newAddOperation(path = op.path, value = op.value))


#------------- MOVE OPERATION ------------------------#
type MoveOperation* = ref object of Operation
  fromPath*: JsonPointer

proc newMoveOperation*(path: JsonPointer,
    fromPath: JsonPointer): MoveOperation =
  new result
  result.kind = Move
  result.path = path
  result.fromPath = fromPath

method apply(op: MoveOperation, doc: JsonNode): JsonNode =
  let node = doc.resolve(op.fromPath)
  if node.isNone:
    op.abort("node at path does not exist")
  result = doc
    .patch(newRemoveOperation(path = op.fromPath))
    .patch(newAddOperation(path = op.path, value = node.get))


#------------- TEST OPERATION ------------------------#
type TestOperation* = ref object of Operation
  value*: JsonNode

proc newTestOperation*(path: JsonPointer, value: JsonNode): TestOperation =
  new result
  result.kind = Test
  result.path = path
  result.value = value

method apply(op: TestOperation, doc: JsonNode): JsonNode =
  result = doc
  let node = doc.resolve(op.path)
  if node.get(nil) != op.value:
    op.abort("Test failed")


#------------- COPY OPERATION ------------------------#
type CopyOperation* = ref object of Operation
  fromPath*: JsonPointer

proc newCopyOperation*(path: JsonPointer,
    fromPath: JsonPointer): CopyOperation =
  new result
  result.kind = Copy
  result.path = path
  result.fromPath = fromPath

method apply(op: CopyOperation, doc: JsonNode): JsonNode =
  let node = doc.resolve(op.fromPath)
  if node.isNone:
    op.abort("node at from does not exist")
  result = doc.patch(newAddOperation(path = op.path, value = node.get))


#------------- JSON PATCH ------------------------#
type JsonPatch* = object
  operations: seq[Operation]

proc initJsonPatch*(operations: seq[Operation]): JsonPatch =
  JsonPatch(operations: operations)

proc initJsonPatch*(operations: varargs[Operation]): JsonPatch =
  JsonPatch(operations: @operations)

func len*(p: JsonPatch): Natural =
  ## Returns the number of operations of patch `p`.
  return p.operations.len

func patch*(doc: JsonNode, operations: seq[Operation]): JsonNode =
  ##[
  Applies sequence of `operations` to `doc`.

  The operations are applied in the order they appear in the sequence.
  ]##
  if operations.len == 0:
    return doc
  result = operations.foldl(a.patch(b), doc)

func patch*(doc: JsonNode, patch: JsonPatch): JsonNode =
  ##[
  Applies `patch` to `doc` and returns the resulting JSON document.
  ]##
  runnableExamples:
    import json
    let src = %* {"foo": "bar"}
    let dst = %* {"foo": "baz"}
    let patch = src.diff(dst)
    assert dst == src.patch(patch)
  return doc.patch(patch.operations)

func recursiveDiff(src: JsonNode, dst: JsonNode, root: JsonPointer): seq[Operation]

func recursiveDiff(src: seq[JsonNode], dst: seq[JsonNode],
    root: JsonPointer): seq[Operation] =
  var src = src
  var dst = dst
  var idx = 0
  while idx < max(src.len, dst.len):
    block handleItem:
      # handle appending to array
      if idx > high(src):
        src.add(dst[idx])
        result.add(newAddOperation(root / $idx, dst[idx]))
        inc idx
        break handleItem

      # handle removal at end of array
      if idx > high(dst):
        src.delete(idx)
        result.add(newRemoveOperation(root / $idx))
        break handleItem

      # skip elements with no change
      if dst[idx] == src[idx]:
        # nothing to do
        inc idx
        break handleItem

      # handle inserts
      # TODO is it worth going through the whole array? How probable are inserts of many items?
      # this optimization assumes that most array items are unique
      for lookaheadIdx in idx..high(dst):
        if dst[lookaheadIdx] == src[idx]:
          src.insert(dst[idx..<lookaheadIdx], idx)
          for insertIdx in idx..<lookaheadIdx:
            result.add(newAddOperation(root / $insertIdx, dst[insertIdx]))
          inc(idx, (lookaheadIdx - idx))
          break handleItem

      # fallback
      result = result & recursiveDiff(src[idx], dst[idx], root / $idx)
      src[idx] = dst[idx]
      inc idx


func recursiveDiff(src: JsonNode, dst: JsonNode, root: JsonPointer): seq[Operation] =
  case src.kind
  of JObject:
    case dst.kind
    of JObject:
      # TODO maybe use pairs instead of keys + lookup
      let keys = src.keys.toSeq().toHashSet() + dst.keys.toSeq().toHashSet()
      for key in keys:
        let path = root / key
        if key in src and key notin dst:
          result.add(newRemoveOperation(path))
        elif key in dst and key notin src:
          result.add(newAddOperation(path, dst[key]))
        else:
          result = result & recursiveDiff(src[key], dst[key], root / key)
    else:
      result.add(newReplaceOperation(root, dst))
  of JArray:
    case dst.kind
    of JArray:
      # TODO using root is incorrect
      result = result & recursiveDiff(src.elems, dst.elems, root)
    else:
      result.add(newReplaceOperation(root, dst))
  else:
    if src != dst:
      result.add(newReplaceOperation(root, dst))

func diff*(src: JsonNode, dst: JsonNode): JsonPatch =
  ## Diffs the JSON document `src` with `dst` and returns the resulting JSON patch.
  runnableExamples:
    import json
    let src = %* {"foo": "bar"}
    let dst = %* {"foo": "baz"}
    let patch = src.diff(dst)
    assert dst == src.patch(patch)
  return initJsonPatch(recursiveDiff(src, dst, "".toJsonPointer))


#------------- MARSHALLING ------------------------#
proc to*[T: Operation](node: JsonNode, t: typedesc[T]): T =
  case node.kind
  of JObject:
    let op = parseEnum[OperationKind](node["op"].getStr())
    let path = node["path"].to(JsonPointer)
    case op
    of Add:
      let value = node["value"]
      return newAddOperation(path, value)
    of Remove:
      return newRemoveOperation(path)
    of Move:
      let fromPath = node["from"].to(JsonPointer)
      return newMoveOperation(path, fromPath)
    of Copy:
      let fromPath = node["from"].to(JsonPointer)
      return newCopyOperation(path, fromPath)
    of Replace:
      let value = node["value"]
      return newReplaceOperation(path, value)
    of Test:
      let value = node["value"]
      return newTestOperation(path, value)
  else:
    raise newException(JsonPatchError, &"Operation must be array, but was {node.kind}")


proc to*[T: JsonPatch](node: JsonNode, t: typedesc[T]): T =
  try:
    case node.kind
    of JArray:
      let operations = node
        .mapIt(it.to(Operation))
      result = JsonPatch(operations: operations)
    else:
      raise newException(JsonPatchError,
          &"Json patch must be an array, but was '{node.kind}'")
  except KeyError, ValueError:
    raise newException(JsonPatchError, "Invalid json patch: " &
        getCurrentExceptionMsg())

proc `%`*(op: Operation): JsonNode =
  result = %* {"op": op.kind, "path": op.path}
  case op.kind
  of Add:
    result["value"] = AddOperation(op).value
  of Replace:
    result["value"] = ReplaceOperation(op).value
  of Move:
    result["from"] = newJString($MoveOperation(op).fromPath)
  of Test:
    result["value"] = TestOperation(op).value
  of Copy:
    result["from"] = newJString($CopyOperation(op).fromPath)
  else: discard

proc `%`*(patch: JsonPatch): JsonNode =
  result = newJArray()
  result.elems = patch.operations.mapIt(%*it)
