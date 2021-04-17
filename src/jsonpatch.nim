import
  std / [json, options]

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
  JsonPatchParseError* = object of JsonPatchError

proc to*[T: JsonPatch](node: JsonNode, t: typedesc[T]): T =
  try:
    JsonPatch(operations: node.to(seq[Operation]))
  except KeyError:
    raise newException(JsonPatchParseError, getCurrentExceptionMsg())


proc `%`*(patch: JsonPatch): JsonNode =
  result = newJArray()
  for operation in patch.operations:
    let jsonOperation = newJObject()
    for key, value in (%operation).pairs():
      if value.kind != JNull:
        jsonOperation.add(key, value)
    result.add(jsonOperation)

# func diff*(first: JsonNode, second: JsonNode): JsonPatch =
  # return JsonPatch()

func applyPatch*(document: JsonNode, patch: JsonPatch): JsonNode =
  document
