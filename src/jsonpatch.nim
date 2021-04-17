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

  # TODO use objects variants once https://github.com/nim-lang/RFCs/issues/368 is implemented
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

func apply(document: JsonNode, o: Operation): JsonNode =
  let jsonPointer = o.path.toJsonPointer()
  case o.op
  of Add:
    let value = o.value.get()
    if jsonPointer.pointsToRoot():
      return value
    var current = document
    var parent: JsonNode 
    # handle all intermediate nodes
    for idx, segment in jsonPointer.tokens[0..jsonPointer.tokens.len-2]:
      if segment == "":
        continue
      case current.kind
      of JObject:
        let intermediateNode = current.getOrDefault(segment)
        if intermediateNode == nil:
          let nextSegment = jsonPointer.tokens[idx + 1]
          case nextSegment.tokenContainerType()
          of JsonArray:
            current.add(segment, newJArray())
          of JsonObject:
            current.add(segment, newJObject())
        parent = current
        current = current[segment]
      of JArray:

        # if segment == "-":
          # currentNode = currentNode.
        discard
      # currentNode.
      else:
        raise newException(Defect,"not implemented")
    # now, handle last segment
    let key = jsonPointer.tokens[^1]
    case current.kind
    of JArray:
      let idx = parseInt(key)
      current.elems.insert(value, idx)
    of JObject:
      current.add(key, value)
    else:
        raise newException(Defect,"not implemented")

    document
  else:
    document

func applyPatch*(document: JsonNode, patch: JsonPatch): JsonNode =
  if len(patch.operations) == 0:
    return document
  result = patch.operations.foldl(a.apply(b), document)