import
  std / [json, options],
  strformat,
  strutils

type
  JsonPointer = object
    segments: seq[string]

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

func toJsonPointer(path: string): JsonPointer =
  return JsonPointer(segments: path.split("/"))

func parseError(msg: string): ref JsonPatchParseError =
  return newException(JsonPatchParseError, msg)

proc to*[T: JsonPatch](node: JsonNode, t: typedesc[T]): T =
  try:
    JsonPatch(operations: node.to(seq[Operation]))
  except KeyError:
    raise parseError(getCurrentExceptionMsg())


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
