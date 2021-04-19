import
  jsonpatch / jsonpointer,
  std / [json, options, strformat, sequtils]

type

  OperationKind {.pure.} = enum
    Add = "add"
    Remove = "remove"
    Replace = "replace"
    Move = "move"
    Copy = "copy"
    Test = "test"

  # maybe use objects variants once https://github.com/nim-lang/RFCs/issues/368 is implemented
  OperationTransport = object
    ## Only used for json marshalling
    op: OperationKind
    path: string
    value: Option[JsonNode]
    `from`: Option[string]

  Operation = ref object of RootObj
    path: JsonPointer

type AddOperation = ref object of Operation
  value: JsonNode

proc newAddOperation(path: JsonPointer, value: JsonNode): AddOperation =
  new result
  result.path = path
  result.value = value

type RemoveOperation = ref object of Operation

proc newRemoveOperation(path: JsonPointer): RemoveOperation =
  new result
  result.path = path

type ReplaceOperation = ref object of Operation
  value: JsonNode

proc newReplaceOperation(path: JsonPointer, value: JsonNode): ReplaceOperation =
  new result
  result.path = path
  result.value = value

type MoveOperation = ref object of Operation
  fromPath: JsonPointer

proc newMoveOperation(path: JsonPointer, fromPath: JsonPointer): MoveOperation =
  new result
  result.path = path
  result.fromPath = fromPath

type TestOperation = ref object of Operation
  value: JsonNode

proc newTestOperation(path: JsonPointer, value: JsonNode): TestOperation =
  new result
  result.path = path
  result.value = value

type CopyOperation = ref object of Operation
  value: JsonNode
  fromPath: JsonPointer

proc newCopyOperation(path: JsonPointer, fromPath: JsonPointer): CopyOperation =
  new result
  result.path = path
  result.fromPath = fromPath

type
  JsonPatch* = object
    operations: seq[Operation]

  JsonPatchError* = object of CatchableError
  InvalidJsonPatchError* = object of CatchableError


func toModel(op: OperationTransport): Operation =
  func abort(msg: string) =
    raise newException(InvalidJsonPatchError, &"Invalid operation {op}: {msg}")
  let path = op.path.toJsonPointer
  case op.op
  of Add:
    if op.value.isNone: abort("missing 'value'")
    result = newAddOperation(path = path, value = op.value.get)
  of Remove:
    if path.pointsToRoot: abort("path cant point to root")
    result = newRemoveOperation(path = op.path.toJsonPointer)
  of Replace:
    if op.value.isNone: abort("missing 'value'")
    result = newReplaceOperation(path = path, op.value.get)
  of Move:
    if op.`from`.isNone: abort("missing 'from'")
    result = newMoveOperation(path = path,
        fromPath = op.`from`.get.toJsonPointer)
  of Test:
    if op.value.isNone: abort("missing 'value'")
    result = newTestOperation(path = path, value = op.value.get)
  of Copy:
    if op.`from`.isNone: abort("missing 'from'")
    result = newCopyOperation(path = path,
        fromPath = op.`from`.get.toJsonPointer)


proc to*[T: JsonPatch](node: JsonNode, t: typedesc[T]): T =
  try:
    case node.kind
    of JArray:
      let operations = node
        .to(seq[OperationTransport])
        .map(toModel)
      result = JsonPatch(operations: operations)
    else:
      raise newException(InvalidJsonPatchError,
          &"Json patch must be an array, but was '{node.kind}'")
  except KeyError:
    raise newException(InvalidJsonPatchError, getCurrentExceptionMsg())


proc `%`*(patch: JsonPatch): JsonNode =
  result = newJArray()
  for operation in patch.operations:
    let jsonOperation = newJObject()
    for key, value in (%operation).pairs():
      if value.kind != JNull:
        jsonOperation.add(key, value)
    result.add(jsonOperation)

proc abort(op: Operation, msg: string) =
  raise newException(JsonPatchError, &"Failed to apply operation {op[]}: {msg}")

method apply(op: Operation, doc: JsonNode): JsonNode {.base.} =
  assert false, "missing impl: abstract base method"

func patch*(doc: JsonNode, op: Operation): JsonNode =
  result = op.apply(doc)
  assert result != nil

func patch*(doc: JsonNode, patch: JsonPatch): JsonNode =
  if len(patch.operations) == 0:
    return doc
  result = patch.operations.foldl(a.patch(b), doc)

method apply(op: AddOperation, doc: JsonNode): JsonNode =
  result = doc
  if op.path.pointsToRoot():
    return op.value
  let parent = doc.resolve(op.path.parent.get)
  if parent.isSome:
    let key = parent.get.parseChildKey(op.path.leafSegment)
    case key.kind
    of JArray:
      parent.get.elems.insert(op.value, key.idx)
    of JObject:
      parent.get.add(key.member, op.value)
    else:
      # TODO implement
      raise newException(Defect, "not implemented")
  else:
    op.abort("Path does not exist")

method apply(op: RemoveOperation, doc: JsonNode): JsonNode =
  result = doc
  if op.path.pointsToRoot:
    op.abort("Can not remove top level node")
  let parent = doc.resolve(op.path.parent.get)
  if parent.isSome:
    let key = parent.get.parseChildKey(op.path.leafSegment)
    case key.kind
    # TODO catch if removed element doesnt exist
    of JArray:
      parent.get.elems.delete(key.idx)
    of JObject:
      parent.get.delete(key.member)
    else:
      assert false, "not implemented"
  else:
    op.abort("node at path does not exist")

method apply(op: ReplaceOperation, doc: JsonNode): JsonNode =
  if op.path.pointsToRoot:
    return op.value
  else:
    return doc
      .patch(newRemoveOperation(path = op.path))
      .patch(newAddOperation(path = op.path, value = op.value))

method apply(op: MoveOperation, doc: JsonNode): JsonNode =
  let node = doc.resolve(op.fromPath)
  if node.isNone:
    op.abort("node at path does not exist")
  result = doc
    .patch(newRemoveOperation(path = op.fromPath))
    .patch(newAddOperation(path = op.path, value = node.get))

method apply(op: TestOperation, doc: JsonNode): JsonNode =
  result = doc
  let node = doc.resolve(op.path)
  if node.get(nil) != op.value:
    op.abort("Test failed")

method apply(op: CopyOperation, doc: JsonNode): JsonNode =
  let node = doc.resolve(op.fromPath)
  if node.isNone:
    op.abort("node at from does not exist")
  result = doc.patch(newAddOperation(path = op.path, value = node.get))
