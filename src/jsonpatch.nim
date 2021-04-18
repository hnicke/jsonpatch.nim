import
  jsonpatch / jsonpointer,
  std / [json, options, strformat, sequtils, strutils]

type

  OperationKind {.pure.} = enum
    Add = "add"
    Remove = "remove"
    Replace = "replace"
    Move = "move"
    Copy = "copy"
    Test = "test"

  # maybe use objects variants once https://github.com/nim-lang/RFCs/issues/368 is implemented
  Operation = object
    op: OperationKind
    path: string
    value: Option[JsonNode]
    `from`: Option[string]

  JsonPatch* = object
    operations: seq[Operation]

  JsonPatchError* = object of CatchableError
  InvalidJsonPatchError* = object of CatchableError


proc check(o: Operation) =
  proc abort(msg: string) =
    raise newException(InvalidJsonPatchError,
        &"Operation {o} is invalid: {msg}")
  case o.op
  of Add:
    if o.value.isNone: abort("Missing 'value'")
  else:
    discard

proc check(p: JsonPatch) =
  p.operations.apply(check)


proc to*[T: Operation](node: JsonNode, t: typedesc[T]): Operation =
  return Operation()

proc to*[T: JsonPatch](node: JsonNode, t: typedesc[T]): T =
  try:
    case node.kind
    of JArray:
      result = JsonPatch(operations: node.to(seq[Operation]))
      result.check()

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

func patch(document: JsonNode, o: Operation): JsonNode =
  let jsonPointer = o.path.toJsonPointer()
  case o.op
  of Add:
    let value = o.value.get()
    if jsonPointer.pointsToRoot():
      return value
    let parent = document.resolve(jsonPointer.parent.get)
    if parent.isSome:
      let key = parent.get.parseChildKey(jsonPointer.leafSegment())
      case key.kind
      of JArray:
        parent.get.elems.insert(value, key.idx)
      of JObject:
        parent.get.add(key.member, value)
      else:
        # TODO implement
        raise newException(Defect, "not implemented")
    else:
      raise newException(JsonPatchError,
          &"Failed to apply operation ${o}: Path does not exist")

    document
  # of Remove:

  else:
    document

func patch*(document: JsonNode, patch: JsonPatch): JsonNode =
  if len(patch.operations) == 0:
    return document
  result = patch.operations.foldl(a.patch(b), document)
