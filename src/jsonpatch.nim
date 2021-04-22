import
  jsonpatch / jsonpointer,
  std / [json, options, strformat, sequtils, strutils]

export jsonpointer.JsonPointerError, jsonpointer.toJsonPointer

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

method apply(op: Operation, doc: JsonNode): JsonNode {.base, locks: "unknown".} =
  assert false, "missing impl: abstract base method"

func patch*(doc: JsonNode, op: Operation): JsonNode =
  result = op.apply(doc)
  assert result != nil


proc abort(op: Operation, msg: string) =
  raise newException(JsonPatchError, &"Failed to apply operation {op[]}: {msg}")

#------------- ADD OPERATION ------------------------#
type AddOperation* = ref object of Operation
  value*: JsonNode

proc newAddOperation(path: JsonPointer, value: JsonNode): AddOperation =
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
      parent.get.elems.insert(op.value, key.idx)
    of JsonObject:
      parent.get.add(key.member, op.value)
  else:
    op.abort("Path does not exist")


#------------- REMOVE OPERATION ------------------------#
type RemoveOperation* = ref object of Operation

proc newRemoveOperation(path: JsonPointer): RemoveOperation =
  if path.isRoot:
    raise newException(JsonPatchError, "path cant point to root")
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

proc newReplaceOperation(path: JsonPointer, value: JsonNode): ReplaceOperation =
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

proc newMoveOperation(path: JsonPointer, fromPath: JsonPointer): MoveOperation =
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

proc newTestOperation(path: JsonPointer, value: JsonNode): TestOperation =
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

proc newCopyOperation(path: JsonPointer, fromPath: JsonPointer): CopyOperation =
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
type
  JsonPatch* = object
    operations: seq[Operation]

func patch*(doc: JsonNode, patch: JsonPatch): JsonNode =
  if len(patch.operations) == 0:
    return doc
  result = patch.operations.foldl(a.patch(b), doc)


proc to*[T: Operation](node: JsonNode, t: typedesc[T]): T =
  case node.kind
  of JObject:
    # path, value, from
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
  result = %* {"op": op.kind, "path": op.path }
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
  for operation in patch.operations:
    let jsonOperation = newJObject()
    for key, value in (%operation).pairs():
      if value.kind != JNull:
        jsonOperation.add(key, value)
    result.add(jsonOperation)
